import AdSupport
import AppTrackingTransparency
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let identifier = ATTrackingManager.trackingAuthorizationStatus == .authorized
            ? ASIdentifierManager.shared().advertisingIdentifier.uuidString
            : (UIDevice.current.identifierForVendor?.uuidString ?? "")
        print("[DebugBadge] Identifier: \(identifier)")

        AudioManager.shared.startBGM()
        AdsManager.shared.start()
        AdsManager.shared.requestTrackingIfNeeded()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
