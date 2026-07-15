//
//  UntilLiveActivity.swift
//  untilWidget
//
//  Lock Screen + Dynamic Island for an event's Live Activity. One clean primary
//  signal — a day count far out, hours in the final day, a ticking clock in the
//  final hour — plus a filling progress bar. All self-updating, no push.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct UntilLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UntilActivityAttributes.self) { context in
            LockScreenLiveView(context: context)
                .padding(16)
                .activityBackgroundTint(context.attributes.accent.color.opacity(0.14))
                .activitySystemActionForegroundColor(context.attributes.accent.color)
        } dynamicIsland: { context in
            let accent = context.attributes.accent.color
            let hero = Self.hero(context.state.targetDate)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 9) {
                        Image(systemName: context.attributes.symbol)
                            .font(.title3)
                            .symbolEffect(.pulse, options: .repeating)
                            .foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text("UNTIL").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        hero.value
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundStyle(accent)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(hero.label).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        DashedProgress(progress: Self.progress(context.state.startDate, context.state.targetDate),
                                       color: accent)
                        Text(context.state.targetDate, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .widgetURL(deepLink(context))
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbol)
                    .symbolEffect(.pulse, options: .repeating)
                    .foregroundStyle(accent)
            } compactTrailing: {
                Self.compact(context.state.targetDate)
                    .font(.callout.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(accent).frame(maxWidth: 68)
            } minimal: {
                Image(systemName: context.attributes.symbol).foregroundStyle(accent)
            }
            .widgetURL(deepLink(context))
        }
    }

    private func deepLink(_ context: ActivityViewContext<UntilActivityAttributes>) -> URL? {
        URL(string: "until://event/\(context.attributes.eventID.uuidString)")
    }

    /// Primary signal: a plain day/hour number far out, a ticking MM:SS in the last
    /// hour. Returns a Text so the ticking case can auto-update.
    static func hero(_ target: Date) -> (value: Text, label: String) {
        let rem = target.timeIntervalSinceNow
        if rem > 0, rem < 3600 {
            return (Text(timerInterval: Date()...target, countsDown: true), "left")
        }
        if rem > 0, rem < 86_400 {
            let h = Int(ceil(rem / 3600))
            return (Text("\(h)"), h == 1 ? "hour left" : "hours left")
        }
        let d = max(0, Int(ceil(rem / 86_400)))
        return (Text("\(d)"), d == 1 ? "day left" : "days left")
    }

    /// Compact form: "15d", "6h", or a ticking clock in the final hour.
    static func compact(_ target: Date) -> Text {
        let rem = target.timeIntervalSinceNow
        if rem > 0, rem < 3600 { return Text(timerInterval: Date()...target, countsDown: true) }
        if rem > 0, rem < 86_400 { return Text("\(Int(ceil(rem / 3600)))h") }
        return Text("\(max(0, Int(ceil(rem / 86_400))))d")
    }

    /// Elapsed fraction of the countdown, evaluated at render time (0…1).
    static func progress(_ start: Date, _ target: Date, now: Date = Date()) -> Double {
        let total = target.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }
}

/// A dashed progress track: faint dashes for the whole span, accent dashes filled
/// up to `progress`.
struct DashedProgress: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let style = StrokeStyle(lineWidth: height, lineCap: .round, dash: [3, 6])
            ZStack(alignment: .leading) {
                line(width: w).stroke(color.opacity(0.25), style: style)
                line(width: w).stroke(color, style: style)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: max(0, w * progress))
                    }
            }
        }
        .frame(height: height)
    }

    private func line(width: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: height / 2))
            p.addLine(to: CGPoint(x: width, y: height / 2))
        }
    }
}

private struct LockScreenLiveView: View {
    let context: ActivityViewContext<UntilActivityAttributes>

    var body: some View {
        let accent = context.attributes.accent.color
        let hero = UntilLiveActivity.hero(context.state.targetDate)

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: context.attributes.symbol)
                    .font(.title2)
                    .symbolEffect(.pulse, options: .repeating)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title).font(.headline).lineLimit(1)
                    Text(context.state.targetDate, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    hero.value
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit().foregroundStyle(accent)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(hero.label).font(.caption2).foregroundStyle(.secondary)
                }
            }
            DashedProgress(progress: UntilLiveActivity.progress(context.state.startDate, context.state.targetDate),
                           color: accent)
        }
        .widgetURL(URL(string: "until://event/\(context.attributes.eventID.uuidString)"))
    }
}
