import UIKit
import AppTrackingTransparency

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

final class AdsManager: NSObject {

    static let shared = AdsManager()

    let bannerUnitID = "ca-app-pub-1615601076718034/7238791375"

    func start() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        #endif
    }

    func requestTrackingIfNeeded() {
        if #available(iOS 14, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
        }
    }

    func makeBanner(rootViewController: UIViewController) -> UIView {
        #if canImport(GoogleMobileAds)
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = bannerUnitID
        banner.rootViewController = rootViewController
        banner.load(Request())
        return banner
        #else
        let placeholder = UIView()
        placeholder.backgroundColor = .clear
        return placeholder
        #endif
    }

}
