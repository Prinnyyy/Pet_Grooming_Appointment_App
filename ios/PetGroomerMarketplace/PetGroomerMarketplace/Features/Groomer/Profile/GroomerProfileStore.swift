import Foundation
import Observation

@MainActor
@Observable
final class GroomerProfileStore {
    static let maximumPhotoBytes = 10 * 1024 * 1024

    private let groomerID: UUID
    private let repository: any GroomerProfileRepository

    private(set) var profile: GroomerProfile?
    private(set) var services: [GroomerService] = []
    private(set) var portfolioPhotos: [GroomerPortfolioPhoto] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isUploading = false

    var errorMessage: String?
    var noticeMessage: String?

    var businessName = ""
    var bio = ""
    var yearsExperience = ""
    var baseCity = ""
    var baseState = ""
    var serviceRadiusMiles = ""
    var isActive = false

    var isShowingServiceForm = false
    var editingServiceID: UUID?
    var serviceTitle = ""
    var serviceDescription = ""
    var serviceBasePrice = ""
    var serviceDurationMinutes = ""
    var selectedServiceSizes: Set<GroomerServicePetSize> = []
    var serviceIsActive = true

    var serviceFormTitle: String {
        editingServiceID == nil ? "Add Service" : "Edit Service"
    }

    var isBusy: Bool {
        isLoading || isSaving || isUploading
    }

    init(
        groomerID: UUID,
        repository: any GroomerProfileRepository
    ) {
        self.groomerID = groomerID
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loadedProfile = try await repository.profile(groomerID: groomerID)
            let loadedServices = try await repository.services(groomerID: groomerID)
            let loadedPhotos = try await repository.portfolioPhotos(groomerID: groomerID)

            profile = loadedProfile
            services = loadedServices
            portfolioPhotos = loadedPhotos
            populateProfileForm(with: loadedProfile)
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "load")
        } catch {
            errorMessage = message(for: .unavailable, action: "load")
        }
    }

    func sortedPortfolioPhotos() -> [GroomerPortfolioPhoto] {
        portfolioPhotos.sorted {
            if $0.sortOrder == $1.sortOrder {
                $0.fileName < $1.fileName
            } else {
                $0.sortOrder < $1.sortOrder
            }
        }
    }

    func saveProfile() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        let draft: GroomerProfileDraft
        do {
            draft = try makeProfileDraft()
        } catch let error as GroomerProfileFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check your profile details and try again."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let updatedProfile = try await repository.updateProfile(
                groomerID: groomerID,
                draft: draft
            )
            profile = updatedProfile
            populateProfileForm(with: updatedProfile)
            noticeMessage = "Groomer profile saved."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save")
        } catch {
            errorMessage = message(for: .unavailable, action: "save")
        }
    }

    func startCreateService() {
        editingServiceID = nil
        resetServiceForm()
        errorMessage = nil
        noticeMessage = nil
        isShowingServiceForm = true
    }

    func startEditService(_ service: GroomerService) {
        editingServiceID = service.id
        serviceTitle = service.title
        serviceDescription = service.description ?? ""
        serviceBasePrice = Self.displayPrice(service.basePrice)
        serviceDurationMinutes = String(service.durationMinutes)
        selectedServiceSizes = Set(service.acceptedPetSizes)
        serviceIsActive = service.isActive
        errorMessage = nil
        noticeMessage = nil
        isShowingServiceForm = true
    }

    func cancelServiceForm() {
        isShowingServiceForm = false
        editingServiceID = nil
        resetServiceForm()
    }

    func saveService() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        let draft: GroomerServiceDraft
        do {
            draft = try makeServiceDraft()
        } catch let error as GroomerProfileFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check your service details and try again."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            if let editingServiceID,
               let currentService = services.first(where: { $0.id == editingServiceID }) {
                let service = try await repository.updateService(
                    service: currentService,
                    draft: draft
                )
                replace(service)
                noticeMessage = "\(service.title) was updated."
            } else {
                let service = try await repository.createService(
                    groomerID: groomerID,
                    draft: draft
                )
                services.insert(service, at: 0)
                noticeMessage = "\(service.title) was added."
            }

            isShowingServiceForm = false
            editingServiceID = nil
            resetServiceForm()
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save")
        } catch {
            errorMessage = message(for: .unavailable, action: "save")
        }
    }

    func deleteService(_ service: GroomerService) async {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSaving = false }

        do {
            try await repository.deleteService(service)
            services.removeAll { $0.id == service.id }
            noticeMessage = "\(service.title) was deleted."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "delete")
        } catch {
            errorMessage = message(for: .unavailable, action: "delete")
        }
    }

    func uploadPortfolioPhoto(
        data: Data,
        contentType: GroomerPortfolioPhotoContentType
    ) async {
        guard !isUploading else { return }

        guard data.count <= Self.maximumPhotoBytes else {
            errorMessage = "Choose a portfolio photo smaller than 10 MB."
            return
        }

        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            let photo = try await repository.uploadPortfolioPhoto(
                groomerID: groomerID,
                data: data,
                contentType: contentType,
                caption: nil
            )
            portfolioPhotos.append(photo)
            noticeMessage = "Portfolio photo was uploaded."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "upload")
        } catch {
            errorMessage = message(for: .unavailable, action: "upload")
        }
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async {
        guard !isUploading else { return }

        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            try await repository.deletePortfolioPhoto(photo)
            portfolioPhotos.removeAll { $0.id == photo.id }
            noticeMessage = "Portfolio photo was deleted."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "delete photo")
        } catch {
            errorMessage = message(for: .unavailable, action: "delete photo")
        }
    }

    private func populateProfileForm(with profile: GroomerProfile) {
        businessName = profile.businessName ?? ""
        bio = profile.bio ?? ""
        yearsExperience = profile.yearsExperience.map(String.init) ?? ""
        baseCity = profile.baseCity ?? ""
        baseState = profile.baseState ?? ""
        serviceRadiusMiles = profile.serviceRadiusMiles.map(String.init) ?? ""
        isActive = profile.isActive
    }

    private func resetServiceForm() {
        serviceTitle = ""
        serviceDescription = ""
        serviceBasePrice = ""
        serviceDurationMinutes = ""
        selectedServiceSizes = []
        serviceIsActive = true
    }

    private func replace(_ service: GroomerService) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else {
            services.insert(service, at: 0)
            return
        }
        services[index] = service
    }

    private func makeProfileDraft() throws -> GroomerProfileDraft {
        let draft = GroomerProfileDraft(
            businessName: try optional(
                businessName,
                field: "Business name",
                maximum: 120
            ),
            bio: try optional(bio, field: "Bio", maximum: 2000),
            yearsExperience: try optionalInteger(
                yearsExperience,
                field: "Years of experience",
                range: 0...80
            ),
            baseCity: try optional(baseCity, field: "City", maximum: 100),
            baseState: try optional(baseState, field: "State", maximum: 80),
            serviceRadiusMiles: try optionalInteger(
                serviceRadiusMiles,
                field: "Service radius",
                range: 1...250
            ),
            isActive: isActive
        )

        if draft.isActive,
           (draft.businessName == nil
            || draft.baseCity == nil
            || draft.baseState == nil
            || draft.serviceRadiusMiles == nil) {
            throw GroomerProfileFormError(
                message: "Complete business name, city, state, and service radius before going active."
            )
        }

        if let baseState = draft.baseState,
           baseState.count < 2 {
            throw GroomerProfileFormError(
                message: "State must be 2–80 characters."
            )
        }

        return draft
    }

    private func makeServiceDraft() throws -> GroomerServiceDraft {
        GroomerServiceDraft(
            title: try required(serviceTitle, field: "Service title", range: 1...80),
            description: try optional(
                serviceDescription,
                field: "Description",
                maximum: 500
            ),
            basePrice: try price(from: serviceBasePrice),
            durationMinutes: try requiredInteger(
                serviceDurationMinutes,
                field: "Duration",
                range: 15...720
            ),
            acceptedPetSizes: GroomerServicePetSize.allCases.filter {
                selectedServiceSizes.contains($0)
            },
            isActive: serviceIsActive
        )
    }

    private func required(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard range.contains(trimmed.count) else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound) characters."
            )
        }
        return trimmed
    }

    private func optional(
        _ value: String,
        field: String,
        maximum: Int
    ) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= maximum else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(maximum) characters or fewer."
            )
        }
        return trimmed
    }

    private func optionalInteger(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try integer(trimmed, field: field, range: range)
    }

    private func requiredInteger(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound)."
            )
        }
        return try integer(trimmed, field: field, range: range)
    }

    private func integer(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> Int {
        guard let integer = Int(value), range.contains(integer) else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound)."
            )
        }
        return integer
    }

    private func price(from value: String) throws -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let price = Double(trimmed),
              price >= 0,
              price <= 100000 else {
            throw GroomerProfileFormError(
                message: "Base price must be between 0 and 100000."
            )
        }

        if let decimals = trimmed.split(separator: ".").dropFirst().first,
           decimals.count > 2 {
            throw GroomerProfileFormError(
                message: "Base price can use at most 2 decimal places."
            )
        }

        return price
    }

    private static func displayPrice(_ price: Double) -> String {
        if price.rounded() == price {
            return String(Int(price))
        }
        return String(format: "%.2f", price)
    }

    private func message(
        for error: GroomerProfileRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) groomer profile details."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not \(action) groomer profile details. Please try again."
        }
    }
}

private struct GroomerProfileFormError: Error {
    let message: String
}
