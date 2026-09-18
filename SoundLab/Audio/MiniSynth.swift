import AVFoundation
import Observation

// MARK: - Patch

enum Waveform: Int, CaseIterable, Identifiable {
    case sine, triangle, saw, square
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .sine:     return "사인"
        case .triangle: return "삼각"
        case .saw:      return "톱니"
        case .square:   return "사각"
        }
    }
}

struct Patch: Equatable, Sendable {
    var waveform: Waveform = .saw
    var pitch: Float = 220           // Hz
    var pitchSweep: Float = 0        // semitones added at trigger, decaying to 0
    var noiseMix: Float = 0          // 0...1
    var filterMode: StateVariableFilter.Mode = .lowpass
    var cutoff: Float = 2_000        // Hz
    var resonance: Float = 0.2       // 0...0.95
    var filterEnv: Float = 0         // Hz added to cutoff at trigger, decaying to 0
    var attack: Float = 0.01
    var decay: Float = 0.3
    var sustain: Float = 0.4
    var release: Float = 0.3

    static let baseline = Patch()

    /// How long the key is held when the patch is played or drawn as a one-shot.
    /// Percussive patches end on their own; sustained ones get a short hold so the
    /// sustain level is visible before the release.
    var gateTime: Double {
        let shape = Double(attack + decay)
        return sustain < 0.01 ? shape : shape + 0.6
    }

    /// Time until the patch falls silent after a one-shot.
    var length: Double {
        sustain < 0.01 ? Double(attack + decay) : gateTime + Double(release)
    }
}

/// The parameters the focus mode walks through, in the order worth learning them.
enum SynthParameter: Int, CaseIterable, Identifiable {
    case cutoff, resonance, filterMode, attack, decay, sustain, release
    case waveform, noiseMix, pitch, pitchSweep, filterEnv

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .waveform:   return "파형"
        case .pitch:      return "피치"
        case .pitchSweep: return "피치 스윕"
        case .noiseMix:   return "노이즈 믹스"
        case .filterMode: return "필터 모드"
        case .cutoff:     return "컷오프"
        case .resonance:  return "레조넌스"
        case .filterEnv:  return "필터 엔벨로프"
        case .attack:     return "어택"
        case .decay:      return "디케이"
        case .sustain:    return "서스테인"
        case .release:    return "릴리스"
        }
    }

    /// One line on what this parameter does to the listener, not to the signal.
    var teaches: String {
        switch self {
        case .waveform:   return "배음의 양. 사인은 순하고, 톱니는 거칠고 존재감이 큽니다."
        case .pitch:      return "크기와 위협의 인상. 낮을수록 크고 무겁게 들립니다."
        case .pitchSweep: return "움직임의 방향. 내려가면 착지, 올라가면 발사로 읽힙니다."
        case .noiseMix:   return "음정의 유무. 노이즈가 섞일수록 자연물·마찰음에 가까워집니다."
        case .filterMode: return "어느 대역을 남길지. 하이패스는 가볍게, 밴드패스는 멀고 좁게 들립니다."
        case .cutoff:     return "밝기와 거리감. 낮을수록 멀고 답답하게 들립니다."
        case .resonance:  return "컷오프 지점의 강조. 높이면 특정 음정이 들리기 시작합니다."
        case .filterEnv:  return "시작 순간의 밝기. 임팩트의 '탁' 소리가 여기서 나옵니다."
        case .attack:     return "놀라게 할지 말지. 짧을수록 반사적 반응을 유발합니다."
        case .decay:      return "타격인지 지속인지. 소리의 성격을 가장 크게 좌우합니다."
        case .sustain:    return "누르고 있는 동안 남는 양. 0이면 타악기, 1이면 지속음."
        case .release:    return "여운. 공간의 크기에 대한 인상을 만듭니다."
        }
    }

    var isDiscrete: Bool { self == .waveform || self == .filterMode }

    /// Sliders run over 0...1 and map through this, so equal finger travel sounds like
    /// an equal change. Frequency and time are heard logarithmically, not linearly.
    enum Scale { case linear, logarithmic, squared }

    var scale: Scale {
        switch self {
        case .pitch, .cutoff, .attack, .decay, .release: return .logarithmic
        case .filterEnv:                                 return .squared
        default:                                         return .linear
        }
    }

    func normalized(_ value: Float) -> Float {
        let lo = range.lowerBound, hi = range.upperBound
        let clamped = min(max(value, lo), hi)
        switch scale {
        case .linear:      return (clamped - lo) / (hi - lo)
        case .logarithmic: return log(clamped / lo) / log(hi / lo)
        case .squared:     return ((clamped - lo) / (hi - lo)).squareRoot()
        }
    }

    func denormalized(_ position: Float) -> Float {
        let lo = range.lowerBound, hi = range.upperBound
        let t = min(max(position, 0), 1)
        switch scale {
        case .linear:      return lo + (hi - lo) * t
        case .logarithmic: return lo * pow(hi / lo, t)
        case .squared:     return lo + (hi - lo) * t * t
        }
    }

    /// Which stage of the signal path the parameter belongs to.
    var module: SynthModule {
        switch self {
        case .waveform, .noiseMix, .pitch, .pitchSweep: return .source
        case .filterMode, .cutoff, .resonance, .filterEnv: return .filter
        case .attack, .decay, .sustain, .release: return .amp
        }
    }

    var range: ClosedRange<Float> {
        switch self {
        case .pitch:      return 30...2_000
        case .pitchSweep: return -36...48
        case .noiseMix:   return 0...1
        case .cutoff:     return 80...12_000
        case .resonance:  return 0...0.95
        case .filterEnv:  return 0...8_000
        case .attack:     return 0.001...2
        case .decay:      return 0.01...3
        case .sustain:    return 0...1
        case .release:    return 0.01...3
        case .waveform:   return 0...3
        case .filterMode: return 0...2
        }
    }

    func value(in patch: Patch) -> Float {
        switch self {
        case .pitch:      return patch.pitch
        case .pitchSweep: return patch.pitchSweep
        case .noiseMix:   return patch.noiseMix
        case .cutoff:     return patch.cutoff
        case .resonance:  return patch.resonance
        case .filterEnv:  return patch.filterEnv
        case .attack:     return patch.attack
        case .decay:      return patch.decay
        case .sustain:    return patch.sustain
        case .release:    return patch.release
        case .waveform:   return Float(patch.waveform.rawValue)
        case .filterMode: return Float(patch.filterMode.rawValue)
        }
    }

    func set(_ newValue: Float, in patch: inout Patch) {
        switch self {
        case .pitch:      patch.pitch = newValue
        case .pitchSweep: patch.pitchSweep = newValue
        case .noiseMix:   patch.noiseMix = newValue
        case .cutoff:     patch.cutoff = newValue
        case .resonance:  patch.resonance = newValue
        case .filterEnv:  patch.filterEnv = newValue
        case .attack:     patch.attack = newValue
        case .decay:      patch.decay = newValue
        case .sustain:    patch.sustain = newValue
        case .release:    patch.release = newValue
        case .waveform:   patch.waveform = Waveform(rawValue: Int(newValue)) ?? .saw
        case .filterMode: patch.filterMode = StateVariableFilter.Mode(rawValue: Int(newValue)) ?? .lowpass
        }
    }

    func formatted(_ value: Float) -> String {
        switch self {
        case .pitch, .cutoff, .filterEnv: return "\(Int(value)) Hz"
        case .pitchSweep:                 return String(format: "%+.0f 반음", value)
        case .noiseMix, .sustain:         return String(format: "%.0f%%", value * 100)
        case .resonance:                  return String(format: "%.2f", value)
        case .attack, .decay, .release:   return String(format: "%.3f s", value)
        case .waveform:                   return Waveform(rawValue: Int(value))?.label ?? "-"
        case .filterMode:                 return StateVariableFilter.Mode(rawValue: Int(value))?.label ?? "-"
        }
    }
}

/// The three stages a sound passes through, in signal order.
enum SynthModule: Int, CaseIterable, Identifiable {
    case source, filter, amp

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .source: return "소스"
        case .filter: return "필터"
        case .amp:    return "앰프"
        }
    }

    var question: String {
        switch self {
        case .source: return "무엇이 울리나"
        case .filter: return "어느 대역을 남기나"
        case .amp:    return "시간에 따라 어떻게 커지고 줄어드나"
        }
    }

    var symbol: String {
        switch self {
        case .source: return "waveform"
        case .filter: return "line.3.horizontal.decrease"
        case .amp:    return "chart.line.uptrend.xyaxis"
        }
    }

    var parameters: [SynthParameter] {
        switch self {
        case .source: return [.waveform, .noiseMix, .pitch, .pitchSweep]
        case .filter: return [.filterMode, .cutoff, .resonance, .filterEnv]
        case .amp:    return [.attack, .decay, .sustain, .release]
        }
    }
}

// MARK: - Challenges

struct SynthChallenge: Identifiable {
    let id: Int
    let title: String
    let symbol: String
    let brief: String
    let target: Patch
    /// The recipe, revealed only after the user has tried on their own.
    let hint: [String]

    static let all: [SynthChallenge] = [
        SynthChallenge(
            id: 0,
            title: "킥",
            symbol: "circle.bottomhalf.filled",
            brief: "가슴을 누르는 짧은 저음. 클럽이 아니라 심장을 떠올리세요.",
            target: Patch(waveform: .sine, pitch: 52, pitchSweep: 30, noiseMix: 0.03,
                          filterMode: .lowpass, cutoff: 3_000, resonance: 0.1, filterEnv: 0,
                          attack: 0.001, decay: 0.30, sustain: 0, release: 0.05),
            hint: [
                "정체성은 피치 스윕입니다. 높은 데서 시작해 순식간에 내려앉는 움직임이 '맞았다'는 인상을 만듭니다.",
                "사인파로 시작하세요. 배음이 많으면 킥이 아니라 베이스가 됩니다.",
                "어택은 가능한 짧게, 서스테인은 0.",
                "디케이 0.3초 근처. 더 길면 둔해지고, 더 짧으면 클릭이 됩니다.",
                "노이즈를 아주 조금(3% 정도) 섞으면 스피커에서 존재감이 살아납니다."
            ]
        ),
        SynthChallenge(
            id: 1,
            title: "심벌",
            symbol: "sparkles",
            brief: "음정이 없는 금속성 잔향. 오실레이터를 아예 쓰지 않습니다.",
            target: Patch(waveform: .saw, pitch: 220, pitchSweep: 0, noiseMix: 1.0,
                          filterMode: .highpass, cutoff: 7_000, resonance: 0.15, filterEnv: 0,
                          attack: 0.001, decay: 0.9, sustain: 0, release: 0.4),
            hint: [
                "노이즈 믹스를 100%로 올립니다. 여기서는 오실레이터가 방해물입니다.",
                "필터 모드를 하이패스로. 로우패스로는 절대 심벌이 되지 않습니다.",
                "컷오프 7kHz 근처. 낮추면 파도 소리에 가까워집니다.",
                "디케이를 0.9초까지 길게. 긴 꼬리가 금속의 인상을 만듭니다.",
                "이 과제의 교훈은 '필터 모드가 음색을 결정한다'입니다."
            ]
        ),
        SynthChallenge(
            id: 2,
            title: "물방울",
            symbol: "drop.fill",
            brief: "올라가는 짧은 블립. 조성이 없는 소리를 다루는 첫 관문입니다.",
            target: Patch(waveform: .sine, pitch: 480, pitchSweep: -20, noiseMix: 0,
                          filterMode: .lowpass, cutoff: 6_000, resonance: 0.2, filterEnv: 0,
                          attack: 0.002, decay: 0.14, sustain: 0, release: 0.06),
            hint: [
                "킥과 정확히 반대입니다. 피치 스윕이 음수, 즉 아래에서 위로 올라갑니다.",
                "이 방향 하나가 '떨어짐'과 '솟음'을 가릅니다. 물리적으로 물방울은 떨어지는데 소리는 올라갑니다.",
                "사인파, 어택은 거의 0, 디케이 0.14초 정도로 아주 짧게.",
                "피치를 480Hz 근처에 두세요. 낮으면 나무 두드리는 소리가 됩니다.",
                "성공하면 피치를 300~900Hz 사이에서 랜덤하게 바꿔 여러 개를 겹쳐 보세요. 빗소리가 됩니다."
            ]
        ),
        SynthChallenge(
            id: 3,
            title: "바람",
            symbol: "wind",
            brief: "유일하게 타악기가 아닌 과제. 지속음의 감정을 다룹니다.",
            target: Patch(waveform: .saw, pitch: 220, pitchSweep: 0, noiseMix: 1.0,
                          filterMode: .bandpass, cutoff: 700, resonance: 0.85, filterEnv: 0,
                          attack: 1.2, decay: 1.2, sustain: 0.65, release: 1.6),
            hint: [
                "노이즈 100% + 밴드패스 + 높은 레조넌스. 이 조합이 바람의 전부입니다.",
                "레조넌스를 0.85까지 올리면 노이즈에서 음정 비슷한 것이 들리기 시작합니다. 그게 바람의 '휘파람'입니다.",
                "서스테인을 0이 아닌 값으로 두고 길게 눌러 유지하세요. 앞의 세 과제와 근본적으로 다른 점입니다.",
                "어택을 1초 이상으로 길게. 갑자기 시작하는 바람은 바람으로 들리지 않습니다.",
                "완성한 뒤 컷오프를 손으로 천천히 움직여 보세요. 돌풍이 됩니다. 이게 절차적 사운드의 출발점입니다."
            ]
        ),
        SynthChallenge(
            id: 4,
            title: "레이저",
            symbol: "bolt.fill",
            brief: "가장 인공적인 소리. 현실에 존재하지 않는 소리를 만드는 연습입니다.",
            target: Patch(waveform: .saw, pitch: 900, pitchSweep: 42, noiseMix: 0,
                          filterMode: .lowpass, cutoff: 9_000, resonance: 0.55, filterEnv: 0,
                          attack: 0.001, decay: 0.32, sustain: 0, release: 0.08),
            hint: [
                "톱니파. 배음이 많을수록 인공적으로 들립니다.",
                "피치 스윕을 40 반음 이상으로 크게. 킥과 원리는 같지만 양이 극단적입니다.",
                "같은 하강 스윕인데 킥과 전혀 다르게 들리는 이유는 피치 대역과 파형입니다. 두 과제를 번갈아 들어 보세요.",
                "레조넌스를 0.5 근처로 올리면 스윕이 지나가는 궤적이 강조됩니다.",
                "디케이 0.3초. 더 길면 레이저가 아니라 신스 리드가 됩니다."
            ]
        ),
        SynthChallenge(
            id: 5,
            title: "심장박동",
            symbol: "heart.fill",
            brief: "귀가 아니라 몸으로 듣는 소리. 두 번 연달아 트리거하세요.",
            target: Patch(waveform: .sine, pitch: 44, pitchSweep: 10, noiseMix: 0,
                          filterMode: .lowpass, cutoff: 180, resonance: 0.2, filterEnv: 0,
                          attack: 0.004, decay: 0.20, sustain: 0, release: 0.08),
            hint: [
                "컷오프를 180Hz까지 내립니다. 거의 들리지 않고 느껴지는 영역입니다.",
                "피치 44Hz. 스피커에서는 약하게 들려도 이어폰과 몸에서는 다르게 작동합니다.",
                "어택을 0.004초로 아주 살짝 늘립니다. 완전히 0이면 클릭음이 섞입니다.",
                "쿵-쿵 두 번을 약 0.25초 간격으로 트리거하세요. 두 번째를 조금 작게 하면 진짜에 가까워집니다.",
                "이 과제의 교훈 — 감정은 크게 들리는 소리가 아니라 몸에 닿는 대역에서 나옵니다."
            ]
        )
    ]
}

// MARK: - Voice

/// Render-thread state. Written from the main thread, read on the audio thread.
/// Individual word-sized writes are used deliberately: locking the audio thread
/// would be worse than an occasional torn parameter update in a learning tool.
final class SynthVoice: @unchecked Sendable {
    private let sampleRate: Float
    private let filter: StateVariableFilter
    private let noise = PinkNoiseGenerator()

    // Live parameters
    var waveform: Int = Waveform.saw.rawValue
    var pitch: Float = 220
    var pitchSweep: Float = 0
    var noiseMix: Float = 0
    var filterMode: Int = StateVariableFilter.Mode.lowpass.rawValue
    var cutoff: Float = 2_000
    var resonance: Float = 0.2
    var filterEnv: Float = 0
    var attack: Float = 0.01
    var decay: Float = 0.3
    var sustain: Float = 0.4
    var release: Float = 0.3

    // Internal state
    private var phase: Float = 0
    private var ampValue: Float = 0
    private var stage: Int = 0          // 0 idle, 1 attack, 2 decay, 3 sustain, 4 release
    private var releaseFrom: Float = 0
    private var sweepValue: Float = 0

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        self.filter = StateVariableFilter(sampleRate: sampleRate)
    }

    func apply(_ patch: Patch) {
        waveform = patch.waveform.rawValue
        pitch = patch.pitch
        pitchSweep = patch.pitchSweep
        noiseMix = patch.noiseMix
        filterMode = patch.filterMode.rawValue
        cutoff = patch.cutoff
        resonance = patch.resonance
        filterEnv = patch.filterEnv
        attack = patch.attack
        decay = patch.decay
        sustain = patch.sustain
        release = patch.release
    }

    func gateOn() {
        stage = 1
        sweepValue = 1
        filter.reset()
    }

    func gateOff() {
        guard stage != 0 else { return }
        releaseFrom = ampValue
        stage = 4
    }

    func render() -> Float {
        // Amplitude envelope
        switch stage {
        case 1:
            ampValue += 1 / max(attack * sampleRate, 1)
            if ampValue >= 1 { ampValue = 1; stage = 2 }
        case 2:
            ampValue -= (1 - sustain) / max(decay * sampleRate, 1)
            if ampValue <= sustain {
                ampValue = sustain
                stage = sustain <= 0.0001 ? 0 : 3
            }
        case 3:
            ampValue = sustain
        case 4:
            ampValue -= releaseFrom / max(release * sampleRate, 1)
            if ampValue <= 0 { ampValue = 0; stage = 0 }
        default:
            ampValue = 0
        }

        guard stage != 0 || ampValue > 0 else { return 0 }

        // Sweep envelope (linear decay to zero over the decay time)
        if sweepValue > 0 {
            sweepValue -= 1 / max(decay * sampleRate, 1)
            if sweepValue < 0 { sweepValue = 0 }
        }

        // Oscillator
        let sweptPitch = pitch * pow(2, (pitchSweep * sweepValue) / 12)
        let frequency = min(max(sweptPitch, 20), sampleRate * 0.45)
        phase += frequency / sampleRate
        if phase >= 1 { phase -= 1 }

        var osc: Float
        switch waveform {
        case Waveform.sine.rawValue:
            osc = sin(2 * Float.pi * phase)
        case Waveform.triangle.rawValue:
            osc = 4 * abs(phase - 0.5) - 1
        case Waveform.square.rawValue:
            osc = phase < 0.5 ? 1 : -1
        default:
            osc = 2 * phase - 1
        }

        // Oscillator / noise blend
        let mixed = osc * (1 - noiseMix) + noise.next() * 4 * noiseMix

        // Filter with its own envelope on the cutoff
        let mode = StateVariableFilter.Mode(rawValue: filterMode) ?? .lowpass
        let movingCutoff = cutoff + filterEnv * sweepValue
        let filtered = filter.process(mixed, cutoff: movingCutoff, resonance: resonance, mode: mode)

        return filtered * ampValue * 0.35
    }
}

// MARK: - Synth

@Observable
final class MiniSynth {

    struct Playhead: Equatable {
        let isTarget: Bool
        let start: Date
    }

    var patch: Patch = .baseline {
        didSet { voice.apply(patch) }
    }
    /// Snapshot to A/B against, and to return to after a focused experiment.
    var baseline: Patch = .baseline
    /// When set, every other parameter is locked. This is principle 02 made mechanical.
    var focus: SynthParameter? {
        didSet { if let focus { explored.insert(focus) } }
    }
    /// Parameters the user has taken through focus mode this session.
    private(set) var explored: Set<SynthParameter> = []
    var selectedChallenge: SynthChallenge?
    var passedChallenges: Set<Int> = []
    /// Which sound is currently sounding, so the picture can follow it.
    private(set) var playhead: Playhead?

    private let engine = AVAudioEngine()
    /// The user's patch and the challenge target get separate voices, so auditioning
    /// the target never has to swap the user's patch out and back in.
    private let voice: SynthVoice
    private let targetVoice: SynthVoice
    private var sourceNode: AVAudioSourceNode?
    private var pressedAt: Date?
    private var releaseTask: Task<Void, Never>?
    private var targetTask: Task<Void, Never>?
    private var abTask: Task<Void, Never>?

    init() {
        let sampleRate = Float(AudioCore.shared.sampleRate)
        voice = SynthVoice(sampleRate: sampleRate)
        targetVoice = SynthVoice(sampleRate: sampleRate)
        buildGraph()
        voice.apply(patch)
    }

    private func buildGraph() {
        let format = AudioCore.shared.format
        let node = AVAudioSourceNode(format: format) { [voice, targetVoice] _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = voice.render() + targetVoice.render()
                for buffer in buffers {
                    let pointer = UnsafeMutableBufferPointer<Float>(buffer)
                    pointer[frame] = sample
                }
            }
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.8
    }

    func start() {
        guard !engine.isRunning else { return }
        engine.prepare()
        do { try engine.start() } catch { print("Synth engine failed: \(error)") }
    }

    func stop() {
        voice.gateOff()
        targetVoice.gateOff()
        engine.stop()
    }

    // MARK: Playing

    /// Finger down on the pad. Holding keeps the sustain stage going.
    func press() {
        abTask?.cancel()
        releaseTask?.cancel()
        start()
        voice.gateOn()
        pressedAt = .now
        playhead = Playhead(isTarget: false, start: .now)
    }

    /// Finger up. A quick tap still plays the whole attack and decay, so a tap and a
    /// hold only differ where the patch actually has something to hold.
    func release() {
        let held = pressedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        let remaining = max(0, Double(patch.attack + patch.decay) - held)
        pressedAt = nil
        releaseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            self.voice.gateOff()
        }
    }

    /// One-shot of the user's patch.
    func playMine() {
        press()
        release()
    }

    func playTarget() {
        guard let target = selectedChallenge?.target else { return }
        abTask?.cancel()
        targetTask?.cancel()
        start()
        targetVoice.apply(target)
        targetVoice.gateOn()
        playhead = Playhead(isTarget: true, start: .now)
        targetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(target.gateTime))
            guard !Task.isCancelled else { return }
            self.targetVoice.gateOff()
        }
    }

    /// Target, a short gap, then the user's patch.
    func playAB() {
        guard let target = selectedChallenge?.target else { return }
        playTarget()
        abTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(target.length + 0.35))
            guard !Task.isCancelled else { return }
            self.playMine()
        }
    }

    // MARK: Focus mode

    func resetToBaseline() {
        patch = baseline
    }

    func captureBaseline() {
        baseline = patch
    }

    func setValue(_ value: Float, for parameter: SynthParameter) {
        guard !isLocked(parameter) else { return }
        var copy = patch
        parameter.set(value, in: &copy)
        patch = copy
    }

    /// Slider position 0...1 on the parameter's perceptual scale.
    func position(of parameter: SynthParameter) -> Float {
        parameter.normalized(parameter.value(in: patch))
    }

    func setPosition(_ position: Float, for parameter: SynthParameter) {
        setValue(parameter.denormalized(position), for: parameter)
    }

    func isLocked(_ parameter: SynthParameter) -> Bool {
        guard let focus else { return false }
        return focus != parameter
    }

    // MARK: Challenges

    func select(_ challenge: SynthChallenge?) {
        selectedChallenge = challenge
        focus = nil
        patch = .baseline
        baseline = .baseline
    }

    func markPassed() {
        guard let challenge = selectedChallenge else { return }
        passedChallenges.insert(challenge.id)
    }

    /// Rough closeness measure so the user gets a nudge, not a grade.
    /// Measured on the same perceptual scale the sliders use.
    var distanceToTarget: Double? {
        guard let target = selectedChallenge?.target else { return nil }

        func difference(_ parameter: SynthParameter) -> Float {
            let mine = parameter.value(in: patch)
            let goal = parameter.value(in: target)
            if parameter.isDiscrete { return mine == goal ? 0 : 1 }
            return abs(parameter.normalized(mine) - parameter.normalized(goal))
        }

        let keys: [SynthParameter] = [.waveform, .pitch, .pitchSweep, .noiseMix,
                                      .filterMode, .cutoff, .resonance,
                                      .attack, .decay, .sustain, .release]
        let total = keys.reduce(Float(0)) { $0 + difference($1) }
        return Double(1 - min(total / Float(keys.count) * 2.2, 1))
    }
}
