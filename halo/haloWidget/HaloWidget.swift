//
//  HaloWidget.swift
//  haloWidget
//
//  One AppIntent-configurable widget with two faces. The Moon face is global (no
//  location); the Sun face reads the app's cached coordinate — available on paid
//  (App Group) builds, else it falls back to a default with a hint. The system
//  applies Liquid Glass to the chrome.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline

struct HaloEntry: TimelineEntry {
    let date: Date
    let face: WidgetFace
    let place: LocationSnapshot
    let hasLocation: Bool          // false → Sun face shows an "open app" hint
}

struct HaloProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HaloEntry {
        HaloEntry(date: Date(), face: .moon, place: LocationCache.fallback, hasLocation: false)
    }

    func snapshot(for configuration: SelectFaceIntent, in context: Context) async -> HaloEntry {
        entry(face: configuration.face, at: Date())
    }

    func timeline(for configuration: SelectFaceIntent, in context: Context) async -> Timeline<HaloEntry> {
        let now = Date()
        let face = configuration.face
        // A few entries across the next hour keep countdown text smooth, then reload
        // just after midnight for the day/moon rollover.
        let entries = stride(from: 0, through: 45, by: 15).map { entry(face: face, at: now.addingTimeInterval(Double($0) * 60)) }
        let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime)
        return Timeline(entries: entries, policy: .after(midnight ?? now.addingTimeInterval(3600)))
    }

    private func entry(face: WidgetFace, at date: Date) -> HaloEntry {
        let cached = LocationCache.load()
        return HaloEntry(date: date, face: face, place: cached ?? LocationCache.fallback, hasLocation: cached != nil)
    }
}

// MARK: - Widget

struct HaloWidget: Widget {
    let kind = "HaloWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectFaceIntent.self, provider: HaloProvider()) { entry in
            HaloWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sun & Moon")
        .description("Daylight remaining, or tonight's moon. Long-press to switch faces.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct HaloWidgetEntryView: View {
    var entry: HaloEntry
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
            .widgetURL(entry.face.url)
    }

    @ViewBuilder private var content: some View {
        switch entry.face {
        case .sun:  SunFace(entry: entry, family: family)
        case .moon: MoonFace(date: entry.date, family: family)
        }
    }
}

// MARK: - Sun face

private struct SunFace: View {
    let entry: HaloEntry
    let family: WidgetFamily

    private var daylight: Solar.Daylight {
        Solar.daylight(at: entry.date, latitude: entry.place.latitude, longitude: entry.place.longitude)
    }
    private var times: Solar.Times {
        Solar.times(on: entry.date, latitude: entry.place.latitude, longitude: entry.place.longitude)
    }

    var body: some View {
        let d = daylight
        switch family {
        case .accessoryInline:
            Label(inlineText(d), systemImage: "sun.max.fill")
        case .accessoryCircular:
            Gauge(value: d.progress) { Image(systemName: "sun.max.fill") }
                .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(entry.place.name, systemImage: "location.fill").font(.headline).lineLimit(1)
                Text(rectText(d)).font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 14) {
                bigReadout(d)
                VStack(alignment: .leading, spacing: 6) {
                    timeLine("sunrise", times.sunrise)
                    timeLine("sun.max", times.solarNoon)
                    timeLine("sunset", times.sunset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                bigReadout(d)
                Spacer(minLength: 0)
                if let ss = times.sunset {
                    Label(ss.formatted(date: .omitted, time: .shortened), systemImage: "sunset")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if !entry.hasLocation {
                    Text("Open app to set location").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func bigReadout(_ d: Solar.Daylight) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(bigValue(d))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.sun).minimumScaleFactor(0.5).lineLimit(1)
            Text(bigLabel(d)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private func timeLine(_ symbol: String, _ date: Date?) -> some View {
        Label(date.map { $0.formatted(date: .omitted, time: .shortened) } ?? "—", systemImage: symbol)
            .font(.caption).foregroundStyle(.secondary)
    }

    private func bigValue(_ d: Solar.Daylight) -> String {
        switch d.phase {
        case .polarDay: return "24h"
        case .polarNight: return "0h"
        default: return Theme.duration(d.remaining)
        }
    }
    private func bigLabel(_ d: Solar.Daylight) -> String {
        switch d.phase {
        case .daytime: return "daylight left"
        case .beforeDawn, .afterDusk: return "until sunrise"
        case .polarDay: return "midnight sun"
        case .polarNight: return "polar night"
        }
    }
    private func inlineText(_ d: Solar.Daylight) -> String {
        d.phase == .daytime ? "\(Theme.duration(d.remaining)) light" : "Sunrise \(Theme.duration(d.remaining))"
    }
    private func rectText(_ d: Solar.Daylight) -> String {
        "\(bigValue(d)) \(bigLabel(d))"
    }
}

// MARK: - Moon face

private struct MoonFace: View {
    let date: Date
    let family: WidgetFamily

    private var illum: Int { Int((Lunar.illumination(date) * 100).rounded()) }
    private var fullInDays: Int { Theme.daysAway(to: Lunar.nextFullMoon(after: date), now: date) }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("\(illum)%", systemImage: Lunar.symbolName(date))
        case .accessoryCircular:
            Gauge(value: Lunar.illumination(date)) { Image(systemName: Lunar.symbolName(date)) }
                .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(Lunar.phaseName(date), systemImage: Lunar.symbolName(date)).font(.headline).lineLimit(1)
                Text("\(illum)% · Full in \(fullInDays)d").font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 16) {
                MoonDisc(illumination: Lunar.illumination(date), waxing: Lunar.isWaxing(date))
                    .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Lunar.phaseName(date)).font(.headline)
                    Text("\(illum)% illuminated").font(.subheadline).foregroundStyle(.secondary)
                    Text("Full moon in \(fullInDays) day\(fullInDays == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            VStack(spacing: 6) {
                MoonDisc(illumination: Lunar.illumination(date), waxing: Lunar.isWaxing(date))
                    .frame(width: 74, height: 74)
                Text("\(illum)% · \(Lunar.phaseName(date))")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
