import UIKit
import AppTrackingTransparency
import IronSource

final class AdsManager: NSObject {

    static let shared = AdsManager()

    private let appKey = "27a7c3f75"
    let bannerAdUnitID   = "7lke5bc7kby2v4mc"
    // TODO: LevelPlay ダッシュボードの実際のリワード Ad Unit ID に差し替える
    let rewardedAdUnitID = "z8e5t2halyz5pncg"

    private(set) var isInitialized = false
    private var hasStarted = false
    private var completions: [() -> Void] = []

    // MARK: - Rewarded Ad

    private var rewardedAd: LPMRewardedAd?
    private var rewardedOnResult: ((Bool) -> Void)?
    private var rewardedPending: ((Bool) -> Void)?
    private var rewardedIsLoading = false

    func start(completion: (() -> Void)? = nil) {
        if let completion {
            if isInitialized {
                completion()
            } else {
                completions.append(completion)
            }
        }
        guard !hasStarted else { return }
        hasStarted = true

        #if targetEnvironment(simulator)
        print("[AdsManager] simulator: skipping SDK init")
        return
        #else
        if DebugDeviceConfig.isDebugDevice {
            LevelPlay.setMetaDataWithKey("is_test_suite", value: "enable")
        }

        let request = LPMInitRequestBuilder(appKey: appKey).build()
        LevelPlay.initWith(request) { [weak self] _, _ in
            guard let self else { return }
            self.isInitialized = true
            DispatchQueue.main.async {
                self.completions.forEach { $0() }
                self.completions.removeAll()
                self.preloadRewarded()
            }
        }
        #endif
    }

    func requestTrackingIfNeeded() {
        if #available(iOS 14, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
        }
    }

    // MARK: - Banner

    func makeBanner(rootViewController: UIViewController) -> UIView {
        let config = LPMBannerAdViewConfigBuilder()
            .set(adSize: .banner())
            .build()
        let banner = LPMBannerAdView(adUnitId: bannerAdUnitID, config: config)
        banner.loadAd(with: rootViewController)
        return banner
    }

    // MARK: - Rewarded

    var isRewardedReady: Bool {
        rewardedAd?.isAdReady() == true
    }

    private func preloadRewarded() {
        guard !rewardedIsLoading else { return }
        rewardedIsLoading = true
        let ad = LPMRewardedAd(adUnitId: rewardedAdUnitID)
        ad.setDelegate(self)
        rewardedAd = ad
        ad.loadAd()
    }

    /// 広告を表示する。視聴完了で true、未ロード/失敗/途中離脱で false をコールバック。
    /// デバッグ端末では本番広告を消費せず、モーダルで 3 秒待って成功を返す。
    func showRewarded(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        if DebugDeviceConfig.isDebugDevice {
            let alert = UIAlertController(
                title: "テスト広告",
                message: "デバッグ端末のため疑似広告です…",
                preferredStyle: .alert)
            viewController.present(alert, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                alert.dismiss(animated: true) { completion(true) }
            }
            return
        }

        if let ad = rewardedAd, ad.isAdReady() {
            rewardedOnResult = completion
            ad.showAd(viewController: viewController, placementName: nil)
            return
        }
        // ロード中または未ロードなら最大 10 秒待つ
        rewardedPending = completion
        preloadRewarded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self, let cb = self.rewardedPending else { return }
            self.rewardedPending = nil
            cb(false)
        }
    }

    private func finishRewarded(_ success: Bool) {
        guard let cb = rewardedOnResult else { return }
        rewardedOnResult = nil
        cb(success)
    }

    // MARK: - Test Suite

    func launchTestSuite(from viewController: UIViewController) {
        guard isInitialized else { return }
        LevelPlay.launchTestSuite(viewController)
    }
}

// MARK: - LPMRewardedAdDelegate

extension AdsManager: LPMRewardedAdDelegate {

    func didLoadAd(with adInfo: LPMAdInfo) {
        print("[AdsManager] rewarded loaded")
        rewardedIsLoading = false
        if let cb = rewardedPending,
           let ad = rewardedAd, ad.isAdReady(),
           let vc = UIApplication.shared.tsRootViewController {
            rewardedPending = nil
            rewardedOnResult = cb
            ad.showAd(viewController: vc, placementName: nil)
        }
    }

    func didFailToLoadAd(withAdUnitId adUnitId: String, error: Error) {
        print("[AdsManager] rewarded load failed: \(error)")
        rewardedIsLoading = false
        if let cb = rewardedPending {
            rewardedPending = nil
            cb(false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.preloadRewarded() }
    }

    func didDisplayAd(with adInfo: LPMAdInfo) {}
    func didClickAd(with adInfo: LPMAdInfo) {}

    func didRewardAd(with adInfo: LPMAdInfo, reward: LPMReward) {
        finishRewarded(true)
    }

    func didFailToDisplayAd(with adInfo: LPMAdInfo, error: Error) {
        print("[AdsManager] rewarded display failed: \(error)")
        finishRewarded(false)
    }

    func didCloseAd(with adInfo: LPMAdInfo) {
        finishRewarded(false)
        preloadRewarded()
    }
}

// MARK: - UIApplication helper

private extension UIApplication {
    var tsRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}
