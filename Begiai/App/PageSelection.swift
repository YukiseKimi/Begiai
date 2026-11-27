import BegiaiKit

/// The train or station open on a tab: in the map's panel, or in the Line Diagram's sheet or
/// column. RootView holds one for each tab, so it knows when a page is open.
enum PageSelection: Hashable, Identifiable {
    case train(TrainState.ID)
    case station(Int)

    var id: Self { self }
}
