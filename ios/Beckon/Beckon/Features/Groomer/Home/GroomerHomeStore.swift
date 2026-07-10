import Foundation
import Observation

nonisolated enum GroomerHomeSection: String, CaseIterable, Equatable, Sendable {
    case profile
    case requests
    case offers
    case bookings
    case availability
}

nonisolated enum GroomerHomeAvailabilityState: Equatable, Sendable {
    case available
    case paused
    case needsSchedule
    case unavailable
}

struct GroomerHomeLoadIssue: Equatable, Identifiable {
    let section: GroomerHomeSection
    let title: String
    let message: String

    var id: GroomerHomeSection { section }

    var feedbackError: BeckonGlobalFeedbackError {
        BeckonGlobalFeedbackError(
            scope: .module("groomer.home.\(section.rawValue)"),
            sourceKey: "groomer-home.\(section.rawValue).load",
            title: title,
            message: message
        )
    }
}

@MainActor
@Observable
final class GroomerHomeStore {
    private let groomerID: UUID
    private let profileRepository: any GroomerProfileRepository
    private let requestRepository: any GroomerRequestRepository
    private let bookingRepository: any BookingRepository
    private let profileSnapshotCache: any ProfileSnapshotCaching
    private let now: () -> Date
    private let debugRecorder: AppDebugEventRecorder?

    private(set) var profile: GroomerProfile?
    private(set) var businessName: String
    private(set) var avatarPhotoData: Data?
    private(set) var newMatchCount = 0
    private(set) var pendingOfferCount = 0
    private(set) var bookings: [Booking] = []
    private(set) var nextBookingPhotoData: Data?
    private(set) var availabilityWindows: [GroomerAvailabilityWindow] = []
    private(set) var issues: [GroomerHomeLoadIssue] = []
    private(set) var isLoading = false

    let greetingName: String

    init(
        groomerID: UUID,
        displayName: String,
        profileRepository: any GroomerProfileRepository,
        requestRepository: any GroomerRequestRepository,
        bookingRepository: any BookingRepository,
        profileSnapshotCache: any ProfileSnapshotCaching = FileProfileSnapshotCache.shared,
        now: @escaping () -> Date = Date.init,
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.groomerID = groomerID
        self.profileRepository = profileRepository
        self.requestRepository = requestRepository
        self.bookingRepository = bookingRepository
        self.profileSnapshotCache = profileSnapshotCache
        self.now = now
        self.debugRecorder = debugRecorder

        let cachedSnapshot = profileSnapshotCache.snapshot(userID: groomerID)
        greetingName = Self.normalized(displayName) ?? "Groomer"
        businessName = Self.normalized(cachedSnapshot?.displayName) ?? "Your Grooming Business"
        avatarPhotoData = cachedSnapshot?.avatarData
    }

    var nextBooking: Booking? {
        let referenceDate = now()
        return bookings
            .filter { booking in
                guard booking.status == .confirmed else { return false }
                let endDate = GroomingRequestDateFormatting.parsedDate(
                    from: booking.scheduledEnd
                )
                return endDate.map { $0 >= referenceDate } ?? false
            }
            .sorted { lhs, rhs in
                let lhsDate = GroomingRequestDateFormatting.parsedDate(
                    from: lhs.scheduledStart
                ) ?? .distantFuture
                let rhsDate = GroomingRequestDateFormatting.parsedDate(
                    from: rhs.scheduledStart
                ) ?? .distantFuture
                if lhsDate == rhsDate {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhsDate < rhsDate
            }
            .first
    }

    var availabilityState: GroomerHomeAvailabilityState {
        guard let profile else { return .unavailable }
        guard profile.isActive else { return .paused }
        return availabilityWindows.contains(where: { $0.isEnabled })
            ? .available
            : .needsSchedule
    }

    func load() async {
        guard !isLoading else { return }

        let startedAt = Date()
        isLoading = true
        issues = []
        defer { isLoading = false }
        record("start", startedAt: startedAt)

        await loadProfile()
        await loadAvailability()
        await loadRequests()
        await loadOffers()
        await loadBookings()
        await loadNextBookingPhoto()

        record(
            "success",
            startedAt: startedAt,
            metadata: [
                "bookingCount": "\(bookings.count)",
                "issueCount": "\(issues.count)",
                "newMatchCount": "\(newMatchCount)",
                "pendingOfferCount": "\(pendingOfferCount)",
            ]
        )
    }

    private func loadProfile() async {
        do {
            let loadedProfile = try await profileRepository.profile(groomerID: groomerID)
            profile = loadedProfile
            businessName = Self.normalized(loadedProfile.businessName) ?? businessName

            if let avatarPath = Self.normalized(loadedProfile.avatarPath) {
                do {
                    avatarPhotoData = try await profileRepository.avatarPhotoData(
                        storagePath: avatarPath
                    )
                } catch GroomerProfileRepositoryError.cancelled {
                    return
                } catch where AppDebugErrorClassifier.isCancellation(error) {
                    return
                } catch {
                    recordImageFallback(error: error, source: "profile-avatar")
                }
            }

            profileSnapshotCache.save(
                ProfileSnapshot(
                    userID: groomerID,
                    displayName: businessName,
                    detailText: Self.profileDetailText(loadedProfile),
                    avatarData: avatarPhotoData
                )
            )
        } catch GroomerProfileRepositoryError.cancelled {
            return
        } catch let error as GroomerProfileRepositoryError {
            addIssue(
                .profile,
                title: "Profile Unavailable",
                message: message(for: error, section: .profile),
                error: error
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            addIssue(
                .profile,
                title: "Profile Unavailable",
                message: message(for: .unavailable, section: .profile),
                error: error
            )
        }
    }

    private func loadAvailability() async {
        do {
            availabilityWindows = try await profileRepository.availabilityWindows(
                groomerID: groomerID
            )
        } catch GroomerProfileRepositoryError.cancelled {
            return
        } catch let error as GroomerProfileRepositoryError {
            addIssue(
                .availability,
                title: "Availability Unavailable",
                message: message(for: error, section: .availability),
                error: error
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            addIssue(
                .availability,
                title: "Availability Unavailable",
                message: message(for: .unavailable, section: .availability),
                error: error
            )
        }
    }

    private func loadRequests() async {
        do {
            let page = try await requestRepository.matchedRequests(
                groomerID: groomerID,
                page: .first
            )
            newMatchCount = page.items.filter { matchedRequest in
                matchedRequest.request.status.isOpenForOffers
                    && (matchedRequest.match.status == .visible
                        || matchedRequest.match.status == .viewed)
            }.count
        } catch GroomerRequestRepositoryError.cancelled {
            return
        } catch let error as GroomerRequestRepositoryError {
            addIssue(
                .requests,
                title: "Requests Unavailable",
                message: requestMessage(for: error),
                error: error
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            addIssue(
                .requests,
                title: "Requests Unavailable",
                message: requestMessage(for: .unavailable),
                error: error
            )
        }
    }

    private func loadOffers() async {
        do {
            let page = try await requestRepository.offers(
                groomerID: groomerID,
                page: .first
            )
            pendingOfferCount = page.items.filter { $0.offer.status == .pending }.count
        } catch GroomerRequestRepositoryError.cancelled {
            return
        } catch let error as GroomerRequestRepositoryError {
            addIssue(
                .offers,
                title: "Offers Unavailable",
                message: requestMessage(for: error),
                error: error
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            addIssue(
                .offers,
                title: "Offers Unavailable",
                message: requestMessage(for: .unavailable),
                error: error
            )
        }
    }

    private func loadBookings() async {
        do {
            let page = try await bookingRepository.bookings(
                participantID: groomerID,
                role: .groomer,
                page: .first
            )
            bookings = page.items
        } catch BookingRepositoryError.cancelled {
            return
        } catch let error as BookingRepositoryError {
            addIssue(
                .bookings,
                title: "Schedule Unavailable",
                message: bookingMessage(for: error),
                error: error
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            addIssue(
                .bookings,
                title: "Schedule Unavailable",
                message: bookingMessage(for: .unavailable),
                error: error
            )
        }
    }

    private func loadNextBookingPhoto() async {
        guard let nextBooking else {
            nextBookingPhotoData = nil
            return
        }

        do {
            let photos = try await requestRepository.requestPhotos(
                groomerID: groomerID,
                requestIDs: [nextBooking.requestID]
            )
            guard let photo = photos
                .filter({ $0.requestID == nextBooking.requestID })
                .sorted(by: Self.photoDisplayOrder)
                .first else {
                nextBookingPhotoData = nil
                return
            }
            nextBookingPhotoData = try await requestRepository.requestPhotoData(photo)
        } catch GroomerRequestRepositoryError.cancelled {
            return
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            nextBookingPhotoData = nil
            recordImageFallback(error: error, source: "booking-pet-photo")
        }
    }

    private func addIssue<E: Error>(
        _ section: GroomerHomeSection,
        title: String,
        message: String,
        error: E
    ) {
        issues.removeAll { $0.section == section }
        issues.append(
            GroomerHomeLoadIssue(
                section: section,
                title: title,
                message: message
            )
        )
        issues.sort { lhs, rhs in
            Self.issueOrder(lhs.section) < Self.issueOrder(rhs.section)
        }
        debugRecorder?.record(
            level: .error,
            category: .store,
            source: "GroomerHomeStore.load.\(section.rawValue)",
            scope: "groomer.home",
            message: message,
            underlyingError: error,
            metadata: ["section": section.rawValue]
        )
    }

    private func record(
        _ message: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "GroomerHomeStore.load",
            scope: "groomer.home",
            message: message,
            durationMs: message == "start"
                ? nil
                : Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: metadata
        )
    }

    private func recordImageFallback(error: any Error, source: String) {
        debugRecorder?.record(
            level: .warning,
            category: .store,
            source: "GroomerHomeStore.\(source)",
            scope: "groomer.home",
            message: "Using local image fallback",
            underlyingError: error
        )
    }

    private func message(
        for error: GroomerProfileRepositoryError,
        section: GroomerHomeSection
    ) -> String {
        switch (section, error) {
        case (_, .networkUnavailable):
            "Check your connection and try again."
        case (.profile, .notAllowed):
            "This account cannot load the groomer profile."
        case (.availability, .notAllowed):
            "This account cannot load availability."
        case (.profile, _):
            "We could not refresh your business profile."
        case (.availability, _):
            "We could not refresh your availability."
        case (_, _):
            "This section is temporarily unavailable."
        }
    }

    private func requestMessage(for error: GroomerRequestRepositoryError) -> String {
        switch error {
        case .networkUnavailable:
            "Check your connection and try again."
        case .notAllowed:
            "This account cannot load groomer requests."
        default:
            "We could not refresh your pre-booking work."
        }
    }

    private func bookingMessage(for error: BookingRepositoryError) -> String {
        switch error {
        case .networkUnavailable:
            "Check your connection and try again."
        case .notAllowed:
            "This account cannot load the groomer schedule."
        default:
            "We could not refresh your schedule."
        }
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func profileDetailText(_ profile: GroomerProfile) -> String? {
        if let city = normalized(profile.baseCity),
           let state = normalized(profile.baseState) {
            return "\(city), \(state)"
        }
        return nil
    }

    private static func photoDisplayOrder(
        lhs: GroomingRequestPhoto,
        rhs: GroomingRequestPhoto
    ) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.sortOrder < rhs.sortOrder
    }

    private static func issueOrder(_ section: GroomerHomeSection) -> Int {
        GroomerHomeSection.allCases.firstIndex(of: section) ?? .max
    }
}
