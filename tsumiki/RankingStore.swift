//
//  RankingStore.swift
//  tsumiki
//
//  Firebase Firestore を使った「みんなのランキング」+ 端末内の自己ベスト・提出履歴の管理。
//  ../nawatobi の StorageBridge / ranking 仕様(端末内=UserDefaults, グローバル=Firestore、
//  名前ごとに最高スコアのみ保持、10分キャッシュ、1日10回までの登録上限、簡易的な個人情報チェック)
//  を踏襲する。Firestore への保存形式だけは、WKWebView 経由の汎用 KV ブリッジ(JSON文字列を
//  1フィールドに詰める方式)ではなく、ネイティブ実装らしく配列フィールドへ直接書き込む形に
//  している(挙動は同一)。
//
//  GoogleService-Info.plist が未設置 / Firebase 未初期化の場合はクラッシュを避け、
//  端末内保存にフォールバックする(ランキングはその端末だけで完結する)。
//

import Foundation
import FirebaseCore
import FirebaseFirestore

final class RankingStore {
    static let shared = RankingStore()

    struct Entry {
        let name: String
        let score: Int
        let timestamp: Double
        let dateStr: String
    }

    enum SubmitError: Error {
        case emptyName
        case containsPII
        case dailyLimitReached
    }

    private let collectionName = "tsumiki_kv"
    private let boardDocID = "board"
    private let dailyLimit = 10
    private let boardCacheInterval: TimeInterval = 10 * 60

    private let nameKey = "tsumiki.ranking.name"
    private let bestKey = "tsumiki.ranking.best"
    private let submittedKey = "tsumiki.ranking.submitted"
    private let quotaDateKey = "tsumiki.ranking.quotaDate"
    private let quotaCountKey = "tsumiki.ranking.quotaCount"
    private let localBoardKey = "tsumiki.ranking.localBoard"

    /// Firebase が未設定(GoogleService-Info.plist なし等)なら nil のままで、常に端末内保存にフォールバックする。
    private lazy var firestore: Firestore? = FirebaseApp.app() != nil ? Firestore.firestore() : nil

    private var board: [Entry] = []
    private var boardFetchedAt: Date?

    private init() {}

    // MARK: - Me (端末内)

    var myName: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    private(set) var myBest: Int {
        get { UserDefaults.standard.integer(forKey: bestKey) }
        set { UserDefaults.standard.set(newValue, forKey: bestKey) }
    }

    private(set) var mySubmittedScore: Int {
        get { UserDefaults.standard.integer(forKey: submittedKey) }
        set { UserDefaults.standard.set(newValue, forKey: submittedKey) }
    }

    /// スコアが 1 以上あれば何度でも登録できる。
    /// Firestore 側では同名の場合は高い方のスコアだけを保持するため、
    /// 低いスコアを送っても既存の最高記録が上書きされることはない。
    func canSubmit(score: Int) -> Bool {
        score > 0
    }

    // MARK: - 個人情報チェック

    /// 電話番号やメールアドレスなど、他の人にも見えるランキングに個人情報が
    /// 載らないよう、登録前に簡易チェックする(数字の連続7桁以上 or @ を含む)。
    func looksLikePII(_ name: String) -> Bool {
        let digitCount = name.unicodeScalars.filter {
            (0x30...0x39).contains($0.value) || (0xFF10...0xFF19).contains($0.value) // 半角/全角数字
        }.count
        return digitCount >= 7 || name.contains("@")
    }

    // MARK: - 1日の登録上限

    private func todayStr() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    func canSubmitToday() -> Bool {
        let ud = UserDefaults.standard
        guard ud.string(forKey: quotaDateKey) == todayStr() else { return true }
        return ud.integer(forKey: quotaCountKey) < dailyLimit
    }

    private func useQuota() {
        let ud = UserDefaults.standard
        let today = todayStr()
        let count = (ud.string(forKey: quotaDateKey) == today ? ud.integer(forKey: quotaCountKey) : 0) + 1
        ud.set(today, forKey: quotaDateKey)
        ud.set(count, forKey: quotaCountKey)
    }

    // MARK: - ランキング取得

    /// 10分間はメモリキャッシュを使い、Firestore の読み取り回数を抑える。
    func fetchBoard(force: Bool = false, completion: @escaping ([Entry]) -> Void) {
        if !force, let fetchedAt = boardFetchedAt, Date().timeIntervalSince(fetchedAt) < boardCacheInterval {
            completion(board)
            return
        }
        readRawBoard { [weak self] raw in
            guard let self else { return }
            self.board = raw.compactMap { dict -> Entry? in
                guard let name = dict["n"] as? String, let score = dict["s"] as? Int else { return nil }
                return Entry(
                    name: name,
                    score: score,
                    timestamp: dict["t"] as? Double ?? 0,
                    dateStr: dict["d"] as? String ?? ""
                )
            }
            self.boardFetchedAt = Date()
            DispatchQueue.main.async { completion(self.board) }
        }
    }

    // MARK: - 登録

    /// 名前とスコアをランキングへ登録する。個人情報チェック・1日の上限チェックを経てから、
    /// 同名の記録は高い方のスコアだけを残す形でマージし、Firestore(未設定なら端末内)へ書き込む。
    func submit(name rawName: String, score: Int, completion: @escaping (Result<[Entry], SubmitError>) -> Void) {
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(10))
        guard !name.isEmpty else {
            completion(.failure(.emptyName))
            return
        }
        guard !looksLikePII(name) else {
            completion(.failure(.containsPII))
            return
        }
        guard canSubmitToday() else {
            completion(.failure(.dailyLimitReached))
            return
        }

        fetchBoard(force: true) { [weak self] currentBoard in
            guard let self else { return }
            self.useQuota()

            var byName: [String: Entry] = [:]
            for entry in currentBoard { byName[entry.name] = entry }
            let newEntry = Entry(name: name, score: score, timestamp: Date().timeIntervalSince1970, dateStr: self.todayStr())
            if let existing = byName[name], existing.score >= score {
                // 既存の記録の方が高ければ据え置く(高い方だけを残す)
            } else {
                byName[name] = newEntry
            }
            let merged = Array(byName.values).sorted {
                $0.score != $1.score ? $0.score > $1.score : $0.timestamp < $1.timestamp
            }
            self.board = merged
            self.boardFetchedAt = Date()

            self.myName = name
            self.mySubmittedScore = score
            if score > self.myBest { self.myBest = score }

            self.writeRawBoard(merged.map { ["n": $0.name, "s": $0.score, "t": $0.timestamp, "d": $0.dateStr] }) {
                DispatchQueue.main.async { completion(.success(merged)) }
            }
        }
    }

    // MARK: - 永続化(Firestore / 端末内フォールバック)

    private func readRawBoard(completion: @escaping ([[String: Any]]) -> Void) {
        guard let firestore else {
            if let data = UserDefaults.standard.data(forKey: localBoardKey),
               let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                completion(raw)
            } else {
                completion([])
            }
            return
        }
        firestore.collection(collectionName).document(boardDocID).getDocument { [weak self] snapshot, error in
            if let error {
                print("[RankingStore] fetch failed: \(error)")
                // エラー時はメモリキャッシュにフォールバックして上書き消去を防ぐ
                let fallback = self?.board.map { ["n": $0.name, "s": $0.score, "t": $0.timestamp, "d": $0.dateStr] as [String: Any] } ?? []
                completion(fallback)
                return
            }
            completion(snapshot?.data()?["entries"] as? [[String: Any]] ?? [])
        }
    }

    private func writeRawBoard(_ raw: [[String: Any]], completion: @escaping () -> Void) {
        guard let firestore else {
            if let data = try? JSONSerialization.data(withJSONObject: raw) {
                UserDefaults.standard.set(data, forKey: localBoardKey)
            }
            completion()
            return
        }
        firestore.collection(collectionName).document(boardDocID).setData(["entries": raw]) { error in
            if let error { print("[RankingStore] write failed: \(error)") }
            completion()
        }
    }
}
