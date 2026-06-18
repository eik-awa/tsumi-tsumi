import Foundation
import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    private let bgmVolumeKey = "tsumiki.bgmVolume"
    private let seVolumeKey = "tsumiki.seVolume"
    private var bgmPlayer: AVAudioPlayer?
    private var sePlayers: [String: AVAudioPlayer] = [:]

    var bgmVolume: Float {
        get {
            if UserDefaults.standard.object(forKey: bgmVolumeKey) == nil { return 0.5 }
            return UserDefaults.standard.float(forKey: bgmVolumeKey)
        }
        set {
            let v = max(0, min(1, newValue))
            UserDefaults.standard.set(v, forKey: bgmVolumeKey)
            bgmPlayer?.volume = v
        }
    }

    var seVolume: Float {
        get {
            if UserDefaults.standard.object(forKey: seVolumeKey) == nil { return 0.8 }
            return UserDefaults.standard.float(forKey: seVolumeKey)
        }
        set {
            let v = max(0, min(1, newValue))
            UserDefaults.standard.set(v, forKey: seVolumeKey)
            for player in sePlayers.values { player.volume = v }
        }
    }

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        prepareBGM()
        prepareSE("se_good")
        prepareSE("se_perfect")
    }

    private func prepareBGM() {
        guard let url = Bundle.main.url(forResource: "bgm", withExtension: "mp3") else { return }
        bgmPlayer = try? AVAudioPlayer(contentsOf: url)
        bgmPlayer?.numberOfLoops = -1
        bgmPlayer?.volume = bgmVolume
        bgmPlayer?.prepareToPlay()
    }

    private func prepareSE(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = seVolume
        player.prepareToPlay()
        sePlayers[name] = player
    }

    func startBGM() {
        guard bgmPlayer?.isPlaying != true else { return }
        bgmPlayer?.play()
    }

    func playSE(_ name: String) {
        guard let player = sePlayers[name] else { return }
        player.currentTime = 0
        player.play()
    }
}
