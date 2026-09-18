import SwiftUI
import SwiftData

struct LogView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ReferenceNoteListView()
                    } label: {
                        Label("레퍼런스 노트", systemImage: "square.stack.3d.up")
                    }
                    NavigationLink {
                        FieldRecordingListView()
                    } label: {
                        Label("필드 레코딩", systemImage: "mic")
                    }
                    NavigationLink {
                        DeliverableListView()
                    } label: {
                        Label("주간 결과물", systemImage: "shippingbox")
                    }
                } footer: {
                    Text("미완성은 세지 않습니다. 주 1개, 끝난 것만 기록하세요.")
                }
            }
            .navigationTitle("기록")
        }
    }
}

// MARK: - Reference notes

struct ReferenceNoteListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ReferenceNote.createdAt, order: .reverse) private var notes: [ReferenceNote]
    @State private var showEditor = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("\(notes.count) / 20")
                        .font(.title3.monospacedDigit())
                    Spacer()
                    ProgressView(value: min(Double(notes.count) / 20, 1))
                        .frame(width: 120)
                }
            } footer: {
                Text("감정은 형용사가 아니라 상황으로 쓰세요. '밝다'가 아니라 '일이 끝났다고 알려준다'.")
            }

            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.title)
                        .font(.subheadline.weight(.medium))
                    Text(note.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(note.emotion)
                        .font(.footnote)
                    HStack(spacing: 12) {
                        axis("어택", note.attack)
                        axis("저역", note.lowEnd)
                        axis("거칠기", note.roughness)
                        axis("테일", note.tail)
                    }
                }
                .padding(.vertical, 3)
            }
            .onDelete { offsets in
                for index in offsets { context.delete(notes[index]) }
            }
        }
        .navigationTitle("레퍼런스 노트")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { showEditor = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showEditor) {
            ReferenceNoteEditor()
        }
    }

    private func axis(_ label: String, _ value: Int) -> some View {
        Text("\(label) \(value)")
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
    }
}

struct ReferenceNoteEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var source = ""
    @State private var attack = 3
    @State private var lowEnd = 3
    @State private var roughness = 3
    @State private var tail = 3
    @State private var emotion = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("무슨 소리인가") {
                    TextField("소리 이름", text: $title)
                    TextField("어디서 들었나 (앱·게임 이름)", text: $source)
                }

                Section {
                    stepper("어택 속도", $attack, low: "느림", high: "즉각")
                    stepper("저역 존재감", $lowEnd, low: "없음", high: "강함")
                    stepper("배음 거칠기", $roughness, low: "매끈", high: "거침")
                    stepper("테일 길이", $tail, low: "짧음", high: "김")
                } header: {
                    Text("네 축")
                } footer: {
                    Text("정확할 필요 없습니다. 언어를 강제하려고 있는 항목입니다.")
                }

                Section("이 소리가 만드는 감정") {
                    TextField("상황으로 한 줄", text: $emotion, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("레퍼런스 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        context.insert(ReferenceNote(title: title, source: source,
                                                     attack: attack, lowEnd: lowEnd,
                                                     roughness: roughness, tail: tail,
                                                     emotion: emotion))
                        dismiss()
                    }
                    .disabled(title.isEmpty || emotion.isEmpty)
                }
            }
        }
    }

    private func stepper(_ label: String, _ value: Binding<Int>, low: String, high: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Stepper("\(label) \(value.wrappedValue)", value: value, in: 1...5)
            Text("1 \(low) · 5 \(high)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Field recordings

struct FieldRecordingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FieldRecording.createdAt, order: .reverse) private var recordings: [FieldRecording]
    @State private var recorder = FieldRecorder()
    @State private var label = ""
    @State private var reimagined = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Text("\(recordings.count) / 30")
                        .font(.title3.monospacedDigit())
                    Spacer()
                    ProgressView(value: min(Double(recordings.count) / 30, 1))
                        .frame(width: 120)
                }
            } footer: {
                Text("가까이 대고 녹음하세요. 초보 녹음 문제의 대부분은 마이크가 너무 멀어서 생깁니다.")
            }

            Section("녹음") {
                Button {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.startRecording()
                    }
                } label: {
                    Label(recorder.isRecording
                          ? String(format: "정지 (%.1fs)", recorder.elapsed)
                          : "녹음 시작",
                          systemImage: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                        .foregroundStyle(recorder.isRecording ? .red : .accentColor)
                }

                if recorder.lastFilename != nil && !recorder.isRecording {
                    TextField("무엇을 녹음했나", text: $label)
                    TextField("무엇으로 쓸 수 있나", text: $reimagined)

                    HStack {
                        Button("저장") { save() }
                            .disabled(label.isEmpty)
                        Spacer()
                        Button("버리기", role: .destructive) {
                            recorder.discardLast()
                            label = ""
                            reimagined = ""
                        }
                    }
                }
            }

            Section("라이브러리") {
                ForEach(recordings) { recording in
                    Button {
                        recorder.play(filename: recording.filename)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(recording.label)
                                .font(.subheadline.weight(.medium))
                            if !recording.reimaginedAs.isEmpty {
                                Text("→ \(recording.reimaginedAs)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Text(String(format: "%.1fs", recording.duration))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets {
                        let item = recordings[index]
                        try? FileManager.default.removeItem(at: item.fileURL)
                        context.delete(item)
                    }
                }
            }
        }
        .navigationTitle("필드 레코딩")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { recorder.requestPermission() }
    }

    private func save() {
        guard let filename = recorder.lastFilename else { return }
        context.insert(FieldRecording(label: label,
                                      filename: filename,
                                      reimaginedAs: reimagined,
                                      duration: recorder.lastDuration))
        recorder.lastFilename = nil
        label = ""
        reimagined = ""
    }
}

// MARK: - Deliverables

struct DeliverableListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Deliverable.week, order: .reverse) private var deliverables: [Deliverable]

    @State private var week = 1
    @State private var title = ""
    @State private var note = ""

    var body: some View {
        List {
            Section("이번 주 결과물") {
                Stepper("W\(week)", value: $week, in: 1...26)
                TextField("무엇을 끝냈나", text: $title)
                TextField("무엇을 배웠나 — 소리가 왜 그 감정을 만들었는지", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                Button("저장") {
                    context.insert(Deliverable(week: week, title: title, note: note))
                    title = ""
                    note = ""
                    if week < 26 { week += 1 }
                }
                .disabled(title.isEmpty)
            }

            Section("지난 기록 (\(deliverables.count)/26)") {
                ForEach(deliverables) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("W\(item.week)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                        }
                        if !item.note.isEmpty {
                            Text(item.note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(deliverables[index]) }
                }
            }
        }
        .navigationTitle("주간 결과물")
        .navigationBarTitleDisplayMode(.inline)
    }
}
