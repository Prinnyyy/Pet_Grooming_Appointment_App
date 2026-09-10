import Foundation

extension GroomerProfileStore {
    func startCreateService() {
        editingServiceID = nil
        resetServiceForm()
        errorMessage = nil
        noticeMessage = nil
        isShowingServiceForm = true
    }

    func startEditService(_ service: GroomerService) {
        editingServiceID = service.id
        serviceType = service.serviceType
        serviceTitle = service.title
        serviceDescription = service.description ?? ""
        serviceBasePrice = Self.displayPrice(service.basePrice)
        serviceDurationMinutes = String(service.durationMinutes)
        serviceUsesCustomSizeRange = !service.acceptedPetSizes.isEmpty
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

    func setServiceUsesCustomSizeRange(_ isEnabled: Bool) {
        errorMessage = nil
        noticeMessage = nil
        serviceUsesCustomSizeRange = isEnabled

        if isEnabled, selectedServiceSizes.isEmpty {
            setServiceAcceptedPetSizeRange(
                lowerIndex: selectedSizeBandRange.lowerBound,
                upperIndex: selectedSizeBandRange.upperBound,
                clearsNotice: false
            )
        } else if !isEnabled {
            selectedServiceSizes = []
        }
    }

    func setServiceAcceptedPetSizeRange(lowerIndex: Int, upperIndex: Int) {
        setServiceAcceptedPetSizeRange(
            lowerIndex: lowerIndex,
            upperIndex: upperIndex,
            clearsNotice: true
        )
    }

    func serviceSizePolicySummary(for service: GroomerService) -> String {
        if service.acceptedPetSizes.isEmpty {
            return service.acceptedPetSizeSummary
        }
        return "Custom range: \(Self.serviceSizeRangeTitle(for: service.acceptedPetSizes))"
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
        profileMutationRevision += 1
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
        profileMutationRevision += 1
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

    func setAvailability(
        day: GroomerAvailabilityWeekday,
        isEnabled: Bool,
        startMinutes: Int,
        endMinutes: Int
    ) {
        guard let index = availabilityDayStates.firstIndex(where: { $0.weekday == day }) else {
            return
        }

        availabilityDayStates[index].isEnabled = isEnabled
        availabilityDayStates[index].startMinutes = startMinutes
        availabilityDayStates[index].endMinutes = endMinutes
    }

    func saveAvailability() async {
        guard !isSaving else { return }
        guard !availabilitySaveNeedsReconciliation else {
            errorMessage = "Reload the saved schedule to confirm its current state before saving again."
            return
        }

        errorMessage = nil
        noticeMessage = nil

        let drafts: [GroomerAvailabilityDraft]
        let preferencesDraft: GroomerBookingPreferencesDraft
        do {
            drafts = try makeAvailabilityDrafts()
            preferencesDraft = try makeBookingPreferencesDraft()
        } catch let error as GroomerProfileFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check your availability and try again."
            return
        }

        isSaving = true
        profileMutationRevision += 1
        defer { isSaving = false }

        do {
            guard let revision = savedAvailability?.revision else {
                throw GroomerProfileRepositoryError.availabilityUpdateRequired
            }
            if preferencesDraft.timingBuffers != nil, savedAvailability?.timingVersion != 1 {
                throw GroomerProfileRepositoryError.availabilityUpdateRequired
            }
            let snapshot = try await repository.saveAvailability(
                groomerID: groomerID,
                expectedRevision: revision,
                windows: drafts,
                preferences: preferencesDraft,
                timeOff: timeOffWindows
            )
            if let requested = preferencesDraft.timingBuffers,
               snapshot.preferences.timingBuffers != requested {
                throw GroomerProfileRepositoryError.unavailable
            }
            applyAvailabilitySnapshot(snapshot)
            noticeMessage = "Availability saved."
        } catch let error as GroomerProfileRepositoryError {
            switch error {
            case .notAllowed, .availabilityUpdateRequired, .bookingOccupancyConflict:
                errorMessage = message(for: error, action: "save availability")
            case .availabilityConflict:
                availabilitySaveNeedsReconciliation = true
                errorMessage = message(for: error, action: "save availability")
            case .networkUnavailable, .cancelled, .unavailable:
                markAvailabilitySaveUnresolved()
            }
        } catch {
            markAvailabilitySaveUnresolved()
        }
    }

    private func markAvailabilitySaveUnresolved() {
        availabilitySaveNeedsReconciliation = true
        errorMessage = "We could not confirm whether availability was saved. Your edits are still here. Reload the saved schedule before trying again."
    }

    func applyAvailabilitySnapshot(_ snapshot: GroomerAvailabilitySnapshot) {
        availabilitySaveNeedsReconciliation = false
        savedAvailability = snapshot
        availabilityWindows = snapshot.windows
        bookingPreferences = snapshot.preferences
        timeOffWindows = snapshot.timeOff
        populateAvailabilityForm(with: snapshot.windows)
        populateBookingPreferencesForm(with: snapshot.preferences)
    }

    func discardAvailabilityEdits() {
        guard !isSaving else { return }
        let needsReconciliation = availabilitySaveNeedsReconciliation
        if let savedAvailability { applyAvailabilitySnapshot(savedAvailability) }
        availabilitySaveNeedsReconciliation = needsReconciliation
        errorMessage = nil
        noticeMessage = nil
    }

    var hasAvailabilityEdits: Bool {
        guard let savedAvailability else { return !timeOffWindows.isEmpty }
        var savedStates = GroomerAvailabilityDayState.defaultStates()
        for window in savedAvailability.windows {
            guard let index = savedStates.firstIndex(where: { $0.weekday == window.weekday }) else { continue }
            savedStates[index] = GroomerAvailabilityDayState(
                weekday: window.weekday, isEnabled: window.isEnabled,
                startMinutes: window.startMinutes, endMinutes: window.endMinutes
            )
        }
        return timeOffWindows != savedAvailability.timeOff
            || maxAppointmentsPerDay != savedAvailability.preferences.maxAppointmentsPerDay
            || minimumAdvanceNoticeDays != savedAvailability.preferences.minimumAdvanceNoticeDays
            || autoAcceptBookings != savedAvailability.preferences.autoAcceptBookings
            || preparationMinutesText != (savedAvailability.preferences.timingBuffers.map { String($0.preparation) } ?? "")
            || cleanupMinutesText != (savedAvailability.preferences.timingBuffers.map { String($0.cleanup) } ?? "")
            || inboundTravelMinutesText != (savedAvailability.preferences.timingBuffers.map { String($0.inboundTravel) } ?? "")
            || outboundTravelMinutesText != (savedAvailability.preferences.timingBuffers.map { String($0.outboundTravel) } ?? "")
            || availabilityDayStates != savedStates
            || savedAvailability.windows.contains { availabilityTimezone != $0.timezone }
    }

    func reloadAvailability() async {
        guard !isBusy else { return }
        isSaving = true
        profileMutationRevision += 1
        defer { isSaving = false }
        do {
            let snapshot = try await repository.availabilitySnapshot(groomerID: groomerID)
            applyAvailabilitySnapshot(snapshot)
            errorMessage = nil
            noticeMessage = nil
        } catch {
            errorMessage = "Could not reload availability. Your edits are still here."
        }
    }

    func startCreateTimeOff() {
        resetTimeOffForm()
        errorMessage = nil
        noticeMessage = nil
        isShowingTimeOffForm = true
    }

    func cancelTimeOffForm() {
        resetTimeOffForm()
        isShowingTimeOffForm = false
    }

    func createTimeOff() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        let draft: GroomerTimeOffDraft
        do {
            draft = try makeTimeOffDraft()
        } catch let error as GroomerProfileFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check your time off dates and try again."
            return
        }

        let window = GroomerTimeOffWindow(
            id: UUID(), groomerID: groomerID, title: draft.title,
            startDate: draft.startDate, endDate: draft.endDate
        )
        timeOffWindows.append(window)
        timeOffWindows.sort {
            if $0.startDate == $1.startDate {
                $0.title < $1.title
            } else {
                $0.startDate < $1.startDate
            }
        }
        isShowingTimeOffForm = false
        resetTimeOffForm()
        noticeMessage = nil
    }

    func deleteTimeOff(_ window: GroomerTimeOffWindow) async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil
        timeOffWindows.removeAll { $0.id == window.id }
    }

    func resetTimeOffForm() {
        timeOffTitle = ""
        let today = Calendar.current.startOfDay(for: Date())
        timeOffStartDate = today
        timeOffEndDate = today
    }

    private func resetServiceForm() {
        serviceType = .fullGroom
        serviceTitle = GroomingServiceType.fullGroom.title
        serviceDescription = ""
        serviceBasePrice = ""
        serviceDurationMinutes = ""
        serviceUsesCustomSizeRange = false
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

    private func makeServiceDraft() throws -> GroomerServiceDraft {
        let serviceTitle = serviceType.title
        return GroomerServiceDraft(
            serviceType: serviceType,
            title: serviceTitle,
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
            acceptedPetSizes: serviceUsesCustomSizeRange
                ? GroomerServicePetSize.allCases.filter { selectedServiceSizes.contains($0) }
                : [],
            isActive: serviceIsActive
        )
    }

    private func makeAvailabilityDrafts() throws -> [GroomerAvailabilityDraft] {
        try availabilityDayStates
            .sorted { $0.weekday.rawValue < $1.weekday.rawValue }
            .map { state in
                guard state.startMinutes >= 0,
                      state.endMinutes <= 23 * 60 + 59 else {
                    throw GroomerProfileFormError(
                        message: "\(state.weekday.title) availability must stay within one day."
                    )
                }

                if state.endMinutes <= state.startMinutes {
                    throw GroomerProfileFormError(
                        message: "\(state.weekday.title) availability needs an end time after the start time."
                    )
                }

                return GroomerAvailabilityDraft(
                    weekday: state.weekday,
                    startMinutes: state.startMinutes,
                    endMinutes: state.endMinutes,
                    isEnabled: state.isEnabled,
                    timezone: availabilityTimezone
                )
            }
    }

    private func makeTimingBuffersDraft() throws -> GroomingTimingBuffers? {
        let values = [preparationMinutesText, cleanupMinutesText, inboundTravelMinutesText, outboundTravelMinutesText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if values.allSatisfy(\.isEmpty), savedAvailability?.preferences.timingBuffers == nil { return nil }
        guard let preparation = Int(values[0]), let cleanup = Int(values[1]),
              let inbound = Int(values[2]), let outbound = Int(values[3]) else {
            throw GroomerProfileFormError(message: "Enter all four timing buffers. Use 0 when no buffer is needed.")
        }
        do {
            return try GroomingTimingBuffers(preparation: preparation, cleanup: cleanup,
                inboundTravel: inbound, outboundTravel: outbound)
        } catch {
            throw GroomerProfileFormError(message: "Preparation and cleanup must be 0-120 minutes. Mobile travel must be 0-180 minutes.")
        }
    }

    private func makeBookingPreferencesDraft() throws -> GroomerBookingPreferencesDraft {
        guard (1...12).contains(maxAppointmentsPerDay) else {
            throw GroomerProfileFormError(
                message: "Max appointments per day must be 1–12."
            )
        }

        guard (0...2).contains(minimumAdvanceNoticeDays) else {
            throw GroomerProfileFormError(
                message: "Minimum advance notice must be Same day, 1 day, or 2 days."
            )
        }

        return GroomerBookingPreferencesDraft(
            maxAppointmentsPerDay: maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: minimumAdvanceNoticeDays,
            autoAcceptBookings: autoAcceptBookings,
            timingBuffers: try makeTimingBuffersDraft()
        )
    }

    private func makeTimeOffDraft() throws -> GroomerTimeOffDraft {
        let title = try required(
            timeOffTitle,
            field: "Time off title",
            range: 1...80
        )
        let startDate = Calendar.current.startOfDay(for: timeOffStartDate)
        let endDate = Calendar.current.startOfDay(for: timeOffEndDate)

        guard endDate >= startDate else {
            throw GroomerProfileFormError(
                message: "Time off end date must be on or after the start date."
            )
        }

        return GroomerTimeOffDraft(
            title: title,
            startDate: Self.dateString(from: startDate),
            endDate: Self.dateString(from: endDate)
        )
    }

    private func setServiceAcceptedPetSizeRange(
        lowerIndex: Int,
        upperIndex: Int,
        clearsNotice: Bool
    ) {
        if clearsNotice {
            errorMessage = nil
            noticeMessage = nil
        }

        let range = Self.normalizedServiceSizeRange(
            lowerIndex: lowerIndex,
            upperIndex: upperIndex
        )
        serviceUsesCustomSizeRange = true
        selectedServiceSizes = Set(
            Self.serviceSizeOptions.enumerated().compactMap { index, size in
                range.contains(index) ? size : nil
            }
        )
    }

    static func displayPrice(_ price: Double) -> String {
        if price.rounded() == price {
            return String(Int(price))
        }
        return String(format: "%.2f", price)
    }

    static var serviceSizeOptions: [GroomerServicePetSize] {
        GroomerServicePetSize.allCases
    }

    static var fullServiceSizeRange: ClosedRange<Int> {
        0...(serviceSizeOptions.count - 1)
    }

    static func normalizedServiceSizeRange(
        lowerIndex: Int,
        upperIndex: Int
    ) -> ClosedRange<Int> {
        let maximumIndex = serviceSizeOptions.count - 1
        let lowerBound = min(max(lowerIndex, 0), maximumIndex)
        let upperBound = min(max(upperIndex, 0), maximumIndex)
        return min(lowerBound, upperBound)...max(lowerBound, upperBound)
    }

    static func serviceSizeRangeTitle(
        for sizes: [GroomerServicePetSize]
    ) -> String {
        let selectedIndices = serviceSizeOptions.enumerated().compactMap { index, size in
            sizes.contains(size) ? index : nil
        }
        guard let lowerBound = selectedIndices.min(),
              let upperBound = selectedIndices.max() else {
            return serviceSizeRangeTitle(for: fullServiceSizeRange)
        }
        return serviceSizeRangeTitle(for: lowerBound...upperBound)
    }

    static func serviceSizeRangeTitle(
        for range: ClosedRange<Int>
    ) -> String {
        let normalizedRange = normalizedServiceSizeRange(
            lowerIndex: range.lowerBound,
            upperIndex: range.upperBound
        )
        let lower = serviceSizeOptions[normalizedRange.lowerBound]
        let upper = serviceSizeOptions[normalizedRange.upperBound]
        if lower == upper {
            return "\(lower.title) (\(lower.singleWeightLabel))"
        }
        return "\(lower.title)-\(upper.title) (\(lower.lowerWeightLabel)-\(upper.upperWeightLabel))"
    }

    static func dateString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 1,
            components.day ?? 1
        )
    }

}
