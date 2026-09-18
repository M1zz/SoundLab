import SwiftUI
import SwiftData

struct EarTrainingView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \DrillResult.date, order: .reverse) private var results: [DrillResult]

    @State private var trainer = EarTrainer()
    @State private var savedThisSession = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    levelPicker
                    transport
                    if trainer.sessionFinished {
                        resultCard
                    } else {
                        questionCard
                    }
                    streakCard
                }
                .padding(20)
            }
            .navigationTitle("귀 훈련")
            .onAppear {
                if let level = router.pendingDrillLevel {
                    trainer.level = level
                    router.pendingDrillLevel = nil
                }
                trainer.start()
                if trainer.asked == 0 && !trainer.sessionFinished { trainer.newQuestion() }
            }
            .onDisappear { trainer.stop() }
        }
    }

    // MARK: Pieces

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("난이도", selection: Binding(
                get: { trainer.level },
                set: { newValue in
                    trainer.level = newValue
                    savedThisSession = false
                }
            )) {
                ForEach(DrillLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)

            Text(trainer.level.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 12) {
            Button {
                trainer.isPlaying ? trainer.stop() : trainer.start()
            } label: {
                Label(trainer.isPlaying ? "노이즈 정지" : "노이즈 재생",
                      systemImage: trainer.isPlaying ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                trainer.toggleFlat()
            } label: {
                Label(trainer.isFlat ? "원본 (A)" : "처리됨 (B)", systemImage: "arrow.left.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!trainer.isPlaying)
        }
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("어느 대역이 달라졌나요?")
                    .font(.headline)
                Spacer()
                Text("\(trainer.asked)/\(trainer.questionsPerSession)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 10) {
                ForEach(trainer.level.frequencies, id: \.self) { frequency in
                    Button {
                        trainer.answer(frequency)
                    } label: {
                        Text(frequency.frequencyLabel)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint(for: frequency))
                    .disabled(trainer.answered)
                }
            }

            if trainer.answered {
                let correct = trainer.lastChoice == trainer.currentFrequency
                VStack(alignment: .leading, spacing: 6) {
                    Text(correct ? "정답" : "오답")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(correct ? .green : .red)
                    Text("\(trainer.currentFrequency.frequencyLabel)Hz를 \(trainer.currentGain > 0 ? "부스트" : "컷")했습니다. A/B로 한 번 더 들어 보고 넘어가세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("다음 문제") {
                        trainer.newQuestion()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("세션 완료")
                .font(.headline)
            Text("\(trainer.correct) / \(trainer.questionsPerSession) · 정답률 \(Int(trainer.accuracy * 100))%")
                .font(.title3.monospacedDigit())

            if !trainer.missed.isEmpty {
                let weak = Set(trainer.missed).sorted()
                Text("약한 대역 — \(weak.map { $0.frequencyLabel + "Hz" }.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("이 대역만 골라 10번 더 들어 보세요. 3kHz가 어려운 건 정상입니다. 목소리 명료도 대역이라 평소 인식하지 못한 채 듣고 있어서 그렇습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if trainer.accuracy >= 0.8 {
                Text("다음 난이도로 올릴 준비가 됐습니다. 3세션 연속 80%를 넘겼는지 아래 기록에서 확인하세요.")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }

            Button("한 세션 더") {
                saveIfNeeded()
                trainer.resetSession()
                savedThisSession = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .onAppear { saveIfNeeded() }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 기록")
                .font(.subheadline.weight(.semibold))

            if results.isEmpty {
                Text("아직 없습니다. 하루 15분이 이 단계의 전부입니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results.prefix(7)) { result in
                    HStack {
                        Text(result.date, format: .dateTime.month().day())
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(result.level.title)
                            .font(.caption)
                        Spacer()
                        Text("\(Int(result.accuracy * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(result.accuracy >= 0.8 ? .green : .primary)
                    }
                }

                Text("연속 \(consecutiveDays)일 · 목표 28일 중 24일")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Helpers

    private func tint(for frequency: Double) -> Color {
        guard trainer.answered else { return .accentColor }
        if frequency == trainer.currentFrequency { return .green }
        if frequency == trainer.lastChoice { return .red }
        return .gray
    }

    private func saveIfNeeded() {
        guard trainer.sessionFinished, !savedThisSession, trainer.asked > 0 else { return }
        context.insert(DrillResult(level: trainer.level,
                                   correct: trainer.correct,
                                   total: trainer.asked,
                                   missedFrequencies: trainer.missed))
        savedThisSession = true
    }

    private var consecutiveDays: Int {
        let calendar = Calendar.current
        let days = Set(results.map { calendar.startOfDay(for: $0.date) })
        var count = 0
        var cursor = calendar.startOfDay(for: .now)
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
