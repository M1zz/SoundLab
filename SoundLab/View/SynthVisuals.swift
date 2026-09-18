import SwiftUI

// MARK: - Sound portrait

enum PortraitMode: String, CaseIterable, Identifiable {
    case outline = "파형"
    case spectrum = "주파수"
    var id: String { rawValue }

    var caption: String {
        switch self {
        case .outline:  return "가로는 시간, 높이는 크기. 그림을 탭하면 재생됩니다."
        case .spectrum: return "가로는 시간, 세로는 주파수(아래가 저음). 밝을수록 셉니다."
        }
    }
}

/// One sound drawn across the shared time axis. Tapping it plays it.
struct SoundLane: View {
    let title: String
    let color: Color
    let picture: SoundPicture?
    let mode: PortraitMode
    /// Set while this lane's sound is playing, so a playhead can sweep across.
    let playStart: Date?

    @State private var animating = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
            playhead
            Label(title, systemImage: "play.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(mode == .spectrum ? .white : color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(6)
        }
        .frame(height: 84)
        .background(mode == .spectrum ? Color.black : color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .task(id: playStart) {
            guard let playStart, let picture else { animating = false; return }
            animating = true
            let remaining = picture.duration - Date.now.timeIntervalSince(playStart)
            try? await Task.sleep(for: .seconds(max(remaining, 0) + 0.05))
            animating = false
        }
    }

    @ViewBuilder
    private var content: some View {
        if let picture {
            switch mode {
            case .outline:
                Canvas { context, size in
                    context.fill(Self.outline(picture.peaks, in: size),
                                 with: .linearGradient(Gradient(colors: [color.opacity(0.9), color.opacity(0.55)]),
                                                       startPoint: .zero,
                                                       endPoint: CGPoint(x: 0, y: size.height)))
                    var centre = Path()
                    centre.move(to: CGPoint(x: 0, y: size.height / 2))
                    centre.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    context.stroke(centre, with: .color(color.opacity(0.3)), lineWidth: 0.5)
                }
            case .spectrum:
                ZStack(alignment: .trailing) {
                    if let image = picture.spectrogram {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.medium)
                    }
                    frequencyTicks
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var frequencyTicks: some View {
        GeometryReader { geo in
            ForEach([100, 1_000, 10_000], id: \.self) { hz in
                let position = log(Float(hz) / SoundAnalyzer.lowestFrequency)
                    / log(SoundAnalyzer.highestFrequency / SoundAnalyzer.lowestFrequency)
                Text(hz >= 1_000 ? "\(hz / 1_000)k" : "\(hz)")
                    .font(.system(size: 9, weight: .medium).monospaced())
                    .foregroundStyle(.white.opacity(0.6))
                    .position(x: geo.size.width - 14, y: geo.size.height * CGFloat(1 - position))
            }
        }
    }

    @ViewBuilder
    private var playhead: some View {
        if let playStart, let picture {
            TimelineView(.animation(paused: !animating)) { timeline in
                let progress = timeline.date.timeIntervalSince(playStart) / picture.duration
                GeometryReader { geo in
                    if animating, progress >= 0, progress <= 1 {
                        Rectangle()
                            .fill(mode == .spectrum ? Color.white : color)
                            .frame(width: 2)
                            .offset(x: geo.size.width * progress)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// Mirrored peak outline, the way a DAW draws a clip.
    static func outline(_ peaks: [Float], in size: CGSize) -> Path {
        var path = Path()
        guard peaks.count > 1 else { return path }
        let mid = size.height / 2
        let step = size.width / CGFloat(peaks.count - 1)
        path.move(to: CGPoint(x: 0, y: mid))
        for (index, peak) in peaks.enumerated() {
            path.addLine(to: CGPoint(x: CGFloat(index) * step, y: mid - CGFloat(peak) * mid * 0.92))
        }
        for (index, peak) in peaks.enumerated().reversed() {
            path.addLine(to: CGPoint(x: CGFloat(index) * step, y: mid + CGFloat(peak) * mid * 0.92))
        }
        path.closeSubpath()
        return path
    }
}

/// Target and attempt described in words, side by side.
struct TraitComparison: View {
    let target: SoundTraits
    let mine: SoundTraits

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
            GridRow {
                Text("")
                Text("목표").foregroundStyle(.orange)
                Text("내 소리").foregroundStyle(Color.accentColor)
            }
            .font(.caption2.weight(.semibold))

            ForEach(Array(SoundTraits.labels.enumerated()), id: \.offset) { index, label in
                let goal = target.values[index]
                let attempt = mine.values[index]
                GridRow {
                    Text(label)
                        .foregroundStyle(.secondary)
                    Text(goal)
                    HStack(spacing: 4) {
                        Text(attempt)
                        Image(systemName: goal == attempt ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(goal == attempt ? Color.green : Color.secondary.opacity(0.5))
                    }
                }
                .font(.caption)
            }
        }
    }
}

// MARK: - Glyphs

struct WaveformGlyph: Shape {
    let waveform: Waveform

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 64
        var previous: CGFloat?
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let phase = (t * 2).truncatingRemainder(dividingBy: 1)
            let value: CGFloat
            switch waveform {
            case .sine:     value = sin(2 * .pi * phase)
            case .triangle: value = 1 - 4 * abs(phase - 0.5)
            case .saw:      value = 2 * phase - 1
            case .square:   value = phase < 0.5 ? 1 : -1
            }
            let x = rect.minX + t * rect.width
            let y = rect.midY - value * rect.height / 2
            if let previous {
                // Jumps in saw and square are drawn as vertical edges.
                if abs(value - previous) > 1 {
                    path.addLine(to: CGPoint(x: x, y: rect.midY - previous * rect.height / 2))
                }
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.move(to: CGPoint(x: x, y: y))
            }
            previous = value
        }
        return path
    }
}

struct FilterModeGlyph: Shape {
    let mode: StateVariableFilter.Mode

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 48
        for step in 0...steps {
            let t = Float(step) / Float(steps)
            let ratio = pow(Float(64), t - 0.5)
            let db = FilterResponse.gain(mode: mode, ratio: ratio, damping: 0.55)
            let normalized = CGFloat(min(max((db + 30) / 36, 0), 1))
            let point = CGPoint(x: rect.minX + CGFloat(t) * rect.width, y: rect.maxY - normalized * rect.height)
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

// MARK: - Filter response

enum FilterResponse {
    /// Magnitude of the analogue two-pole state variable filter the Chamberlin topology models.
    /// - Parameters:
    ///   - ratio: frequency divided by cutoff.
    ///   - damping: `1 - resonance`, the filter's q.
    static func gain(mode: StateVariableFilter.Mode, ratio: Float, damping: Float) -> Float {
        let real = 1 - ratio * ratio
        let imag = damping * ratio
        let denominator = max((real * real + imag * imag).squareRoot(), 1e-6)
        let numerator: Float
        switch mode {
        case .lowpass:  numerator = 1
        case .bandpass: numerator = ratio
        case .highpass: numerator = ratio * ratio
        }
        return 20 * log10(max(numerator / denominator, 1e-6))
    }
}

/// Drag sideways for cutoff, up and down for resonance.
struct FilterResponseGraph: View {
    let patch: Patch
    let cutoffLocked: Bool
    let resonanceLocked: Bool
    let onCutoff: (Float) -> Void
    let onResonance: (Float) -> Void

    private static let lowest: Float = 20
    private static let highest: Float = 20_000
    private static let floorDB: Float = -36
    private static let ceilingDB: Float = 30

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { context, size in
                drawGrid(&context, size: size)

                if patch.filterEnv > 1 {
                    let opened = min(patch.cutoff + patch.filterEnv, 12_000)
                    context.stroke(curve(cutoff: opened, size: size),
                                   with: .color(.accentColor.opacity(0.45)),
                                   style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }

                let main = curve(cutoff: patch.cutoff, size: size)
                var area = main
                area.addLine(to: CGPoint(x: size.width, y: size.height))
                area.addLine(to: CGPoint(x: 0, y: size.height))
                area.closeSubpath()
                context.fill(area, with: .linearGradient(
                    Gradient(colors: [.accentColor.opacity(0.28), .accentColor.opacity(0.02)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                context.stroke(main, with: .color(.accentColor), lineWidth: 2)

                let handle = handlePoint(size: size)
                let both = cutoffLocked && resonanceLocked
                context.fill(Path(ellipseIn: CGRect(x: handle.x - 9, y: handle.y - 9, width: 18, height: 18)),
                             with: .color(.accentColor.opacity(both ? 0.25 : 1)))
                context.stroke(Path(ellipseIn: CGRect(x: handle.x - 9, y: handle.y - 9, width: 18, height: 18)),
                               with: .color(.white), lineWidth: 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onCutoff(min(max(frequency(atX: value.location.x, width: size.width), 80), 12_000))
                        let peakDB = db(atY: value.location.y, height: size.height)
                        onResonance(min(max(1 - pow(10, -peakDB / 20), 0), 0.95))
                    }
            )
        }
        .frame(height: 150)
        .overlay(alignment: .topTrailing) {
            Text("↔ 컷오프  ↕ 레조넌스")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(6)
        }
        .overlay(alignment: .topLeading) {
            if patch.filterEnv > 1 {
                Text("점선 = 치는 순간 열리는 곳")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
    }

    private func drawGrid(_ context: inout GraphicsContext, size: CGSize) {
        for hz: Float in [100, 1_000, 10_000] {
            let x = xPosition(hz, width: size.width)
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(.secondary.opacity(0.18)), lineWidth: 0.5)
            context.draw(Text(hz >= 1_000 ? "\(Int(hz / 1_000))k" : "\(Int(hz))")
                            .font(.system(size: 9).monospaced())
                            .foregroundStyle(.secondary),
                         at: CGPoint(x: x + 3, y: size.height - 3), anchor: .bottomLeading)
        }
        let zero = yPosition(0, height: size.height)
        var unity = Path()
        unity.move(to: CGPoint(x: 0, y: zero))
        unity.addLine(to: CGPoint(x: size.width, y: zero))
        context.stroke(unity, with: .color(.secondary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
    }

    private var damping: Float { 1 - min(max(patch.resonance, 0), 0.95) }

    private func curve(cutoff: Float, size: CGSize) -> Path {
        var path = Path()
        let steps = 140
        for step in 0...steps {
            let x = size.width * CGFloat(step) / CGFloat(steps)
            let hz = frequency(atX: x, width: size.width)
            let gain = FilterResponse.gain(mode: patch.filterMode, ratio: hz / cutoff, damping: damping)
            let point = CGPoint(x: x, y: yPosition(gain, height: size.height))
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }

    /// Every mode peaks at `1/q` right at the cutoff, which is where the handle sits.
    private func handlePoint(size: CGSize) -> CGPoint {
        CGPoint(x: xPosition(patch.cutoff, width: size.width),
                y: yPosition(20 * log10(1 / damping), height: size.height))
    }

    private func xPosition(_ hz: Float, width: CGFloat) -> CGFloat {
        width * CGFloat(log(hz / Self.lowest) / log(Self.highest / Self.lowest))
    }

    private func frequency(atX x: CGFloat, width: CGFloat) -> Float {
        let t = Float(min(max(x / max(width, 1), 0), 1))
        return Self.lowest * pow(Self.highest / Self.lowest, t)
    }

    private func yPosition(_ db: Float, height: CGFloat) -> CGFloat {
        let t = (min(max(db, Self.floorDB), Self.ceilingDB) - Self.floorDB) / (Self.ceilingDB - Self.floorDB)
        return height * CGFloat(1 - t)
    }

    private func db(atY y: CGFloat, height: CGFloat) -> Float {
        let t = Float(1 - min(max(y / max(height, 1), 0), 1))
        return Self.floorDB + t * (Self.ceilingDB - Self.floorDB)
    }
}

// MARK: - Envelope

/// ADSR drawn as a shape, with a handle on each corner the user can move.
struct EnvelopeGraph: View {
    let patch: Patch
    let isLocked: (SynthParameter) -> Bool
    let onChange: (SynthParameter, Float) -> Void

    private enum Handle { case peak, sustain, end }
    @State private var active: Handle?

    // Share of the width each stage can use at its maximum.
    private let attackZone: CGFloat = 0.22
    private let decayZone: CGFloat = 0.30
    private let holdZone: CGFloat = 0.18
    private let releaseZone: CGFloat = 0.30
    private let inset: CGFloat = 10

    private var percussive: Bool { patch.sustain < 0.01 }

    var body: some View {
        GeometryReader { geo in
            let points = corners(in: geo.size)
            Canvas { context, size in
                let p = corners(in: size)

                var shape = Path()
                shape.move(to: p.start)
                shape.addLine(to: p.peak)
                shape.addLine(to: p.sustain)
                shape.addLine(to: p.holdEnd)
                var area = shape
                area.addLine(to: p.end)
                area.closeSubpath()
                context.fill(area, with: .linearGradient(
                    Gradient(colors: [.accentColor.opacity(0.3), .accentColor.opacity(0.04)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                context.stroke(shape, with: .color(.accentColor), lineWidth: 2)

                var tail = Path()
                tail.move(to: p.holdEnd)
                tail.addLine(to: p.end)
                context.stroke(tail, with: .color(.accentColor.opacity(percussive ? 0.3 : 1)),
                               style: StrokeStyle(lineWidth: 2, dash: percussive ? [4, 3] : []))

                for (label, x) in [("A", (p.start.x + p.peak.x) / 2),
                                   ("D", (p.peak.x + p.sustain.x) / 2),
                                   ("S", (p.sustain.x + p.holdEnd.x) / 2),
                                   ("R", (p.holdEnd.x + p.end.x) / 2)] {
                    context.draw(Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary),
                                 at: CGPoint(x: x, y: size.height - 2), anchor: .bottom)
                }

                drawHandle(&context, at: p.peak, dimmed: isLocked(.attack))
                drawHandle(&context, at: p.sustain, dimmed: isLocked(.decay) && isLocked(.sustain))
                drawHandle(&context, at: p.end, dimmed: isLocked(.release) || percussive)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if active == nil { active = nearestHandle(to: value.startLocation, points: points) }
                        drag(active, to: value.location, size: geo.size)
                    }
                    .onEnded { _ in active = nil }
            )
        }
        .frame(height: 130)
        .overlay(alignment: .topTrailing) {
            Text(percussive ? "서스테인 0 · 릴리스는 들리지 않음" : "가운데 평평한 곳 = 누르고 있는 동안")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(6)
        }
    }

    private struct Corners {
        let start, peak, sustain, holdEnd, end: CGPoint
    }

    private func corners(in size: CGSize) -> Corners {
        let width = size.width - inset * 2
        let top: CGFloat = 26
        let bottom = size.height - 16
        let sustainY = bottom - CGFloat(patch.sustain) * (bottom - top)

        let start = CGPoint(x: inset, y: bottom)
        let peak = CGPoint(x: start.x + CGFloat(SynthParameter.attack.normalized(patch.attack)) * width * attackZone, y: top)
        let sustain = CGPoint(x: peak.x + CGFloat(SynthParameter.decay.normalized(patch.decay)) * width * decayZone, y: sustainY)
        let holdEnd = CGPoint(x: sustain.x + width * holdZone, y: sustainY)
        let end = CGPoint(x: holdEnd.x + CGFloat(SynthParameter.release.normalized(patch.release)) * width * releaseZone, y: bottom)
        return Corners(start: start, peak: peak, sustain: sustain, holdEnd: holdEnd, end: end)
    }

    private func nearestHandle(to location: CGPoint, points: Corners) -> Handle {
        let candidates: [(Handle, CGPoint)] = [(.peak, points.peak), (.sustain, points.sustain), (.end, points.end)]
        return candidates.min { hypot($0.1.x - location.x, $0.1.y - location.y) < hypot($1.1.x - location.x, $1.1.y - location.y) }!.0
    }

    private func drag(_ handle: Handle?, to location: CGPoint, size: CGSize) {
        guard let handle else { return }
        let width = size.width - inset * 2
        let p = corners(in: size)
        switch handle {
        case .peak:
            let t = (location.x - p.start.x) / (width * attackZone)
            onChange(.attack, SynthParameter.attack.denormalized(Float(t)))
        case .sustain:
            let t = (location.x - p.peak.x) / (width * decayZone)
            onChange(.decay, SynthParameter.decay.denormalized(Float(t)))
            let top: CGFloat = 26
            let bottom = size.height - 16
            let level = (bottom - location.y) / (bottom - top)
            onChange(.sustain, Float(min(max(level, 0), 1)))
        case .end:
            let t = (location.x - p.holdEnd.x) / (width * releaseZone)
            onChange(.release, SynthParameter.release.denormalized(Float(t)))
        }
    }

    private func drawHandle(_ context: inout GraphicsContext, at point: CGPoint, dimmed: Bool) {
        let rect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
        context.fill(Path(ellipseIn: rect), with: .color(.accentColor.opacity(dimmed ? 0.25 : 1)))
        context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 2)
    }
}

// MARK: - Pitch

/// Pitch over time. The start handle sets where the sweep begins, the end handle the
/// pitch it settles on. Noise fades the line, because noise has no pitch to draw.
struct PitchContourGraph: View {
    let patch: Patch
    let isLocked: (SynthParameter) -> Bool
    let onChange: (SynthParameter, Float) -> Void

    private enum Handle { case start, end }
    @State private var active: Handle?

    private static let lowest: Float = 25
    private static let highest: Float = 20_000
    private let inset: CGFloat = 14
    private let sweepShare: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                if patch.noiseMix > 0.01 {
                    context.fill(Path(CGRect(origin: .zero, size: size)),
                                 with: .color(.gray.opacity(Double(patch.noiseMix) * 0.25)))
                }

                for hz: Float in [100, 1_000, 10_000] {
                    let y = yPosition(hz, height: size.height)
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(.secondary.opacity(0.18)), lineWidth: 0.5)
                    context.draw(Text(hz >= 1_000 ? "\(Int(hz / 1_000))k" : "\(Int(hz))")
                                    .font(.system(size: 9).monospaced())
                                    .foregroundStyle(.secondary),
                                 at: CGPoint(x: size.width - 4, y: y - 2), anchor: .bottomTrailing)
                }

                let p = points(in: size)
                var contour = Path()
                contour.move(to: p.start)
                contour.addLine(to: p.end)
                contour.addLine(to: CGPoint(x: size.width - inset, y: p.end.y))
                let clarity = 1 - Double(patch.noiseMix) * 0.8
                context.stroke(contour, with: .color(.accentColor.opacity(clarity)),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                drawHandle(&context, at: p.start, dimmed: isLocked(.pitchSweep))
                drawHandle(&context, at: p.end, dimmed: isLocked(.pitch))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let p = points(in: geo.size)
                        if active == nil {
                            let toStart = hypot(value.startLocation.x - p.start.x, value.startLocation.y - p.start.y)
                            let toEnd = hypot(value.startLocation.x - p.end.x, value.startLocation.y - p.end.y)
                            active = toStart < toEnd ? .start : .end
                        }
                        let hz = frequency(atY: value.location.y, height: geo.size.height)
                        switch active {
                        case .start:
                            let semitones = 12 * log2(hz / patch.pitch)
                            onChange(.pitchSweep, min(max(semitones, -36), 48))
                        case .end:
                            onChange(.pitch, min(max(hz, 30), 2_000))
                        case nil:
                            break
                        }
                    }
                    .onEnded { _ in active = nil }
            )
        }
        .frame(height: 120)
        .overlay(alignment: .topLeading) {
            Text(patch.noiseMix > 0.7 ? "노이즈가 많아 음높이가 흐려짐" : "왼쪽 점 = 치는 순간 · 오른쪽 점 = 자리잡는 음")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(6)
        }
    }

    private func points(in size: CGSize) -> (start: CGPoint, end: CGPoint) {
        let startHz = patch.pitch * pow(2, patch.pitchSweep / 12)
        let endX = inset + (size.width - inset * 2) * sweepShare
        return (CGPoint(x: inset, y: yPosition(startHz, height: size.height)),
                CGPoint(x: endX, y: yPosition(patch.pitch, height: size.height)))
    }

    private func yPosition(_ hz: Float, height: CGFloat) -> CGFloat {
        let clamped = min(max(hz, Self.lowest), Self.highest)
        let t = log(clamped / Self.lowest) / log(Self.highest / Self.lowest)
        let top: CGFloat = 22, bottom = height - 8
        return bottom - CGFloat(t) * (bottom - top)
    }

    private func frequency(atY y: CGFloat, height: CGFloat) -> Float {
        let top: CGFloat = 22, bottom = height - 8
        let t = Float(min(max((bottom - y) / (bottom - top), 0), 1))
        return Self.lowest * pow(Self.highest / Self.lowest, t)
    }

    private func drawHandle(_ context: inout GraphicsContext, at point: CGPoint, dimmed: Bool) {
        let rect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
        context.fill(Path(ellipseIn: rect), with: .color(.accentColor.opacity(dimmed ? 0.25 : 1)))
        context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 2)
    }
}
