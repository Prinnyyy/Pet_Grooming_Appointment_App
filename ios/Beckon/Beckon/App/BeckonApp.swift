import SwiftUI
import UIKit

@main
struct BeckonApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(CustomerPushNotificationAppDelegate.self)
    private var customerPushNotificationAppDelegate

    private let composition = AppComposition()

    init() {
        UIScrollView.appearance().showsVerticalScrollIndicator = false
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                route: .authentication,
                authenticationBootstrapState: composition.authenticationBootstrapState,
                authenticationStore: composition.authenticationStore,
                profileRepository: composition.profileRepository,
                customerProfileRepository: composition.customerProfileRepository,
                customerPetRepository: composition.customerPetRepository,
                customerRequestRepository: composition.customerRequestRepository,
                customerNotificationRepository: composition.customerNotificationRepository,
                bookingRepository: composition.bookingRepository,
                chatRepository: composition.chatRepository,
                groomerProfileRepository: composition.groomerProfileRepository,
                groomerRequestRepository: composition.groomerRequestRepository,
                groomerNotificationRepository: composition.groomerNotificationRepository,
                operationalEventRecorder: composition.operationalEventRecorder
            )
            .transaction { transaction in
                if composition.launchConfiguration.testOps.disablesAnimations {
                    transaction.animation = nil
                }
            }
            .task {
                composition.operationalEventRecorder.beginLaunch()
            }
            .onChange(of: scenePhase) { _, newPhase in
                composition.operationalEventRecorder.recordScenePhase(newPhase)
            }
            .onOpenURL { url in
                Task {
                    await composition.authenticationStore?.handleAuthCallback(url)
                }
            }
        }
    }
}
