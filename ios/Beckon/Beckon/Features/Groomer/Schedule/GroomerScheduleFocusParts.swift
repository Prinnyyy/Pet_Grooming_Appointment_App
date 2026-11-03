import SwiftUI

/// Shared real/skeleton slot contents; placeholders inherit the rendered element's bounds.
struct GroomerFocusHeader: View {
    let title: String
    var price: String? = nil
    var isSkeleton = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.sm))) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Circle().fill(DesignTokens.Colors.customerDeep)
                    .frame(width: DesignTokens.Metrics.liveDot, height: DesignTokens.Metrics.liveDot)
                Text(title).font(DesignTokens.Typography.Expressive.chip)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.customerTint, in: Capsule())
            .scheduleFocusPlaceholder(isSkeleton, cornerRadius: DesignTokens.CornerRadius.pill)
            if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.sm) }
            if let price {
                Text(price).font(DesignTokens.Typography.Expressive.section)
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.85)
                    .scheduleFocusPlaceholder(isSkeleton)
            }
        }
        .foregroundStyle(DesignTokens.Colors.customerInk)
        .accessibilityElement(children: .combine)
    }
}

struct GroomerFocusIdentity: View {
    let species: String
    let name: String
    let detail: String
    var isSkeleton = false
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            GroomerPetAvatar(species: species, size: DesignTokens.Metrics.petAvatar)
                .scheduleFocusPlaceholder(isSkeleton, cornerRadius: DesignTokens.CornerRadius.round)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs / 2) {
                Text(name).font(DesignTokens.Typography.Expressive.hero).lineLimit(1)
                    .scheduleFocusPlaceholder(isSkeleton)
                Text(detail).font(DesignTokens.Typography.Expressive.body).lineLimit(1)
                    .scheduleFocusPlaceholder(isSkeleton)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(DesignTokens.Colors.customerInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GroomerFocusTiming: View {
    let isLive: Bool
    let timing: String
    let duration: String
    var started: String = ""
    var fraction: Double = 0
    var isSkeleton = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            if isLive {
                Capsule().fill(DesignTokens.Colors.customerHeroBubble)
                    .frame(height: DesignTokens.Metrics.dayShapeHeight - 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(DesignTokens.Colors.customerInk)
                                .frame(width: proxy.size.width * min(1, max(0, fraction)))
                        }
                    }
                    .scheduleFocusPlaceholder(isSkeleton, cornerRadius: DesignTokens.CornerRadius.pill)
                (typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                    Text(started).scheduleFocusPlaceholder(isSkeleton)
                    if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.sm) }
                    Text(timing).scheduleFocusPlaceholder(isSkeleton)
                }
            } else {
                (typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md))) {
                    Text(timing)
                    Label(duration, systemImage: "clock")
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                }
            }
        }
        .font(DesignTokens.Typography.Expressive.label)
        .foregroundStyle(DesignTokens.Colors.customerInk)
        .monospacedDigit().lineLimit(1)
    }
}

struct GroomerFocusPlace: View {
    let symbol: String
    let text: String
    var isSkeleton = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: symbol)
                .scheduleFocusPlaceholder(isSkeleton, cornerRadius: DesignTokens.CornerRadius.round)
            Text(text).lineLimit(1).scheduleFocusPlaceholder(isSkeleton)
        }
        .font(DesignTokens.Typography.Expressive.label)
        .foregroundStyle(DesignTokens.Colors.customerInk)
    }
}

struct GroomerFocusMessageGlyph: View {
    var isSkeleton = false
    var body: some View {
        Image(systemName: "bubble.left.fill")
            .font(DesignTokens.Typography.Expressive.glyph)
            .foregroundStyle(DesignTokens.Colors.customerDeep)
            .frame(width: DesignTokens.Metrics.ledgeRoundControl, height: DesignTokens.Metrics.ledgeRoundControl)
            .scheduleFocusPlaceholder(isSkeleton, cornerRadius: DesignTokens.CornerRadius.round)
    }
}

struct GroomerFocusActionLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))) { content() }
    }
}

extension View {
    @ViewBuilder
    func scheduleFocusPlaceholder(_ loading: Bool, cornerRadius: CGFloat? = nil) -> some View {
        if loading {
            hidden().overlay {
                if let cornerRadius { DesignSkeletonBlock(cornerRadius: cornerRadius) }
                else {
                    // Match DesignSkeletonLine's capsule treatment without losing the real text's bounds.
                    GeometryReader { proxy in
                        DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.round)
                            .frame(height: proxy.size.height * 0.6).frame(maxHeight: .infinity)
                    }
                }
            }
        } else { self }
    }
}
