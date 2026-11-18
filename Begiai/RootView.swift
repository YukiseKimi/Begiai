import BegiaiKit
import SwiftUI

struct RootView: View {
    let store: TimetableStore

    var body: some View {
        TabView {
            Tab(.tabMap, systemImage: "map") {
                MapTab(store: store)
            }
            Tab(.tabLineDiagram, systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                LineDiagramTab(store: store)
            }
        }
    }
}

#Preview {
    RootView(store: TimetableStore())
}
