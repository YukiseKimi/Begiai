import BegiaiKit
import SwiftUI

/// The field above the line filter that finds a station by name.
struct StationSearchField: View {
    @Bindable var query: StationQuery
    /// The map tab holds the focus: the field has the keyboard only while the panel is at full height.
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            // A field's own prompt keeps to one line and is cut at the field's edge, with no
            // “…”. This prompt wraps at large text sizes, and the field grows to hold it.
            Text(.mapSearch)
                .foregroundStyle(Color(uiColor: .placeholderText))
                .opacity(query.isEmpty ? 1 : 0)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
                .overlay {
                    // An empty prompt, so the field does not draw its label as a second prompt.
                    TextField(text: $query.text, prompt: Text(verbatim: "")) {
                        Text(.mapSearch)
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused(focused)
                    .frame(maxHeight: .infinity)
                    .accessibilityIdentifier(A11yID.Map.search)
                }
            // The query keeps isEmpty as the text changes, so this body runs again only when the
            // field empties or fills, not at each keystroke.
            if !query.isEmpty {
                Button {
                    query.text = ""
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
        // A capsule while the field is one line high; taller, its corners keep that radius.
        .background(.fill.tertiary, in: .rect(cornerRadius: 22))
    }
}

/// The stations whose names hold the search, in place of the lines; a tap opens a board.
struct StationResults: View {
    let names: [String]
    /// The trips that call at each station, which put the busier stations first.
    var calls: [Int] = []
    let query: StationQuery
    @Binding var selection: PageSelection?
    /// The sheet's height, which a result lowers.
    @Binding var height: PanelHeight

    var body: some View {
        let found = StationSearch.matches(query.text, in: names, calls: calls).map { FoundStation(index: $0, name: names[$0]) }
        List {
            ForEach(found) { station in
                StationResultRow(station: station, selection: $selection, height: $height)
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

/// A station the search found.
private struct FoundStation: Identifiable {
    let index: Int
    let name: String

    var id: Int { index }
}

private struct StationResultRow: View {
    let station: FoundStation
    @Binding var selection: PageSelection?
    @Binding var height: PanelHeight

    var body: some View {
        Button {
            selection = .station(station.index)
            // The search raised the panel; at half height the map shows again beside the board.
            height = .half
        } label: {
            Text(verbatim: station.name)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(.boardStationHint))
        .accessibilityIdentifier(A11yID.Map.searchResult)
    }
}

#Preview {
    @Previewable @State var query = StationQuery(text: "kai")
    @Previewable @FocusState var focused: Bool
    VStack {
        StationSearchField(query: query, focused: $focused)
            .padding(.horizontal)
        StationResults(
            names: ["Vilnius", "Kaišiadorys", "Kaunas"], query: query, selection: .constant(nil), height: .constant(.full))
    }
}
