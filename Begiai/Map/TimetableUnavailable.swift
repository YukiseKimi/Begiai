import BegiaiKit
import SwiftUI

/// What a tab shows while the timetable loads, or when it failed: the same words on each tab,
/// so no tab spins for ever.
struct TimetableUnavailable: View {
    let state: TimetableStore.State

    var body: some View {
        switch state {
        case .loading:
            ProgressView {
                Text(.timetableLoading)
            }
        case .failed:
            ContentUnavailableView(.mapLoadFailed, systemImage: "tram", description: Text(.mapLoadFailedDetail))
        case .ready:
            EmptyView()
        }
    }
}

#Preview {
    TimetableUnavailable(state: .failed("No file"))
}
