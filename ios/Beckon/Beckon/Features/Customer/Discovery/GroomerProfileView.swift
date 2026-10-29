// The page of one groomer, as a customer needs to read it before trusting them with a pet (S-069). The old "Groomer profile" sheet was
// the list card again (avatar, name, city, stars, a bio line) with the buttons under it, so nothing of what the groomer has put into
// the app reached the customer. This page is built from all of it: who they are and how they rate, what they say about themselves,
// where they work, their portfolio (photos with the kind of pet each shows), every service with its time and reference price, what
// they claim to be good with, and when they work. When the page was opened from a request it starts with how the groomer stands for
// that request. One page for every way in (Saved groomers, the picker of the request wizard); what the bottom bar does is the
// caller's: choose this groomer, send the request, nothing.
import SwiftUI


/// What the page knows about the request it was opened from: the groomer's place in it. Nothing when it was opened from a plain list.
struct GroomerProfileContext {
    /// The pet of the request, when it is known (a request that was already sent); the section says "your request" otherwise.
    var petName: String?
    /// "estimated_fit", "assessment_required" or anything else (not a fit).
    var eligibilityState: String?
    var distanceMiles: Double?
    var referencePrice: GroomerReferencePrice?
    var evidence: MatchingEvidence?
}


struct GroomerProfileView<Bar: View>: View {
    let profile: MarketplaceGroomerSummary
    var avatarData: Data?
    var content: GroomerProfileContent
    var context: GroomerProfileContext?
    /// nil: the page has no heart (the bar of the caller carries it).
    var isFavorite: Bool?
    var onFavorite: () -> Void
    /// Set when the page is a sheet: the page then draws its own top bar with the close button (no system navigation bar, no "Done").
    var onClose: (() -> Void)?
    @ViewBuilder let bar: Bar
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The photo that was opened, and the one showing now (it changes as the person swipes).
    @State private var viewing: GroomerWork?
    @State private var viewerPosition: UUID?

    init(profile: MarketplaceGroomerSummary, avatarData: Data? = nil, content: GroomerProfileContent,
         context: GroomerProfileContext? = nil, isFavorite: Bool? = nil, onFavorite: @escaping () -> Void = {},
         onClose: (() -> Void)? = nil, @ViewBuilder bar: () -> Bar) {
        self.profile = profile
        self.avatarData = avatarData
        self.content = content
        self.context = context
        self.isFavorite = isFavorite
        self.onFavorite = onFavorite
        self.onClose = onClose
        self.bar = bar()
    }

    var body: some View {
        DesignPage {
            hero
            if let context { forRequest(context) }
            about
            if !content.works.isEmpty { portfolio }
            if !content.services.isEmpty { services }
            if !content.specialties.isEmpty { specialties }
            if !content.windows.isEmpty || content.noticeDays != nil || content.timeOff != nil { availability }
        }
        .accessibilityIdentifier("customer.groomer-profile")
        .safeAreaInset(edge: .top, spacing: 0) {
            if let onClose { DesignSheetBar(title: "Groomer profile", closeIdentifier: "customer.groomer-profile.close", onClose: onClose) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bar }
        // A photo covers the whole phone, not a sheet over the sheet. It is shown and hidden without the system's slide: the viewer
        // fades itself in and out.
        .fullScreenCover(item: $viewing) { _ in
            GroomerWorkViewer(works: content.works, position: $viewerPosition)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var stacks: Bool { typeSize.isAccessibilitySize }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            (stacks
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
                : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.lg))) {
                BeckonProfileAvatar(data: avatarData, tone: .groomer, size: 88,
                    cornerRadius: DesignTokens.CornerRadius.inset)
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(profile.displayName)
                        .font(DesignTokens.Typography.Expressive.title)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if profile.isVerified { BeckonMetaChip(text: "Verified", systemImage: "checkmark.seal.fill") }
                    if let place { Label(place, systemImage: "mappin.and.ellipse").designSupportingText() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let isFavorite {
                    GroomerFavoriteButton(isFavorite: isFavorite, size: DesignTokens.Metrics.minimumTouchTarget,
                        action: onFavorite)
                }
            }
            (stacks
                ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))) {
                ratingTile
                if let years = profile.yearsExperience { stat(value: years == 1 ? "1 yr" : "\(years) yrs", caption: "experience") }
                stat(value: content.workplace.value, caption: content.workplace.caption)
            }
        }
        .designCardBody()
    }

    private var place: String? {
        let text = [profile.city, profile.state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return text.isEmpty ? nil : text
    }

    private var ratingTile: some View {
        let average = profile.ratingAverage
        return VStack(spacing: 2) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if average != nil {
                    Image(systemName: "star.fill").foregroundStyle(DesignTokens.Colors.ratingStar).accessibilityHidden(true)
                }
                Text(average.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "New")
            }
            .font(DesignTokens.Typography.Expressive.title)
            .foregroundStyle(DesignTokens.Colors.customerInk)
            Text(profile.ratingCount == 0 ? "no reviews yet" : profile.ratingCount == 1 ? "1 review" : "\(profile.ratingCount) reviews")
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .statTileFrame()
        .accessibilityElement(children: .combine)
    }

    private func stat(value: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DesignTokens.Typography.Expressive.title)
                .foregroundStyle(DesignTokens.Colors.customerInk)
            Text(caption)
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .statTileFrame()
        .accessibilityElement(children: .combine)
    }

    // MARK: For the request

    private func forRequest(_ context: GroomerProfileContext) -> some View {
        DesignSection(title: context.petName.map { "For \($0)'s request" } ?? "For your request", systemImage: "checkmark.seal.fill") {
            let fit = Self.fit(context.eligibilityState)
            DesignValueRow(title: "Fit", value: fit.text, systemImage: fit.symbol)
            if let miles = context.distanceMiles {
                DesignValueRow(title: "Distance", value: "\(miles.formatted(.number.precision(.fractionLength(1)))) mi",
                    systemImage: "location.fill")
            }
            if let price = context.referencePrice {
                DesignValueRow(title: "Reference price", value: "From \(price.amount.formatted(.currency(code: price.currency)))",
                    systemImage: "tag.fill")
            }
            if let evidence = context.evidence {
                BeckonFitEvidenceBlock(scoreText: nil, summary: evidence.summary, reason: evidence.detail, isCompact: false)
            }
        }
    }

    private static func fit(_ state: String?) -> (text: String, symbol: String) {
        switch state {
        case "estimated_fit": ("Fits your request", "checkmark.circle.fill")
        case "assessment_required": ("Needs groomer assessment", "stethoscope")
        default: ("Not a fit for this request", "minus.circle")
        }
    }

    // MARK: About

    private var about: some View {
        DesignSection(title: "About", systemImage: "person.text.rectangle") {
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(DesignTokens.Typography.Expressive.body)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DesignValueRow(title: "Where", value: whereText, systemImage: "house.fill")
            if content.modes.contains(.groomerComesToCustomer), let radius = content.radiusMiles {
                DesignValueRow(title: "Travels", value: "Up to \(radius) mi", systemImage: "car.fill")
            }
        }
    }

    private var whereText: String {
        let studio = profile.city.map { "Their studio in \($0)" } ?? "Their studio"
        switch (content.modes.contains(.groomerComesToCustomer), content.modes.contains(.customerComesToGroomer)) {
        case (true, true): return "At your home or \(studio.prefix(1).lowercased() + studio.dropFirst())"
        case (true, false): return "At your home"
        case (false, true): return studio
        default: return "Location not listed"
        }
    }

    // MARK: Portfolio

    private var portfolio: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Portfolio", systemImage: "photo.on.rectangle.angled", count: content.works.count)
            BeckonPeekCarousel(wholeCards: 1, minimumWidth: 260, pageCount: content.works.count,
                pageLabel: { "Photo \($0 + 1) of \(content.works.count)" }) { width in
                ForEach(content.works) { work in
                    Button {
                        viewerPosition = work.id
                        var instantly = Transaction()
                        instantly.disablesAnimations = true
                        withTransaction(instantly) { viewing = work }
                    } label: { GroomerWorkTile(work: work).frame(width: width) }
                        .buttonStyle(BeckonGuardedPlainButtonStyle())
                        .accessibilityLabel(work.caption)
                        .accessibilityHint("Opens the photo.")
                }
            }
        }
    }

    // MARK: Services

    private var services: some View {
        DesignSection(title: "Services", systemImage: "scissors", count: content.services.count, spacing: DesignTokens.Spacing.lg) {
            ForEach(Array(content.services.enumerated()), id: \.element.id) { index, service in
                if index > 0 { DesignRowDivider() }
                CustomerGroomerServiceTile(service: service)
            }
            Text("Reference prices. Your offer sets the final one.")
                .designSupportingText()
        }
    }

    // MARK: Specialties

    private var specialties: some View {
        let groups = Dictionary(grouping: content.specialties, by: \.group)
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
        return DesignSection(title: "Specialties", systemImage: "rosette", spacing: DesignTokens.Spacing.lg) {
            ForEach(groups, id: \.key) { group, signals in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(group.title)
                        .font(DesignTokens.Typography.Expressive.label)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                    BeckonFlowLayout {
                        ForEach(signals) { BeckonMetaChip(text: $0.title, systemImage: "checkmark") }
                    }
                }
            }
        }
    }

    // MARK: Availability

    private var availability: some View {
        DesignSection(title: "Availability", systemImage: "calendar") {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(GroomerAvailabilityWeekday.allCases) { day in dayDot(day) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Works " + GroomerAvailabilityWeekday.allCases.filter(content.isOpen).map(\.title).joined(separator: ", "))
            if let hours = content.hoursText {
                DesignValueRow(title: "Hours", value: hours, systemImage: "clock.fill")
            }
            if let notice = content.noticeDays {
                DesignValueRow(title: "Booking", value: notice == 0 ? "Same-day requests welcome"
                    : "\(notice) day\(notice == 1 ? "" : "s") ahead", systemImage: "bell.fill")
            }
            if let zone = content.windows.first?.timezone {
                DesignValueRow(title: "Time zone", value: zone, systemImage: "globe")
            }
            if content.hoursText == "Varies by day" {
                ForEach(content.windows) { window in
                    DesignValueRow(title: window.weekday.title, value: window.timeRangeSummary, systemImage: "clock")
                }
            }
            if let away = content.timeOff {
                DesignValueRow(title: away.title, value: away.dateSummary, systemImage: "moon.zzz.fill")
            }
        }
    }

    private func dayDot(_ day: GroomerAvailabilityWeekday) -> some View {
        let open = content.isOpen(day)
        return Text(String(day.shortTitle.prefix(1)))
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(open ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(open ? DesignTokens.Colors.customerFill : DesignTokens.Colors.placeholderFill, in: Circle())
    }
}


extension GroomerProfileView where Bar == EmptyView {
    init(profile: MarketplaceGroomerSummary, avatarData: Data? = nil, content: GroomerProfileContent,
         context: GroomerProfileContext? = nil, isFavorite: Bool? = nil, onFavorite: @escaping () -> Void = {},
         onClose: (() -> Void)? = nil) {
        self.init(profile: profile, avatarData: avatarData, content: content, context: context, isFavorite: isFavorite,
            onFavorite: onFavorite, onClose: onClose) { EmptyView() }
    }
}


private extension View {
    /// One figure of the hero: a mint tile, the same size as its neighbours.
    func statTileFrame() -> some View {
        padding(.vertical, DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Colors.customerTint,
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
    }
}


// MARK: A service

/// One service of the groomer: its symbol, its name, how long it takes and which pets it takes, and the reference price.
struct CustomerGroomerServiceTile: View {
    let service: GroomerService
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            DesignIconDisc(systemImage: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(service.title)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text([GroomerProfileContent.durationText(service.durationMinutes),
                      GroomerProfileContent.sizeText(service.acceptedPetSizes), species]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .designSupportingText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 0) {
                Text("from")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Text(service.basePrice.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                    .font(DesignTokens.Typography.Expressive.title)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var species: String {
        let accepted = service.acceptedSpecies ?? []
        switch (accepted.contains(.dog), accepted.contains(.cat)) {
        case (true, true): return ""
        case (true, false): return "Dogs only"
        case (false, true): return "Cats only"
        default: return "Species on request"
        }
    }

    private var symbol: String {
        switch service.serviceType {
        case .fullGroom: "sparkles"
        case .bathAndBrush: "shower.fill"
        case .haircutOnly: "scissors"
        case .nailTrim: "pawprint.fill"
        case .deShedding: "wind"
        case .customRequest: "pencil.and.list.clipboard"
        }
    }
}


// MARK: Portfolio

/// A photo of the groomer's work as a card: the picture, then what it shows and for which kind of pet. The sandbox has no photos, so
/// the picture is a stand-in (`GroomerWorkArt`); a real photo replaces it and nothing else changes.
struct GroomerWorkTile: View {
    let work: GroomerWork
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            GroomerWorkArt(work: work)
                .aspectRatio(4 / 3, contentMode: .fit)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(work.caption)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(typeSize.isAccessibilitySize ? 12 : 2, reservesSpace: !typeSize.isAccessibilitySize)
                    .multilineTextAlignment(.leading)
                // Two tags when both fit the row, the first alone when they do not, so a card never grows a second row of tags and
                // the cards of a row keep one height; at accessibility sizes one under the other.
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        ForEach(work.tags.prefix(2)) { BeckonMetaChip(text: $0.title, systemImage: "pawprint.fill") }
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(work.tags.prefix(2)) { BeckonMetaChip(text: $0.title, systemImage: "pawprint.fill") }
                        }
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(work.tags.prefix(1)) { BeckonMetaChip(text: $0.title, systemImage: "pawprint.fill") }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .beckonLedge(.card)
    }
}


/// The picture of a work: the groomer's photo when there is one, otherwise a coloured stand-in with the kind of pet.
struct GroomerWorkArt: View {
    let work: GroomerWork

    var body: some View {
        ZStack {
            if work.image != nil {
                BeckonModuleImage(data: work.image) { Color.clear }
            } else {
                LinearGradient(colors: [palette.light, palette.strong], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: work.symbol)
                    .font(DesignTokens.Typography.Expressive.workPlaceholder) // a stand-in picture, fixed by design
                    .foregroundStyle(palette.ink)
                Image(systemName: "sparkles")
                    .font(DesignTokens.Typography.Expressive.workSparkle) // a stand-in picture, fixed by design
                    .foregroundStyle(DesignTokens.Colors.ratingStar)
                    .offset(x: 56, y: -40)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var palette: (light: Color, strong: Color, ink: Color) {
        switch work.look {
        case 1: (DesignTokens.Colors.groomerTint, DesignTokens.Colors.groomerFill, DesignTokens.Colors.groomerDeep)
        case 2: (DesignTokens.Colors.iconTileFill, DesignTokens.Colors.border, DesignTokens.Colors.textTertiary)
        default: (DesignTokens.Colors.customerTint, DesignTokens.Colors.customerHeroEnd, DesignTokens.Colors.customerDeep)
        }
    }
}


/// A photo of the portfolio over the whole phone: the photo takes all the room there is, what it shows and the kinds of pet it shows
/// are under it, and a swipe sideways goes to the next one. The bar and the dots are the app's own (S-070), the round button closes it.
/// A plain full-screen cover, and no scroll view inside: the photos are a row moved by one number, the sideways offset, so nothing
/// can be pulled up or down.
struct GroomerWorkViewer: View {
    let works: [GroomerWork]
    @Binding var position: UUID?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The viewer is on screen at once and brings itself in: it fades and scales up, and does the same backwards before it goes.
    @State private var shown = false

    /// How far the finger has pulled the photos sideways, and whether this touch is a sideways one.
    @State private var pull: CGFloat = 0
    @State private var isSideways: Bool?

    private var index: Int { works.firstIndex { $0.id == position } ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            // No "2 of 5" beside the title: the dots at the foot already say how many photos there are and which one this is.
            DesignSheetBar(title: "Portfolio", showsGrabber: false, closeIdentifier: "customer.groomer-profile.close", onClose: close)
            GeometryReader { pager in pages(width: pager.size.width, height: pager.size.height) }
            DesignPageDots(count: works.count, current: index, label: "Photo \(index + 1) of \(works.count)")
                .padding(.vertical, DesignTokens.Spacing.lg)
        }
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .opacity(shown ? 1 : 0)
        .scaleEffect(shown || reduceMotion ? 1 : 0.94)
        .onAppear { withAnimation(animation) { shown = true } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("customer.groomer-profile.photo")
    }

    /// The photos in a row, moved by one number: the sideways offset. They are not in a scroll view, so there is nothing that can
    /// scroll up, and nothing the finger can pull up or down: only the sideways part of a drag is read, and only `x` ever changes.
    private func pages(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(works) { work in
                page(work).frame(width: width, height: height)
            }
        }
        .offset(x: -CGFloat(index) * width + pull)
        .frame(width: width, height: height, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(drag(width: width))
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next photo") { step(1) }
        .accessibilityAction(named: "Previous photo") { step(-1) }
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if isSideways == nil { isSideways = abs(value.translation.width) > abs(value.translation.height) }
                guard isSideways == true else { return }
                // Past the first or the last photo the row gives a third of the finger, then comes back.
                let pastEnd = (index == 0 && value.translation.width > 0) || (index == works.count - 1 && value.translation.width < 0)
                pull = pastEnd ? value.translation.width / 3 : value.translation.width
            }
            .onEnded { value in
                defer { isSideways = nil }
                guard isSideways == true else { return }
                let far = width * 0.25, flick = width * 0.5
                var move = 0
                if value.translation.width < -far || value.predictedEndTranslation.width < -flick { move = 1 }
                if value.translation.width > far || value.predictedEndTranslation.width > flick { move = -1 }
                withAnimation(animation) { pull = 0; step(move) }
            }
    }

    private func step(_ move: Int) {
        let next = min(max(index + move, 0), works.count - 1)
        if works.indices.contains(next) { position = works[next].id }
    }

    private var animation: Animation { reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap }

    private func close() {
        withAnimation(.easeIn(duration: 0.18)) { shown = false }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            var instantly = Transaction()
            instantly.disablesAnimations = true
            withTransaction(instantly) { dismiss() }
        }
    }

    private func page(_ work: GroomerWork) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            GroomerWorkArt(work: work)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
                .beckonLedge(.card)
            Text(work.caption)
                .font(DesignTokens.Typography.Expressive.title)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            BeckonFlowLayout {
                ForEach(work.tags) { BeckonMetaChip(text: $0.title, systemImage: "pawprint.fill") }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.top, DesignTokens.Spacing.md)
    }
}


// MARK: Previews
