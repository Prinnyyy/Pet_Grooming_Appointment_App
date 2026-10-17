#if DEBUG
import SwiftUI

struct BeckonComponentCatalog: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                BeckonColorActionCatalog()
                BeckonSection("Actions", subtitle: "Default, visually unavailable, and disabled states") {
                    VStack(spacing: DesignTokens.Layout.sectionContentSpacing) {
                        Button("Primary action") {}
                            .buttonStyle(BeckonPrimaryButtonStyle())

                        Button("Visually unavailable") {}
                            .buttonStyle(BeckonPrimaryButtonStyle(isVisuallyEnabled: false))

                        Button("Disabled action") {}
                            .buttonStyle(BeckonPrimaryButtonStyle())
                            .disabled(true)

                        Button("Secondary action") {}
                            .buttonStyle(BeckonSecondaryButtonStyle())
                    }
                }

                BeckonSection("Surfaces") {
                    VStack(spacing: DesignTokens.Layout.sectionContentSpacing) {
                        BeckonCard {
                            catalogCopy(title: "Raised card", detail: "Photography-led or decision content.")
                        }

                        BeckonGroupedSurface {
                            catalogCopy(title: "Grouped surface", detail: "Operational rows without elevation.")
                                .padding(DesignTokens.Layout.surfaceInset)
                        }

                        BeckonSelectionCard(
                            isSelected: true,
                            accent: .customer,
                            action: {}
                        ) {
                            catalogCopy(title: "Selected option", detail: "Customer accent selection state.")
                        }

                        BeckonSelectionCard(
                            isSelected: false,
                            isInvalid: true,
                            accent: .customer,
                            action: {}
                        ) {
                            catalogCopy(title: "Invalid option", detail: "Error state remains visible without color-only meaning.")
                        }
                    }
                }

                BeckonSection("Settings and fields") {
                    VStack(spacing: DesignTokens.Layout.sectionContentSpacing) {
                        BeckonGroupedSurface {
                            BeckonSettingsRowLabel(
                                title: "Profile settings",
                                summary: "Name, contact details, and service address",
                                systemImage: "person.crop.circle",
                                accent: .customer
                            )
                        }

                        BeckonFieldGroup(
                            "Pet name",
                            supportingText: "Use the name your groomer should recognize."
                        ) {
                            TextField("Pet name", text: .constant("Mochi"))
                                .beckonFormField()
                        }

                        BeckonFieldGroup(
                            "Service address",
                            errorText: "Confirm this address before continuing."
                        ) {
                            TextField("Address", text: .constant(""))
                                .beckonFormField(isInvalid: true)
                        }
                    }
                }

                BeckonSection("Status and feedback") {
                    VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                statusChips
                            }
                            VStack(alignment: .leading) {
                                statusChips
                            }
                        }

                        BeckonLoadingView(title: "Loading appointments")
                        BeckonEmptyState(
                            title: "No requests yet",
                            message: "Your open grooming requests will appear here."
                        )
                        BeckonErrorBanner(
                            title: "Could not refresh",
                            message: "Check your connection and try again."
                        )
                    }
                }
            }
            .beckonPageInsets()
        }
        .background(DesignTokens.Colors.appBackground)
        .beckonKeyboardDoneAccessory()
    }

    private func catalogCopy(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.cardTitle)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Text(detail)
                .font(DesignTokens.Typography.supporting)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusChips: some View {
        BeckonStatusChip("Confirmed", systemImage: "checkmark", tone: .success)
        BeckonStatusChip("Needs review", systemImage: "exclamationmark", tone: .warning)
        BeckonStatusChip("Unavailable", systemImage: "xmark", tone: .error)
        BeckonStatusChip("Open", systemImage: "clock", tone: .info)
        BeckonStatusChip("Cancelled", systemImage: "xmark.circle", tone: .neutral)
    }
}

struct BeckonColorActionCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            BeckonSection("Customer") {
                Button("Primary action") {}.buttonStyle(BeckonPrimaryButtonStyle(accent: .customer))
                Button("Secondary action") {}.buttonStyle(BeckonSecondaryButtonStyle(accent: .customer))
                Button("Text action") {}.buttonStyle(BeckonTertiaryButtonStyle(accent: .customer))
                Button("Destructive action") {}.buttonStyle(BeckonDestructiveButtonStyle())
            }
            BeckonSection("Groomer") {
                Button("Primary action") {}.buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer))
                Button("Secondary action") {}.buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
                Button("Text action") {}.buttonStyle(BeckonTertiaryButtonStyle(accent: .groomer))
                Button("Destructive action") {}.buttonStyle(BeckonDestructiveButtonStyle())
            }
            BeckonStatusChip("Open", systemImage: "clock", tone: .info)
            BeckonStatusChip("Has offers", systemImage: "tag", tone: .warning)
            BeckonStatusChip("Completed", systemImage: "checkmark.circle", tone: .success)
            BeckonStatusChip("Cancelled", systemImage: "xmark.circle", tone: .neutral)
            BeckonStatusChip("Could not save", systemImage: "exclamationmark.triangle", tone: .error)
        }
    }
}

#Preview("Color actions") {
    ScrollView { BeckonColorActionCatalog().beckonPageInsets() }
}

#Preview("Color actions AX3") {
    ScrollView { BeckonColorActionCatalog().beckonPageInsets() }
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Default") {
    BeckonComponentCatalog()
}

#Preview("Accessibility 3") {
    BeckonComponentCatalog()
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 390, height: 844)
}
#endif
