import LinkPresentation
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
        AdsManager.shared.showInterstitialIfReady(from: self) {
            completion()
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
