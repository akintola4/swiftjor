//
//  HaloLiveActivity.swift
//  haloWidget
//
//  Halo's own Live Activity language — not a countdown bar. The Sun rides its daily
//  arc from sunrise to sunset; the Moon shows its true rendered disc above a lunar
//  phase track (ticks at new / quarter / full). Self-updating, no push.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct HaloLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HaloActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(context.attributes.face.tint.opacity(0.12))
                .activitySystemActionForegroundColor(context.attributes.face.tint)
        } dynamicIsland: { context in
            let tint = context.attributes.face.tint
            let isMoon = context.attributes.face == .moon

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        heroGlyph(context, size: isMoon ? 26 : 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.headline).font(.subheadline.weight(.semibold))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text(subtitle(context)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let hero = Self.hero(context)
                    VStack(alignment: .trailing, spacing: 0) {
                        hero.value
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundStyle(tint)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(hero.label).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Group {
                        if isMoon {
                            MoonPhaseTrack(phaseFraction: context.state.phaseFraction, tint: tint, labeled: true)
                                .frame(height: 40)
                        } else {
                            SunArc(progress: context.state.progress(), tint: tint,
                                   startLabel: sunriseLabel(context),
                                   endLabel: context.state.target.formatted(date: .omitted, time: .shortened))
                                .frame(height: 62)
                        }
                    }
                    .widgetURL(context.attributes.face.url)
                }
            } compactLeading: {
                heroGlyph(context, size: 20)
            } compactTrailing: {
                Self.compact(context).font(.callout.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(tint).frame(maxWidth: 62)
            } minimal: {
                heroGlyph(context, size: 20)
            }
            .widgetURL(context.attributes.face.url)
        }
    }

    // MARK: Shared pieces

    /// Moon → its true disc; Sun → a soft glowing orb.
    @ViewBuilder private func heroGlyph(_ context: ActivityViewContext<HaloActivityAttributes>, size: CGFloat) -> some View {
        if context.attributes.face == .moon {
            MoonDisc(illumination: context.state.illumination, waxing: context.state.waxing)
                .frame(width: size, height: size)
        } else {
            Circle()
                .fill(RadialGradient(colors: [Theme.sun, Theme.sun.opacity(0.7)], center: .center,
                                     startRadius: 0, endRadius: size))
                .frame(width: size, height: size)
                .shadow(color: Theme.sun.opacity(0.8), radius: size * 0.35)
        }
    }

    private func subtitle(_ context: ActivityViewContext<HaloActivityAttributes>) -> String {
        if context.attributes.face == .moon { return "\(Int((context.state.illumination * 100).rounded()))% lit" }
        return context.attributes.place.isEmpty ? "today" : context.attributes.place
    }

    private func sunriseLabel(_ context: ActivityViewContext<HaloActivityAttributes>) -> String {
        context.state.start.formatted(date: .omitted, time: .shortened)
    }

    static func hero(_ context: ActivityViewContext<HaloActivityAttributes>) -> (value: Text, label: String) {
        if context.attributes.face == .moon {
            let d = Theme.daysAway(to: context.state.target)
            return (Text("\(d)"), d == 1 ? "day to full" : "days to full")
        }
        return (Text(timerInterval: Date()...context.state.target, countsDown: true), context.state.headline.lowercased())
    }

    static func compact(_ context: ActivityViewContext<HaloActivityAttributes>) -> Text {
        if context.attributes.face == .moon {
            return Text("\(Theme.daysAway(to: context.state.target))d")
        }
        return Text(timerInterval: Date()...context.state.target, countsDown: true)
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let context: ActivityViewContext<HaloActivityAttributes>

    var body: some View {
        if context.attributes.face == .moon { moon } else { sun }
    }

    private var sun: some View {
        let tint = Theme.sun
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(context.state.headline).font(.headline)
                    Text(context.attributes.place.isEmpty ? "Today" : context.attributes.place)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(timerInterval: Date()...context.state.target, countsDown: true)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.6).frame(maxWidth: 130, alignment: .trailing)
            }
            SunArc(progress: context.state.progress(), tint: tint,
                   startLabel: context.state.start.formatted(date: .omitted, time: .shortened),
                   endLabel: context.state.target.formatted(date: .omitted, time: .shortened))
                .frame(height: 66)
        }
        .widgetURL(context.attributes.face.url)
    }

    private var moon: some View {
        let tint = Theme.moon
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                MoonDisc(illumination: context.state.illumination, waxing: context.state.waxing)
                    .frame(width: 50, height: 50)
                    .shadow(color: tint.opacity(0.4), radius: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.headline).font(.headline)
                    Text("\(Int((context.state.illumination * 100).rounded()))% lit · \(context.state.caption)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Theme.daysAway(to: context.state.target))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit().foregroundStyle(tint)
                    Text("days to full").font(.caption2).foregroundStyle(.secondary)
                }
            }
            MoonPhaseTrack(phaseFraction: context.state.phaseFraction, tint: tint, labeled: true)
                .frame(height: 36)
        }
        .widgetURL(context.attributes.face.url)
    }
}
