import AVFoundation
import Observation

enum DrillLevel: Int, CaseIterable, Identifiable, Hashable {
    case starter = 0
    case intermediate
    case advanced

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .starter:      return "입문 3밴드"
        case .intermediate: return "중급 5밴드"
        case .advanced:     return "고급 8밴드"
        }
    }

    var frequencies: [Double] {
        switch self {
        case .starter:      return [100, 1_000, 8_000]
        case .intermediate: return [100, 250, 1_000, 3_000, 8_000]
        case .advanced:     return [63, 125, 250, 500, 1_000, 2_000, 4_000, 8_000]
        }
    }

    /// Boost/cut magnitude in dB. Smaller is harder.
    var gain: Float {
        switch self {
        case .starter:      return 12
        case .intermediate: return 6
        case .advanced:     return 3
        }
    }

    var detail: String {
        switch self {
        case .starter:      return "±12dB · 부스트만"
        case .intermediate: return "±6dB · 부스트와 컷"
        case .advanced:     return "±3dB · 부스트와 컷"
        }
    }

    /// Cuts are only introduced once the user can hear boosts reliably.
    var includesCuts: Bool { self != .starter }
}

@Observable
final class EarTrainer {

    // MARK: Published state

    var level: DrillLevel = .starter {
        didSet { resetSession() }
    }
    var isPlaying = false
    /// True while the user is listening to the flat reference.
    var isFlat = false
    var currentFrequency: Double = 1_000
    var currentGain: Float = 12
    var asked = 0
    var correct = 0
    var answered = false
    var lastChoice: Double?
    var missed: [Double] = []
    var sessionFinished = false

    let questionsPerSession = 10

    // MARK: Audio graph

    private let engine = AVAudioEngine()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    private let noise = PinkNoiseGenerator()
    private var sourceNode: AVAudioSourceNode?

    init() {
        buildGraph()
    }

    private func buildGraph() {
        let format = AudioCore.shared.format

        let node = AVAudioSourceNode(format: format) { [noise] _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = noise.next()
                for buffer in buffers {
                    let pointer = UnsafeMutableBufferPointer<Float>(buffer)
                    pointer[frame] = sample
                }
            }
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.attach(eq)
        engine.connect(node, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.45

        let band = eq.bands[0]
        band.filterType = .parametric
        band.bandwidth = 0.5   // octaves — narrow enough to be a real test
        band.bypass = false
        eq.globalGain = 0
    }

    // MARK: Transport

    func start() {
        guard !engine.isRunning else { return }
        engine.prepare()
        do {
            try engine.start()
            isPlaying = true
        } catch {
            print("Ear trainer engine failed: \(error)")
        }
    }

    func stop() {
        engine.stop()
        isPlaying = false
    }

    // MARK: Session

    func resetSession() {
        asked = 0
        correct = 0
        missed = []
        sessionFinished = false
        answered = false
        lastChoice = nil
        newQuestion()
    }

    func newQuestion() {
        guard asked < questionsPerSession else {
            sessionFinished = true
            setFlat(true)
            return
        }

        currentFrequency = level.frequencies.randomElement() ?? 1_000
        let magnitude = level.gain
        currentGain = level.includesCuts ? (Bool.random() ? magnitude : -magnitude) : magnitude

        let band = eq.bands[0]
        band.frequency = Float(currentFrequency)
        band.gain = currentGain

        answered = false
        lastChoice = nil
        setFlat(false)
    }

    /// A/B between the processed signal and the flat reference.
    func setFlat(_ flat: Bool) {
        isFlat = flat
        eq.bands[0].bypass = flat
    }

    func toggleFlat() {
        setFlat(!isFlat)
    }

    @discardableResult
    func answer(_ frequency: Double) -> Bool {
        guard !answered else { return lastChoice == currentFrequency }

        answered = true
        lastChoice = frequency
        asked += 1

        let isCorrect = frequency == currentFrequency
        if isCorrect {
            correct += 1
        } else {
            missed.append(currentFrequency)
        }

        // Reveal the answer by parking on the processed signal.
        setFlat(false)

        if asked >= questionsPerSession {
            sessionFinished = true
        }
        return isCorrect
    }

    var accuracy: Double {
        asked == 0 ? 0 : Double(correct) / Double(asked)
    }
}

extension Double {
    /// 8000 -> "8k", 250 -> "250"
    var frequencyLabel: String {
        self >= 1_000 ? "\(Int(self / 1_000))k" : "\(Int(self))"
    }
}
