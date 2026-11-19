import BegiaiKit
import SwiftUI

struct RootView: View {
    let store: TimetableStore
    var mayWelcome = false
    @AppStorage("welcome.seen") private var welcomeSeen = false

    /// Open on the first launch; closing it marks the welcome as seen.
    private var showsWelcome: Binding<Bool> {
        Binding(get: { mayWelcome && !welcomeSeen }, set: { if !$0 { welcomeSeen = true } })
    }

    var body: some View {
        TabView {
            Tab(.tabMap, systemImage: "map") {
                MapTab(store: store)
            }
            Tab(.tabLineDiagram, systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                LineDiagramTab(store: store)
            }
        }
        .sheet(isPresented: showsWelcome) {
            WelcomeSheet { welcomeSeen = true }
                .interactiveDismissDisabled()
        }
    }
}

#Preview {
    RootView(store: TimetableStore())
}
