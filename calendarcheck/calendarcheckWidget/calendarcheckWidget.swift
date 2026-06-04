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
                    .font(Theme.display(.headline).weight(.semibold))
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

// MARK: - Full month (large)

struct LargeWidget: Widget {
    let kind = "calendarcheckLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckProvider()) { entry in
            LargeWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Full Month")
        .description("The whole month, with your total and streak.")
        .supportedFamilies([.systemLarge])
    }
}

struct LargeWidgetView: View {
    let entry: CheckEntry
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var calendar: Calendar { CheckPersistence.calendar() }
    private var today: DayKey { DayKey(date: entry.date, calendar: calendar) }
    private var grid: MonthGrid { MonthGrid(year: today.year, month: today.month, calendar: calendar) }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var fillColor: Color { renderingMode == .fullColor ? CheckPersistence.accentColor() : .primary }

    /// Flat, uniquely-identified cells (weekday headers + blanks + days) so the
    /// integer ids can't collide inside the LazyVGrid and drop early days.
    private enum Cell: Identifiable {
        case weekday(Int, String)
        case blank(Int)
        case day(Int)
        var id: String {
            switch self {
            case .weekday(let i, _): return "wd-\(i)"
            case .blank(let i):      return "blank-\(i)"
            case .day(let d):        return "day-\(d)"
            }
        }
    }

    private var cells: [Cell] {
        var result: [Cell] = grid.weekdaySymbols.enumerated().map { .weekday($0.offset, $0.element) }
        result += (0..<grid.leadingBlanks).map { .blank($0) }
        result += grid.days.map { .day($0) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title)
                        .font(Theme.display(.title3).weight(.semibold))
                        .lineLimit(1)
                    Text("\(grid.name(calendar: calendar)) \(String(today.year))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(entry.days.count)")
                        .font(.system(size: 30, weight: .bold))
                        .monospacedDigit()
                    Text("total days")
                        .font(.caption2)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }

            Rectangle().fill(.primary.opacity(0.15)).frame(height: 1)

            Spacer(minLength: 0)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(cells) { cell in
                    switch cell {
                    case .weekday(_, let symbol):
                        Text(symbol)
                            .font(.caption2)
                            .textCase(.uppercase)
                            .foregroundStyle(.tertiary)
                    case .blank:
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    case .day(let dayNumber):
                        let key = DayKey(year: today.year, month: today.month, day: dayNumber)
                        let passed = entry.days.contains(key)
                        let isToday = key == today
                        ZStack {
                            if passed {
                                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fillColor)
                            } else if isToday {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(.primary.opacity(0.5), lineWidth: 1)
                            }
                            Text("\(dayNumber)")
                                .font(.system(size: 13, weight: passed ? .semibold : .regular))
                                .monospacedDigit()
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(passed ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text("\(entry.streak) day streak")
                Spacer()
                Text("\(entry.monthCount) this month")
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Milestones (medium)

struct MilestoneWidget: Widget {
    let kind = "calendarcheckMilestoneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckProvider()) { entry in
            MilestoneWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Milestones")
        .description("The streak badges you've earned.")
        .supportedFamilies([.systemMedium])
    }
}

struct MilestoneWidgetView: View {
    let entry: CheckEntry
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var calendar: Calendar { CheckPersistence.calendar() }
    private var accent: Color { renderingMode == .fullColor ? CheckPersistence.accentColor() : .primary }

    private func label(_ m: Int) -> String {
        switch m {
        case 7: return "Week"
        case 30: return "Month"
        case 365: return "Year"
        default: return "\(m) days"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MILESTONES")
                .font(.caption2)
                .tracking(1.5)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(CheckLogic.milestones, id: \.self) { m in
                    let hits = CheckLogic.milestoneHits(m, passed: entry.days, calendar: calendar)
                    let earned = hits > 0
                    VStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            ZStack {
                                Circle()
                                    .fill(earned ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary))
                                    .frame(width: 50, height: 50)
                                Text("\(m)")
                                    .font(.system(size: 15, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(earned ? AnyShapeStyle(.background) : AnyShapeStyle(.secondary))
                            }
                            if hits > 0 {
                                Text("×\(hits)")
                                    .font(.system(size: 10, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.background)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(.primary))
                                    .offset(x: 6, y: -2)
                            }
                        }
                        Text(label(m))
                            .font(.caption2)
                            .foregroundStyle(earned ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Year heatmap (medium)

struct HeatmapWidget: Widget {
    let kind = "calendarcheckHeatmapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckProvider()) { entry in
            HeatmapWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Year Heatmap")
        .description("Every day this year at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct HeatmapWidgetView: View {
    let entry: CheckEntry
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var calendar: Calendar { CheckPersistence.calendar() }
    private var year: Int { calendar.component(.year, from: entry.date) }
    private var accent: Color { renderingMode == .fullColor ? CheckPersistence.accentColor() : .primary }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(year))
                    .font(Theme.display(.headline).weight(.semibold))
                    .monospacedDigit()
                Spacer()
                Text("\(CheckLogic.daysPassed(in: entry.days, year: year)) days")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 3) {
                ForEach(1...12, id: \.self) { month in
                    let last = CheckLogic.lastDay(ofYear: year, month: month, calendar: calendar)
                    HStack(spacing: 3) {
                        ForEach(1...31, id: \.self) { day in
                            if day <= last {
                                let passed = entry.days.contains(DayKey(year: year, month: month, day: day))
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(passed ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary))
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

#Preview("Full Month", as: .systemLarge) {
    LargeWidget()
} timeline: {
    CheckEntry(date: .now, days: [DayKey(date: .now)], title: "Meditate", icon: "", streak: 5, monthCount: 12, monthlyGoal: 20)
}

#Preview("Milestones", as: .systemMedium) {
    MilestoneWidget()
} timeline: {
    CheckEntry(date: .now, days: [DayKey(date: .now)], title: "Meditate", icon: "", streak: 5, monthCount: 12, monthlyGoal: 20)
}

#Preview("Heatmap", as: .systemMedium) {
    HeatmapWidget()
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
