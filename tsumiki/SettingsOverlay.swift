import UIKit

final class SettingsOverlay: UIView {

    private let dim = UIView()
    private let card = UIView()
    private let titleLabel = UILabel()

    private let bgmLabel = UILabel()
    private let bgmValueLabel = UILabel()
    private let bgmSlider = UISlider()

    private let seLabel = UILabel()
    private let seValueLabel = UILabel()
    private let seSlider = UISlider()

    private let closeButton = UIButton(type: .system)

    var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        let cream = UIColor(red: 1, green: 248/255, blue: 236/255, alpha: 1)
        let accent = UIColor(red: 1, green: 233/255, blue: 184/255, alpha: 1)

        dim.backgroundColor = UIColor(white: 0, alpha: 0.55)
        dim.frame = bounds
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(dim)
        let tap = UITapGestureRecognizer(target: self, action: #selector(dimTapped))
        dim.addGestureRecognizer(tap)

        card.backgroundColor = UIColor(red: 27/255, green: 34/255, blue: 71/255, alpha: 0.98)
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = cream.withAlphaComponent(0.18).cgColor
        addSubview(card)

        titleLabel.text = "設定"
        titleLabel.textColor = cream
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center
        card.addSubview(titleLabel)

        configureRow(label: bgmLabel, value: bgmValueLabel, slider: bgmSlider,
                     title: "BGM 音量",
                     initialValue: AudioManager.shared.bgmVolume,
                     action: #selector(bgmChanged),
                     cream: cream, accent: accent)

        configureRow(label: seLabel, value: seValueLabel, slider: seSlider,
                     title: "効果音 音量",
                     initialValue: AudioManager.shared.seVolume,
                     action: #selector(seChanged),
                     cream: cream, accent: accent)

        closeButton.setTitle("閉じる", for: .normal)
        closeButton.setTitleColor(cream, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        closeButton.layer.cornerRadius = 10
        closeButton.layer.borderWidth = 1
        closeButton.layer.borderColor = cream.withAlphaComponent(0.4).cgColor
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        card.addSubview(closeButton)

        updateBgmValue()
        updateSeValue()
    }

    private func configureRow(label: UILabel, value: UILabel, slider: UISlider,
                              title: String, initialValue: Float, action: Selector,
                              cream: UIColor, accent: UIColor) {
        label.text = title
        label.textColor = cream.withAlphaComponent(0.85)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        card.addSubview(label)

        value.textColor = cream.withAlphaComponent(0.7)
        value.font = .systemFont(ofSize: 13, weight: .regular)
        value.textAlignment = .right
        card.addSubview(value)

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = initialValue
        slider.minimumTrackTintColor = accent
        slider.maximumTrackTintColor = cream.withAlphaComponent(0.2)
        slider.thumbTintColor = cream
        slider.addTarget(self, action: action, for: .valueChanged)
        card.addSubview(slider)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w: CGFloat = min(bounds.width - 48, 320)
        let h: CGFloat = 296
        card.frame = CGRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
        titleLabel.frame = CGRect(x: 0, y: 20, width: w, height: 30)

        bgmLabel.frame      = CGRect(x: 24, y: 70, width: 160, height: 20)
        bgmValueLabel.frame = CGRect(x: w - 24 - 60, y: 70, width: 60, height: 20)
        bgmSlider.frame     = CGRect(x: 24, y: 96, width: w - 48, height: 30)

        seLabel.frame       = CGRect(x: 24, y: 144, width: 160, height: 20)
        seValueLabel.frame  = CGRect(x: w - 24 - 60, y: 144, width: 60, height: 20)
        seSlider.frame      = CGRect(x: 24, y: 170, width: w - 48, height: 30)

        closeButton.frame   = CGRect(x: 24, y: h - 60, width: w - 48, height: 44)
    }

    @objc private func bgmChanged() {
        AudioManager.shared.bgmVolume = bgmSlider.value
        updateBgmValue()
    }

    @objc private func seChanged() {
        AudioManager.shared.seVolume = seSlider.value
        updateSeValue()
        AudioManager.shared.playSE("se_good")
    }

    @objc private func closeTapped() { onClose?() }
    @objc private func dimTapped() { onClose?() }

    private func updateBgmValue() {
        bgmValueLabel.text = "\(Int(bgmSlider.value * 100))"
    }

    private func updateSeValue() {
        seValueLabel.text = "\(Int(seSlider.value * 100))"
    }
}
