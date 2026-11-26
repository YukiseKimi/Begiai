import BegiaiKit
import SwiftUI

struct RootView: View {
    let store: TimetableStore
    var mayWelcome = false
    @AppStorage("welcome.seen") private var welcomeSeen = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.timeSource) private var time
    @State private var tab = RootTab.map
    /// A train link to open, from a tap on the Live Activity, kept until the timetable is in.
    @State private var link: TrainLink?
    /// True after a link to a train that no longer runs: the map says so.
    @State private var linkedTrainGone = false
    /// The page open on each tab, held here so a newer timetable waits until none is open.
    @State private var mapSelection: PanelSelection?
    /// The train the map keeps in its middle, while Follow is on and the map was not moved.
    @State private var mapFollowing: TrainState.ID?
    @State private var diagramSelection: DiagramSelection?

    /// Open on the first launch; closing it marks the welcome as seen.
    private var showsWelcome: Binding<Bool> {
        Binding(get: { mayWelcome && !welcomeSeen }, set: { if !$0 { welcomeSeen = true } })
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab(.tabMap, systemImage: "map", value: .map) {
                MapTab(store: store, selection: $mapSelection, following: $mapFollowing)
            }
            Tab(.tabLineDiagram, systemImage: "point.topleft.down.to.point.bottomright.curvepath", value: .lineDiagram) {
                LineDiagramTab(store: store, selection: $diagramSelection)
            }
        }
        .overlay(alignment: .top) {
            if linkedTrainGone {
                TrainGoneNote { linkedTrainGone = false }
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
        .onOpenURL { url in
            link = TrainLink(url: url)
        }
        .onChange(of: LinkOpening(link: link, revision: store.revision), initial: true) {
            openLink()
        }
    }

    /// Opens the linked train's page on the map, or, once the train has arrived, the map with
    /// a note that says so. A tap on the Live Activity asks to see its train, so the map follows
    /// it again, also after a drag let it go.
    private func openLink() {
        guard let link, let engine = store.engine else { return }
        self.link = nil
        tab = .map
        if let train = engine.train(for: link, at: time.now) {
            linkedTrainGone = false
            mapSelection = .train(train.id)
            mapFollowing = train.id
        } else {
            mapSelection = nil
            linkedTrainGone = true
        }
    }

    /// True when no train or station is open on either tab.
    private var idle: Bool {
        mapSelection == nil && diagramSelection == nil
    }
}

private enum RootTab: Hashable {
    case map
    case lineDiagram
}

private struct LinkOpening: Equatable {
    let link: TrainLink?
    let revision: Int
}

#Preview {
    RootView(store: TimetableStore())
        .environment(TrainFollower())
}
