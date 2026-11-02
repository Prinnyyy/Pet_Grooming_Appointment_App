#if DEBUG
// The groomer prototype's bookings, conversations and notifications (design): what Home, Schedule, Messages and the bell run on.
// Same idea as GroomerSandbox.swift: real model types, in-memory repositories behind the real stores, dates relative to
// today (appointments sit on tidy wall times in the schedule's time zone, so the day strip always has something on it).
import SwiftUI


// MARK: Data

extension GroomerSandboxFixtures {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .current
        return calendar
    }

    /// An appointment `day` days from today at `hour:minute` in the schedule's time zone, `minutes` long.
    static func slot(day: Int, hour: Int, minute: Int = 0, minutes: Int) -> (start: Date, end: Date) {
        let calendar = calendar
        let today = calendar.startOfDay(for: Date())
        let dayStart = calendar.date(byAdding: .day, value: day, to: today) ?? today
        let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
        return (start, start.addingTimeInterval(Double(minutes) * 60))
    }

    /// The four photos of the fixture portfolio, by id.
    static var portfolioPhotoIDs: [UUID] { (1...4).map { id(850 + $0) } }

    /// The picture of a fixture portfolio photo, drawn: what the repository serves, and what a still is given from its first frame.
    static func portfolioImage(sortOrder: Int) -> Data {
        let symbols = ["pawprint.fill", "scissors", "sparkles", "heart.fill"]
        return imageData(symbol: symbols[abs(sortOrder) % symbols.count])
    }

    /// A coral picture with a symbol on it: the sandbox's profile photo and work photos, drawn here so nothing is downloaded.
    static func imageData(symbol: String) -> Data {
        let size = CGSize(width: 240, height: 240)
        return UIGraphicsImageRenderer(size: size).pngData { context in
            UIColor(red: 1, green: 0.93, blue: 0.91, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let configuration = UIImage.SymbolConfiguration(pointSize: 96, weight: .bold)
            if let image = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(UIColor(red: 0.7, green: 0.23, blue: 0.17, alpha: 1), renderingMode: .alwaysOriginal) {
                image.draw(at: CGPoint(x: (size.width - image.size.width) / 2, y: (size.height - image.size.height) / 2))
            }
        }
    }

    /// No buffers (design): the groomer judges each time, so a booking holds exactly its service. The zeros are the "none" that a time
    /// change and an offer are still written down with.
    static let buffers = try! GroomingTimingBuffers(preparation: 0, cleanup: 0, inboundTravel: 0, outboundTravel: 0)

    /// The groomer's week as the store reads it: nine to five, the weekend off, every day in one time zone (the Schedule needs that).
    static var weekWindows: [GroomerAvailabilityWindow] {
        GroomerAvailabilityWeekday.allCases.map {
            GroomerAvailabilityWindow(id: UUID(), groomerID: groomerID, weekday: $0, startMinutes: 9 * 60, endMinutes: 17 * 60,
                isEnabled: ![.saturday, .sunday].contains($0), timezone: timeZone)
        }
    }

    /// Who said the service took place, when a service is reported and not yet confirmed.
    enum Reporter { case customer, groomer }

    static func booking(_ number: Int, pet: GroomingRequestPetSnapshot, service: GroomingServiceType, start: Date, end: Date,
                        price: Double, status: BookingStatus = .confirmed, mode: GroomingLocationMode = .groomerComesToCustomer,
                        street: String, city: String = "Seattle", zip: String, phase: BookingFulfillmentPhase = .scheduled,
                        startedAt: Date? = nil, reportedBy: Reporter? = nil, reviewText: String? = nil,
                        serviceNotes: String? = nil) -> Booking {
        let startText = GroomingRequestDateFormatting.serverString(from: start)
        let endText = GroomingRequestDateFormatting.serverString(from: end)
        let isDone = status == .completed
        let address = ServiceAgreementAddress(streetAddress: street, addressLine2: nil, city: city, state: "WA", zipCode: zip,
            countryCode: "US")
        let agreement = ServiceAgreement(schemaVersion: 1, requestRevision: id(300 + number), quoteRevision: id(350 + number),
            petID: pet.id, petSnapshot: pet, serviceType: service, serviceNotes: serviceNotes, locationMode: mode, address: address,
            serviceTimeZoneIdentifier: timeZone, scheduledStart: startText, scheduledEnd: endText, priceEstimate: price,
            currency: "USD", capturedAt: iso(hours: -72))
        let customerID = customerIDs[number % customerIDs.count]
        return Booking(id: id(600 + number), requestID: id(250 + number), offerID: id(550 + number), customerID: customerID,
            groomerID: groomerID, scheduledStart: startText, scheduledEnd: endText, priceEstimate: price, status: status,
            cancelledBy: status == .cancelledByCustomer ? customerID : nil,
            cancelledAt: status == .cancelledByCustomer ? iso(hours: -5) : nil,
            completedAt: isDone ? endText : nil, completedBy: isDone ? groomerID : nil, createdAt: iso(hours: -72),
            updatedAt: iso(hours: -2),
            review: reviewText.map { BookingReview(id: id(900 + number), bookingID: id(600 + number), customerID: customerID,
                groomerID: groomerID, rating: 5, content: $0, createdAt: iso(hours: -20)) },
            serviceType: service, requestPetSnapshot: pet,
            groomerBusinessName: "Fresh Coat Grooming", locationMode: mode,
            customerStreetAddress: street, customerCity: city, customerState: "WA", customerZipCode: zip,
            appliedTimingBuffers: buffers, serviceTimeZoneIdentifier: timeZone, scheduleTimeZoneIdentifier: timeZone,
            occupiedStart: startText, occupiedEnd: endText,
            agreementSnapshot: agreement,
            fulfillment: BookingFulfillment(revision: id(650 + number), phase: isDone ? .completed
                : status == .cancelledByCustomer ? .cancelled : phase, basis: "participant_confirmed",
                actualStartedAt: startedAt.map(GroomingRequestDateFormatting.serverString(from:)) ?? (isDone ? startText : nil),
                actualEndedAt: isDone ? endText : nil, petReleaseAt: nil, resourceReleaseAt: nil,
                reportedOutcome: reportedBy == nil ? nil : "completion",
                reportedBy: reportedBy.map { $0 == .groomer ? groomerID : customerID }, reportedAt: reportedBy == nil ? nil : iso(hours: -1),
                reportPreviousPhase: reportedBy == nil ? nil : "in_service",
                reportNote: reportedBy == nil ? nil : "Grooming finished; ready for pickup."))
    }

    /// The groomer's bookings: the next days, one done yesterday, one cancelled. `busyDay` adds a service under way now and one
    /// later today, so the schedule opens on today with a Complete button.
    static func bookings(busyDay: Bool = false) -> [Booking] {
        let cooper = booking(1, pet: pet(11, name: "Cooper", breed: "Beagle", size: "S", weight: 24, temperament: "Friendly"),
            service: .nailTrim, start: slot(day: 1, hour: 9, minutes: 30).start, end: slot(day: 1, hour: 9, minutes: 30).end,
            price: 25, street: "21 Birch Lane", zip: "98103")
        let daisy = booking(2, pet: pet(12, name: "Daisy", breed: "Maltese", size: "XS", weight: 7, temperament: "Shy"),
            service: .bathAndBrush, start: slot(day: 1, hour: 11, minutes: 60).start, end: slot(day: 1, hour: 11, minutes: 60).end,
            price: 55, mode: .customerComesToGroomer, street: "123 Pine Street", zip: "98101")
        let bella = booking(3, pet: pet(6, name: "Bella", breed: "Golden Retriever", size: "L", weight: 62, temperament: "Friendly",
            notes: "Feathers tangle behind the ears. Likes the table lowered.", medical: "Mild hip arthritis: keep standing time short.",
            coat: "Double coat", birthday: "2019-05-02"),
            service: .fullGroom, start: slot(day: 2, hour: 10, minutes: 120).start, end: slot(day: 2, hour: 10, minutes: 120).end,
            price: 110, street: "77 Lakeview Drive", zip: "98115",
            serviceNotes: "Please use the side gate; Bella is nervous at the front door.")
        let oscar = booking(4, pet: pet(13, name: "Oscar", breed: "Corgi", size: "M", weight: 26, temperament: "Playful"),
            service: .fullGroom, start: slot(day: 4, hour: 14, minutes: 120).start, end: slot(day: 4, hour: 14, minutes: 120).end,
            price: 95, street: "5 Cedar Court", zip: "98107")
        let milo = booking(5, pet: pet(7, name: "Milo", breed: "Shih Tzu", size: "S", weight: 11, temperament: "Gentle"),
            service: .bathAndBrush, start: slot(day: -1, hour: 13, minutes: 90).start, end: slot(day: -1, hour: 13, minutes: 90).end,
            price: 55, status: .completed, street: "3 Cedar Lane", zip: "98107")
        let luna = booking(6, pet: pet(3, name: "Luna", breed: "Miniature Poodle", size: "S", weight: 12, temperament: "Playful"),
            service: .haircutOnly, start: slot(day: 3, hour: 11, minutes: 90).start, end: slot(day: 3, hour: 11, minutes: 90).end,
            price: 70, status: .cancelledByCustomer, street: "55 Alder Ave", zip: "98103")
        guard busyDay else { return [cooper, daisy, bella, oscar, milo, luna] }
        let now = Date()
        let underway = booking(7, pet: pet(14, name: "Rosie", breed: "Cocker Spaniel", size: "M", weight: 28, temperament: "Calm",
            notes: "Sensitive around the ears; keep the dryer low.", coat: "Wavy coat", birthday: "2021-06-12"),
            service: .fullGroom, start: now.addingTimeInterval(-40 * 60), end: now.addingTimeInterval(80 * 60), price: 95,
            street: "88 Maple Court", zip: "98109", phase: .inService, startedAt: now.addingTimeInterval(-38 * 60))
        let later = booking(8, pet: pet(15, name: "Teddy", breed: "Cavapoo", size: "S", weight: 15, temperament: "Playful",
            notes: "Wriggles on the table; short breaks help.", coat: "Curly coat", birthday: "2024-03-20"),
            service: .bathAndBrush, start: now.addingTimeInterval(3 * 3600), end: now.addingTimeInterval(4 * 3600), price: 55,
            mode: .customerComesToGroomer, street: "123 Pine Street", zip: "98101")
        // A bath done this morning, so the page has something behind it as well as under way and ahead.
        let earlier = booking(9, pet: pet(16, name: "Nala", breed: "Labrador Retriever", size: "L", weight: 66, temperament: "Friendly"),
            service: .bathAndBrush, start: now.addingTimeInterval(-4.5 * 3600), end: now.addingTimeInterval(-3.5 * 3600), price: 65,
            status: .completed, street: "14 Willow Way", zip: "98105")
        return [earlier, underway, later, cooper, daisy, bella, oscar, milo, luna]
    }

    static func conversations(for bookings: [Booking]) -> [ChatConversation] {
        func conversation(_ booking: Booking, number: Int, last: String, fromGroomer: Bool, hoursAgo: Double) -> ChatConversation {
            ChatConversation(id: id(700 + number), customerID: booking.customerID, groomerID: groomerID,
                latestBookingID: booking.id, latestRequestID: booking.requestID, scheduledStart: booking.scheduledStart,
                scheduledEnd: booking.scheduledEnd, priceEstimate: booking.priceEstimate, bookingStatus: booking.status,
                completedAt: booking.completedAt, groomerBusinessName: booking.groomerBusinessName,
                latestMessageSenderID: fromGroomer ? groomerID : booking.customerID,
                latestMessageCreatedAt: iso(hours: -hoursAgo), latestMessageBody: last, createdAt: iso(hours: -72),
                updatedAt: iso(hours: -hoursAgo), serviceTimeZoneIdentifier: timeZone)
        }
        let byPet = Dictionary(uniqueKeysWithValues: bookings.compactMap { booking in
            booking.requestPetSnapshot.map { ($0.name, booking) }
        })
        return [
            byPet["Bella"].map { conversation($0, number: 1, last: "Thank you! Is there parking on your street?", fromGroomer: false, hoursAgo: 1) },
            byPet["Cooper"].map { conversation($0, number: 2, last: "See you at 9. I will bring the quiet clippers.", fromGroomer: true, hoursAgo: 6) },
            byPet["Milo"].map { conversation($0, number: 3, last: "Milo was wonderful. Thanks for the careful trim!", fromGroomer: false, hoursAgo: 20) },
        ].compactMap { $0 }
    }

    static func messages(for conversation: ChatConversation, booking: Booking?) -> [ChatMessage] {
        let name = booking?.requestPetSnapshot?.name ?? "your pet"
        func message(_ n: Int, from sender: UUID, _ body: String, hoursAgo: Double) -> ChatMessage {
            ChatMessage(id: id(800 + Int(conversation.id.uuidString.prefix(8))! * 10 + n), conversationID: conversation.id,
                senderID: sender, kind: .text, body: body, booking: nil, createdAt: iso(hours: -hoursAgo))
        }
        var items = [
            message(1, from: groomerID, "Hi! Your booking for \(name) is confirmed. Anything I should know before I arrive?", hoursAgo: 48),
            message(2, from: conversation.customerID, "Thanks! \(name) is a little nervous with dryers.", hoursAgo: 40),
            message(3, from: groomerID, "No problem, I will keep the dryer low and take breaks.", hoursAgo: 39),
        ]
        if let booking {
            items.append(ChatMessage(id: id(790 + Int(conversation.id.uuidString.prefix(8))!), conversationID: conversation.id,
                senderID: groomerID, kind: .bookingCard, body: nil, booking: booking, createdAt: iso(hours: -38)))
        }
        if let last = conversation.latestMessageBody, let sender = conversation.latestMessageSenderID {
            items.append(message(4, from: sender, last, hoursAgo: 1))
        }
        return items
    }

    static func notifications(for bookings: [Booking], matches: [GroomerMatchedRequest]) -> [GroomerNotification] {
        var items: [GroomerNotification] = []
        if let mochi = matches.first {
            items.append(GroomerNotification(id: id(900), groomerID: groomerID, kind: .newMatch, title: "New request matches your services",
                body: "A \(mochi.request.serviceType.title.lowercased()) for \(mochi.request.petSnapshot.name) in \(mochi.request.city).",
                isRead: false, createdAt: iso(hours: -1), readAt: nil, relatedRequestID: mochi.request.id, relatedBookingID: nil,
                relatedOfferID: nil))
        }
        if let bella = bookings.first(where: { $0.requestPetSnapshot?.name == "Bella" }) {
            items.append(GroomerNotification(id: id(901), groomerID: groomerID, kind: .offerAccepted, title: "Your offer was accepted",
                body: "Bella's owner booked your \(bella.appointmentServiceTitle.lowercased()).", isRead: false, createdAt: iso(hours: -3),
                readAt: nil, relatedRequestID: bella.requestID, relatedBookingID: bella.id, relatedOfferID: bella.offerID))
            items.append(GroomerNotification(id: id(902), groomerID: groomerID, kind: .newMessage, title: "New message",
                body: "Thank you! Is there parking on your street?", isRead: false, createdAt: iso(hours: -1), readAt: nil,
                relatedRequestID: nil, relatedBookingID: bella.id, relatedOfferID: nil, relatedConversationID: id(701)))
        }
        if let luna = bookings.first(where: { $0.status == .cancelledByCustomer }) {
            items.append(GroomerNotification(id: id(903), groomerID: groomerID, kind: .bookingCancelledByCustomer,
                title: "A booking was cancelled", body: "Luna's owner cancelled the \(luna.appointmentServiceTitle.lowercased()).",
                isRead: true, createdAt: iso(hours: -5), readAt: iso(hours: -4), relatedRequestID: luna.requestID,
                relatedBookingID: luna.id, relatedOfferID: nil))
        }
        return items
    }
}


// MARK: Repositories

/// The groomer's bookings, from memory. Starting, completing and cancelling work (the fulfillment state moves, nothing else).
@MainActor
final class GroomerSandboxBookingRepository: BookingRepository {
    private let boundary: GroomerSandboxBoundary
    var items: [Booking]
    private var fulfillmentResults: [UUID: BookingFulfillmentResult] = [:]
    private var events: [BookingFulfillmentEvent] = []

    init(bookings: [Booking], boundary: GroomerSandboxBoundary) {
        items = bookings
        self.boundary = boundary
    }

    func bookings(participantID: UUID, role: UserRole) async throws -> [Booking] {
        try await boundary.check()
        return items
    }

    func bookings(bookingIDs: [UUID]) async throws -> [Booking] {
        try await boundary.check()
        return items.filter { bookingIDs.contains($0.id) }
    }

    func bookings(participantID: UUID, role: UserRole, interval: DateInterval, page: ListPageRequest) async throws -> ListPage<Booking> {
        try await boundary.check()
        let inside = items.filter { booking in
            guard let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
                  let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd) else { return false }
            return start < interval.end && end > interval.start && !booking.status.isCancellation
        }
        return ListPage(items: inside, request: page, hasMore: false)
    }

    func upcomingBookings(participantID: UUID, role: UserRole, now: Date, limit: Int) async throws -> [Booking] {
        try await boundary.check()
        return Array(items.filter {
            $0.groomerID == participantID && $0.status == .confirmed &&
            (GroomingRequestDateFormatting.parsedDate(from: $0.scheduledEnd) ?? .distantPast) >= now
        }.sortedByScheduledStart(ascending: true).prefix(limit))
    }

    func nearestBooking(participantID: UUID, role: UserRole, now: Date) async throws -> Booking? {
        try await boundary.check()
        return items.filter { $0.status == .confirmed && (GroomingRequestDateFormatting.parsedDate(from: $0.scheduledEnd) ?? .distantPast) > now }
            .sortedByScheduledStart(ascending: true).first
    }

    func reminderSnapshot(participantID: UUID, role: UserRole) async throws -> AppointmentReminderSnapshot {
        try await boundary.check()
        return AppointmentReminderSnapshot(participantID: participantID, role: role, asOf: GroomerSandboxFixtures.iso(hours: 0),
            horizonEnd: GroomerSandboxFixtures.iso(hours: 168), complete: true, bookings: [])
    }

    func acceptOffer(offerID: UUID) async throws -> AcceptGroomerOfferResult { throw BookingRepositoryError.notAllowed }

    func cancelBooking(bookingID: UUID) async throws -> CancelBookingResult {
        try await boundary.check()
        let time = GroomerSandboxFixtures.iso(hours: 0)
        items = items.map { $0.id == bookingID ? $0.replacing(status: .cancelledByGroomer, cancelledBy: GroomerSandboxFixtures.groomerID,
            cancelledAt: time) : $0 }
        return CancelBookingResult(bookingID: bookingID, bookingStatus: .cancelledByGroomer, cancelledTimestamp: time,
            cancelledBy: GroomerSandboxFixtures.groomerID)
    }

    func completeBooking(bookingID: UUID) async throws -> CompleteBookingResult {
        try await boundary.check()
        let time = GroomerSandboxFixtures.iso(hours: 0)
        items = items.map { $0.id == bookingID ? $0.replacing(status: .completed, cancelledBy: nil, cancelledAt: nil, completedAt: time,
            completedBy: GroomerSandboxFixtures.groomerID) : $0 }
        return CompleteBookingResult(bookingID: bookingID, bookingStatus: .completed, completedTimestamp: time,
            completedBy: GroomerSandboxFixtures.groomerID)
    }

    func createReview(bookingID: UUID, draft: BookingReviewDraft) async throws -> CreateReviewResult {
        throw BookingRepositoryError.notAllowed
    }

    func fulfillmentEvents(bookingID: UUID) async throws -> [BookingFulfillmentEvent] {
        try await boundary.check()
        return events
    }

    func fulfillmentOperation(id: UUID) async throws -> BookingFulfillmentResult? {
        try await boundary.check()
        return fulfillmentResults[id]
    }

    func mutateFulfillment(_ operation: BookingFulfillmentOperation) async throws -> BookingFulfillmentResult {
        try await boundary.check()
        if let known = fulfillmentResults[operation.id] { return known }
        guard let index = items.firstIndex(where: { $0.id == operation.bookingID }) else { throw BookingRepositoryError.bookingNotFound }
        let now = GroomerSandboxFixtures.iso(hours: 0)
        var booking = items[index]
        let phase: BookingFulfillmentPhase = switch operation.action {
        case .start: .inService
        case .complete, .confirmCompletion: .completed
        case .cancel, .confirmStop: .cancelled
        case .closeElapsed: .unfulfilled
        case .withdrawReport: .scheduled
        default: .outcomeReported
        }
        switch phase {
        case .completed:
            booking = booking.replacing(status: .completed, cancelledBy: nil, cancelledAt: nil, completedAt: now,
                completedBy: GroomerSandboxFixtures.groomerID)
        case .cancelled:
            booking = booking.replacing(status: .cancelledByGroomer, cancelledBy: GroomerSandboxFixtures.groomerID, cancelledAt: now)
        default: break
        }
        let revision = UUID()
        let started = booking.fulfillment?.actualStartedAt ?? (phase == .inService ? now : nil)
        booking.fulfillment = BookingFulfillment(revision: revision, phase: phase, basis: "participant_confirmed",
            actualStartedAt: started, actualEndedAt: phase == .completed ? now : nil, petReleaseAt: nil, resourceReleaseAt: nil,
            reportedOutcome: phase == .outcomeReported ? "completion" : nil,
            reportedBy: phase == .outcomeReported ? GroomerSandboxFixtures.groomerID : nil,
            reportedAt: phase == .outcomeReported ? now : nil, reportPreviousPhase: phase == .outcomeReported ? "in_service" : nil,
            reportNote: operation.note)
        items[index] = booking
        let receipt = BookingFulfillmentReceipt(id: UUID(), operationID: operation.id, bookingID: operation.bookingID,
            action: operation.action, resultRevision: revision, recordedAt: now)
        events.append(BookingFulfillmentEvent(id: receipt.id, actorID: GroomerSandboxFixtures.groomerID, action: operation.action,
            note: operation.note, recordedAt: now))
        let result = BookingFulfillmentResult(receipt: receipt, booking: booking, replayed: false)
        fulfillmentResults[operation.id] = result
        return result
    }

    func reschedule(bookingID: UUID) async throws -> BookingRescheduleResult {
        try await boundary.check()
        guard let booking = items.first(where: { $0.id == bookingID }) else { throw BookingRepositoryError.bookingNotFound }
        return BookingRescheduleResult(booking: booking, proposal: nil, receipt: nil)
    }
}


/// The groomer's conversations, from memory; a sent message answers at once and goes to any open thread.
@MainActor
final class GroomerSandboxChatRepository: ChatRepository {
    private let boundary: GroomerSandboxBoundary
    private var conversationItems: [ChatConversation]
    private var messageItems: [UUID: [ChatMessage]]
    private var streams: [UUID: AsyncStream<ChatMessage>.Continuation] = [:]

    init(conversations: [ChatConversation], bookings: [Booking], boundary: GroomerSandboxBoundary) {
        self.boundary = boundary
        conversationItems = conversations
        messageItems = Dictionary(uniqueKeysWithValues: conversations.map { conversation in
            (conversation.id, GroomerSandboxFixtures.messages(for: conversation,
                booking: bookings.first { $0.id == conversation.latestBookingID }))
        })
    }

    func conversations(participantID: UUID, role: UserRole) async throws -> [ChatConversation] {
        try await boundary.check()
        return conversationItems
    }

    func conversation(id: UUID, participantID: UUID, role: UserRole) async throws -> ChatConversation {
        try await boundary.check()
        guard let found = conversationItems.first(where: { $0.id == id }) else { throw ChatRepositoryError.conversationNotFound }
        return found
    }

    func conversation(customerID: UUID, groomerID: UUID, role: UserRole) async throws -> ChatConversation {
        try await boundary.check()
        guard let found = conversationItems.first(where: { $0.customerID == customerID }) else { throw ChatRepositoryError.conversationNotFound }
        return found
    }

    func messages(conversationID: UUID) async throws -> [ChatMessage] {
        try await boundary.check()
        return messageItems[conversationID] ?? []
    }

    func sendMessage(conversationID: UUID, senderID: UUID, body: String) async throws -> ChatMessage {
        try await boundary.check()
        let message = ChatMessage(id: UUID(), conversationID: conversationID, senderID: senderID, kind: .text, body: body,
            booking: nil, createdAt: GroomerSandboxFixtures.iso(hours: 0))
        messageItems[conversationID, default: []].append(message)
        streams.values.forEach { $0.yield(message) }
        return message
    }

    func messageEvents(conversationID: UUID) async throws -> AsyncStream<ChatMessage> {
        try await boundary.check()
        let token = UUID()
        return AsyncStream { continuation in
            streams[token] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.streams[token] = nil }
            }
        }
    }
}


@MainActor
final class GroomerSandboxNotificationRepository: GroomerNotificationRepository {
    private let boundary: GroomerSandboxBoundary
    private var items: [GroomerNotification]

    init(notifications: [GroomerNotification], boundary: GroomerSandboxBoundary) {
        items = notifications
        self.boundary = boundary
    }

    func notifications(groomerID: UUID) async throws -> [GroomerNotification] {
        try await boundary.check()
        return items
    }

    func markRead(notificationID: UUID) async throws -> GroomerNotification {
        try await boundary.check()
        guard let index = items.firstIndex(where: { $0.id == notificationID }) else {
            throw GroomerNotificationRepositoryError.notificationNotFound
        }
        items[index] = items[index].replacingReadState(isRead: true, readAt: GroomerSandboxFixtures.iso(hours: 0))
        return items[index]
    }

    func markAllRead(groomerID: UUID) async throws -> [GroomerNotification] {
        try await boundary.check()
        items = items.map { $0.replacingReadState(isRead: true, readAt: GroomerSandboxFixtures.iso(hours: 0)) }
        return items
    }
}


/// Reminders that always get scheduled, so the Schedule is shown without its "reminders are off" row (the row is the customer
/// prototype's `GroomingReminderNotice`, shown when the system refuses).
struct GroomerReminders: AppointmentReminderScheduling {
    func syncReminders(for bookings: [Booking], role: UserRole) async -> AppointmentReminderSyncResult {
        .scheduled(count: bookings.count)
    }
    func cancelReminder(for bookingID: UUID, role: UserRole) async {}
}


/// The profile snapshot Home keeps between launches, in memory (the real one is a file under the app's support folder).
@MainActor
final class GroomerSnapshotCache: ProfileSnapshotCaching {
    private var stored: [UUID: ProfileSnapshot] = [:]
    func snapshot(userID: UUID) -> ProfileSnapshot? { stored[userID] }
    func save(_ snapshot: ProfileSnapshot) { stored[snapshot.userID] = snapshot }
    func remove(userID: UUID) { stored[userID] = nil }
}
#endif
