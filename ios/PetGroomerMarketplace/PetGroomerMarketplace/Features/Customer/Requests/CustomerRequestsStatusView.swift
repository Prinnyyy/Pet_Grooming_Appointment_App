import Foundation
import SwiftUI

struct CustomerRequestsStatusView: View {
    let store: CustomerRequestsStore

    var body: some View {
        GroomlyGlobalFeedbackForwarder(
            noticeMessage: store.noticeMessage,
            clearNotice: { message in
                store.clearNotice(ifCurrent: message)
            },
            error: errorPrompt,
            progress: progressPrompt
        )
    }

    private var errorPrompt: GroomlyGlobalFeedbackError? {
        guard let errorMessage = store.errorMessage,
              !store.isShowingWizard else { return nil }
        return GroomlyGlobalFeedbackError(
            scope: .page("customer.requests"),
            sourceKey: "customer.requests.error",
            title: "We Could Not Update Requests",
            message: errorMessage
        )
    }

    private var progressPrompt: GroomlyGlobalFeedbackProgress? {
        guard store.isSubmitting else { return nil }
        return GroomlyGlobalFeedbackProgress(
            scope: .operation("customer.requests.publish"),
            sourceKey: "customer.requests.publish-progress",
            title: "Publishing…",
            tone: .customer
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CustomerRequestsView(
            customerID: UUID(),
            petRepository: CustomerRequestsPreviewPetRepository(),
            requestRepository: CustomerRequestsPreviewRequestRepository(),
            bookingRepository: CustomerRequestsPreviewBookingRepository()
        )
    }
}

@MainActor
private final class CustomerRequestsPreviewPetRepository: CustomerPetRepository {
    private let pet = CustomerPet(
        id: UUID(),
        customerID: UUID(),
        name: "Mochi",
        species: "Dog",
        breed: "Corgi",
        coatType: nil,
        size: "M",
        weightLbs: 22,
        birthday: nil,
        temperament: "Gentle",
        medicalNotes: nil,
        groomingNotes: nil,
        isActive: true
    )

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        [pet]
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        []
    }

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        pet
    }

    func updatePet(
        pet: CustomerPet,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        pet
    }

    func softDeletePet(_ pet: CustomerPet) async throws {}

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        throw CustomerPetRepositoryError.unavailable
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {}
}

@MainActor
private final class CustomerRequestsPreviewRequestRepository: CustomerRequestRepository {
    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        [
            CustomerGroomingRequest(
                id: UUID(),
                customerID: customerID,
                petID: UUID(),
                petSnapshot: GroomingRequestPetSnapshot(
                    id: UUID(),
                    name: "Mochi",
                    species: "Dog",
                    breed: "Corgi",
                    coatType: nil,
                    size: "M",
                    weightLbs: 22,
                    birthday: nil,
                    temperament: "Gentle",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-20T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: .fullGroom,
                serviceNotes: "Please be gentle around the paws.",
                preferredStart: "2026-06-22T16:00:00Z",
                preferredEnd: "2026-06-22T18:00:00Z",
                locationMode: .groomerComesToCustomer,
                streetAddress: "123 Pine Street",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                travelRadiusMiles: nil,
                status: .open,
                expiresAt: "2026-06-22T12:00:00Z",
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
            CustomerGroomingRequest(
                id: UUID(),
                customerID: customerID,
                petID: UUID(),
                petSnapshot: GroomingRequestPetSnapshot(
                    id: UUID(),
                    name: "Biscuit",
                    species: "Dog",
                    breed: "Pomeranian",
                    coatType: nil,
                    size: "S",
                    weightLbs: 12,
                    birthday: nil,
                    temperament: "Playful",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-18T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: .bathAndBrush,
                serviceNotes: nil,
                preferredStart: "2026-06-24T17:00:00Z",
                preferredEnd: "2026-06-24T18:30:00Z",
                locationMode: .customerComesToGroomer,
                streetAddress: "456 Cedar Avenue",
                city: "Seattle",
                state: "WA",
                zipCode: "98103",
                travelRadiusMiles: 15,
                status: .booked,
                expiresAt: "2026-06-23T12:00:00Z",
                createdAt: "2026-06-18T12:00:00Z",
                updatedAt: "2026-06-21T12:00:00Z"
            ),
        ]
    }

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview] {
        [
            CustomerOfferReview(
                offer: GroomerOffer(
                    id: UUID(),
                    requestID: requestID,
                    matchID: UUID(),
                    customerID: customerID,
                    groomerID: UUID(),
                    proposedStart: "2026-06-22T16:30:00Z",
                    proposedEnd: "2026-06-22T18:00:00Z",
                    priceEstimate: 125,
                    message: "I can do a calm full groom.",
                    status: .pending,
                    expiresAt: "2026-06-22T12:00:00Z",
                    withdrawnAt: nil,
                    createdAt: "2026-06-20T13:00:00Z",
                    updatedAt: "2026-06-20T13:00:00Z"
                ),
                groomerProfile: GroomerProfile(
                    userID: UUID(),
                    businessName: "Fresh Paws Grooming",
                    bio: "Low-stress grooming for small dogs.",
                    yearsExperience: 5,
                    baseCity: "Seattle",
                    baseState: "WA",
                    serviceRadiusMiles: 12,
                    serviceLocationMode: .groomerComesToCustomer,
                    ratingAverage: 0,
                    ratingCount: 0,
                    isActive: true,
                    isVerified: false
                ),
                matchScore: 94,
                matchReason: "Same city and service location. Pet-fit evidence: completed poodle coats."
            ),
        ]
    }

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult {
        GroomingRequestPublishResult(
            requestID: UUID(),
            matchCount: 2
        )
    }

    func uploadRequestPhoto(
        customerID: UUID,
        requestID: UUID,
        data: Data,
        contentType: GroomingRequestPhotoContentType,
        caption: String?
    ) async throws -> GroomingRequestPhoto {
        GroomingRequestPhoto(
            id: UUID(),
            requestID: requestID,
            customerID: customerID,
            storageBucket: "request-photos",
            storagePath: GroomingRequestPhotoPath.make(
                customerID: customerID,
                requestID: requestID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: 0,
            createdAt: "2026-06-20T14:00:00Z"
        )
    }

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult {
        CancelGroomingRequestResult(
            requestID: requestID,
            requestStatus: .cancelled,
            cancelledTimestamp: "2026-06-20T14:00:00Z"
        )
    }
}

@MainActor
private final class CustomerRequestsPreviewBookingRepository: BookingRepository {
    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        []
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        AcceptGroomerOfferResult(
            bookingID: UUID(),
            conversationID: UUID(),
            requestID: UUID(),
            offerID: offerID,
            bookingStatus: .confirmed,
            offerStatus: .acceptedByCustomer,
            requestStatus: .booked
        )
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        throw BookingRepositoryError.unavailable
    }
}
#endif
