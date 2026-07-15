//
//  UntilWidget.swift
//  untilWidget
//
//  One configurable widget across Home Screen + Lock Screen families. Long-press
//  to pick which event it shows (AppIntentConfiguration). Reads the shared App
//  Group store directly; the system applies Liquid Glass to the chrome.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline

struct EventEntry: TimelineEntry {
    let date: Date
    let event: UntilEvent?
}

struct UntilProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> EventEntry {
        EventEntry(date: Date(), event: EventStore.loadEvents().first ?? UntilProvider.sample)
    }

    func snapshot(for configuration: SelectEventIntent, in context: Context) async -> EventEntry {
        EventEntry(date: Date(), event: resolve(configuration))
    }

    func timeline(for configuration: SelectEventIntent, in context: Context) async -> Timeline<EventEntry> {
        let now = Date()
        let event = resolve(configuration)
        return Timeline(entries: [EventEntry(date: now, event: event)],
                        policy: .after(nextRefresh(for: event, after: now)))
    }

    private func resolve(_ configuration: SelectEventIntent) -> UntilEvent? {
        if let id = configuration.event?.id, let match = EventStore.event(id: id) { return match }
        // Free-signing fallback: with no App Group the widget can't see the app's
        // events, so show the sample event instead of an empty (perpetually loading)
        // state. Harmless on paid builds — it only appears when there are no events.
        return EventStore.defaultEvent() ?? UntilProvider.sample
    }

    /// Near, time-precise events refresh every 15 minutes; everything else just
    /// after midnight when the day count rolls over.
    private func nextRefresh(for event: UntilEvent?, after now: Date) -> Date {
        if let event, event.includeTime, abs(event.date.timeIntervalSince(now)) < 86_400 {
            return now.addingTimeInterval(900)
        }
        return Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime)
            ?? now.addingTimeInterval(3_600)
    }

    static let sample = UntilEvent(title: "New Year", symbol: "sparkles", accent: .cobalt, mode: .until,
                                   date: Date().addingTimeInterval(86_400 * 42))
}

// MARK: - Widget

struct UntilWidget: Widget {
    let kind = "UntilWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectEventIntent.self, provider: UntilProvider()) { entry in
            UntilWidgetEntryView(entry: entry)
                .widgetURL(entry.event.flatMap { URL(string: "until://event/\($0.id.uuidString)") })
        }
        .configurationDisplayName("Countdown")
        .description("Count down to a date — or up from one. Long-press to pick the event.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct UntilWidgetEntryView: View {
    var entry: EventEntry
    @Environment(\.widgetFamily) private var family

    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
        default: return false
        }
    }

    var body: some View {
        content
            .containerBackground(isAccessory ? AnyShapeStyle(.clear) : AnyShapeStyle(.background), for: .widget)
    }

    @ViewBuilder private var content: some View {
        if let event = entry.event {
            switch family {
            case .systemMedium:        MediumView(event: event, now: entry.date)
            case .accessoryCircular:   CircularView(event: event, now: entry.date)
            case .accessoryRectangular: RectangularView(event: event, now: entry.date)
            case .accessoryInline:     InlineView(event: event, now: entry.date)
            default:                   SmallView(event: event, now: entry.date)
            }
        } else {
            EmptyWidgetView()
        }
    }
}

// MARK: - Home Screen families

private struct SmallView: View {
    let event: UntilEvent
    let now: Date

    var body: some View {
        let r = CountLogic.readout(for: event, now: now)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: event.symbol).font(.caption).foregroundStyle(event.accent.color)
                Text(event.title).font(.caption.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text(r.big)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(event.accent.color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(r.unit.isEmpty ? r.detail : r.unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumView: View {
    let event: UntilEvent
    let now: Date

    var body: some View {
        let r = CountLogic.readout(for: event, now: now)
        let p = CountLogic.progress(for: event, now: now)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: event.symbol).foregroundStyle(event.accent.color)
                Text(event.title).font(.headline).lineLimit(1)
                Spacer()
                Text(event.displayBadge)
                    .font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(r.big)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(event.accent.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 1) {
                    if !r.unit.isEmpty { Text(r.unit).font(.subheadline) }
                    Text(r.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            ProgressView(value: p).tint(event.accent.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Lock Screen families

private struct CircularView: View {
    let event: UntilEvent
    let now: Date

    var body: some View {
        let r = CountLogic.readout(for: event, now: now)
        Gauge(value: CountLogic.progress(for: event, now: now)) {
            Image(systemName: event.symbol)
        } currentValueLabel: {
            Text(r.big).monospacedDigit().minimumScaleFactor(0.4)
        }
        .gaugeStyle(.accessoryCircular)
    }
}

private struct RectangularView: View {
    let event: UntilEvent
    let now: Date

    var body: some View {
        let r = CountLogic.readout(for: event, now: now)
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Label(event.title, systemImage: event.symbol)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(r.big).font(.body.weight(.semibold)).monospacedDigit()
                    Text(r.unit.isEmpty ? r.detail : r.unit)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if event.mode == .since {
                Button(intent: ResetSinceIntent(eventID: event.id)) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InlineView: View {
    let event: UntilEvent
    let now: Date

    var body: some View {
        let r = CountLogic.readout(for: event, now: now)
        Label("\(r.big) \(r.unit.isEmpty ? r.detail : r.unit)", systemImage: event.symbol)
    }
}

// MARK: - Empty

private struct EmptyWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("No event", systemImage: "hourglass")
        case .accessoryCircular:
            Image(systemName: "hourglass")
        default:
            VStack(spacing: 4) {
                Image(systemName: "hourglass").font(.title2).foregroundStyle(.secondary)
                Text("Add an event").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
