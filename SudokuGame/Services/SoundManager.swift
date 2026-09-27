import AVFoundation

enum SoundEffect: String, CaseIterable {
    case tap, button, place, erase, error, hint, group, star, win

    var volume: Float {
        switch self {
        case .tap, .button: return 0.5
        case .erase: return 0.6
        case .error: return 0.7
        default: return 0.85
        }
    }
}

final class SoundManager {
    static let shared = SoundManager()

    private var players: [SoundEffect: [AVAudioPlayer]] = [:]
    private var nextIndex: [SoundEffect: Int] = [:]
    private var prepared = false

    private init() {}

    func prepare() {
        guard !prepared else { return }
        prepared = true
        // Ambient: respects the silent switch and mixes with the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for effect in SoundEffect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else { continue }
            let list = (0..<3).compactMap { _ in try? AVAudioPlayer(contentsOf: url) }
            for player in list {
                player.volume = effect.volume
                player.prepareToPlay()
            }
            players[effect] = list
        }
    }

    func play(_ effect: SoundEffect) {
        guard UserDefaults.standard.bool(forKey: SettingsKey.sound),
              let list = players[effect], !list.isEmpty else { return }
        let index = nextIndex[effect, default: 0]
        nextIndex[effect] = (index + 1) % list.count
        let player = list[index]
        player.currentTime = 0
        player.play()
    }
}
