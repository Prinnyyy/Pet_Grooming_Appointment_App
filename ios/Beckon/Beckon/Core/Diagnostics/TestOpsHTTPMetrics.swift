import Foundation

#if DEBUG && targetEnvironment(simulator)
nonisolated final class TestOpsHTTPMetrics: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let directory: URL

    init?(arguments: [String]) {
        guard arguments.contains("--beckon-testops-record-http"),
              let index = arguments.firstIndex(of: "--beckon-testops-run-id"),
              arguments.indices.contains(index + 1),
              arguments[index + 1].range(of: "^TESTOPS-T392-[A-Z0-9-]{1,70}$", options: .regularExpression) != nil,
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        directory = documents.appendingPathComponent("TestOps").appendingPathComponent(arguments[index + 1])
        super.init()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard task.originalRequest?.httpMethod == "POST",
              task.originalRequest?.url?.path == "/rest/v1/rpc/accept_groomer_offer_v2" else { return }
        let transactions = metrics.transactionMetrics.compactMap { transaction -> [String: Any]? in
            guard let start = transaction.requestStartDate, let end = transaction.responseEndDate else { return nil }
            return ["requestStart": start.timeIntervalSince1970, "responseEnd": end.timeIntervalSince1970,
                    "status": (transaction.response as? HTTPURLResponse)?.statusCode ?? 0]
        }
        guard !transactions.isEmpty else { return }
        let record: [String: Any] = ["endpoint": "accept_groomer_offer_v2", "taskID": task.taskIdentifier,
                                     "transactions": transactions]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            try data.write(to: directory.appendingPathComponent("http-\(UUID().uuidString).json"), options: .atomic)
        } catch {
            // Missing timing artifacts fail acceptance; diagnostics must not change a booking result.
        }
    }
}
#endif
