import SwiftUI

// Request wizard, Home style: header and progress, the title block, the bottom bar and the review page. The inputs of steps 1 to 4
// are in `CustomerRequestPetAndService.swift`, `...TimeAndPlace.swift` and `...Details.swift`. These views take plain
// values so they can be previewed on their own; the live wizard is `CustomerRequestWizardView`, which uses them.
//
// The customer sees six steps. The shared wizard has five (pet to review); "Groomers" is the sixth, where the request is
// actually sent, so the path, the title block and the bottom bar treat it like any other step (S-011).

/// The six steps of creating a request: the five form steps of the shared wizard, then choosing who gets it.
/// How every step of the request wizard is dealt, the sixth (the groomer picker) included: the step title leads, the blocks under it
/// start at `contentStart` and follow one beat apart, in the step family with the direction the wizard sets. The wizard and the
/// picker both read these two numbers, and the picker takes the wizard's family and direction instead of setting its own while it is
/// a step (S-040).
enum CustomerRequestStepMotion {
    static let titleOrder = 0
    static let contentStart = 1
}


enum CustomerRequestStep: Int, CaseIterable, Identifiable {
    case pet, service, time, details, review, groomers

    var id: Self { self }

    init(_ step: CustomerRequestWizardStep) {
        switch step {
        case .pet: self = .pet
        case .service: self = .service
        case .time: self = .time
        case .details: self = .details
        case .review: self = .review
        }
    }

    /// The matching step of the shared wizard; `nil` for "Groomers".
    var formStep: CustomerRequestWizardStep? { CustomerRequestWizardStep(rawValue: rawValue) }

    var title: String { formStep?.title ?? "Groomers" }

    var headline: String { formStep?.headline ?? "Who should hear about it?" }

    /// None: the headline of a step says what it asks, and a line under it only said it again (S-066).
    var subtitle: String? { nil }

    var pathIcon: String {
        switch self {
        case .pet: "pawprint.fill"
        case .service: "scissors"
        case .time: "calendar"
        case .details: "text.badge.plus"
        case .review: "checkmark.seal.fill"
        case .groomers: "person.2.fill"
        }
    }

    var shortTitle: String { self == .time ? "Time" : title }
}

/// Progress band: the six-node path and nothing else. The nodes say how far you are and how many steps there are, the headline
/// under it says which step this is, so the "Grooming request" caption, the "2 of 6" chip and the step name under the path were
/// the same thing three more times (S-066). Once the request has been sent every node is done and it says "Request sent".
struct CustomerRequestWizardHeader: View {
    let step: CustomerRequestStep
    var isSent = false
    private let steps = CustomerRequestStep.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            DesignStepPath(labels: steps.map(\.shortTitle), systemImages: steps.map(\.pathIcon),
                current: isSent ? steps.count + 1 : step.rawValue + 1, nodeSize: 32, showsLabels: false,
                pulsesCurrent: true)
                .padding(.bottom, DesignTokens.Spacing.xs)
            if isSent {
                Text("Request sent")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.push(from: .trailing))
            }
        }
        .beckonAnimation(DesignTokens.Motion.swap, value: isSent ? -1 : step.rawValue)
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.top, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [DesignTokens.Colors.customerTint, DesignTokens.Colors.appBackground],
            startPoint: .top, endPoint: .bottom))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isSent ? "Grooming request. Sent."
            : "Grooming request. Step \(step.rawValue + 1) of \(steps.count): \(step.title)")
        .accessibilityIdentifier("customer.requests.wizard.header")
    }
}

/// Headline and subtitle at the top of each step.
struct CustomerRequestWizardTitleBlock: View {
    let headline: String
    var subtitle: String?

    init(step: CustomerRequestStep) {
        headline = step.headline
        subtitle = step.subtitle
    }

    init(step: CustomerRequestWizardStep) {
        self.init(step: CustomerRequestStep(step))
    }

    init(headline: String, subtitle: String? = nil) {
        self.headline = headline
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(headline)
                .font(DesignTokens.Typography.Expressive.hero)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(DesignTokens.Typography.Expressive.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Back (or Done) on the left, the one mint primary action on the right. Every step of the request uses it, the groomers
/// step included. With `confirmation` the primary action first asks "Send this request?" and shows that summary.
struct DesignActionBar: View {
    let leadingTitle: String
    let leadingImage: String
    let primaryTitle: String
    let primaryImage: String
    var isPrimaryEnabled = true
    /// False for a moment when the left button must not be tapped (the page is about to leave by itself); it dims like any disabled one.
    var isLeadingEnabled = true
    var isBusy = false
    var confirmation: String?
    var leadingIdentifier = "customer.requests.wizard.back"
    var primaryIdentifier = "customer.requests.wizard.continue"
    /// The primary action leans in when this changes (the step) and when the bar appears.
    var bumpTrigger = 0
    let leading: () -> Void
    let primary: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isConfirming = false
    @State private var confirmedSummary = ""

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))) {
            Button(action: leading) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: leadingImage)
                    Text(leadingTitle)
                }
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .frame(minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.card))
            .disabled(isBusy || !isLeadingEnabled)
            .accessibilityIdentifier(leadingIdentifier)

            Button {
                if let confirmation {
                    confirmedSummary = confirmation
                    isConfirming = true
                } else { primary() }
            } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if isBusy {
                        ProgressView().tint(DesignTokens.Colors.customerInk)
                    }
                    Text(primaryTitle)
                        .font(DesignTokens.Typography.Expressive.headline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if !isBusy {
                        Image(systemName: primaryImage)
                            .font(DesignTokens.Typography.Expressive.glyph)
                    }
                }
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.pill))
            .disabled(!isPrimaryEnabled)
            .beckonBump(trigger: bumpTrigger)
            .accessibilityIdentifier(primaryIdentifier)
        }
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.actionAreaInset)
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) { DesignTokens.Colors.borderSoft.frame(height: DesignTokens.Ledge.edgeWidth / 2) }
        .sendRequestDialog(isPresented: $isConfirming, summary: confirmedSummary, send: { primary() })
    }
}


/// The form steps' bar: Back (Close on the first step) and Continue. The review step's action is the last form action.
struct CustomerRequestWizardBottomBar: View {
    let step: CustomerRequestWizardStep
    let backTitle: String
    let primaryTitle: String
    let isPrimaryEnabled: Bool
    let isSubmitting: Bool
    let back: () -> Void
    let advance: () -> Void

    private var isFinal: Bool { step == .review }

    var body: some View {
        DesignActionBar(leadingTitle: backTitle, leadingImage: step == .pet ? "xmark" : "chevron.left",
            primaryTitle: primaryTitle, primaryImage: isFinal ? "sparkles" : "arrow.right",
            isPrimaryEnabled: isPrimaryEnabled, isBusy: isSubmitting,
            leadingIdentifier: step == .pet ? "customer.requests.wizard.dismiss" : "customer.requests.wizard.back",
            primaryIdentifier: isFinal ? "customer.requests.publish" : "customer.requests.wizard.continue",
            bumpTrigger: step.rawValue, leading: back, primary: advance)
    }
}

/// The review step: a summary "ticket" with the pup resting on it, what matching will look for, and the privacy note.
struct CustomerRequestWizardReview: View {
    let rows: [CustomerRequestWizardReviewPresentation.Row]
    let photos: [PendingGroomingRequestPhoto]
    let fitChips: [CustomerRequestWizardFitInputPresentation.Chip]
    var isRecoveringPublication = false
    var isRevisingRequest = false
    /// Where this page's blocks start counting when a title block above them leads; 0 when they lead themselves.
    var entranceStart = 0
    /// A row asks for its step; nil leaves the rows as plain facts (the chrome gallery).
    var onEdit: ((CustomerRequestWizardStep) -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        BeckonCascade(start: entranceStart, spacing: DesignTokens.Layout.sectionSpacing) {
            if isRecoveringPublication {
                BeckonLedgeNote(systemImage: "arrow.clockwise",
                    text: "Not confirmed yet. Retrying will not create a second request.")
                    .accessibilityIdentifier("customer.requests.publication-recovery")
            }
            if isRevisingRequest {
                BeckonLedgeNote(systemImage: "square.and.pencil",
                    text: "Publishing these changes will replace the original request and close its existing offers.")
            }

            DesignPupPeek { summary }

            // What matching looks for, only when there is something specific to say; the line that said "based on the pet and the
            // service" and the one that explained why a time helps are gone: the page above already shows both.
            if !fitChips.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                    BeckonLedgeHeading(title: "Fit needs", systemImage: "sparkles")
                    DesignFactCard {
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(fitChips) { chip in fitChip(chip) }
                        }
                    }
                }
            }

            BeckonLedgeNote(systemImage: "lock", text: "Your phone and email stay hidden until you accept an offer.")
        }
    }

    private var summary: some View {
        VStack(spacing: 0) {
            // The title above says it is your request; the mint band that said so again is gone, the pup rests on the top edge.
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                ForEach(rows) { row in summaryRow(row) }
                if !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            ForEach(photos) { photo in
                                BeckonModuleImage(data: photo.data) {
                                    Image(systemName: "photo").foregroundStyle(DesignTokens.Colors.textTertiary)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(DesignTokens.Colors.placeholderFill)
                                }
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill, style: .continuous))
                                .accessibilityLabel("Request photo")
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .beckonLedge(.card)
    }

    @ViewBuilder
    private func summaryRow(_ row: CustomerRequestWizardReviewPresentation.Row) -> some View {
        let fact = DesignFactRow(systemImage: icon(for: row.title), title: row.title, value: row.value)
        if let onEdit {
            Button { onEdit(step(for: row.title)) } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    fact
                    Image(systemName: "chevron.right")
                        .font(DesignTokens.Typography.Expressive.micro)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityLabel("\(row.title), \(row.value)")
            .accessibilityHint("Goes back to change it")
            .accessibilityIdentifier("customer.requests.review.edit.\(step(for: row.title).rawValue)")
        } else {
            fact
        }
    }

    /// The step a review row is answered in.
    private func step(for title: String) -> CustomerRequestWizardStep {
        switch title {
        case "Pet": .pet
        case "Service": .service
        case "Preferred time", "Location": .time
        default: .details
        }
    }

    private func icon(for title: String) -> String {
        switch title {
        case "Pet": "pawprint.fill"
        case "Service": "scissors"
        case "Preferred time": "calendar"
        case "Location": "location.fill"
        case "Notes": "text.quote"
        default: "photo.on.rectangle"
        }
    }

    private func fitChip(_ chip: CustomerRequestWizardFitInputPresentation.Chip) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: chip.systemImage)
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(chip.label)
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                Text(chip.title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(DesignTokens.Colors.customerTint,
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill, style: .continuous))
    }
}
