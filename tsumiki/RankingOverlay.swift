//
//  RankingOverlay.swift
//  tsumiki
//
//  みんなのランキング(Firestore, RankingStore 経由)を表示するオーバーレイ。
//  ../nawatobi では「登録フォーム付きの結果画面」と「一覧だけのランキング画面」が
//  別々の画面だったが、tsumi-tsumi のゲーム画面は Canvas 描画のためテキスト入力を
//  埋め込めない。そこで score を渡して呼び出すと(まだ登録可能なスコアの場合のみ)
//  名前入力フォームを上部に出し、登録後そのまま一覧を表示する1枚のオーバーレイに
//  まとめている。score なし、または登録済みスコア以下で呼び出すと一覧だけを表示する。
//

import UIKit

final class RankingOverlay: UIView {

    private let dim = UIView()
    private let card = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // Submit form
    private let scoreLabel = UILabel()
    private let nameField = UITextField()
    private let submitButton = UIButton(type: .system)
    private let noteLabel = UILabel()
    private let defaultNote = "名前と記録が、このゲームを開いた他の人にも表示されます。"

    // List
    private let scrollView = UIScrollView()
    private let listStack = UIStackView()
    private let statusLabel = UILabel()

    private let closeButton = UIButton(type: .system)

    var onClose: (() -> Void)?

    private let pendingScore: Int?
    private var hasSubmitForm: Bool { pendingScore != nil }

    private let cream = UIColor(red: 1, green: 248/255, blue: 236/255, alpha: 1)
    private let accent = UIColor(red: 1, green: 233/255, blue: 184/255, alpha: 1)
    private let pink = UIColor(red: 1, green: 138/255, blue: 148/255, alpha: 1)

    /// score を渡すと(登録済みスコアより高ければ)登録フォーム付きで表示する。
    init(frame: CGRect, score: Int?) {
        self.pendingScore = (score.map { RankingStore.shared.canSubmit(score: $0) } == true) ? score : nil
        super.init(frame: frame)
        setupUI()
        loadBoard(force: false)
        registerForKeyboardNotifications()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup

    private func setupUI() {
        dim.backgroundColor = UIColor(white: 0, alpha: 0.55)
        dim.frame = bounds
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(dim)
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))

        card.backgroundColor = UIColor(red: 27/255, green: 34/255, blue: 71/255, alpha: 0.98)
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = cream.withAlphaComponent(0.18).cgColor
        addSubview(card)

        titleLabel.text = "ランキング"
        titleLabel.textColor = cream
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center
        card.addSubview(titleLabel)

        subtitleLabel.text = "みんなの記録"
        subtitleLabel.textColor = cream.withAlphaComponent(0.6)
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textAlignment = .center
        card.addSubview(subtitleLabel)

        if hasSubmitForm {
            scoreLabel.text = "今回の記録  \(pendingScore ?? 0) 段"
            scoreLabel.textColor = accent
            scoreLabel.font = .systemFont(ofSize: 15, weight: .medium)
            scoreLabel.textAlignment = .center
            card.addSubview(scoreLabel)

            nameField.placeholder = "なまえ"
            nameField.text = RankingStore.shared.myName
            nameField.textColor = cream
            nameField.font = .systemFont(ofSize: 15)
            nameField.backgroundColor = cream.withAlphaComponent(0.1)
            nameField.layer.cornerRadius = 10
            nameField.layer.borderWidth = 1
            nameField.layer.borderColor = cream.withAlphaComponent(0.3).cgColor
            nameField.attributedPlaceholder = NSAttributedString(
                string: "なまえ", attributes: [.foregroundColor: cream.withAlphaComponent(0.4)])
            nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
            nameField.leftViewMode = .always
            nameField.returnKeyType = .done
            nameField.delegate = self
            card.addSubview(nameField)

            submitButton.setTitle("ランキングに登録", for: .normal)
            submitButton.setTitleColor(UIColor(red: 27/255, green: 34/255, blue: 71/255, alpha: 1), for: .normal)
            submitButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            submitButton.backgroundColor = cream.withAlphaComponent(0.92)
            submitButton.layer.cornerRadius = 10
            submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
            card.addSubview(submitButton)

            noteLabel.text = defaultNote
            noteLabel.textColor = cream.withAlphaComponent(0.55)
            noteLabel.font = .systemFont(ofSize: 10.5)
            noteLabel.textAlignment = .center
            noteLabel.numberOfLines = 2
            card.addSubview(noteLabel)
        }

        scrollView.showsVerticalScrollIndicator = false
        card.addSubview(scrollView)

        listStack.axis = .vertical
        listStack.spacing = 6
        scrollView.addSubview(listStack)

        statusLabel.textColor = cream.withAlphaComponent(0.6)
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = "読み込み中…"
        scrollView.addSubview(statusLabel)

        closeButton.setTitle("とじる", for: .normal)
        closeButton.setTitleColor(cream, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        closeButton.layer.cornerRadius = 10
        closeButton.layer.borderWidth = 1
        closeButton.layer.borderColor = cream.withAlphaComponent(0.4).cgColor
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        card.addSubview(closeButton)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let w: CGFloat = min(bounds.width - 40, 340)
        let formH: CGFloat = hasSubmitForm ? 168 : 0
        let listH: CGFloat = 260
        let h: CGFloat = 88 + formH + listH + 76
        card.frame = CGRect(x: (bounds.width - w) / 2, y: max((bounds.height - h) / 2, 24), width: w, height: min(h, bounds.height - 48))

        titleLabel.frame = CGRect(x: 0, y: 18, width: w, height: 28)
        subtitleLabel.frame = CGRect(x: 0, y: 46, width: w, height: 16)

        var y: CGFloat = 70
        if hasSubmitForm {
            scoreLabel.frame = CGRect(x: 24, y: y, width: w - 48, height: 20)
            y += 26
            nameField.frame = CGRect(x: 24, y: y, width: w - 48, height: 42)
            y += 50
            submitButton.frame = CGRect(x: 24, y: y, width: w - 48, height: 42)
            y += 50
            noteLabel.frame = CGRect(x: 24, y: y, width: w - 48, height: 28)
            y += 36
        }

        let listBottomReserve: CGFloat = 68
        let listTop = y + 6
        let listHeight = card.bounds.height - listTop - listBottomReserve
        scrollView.frame = CGRect(x: 16, y: listTop, width: w - 32, height: max(listHeight, 80))
        statusLabel.frame = CGRect(x: 0, y: 20, width: scrollView.bounds.width, height: 60)
        layoutListStack()

        closeButton.frame = CGRect(x: 24, y: card.bounds.height - 56, width: w - 48, height: 42)
    }

    private func layoutListStack() {
        let rowH: CGFloat = 34
        listStack.frame = CGRect(x: 0, y: 0, width: scrollView.bounds.width, height: CGFloat(listStack.arrangedSubviews.count) * (rowH + listStack.spacing))
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: max(listStack.frame.height, scrollView.bounds.height))
    }

    // MARK: - Board

    private func loadBoard(force: Bool) {
        statusLabel.isHidden = false
        statusLabel.text = "読み込み中…"
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        RankingStore.shared.fetchBoard(force: force) { [weak self] entries in
            self?.render(entries: entries)
        }
    }

    private func render(entries: [RankingStore.Entry]) {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !entries.isEmpty else {
            statusLabel.isHidden = false
            statusLabel.text = "まだ誰も登録していない。\n一番乗りのチャンス。"
            setNeedsLayout()
            return
        }
        statusLabel.isHidden = true
        let myName = RankingStore.shared.myName
        for (i, entry) in entries.prefix(10).enumerated() {
            let isMine = !myName.isEmpty && entry.name == myName
            listStack.addArrangedSubview(makeRow(rank: i + 1, entry: entry, isTop: i < 3, isMine: isMine))
        }
        setNeedsLayout()
    }

    private func makeRow(rank: Int, entry: RankingStore.Entry, isTop: Bool, isMine: Bool) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 34).isActive = true
        if isMine {
            row.backgroundColor = accent.withAlphaComponent(0.16)
            row.layer.cornerRadius = 8
        }

        let rankLabel = UILabel()
        rankLabel.text = "\(rank)"
        rankLabel.font = .systemFont(ofSize: 14, weight: isTop ? .bold : .regular)
        rankLabel.textColor = isTop ? accent : cream.withAlphaComponent(0.75)
        rankLabel.textAlignment = .left

        let nameLabel = UILabel()
        nameLabel.text = entry.name
        nameLabel.font = .systemFont(ofSize: 14, weight: isMine ? .semibold : .regular)
        nameLabel.textColor = cream
        nameLabel.lineBreakMode = .byTruncatingTail

        let scoreLabel = UILabel()
        scoreLabel.text = "\(entry.score)"
        scoreLabel.font = .systemFont(ofSize: 14, weight: .medium)
        scoreLabel.textColor = cream
        scoreLabel.textAlignment = .right

        [rankLabel, nameLabel, scoreLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }
        NSLayoutConstraint.activate([
            rankLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            rankLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 26),

            scoreLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            scoreLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            scoreLabel.widthAnchor.constraint(equalToConstant: 50),

            nameLabel.leadingAnchor.constraint(equalTo: rankLabel.trailingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: scoreLabel.leadingAnchor, constant: -6),
            nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    // MARK: - Actions

    @objc private func dimTapped() {
        nameField.resignFirstResponder()
        onClose?()
    }
    @objc private func closeTapped() {
        nameField.resignFirstResponder()
        onClose?()
    }

    @objc private func submitTapped() {
        nameField.resignFirstResponder()
        let name = nameField.text ?? ""
        guard let score = pendingScore else { return }

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameField.becomeFirstResponder()
            return
        }
        if RankingStore.shared.looksLikePII(name) {
            showNote("電話番号やメールアドレスなど、個人情報になる文字列は登録できません。", isError: true)
            nameField.becomeFirstResponder()
            return
        }
        if !RankingStore.shared.canSubmitToday() {
            showNote("本日の登録上限（10回）に達しました。また明日どうぞ。", isError: true)
            return
        }

        showNote(defaultNote, isError: false)
        submitButton.isEnabled = false
        submitButton.setTitle("登録中…", for: .normal)

        RankingStore.shared.submit(name: name, score: score) { [weak self] result in
            guard let self else { return }
            self.submitButton.isEnabled = true
            self.submitButton.setTitle("ランキングに登録", for: .normal)
            switch result {
            case .success(let entries):
                self.render(entries: entries)
            case .failure(.emptyName):
                self.nameField.becomeFirstResponder()
            case .failure(.containsPII):
                self.showNote("電話番号やメールアドレスなど、個人情報になる文字列は登録できません。", isError: true)
            case .failure(.dailyLimitReached):
                self.showNote("本日の登録上限（10回）に達しました。また明日どうぞ。", isError: true)
            }
        }
    }

    private func showNote(_ text: String, isError: Bool) {
        noteLabel.text = text
        noteLabel.textColor = isError ? pink : cream.withAlphaComponent(0.55)
    }

    // MARK: - Keyboard

    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ note: Notification) {
        guard let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let overlap = card.frame.maxY - (bounds.height - frame.height) + 12
        guard overlap > 0 else { return }
        UIView.animate(withDuration: 0.25) { self.card.transform = CGAffineTransform(translationX: 0, y: -overlap) }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        UIView.animate(withDuration: 0.25) { self.card.transform = .identity }
    }
}

// MARK: - UITextFieldDelegate

extension RankingOverlay: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = (textField.text ?? "") as NSString
        let updated = current.replacingCharacters(in: range, with: string)
        return updated.count <= 10
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
