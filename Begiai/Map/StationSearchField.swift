import BegiaiKit
import SwiftUI

/// The field above the line filter that finds a station by name.
struct StationSearchField: View {
    @Binding var query: String
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
                    TextField(text: $query, prompt: Text(verbatim: "")) {
                        Text(.mapSearch)
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused(focused)
                    .frame(maxHeight: .infinity)
                    .accessibilityIdentifier(A11yID.Map.search)
                }
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
        // A capsule while the field is one line high; taller, its corners keep that radius.
        .background(.fill.tertiary, in: .rect(cornerRadius: 22))
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
    @Previewable @FocusState var focused: Bool
    VStack {
        StationSearchField(query: $query, focused: $focused)
            .padding(.horizontal)
        StationResults(names: ["Vilnius", "Kaišiadorys", "Kaunas"], query: query) { _ in }
    }
}
