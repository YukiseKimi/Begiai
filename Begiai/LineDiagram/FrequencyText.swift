import BegiaiKit
import SwiftUI

/// “Every 30–60 min at rush hour · every 2 h midday”.
struct FrequencyText: View {
    let frequency: LineFrequency

    var body: some View {
        Text(.frequencyLine(rush: rush, midday: midday))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(A11yID.LineDiagram.frequency)
    }

    private var rush: String {
        switch frequency.rush {
        case .noTrain: String(localized: .frequencyRushNone)
        case .one: String(localized: .frequencyRushOne)
        case .trains(let count): String(localized: .frequencyRushTrains(count: count))
        case .every(let gaps): String(localized: .frequencyRushEvery(gap: Self.text(of: gaps)))
        }
    }

    private var midday: String {
        switch frequency.midday {
        case .noTrain: String(localized: .frequencyMiddayNone)
        case .one: String(localized: .frequencyMiddayOne)
        case .trains(let count): String(localized: .frequencyMiddayTrains(count: count))
        case .every(let gaps): String(localized: .frequencyMiddayEvery(gap: Self.text(of: gaps)))
        }
    }

    /// Whole hours from 2 h up; minutes below that.
    static func text(of gaps: ClosedRange<Int>) -> String {
        let hours = gaps.lowerBound >= 120 && gaps.lowerBound % 60 == 0 && gaps.upperBound % 60 == 0
        switch (hours, gaps.lowerBound == gaps.upperBound) {
        case (true, true): return String(localized: .frequencyGapHours(hours: gaps.lowerBound / 60))
        case (true, false): return String(localized: .frequencyGapHourRange(low: gaps.lowerBound / 60, high: gaps.upperBound / 60))
        case (false, true): return String(localized: .frequencyGapMinutes(minutes: gaps.lowerBound))
        case (false, false): return String(localized: .frequencyGapMinuteRange(low: gaps.lowerBound, high: gaps.upperBound))
        }
    }
}

#Preview {
    FrequencyText(frequency: LineFrequency(rush: .every(30...60), midday: .every(120...120)))
}
