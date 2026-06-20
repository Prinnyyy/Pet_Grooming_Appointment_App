import SwiftUI

struct RoleOnboardingPlaceholderView: View {
    var body: some View {
        NavigationStack {
            FeaturePlaceholderView(
                title: "Choose your role",
                message: "Role onboarding is not connected yet.",
                systemImage: "person.2"
            )
        }
    }
}
