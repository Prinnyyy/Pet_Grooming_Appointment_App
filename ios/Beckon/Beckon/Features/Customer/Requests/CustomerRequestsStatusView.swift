import Foundation
import SwiftUI

struct CustomerRequestsStatusView: View {
    let store: CustomerRequestsStore

    var body: some View {
        BeckonGlobalFeedbackForwarder(
            noticeMessage: store.noticeMessage,
            clearNotice: { message in
                store.clearNotice(ifCurrent: message)
            },
            error: errorPrompt,
            progress: progressPrompt
        )
    }

    private var errorPrompt: BeckonGlobalFeedbackError? {
        guard let errorMessage = store.errorMessage,
              !store.isShowingWizard else { return nil }
        return BeckonGlobalFeedbackError(
            scope: .page("customer.requests"),
            sourceKey: "customer.requests.error",
            title: "We could not update requests",
            message: errorMessage
        )
    }

    private var progressPrompt: BeckonGlobalFeedbackProgress? {
        guard store.isSubmitting else { return nil }
        return BeckonGlobalFeedbackProgress(
            scope: .operation("customer.requests.publish"),
            sourceKey: "customer.requests.publish-progress",
            title: "Publishing…",
            tone: .customer
        )
    }
}
