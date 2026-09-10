import Foundation

extension GroomerProfileStore {
    func sortedPetFitEvidenceSummary() -> [GroomerPetFitEvidenceSummary] {
        petFitEvidenceSummary.sorted(by: Self.sortPetFitEvidenceSummary)
    }

    func isFitClaimSelected(_ signal: PetFitSignal) -> Bool {
        selectedFitClaimIDs.contains(signal.id)
    }

    func selectedFitClaimCount(in group: PetFitSignal.Group) -> Int {
        selectedFitClaimCount { $0.group == group }
    }

    func ensureSizeBandFitClaimRange() {
        setSizeBandFitClaimRange(
            lowerIndex: selectedSizeBandRange.lowerBound,
            upperIndex: selectedSizeBandRange.upperBound,
            clearsNotice: false
        )
    }

    func setSizeBandFitClaimRange(
        lowerIndex: Int,
        upperIndex: Int
    ) {
        setSizeBandFitClaimRange(
            lowerIndex: lowerIndex,
            upperIndex: upperIndex,
            clearsNotice: true
        )
    }

    func toggleFitClaim(_ signal: PetFitSignal) {
        errorMessage = nil
        noticeMessage = nil

        if selectedFitClaimIDs.contains(signal.id) {
            selectedFitClaimIDs.remove(signal.id)
            return
        }

        guard signal.group == .sizeBand
                || selectedCoreFitClaimCount < GroomerFitClaim.maximumActiveClaims else {
            errorMessage = Self.fitClaimLimitMessage
            return
        }

        selectedFitClaimIDs.insert(signal.id)
    }

    func saveFitClaims() async -> String? {
        guard !isSaving else { return nil }
        guard canEditFitSignals else {
            errorMessage = "Refresh fit signals before saving."
            return nil
        }

        errorMessage = nil
        noticeMessage = nil

        guard selectedCoreFitClaimCount <= GroomerFitClaim.maximumActiveClaims else {
            errorMessage = Self.fitClaimLimitMessage
            return nil
        }

        let drafts = makeFitClaimDrafts()

        isSaving = true
        profileMutationRevision += 1
        defer { isSaving = false }

        do {
            let updatedClaims = try await repository.replaceFitClaims(
                groomerID: groomerID,
                drafts: drafts
            )
            populateFitClaims(with: updatedClaims)
            let successMessage = "Fit signals saved."
            noticeMessage = successMessage
            return successMessage
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save fit signals")
        } catch {
            errorMessage = message(for: .unavailable, action: "save fit signals")
        }
        return nil
    }

    private func makeFitClaimDrafts() -> [GroomerFitClaimDraft] {
        let supportedSignals = Set(PetFitSignal.allCases)
        let knownSignals = Set(
            fitClaims
                .map(\.signal)
                .filter { supportedSignals.contains($0) }
        )
        let selectedSignals = Set(
            GroomerFitClaim.availableSignals.filter {
                selectedFitClaimIDs.contains($0.id)
            }
        )

        return knownSignals
            .union(selectedSignals)
            .sorted(by: Self.sortFitSignals)
            .map { signal in
                GroomerFitClaimDraft(
                    signal: signal,
                    isActive: selectedFitClaimIDs.contains(signal.id)
                )
            }
    }

    func selectedFitClaimCount(
        where matches: (PetFitSignal) -> Bool
    ) -> Int {
        GroomerFitClaim.availableSignals.reduce(0) { count, signal in
            guard matches(signal), selectedFitClaimIDs.contains(signal.id) else {
                return count
            }
            return count + 1
        }
    }

    private func setSizeBandFitClaimRange(
        lowerIndex: Int,
        upperIndex: Int,
        clearsNotice: Bool
    ) {
        if clearsNotice {
            errorMessage = nil
            noticeMessage = nil
        }

        let range = Self.normalizedSizeBandRange(
            lowerIndex: lowerIndex,
            upperIndex: upperIndex
        )
        let sizeBandIDs = Set(Self.sizeBandSignals.map(\.id))
        selectedFitClaimIDs.subtract(sizeBandIDs)

        for index in range {
            selectedFitClaimIDs.insert(Self.sizeBandSignals[index].id)
        }
    }

    private static var fitClaimLimitMessage: String {
        "Choose up to \(GroomerFitClaim.maximumActiveClaims) core fit signals. Size experience does not use this limit."
    }

    static var sizeBandSignals: [PetFitSignal] {
        CustomerPetSizeCode.allCases.map { PetFitSignal.sizeBand($0) }
    }

    static var fullSizeBandRange: ClosedRange<Int> {
        0...(sizeBandSignals.count - 1)
    }

    static func normalizedSizeBandRange(
        lowerIndex: Int,
        upperIndex: Int
    ) -> ClosedRange<Int> {
        let maximumIndex = sizeBandSignals.count - 1
        let lowerBound = min(max(lowerIndex, 0), maximumIndex)
        let upperBound = min(max(upperIndex, 0), maximumIndex)
        return min(lowerBound, upperBound)...max(lowerBound, upperBound)
    }

    static func sizeBandRangeTitle(
        for range: ClosedRange<Int>
    ) -> String {
        let normalizedRange = normalizedSizeBandRange(
            lowerIndex: range.lowerBound,
            upperIndex: range.upperBound
        )
        let codes = CustomerPetSizeCode.allCases
        let lower = codes[normalizedRange.lowerBound]
        let upper = codes[normalizedRange.upperBound]
        return "\(lower.title)-\(upper.title) (\(lower.lowerWeightLabel)-\(upper.upperWeightLabel))"
    }

}
