import BegiaiKit
import SwiftUI

struct TrainPage: View {
    let timeline: TrainTimeline?
    let color: Color
    let now: Date
    @Binding var following: Bool
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: close) {
                    Label {
                        Text(.trainBack)
                    } icon: {
                        Image(systemName: "chevron.left")
                    }
                }
                .accessibilityIdentifier(A11yID.Train.back)
                Spacer()
                if timeline != nil {
                    Button {
                        following.toggle()
                    } label: {
                        Label {
                            Text(following ? .trainFollowing : .trainFollow)
                        } icon: {
                            Image(systemName: "location.fill")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(following ? color : .secondary)
                    .accessibilityIdentifier(A11yID.Train.follow)
                }
            }
            if let timeline {
                Text(.trainTitle(time: timeline.firstDeparture.vilniusTime, origin: timeline.origin, destination: timeline.destination))
                    .font(.headline)
                    .accessibilityIdentifier(A11yID.Train.title)
                if let standing = timeline.standingAt {
                    let stop = timeline.stops[standing]
                    HStack(spacing: 6) {
                        Text(.trainAt(station: stop.station, time: stop.departure.vilniusTime))
                        Text(.trainIn(minutes: stop.departure.minutes(after: now)))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                } else if let nextStop = timeline.nextStop {
                    let next = timeline.stops[nextStop]
                    HStack(spacing: 6) {
                        Text(.trainNext(station: next.station, time: next.arrival.vilniusTime))
                        Text(.trainIn(minutes: next.arrival.minutes(after: now)))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
                Text(.trainEstimated)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(.trainGone)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

struct StopList: View {
    let timeline: TrainTimeline
    let color: Color

    var body: some View {
        List(timeline.stops) { stop in
            HStack(spacing: 12) {
                StopMark(
                    color: color, passed: stop.passed, isNext: stop.id == (timeline.standingAt ?? timeline.nextStop),
                    progress: stop.id == timeline.nextStop ? timeline.progressToNext : nil)
                Text(verbatim: stop.station)
                    .foregroundStyle(stop.passed ? .secondary : .primary)
                Spacer()
                Text(verbatim: (stop.id == 0 ? stop.departure : stop.arrival).vilniusTime)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(A11yID.Train.stop)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct StopMark: View {
    let color: Color
    let passed: Bool
    let isNext: Bool
    let progress: Double?

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(passed ? color.opacity(0.35) : color)
                .frame(width: 4)
            Circle()
                .strokeBorder(color, lineWidth: 3)
                .background(Circle().fill(passed ? color : Color(.systemBackground)))
                .frame(width: 14, height: 14)
                .padding(.top, 15)
            if let progress, progress > 0 {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .offset(y: 17 - 22 * (1 - progress))
            }
        }
        .frame(width: 16, height: 44)
        .accessibilityHidden(true)
    }
}

#Preview {
    TrainPage(timeline: nil, color: .blue, now: .now, following: .constant(false)) {}
}
