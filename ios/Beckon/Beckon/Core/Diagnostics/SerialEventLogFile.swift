import Foundation

/// Only this queue touches the file/counters. Recording an already-sanitized line never waits
/// on disk. Explicit reads drain the queue for exports/tests; they are not used while navigating.
nonisolated final class SerialEventLogFile: @unchecked Sendable {
    let url: URL
    private let queue = DispatchQueue(label: "com.hellobeckon.event-log", qos: .utility)
    private let maximumLines: Int
    private let maximumBytes: Int
    private let retention: TimeInterval
    private var lineCount = 0
    private var byteCount = 0

    init(url: URL, maximumLines: Int, maximumBytes: Int = .max, retention: TimeInterval) {
        self.url = url
        self.maximumLines = max(1, maximumLines)
        self.maximumBytes = maximumBytes
        self.retention = retention
        queue.async { try? self.trim() }
    }

    func append(_ line: String) {
        queue.async {
            do {
                try self.ensureDirectory()
                if !FileManager.default.fileExists(atPath: self.url.path) {
                    FileManager.default.createFile(atPath: self.url.path, contents: nil)
                }
                let data = Data((line + "\n").utf8)
                let handle = try FileHandle(forWritingTo: self.url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                self.lineCount += 1
                self.byteCount += data.count
                if self.lineCount > self.maximumLines || self.byteCount > self.maximumBytes {
                    try self.trim()
                }
            } catch { /* Diagnostics must never prevent a user operation. */ }
        }
    }

    func replace(with lines: [String]) {
        queue.async { try? self.write(lines) }
    }

    func readLines() throws -> [String] { try queue.sync { try read() } }

    private func read() throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    private func trim() throws {
        struct Stamp: Decodable { let timestamp: Date }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cutoff = Date().addingTimeInterval(-retention)
        var retained = ((try? read()) ?? []).suffix(maximumLines).filter {
            guard let stamp = try? decoder.decode(Stamp.self, from: Data($0.utf8)) else { return false }
            return stamp.timestamp >= cutoff
        }
        var bytes = retained.reduce(0) { $0 + $1.utf8.count + 1 }
        while bytes > maximumBytes, !retained.isEmpty {
            bytes -= retained.removeFirst().utf8.count + 1
        }
        try write(retained)
    }

    private func write(_ lines: [String]) throws {
        try ensureDirectory()
        let data = Data((lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n").utf8)
        try data.write(to: url, options: .atomic)
        lineCount = lines.count
        byteCount = data.count
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
}
