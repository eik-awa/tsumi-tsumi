import LinkPresentation
import StoreKit
import UIKit

private let GAME_COUNT_KEY = "tsumiki.gameCount"

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

    /// デバッグ端末では、本番の広告リクエストを送らずプレースホルダーを表示する。
    private func installBannerIfNeeded() {
        guard bannerView == nil else { return }

        if DebugDeviceConfig.isDebugDevice {
            let placeholder = DebugAdPlaceholderView()
            placeholder.hostViewController = self
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            bannerContainer.addSubview(placeholder)
            NSLayoutConstraint.activate([
                placeholder.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
                placeholder.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor),
                placeholder.topAnchor.constraint(equalTo: bannerContainer.topAnchor),
                placeholder.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor)
            ])
            bannerView = placeholder
            return
        }

        AdsManager.shared.start { [weak self] in
            guard let self, self.bannerView == nil else { return }
            let banner = AdsManager.shared.makeBanner(rootViewController: self)
            banner.translatesAutoresizingMaskIntoConstraints = false
            self.bannerContainer.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.leadingAnchor.constraint(equalTo: self.bannerContainer.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: self.bannerContainer.trailingAnchor),
                banner.topAnchor.constraint(equalTo: self.bannerContainer.topAnchor),
                banner.bottomAnchor.constraint(equalTo: self.bannerContainer.bottomAnchor)
            ])
            self.bannerView = banner
        }
    }

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .allButUpsideDown : .all
    }
}

// MARK: - GameViewDelegate

extension GameViewController: GameViewDelegate {

    func gameViewDidRequestSettings() {
        gameView.isInputBlocked = true
        let overlay = SettingsOverlay(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onClose = { [weak self, weak overlay] in
            overlay?.removeFromSuperview()
            self?.gameView.isInputBlocked = false
        }
        view.addSubview(overlay)
    }

    func gameViewDidRequestShare(score: Int, image: UIImage?) {
        let text = """
        「積み積み」で \(score) 段まで積めた！
        https://apps.apple.com/gm/app/積み積み/id6779612241
        """
        // プレビュー（共有シート上部のアイコン横）に見出しを出す。
        let previewTitle = "「積み積み」で \(score) 段まで積めた！"
        var items: [Any] = [ShareTextSource(text: text, previewTitle: previewTitle, previewImage: image)]
        if let image = image {
            items.append(image)
        }
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        present(activity, animated: true)
    }

    func gameViewDidRequestMainMenu(score: Int, completion: @escaping () -> Void) {
        completion()
    }

    func gameViewDidRequestContinue(completion: @escaping (Bool) -> Void) {
        AdsManager.shared.showRewarded(from: self, completion: completion)
    }

    func gameViewDidRequestRanking(score: Int?) {
        gameView.isInputBlocked = true
        let overlay = RankingOverlay(frame: view.bounds, score: score)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onClose = { [weak self, weak overlay] in
            overlay?.removeFromSuperview()
            self?.gameView.isInputBlocked = false
        }
        view.addSubview(overlay)
    }

    func gameViewDidEndGame(score: Int) {
        let count = UserDefaults.standard.integer(forKey: GAME_COUNT_KEY) + 1
        UserDefaults.standard.set(count, forKey: GAME_COUNT_KEY)
        // 3・10・30 回目にレビューを促す（Apple が年 3 回まで自動制限）
        guard [3, 10, 30].contains(count) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let scene = self?.view.window?.windowScene else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}

// MARK: - Share Item Source

/// Provides share text for messaging activities, but omits it for image-only
/// activities like "Save Image" so the user just gets a clean screenshot.
/// Also supplies LPLinkMetadata so the share sheet's top preview shows a title
/// (and the result image) next to the app icon instead of an icon alone.
private final class ShareTextSource: NSObject, UIActivityItemSource {

    private let text: String
    private let previewTitle: String
    private let previewImage: UIImage?

    init(text: String, previewTitle: String, previewImage: UIImage?) {
        self.text = text
        self.previewTitle = previewTitle
        self.previewImage = previewImage
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        text
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        switch activityType {
        case .saveToCameraRoll, .assignToContact, .print, .copyToPasteboard:
            return nil
        default:
            // "Save to Files" has no public constant; match by raw value so the
            // share sheet only writes the image, not a separate text file.
            if let raw = activityType?.rawValue,
               raw.contains("SaveToFiles") || raw.contains("CloudDocsUI") {
                return nil
            }
            return text
        }
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = previewTitle
        metadata.originalURL = URL(string: "積み積み")
        if let image = previewImage {
            metadata.imageProvider = NSItemProvider(object: image)
            metadata.iconProvider = NSItemProvider(object: image)
        }
        return metadata
    }
}

// MARK: - Debug Ad Placeholder

/// デバッグ端末用のプレースホルダー。バナー領域自体をタップすると LevelPlay の Test Suite が起動する。
private final class DebugAdPlaceholderView: UIView {

    weak var hostViewController: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.18, alpha: 1)

        let label = UILabel()
        label.text = "テストモード"
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = UIColor(white: 0.55, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        guard let hostViewController else { return }
        AdsManager.shared.launchTestSuite(from: hostViewController)
    }
}
