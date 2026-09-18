import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            CurriculumView()
                .tabItem { Label("커리큘럼", systemImage: "list.bullet.rectangle") }
                .tag(AppRouter.Tab.curriculum)

            EarTrainingView()
                .tabItem { Label("귀 훈련", systemImage: "ear") }
                .tag(AppRouter.Tab.ear)

            SynthLabView()
                .tabItem { Label("신스 랩", systemImage: "waveform.path") }
                .tag(AppRouter.Tab.synth)

            LogView()
                .tabItem { Label("기록", systemImage: "square.and.pencil") }
                .tag(AppRouter.Tab.log)
        }
    }
}
