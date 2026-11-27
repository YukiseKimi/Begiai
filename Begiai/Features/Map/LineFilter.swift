import BegiaiKit
import SwiftUI

extension LineFilter {
    var title: LocalizedStringResource {
        switch self {
        case .all: .filterAll
        case .starred: .filterStarred
        case .international: .filterInternational
        }
    }
}

struct LineFilterPicker: View {
    @Binding var filter: LineFilter

    var body: some View {
        Picker(selection: $filter) {
            ForEach(LineFilter.allCases, id: \.self) { filter in
                Text(filter.title).tag(filter)
            }
        } label: {
            Text(.filterLabel)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: filter)
        .accessibilityIdentifier(A11yID.Map.filter)
    }
}
