import AVFoundation

enum MusicTrack: String, CaseIterable {
    case home = "music_home"
    case game = "music_game"
}

/// Plays the bundled jazz loops gaplessly and crossfades between the home and
/// in-game tracks. Stays silent when music is off or the user is already
/// listening to something else.
final class MusicManager {
    static let shared = MusicManager()

    private let engine = AVAudioEngine()
    private var players: [MusicTrack: AVAudioPlayerNode] = [:]
    private var buffers: [MusicTrack: AVAudioPCMBuffer] = [:]
    private var scheduled: Set<MusicTrack> = []
    private var fadeTimers: [MusicTrack: Timer] = [:]
    private var current: MusicTrack = .home
    private let targetVolume: Float = 0.5

    private init() {
        let loops = MusicManager.loopLengths()
        for track in MusicTrack.allCases {
            guard let buffer = MusicManager.loadLoop(track, frames: loops[track.rawValue]) else { continue }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
            player.volume = 0
            players[track] = player
            buffers[track] = buffer
        }
    }

    private var shouldPlay: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.music)
            && !AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
    }

    /// Switches to `track`, crossfading from whatever is playing.
    func play(_ track: MusicTrack) {
        guard track != current else {
            refresh()
            return
        }
        let previous = current
        current = track
        guard shouldPlay else { return }
        fadeOut(previous, duration: 1.5)
        start(track, fadeIn: 2.0)
    }

    /// Call when the app becomes active or the music setting changes.
    func refresh() {
        if shouldPlay {
            start(current, fadeIn: 2.0)
        } else {
            stop()
        }
    }

    func stop() {
        for track in MusicTrack.allCases {
            fadeOut(track, duration: 0.8)
        }
    }

    // MARK: - Playback

    private func start(_ track: MusicTrack, fadeIn: Double) {
        guard let player = players[track], let buffer = buffers[track] else { return }
        if !engine.isRunning {
            // Interruptions and route changes stop the engine and drop scheduled audio.
            for p in players.values { p.stop() }
            scheduled.removeAll()
            do { try engine.start() } catch { return }
        }
        if !scheduled.contains(track) {
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            scheduled.insert(track)
        }
        if !player.isPlaying {
            player.volume = 0
            player.play()
        }
        fade(track, to: targetVolume, duration: fadeIn, completion: nil)
    }

    private func fadeOut(_ track: MusicTrack, duration: Double) {
        guard let player = players[track], player.isPlaying else { return }
        fade(track, to: 0, duration: duration) { [weak self] in
            guard let self else { return }
            player.pause()
            if !self.players.values.contains(where: { $0.isPlaying }) {
                self.engine.pause()
            }
        }
    }

    private func fade(_ track: MusicTrack, to target: Float, duration: Double, completion: (() -> Void)?) {
        guard let player = players[track] else { return }
        fadeTimers[track]?.invalidate()
        let start = player.volume
        let steps = 30
        var step = 0
        let timer = Timer(timeInterval: duration / Double(steps), repeats: true) { t in
            step += 1
            player.volume = start + (target - start) * Float(step) / Float(steps)
            if step >= steps {
                t.invalidate()
                completion?()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        fadeTimers[track] = timer
    }

    // MARK: - Loading

    private static func loopLengths() -> [String: Int] {
        guard let url = Bundle.main.url(forResource: "music_loops", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lengths = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return lengths
    }

    /// Decodes a track and trims AAC encoder padding so the loop is exactly `frames` long.
    private static func loadLoop(_ track: MusicTrack, frames: Int?) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let full = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                          frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: full)) != nil else { return nil }
        guard let frames, Int(full.frameLength) > frames,
              let trimmed = AVAudioPCMBuffer(pcmFormat: full.format, frameCapacity: AVAudioFrameCount(frames)),
              let source = full.floatChannelData,
              let destination = trimmed.floatChannelData else { return full }
        // Padding is always added at the end; the encoder's 1024-frame priming also
        // remains at the start if the decoder did not strip it.
        let excess = Int(full.frameLength) - frames
        let offset = excess >= 1024 ? 1024 : 0
        for channel in 0..<Int(full.format.channelCount) {
            destination[channel].update(from: source[channel] + offset, count: frames)
        }
        trimmed.frameLength = AVAudioFrameCount(frames)
        return trimmed
    }
}
