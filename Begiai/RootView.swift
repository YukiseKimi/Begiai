import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab(.tabMap, systemImage: "map") {
                Color.clear
                    .accessibilityIdentifier(A11yID.Map.page)
            }
            Tab(.tabLineDiagram, systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                Color.clear
                    .accessibilityIdentifier(A11yID.LineDiagram.page)
            }
        }
    }
}

#Preview {
    RootView()
}
