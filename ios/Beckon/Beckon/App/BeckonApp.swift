import SwiftUI
import UIKit

@main
struct BeckonApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(CustomerPushNotificationAppDelegate.self)
    private var customerPushNotificationAppDelegate

    private let launch: AppLaunchConfiguration
    @State private var composition: AppComposition?
    @State private var pendingAuthURL: URL?

    init() {
        launch = AppLaunchConfiguration()
        // First mount the lightweight launch scene. Build services after SwiftUI gets a turn to present it.
        UIScrollView.appearance().showsVerticalScrollIndicator = false
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--beckon-ui-test-customer-navigation") {
                // Reuse the existing isolated repositories; never construct production services for this UI test entry.
                CustomerSandboxScreenHost(screen: .tabs, state: .loaded)
            } else { appContent }
            #else
            appContent
            #endif
        }
    }

    @ViewBuilder private var appContent: some View {
            if !launch.isSwiftUIPreview {
                AppRootView(
                    route: .authentication,
                    authenticationBootstrapState: composition?.authenticationBootstrapState ?? .ready,
                    authenticationStore: composition?.authenticationStore,
                    profileRepository: composition?.profileRepository,
                    customerProfileRepository: composition?.customerProfileRepository,
                    customerPetRepository: composition?.customerPetRepository,
                    customerRequestRepository: composition?.customerRequestRepository,
                    customerNotificationRepository: composition?.customerNotificationRepository,
                    bookingRepository: composition?.bookingRepository,
                    chatRepository: composition?.chatRepository,
                    groomerProfileRepository: composition?.groomerProfileRepository,
                    groomerRequestRepository: composition?.groomerRequestRepository,
                    groomerNotificationRepository: composition?.groomerNotificationRepository,
                    operationalEventRecorder: composition?.operationalEventRecorder
                )
                .environment(\.customerMarketplaceServices, composition?.customerMarketplaceServices)
                .scrollIndicators(.hidden)
                .transaction { transaction in
                    if launch.testOps.disablesAnimations {
                        transaction.animation = nil
                    }
                }
                .task {
                    guard composition == nil else { return }
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    let services = AppComposition(launchConfiguration: launch)
                    composition = services
                    services.operationalEventRecorder.beginLaunch()
                    if let url = pendingAuthURL {
                        pendingAuthURL = nil
                        await services.authenticationStore?.handleAuthCallback(url)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    composition?.operationalEventRecorder.recordScenePhase(newPhase)
                    if newPhase == .active {
                        Task { _ = await AppointmentReminderScheduler.shared.refresh() }
                    }
                }
                .onOpenURL { url in
                    if let store = composition?.authenticationStore {
                        Task { await store.handleAuthCallback(url) }
                    } else { pendingAuthURL = url }
                }
            }
    }
}
