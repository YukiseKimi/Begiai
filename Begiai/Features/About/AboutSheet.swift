import BegiaiKit
import SwiftUI

/// The ⓘ button on the map. It opens About.
struct AboutButton: View {
    let timetable: Timetable?
    @State private var showsAbout = false

    var body: some View {
        Button {
            showsAbout = true
        } label: {
            MapCircleLabel(systemName: "info")
        }
        .buttonStyle(.plain)
        .glassEffect(in: .circle)
        .accessibilityLabel(Text(.aboutOpen))
        .accessibilityShowsLargeContentViewer {
            Label {
                Text(.aboutOpen)
            } icon: {
                Image(systemName: "info")
            }
        }
        .accessibilityIdentifier(A11yID.About.open)
        .sheet(isPresented: $showsAbout) {
            AboutSheet(timetable: timetable)
        }
    }
}

/// What the app is, where its data comes from, and how to read a train. The welcome cards
/// say the same once; this page keeps it.
struct AboutSheet: View {
    let timetable: Timetable?
    @Environment(\.dismiss) private var dismiss

    static let gtfs = URL(string: "https://www.visimarsrutai.lt/gtfs/")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(.trainEstimated)
                    LegendRow(text: .aboutLegendTrain) {
                        TrainBullet().fill(.tint).frame(width: 11, height: 20).rotationEffect(.degrees(45))
                    }
                    LegendRow(text: .aboutLegendArrow) {
                        Image(systemName: "location.north.fill").foregroundStyle(.tint)
                    }
                    LegendRow(text: .aboutLegendStation) {
                        Image(systemName: "sparkle").foregroundStyle(.tint)
                    }
                } header: {
                    Text(.aboutHowTitle)
                }

                Section {
                    if let built = timetable?.builtOn {
                        Text(
                            .aboutTimetableDate(
                                date: built.midnight.formatted(
                                    Date.FormatStyle(timeZone: Vilnius.timeZone).day().month(.abbreviated).year()))
                        )
                        .accessibilityIdentifier(A11yID.About.timetableDate)
                    }
                    Link(destination: Self.gtfs) {
                        Text(.aboutSourceTimetable)
                    }
                    .speaksAsLink()
                    .accessibilityIdentifier(A11yID.About.source)
                    Text(.aboutSourceMap)
                    NoticesLink(font: .body)
                } header: {
                    Text(.aboutSourcesTitle)
                }

                DisplaySettings()

                TipJar()

                Section {
                    Text(.aboutUnofficial)
                        .accessibilityIdentifier(A11yID.About.unofficial)
                    Text(.aboutPrivacy)
                    Text(.aboutVersion(version: Self.version))
                        .foregroundStyle(.secondary)
                } header: {
                    Text(.aboutAppTitle)
                }
            }
            .navigationTitle(Text(.aboutTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Close stays at the top trailing corner, where the approved About shot has it.
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) { dismiss() }
                        .accessibilityIdentifier(A11yID.About.close)
                }
            }
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

private struct LegendRow<Icon: View>: View {
    let text: LocalizedStringResource
    let icon: Icon

    init(text: LocalizedStringResource, @ViewBuilder icon: () -> Icon) {
        self.text = text
        self.icon = icon()
    }

    var body: some View {
        Label {
            Text(text)
        } icon: {
            icon
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    AboutSheet(timetable: nil)
}
