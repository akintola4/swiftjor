//
//  calendarcheckWidget.swift
//  calendarcheckWidget
//
//  Two widgets, both reading the shared App Group store directly (no observation).
//  The system applies Liquid Glass to the widget container — we don't call
//  glassEffect here; we just keep content legible, including in accented/tinted mode.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Interactive toggle

struct ToggleTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle today's check"

    func perform() async throws -> some IntentResult {
        let cal = CheckPersistence.calendar()
        var days = CheckPersistence.loadDays()
        let today = DayKey(date: Date(), calendar: cal)
        if days.contains(today) { days.remove(today) } else { days.insert(today) }
        CheckPersistence.saveDays(days)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline

struct CheckEntry: TimelineEntry {
    let date: Date
    let days: Set<DayKey>
    let title: String
    let icon: String
    let streak: Int
    let monthCount: Int
    let monthlyGoal: Int
}

struct CheckProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckEntry {
        CheckEntry(date: Date(), days: [], title: CheckPersistence.defaultTitle, icon: "", streak: 0, monthCount: 0, monthlyGoal: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckEntry>) -> Void) {
        let cal = Calendar.current
        let refresh = cal.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [makeEntry()], policy: .after(refresh)))
    }

    private func makeEntry() -> CheckEntry {
        let cal = CheckPersistence.calendar()
        let days = CheckPersistence.loadDays()
        let c = cal.dateComponents([.year, .month], from: Date())
        let monthCount = CheckLogic.daysPassed(in: days, year: c.year ?? 0, month: c.month ?? 0)
        return CheckEntry(
            date: Date(),
            days: days,
            title: CheckPersistence.loadTitle(),
            icon: CheckPersistence.loadIcon(),
            streak: CheckLogic.currentStreak(passed: days, calendar: cal),
            monthCount: monthCount,
            monthlyGoal: CheckPersistence.loadMonthlyGoal()
        )
    }
}

// MARK: - Mini month calendar (medium)

struct MonthWidget: Widget {
    let kind = "calendarcheckMonthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckProvider()) { entry in
            MonthWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Month")
        .description("Your passed days this month at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct MonthWidgetView: View {
    let entry: CheckEntry
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var calendar: Calendar { CheckPersistence.calendar() }
    private var today: DayKey { DayKey(date: entry.date, calendar: calendar) }
    private var grid: MonthGrid { MonthGrid(year: today.year, month: today.month, calendar: calendar) }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    private var fillColor: Color { renderingMode == .fullColor ? CheckPersistence.accentColor() : .primary }

    /// Flat, uniquely-identified cells so the leading blanks and day numbers can't
    /// collide on integer ids inside the LazyVGrid (which would drop the early days).
    private enum Cell: Identifiable {
        case blank(Int)
        case day(Int)
        var id: String {
            switch self {
            case .blank(let i): return "blank-\(i)"
            case .day(let d):   return "day-\(d)"
            }
        }
    }

    private var cells: [Cell] {
        (0..<grid.leadingBlanks).map { Cell.blank($0) } + grid.days.map { Cell.day($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(grid.name(calendar: calendar))
                    .font(Theme.serif(.headline).weight(.semibold))
                Spacer()
                Text("\(entry.monthCount)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(cells) { cell in
                    switch cell {
                    case .blank:
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    case .day(let dayNumber):
                        let key = DayKey(year: today.year, month: today.month, day: dayNumber)
                        let passed = entry.days.contains(key)
                        let isToday = key == today
                        ZStack {
                            if passed {
                                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(fillColor)
                            } else if isToday {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(.primary.opacity(0.5), lineWidth: 1)
                            }
                            Text("\(dayNumber)")
                                .font(.system(size: 11, weight: passed ? .semibold : .regular))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(passed ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}

// MARK: - Streak + count (small)

struct StreakWidget: Widget {
    let kind = "calendarcheckStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Total")
        .description("Your total days and a tap-to-check button.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakWidgetView: View {
    let entry: CheckEntry
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var todayPassed: Bool { entry.days.contains(DayKey(date: entry.date)) }
    private var dotColor: Color { renderingMode == .fullColor ? CheckPersistence.accentColor() : .primary }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(entry.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(intent: ToggleTodayIntent()) {
                    Image(systemName: todayPassed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(todayPassed ? AnyShapeStyle(dotColor) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Text("\(entry.days.count)")
                .font(.system(size: 56, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
            Text("total days")
                .font(.caption2)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Text("\(entry.monthCount) this month")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lock Screen (accessory families)

/// Lives on the Lock Screen and in StandBy. The system renders these in a vibrant,
/// largely monochrome mode, so we lean on shape and the day number rather than the
/// accent hue (which is desaturated here anyway). Tapping checks today via the
/// shared intent.
struct LockWidget: Widget {
    let kind = "calendarcheckLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckProvider()) { entry in
            LockWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Lock Screen")
        .description("A check-today control for your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockWidgetView: View {
    let entry: CheckEntry
    @Environment(\.widgetFamily) private var family

    private var todayPassed: Bool { entry.days.contains(DayKey(date: entry.date)) }

    /// Denominator for the ring: the monthly goal if set, otherwise the days in
    /// the current month.
    private var goalTotal: Int {
        if entry.monthlyGoal > 0 { return entry.monthlyGoal }
        let cal = CheckPersistence.calendar()
        let c = cal.dateComponents([.year, .month], from: entry.date)
        return CheckLogic.lastDay(ofYear: c.year ?? 0, month: c.month ?? 0, calendar: cal)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(min(entry.monthCount, goalTotal)), in: 0...Double(max(goalTotal, 1))) {
                Image(systemName: "checkmark")
            } currentValueLabel: {
                Text("\(entry.monthCount)").monospacedDigit()
            }
            .gaugeStyle(.accessoryCircular)

        case .accessoryInline:
            // Inline sits next to the clock: icon + count only.
            Label("\(entry.monthCount) this month", systemImage: todayPassed ? "checkmark.circle.fill" : "circle")

        case .accessoryRectangular:
            // Narrow family: lean on the three available lines, keep the toggle small.
            HStack(spacing: 6) {
                Button(intent: ToggleTodayIntent()) {
                    Image(systemName: todayPassed ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(entry.streak) day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(entry.monthCount) this month")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        default:
            Text("\(entry.monthCount)").monospacedDigit()
        }
    }
}

// MARK: - Previews

#Preview("Month", as: .systemMedium) {
    MonthWidget()
} timeline: {
    CheckEntry(date: .now, days: [], title: "Meditate", icon: "", streak: 0, monthCount: 0, monthlyGoal: 0)
}

#Preview("Streak", as: .systemSmall) {
    StreakWidget()
} timeline: {
    CheckEntry(date: .now, days: [DayKey(date: .now)], title: "Meditate", icon: "", streak: 5, monthCount: 12, monthlyGoal: 20)
}

#Preview("Lock circular", as: .accessoryCircular) {
    LockWidget()
} timeline: {
    CheckEntry(date: .now, days: [DayKey(date: .now)], title: "Meditate", icon: "", streak: 5, monthCount: 12, monthlyGoal: 20)
}

#Preview("Lock rectangular", as: .accessoryRectangular) {
    LockWidget()
} timeline: {
    CheckEntry(date: .now, days: [DayKey(date: .now)], title: "Meditate", icon: "", streak: 5, monthCount: 12, monthlyGoal: 20)
}
