import SwiftUI

extension EnvironmentValues {
    @Entry var groomerVisitAppearance = false
}

/// Resting lips for the three shared unoutlined faces in the groomer preview.
enum GroomerVisitButtonLips {
    static let coral = Color(.sRGB, red: 187/255, green: 101/255, blue: 88/255)
    static let whiteFace = Color(.sRGB, red: 199/255, green: 178/255, blue: 168/255)
    static let neutral = Color(.sRGB, red: 175/255, green: 169/255, blue: 160/255)
}
