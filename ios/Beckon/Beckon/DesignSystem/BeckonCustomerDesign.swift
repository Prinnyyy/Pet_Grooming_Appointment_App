#if DEBUG
import SwiftUI

// Source compatibility for the user-owned editable prototypes. Runtime adoption is complete:
// there is no environment key, stored flag or appearance branch in the shipping app.
extension EnvironmentValues {
    var beckonCustomerDesign: Bool {
        get { true }
        set { }
    }
}
#endif
