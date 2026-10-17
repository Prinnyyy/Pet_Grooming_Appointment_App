import SwiftUI

struct CustomerRequestProgressView: View {
    let requestID: UUID
    let store: CustomerRequestDistributionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let progress = store.progressByRequestID[requestID] {
                Text(progress.waitingTitle())
                    .font(DesignTokens.Typography.headline)
                    .accessibilityIdentifier("customer.request.progress")
                Text("\(progress.validOfferCount) valid offers")
                    .font(DesignTokens.Typography.supporting).accessibilityIdentifier("discovery.valid-offer-count")
                if progress.status.isOpenForOffers && progress.expiresAt > Date() {
                    Toggle("Request pool", isOn: Binding(get: { progress.poolEnabled }, set: { enabled in
                        Task { _ = await store.setPool(requestID: requestID, enabled: enabled) }
                    }))
                    .disabled(store.mutatingIDs.contains(requestID) || store.uncertainRequestIDs.contains(requestID))
                    .accessibilityIdentifier("discovery.pool")
                    Text("Request closes \(progress.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                ForEach(progress.invitations) { invitation in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(invitation.profile?.businessName ?? "Groomer unavailable").font(DesignTokens.Typography.supporting.weight(.medium))
                            Text(store.state(requestID: requestID, groomerID: invitation.groomerID, seed: invitation.state).title)
                                .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                            if invitation.state == .awaitingResponse && invitation.replyBy > Date() {
                                Text("Reply by \(invitation.replyBy.formatted(date: .abbreviated, time: .shortened))")
                                    .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                            }
                        }
                        Spacer(minLength: 8)
                        if invitation.state == .awaitingResponse && invitation.replyBy > Date() && progress.expiresAt > Date() {
                            Button { Task { _ = await store.withdraw(requestID: requestID, groomerID: invitation.groomerID) } }
                                label: { Image(systemName: "xmark.circle").frame(width: 44, height: 44) }
                                .accessibilityLabel("Withdraw invitation to \(invitation.profile?.businessName ?? "groomer")")
                                .help("Withdraw invitation")
                                .accessibilityIdentifier("discovery.withdraw.\(invitation.groomerID.uuidString)")
                                .disabled(store.mutatingIDs.contains(requestID))
                        }
                    }
                }
                if progress.evaluationPending { Label("Checking more availability", systemImage: "clock").font(DesignTokens.Typography.caption) }
                Text("Checked \(progress.checkedAt.formatted(date: .omitted, time: .shortened))")
                    .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityIdentifier("discovery.checked-at")
                    .accessibilityValue(progress.checkedAt.ISO8601Format())
            } else {
                ProgressView("Checking request status...")
            }
            if let error = store.error { Text(error.message).font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.errorText) }
            if store.uncertainRequestIDs.contains(requestID) {
                Button("Retry Update", systemImage: "arrow.clockwise") { Task { _ = await store.retry(requestID: requestID) } }
            }
        }
    }
}
