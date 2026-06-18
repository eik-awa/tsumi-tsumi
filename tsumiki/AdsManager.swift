import UIKit
import AppTrackingTransparency

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

final class AdsManager: NSObject {

    static let shared = AdsManager()

    let bannerUnitID = "ca-app-pub-1615601076718034/7238791375"
    let interstitialUnitID = "ca-app-pub-1615601076718034/4421056349"

    private var gameCount = 0
    private let gamesPerInterstitial = 3

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    private var interstitialDismissCompletion: (() -> Void)?
    #endif

    func start() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        loadInterstitial()
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

    func recordGameEnd() {
        gameCount += 1
    }

    func showInterstitialIfReady(from viewController: UIViewController, completion: @escaping () -> Void) {
        #if canImport(GoogleMobileAds)
        guard gameCount >= gamesPerInterstitial, let ad = interstitial else {
            completion()
            return
        }
        gameCount = 0
        interstitialDismissCompletion = completion
        ad.fullScreenContentDelegate = self
        ad.present(from: viewController)
        #else
        completion()
        #endif
    }

    #if canImport(GoogleMobileAds)
    private func loadInterstitial() {
        InterstitialAd.load(with: interstitialUnitID, request: Request()) { [weak self] ad, error in
            guard error == nil else { return }
            self?.interstitial = ad
        }
    }
    #endif
}

#if canImport(GoogleMobileAds)
extension AdsManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitial = nil
        loadInterstitial()
        interstitialDismissCompletion?()
        interstitialDismissCompletion = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitial = nil
        loadInterstitial()
        interstitialDismissCompletion?()
        interstitialDismissCompletion = nil
    }
}
#endif
