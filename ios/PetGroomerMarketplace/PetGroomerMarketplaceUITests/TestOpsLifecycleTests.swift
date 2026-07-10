import XCTest

final class TestOpsLifecycleTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSeededDualRoleMarketplaceLifecycle() throws {
        let context = try TestOpsLifecycleContext.fromEnvironment()
        let customer = try TestOpsSeedAccount.fromEnvironment(role: .customer)
        let groomer = try TestOpsSeedAccount.fromEnvironment(role: .groomer)
        let driver = TestOpsUIFlowDriver()

        driver.launchSignedOut()
        driver.signIn(customer)
        let requestReference = driver.publishTaggedRequest(context)

        driver.launchSignedOut()
        driver.signIn(groomer)
        driver.submitTaggedOffer(
            context,
            expectedRequestReference: requestReference
        )

        driver.launchSignedOut()
        driver.signIn(customer)
        driver.acceptOfferAndSendChat(
            context,
            requestReference: requestReference
        )

        driver.launchSignedOut()
        driver.signIn(groomer)
        driver.verifyChatAndCompleteBooking(
            context,
            requestReference: requestReference
        )

        driver.launchSignedOut()
        driver.signIn(customer)
        driver.submitTaggedReview(
            context,
            requestReference: requestReference
        )
    }
}
