import CoreLocation
import SwiftUI

/// Why the Locate button cannot show the rider: said at the top of the map panel after a tap.
enum LocationNote {
    /// The rider said no; Settings can change that.
    case denied
    /// The iPhone does not allow it, for example through Screen Time; Settings in the app cannot change that.
    case restricted

    /// The note for the current authorization, or nil when the app may locate the rider or may still ask.
    static var current: LocationNote? {
        switch CLLocationManager().authorizationStatus {
        case .denied: .denied
        case .restricted: .restricted
        default: nil
        }
    }
}

struct LocationNoteView: View {
    let note: LocationNote
    let dismiss: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "location.slash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
                .padding(.top, 12)
            VStack(alignment: .leading, spacing: 4) {
                Text(note == .denied ? .locationDenied : .locationRestricted)
                    .font(.footnote)
                    .padding(.top, 12)
                if note == .denied {
                    Button {
                        if let settings = URL(string: UIApplication.openSettingsURLString) { openURL(settings) }
                    } label: {
                        Text(.locationOpenSettings)
                            .font(.footnote.weight(.semibold))
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }
            .padding(.bottom, note == .denied ? 0 : 12)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(.locationDismiss))
        }
        .padding(.leading, 12)
        .background(.fill.tertiary, in: .rect(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    VStack {
        LocationNoteView(note: .denied) {}
        LocationNoteView(note: .restricted) {}
    }
}
