import SwiftUI
import Combine

/// Grooming workspace using the shell navigation stack and existing account-scoped stores.
struct GroomerGroomingView: View {
    private static let cardMargin = DesignTokens.Layout.pageHorizontalInset
    private typealias Section = GroomerGroomingWorkspace.Section
    private typealias MatchLocation = GroomerGroomingWorkspace.MatchLocation
    @State private var locationFilter = MatchLocation.all
    private enum Filter: String, CaseIterable {
        case waiting = "Waiting", accepted = "Accepted", closed = "Closed"
        var symbol: String {
            switch self { case .waiting: "clock"; case .accepted: "checkmark.seal"; case .closed: "archivebox" }
        }
    }
    private enum Route: Hashable { case match(UUID), offer(GroomerOfferListItem), booking(UUID) }
    private enum BookingFilter: String, CaseIterable {
        case active = "Active", closed = "Closed"
        var symbol: String { self == .active ? "calendar" : "archivebox" }
    }
    @State private var bookingFilter = BookingFilter.active
    @State private var positions: [String: ScrollPosition] = [:]
    let workspace: GroomerGroomingWorkspace
    @Binding var path: NavigationPath
    @Binding var externalRoute: GroomerRequestsRoute
    @State private var section = Section.matches
    @State private var filter = Filter.waiting
    @State private var sentID: UUID?
    @State private var currentRoute: Route?
    @State private var now = Date()
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var session: GroomerGroomingSession { workspace.session }

    private var listID: String {
        switch section {
        case .matches: "Matches/" + locationFilter.rawValue
        case .offers: "Offers/" + filter.rawValue
        case .bookings: "Bookings/" + bookingFilter.rawValue
        }
    }

    private static let pagingMotion = Animation.easeOut(duration: 0.22)
    private var pageCount: Int { section == .bookings ? 2 : 3 }
    private var pageSelection: Binding<Int> {
        Binding(get: {
            switch section {
            case .matches: MatchLocation.allCases.firstIndex(of: locationFilter) ?? 0
            case .offers: Filter.allCases.firstIndex(of: filter) ?? 0
            case .bookings: BookingFilter.allCases.firstIndex(of: bookingFilter) ?? 0
            }
        }, set: { index in
            guard (0..<pageCount).contains(index) else { return }
            switch section {
            case .matches: locationFilter = MatchLocation.allCases[index]
            case .offers: filter = Filter.allCases[index]
            case .bookings: bookingFilter = BookingFilter.allCases[index]
            }
        })
    }

    private func location(at index: Int) -> GroomingLocationMode? {
        switch MatchLocation.allCases[index] {
        case .all: nil
        case .studio: .customerComesToGroomer
        case .home: .groomerComesToCustomer
        }
    }

    private func pageKey(at index: Int) -> String {
        switch section {
        case .matches: "matches/" + (location(at: index)?.rawValue ?? "all")
        case .offers: "offers/" + Filter.allCases[index].rawValue.lowercased()
        case .bookings: "bookings/" + BookingFilter.allCases[index].rawValue.lowercased()
        }
    }

    private var pages: some View {
        TabView(selection: pageSelection) {
            ForEach(0..<pageCount, id: \.self) { index in
                workspaceList(index: index).tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .id(section)
        .accessibilityIdentifier("groomer.grooming.pages")
    }

    private func position(for key: String) -> Binding<ScrollPosition> {
        Binding(get: { positions[key] ?? ScrollPosition() }, set: { positions[key] = $0 })
    }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                if !typeSize.isAccessibilitySize {
                    controls.padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
                }
                pages.beckonEntrance(2)
            }
            .padding(.top, DesignTokens.Layout.pageTopInset)
            .beckonEntranceClock()
            .background { BeckonExpressiveBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
            .beckonNavigationDestination(for: Route.self) { route in
                switch route {
                case .match(let id):
                    GroomerGroomingRequestDetail(target: .match(id), workspace: workspace) {
                        push(.booking($0.id))
                    }
                    .onChange(of: session.requests.authorizedDetail?.id, initial: true) { _, opened in
                        if opened == id, let row = session.requests.authorizedDetail { workspace.reflectOpenedMatch(row) }
                    }

                case .offer(let item):
                    GroomerGroomingOfferPage(selected: item, workspace: workspace, isCurrent: currentRoute == route, justSent: sentID == item.id,
                        viewWaiting: {
                            sentID = nil
                            section = .offers
                            filter = .waiting
                            path = NavigationPath(); currentRoute = nil
                        }, openBooking: { push(.booking($0)) },
                        onWithdrawn: {
                            section = .matches
                            locationFilter = .all
                            path = NavigationPath(); currentRoute = nil
                        }, makeOffer: { match in
                            section = .matches
                            locationFilter = .all
                            path = NavigationPath()
                            push(.match(match.id))
                        })
                        .onAppear { currentRoute = route }
                case .booking(let id):
                    GroomerVisitBookingDetail(bookingID: id, store: session.bookings, chat: session.chat, decision: workspace.bookingDecision)
                        .onChange(of: currentRoute == route ? workspace.displayedBookingUpdates(id, now: now) : [], initial: true) {
                            _, updates in workspace.didDisplay(updates)
                        }
                }
            }
        }
        .onReceive(tick) { now = $0 }
        .task(id: listID) {
            let location: GroomingLocationMode? = switch locationFilter {
            case .all: nil; case .studio: .customerComesToGroomer; case .home: .groomerComesToCustomer
            }
            workspace.select(location: location, offers: filter.rawValue.lowercased(), bookingsClosed: bookingFilter == .closed)
            if !workspace.loaded.contains(section) { await workspace.refresh(section) }
        }
        .onChange(of: path.count) { previous, count in
            guard previous > 0, count == 0 else { return }
            currentRoute = nil
            Task { await workspace.refresh(section) }
        }
        .onChange(of: externalRoute) { _, _ in Task { await openExternalRoute() } }
        .task { await openExternalRoute() }
        .onChange(of: workspace.lastSentOfferID) { _, id in
            guard let id else { return }
            Task {
                await workspace.refresh(.offers)
                await workspace.refresh(.matches)
                guard let item = try? await workspace.offerItem(id: id),
                      case .match(item.offer.matchID) = currentRoute else { return }
                sentID = id
                if !path.isEmpty { path.removeLast() }
                push(.offer(item))
            }
        }
        .environment(\.beckonRole, .groomer)
            .environment(\.groomerVisitAppearance, true)
        .tint(DesignTokens.Colors.textSecondary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.requests.list")
    }

    private func push(_ destination: Route) {
        currentRoute = destination
        path.append(destination)
    }

    private func openExternalRoute() async {
        section = externalRoute.segment == .matches ? .matches : .offers
        if let id = externalRoute.offerID {
            if !workspace.loaded.contains(.offers) { await workspace.refresh(.offers) }
            if let item = try? await workspace.offerItem(id: id) { push(.offer(item)) }
        } else if let id = externalRoute.requestID,
                  let match = try? await session.requests.resolveNotificationRequest(id: id) {
            push(.match(match.id))
        }
    }

    private func workspaceList(index: Int) -> some View {
        let loaded = workspace.hasLoadedPage(pageKey(at: index))
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                if typeSize.isAccessibilitySize { controls.padding(.horizontal, DesignTokens.Layout.pageHorizontalInset) }
                if index == pageSelection.wrappedValue, let error = workspace.errors[section] {
                    Button { Task { await workspace.refresh(section) } } label: {
                        DesignQuietAction(title: error + " Try again", systemImage: "arrow.clockwise")
                    }.buttonStyle(BeckonGuardedPlainButtonStyle(.inline))
                    .padding(.horizontal, Self.cardMargin)
                }
                switch section {
                case .offers: offerList(filter: Filter.allCases[index], loaded: loaded)
                case .matches: matchList(locationFilter: MatchLocation.allCases[index], location: location(at: index), loaded: loaded)
                case .bookings: bookingList(bookingFilter: BookingFilter.allCases[index], loaded: loaded)
                }
                if index == pageSelection.wrappedValue && workspace.hasMore(section) {
                    Button { Task { await workspace.loadMore(section) } } label: {
                        DesignQuietAction(title: "Load more", systemImage: "arrow.down")
                    }.buttonStyle(BeckonGuardedPlainButtonStyle())
                        .padding(.horizontal, Self.cardMargin)
                }
            }
            .scrollTargetLayout()
            .padding(.bottom, DesignTokens.Layout.pageBottomInset)
        }
        .scrollPosition(position(for: pageKey(at: index)))
        .refreshable {
            await workspace.refresh(section)
            await workspace.refreshCardPresentation(section)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            BeckonPageTitle("Grooming").beckonEntrance(0)
            workspaceHeader.beckonEntrance(1)
            switch section {
            case .offers: subTabs(Filter.allCases, selection: $filter, symbol: \.symbol)
            case .bookings: subTabs(BookingFilter.allCases, selection: $bookingFilter, symbol: \.symbol)
            case .matches: subTabs(MatchLocation.allCases, selection: $locationFilter, symbol: \.symbol)
            }
        }
    }

    private var workspaceHeader: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
        return layout {
            ForEach(Section.allCases, id: \.self) { option in
                let selected = section == option
                Button {
                    guard !selected else { return }
                    switch option {
                    case .matches: locationFilter = .all
                    case .offers: filter = .waiting
                    case .bookings: bookingFilter = .active
                    }
                    section = option
                } label: {
                    Text(option.rawValue)
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(selected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                }
                .buttonStyle(BeckonLedgeButtonStyle(selected ? .pill : .card))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("groomer.requests.segment." + option.rawValue.lowercased())
            }
        }
    }

    private func subTabs<Option: RawRepresentable & Hashable>(_ options: [Option], selection: Binding<Option>,
        symbol: KeyPath<Option, String>) -> some View where Option.RawValue == String {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
        return layout {
            ForEach(options, id: \.self) { option in
                let selected = selection.wrappedValue == option
                Button {
                    if !selected {
                        withAnimation(reduceMotion ? nil : Self.pagingMotion) { selection.wrappedValue = option }
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: option[keyPath: symbol])
                            .symbolVariant(selected ? .fill : .none)
                            .font(DesignTokens.Typography.Expressive.labelMuted)
                            .foregroundStyle(selected ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.textSecondary)
                            .padding(DesignTokens.Spacing.xs)
                            .background { if selected { Circle().fill(DesignTokens.Colors.customerTint) } }
                            .accessibilityHidden(true)
                        Text(option.rawValue)
                            .font(DesignTokens.Typography.Expressive.label)
                            .foregroundStyle(selected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                    .anchorPreference(key: GroomingSubtabBounds.self, value: .bounds) {
                        [option.rawValue: $0]
                    }
                    .frame(minWidth: DesignTokens.Metrics.minimumTouchTarget, maxWidth: stacked ? .infinity : nil,
                        alignment: .leading)
                    .contentShape(Rectangle())
                    .animation(nil, value: selected)
                }
                .buttonStyle(GroomingSubtabPressStyle())
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .background(alignment: .bottom) {
            if !stacked { Rectangle().fill(DesignTokens.Colors.borderSoft).frame(height: 1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlayPreferenceValue(GroomingSubtabBounds.self) { anchors in
            GeometryReader { geometry in
                if let anchor = anchors[selection.wrappedValue.rawValue] {
                    let bounds = geometry[anchor]
                    // One persistent indicator moves; labels, symbols and list content do not morph.
                    Capsule().fill(DesignTokens.Colors.customerDeep)
                        .frame(width: bounds.width, height: DesignTokens.Ledge.card)
                        .offset(x: bounds.minX, y: bounds.maxY - DesignTokens.Ledge.card)
                        .animation(reduceMotion ? nil : Self.pagingMotion, value: bounds)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder private func matchList(locationFilter: MatchLocation, location: GroomingLocationMode?, loaded: Bool) -> some View {
        let matches = workspace.cachedMatches(location: location).filter {
            locationFilter.includes($0.request.locationMode) &&
                GroomerRequestStage(.init(matched: $0), now: now).kind == .new
        }
        if matches.isEmpty {
            let message = switch locationFilter { case .all: "No matches yet"; case .studio: "No studio visits"; case .home: "No home visits" }
            listPlaceholder(message, icon: locationFilter.symbol, loaded: loaded).padding(.horizontal, Self.cardMargin)
        } else {
            let unread = matches.filter { $0.match.status == .visible }.count
            listSummary(matches.count, unread: unread)
        }
        ForEach(matches) { match in
            let isUnread = match.match.status == .visible
            listRow(unread: isUnread) {
                GroomerGroomingListCard(model: .workspaceMatch(match, photo: workspace.photo(for: match.request.id), now: now, location: locationFilter),
                    decision: workspace.matchDecision(match, now: now),
                    status: GroomerVisitCardStatus.offer(.init(matched: match), stage: GroomerRequestStage(.init(matched: match), now: now), linked: false)) {
                    push(.match(match.id))
                }
                .task(id: match.request.id) { await workspace.loadPetPhoto(requestID: match.request.id) }
            }
        }
    }

    private func listRow<Content: View>(unread: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, Self.cardMargin)
            .overlay(alignment: .leading) {
                if unread { unreadDot.frame(width: Self.cardMargin).allowsHitTesting(false) }
            }
            .accessibilityValue(unread ? "New update" : "")
    }

    private var unreadDot: some View {
        Circle().fill(DesignTokens.Colors.customerDeep)
            .frame(width: DesignTokens.Metrics.liveDot, height: DesignTokens.Metrics.liveDot)
            .accessibilityHidden(true)
    }

    private func listSummary(_ count: Int, unread: Int) -> some View {
        let noun = switch section {
        case .matches: count == 1 ? "match" : "matches"
        case .offers: count == 1 ? "offer" : "offers"
        case .bookings: count == 1 ? "booking" : "bookings"
        }
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md))
        return layout {
            Text("\(count) \(noun)")
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            if unread > 0 {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    unreadDot
                    Text(unread == 1 ? "1 update" : "\(unread) updates")
                }
                .font(DesignTokens.Typography.Expressive.labelMuted)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
            }
        }
        .monospacedDigit()
        .accessibilityElement(children: .combine)
        .padding(.horizontal, Self.cardMargin)
    }

    private func openOffer(_ item: GroomerOfferListItem) {
        push(.offer(item))
    }

    @ViewBuilder private func offerList(filter: Filter, loaded: Bool) -> some View {
        let groups = GroomerOfferGroups(workspace.cachedOffers(group: filter.rawValue.lowercased()).filter { $0.offer.status != .withdrawnByGroomer }, now: now)
        let entries: [GroomerOfferGroups.Entry] = switch filter {
        case .waiting: (groups.attention + groups.pending).sorted {
            let a = $0.stage.problem?.needsAttention == true
            let b = $1.stage.problem?.needsAttention == true
            return a != b ? a : $0.item.offer.expiresAt < $1.item.offer.expiresAt
        }
        case .accepted: groups.booked.sorted { ($0.item.offer.updatedAt ?? "") > ($1.item.offer.updatedAt ?? "") }
        case .closed: groups.earlier.sorted { ($0.item.offer.updatedAt ?? "") > ($1.item.offer.updatedAt ?? "") }
        }
        let unread = Set(entries.filter { !workspace.offerUpdates($0, now: now).isEmpty }.map(\.id))
        if entries.isEmpty {
            let (title, hint) = switch filter {
            case .waiting: ("No offers awaiting a reply", "New offers appear here while customers decide.")
            case .accepted: ("No accepted offers yet", "Offers accepted by customers appear here.")
            case .closed: ("No closed offers", "Declined and expired offers appear here.")
            }
            listPlaceholder(title, icon: filter.symbol, hint: hint, loaded: loaded)
                .padding(.horizontal, Self.cardMargin)
        } else {
            listSummary(entries.count, unread: unread.count)
        }
        ForEach(entries) { entry in
            let item = entry.item
            let booking = workspace.booking(for: item)
            let decision = workspace.offerDecision(entry)
            let status = decision == nil ? GroomerVisitCardStatus.offer(.init(item: item), stage: entry.stage, linked: booking != nil) : nil
            let note = status?.note
            let photo = booking.flatMap(session.bookings.petPhoto(for:)) ?? workspace.photo(for: item.offer.requestID)
            listRow(unread: unread.contains(item.id)) {
                GroomerGroomingListCard(model: .workspaceOffer(entry, photo: photo, note: note, now: now),
                    customerName: nil, decision: decision, status: status) {
                    openOffer(item)
                }
                .task(id: item.offer.requestID) { await workspace.loadPetPhoto(requestID: item.offer.requestID) }
                .accessibilityIdentifier("groomerVisit.offer." + item.id.uuidString)
            }
        }
    }

    @ViewBuilder private func bookingList(bookingFilter: BookingFilter, loaded: Bool) -> some View {
        let closed = bookingFilter == .closed
        let items = workspace.cachedBookings(closed: closed).filter {
            let stage = GroomerBookingStage($0, now: now)
            return (stage.isClosed || stage.isFinished) == closed
        }.sorted {
            if closed { return GroomerGroomingWorkspace.closedAt($0) > GroomerGroomingWorkspace.closedAt($1) }
            let lhs = workspace.bookingPriority($0, now: now), rhs = workspace.bookingPriority($1, now: now)
            return lhs == rhs ? $0.scheduledStart < $1.scheduledStart : lhs < rhs
        }
        let unread = Set(items.filter { !workspace.bookingUpdates($0, now: now).isEmpty }.map(\.id))
        if items.isEmpty {
            listPlaceholder(closed ? "No closed bookings" : "No active bookings", icon: bookingFilter.symbol,
                hint: closed ? "Completed and cancelled appointments appear here." : "Bookings appear here when a customer accepts an offer.", loaded: loaded)
                .padding(.horizontal, Self.cardMargin)
        } else {
            listSummary(items.count, unread: unread.count)
        }
        ForEach(items) { booking in
            let decision = workspace.bookingDecision(booking, now: now)
            let status = decision == nil ? GroomerVisitCardStatus.booking(booking, stage: GroomerBookingStage(booking, now: now),
                proposal: session.bookings.rescheduleSnapshots[booking.id]?.proposal, now: now) : nil
            let note = status?.note
            listRow(unread: unread.contains(booking.id)) {
                GroomerGroomingListCard(model: .workspaceBooking(booking, closed: closed, photo: session.bookings.petPhoto(for: booking), note: note, now: now),
                    customerName: session.bookings.customerNamesByBookingID[booking.id], decision: decision, status: status) {
                    push(.booking(booking.id))
                }
                .task(id: booking.id.uuidString + booking.updatedAt) {
                    await workspace.loadBookingCard(booking)
                }
            }
        }
    }

    @ViewBuilder private func listPlaceholder(_ title: String, icon: String, hint: String? = nil, loaded: Bool) -> some View {
        if workspace.errors[section] == nil {
            if loaded {
                HStack(spacing: DesignTokens.Spacing.md) {
                    if !typeSize.isAccessibilitySize { DesignIconDisc(systemImage: icon) }
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(title).font(DesignTokens.Typography.Expressive.emphasis).foregroundStyle(DesignTokens.Colors.textPrimary)
                        if let hint { Text(hint).designSupportingText().fixedSize(horizontal: false, vertical: true) }
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .beckonLedge(.card)
                .accessibilityElement(children: .combine)
            } else {
                let label = "Loading " + section.rawValue.lowercased()
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text(section.rawValue).font(DesignTokens.Typography.Expressive.emphasis)
                        .padding(.horizontal, DesignTokens.Spacing.sm).hidden()
                        .overlay { DesignSkeletonLine(font: DesignTokens.Typography.Expressive.emphasis) }
                        .designSkeletonOnPage().designSkeleton(label: nil)
                    GroomerGroomingListCardSkeleton(hasPriceAndStatus: section != .matches, label: label)
                }
            }
        }
    }

}



private extension GroomerGroomingWorkspace.MatchLocation {
    var symbol: String {
        switch self { case .all: "rectangle.stack"; case .studio: "storefront"; case .home: "house" }
    }
}

private struct GroomingSubtabBounds: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

/// Touch-down feedback is immediate; native Button cancellation still protects scrolling.
private struct GroomingSubtabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
    }
}
