import BegiaiKit
import SwiftUI

/// The field above the line filter that finds a station by name.
struct StationSearchField: View {
    @Binding var query: String
    /// Runs as the field takes the keyboard, so the panel can rise and give the results room.
    var onFocus: () -> Void = {}
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(text: $query, prompt: Text(.mapSearch)) {
                Text(.mapSearch)
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($focused)
            .onChange(of: focused) { _, now in
                if now { onFocus() }
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier(A11yID.Map.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(.mapSearchClear))
            }
        }
        .padding(.leading, 12)
        .background(.fill.tertiary, in: .capsule)
    }
}

/// The stations whose names hold the search, in place of the lines; a tap opens a board.
struct StationResults: View {
    let names: [String]
    /// The trips that call at each station, which put the busier stations first.
    var calls: [Int] = []
    let query: String
    let open: (Int) -> Void

    var body: some View {
        let found = StationSearch.matches(query, in: names, calls: calls)
        List {
            ForEach(found, id: \.self) { station in
                Button {
                    open(station)
                } label: {
                    Text(verbatim: names[station])
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(.boardStationHint))
                .accessibilityIdentifier(A11yID.Map.searchResult)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if found.isEmpty {
                ContentUnavailableView(.mapSearchNone, systemImage: "magnifyingglass")
            }
        }
    }
}

#Preview {
    @Previewable @State var query = "kai"
    VStack {
        StationSearchField(query: $query)
            .padding(.horizontal)
        StationResults(names: ["Vilnius", "Kaišiadorys", "Kaunas"], query: query) { _ in }
    }
}
