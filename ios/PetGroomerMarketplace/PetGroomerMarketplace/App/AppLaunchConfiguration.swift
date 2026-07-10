import Foundation

struct AppTestOpsConfiguration: Equatable, Sendable {
    static let runIDArgument = "--groomly-testops-run-id"
    static let scenarioArgument = "--groomly-testops-scenario"
    static let clearSessionArgument = "--groomly-testops-clear-session"
    static let disableAnimationsArgument = "--groomly-testops-disable-animations"

    let runID: String?
    let scenarioID: String?
    let clearsSessionBeforeRestore: Bool
    let disablesAnimations: Bool

    init(
        runID: String? = nil,
        scenarioID: String? = nil,
        clearsSessionBeforeRestore: Bool = false,
        disablesAnimations: Bool = false
    ) {
        self.runID = Self.normalizedValue(runID)
        self.scenarioID = Self.normalizedValue(scenarioID)
        self.clearsSessionBeforeRestore = clearsSessionBeforeRestore
        self.disablesAnimations = disablesAnimations
    }

    init(arguments: [String]) {
        self.init(
            runID: Self.value(after: Self.runIDArgument, in: arguments),
            scenarioID: Self.value(after: Self.scenarioArgument, in: arguments),
            clearsSessionBeforeRestore: arguments.contains(Self.clearSessionArgument),
            disablesAnimations: arguments.contains(Self.disableAnimationsArgument)
        )
    }

    var isEnabled: Bool {
        runID != nil || scenarioID != nil
            || clearsSessionBeforeRestore || disablesAnimations
    }

    var scope: String {
        if let scenarioID {
            "testops.\(scenarioID)"
        } else {
            "testops"
        }
    }

    var metadata: [String: String] {
        var values: [String: String] = [:]
        if let runID {
            values["automationRunID"] = runID
        }
        if let scenarioID {
            values["scenarioID"] = scenarioID
        }
        values["clearSession"] = clearsSessionBeforeRestore ? "true" : "false"
        values["disableAnimations"] = disablesAnimations ? "true" : "false"
        return values
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }

        let candidate = arguments[valueIndex]
        guard candidate.hasPrefix("--") == false else { return nil }
        return normalizedValue(candidate)
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

nonisolated enum AppTestOpsAccessibility {
    private static let marker = "TESTOPS:"

    static func runID(fromServiceNotes serviceNotes: String?) -> String? {
        guard let serviceNotes,
              let markerRange = serviceNotes.range(of: marker) else {
            return nil
        }

        let suffix = serviceNotes[markerRange.upperBound...]
        let candidate = suffix.prefix { !$0.isWhitespace }
        guard candidate.count >= 9,
              candidate.count <= 104,
              candidate.hasPrefix("TESTOPS-") else {
            return nil
        }

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        guard candidate.unicodeScalars.allSatisfy(allowed.contains) else {
            return nil
        }
        return String(candidate)
    }

    static func identifier(
        prefix: String,
        serviceNotes: String?
    ) -> String? {
        guard let runID = runID(fromServiceNotes: serviceNotes) else {
            return nil
        }
        return "\(prefix).\(runID)"
    }

    static func requestReference(_ requestID: UUID) -> String {
        String(requestID.uuidString.prefix(8)).uppercased()
    }

    static func requestIdentifier(prefix: String, requestID: UUID) -> String {
        "\(prefix).\(requestReference(requestID))"
    }
}

struct AppLaunchConfiguration: Equatable, Sendable {
    static let signedOutAuthSessionArgument =
        "--groomly-ui-test-signed-out-auth"

    let usesSignedOutAuthSessionRepository: Bool
    let testOps: AppTestOpsConfiguration

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        usesSignedOutAuthSessionRepository = arguments.contains(
            Self.signedOutAuthSessionArgument
        )
        testOps = AppTestOpsConfiguration(arguments: arguments)
    }
}
