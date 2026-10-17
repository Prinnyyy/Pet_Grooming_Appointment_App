import Foundation
import Testing
@testable import Beckon

struct BeckonDateTimeFormatterTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let newYork = TimeZone(identifier: "America/New_York")!
    private let referenceDate = Date(timeIntervalSince1970: 1792242000)

    @Test func sameZoneMergesDateAndMeridiem() {
        let value = BeckonDateTimeFormatter.interval(from: "2026-10-24T17:00:00Z", to: "2026-10-24T18:00:00Z",
            serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: losAngeles, referenceDate: referenceDate)
        #expect(value.text == "Sat, Oct 24 · 10:00–11:00 AM")
        #expect(value.timeZoneNotice == nil)
        #expect(value.accessibilityLabel.contains(losAngeles.identifier))
        #expect(!value.text.contains(losAngeles.identifier))
    }

    @Test func crossZoneAppendsAbbreviationOnce() {
        let value = BeckonDateTimeFormatter.interval(from: "2026-10-24T17:00:00Z", to: "2026-10-24T18:00:00Z",
            serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: newYork, referenceDate: referenceDate)
        #expect(value.text == "Sat, Oct 24 · 10:00–11:00 AM PDT")
    }

    @Test func crossingNoonKeepsBothMeridiems() {
        let value = BeckonDateTimeFormatter.interval(from: "2026-10-24T18:30:00Z", to: "2026-10-24T19:30:00Z",
            serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: losAngeles, referenceDate: referenceDate)
        #expect(value.text == "Sat, Oct 24 · 11:30 AM–12:30 PM")
    }

    @Test func crossingMidnightKeepsBothDates() {
        let value = BeckonDateTimeFormatter.interval(from: "2026-10-25T06:30:00Z", to: "2026-10-25T07:30:00Z",
            serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: losAngeles, referenceDate: referenceDate)
        #expect(value.text == "Sat, Oct 24 · 11:30 PM – Sun, Oct 25 · 12:30 AM")
    }

    @Test func fallBackDistinguishesRepeatedHoursEvenInDeviceZone() {
        let value = BeckonDateTimeFormatter.interval(from: "2026-11-01T08:30:00Z", to: "2026-11-01T09:30:00Z",
            serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: losAngeles, referenceDate: referenceDate)
        #expect(value.text == "Sun, Nov 1 · 1:30 AM PDT–1:30 AM PST")
        let first = BeckonDateTimeFormatter.instant(from: "2026-11-01T08:30:00Z",
            serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: losAngeles, referenceDate: referenceDate)
        let last = BeckonDateTimeFormatter.instant(from: "2026-11-01T09:30:00Z",
            serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: losAngeles, referenceDate: referenceDate)
        #expect(first.text != last.text)
    }

    @Test func springForwardShowsActualOffsets() {
        let value = BeckonDateTimeFormatter.interval(from: "2026-03-08T09:30:00Z", to: "2026-03-08T10:30:00Z",
            serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: losAngeles, referenceDate: referenceDate)
        #expect(value.text == "Sun, Mar 8 · 1:30 AM PST–3:30 AM PDT")
    }

    @Test func unknownZoneNeverInventsServiceLocalTime() {
        for zone in [nil, "Invalid/Zone"] as [String?] {
            let value = BeckonDateTimeFormatter.interval(from: "2026-10-24T17:00:00Z", to: "2026-10-24T18:00:00Z",
                serviceTimeZoneIdentifier: zone, deviceTimeZone: losAngeles, referenceDate: referenceDate)
            #expect(value.timeZoneNotice == "Time zone not confirmed")
            #expect(value.summary == "Time unavailable\nTime zone not confirmed")
            #expect(!value.summary.contains("2026-10-24T"))
        }
    }

    @Test func malformedOrInvertedIntervalsDoNotLeakRawTimestamps() {
        for pair in [("broken", "2026-10-24T18:00:00Z"), ("2026-10-24T18:00:00Z", "2026-10-24T17:00:00Z")] {
            let value = BeckonDateTimeFormatter.interval(from: pair.0, to: pair.1,
                serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: losAngeles, referenceDate: referenceDate)
            #expect(value.text == "Time unavailable")
        }
    }

    @Test func crossingYearsShowsBothYears() {
        let value = BeckonDateTimeFormatter.interval(from: "2027-01-01T07:30:00Z", to: "2027-01-01T08:30:00Z",
            serviceTimeZoneIdentifier: losAngeles.identifier, deviceTimeZone: losAngeles, referenceDate: referenceDate)
        #expect(value.text.contains("2026"))
        #expect(value.text.contains("2027"))
    }
}
