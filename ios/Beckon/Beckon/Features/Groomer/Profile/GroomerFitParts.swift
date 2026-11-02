// The pieces the groomer's three pet-fit pages share (design: Fit signals, Portfolio, Evidence): one vocabulary for the groups of skills,
// the pips that say how many of a few slots are used, and the bar that says how a skill's completed jobs were answered. Colour comes
// from the role, so nothing here names coral.
import SwiftUI


// MARK: Skills

extension PetFitSignal.Group {
    /// What the groomer's pages call a group of skills (a claimed skill and the verified one it is proved by share their words).
    var beckonTitle: String {
        switch self {
        case .coatType, .verifiedCoat: "Coat skills"
        case .breedGroup: "Breed groups"
        case .sizeBand, .verifiedSize: "Size experience"
        case .careFlag, .verifiedCare: "Handling needs"
        case .serviceFit, .verifiedService: "Service strengths"
        }
    }

    var beckonSymbol: String {
        switch self {
        case .coatType, .verifiedCoat: "comb.fill"
        case .breedGroup: "pawprint.fill"
        case .sizeBand, .verifiedSize: "ruler.fill"
        case .careFlag, .verifiedCare: "heart.fill"
        case .serviceFit, .verifiedService: "scissors"
        }
    }

    /// One line for the group, where its name alone does not say what it is.
    var beckonSubtitle: String {
        switch self {
        case .coatType, .verifiedCoat: "Coat structures you handle reliably."
        case .breedGroup: "Breed contexts retained for matching compatibility."
        case .sizeBand, .verifiedSize: "Body-size experience is set above and does not use core slots."
        case .careFlag, .verifiedCare: "Care situations you accept."
        case .serviceFit, .verifiedService: "Service work that matches your setup."
        }
    }
}


// MARK: Pips

/// A row of short bars, the first `filled` of them lit: how many of a few slots are used (eight core skills, the three steps of how
/// sure the evidence is).
struct GroomerPips: View {
    let filled: Int
    let total: Int
    /// On the coral banner the lit pips are ink and the unlit ones its pale bubble; on white they are deep and the quiet edge.
    var onBanner = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? lit : unlit)
                    .frame(width: DesignTokens.Metrics.pipWidth, height: DesignTokens.Metrics.pipHeight)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) of \(total)")
    }

    private var lit: Color { onBanner ? DesignTokens.Colors.customerInk : DesignTokens.Colors.customerDeep }
    private var unlit: Color { onBanner ? DesignTokens.Colors.customerHeroBubble : DesignTokens.Colors.border }
}


// MARK: Proof

/// How a skill's completed jobs were answered, as one bar: the positive share, the negative share, and the rest (answers that are
/// neither, and jobs nobody has answered yet) in the quiet colour. The numbers are in the words beside it.
struct GroomerProofBar: View {
    let positive: Int
    let negative: Int
    let total: Int

    var body: some View {
        let whole = CGFloat(max(total, positive + negative, 1))
        GeometryReader { proxy in
            HStack(spacing: 0) {
                DesignTokens.Colors.customerDeep.frame(width: proxy.size.width * CGFloat(positive) / whole)
                DesignTokens.Colors.statusErrorText.frame(width: proxy.size.width * CGFloat(negative) / whole)
                Spacer(minLength: 0)
            }
        }
        .frame(height: DesignTokens.Metrics.proofBarHeight)
        .background(DesignTokens.Colors.border)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}
