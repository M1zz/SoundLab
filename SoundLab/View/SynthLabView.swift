import SwiftUI

struct SynthLabView: View {
    @Environment(AppRouter.self) private var router
    @State private var synth = MiniSynth()
    @State private var showHint = false
    @State private var portraitMode: PortraitMode = .outline
    @State private var minePicture: SoundPicture?
    @State private var targetPicture: SoundPicture?
    @State private var pressing = false

    /// What the pictures are drawn from. Changing either redraws both on a shared time axis.
    private struct PortraitKey: Equatable {
        let mine: Patch
        let target: Patch?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    challengePicker
                    portraitCard
                    if let challenge = synth.selectedChallenge {
                        challengeNotes(challenge)
                    }
                    focusCard
                    ForEach(SynthModule.allCases) { module in
                        moduleCard(module)
                        if module != SynthModule.allCases.last {
                            Image(systemName: "arrow.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, -8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .safeAreaInset(edge: .bottom) { playBar }
            .navigationTitle("신스 랩")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: PortraitKey(mine: synth.patch, target: synth.selectedChallenge?.target)) {
                await redraw()
            }
            .onAppear {
                synth.start()
                if let index = router.pendingSynthChallenge,
                   index < SynthChallenge.all.count {
                    synth.select(SynthChallenge.all[index])
                    router.pendingSynthChallenge = nil
                }
            }
            .onDisappear { synth.stop() }
        }
    }

    /// Renders both sounds off the main thread. Debounced by `task(id:)` cancelling
    /// the previous run while a slider is still moving.
    private func redraw() async {
        let mine = synth.patch
        let target = synth.selectedChallenge?.target
        try? await Task.sleep(for: .milliseconds(30))
        guard !Task.isCancelled else { return }

        let pictures = await Task.detached(priority: .userInitiated) {
            let duration = SoundAnalyzer.duration(for: [mine] + (target.map { [$0] } ?? []))
            return (SoundAnalyzer.picture(of: mine, duration: duration),
                    target.map { SoundAnalyzer.picture(of: $0, duration: duration) })
        }.value

        guard !Task.isCancelled else { return }
        minePicture = pictures.0
        targetPicture = pictures.1
    }

    // MARK: Challenge

    private var challengePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "자유 탐색", symbol: "slider.horizontal.3",
                     selected: synth.selectedChallenge == nil, passed: false) {
                    synth.select(nil)
                }
                ForEach(SynthChallenge.all) { challenge in
                    chip(title: challenge.title, symbol: challenge.symbol,
                         selected: synth.selectedChallenge?.id == challenge.id,
                         passed: synth.passedChallenges.contains(challenge.id)) {
                        synth.select(challenge)
                    }
                }
            }
        }
    }

    private func chip(title: String, symbol: String, selected: Bool, passed: Bool,
                      action: @escaping () -> Void) -> some View {
        Button {
            showHint = false
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: passed ? "checkmark.circle.fill" : symbol)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .buttonStyle(.bordered)
        .tint(selected ? .accentColor : .gray)
    }

    // MARK: Portrait

    private var portraitCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(synth.selectedChallenge.map { "\($0.title) 만들기" } ?? "내 소리")
                    .font(.headline)
                Spacer()
                Picker("표시", selection: $portraitMode) {
                    ForEach(PortraitMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }

            if let challenge = synth.selectedChallenge {
                Text(challenge.brief)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                SoundLane(title: "목표", color: .orange, picture: targetPicture, mode: portraitMode,
                          playStart: synth.playhead?.isTarget == true ? synth.playhead?.start : nil)
                    .onTapGesture { synth.playTarget() }
            }

            SoundLane(title: "내 소리", color: .accentColor, picture: minePicture, mode: portraitMode,
                      playStart: synth.playhead?.isTarget == false ? synth.playhead?.start : nil)
                .onTapGesture { synth.playMine() }

            HStack {
                Text("0초")
                Spacer()
                Text(portraitMode.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(String(format: "%.2f초", minePicture?.duration ?? 0))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let challenge = synth.selectedChallenge,
               let minePicture, let targetPicture {
                Divider()
                TraitComparison(target: SoundTraits(patch: challenge.target, picture: targetPicture),
                                mine: SoundTraits(patch: synth.patch, picture: minePicture))

                if let distance = synth.distanceToTarget {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: distance)
                            .tint(distance > 0.85 ? .green : .accentColor)
                        Text("근접도 \(Int(distance * 100))% — 참고용입니다. 최종 판단은 귀로 하세요.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
    }

    private func challengeNotes(_ challenge: SynthChallenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup("힌트 · 최소 10분 직접 해본 뒤 열기", isExpanded: $showHint) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(challenge.hint.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(line)
                                .font(.footnote)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .font(.subheadline)

            Button {
                synth.markPassed()
            } label: {
                Label(synth.passedChallenges.contains(challenge.id) ? "통과함" : "통과로 표시",
                      systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(synth.passedChallenges.contains(challenge.id))
        }
        .padding(14)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Focus

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("집중 모드", systemImage: "scope")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(synth.explored.count)/\(SynthParameter.allCases.count) 돌려봄")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let focus = synth.focus {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(focus.label)만 움직입니다")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                        Text(focus.teaches)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("해제") { synth.focus = nil }
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
            } else {
                Text("파라미터 이름을 탭하면 그것만 남고 나머지는 잠깁니다. 극단까지 돌렸다가 되돌리세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    synth.captureBaseline()
                } label: {
                    Label("지금을 기준으로", systemImage: "bookmark")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    synth.resetToBaseline()
                } label: {
                    Label("기준으로 되돌리기", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Modules

    private func moduleCard(_ module: SynthModule) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\(module.rawValue + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.accentColor, in: Circle())
                Text(module.title)
                    .font(.headline)
                Text(module.question)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            graph(for: module)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            ForEach(module.parameters) { parameter in
                if parameter == .waveform {
                    waveformPicker
                } else if parameter == .filterMode {
                    filterModePicker
                } else {
                    ParameterSlider(parameter: parameter, synth: synth)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func graph(for module: SynthModule) -> some View {
        switch module {
        case .source:
            PitchContourGraph(patch: synth.patch, isLocked: synth.isLocked, onChange: { synth.setValue($1, for: $0) })
        case .filter:
            FilterResponseGraph(patch: synth.patch,
                                cutoffLocked: synth.isLocked(.cutoff),
                                resonanceLocked: synth.isLocked(.resonance),
                                onCutoff: { synth.setValue($0, for: .cutoff) },
                                onResonance: { synth.setValue($0, for: .resonance) })
        case .amp:
            EnvelopeGraph(patch: synth.patch, isLocked: synth.isLocked, onChange: { synth.setValue($1, for: $0) })
        }
    }

    private var waveformPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            ParameterHeader(parameter: .waveform, synth: synth)
            HStack(spacing: 8) {
                ForEach(Waveform.allCases) { waveform in
                    tile(label: waveform.label, selected: synth.patch.waveform == waveform,
                         locked: synth.isLocked(.waveform)) {
                        WaveformGlyph(waveform: waveform)
                            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    } action: {
                        synth.setValue(Float(waveform.rawValue), for: .waveform)
                    }
                }
            }
        }
        .opacity(synth.isLocked(.waveform) ? 0.35 : 1)
    }

    private var filterModePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            ParameterHeader(parameter: .filterMode, synth: synth)
            HStack(spacing: 8) {
                ForEach(StateVariableFilter.Mode.allCases) { mode in
                    tile(label: mode.label, selected: synth.patch.filterMode == mode,
                         locked: synth.isLocked(.filterMode)) {
                        FilterModeGlyph(mode: mode)
                            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    } action: {
                        synth.setValue(Float(mode.rawValue), for: .filterMode)
                    }
                }
            }
        }
        .opacity(synth.isLocked(.filterMode) ? 0.35 : 1)
    }

    private func tile<Glyph: View>(label: String, selected: Bool, locked: Bool,
                                   @ViewBuilder glyph: () -> Glyph,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                glyph()
                    .frame(height: 22)
                    .padding(.horizontal, 6)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? Color.accentColor : Color(.systemBackground),
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    // MARK: Play bar

    private var playBar: some View {
        HStack(spacing: 10) {
            if synth.selectedChallenge != nil {
                barButton(title: "목표", symbol: "target", tint: .orange) { synth.playTarget() }
                barButton(title: "A/B", symbol: "arrow.left.arrow.right", tint: .gray) { synth.playAB() }
            }

            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text("내 소리")
                        .font(.subheadline.weight(.semibold))
                    Text("탭하면 한 번 · 누르고 있으면 유지")
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.accentColor.opacity(pressing ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(pressing ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: pressing)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressing else { return }
                        pressing = true
                        synth.press()
                    }
                    .onEnded { _ in
                        pressing = false
                        synth.release()
                    }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func barButton(title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                Text(title).font(.caption2.weight(.semibold))
            }
            .frame(width: 58, height: 54)
        }
        .buttonStyle(.bordered)
        .tint(tint)
    }
}

// MARK: - Parameter rows

/// Name, value and the focus toggle. Tapping the name focuses the parameter.
private struct ParameterHeader: View {
    let parameter: SynthParameter
    @Bindable var synth: MiniSynth

    var body: some View {
        HStack {
            Button {
                synth.focus = (synth.focus == parameter) ? nil : parameter
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: synth.focus == parameter ? "scope"
                          : synth.explored.contains(parameter) ? "checkmark.circle" : "circle.dashed")
                        .font(.caption2)
                    Text(parameter.label)
                        .font(.subheadline.weight(.medium))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(synth.focus == parameter ? Color.accentColor : .primary)

            Spacer()

            Text(parameter.formatted(parameter.value(in: synth.patch)))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

private struct ParameterSlider: View {
    let parameter: SynthParameter
    @Bindable var synth: MiniSynth

    private var locked: Bool { synth.isLocked(parameter) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ParameterHeader(parameter: parameter, synth: synth)
            Slider(
                value: Binding(
                    get: { synth.position(of: parameter) },
                    set: { synth.setPosition($0, for: parameter) }
                ),
                in: 0...1
            )
            .disabled(locked)
        }
        .opacity(locked ? 0.35 : 1)
    }
}
