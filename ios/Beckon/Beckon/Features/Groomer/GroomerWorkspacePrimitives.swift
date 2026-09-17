import SwiftUI

struct GroomerWorkspaceSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        BeckonSection(title) {
            content()
        }
    }
}

struct GroomerGroupedSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        BeckonGroupedSurface {
            content
        }
    }
}

struct GroomerWorkspaceDivider: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        BeckonGroupedDivider(leadingInset: leadingInset)
    }
}
