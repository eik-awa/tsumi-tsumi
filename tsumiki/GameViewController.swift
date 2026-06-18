import UIKit

class GameViewController: UIViewController {

    private var gameView: GameView!
    private var bannerContainer: UIView!
    private var bannerView: UIView?

    override func loadView() {
        gameView = GameView()
        view = gameView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        gameView.delegate = self

        bannerContainer = UIView()
        bannerContainer.backgroundColor = .clear
        bannerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerContainer)

        NSLayoutConstraint.activate([
            bannerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bannerContainer.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installBannerIfNeeded()
    }

    private func installBannerIfNeeded() {
        guard bannerView == nil else { return }
        let banner = AdsManager.shared.makeBanner(rootViewController: self)
        banner.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: bannerContainer.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: bannerContainer.centerYAnchor)
        ])
        bannerView = banner
    }

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .allButUpsideDown : .all
    }
}

// MARK: - GameViewDelegate

extension GameViewController: GameViewDelegate {

    func gameViewDidRequestSettings() {
        let overlay = SettingsOverlay(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onClose = { [weak overlay] in
            overlay?.removeFromSuperview()
        }
        view.addSubview(overlay)
    }

    func gameViewDidRequestShare(score: Int) {
        let text = "「積み積み」で \(score) 段まで積めた！ #積み積み"
        let items: [Any] = [text]
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        present(activity, animated: true)
    }

    func gameViewDidRequestMainMenu(score: Int, completion: @escaping () -> Void) {
        AdsManager.shared.showInterstitialIfReady(from: self) {
            completion()
        }
    }
}
