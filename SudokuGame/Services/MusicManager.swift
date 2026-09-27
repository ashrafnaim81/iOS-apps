import AVFoundation

/// Plays the bundled ambient loop gaplessly. It stays silent when the user
/// turned music off or is already listening to something else.
final class MusicManager {
    static let shared = MusicManager()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?
    private var fadeTimer: Timer?
    private var scheduled = false
    private let targetVolume: Float = 0.45

    private init() {
        guard let url = Bundle.main.url(forResource: "music", withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let pcm = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                         frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: pcm)) != nil else { return }
        buffer = pcm
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: pcm.format)
        player.volume = 0
    }

    private var enabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.music) }

    /// Call when the app becomes active or the setting changes.
    func refresh() {
        if enabled && !AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint {
            start()
        } else {
            stop()
        }
    }

    func stop() {
        guard player.isPlaying else { return }
        fade(to: 0, duration: 0.8) { [weak self] in
            self?.player.pause()
            self?.engine.pause()
        }
    }

    private func start() {
        guard let buffer else { return }
        if !engine.isRunning {
            // Interruptions and route changes stop the engine and drop scheduled audio.
            player.stop()
            scheduled = false
            do { try engine.start() } catch { return }
        }
        if !scheduled {
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            scheduled = true
        }
        if !player.isPlaying {
            player.play()
        }
        fade(to: targetVolume, duration: 2.0, completion: nil)
    }

    private func fade(to target: Float, duration: Double, completion: (() -> Void)?) {
        fadeTimer?.invalidate()
        let start = player.volume
        let steps = 30
        var step = 0
        let timer = Timer(timeInterval: duration / Double(steps), repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            step += 1
            self.player.volume = start + (target - start) * Float(step) / Float(steps)
            if step >= steps {
                t.invalidate()
                completion?()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        fadeTimer = timer
    }
}
