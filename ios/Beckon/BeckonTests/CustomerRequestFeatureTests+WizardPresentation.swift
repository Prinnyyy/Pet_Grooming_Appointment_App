import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Beckon

extension CustomerRequestsStoreTests {
    @Test @MainActor
    func requestsRootUsesStableTitleWithoutSubtitle() {
        #expect(CustomerRequestsRootHeader.title == "Requests")
    }

    @Test @MainActor
    func homeRequestHeroStaysEnabledWhileRequestsReloadWhenPetsExist() {
        let loadingWithPet = CustomerHomeRequestHeroPresentation(
            hasPets: true,
            isRequestStoreBusy: true
        )
        let emptyPets = CustomerHomeRequestHeroPresentation(
            hasPets: false,
            isRequestStoreBusy: false
        )

        #expect(loadingWithPet.isStartRequestDisabled == false)
        #expect(emptyPets.isStartRequestDisabled == true)
    }

    @Test @MainActor
    func homeActiveRequestPresentationUsesAllCardsAndNeverShowsLoadingCard() {
        let customerID = UUID()
        let openRequest = Self.request(
            customerID: customerID,
            petID: UUID(),
            status: .open
        )
        let offerRequest = Self.request(
            customerID: customerID,
            petID: UUID(),
            status: .hasOffers
        )
        let cards = [
            CustomerRequestActionCardItem(request: openRequest, handoff: nil),
            CustomerRequestActionCardItem(request: offerRequest, handoff: nil),
        ]
        let populated = CustomerHomeActiveRequestPresentation(
            cards: cards,
            isLoading: true
        )
        let emptyLoading = CustomerHomeActiveRequestPresentation(
            cards: [],
            isLoading: true
        )

        #expect(populated.cards == cards)
        #expect(populated.shouldShowCarousel == true)
        #expect(populated.shouldShowEmptyText == false)
        #expect(populated.shouldShowLoadingCard == false)
        #expect(emptyLoading.cards.isEmpty)
        #expect(emptyLoading.shouldShowCarousel == false)
        #expect(emptyLoading.shouldShowEmptyText == true)
        #expect(emptyLoading.shouldShowLoadingCard == false)
    }

    @Test @MainActor
    func homeNextBookingPresentationUsesInlineEmptyTextInsteadOfCard() {
        let booking = Self.booking(
            requestID: UUID(),
            customerID: UUID()
        )
        let populated = CustomerHomeNextBookingPresentation(
            booking: booking,
            isLoading: false
        )
        let emptyLoading = CustomerHomeNextBookingPresentation(
            booking: nil,
            isLoading: true
        )
        let emptyLoaded = CustomerHomeNextBookingPresentation(
            booking: nil,
            isLoading: false
        )

        #expect(populated.shouldShowBooking == true)
        #expect(populated.shouldShowLoading == false)
        #expect(populated.shouldShowEmptyText == false)
        #expect(populated.shouldShowEmptyCard == false)
        #expect(emptyLoading.shouldShowBooking == false)
        #expect(emptyLoading.shouldShowLoading == false)
        #expect(emptyLoading.shouldShowEmptyText == true)
        #expect(emptyLoading.shouldShowEmptyCard == false)
        #expect(emptyLoaded.shouldShowBooking == false)
        #expect(emptyLoaded.shouldShowLoading == false)
        #expect(emptyLoaded.shouldShowEmptyText == true)
        #expect(emptyLoaded.shouldShowEmptyCard == false)
    }

    @Test @MainActor
    func homeNextBookingLoadFailureDoesNotCreateGlobalPrompt() {
        let presentation = CustomerHomeNextBookingPresentation(
            booking: nil,
            isLoading: false,
            loadErrorMessage: "We could not load bookings. Please try again."
        )

        #expect(presentation.shouldShowLoadError == false)
        #expect(presentation.shouldShowEmptyText == true)
        #expect(presentation.globalErrorPrompt == nil)
    }

    @Test @MainActor
    func requestEmptyCopyIsSharedByHomeAndRequests() {
        #expect(CustomerRequestEmptyCopy.title == "No Active Request")
        #expect(
            CustomerRequestEmptyCopy.message ==
                "Open quests and newly confirmed booking handoffs will appear here."
        )
    }

    @Test @MainActor
    func requestWizardStepsMatchPrototypeProgression() {
        #expect(CustomerRequestWizardStep.allCases.map(\.title) == [
            "Pet",
            "Service",
            "Time & Location",
            "Details",
            "Review",
        ])
        #expect(CustomerRequestWizardStep.pet.progress == 0.2)
        #expect(CustomerRequestWizardStep.review.progress == 1)
    }

    @Test @MainActor
    func requestWizardSeparatesServiceLocationFromAddressDetails() {
        #expect(CustomerRequestLocationSection.allCases.map(\.title) == [
            "Service Location",
            "Address Details",
        ])
        #expect(CustomerRequestLocationSection.groomingSetup.supportingText == nil)
        #expect(CustomerRequestLocationMode.groomerComesToCustomer.rawValue == "groomer_comes_to_customer")
        #expect(CustomerRequestLocationMode.customerComesToGroomer.rawValue == "customer_comes_to_groomer")
        let customerPresentations = CustomerRequestLocationMode.allCases.map {
            BeckonGroomingLocationModePresentation(mode: $0, perspective: .customer)
        }
        let groomerPresentations = CustomerRequestLocationMode.allCases.map {
            BeckonGroomingLocationModePresentation(mode: $0, perspective: .groomer)
        }

        #expect(customerPresentations.map(\.title) == ["My Home", "Groomer's Place"])
        #expect(groomerPresentations.map(\.title) == ["Customer's Home", "My Place"])
        #expect(customerPresentations.allSatisfy { $0.leadingIcon == nil })
        #expect(groomerPresentations.allSatisfy { $0.leadingIcon == nil })
        #expect(
            BeckonGroomingLocationSelectionPolicy.single.updatedSelection(
                [.groomerComesToCustomer],
                toggling: .customerComesToGroomer
            ) == [.customerComesToGroomer]
        )
        #expect(
            BeckonGroomingLocationSelectionPolicy.multiple.updatedSelection(
                [.groomerComesToCustomer],
                toggling: .customerComesToGroomer
            ) == [.groomerComesToCustomer, .customerComesToGroomer]
        )
    }

    @Test @MainActor
    func requestWizardStepLabelUsesProgressTrackWidth() {
        let layout = CustomerRequestWizardProgressLayout(
            backButtonWidth: 54,
            horizontalSpacing: 16,
            dynamicTypeSize: .large
        )

        #expect(layout.progressTrackLeadingOffset == 70)
        #expect(layout.doesStepLabelShareProgressTrackWidth == true)
        #expect(layout.usesStackedHeader == false)
        #expect(layout.usesSingleColumnChoices == false)
    }

    @Test @MainActor
    func requestWizardAccessibilityThreeUsesStackedSingleColumnLayout() {
        let layout = CustomerRequestWizardProgressLayout(
            backButtonWidth: 54,
            horizontalSpacing: 16,
            dynamicTypeSize: .accessibility3
        )

        #expect(layout.usesStackedHeader == true)
        #expect(layout.usesSingleColumnChoices == true)
    }

    @Test
    func dockedKeyboardMovesStationaryPageActionsFullyOffscreen() {
        let layout = BeckonKeyboardFormLayout(
            containerFrame: CGRect(x: 0, y: 0, width: 320, height: 800),
            keyboardFrame: CGRect(x: 0, y: 500, width: 320, height: 300)
        )

        #expect(layout.keyboardOverlap == 300)
        #expect(layout.stationaryPageActionOffset(actionHeight: 88) == 388)
        #expect(
            BeckonKeyboardFormLayout(
                containerFrame: CGRect(x: 0, y: 0, width: 320, height: 800),
                keyboardFrame: CGRect(x: 0, y: 800, width: 320, height: 0)
            ).stationaryPageActionOffset(actionHeight: 88) == 0
        )
    }

    @Test
    func floatingKeyboardDoesNotMoveStationaryPageActions() {
        let layout = BeckonKeyboardFormLayout(
            containerFrame: CGRect(x: 0, y: 0, width: 1024, height: 1366),
            keyboardFrame: CGRect(x: 420, y: 700, width: 520, height: 300)
        )

        #expect(layout.keyboardOverlap == 300)
        #expect(layout.stationaryPageActionOffset(actionHeight: 88) == 0)
    }

    @Test
    func requestWizardKeyboardRevealUsesMinimumObscuredEdge() {
        let layout = BeckonKeyboardFormLayout(
            containerFrame: CGRect(x: 0, y: 0, width: 320, height: 800),
            keyboardFrame: CGRect(x: 0, y: 500, width: 320, height: 300)
        )

        #expect(
            layout.revealAction(
                for: CGRect(x: 0, y: 300, width: 320, height: 80),
                clearance: 16
            ) == .none
        )
        #expect(
            layout.revealAction(
                for: CGRect(x: 0, y: 450, width: 320, height: 80),
                clearance: 16
            ) == .bottom
        )
        #expect(
            layout.revealAction(
                for: CGRect(x: 0, y: -10, width: 320, height: 80),
                clearance: 16
            ) == .top
        )
    }

    @Test
    func requestWizardKeyboardRevealHandlesBoundariesAndOversizedGroups() {
        let layout = BeckonKeyboardFormLayout(
            containerFrame: CGRect(x: 0, y: 0, width: 320, height: 800),
            keyboardFrame: CGRect(x: 0, y: 500, width: 320, height: 300)
        )

        #expect(
            layout.revealAction(
                for: CGRect(x: 0, y: 16, width: 320, height: 468),
                clearance: 16
            ) == .none
        )
        #expect(
            layout.revealAction(
                for: CGRect(x: 0, y: -20, width: 320, height: 540),
                clearance: 16
            ) == .top
        )
        #expect(
            layout.revealAction(
                for: CGRect(x: 0, y: -100, width: 320, height: 620),
                clearance: 16
            ) == .bottom
        )
    }

    @Test
    func requestWizardKeyboardRevealIgnoresUnrelatedKeyboardFrames() {
        let container = CGRect(x: 0, y: 0, width: 320, height: 800)
        let hiddenLayout = BeckonKeyboardFormLayout(
            containerFrame: container,
            keyboardFrame: CGRect(x: 0, y: 800, width: 320, height: 0)
        )
        let floatingLayout = BeckonKeyboardFormLayout(
            containerFrame: container,
            keyboardFrame: CGRect(x: 400, y: 500, width: 300, height: 250)
        )
        let obscuredTarget = CGRect(x: 0, y: 700, width: 320, height: 60)

        #expect(hiddenLayout.revealAction(for: obscuredTarget, clearance: 16) == .none)
        #expect(floatingLayout.revealAction(for: obscuredTarget, clearance: 16) == .none)
    }

    @Test
    func requestWizardKeyboardRevealUsesKeyboardAdjustedScrollViewport() throws {
        let layout = BeckonKeyboardFormLayout(
            containerFrame: CGRect(x: 0, y: 0, width: 320, height: 500),
            keyboardFrame: CGRect(x: 0, y: 500, width: 320, height: 300)
        )

        #expect(
            layout.revealAction(
                for: CGRect(x: 0, y: 450, width: 320, height: 80),
                clearance: 16
            ) == .bottom
        )
        let anchor = try #require(layout.scrollAnchor(for: .bottom, clearance: 16))
        #expect(anchor.y == 0.968)
    }

    @Test
    func requestWizardKeyboardFocusTargetMarkerIDsAreStableAndDistinct() {
        let line1 = BeckonKeyboardFocusTargetID("address.line1")
        let city = BeckonKeyboardFocusTargetID("address.city")

        #expect(line1.top == BeckonKeyboardFocusTargetID("address.line1").top)
        #expect(line1.bottom == BeckonKeyboardFocusTargetID("address.line1").bottom)
        #expect(line1.top != line1.bottom)
        #expect(line1.top != city.top)
        #expect(line1.bottom != city.bottom)
    }

    @Test @MainActor
    func requestWizardServiceOptionsMapToExistingServiceTypeField() {
        #expect(CustomerRequestServiceOption.allCases.count == 6)
        #expect(CustomerRequestServiceOption.fullGroom.title == "Full Groom")
        #expect(CustomerRequestServiceOption.fullGroom.rawValue == "full_groom")
        #expect(CustomerRequestServiceOption.bathAndBrush.rawValue == "bath_and_brush")
        #expect(CustomerRequestServiceOption.customRequest.subtitle == "Describe exactly what you need")
    }

    @Test @MainActor
    func requestWizardTimeWindowsApplyPresetRangesToSelectedDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let selectedDate = try #require(Self.isoDate("2026-06-19T12:00:00Z"))

        let morning = try #require(
            CustomerRequestTimeWindowOption.morning.range(
                on: selectedDate,
                calendar: calendar
            )
        )
        let afternoon = try #require(
            CustomerRequestTimeWindowOption.afternoon.range(
                on: selectedDate,
                calendar: calendar
            )
        )
        let evening = try #require(
            CustomerRequestTimeWindowOption.evening.range(
                on: selectedDate,
                calendar: calendar
            )
        )

        #expect(Self.hourMinute(morning.start, calendar: calendar) == [6, 0])
        #expect(Self.hourMinute(morning.end, calendar: calendar) == [11, 59])
        #expect(Self.hourMinute(afternoon.start, calendar: calendar) == [12, 0])
        #expect(Self.hourMinute(afternoon.end, calendar: calendar) == [16, 59])
        #expect(Self.hourMinute(evening.start, calendar: calendar) == [17, 0])
        #expect(Self.hourMinute(evening.end, calendar: calendar) == [21, 0])
        #expect(
            CustomerRequestTimeWindowOption.detailed.range(
                on: selectedDate,
                calendar: calendar
            ) == nil
        )
    }

    @Test @MainActor
    func requestWizardFlexibleTimeUsesAllDayWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let selectedDate = try #require(Self.isoDate("2026-06-19T12:00:00Z"))

        let flexible = CustomerRequestTimeWindowOption.flexibleRange(
            on: selectedDate,
            calendar: calendar
        )

        #expect(Self.hourMinute(flexible.start, calendar: calendar) == [0, 0])
        #expect(Self.hourMinute(flexible.end, calendar: calendar) == [23, 59])
    }

    @Test @MainActor
    func requestMatchingCopyExplainsPreferredTimeAsFlexible() {
        #expect(
            CustomerRequestMatchingCopy.customerReviewInfo ==
                "Your preferred time helps us find groomers with availability on that day. Groomers will send offers with a real appointment time for you to review."
        )
        #expect(
            CustomerRequestMatchingCopy.groomerOfferGuidance ==
                "Start from the customer's preferred window, then choose a time that is actually available on your schedule."
        )
    }

    @Test @MainActor
    func requestWizardTravelRangeClampsToSupportedMiles() {
        #expect(CustomerRequestTravelRange.clampedMiles(3) == 5)
        #expect(CustomerRequestTravelRange.clampedMiles(42) == 42)
        #expect(CustomerRequestTravelRange.clampedMiles(120) == 100)
    }

    @Test @MainActor
    func requestWizardReviewSummaryUsesCurrentRequestFields() {
        let summary = CustomerRequestWizardReviewPresentation(
            pet: "Mochi · Toy Poodle",
            service: "Full Groom",
            preferredTime: "Fri 19 · Afternoon",
            location: "Mobile · Seattle, WA 98101",
            notes: "Mochi needs a teddy-style trim."
        )

        #expect(summary.rows.map(\.title) == [
            "Pet",
            "Service",
            "Preferred Time",
            "Location",
            "Notes",
        ])
        #expect(summary.rows.map(\.value) == [
            "Mochi · Toy Poodle",
            "Full Groom",
            "Fri 19 · Afternoon",
            "Mobile · Seattle, WA 98101",
            "Mochi needs a teddy-style trim.",
        ])
    }

    @Test @MainActor
    func requestWizardFitInputPreviewDerivesSignalsFromSelectedPetAndService() async throws {
        let customerID = UUID()
        let pet = CustomerPet(
            id: UUID(),
            customerID: customerID,
            name: "Mochi",
            species: "Dog",
            breed: "Toy Poodle",
            coatType: nil,
            size: "S",
            weightLbs: 15,
            birthday: nil,
            temperament: "Gentle",
            medicalNotes: nil,
            groomingNotes: nil,
            isActive: true
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()
        store.startCreate()
        store.serviceType = .fullGroom

        #expect(store.requestFitInputSignals().map(\.id) == [
            "coat_type:curly_wavy",
            "breed_group:poodle",
            "size_band:S",
            "service_fit:curly_coat",
            "service_fit:full_haircut_styling",
        ])
    }

    @Test @MainActor
    func requestWizardFitInputPresentationUsesReadableReviewLabels() {
        let presentation = CustomerRequestWizardFitInputPresentation(
            signals: [
                .breedGroup(.poodle),
                .sizeBand(.s),
                .serviceFit(.curlyCoat),
            ]
        )

        #expect(presentation.chips.map(\.label) == [
            "Breed",
            "Pet Size",
            "Service Fit",
        ])
        #expect(presentation.chips.map(\.title) == [
            "Poodle",
            "S",
            "Curly Coat",
        ])
    }

    @Test @MainActor
    func requestWizardTimeStepRequiresCompleteAddressBeforeContinuing() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()
        store.startCreate()
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.streetAddress = "760"
        store.city = ""
        store.stateCode = nil
        store.zipCode = ""

        let validation = store.validateWizardStep(.time)

        #expect(validation.isValid == false)
        #expect(validation.message == "Complete the highlighted required fields before continuing.")
        #expect(validation.fields == [
            .streetAddress,
            .city,
            .state,
            .zipCode,
        ])
    }

    @Test @MainActor
    func sharedAddressSuggestionsDeduplicateRepeatedMapResults() {
        let result = BeckonAddressSuggestionBuilder.build(
            from: [
                BeckonAddressCompletion(
                    title: "760 Market Street",
                    subtitle: "San Francisco, CA",
                    completion: "first"
                ),
                BeckonAddressCompletion(
                    title: "760 Market Street",
                    subtitle: "San Francisco, CA",
                    completion: "duplicate"
                ),
                BeckonAddressCompletion(
                    title: "760 2nd Street",
                    subtitle: "San Francisco, CA",
                    completion: "second"
                ),
            ]
        )

        #expect(result.suggestions.map(\.title) == [
            "760 Market Street",
            "760 2nd Street",
        ])
        #expect(result.completionsByID[result.suggestions[0].id] == "first")
        #expect(result.completionsByID[result.suggestions[1].id] == "second")
    }

    @Test @MainActor
    func profileAddressAutofillRequiresCompleteTrimmedAddress() {
        let customerID = UUID()
        let completeProfile = CustomerProfileDetails(
            userID: customerID,
            nickname: "Prinny",
            avatarPath: nil,
            streetAddress: " 123 Pine Street ",
            city: " Seattle ",
            stateCode: .washington,
            zipCode: " 98101 ",
            contactEmail: nil,
            phoneNumber: nil
        )

        #expect(CustomerProfileAddressAutofill.make(from: completeProfile) == CustomerProfileAddressAutofill(
            streetAddress: "123 Pine Street",
            city: "Seattle",
            stateCode: .washington,
            zipCode: "98101"
        ))

        let incompleteProfile = CustomerProfileDetails(
            userID: customerID,
            nickname: "Prinny",
            avatarPath: nil,
            streetAddress: "123 Pine Street",
            city: "",
            stateCode: .washington,
            zipCode: "98101",
            contactEmail: nil,
            phoneNumber: nil
        )

        #expect(CustomerProfileAddressAutofill.make(from: incompleteProfile) == nil)
    }

    @Test @MainActor
    func requestWizardAddressSuggestionsDeduplicateRepeatedMapResults() {
        let result = CustomerRequestAddressSuggestionBuilder.build(
            from: [
                CustomerRequestAddressCompletion(
                    title: "760 Market Street",
                    subtitle: "San Francisco, CA",
                    completion: "first"
                ),
                CustomerRequestAddressCompletion(
                    title: "760 Market Street",
                    subtitle: "San Francisco, CA",
                    completion: "duplicate"
                ),
                CustomerRequestAddressCompletion(
                    title: "760 2nd Street",
                    subtitle: "San Francisco, CA",
                    completion: "second"
                ),
            ]
        )

        #expect(result.suggestions.map(\.title) == [
            "760 Market Street",
            "760 2nd Street",
        ])
        #expect(result.completionsByID[result.suggestions[0].id] == "first")
        #expect(result.completionsByID[result.suggestions[1].id] == "second")
    }

    @Test
    func requestAddressInputRulesRejectUnsupportedCharactersBeforeDisplay() {
        #expect(
            BeckonAddressInputRule.street.sanitize("760 S Harbor Blvd #12-B / Rear")
                == "760 S Harbor Blvd #12-B / Rear"
        )
        #expect(
            BeckonAddressInputRule.street.sanitize("760 S Harbor Blvd\n<script>")
                == "760 S Harbor Blvdscript"
        )
        #expect(BeckonAddressInputRule.city.sanitize("Rancho Santa Margarita") == "Rancho Santa Margarita")
        #expect(BeckonAddressInputRule.city.sanitize("O'Fallon-2!") == "O'Fallon-2")
        #expect(BeckonAddressInputRule.zipCode.sanitize("92A80-1") == "92801")
    }

    @Test
    func requestAddressQuerySearchesTheDeliverableAddressAndPreservesUnit() {
        let unit = BeckonAddressQuery(street: "760 S Harbor Blvd UNIT 2410")
        let apartment = BeckonAddressQuery(street: "123 Pine Street, Apt. 5B")
        let plain = BeckonAddressQuery(street: "456 Cedar Avenue")

        #expect(unit.searchStreet == "760 S Harbor Blvd")
        #expect(unit.secondaryUnit == "UNIT 2410")
        #expect(unit.appendingSecondary(to: "760 South Harbor Boulevard") == "760 South Harbor Boulevard UNIT 2410")
        #expect(apartment.searchStreet == "123 Pine Street")
        #expect(apartment.secondaryUnit == "Apt. 5B")
        #expect(plain.searchStreet == "456 Cedar Avenue")
        #expect(plain.secondaryUnit == nil)
    }

    @Test
    func secondaryAddressParserMovesOnlyCompleteSupportedSuffixes() {
        let cases = [
            ("770 S Harbor Blvd Apt 5B", "Apt 5B"),
            ("770 S Harbor Blvd, Apartment 5B", "Apartment 5B"),
            ("770 S Harbor Blvd Unit 2410", "Unit 2410"),
            ("770 S Harbor Blvd Suite 300", "Suite 300"),
            ("770 S Harbor Blvd Ste 300", "Ste 300"),
            ("770 S Harbor Blvd Floor 2", "Floor 2"),
            ("770 S Harbor Blvd Fl 2", "Fl 2"),
            ("770 S Harbor Blvd Building A", "Building A"),
            ("770 S Harbor Blvd Bldg A", "Bldg A"),
            ("770 S Harbor Blvd Room 12", "Room 12"),
            ("770 S Harbor Blvd Rm 12", "Rm 12"),
            ("770 S Harbor Blvd #2410", "#2410"),
        ]

        for (line1, expectedLine2) in cases {
            let result = BeckonSecondaryAddressParser.parse(line1: line1, line2: "")
            #expect(result.line1 == "770 S Harbor Blvd")
            #expect(result.line2 == expectedLine2)
            #expect(result.movedSecondary == expectedLine2)
            #expect(result.conflict == nil)
        }
    }

    @Test
    func secondaryAddressParserLeavesPartialSuffixesInLineOne() {
        for line1 in [
            "770 S Harbor Blvd U",
            "770 S Harbor Blvd Un",
            "770 S Harbor Blvd Unit",
            "770 S Harbor Blvd A",
            "770 S Harbor Blvd Apt",
        ] {
            let result = BeckonSecondaryAddressParser.parse(line1: line1, line2: "")
            #expect(result.line1 == line1)
            #expect(result.line2.isEmpty)
            #expect(result.movedSecondary == nil)
            #expect(result.conflict == nil)
        }
    }

    @Test
    func secondaryAddressParserNeverOverwritesOccupiedLineTwo() {
        let result = BeckonSecondaryAddressParser.parse(
            line1: "770 S Harbor Blvd Unit 2410",
            line2: "Suite 300"
        )

        #expect(result.line1 == "770 S Harbor Blvd Unit 2410")
        #expect(result.line2 == "Suite 300")
        #expect(result.movedSecondary == nil)
        #expect(result.conflict == BeckonSecondaryAddressConflict(
            line1Secondary: "Unit 2410",
            existingLine2: "Suite 300"
        ))
    }

    @Test
    func materialAddressEditsInvalidateAConfirmedResolution() {
        let accepted = BeckonAddressInput(
            line1: "770 S Harbor Blvd",
            line2: "Unit 2410",
            city: "Fullerton",
            stateCode: .california,
            postalCode: "92832",
            countryCode: "US"
        )
        let confirmed = BeckonConfirmedAddress(
            entered: accepted,
            accepted: accepted,
            provider: "apple_maps",
            placeID: nil,
            coordinate: BeckonAddressCoordinate(latitude: 33.8703, longitude: -117.9242),
            resolutionSource: "autocomplete_selection",
            confirmedAt: Date(timeIntervalSince1970: 1)
        )

        var line2Only = accepted
        line2Only.line2 = "Unit 2500"
        var changedStreet = accepted
        changedStreet.line1 = "780 S Harbor Blvd"
        var changedCity = accepted
        changedCity.city = "Anaheim"

        #expect(confirmed.isBuildingResolutionValid(for: line2Only))
        #expect(!confirmed.isBuildingResolutionValid(for: changedStreet))
        #expect(!confirmed.isBuildingResolutionValid(for: changedCity))
    }

    @Test
    func compatibleAddressQueriesRetainVisibleSuggestionsWhileLoading() {
        #expect(BeckonAddressSuggestionRetention.shouldRetain(
            previousQuery: "770 S",
            nextQuery: "770 S H"
        ))
        #expect(BeckonAddressSuggestionRetention.shouldRetain(
            previousQuery: "770 S Harbor",
            nextQuery: "770 S H"
        ))
        #expect(!BeckonAddressSuggestionRetention.shouldRetain(
            previousQuery: "770 S Harbor",
            nextQuery: "123 Pine"
        ))

        let base = BeckonAddressQuery(street: "770 S Harbor Blvd")
        let withUnit = BeckonAddressQuery(street: "770 S Harbor Blvd Unit 2410")
        #expect(base.searchStreet == withUnit.searchStreet)
    }

    @Test @MainActor
    func localizedMapCompletionIsPresentedDirectlyWithoutBatchResolution() {
        let result = BeckonAddressSuggestionBuilder.build(
            from: [
                BeckonAddressCompletion(
                    title: "南港大道760号",
                    subtitle: "加利福尼亚州富勒顿",
                    completion: "localized"
                ),
            ]
        )
        #expect(result.suggestions == [
            BeckonAddressSuggestion(
                id: "南港大道760号|加利福尼亚州富勒顿",
                title: "南港大道760号",
                subtitle: "加利福尼亚州富勒顿"
            ),
        ])
        #expect(result.completionsByID[result.suggestions[0].id] == "localized")
    }

    @Test @MainActor
    func bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let booking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let presentation = CustomerRequestProgressCardPresentation(
            request: bookedRequest,
            handoff: CustomerRequestBookingHandoff(
                request: bookedRequest,
                booking: booking
            )
        )

        #expect(presentation.headline == "Booking\nConfirmed")
        #expect(presentation.subtitle == "Full Groom for Mochi")
        #expect(presentation.infoLines == [
            CustomerRequestProgressCardPresentation.InfoLine(
                systemImage: "calendar",
                text: Self.compactDisplayRange(
                    from: booking.scheduledStart,
                    to: booking.scheduledEnd
                )
            ),
            CustomerRequestProgressCardPresentation.InfoLine(
                systemImage: "mappin.and.ellipse",
                text: "Seattle, WA 98101"
            ),
        ])
    }

    @Test @MainActor
    func openRequestCardPresentationUsesTitleCaseHeadlineAndCompactTimeRange() async throws {
        let customerID = UUID()
        let request = Self.request(
            customerID: customerID,
            petID: UUID(),
            status: .open
        )
        let presentation = CustomerRequestProgressCardPresentation(
            request: request,
            handoff: nil
        )

        #expect(presentation.headline == "Open\nRequest")
        #expect(presentation.infoLines.first == CustomerRequestProgressCardPresentation.InfoLine(
            systemImage: "calendar",
            text: Self.compactDisplayRange(
                from: request.preferredStart,
                to: request.preferredEnd
            )
        ))
        #expect(presentation.infoLines.first?.text.contains("2026") == false)
        #expect(presentation.infoLines.first?.text.contains("\n") == false)
    }

    @Test @MainActor
    func clearNoticeOnlyDismissesMatchingMessage() async throws {
        let store = CustomerRequestsStore(
            customerID: UUID(),
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        store.noticeMessage = "Request cancelled."
        store.clearNotice(ifCurrent: "Offer accepted. Booking confirmed.")
        #expect(store.noticeMessage == "Request cancelled.")

        store.clearNotice(ifCurrent: "Request cancelled.")
        #expect(store.noticeMessage == nil)
    }

}
