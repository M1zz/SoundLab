import SwiftUI
import SwiftData

@main
struct SoundLabApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onAppear { AudioCore.shared.activateSession() }
        }
        .modelContainer(for: [
            TaskCompletion.self,
            DrillResult.self,
            ReferenceNote.self,
            FieldRecording.self,
            Deliverable.self
        ])
    }
}

/// Lets a curriculum task hand the user straight to the tool that performs it.
@Observable
final class AppRouter {
    enum Tab: Hashable { case curriculum, ear, synth, log }

    var tab: Tab = .curriculum
    /// Index into `SynthChallenge.all`, set when a task deep-links to a specific drill.
    var pendingSynthChallenge: Int?
    /// Drill level a task wants the ear trainer to open with.
    var pendingDrillLevel: DrillLevel?

    func openEarTraining(level: DrillLevel?) {
        pendingDrillLevel = level
        tab = .ear
    }

    func openSynthLab(challenge: Int?) {
        pendingSynthChallenge = challenge
        tab = .synth
    }
}
