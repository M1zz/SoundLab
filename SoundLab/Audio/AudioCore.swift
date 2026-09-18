import AVFoundation

/// Owns the audio session only. Each feature runs its own `AVAudioEngine` so that
/// attaching and detaching nodes never happens on a running graph.
final class AudioCore {
    static let shared = AudioCore()

    let sampleRate: Double = 44_100

    var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    }

    private init() {}

    func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("Audio session failed: \(error)")
        }
    }
}

/// Paul Kellet's economy pink noise filter.
/// A class rather than a struct because the render block captures it by reference
/// and mutates it on the audio thread.
final class PinkNoiseGenerator: @unchecked Sendable {
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0

    func next() -> Float {
        let white = Float.random(in: -1...1)
        b0 = 0.99765 * b0 + white * 0.0990460
        b1 = 0.96300 * b1 + white * 0.2965164
        b2 = 0.57000 * b2 + white * 1.0526913
        return (b0 + b1 + b2 + white * 0.1848) * 0.12
    }
}

/// Chamberlin state variable filter. Gives lowpass, bandpass and highpass from one
/// structure, which is also the cheapest way to show a learner what filter mode means.
final class StateVariableFilter: @unchecked Sendable {
    enum Mode: Int, CaseIterable, Identifiable {
        case lowpass, bandpass, highpass
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .lowpass:  return "로우패스"
            case .bandpass: return "밴드패스"
            case .highpass: return "하이패스"
            }
        }
    }

    private var low: Float = 0
    private var band: Float = 0
    private let sampleRate: Float

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
    }

    func reset() {
        low = 0
        band = 0
    }

    /// - Parameters:
    ///   - cutoff: Hz, clamped to a stable range for this topology.
    ///   - resonance: 0...0.95, higher is more peaked.
    func process(_ input: Float, cutoff: Float, resonance: Float, mode: Mode) -> Float {
        let safeCutoff = min(max(cutoff, 20), sampleRate * 0.24)
        let f = 2 * sin(Float.pi * safeCutoff / sampleRate)
        let q = 1 - min(max(resonance, 0), 0.95)

        let high = input - low - q * band
        band += f * high
        low += f * band

        // Cheap guard against blow-ups at extreme settings.
        if !low.isFinite || !band.isFinite { reset() }

        switch mode {
        case .lowpass:  return low
        case .bandpass: return band
        case .highpass: return high
        }
    }
}
