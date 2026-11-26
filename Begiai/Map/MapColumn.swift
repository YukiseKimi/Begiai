import SwiftUI

/// The map with its panel as a glass column, for a wide screen such as the open iPhone Duo.
/// Open flat, the map fills the screen and the column floats over its trailing side. Partly
/// folded, the arrangement puts the map on one side of the fold and the panel on the other:
/// the map above and the panel below when folded like a laptop, side by side like a book.
@available(iOS 27.1, *)
struct MapColumn<Map: View, Panel: View>: View {
    /// The column's accessibility identifier, which the journeys find it by.
    var identifier = A11yID.Map.column
    /// False while the column has nothing to show: the map then has the whole screen.
    var shows = true
    /// The map, given what it keeps clear for the column, from the screen's edges. Only the
    /// column knows that, so the map is view-builder content called with it once per body.
    @ViewBuilder let map: (EdgeInsets) -> Map
    let panel: Panel
    /// True while a fold divides the screen, so the panel has a side of its own.
    @State private var divided = false
    @State private var screenMaxX: CGFloat = 0
    @State private var columnMinX: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        identifier: String = A11yID.Map.column, shows: Bool = true, @ViewBuilder map: @escaping (EdgeInsets) -> Map,
        @ViewBuilder panel: () -> Panel
    ) {
        self.identifier = identifier
        self.shows = shows
        self.map = map
        self.panel = panel()
    }

    var body: some View {
        // The overlay style puts the primary view over the secondary one on a flat screen, and
        // the secondary above or before the fold, the primary below or after it.
        ArrangementView {
            if shows {
                ColumnGlass(identifier: identifier, divided: divided, content: panel)
                    .onGeometryChange(for: CGFloat.self) {
                        $0.frame(in: .global).minX
                    } action: {
                        columnMinX = $0
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        } secondary: {
            map(
                divided || !shows
                    ? EdgeInsets() : EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: max(0, screenMaxX - columnMinX))
            )
            // The map reaches under the safe area, such as the tab strip on the right of the
            // open Duo held wide, so the screen's edge is past the map's frame by that inset.
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).maxX + $0.safeAreaInsets.trailing
            } action: {
                screenMaxX = $0
            }
        }
        .arrangementViewStyle(.overlay)
        // With Reduce Motion the column shows and goes at once.
        .animation(reduceMotion ? nil : .snappy, value: shows)
        .onGeometryChange(for: Bool.self) {
            !$0.reservedRegions(kind: .division).isEmpty
        } action: {
            divided = $0
        }
    }

}

/// The panel in a glass column; on a side of its own beside a fold, it takes that whole side.
private struct ColumnGlass<Content: View>: View {
    /// The column's accessibility identifier, which the journeys find it by.
    let identifier: String
    /// True while a fold divides the screen. The column's width cannot change whether it does,
    /// so the width that follows it feeds nothing back.
    let divided: Bool
    let content: Content

    var body: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 28), isUniform: true)
        content
            // The arrangement gives its views no margins, so a list's rows would touch the
            // column's edges; these are the margins the sheet's lists have on an iPhone.
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .padding(.top, 12)
            .frame(maxWidth: divided ? .infinity : LayoutMetric.column, maxHeight: .infinity, alignment: .top)
            .clipShape(shape)
            .glassEffect(in: shape)
            // A container that keeps the identifiers of the views inside it, which a plain
            // identifier on the column would replace.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
    }
}

enum LayoutMetric {
    /// The column's width beside the map: the width of the panel on an iPhone.
    static let column: CGFloat = 360
}
