import SwiftUI
import SwiftData

struct CurriculumView: View {
    @Query private var completions: [TaskCompletion]

    private var completedIDs: Set<String> {
        Set(completions.map(\.taskID))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("소리는 혼자서 감정을 만들지 못합니다. 감정은 소리와 타이밍과 맥락이 겹칠 때 생깁니다.")
                            .font(.callout)
                        Text("그래서 이 커리큘럼은 소리를 따로 만드는 훈련이 아니라, 항상 붙일 대상과 함께 만드는 훈련입니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("지켜야 할 세 가지") {
                    ForEach(Array(Curriculum.principles.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(item.0)")
                                .font(.subheadline.weight(.semibold))
                            Text(item.1)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("단계") {
                    ForEach(Curriculum.all) { phase in
                        NavigationLink {
                            PhaseDetailView(phase: phase)
                        } label: {
                            PhaseRow(phase: phase, completedIDs: completedIDs)
                        }
                    }
                }

                Section {
                    ForEach(Curriculum.shipList) { item in
                        NavigationLink {
                            ShipDetailView(item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(item.id). \(item.title)")
                                    .font(.subheadline.weight(.medium))
                                Text(item.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("만들 것 · W7부터 병행")
                } footer: {
                    Text("마지막 한 달에는 새 단계가 없습니다. 만드는 데만 씁니다.")
                }
            }
            .navigationTitle("6개월 커리큘럼")
        }
    }
}

private struct PhaseRow: View {
    let phase: Phase
    let completedIDs: Set<String>

    private var done: Int {
        phase.tasks.filter { completedIDs.contains($0.id) }.count
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(phase.tint)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(phase.title)
                    .font(.headline)
                Text(phase.weeks)
                    .font(.caption.monospaced())
                    .foregroundStyle(phase.tint)
            }

            Spacer()

            Text("\(done)/\(phase.tasks.count)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct PhaseDetailView: View {
    let phase: Phase

    @Environment(\.modelContext) private var context
    @Query private var completions: [TaskCompletion]

    var body: some View {
        List {
            Section {
                Text(phase.why)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("과제") {
                ForEach(phase.tasks) { task in
                    NavigationLink {
                        TaskDetailView(task: task, tint: phase.tint)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: isDone(task) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isDone(task) ? phase.tint : .secondary)
                                .font(.body)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title)
                                    .font(.subheadline.weight(.medium))
                                    .strikethrough(isDone(task), color: .secondary)
                                Text(task.rationale)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("이 단계의 결과물") {
                Text(phase.deliverable)
                    .font(.footnote)
            }
        }
        .navigationTitle(phase.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isDone(_ task: CurriculumTask) -> Bool {
        completions.contains { $0.taskID == task.id }
    }
}

struct TaskDetailView: View {
    let task: CurriculumTask
    let tint: Color

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query private var completions: [TaskCompletion]

    private var isDone: Bool {
        completions.contains { $0.taskID == task.id }
    }

    var body: some View {
        List {
            Section {
                Text(task.rationale)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("방법") {
                ForEach(Array(task.method.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospaced())
                            .foregroundStyle(tint)
                            .frame(width: 16, alignment: .leading)
                            .padding(.top, 2)
                        Text(step)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("완료 기준") {
                Text(task.doneWhen)
                    .font(.subheadline)
            }

            if let label = toolLabel {
                Section("어디서 하는가") {
                    if isExternal {
                        Text(label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            openTool()
                        } label: {
                            Label(label, systemImage: "arrow.forward.circle")
                        }
                    }
                }
            }

            Section {
                Button {
                    toggle()
                } label: {
                    Label(isDone ? "완료 취소" : "완료로 표시",
                          systemImage: isDone ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(tint)
            }
        }
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isExternal: Bool {
        if case .external = task.tool { return true }
        return false
    }

    private var toolLabel: String? {
        switch task.tool {
        case .earTraining:     return "귀 훈련 열기"
        case .synthLab:        return "신스 랩 열기"
        case .referenceNotes:  return "레퍼런스 노트 열기"
        case .fieldRecorder:   return "필드 레코딩 열기"
        case .deliverables:    return "주간 결과물 열기"
        case .external(let s): return s
        }
    }

    private func openTool() {
        switch task.tool {
        case .earTraining(let level):
            router.openEarTraining(level: level)
        case .synthLab(let challenge):
            router.openSynthLab(challenge: challenge)
        case .referenceNotes, .fieldRecorder, .deliverables:
            router.tab = .log
        case .external:
            break
        }
    }

    private func toggle() {
        if let existing = completions.first(where: { $0.taskID == task.id }) {
            context.delete(existing)
        } else {
            context.insert(TaskCompletion(taskID: task.id))
        }
    }
}

struct ShipDetailView: View {
    let item: Curriculum.ShipItem

    var body: some View {
        List {
            Section {
                Text(item.detail)
                    .font(.callout)
            }
            Section("방법") {
                ForEach(Array(item.method.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.red)
                            .frame(width: 16, alignment: .leading)
                            .padding(.top, 2)
                        Text(step)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
