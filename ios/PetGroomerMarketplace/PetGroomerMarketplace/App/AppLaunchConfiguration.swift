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
