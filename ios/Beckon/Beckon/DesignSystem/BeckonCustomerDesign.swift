import SwiftUI

/// Customer adoption is scoped at its entry points. Shared primitives keep the
/// existing appearance for groomer screens until that role adopts a new design.
private struct BeckonCustomerDesignKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var beckonCustomerDesign: Bool {
        get { self[BeckonCustomerDesignKey.self] }
        set { self[BeckonCustomerDesignKey.self] = newValue }
    }
}
