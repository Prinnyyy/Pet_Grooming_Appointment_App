// The blocks of the merged request page that are the groomer's own (design). The page is the owner's Grooming detail seen from the
// other side (the hero with its path, the cards that say what needs the person, the manage rows, the activity are that page's), and
// what is here is what a groomer reads about a request and the offer they made for it: why it matched, what was asked, the offer as
// a record, and the booking it became. The page that holds them is GroomerRequestDetailView.swift.
import SwiftUI


// MARK: Why it matched

/// Why the request reached this groomer: where it came from and the evidence. A match that is only "New" says nothing the path
/// does not, so with no source and no evidence the block is not there. What holds an answer back (still being checked, a species to
/// confirm) is the needs card's, not this block's.
struct GroomerWhyMatched: View {
    let matched: GroomerMatchedRequest

    var body: some View {
        let source = matched.request.distributionSourceTitle
        let evidence = matched.fitEvidencePresentation
        if source != nil || evidence != nil {
            DesignSection(title: "Why this matched", systemImage: "sparkles") {
                if let source {
                    DesignFactRow(systemImage: "paperplane", title: "Source", value: source)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(source)
                        .accessibilityIdentifier("groomer.requests.source")
                }
                if let evidence {
                    BeckonFitEvidenceBlock(scoreText: evidence.scoreText, summary: evidence.listSummary,
                        reason: evidence.reason, isCompact: false)
                }
            }
        }
    }
}


// MARK: What was asked

/// When and where the customer asked for the grooming. The pet is its own block (`GroomerPetCard`).
struct GroomerRequestDetails: View {
    let request: GroomerMatchedGroomingRequest

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "The request", systemImage: "doc.text.fill")
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DesignFactRow(systemImage: "clock", title: "Preferred time", value: request.preferredTimePresentation.summary)
                DesignFactRow(systemImage: "location.fill",
                    title: BeckonGroomingLocationModePresentation(mode: request.locationMode, perspective: .groomer).title,
                    value: request.locationSummary)
                if request.locationMode == .customerComesToGroomer, let miles = request.travelRadiusMiles {
                    DesignFactRow(systemImage: "point.topleft.down.curvedto.point.bottomright.up", title: "Travel radius",
                        value: "\(miles) miles")
                }
            }
            .designCardBody()
        }
        .accessibilityIdentifier("groomer.requests.details")
    }
}


// MARK: The offer

/// An offer the groomer made, as a record: the price large, the time, when it ends, and the groomer's message. How the customer
/// answered is said above it (the hero, the booked card, the needs card), so the answer is only a chip here over an earlier offer,
/// which nothing else on the page speaks for. The one that is waiting is withdrawn from the page's manage rows.
struct GroomerOfferRecord: View {
    let offer: GroomerOffer
    /// "Your offer", or "Your earlier offer" over the one before the form of a new one.
    var title = "Your offer"
    let now: Date
    /// The answer to the offer, as a chip beside the price.
    var showsStatus = false
    /// The time the groomer proposed. Once it is a booking the booked card says it, so the page leaves it out here.
    var showsTime = true

    private var zone: String? { offer.agreementSnapshot?.serviceTimeZoneIdentifier ?? offer.serviceTimeZoneIdentifier }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: title, systemImage: "tag.fill")
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                    Text(offer.priceSummary)
                        .font(DesignTokens.Typography.Expressive.display)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                    if showsStatus {
                        Spacer(minLength: DesignTokens.Spacing.sm)
                        BeckonStatusChip(offer.statusPresentation(now: now))
                    }
                }
                if showsTime {
                    DesignFactRow(systemImage: "calendar", title: "Your proposed time",
                        value: BeckonDateTimeFormatter.interval(from: offer.proposedStart, to: offer.proposedEnd,
                            serviceTimeZoneIdentifier: zone).summary)
                }
                if offer.status == .pending {
                    DesignFactRow(systemImage: "hourglass", title: "The offer ends",
                        value: GroomingRequestDateFormatting.displayString(from: offer.expiresAt, serviceTimeZoneIdentifier: zone))
                }
                if let message = offer.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DesignFactRow(systemImage: "text.bubble", title: "Your message", value: message)
                }
            }
            .designCardBody()
        }
        .accessibilityIdentifier("groomer.requests.offer")
    }
}


// MARK: The booking

/// The customer accepted: the booking it became, and the way to it. The booking is a page of its own (the Schedule's), so this card
/// is the hand-over.
struct GroomerBookedCard: View {
    let booking: Booking?
    var onOpenBooking: ((Booking) -> Void)?

    var body: some View {
        GroomingNeedsCard(title: "Booked", systemImage: "checkmark.seal.fill", tone: .info) {
            if let booking {
                DesignFactRow(systemImage: "calendar", title: "Appointment", value: booking.scheduledTimeSummary)
                DesignFactRow(systemImage: "number", title: "Booking", value: "#\(booking.referenceCode)")
                if let onOpenBooking {
                    GroomingActionButton(title: "View booking", systemImage: "arrow.right",
                        identifier: "groomer.requests.view-booking") { onOpenBooking(booking) }
                }
            } else {
                Text("The customer accepted your offer. The booking is being set up: pull down to check again.")
                    .designSupportingText()
            }
        }
        .accessibilityIdentifier("groomer.requests.booked")
    }
}
