import BegiaiKit
import SwiftUI

struct RootView: View {
    let store: TimetableStore
    var mayWelcome = false
    @AppStorage("welcome.seen") private var welcomeSeen = false
    @Environment(\.scenePhase) private var scenePhase
    /// The page open on each tab, held here so a newer timetable waits until none is open.
    @State private var mapSelection: PanelSelection?
    @State private var diagramSelection: DiagramSelection?

    /// Open on the first launch; closing it marks the welcome as seen.
    private var showsWelcome: Binding<Bool> {
        Binding(get: { mayWelcome && !welcomeSeen }, set: { if !$0 { welcomeSeen = true } })
    }

    var body: some View {
        TabView {
            Tab(.tabMap, systemImage: "map") {
                MapTab(store: store, selection: $mapSelection)
            }
            Tab(.tabLineDiagram, systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                LineDiagramTab(store: store, selection: $diagramSelection)
            }
        }
        .environment(\.linePalette, LinePalette(slots: store.lineColours))
        .modifier(MarkerStyleReader())
        .sheet(isPresented: showsWelcome) {
            WelcomeSheet { welcomeSeen = true }
                .interactiveDismissDisabled()
        }
        // On a return to the app, a newer saved timetable takes over, but only when no train
        // or station is open, so nothing the rider looks at jumps. The store asks again just
        // before the swap, since a page can open while it reads the saved copy.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, idle else { return }
            Task { await store.adoptPending { idle } }
        }
    }

    /// True when no train or station is open on either tab.
    private var idle: Bool {
        mapSelection == nil && diagramSelection == nil
    }
}

#Preview {
    RootView(store: TimetableStore())
}
