import SwiftUI

struct CustomerRequestWizardHeader: View {
    let currentStep: CustomerRequestWizardStep

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Grooming Request")
                .font(DesignTokens.Typography.fieldLabel)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignTokens.Colors.borderSoft)
                    Capsule().fill(DesignTokens.Colors.customerDeep)
                        .frame(width: proxy.size.width * currentStep.progress)
                }
            }
            .frame(height: DesignTokens.Spacing.sm)
            .accessibilityHidden(true)
            Text("Step \(currentStep.rawValue + 1) of \(CustomerRequestWizardStep.allCases.count): \(currentStep.title)")
                .font(DesignTokens.Typography.supporting)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DesignTokens.Spacing.xs)
        }
        .padding(.leading, CustomerRequestWizardHeaderLayout.progressTrackLeadingOffset)
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(DesignTokens.Colors.appBackground)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("customer.requests.wizard.header")
    }
}

nonisolated enum CustomerRequestWizardHeaderLayout {
    static let progressTrackLeadingOffset: CGFloat = 0
}
