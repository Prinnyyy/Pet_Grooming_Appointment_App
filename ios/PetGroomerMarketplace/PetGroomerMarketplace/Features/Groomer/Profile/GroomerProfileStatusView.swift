import SwiftUI

struct GroomerProfileStatusView: View {
    let store: GroomerProfileStore

    var body: some View {
        GroomlyGlobalFeedbackForwarder(
            noticeMessage: store.noticeMessage,
            clearNotice: { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            },
            error: errorPrompt,
            progress: progressPrompt
        )
    }

    private var errorPrompt: GroomlyGlobalFeedbackError? {
        guard let errorMessage = store.errorMessage,
              !store.isShowingServiceForm else { return nil }
        return GroomlyGlobalFeedbackError(
            scope: .page("groomer.profile"),
            sourceKey: "groomer.profile.error",
            title: "Profile Update Failed",
            message: errorMessage
        )
    }

    private var progressPrompt: GroomlyGlobalFeedbackProgress? {
        guard store.isSaving || store.isUploading else { return nil }
        return GroomlyGlobalFeedbackProgress(
            scope: .operation("groomer.profile.save"),
            sourceKey: "groomer.profile.save-progress",
            title: store.isUploading ? "Uploading…" : "Saving…",
            tone: .groomer
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GroomerProfileManagementView(
            groomerID: UUID(),
            repository: GroomerProfilePreviewRepository()
        )
    }
}

@MainActor
private final class GroomerProfilePreviewRepository: GroomerProfileRepository {
    private let groomerID = UUID()
    private var storedProfile: GroomerProfile
    private var storedServices: [GroomerService]
    private var storedPhotos: [GroomerPortfolioPhoto] = []
    private var storedPortfolioFitTags: [GroomerPortfolioFitTag] = []
    private var storedAvailability: [GroomerAvailabilityWindow] = []
    private var storedBookingPreferences: GroomerBookingPreferences
    private var storedTimeOff: [GroomerTimeOffWindow] = []
    private var storedPetFitEvidenceSummary: [GroomerPetFitEvidenceSummary] = []

    init() {
        storedProfile = GroomerProfile(
            userID: groomerID,
            businessName: "Fresh Coat Grooming",
            bio: "Calm, one-on-one grooming for small and medium dogs.",
            yearsExperience: 5,
            baseStreetAddress: "123 Pine Street",
            baseCity: "Seattle",
            baseState: "WA",
            baseZipCode: "98101",
            serviceRadiusMiles: 12,
            serviceLocationMode: .groomerComesToCustomer,
            serviceLocationModes: [.groomerComesToCustomer, .customerComesToGroomer],
            ratingAverage: 0,
            ratingCount: 0,
            isActive: false,
            isVerified: false
        )
        storedServices = [
            GroomerService(
                id: UUID(),
                groomerID: groomerID,
                serviceType: .fullGroom,
                title: "Full Groom",
                description: "Bath, haircut, nails, and ear cleaning.",
                basePrice: 95,
                durationMinutes: 120,
                acceptedPetSizes: [.xs, .s, .m],
                isActive: true
            ),
        ]
        storedBookingPreferences = GroomerBookingPreferences(
            groomerID: groomerID,
            maxAppointmentsPerDay: 4,
            minimumAdvanceNoticeDays: 0,
            autoAcceptBookings: false
        )
        storedTimeOff = [
            GroomerTimeOffWindow(
                id: UUID(),
                groomerID: groomerID,
                title: "Long weekend away",
                startDate: "2026-07-04",
                endDate: "2026-07-06"
            ),
            GroomerTimeOffWindow(
                id: UUID(),
                groomerID: groomerID,
                title: "Grooming workshop",
                startDate: "2026-08-12",
                endDate: "2026-08-12"
            ),
        ]
        storedAvailability = [
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: .monday,
                startMinutes: 9 * 60,
                endMinutes: 17 * 60,
                isEnabled: true,
                timezone: TimeZone.current.identifier
            ),
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: .tuesday,
                startMinutes: 9 * 60,
                endMinutes: 17 * 60,
                isEnabled: true,
                timezone: TimeZone.current.identifier
            ),
        ]
        storedPetFitEvidenceSummary = [
            GroomerPetFitEvidenceSummary(
                groomerID: groomerID,
                signal: .breedGroup(.poodle),
                completedBookingCount: 5,
                positiveReviewOutcomeCount: 3,
                negativeReviewOutcomeCount: 0,
                structuredReviewOutcomeCount: 3,
                lastCompletedAt: "2026-06-21T17:00:00Z",
                lastReviewOutcomeAt: "2026-06-22T18:00:00Z",
                evidenceUpdatedAt: "2026-06-22T18:00:00Z",
                confidenceTier: .high
            ),
            GroomerPetFitEvidenceSummary(
                groomerID: groomerID,
                signal: .serviceFit(.gentleHandling),
                completedBookingCount: 2,
                positiveReviewOutcomeCount: 1,
                negativeReviewOutcomeCount: 0,
                structuredReviewOutcomeCount: 1,
                lastCompletedAt: "2026-06-18T16:00:00Z",
                lastReviewOutcomeAt: "2026-06-19T16:30:00Z",
                evidenceUpdatedAt: "2026-06-19T16:30:00Z",
                confidenceTier: .medium
            ),
        ]
    }

    func profile(groomerID: UUID) async throws -> GroomerProfile {
        storedProfile
    }

    func services(groomerID: UUID) async throws -> [GroomerService] {
        storedServices
    }

    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto] {
        storedPhotos
    }

    func portfolioFitTags(groomerID: UUID) async throws -> [GroomerPortfolioFitTag] {
        storedPortfolioFitTags
    }

    func fitClaims(groomerID: UUID) async throws -> [GroomerFitClaim] {
        []
    }

    func petFitEvidenceSummary(groomerID: UUID) async throws -> [GroomerPetFitEvidenceSummary] {
        storedPetFitEvidenceSummary
    }

    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow] {
        storedAvailability
    }

    func bookingPreferences(groomerID: UUID) async throws -> GroomerBookingPreferences {
        storedBookingPreferences
    }

    func timeOffWindows(groomerID: UUID) async throws -> [GroomerTimeOffWindow] {
        storedTimeOff
    }

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft
    ) async throws -> GroomerProfile {
        storedProfile = GroomerProfile(
            userID: groomerID,
            businessName: draft.businessName,
            bio: draft.bio,
            yearsExperience: draft.yearsExperience,
            baseStreetAddress: draft.baseStreetAddress,
            baseCity: draft.baseCity,
            baseState: draft.baseStateCode?.rawValue,
            baseZipCode: draft.baseZipCode,
            serviceRadiusMiles: draft.serviceRadiusMiles,
            serviceLocationMode: draft.serviceLocationMode,
            serviceLocationModes: draft.serviceLocationModes,
            ratingAverage: storedProfile.ratingAverage,
            ratingCount: storedProfile.ratingCount,
            isActive: draft.isActive,
            isVerified: storedProfile.isVerified
        )
        return storedProfile
    }

    func createService(
        groomerID: UUID,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        let service = GroomerService(
            id: UUID(),
            groomerID: groomerID,
            serviceType: draft.serviceType,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
        storedServices.insert(service, at: 0)
        return service
    }

    func updateService(
        service: GroomerService,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        GroomerService(
            id: service.id,
            groomerID: service.groomerID,
            serviceType: draft.serviceType,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
    }

    func deleteService(_ service: GroomerService) async throws {}

    func uploadPortfolioPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerPortfolioPhotoContentType,
        caption: String?
    ) async throws -> GroomerPortfolioPhoto {
        let photo = GroomerPortfolioPhoto(
            id: UUID(),
            groomerID: groomerID,
            storageBucket: "groomer-portfolio",
            storagePath: GroomerPortfolioPhotoPath.make(
                groomerID: groomerID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: 0
        )
        storedPhotos.append(photo)
        return photo
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws {
        storedPhotos.removeAll { $0.id == photo.id }
        storedPortfolioFitTags.removeAll { $0.portfolioPhotoID == photo.id }
    }

    func replaceFitClaims(
        groomerID: UUID,
        drafts: [GroomerFitClaimDraft]
    ) async throws -> [GroomerFitClaim] {
        drafts.map {
            GroomerFitClaim(
                id: UUID(),
                groomerID: groomerID,
                signal: $0.signal,
                isActive: $0.isActive
            )
        }
    }

    func replacePortfolioFitTags(
        groomerID: UUID,
        photoID: UUID,
        drafts: [GroomerPortfolioFitTagDraft]
    ) async throws -> [GroomerPortfolioFitTag] {
        let tags = drafts.map {
            GroomerPortfolioFitTag(
                id: UUID(),
                portfolioPhotoID: photoID,
                groomerID: groomerID,
                signal: $0.signal
            )
        }
        storedPortfolioFitTags.removeAll { $0.portfolioPhotoID == photoID }
        storedPortfolioFitTags.append(contentsOf: tags)
        return tags
    }

    func uploadAvatarPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerAvatarPhotoContentType
    ) async throws -> String {
        let path = GroomerAvatarPhotoPath.make(
            groomerID: groomerID,
            contentType: contentType
        )
        storedProfile.avatarPath = path
        return path
    }

    func avatarPhotoData(storagePath: String) async throws -> Data {
        Data()
    }

    func replaceAvailability(
        groomerID: UUID,
        drafts: [GroomerAvailabilityDraft]
    ) async throws -> [GroomerAvailabilityWindow] {
        storedAvailability = drafts.map {
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: $0.weekday,
                startMinutes: $0.startMinutes,
                endMinutes: $0.endMinutes,
                isEnabled: $0.isEnabled,
                timezone: $0.timezone
            )
        }
        return storedAvailability
    }

    func updateBookingPreferences(
        groomerID: UUID,
        draft: GroomerBookingPreferencesDraft
    ) async throws -> GroomerBookingPreferences {
        storedBookingPreferences = GroomerBookingPreferences(
            groomerID: groomerID,
            maxAppointmentsPerDay: draft.maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: draft.minimumAdvanceNoticeDays,
            autoAcceptBookings: draft.autoAcceptBookings
        )
        return storedBookingPreferences
    }

    func createTimeOff(
        groomerID: UUID,
        draft: GroomerTimeOffDraft
    ) async throws -> GroomerTimeOffWindow {
        let window = GroomerTimeOffWindow(
            id: UUID(),
            groomerID: groomerID,
            title: draft.title,
            startDate: draft.startDate,
            endDate: draft.endDate
        )
        storedTimeOff.append(window)
        return window
    }

    func deleteTimeOff(_ window: GroomerTimeOffWindow) async throws {
        storedTimeOff.removeAll { $0.id == window.id }
    }
}
#endif
