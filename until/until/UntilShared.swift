//
//  UntilShared.swift
//  until
//
//  Shared between the app AND the widget extension.
//  IMPORTANT: Target Membership must be checked for BOTH `until` and
//     `untilWidgetExtension`, or the widget build will fail with
//     "Cannot find type ... in scope".
//
//  Everything here is observation-free and side-effect-free so the widget's
//  timeline provider can read it directly without an @Observable store.
//

import SwiftUI
import ActivityKit

// MARK: - Live Activity

/// Shared between the app (which starts/stops activities) and the widget extension
/// (which renders the Lock Screen + Dynamic Island). Countdown ticks via
/// `Text(timerInterval:)`, so no push updates are needed — works on free signing.
struct UntilActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date      // countdown origin — anchors the filling progress bar
        var targetDate: Date
        var mode: EventMode
    }
    var eventID: UUID
    var title: String
    var symbol: String
    var accent: AccentChoice
}

// MARK: - Model

/// Count *down* to a future date, or *up* from a past one.
enum EventMode: String, Codable, CaseIterable, Identifiable {
    case until   // countdown to a target date
    case since   // count up from an anchor (resettable)

    var id: String { rawValue }
    var label: String { self == .until ? "Until" : "Since" }
}

/// How a countdown target repeats. Only meaningful for `.until` events — a
/// recurring event's target is *computed* (the next occurrence), so it rolls
/// forward on its own. `Codable`/`Hashable` are auto-synthesized for the cases.
enum RecurrenceRule: Codable, Hashable {
    case none
    case monthlyDay(day: Int)               // 1…31, clamped to month length (31 → Feb 28/29)
    case everyNWeeks(n: Int, anchor: Date)  // n = 2 for biweekly; anchor = a reference occurrence
    case lastWeekdayOfMonth(weekday: Int)   // Calendar weekday 1=Sun … 7=Sat (last Friday = 6)

    var isRecurring: Bool {
        if case .none = self { return false }
        return true
    }

    /// True when `date`'s calendar day is itself an occurrence of this rule.
    func isOccurrence(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        switch self {
        case .none:
            return false
        case .monthlyDay(let d):
            let c = calendar.dateComponents([.year, .month, .day], from: day)
            guard let y = c.year, let m = c.month, let dd = c.day else { return false }
            let target = min(max(1, min(d, 31)), Self.daysInMonth(year: y, month: m, calendar: calendar))
            return dd == target
        case .lastWeekdayOfMonth(let wd):
            let c = calendar.dateComponents([.year, .month], from: day)
            guard let y = c.year, let m = c.month,
                  let last = Self.lastWeekday(wd, year: y, month: m, calendar: calendar) else { return false }
            return calendar.isDate(last, inSameDayAs: day)
        case .everyNWeeks(let n, let anchor):
            let a = calendar.startOfDay(for: anchor)
            guard let diff = calendar.dateComponents([.day], from: a, to: day).day else { return false }
            let period = max(1, n) * 7
            return diff >= 0 && diff % period == 0
        }
    }

    /// The soonest occurrence on or after `now` (day-granular). Nil for `.none`.
    func nextOccurrence(onOrAfter now: Date, calendar: Calendar = .current) -> Date? {
        guard isRecurring else { return nil }
        var d = calendar.startOfDay(for: now)
        for _ in 0..<800 {                              // ~2 years; every rule hits within ~31 days
            if isOccurrence(on: d, calendar: calendar) { return d }
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { return nil }
            d = next
        }
        return nil
    }

    /// The most recent occurrence strictly before `ref` — used for the progress ring.
    func previousOccurrence(before ref: Date, calendar: Calendar = .current) -> Date? {
        guard isRecurring else { return nil }
        guard var d = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: ref)) else { return nil }
        for _ in 0..<800 {
            if isOccurrence(on: d, calendar: calendar) { return d }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: d) else { return nil }
            d = prev
        }
        return nil
    }

    private static func daysInMonth(year: Int, month: Int, calendar: Calendar) -> Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 28 }
        return range.count
    }

    private static func lastWeekday(_ weekday: Int, year: Int, month: Int, calendar: Calendar) -> Date? {
        let last = daysInMonth(year: year, month: month, calendar: calendar)
        for day in stride(from: last, through: 1, by: -1) {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
               calendar.component(.weekday, from: date) == weekday {
                return date
            }
        }
        return nil
    }

    /// "MON", "FRI" … from a Calendar weekday (1=Sun … 7=Sat).
    static func shortWeekday(_ weekday: Int) -> String {
        let names = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return names[((weekday - 1) % 7 + 7) % 7]
    }
}

/// One tracked moment. For `.until`, `date` is the target. For `.since`, `date`
/// is the current anchor (the last reset), and `recordSeconds` is the longest run.
struct UntilEvent: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var symbol: String           // SF Symbol name
    var accent: AccentChoice
    var mode: EventMode
    var date: Date
    var includeTime: Bool        // show hours/minutes precision when close
    var recordSeconds: Double    // since: longest run achieved (0 if none)
    var sortOrder: Int
    var createdAt: Date
    var recurrence: RecurrenceRule  // .none for a one-shot event; otherwise auto-rolls
    var reminder: Bool           // fire a local notification on the (recurring) occurrence
    var notes: String            // free-text note shown on the detail page
    var startDate: Date?         // when the countdown "begins" (progress origin); nil → createdAt
    var milestoneAlerts: Bool    // notify at 100/30/7/1 days out, etc.
    var category: String         // free-text tag for grouping/filtering ("" = none)
    var filled: Bool             // render the card as a filled accent cover

    init(
        id: UUID = UUID(),
        title: String,
        symbol: String = "calendar",
        accent: AccentChoice = .vermilion,
        mode: EventMode = .until,
        date: Date,
        includeTime: Bool = false,
        recordSeconds: Double = 0,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        recurrence: RecurrenceRule = .none,
        reminder: Bool = false,
        notes: String = "",
        startDate: Date? = nil,
        milestoneAlerts: Bool = false,
        category: String = "",
        filled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.accent = accent
        self.mode = mode
        self.date = date
        self.includeTime = includeTime
        self.recordSeconds = recordSeconds
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.recurrence = recurrence
        self.reminder = reminder
        self.notes = notes
        self.startDate = startDate
        self.milestoneAlerts = milestoneAlerts
        self.category = category
        self.filled = filled
    }

    /// Where the countdown progress starts: an explicit start date, else creation.
    var progressOrigin: Date { startDate ?? createdAt }

    // Tolerant decoding: any key missing from older saved data falls back to its
    // default, so adding fields never wipes a user's events on update.
    enum CodingKeys: String, CodingKey {
        case id, title, symbol, accent, mode, date, includeTime, recordSeconds
        case sortOrder, createdAt, recurrence, reminder, notes, startDate
        case milestoneAlerts, category, filled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "calendar"
        accent = try c.decodeIfPresent(AccentChoice.self, forKey: .accent) ?? .vermilion
        mode = try c.decodeIfPresent(EventMode.self, forKey: .mode) ?? .until
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        includeTime = try c.decodeIfPresent(Bool.self, forKey: .includeTime) ?? false
        recordSeconds = try c.decodeIfPresent(Double.self, forKey: .recordSeconds) ?? 0
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        recurrence = try c.decodeIfPresent(RecurrenceRule.self, forKey: .recurrence) ?? .none
        reminder = try c.decodeIfPresent(Bool.self, forKey: .reminder) ?? false
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)
        milestoneAlerts = try c.decodeIfPresent(Bool.self, forKey: .milestoneAlerts) ?? false
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        filled = try c.decodeIfPresent(Bool.self, forKey: .filled) ?? false
    }

    /// A shareable one-liner, e.g. "170 days until New Year".
    func shareSummary(now: Date = Date()) -> String {
        let r = CountLogic.readout(for: self, now: now)
        let phrase = r.unit.isEmpty ? "\(title): \(r.big)" : "\(r.big) \(r.unit) \(title)"
        return phrase
    }

    /// The date this event actually counts to. For a recurring `.until` event that's
    /// the next occurrence (rolls forward); otherwise the stored `date`.
    func effectiveTarget(now: Date = Date(), calendar: Calendar = .current) -> Date {
        guard mode == .until, recurrence.isRecurring else { return date }
        return recurrence.nextOccurrence(onOrAfter: now, calendar: calendar) ?? date
    }

    var isRecurring: Bool { mode == .until && recurrence.isRecurring }

    /// The small uppercase badge on cards/widgets: the recurrence for repeating
    /// events, else the mode ("UNTIL" / "SINCE").
    var displayBadge: String {
        switch recurrence {
        case .none:
            return mode.label.uppercased()
        case .monthlyDay:
            return "MONTHLY"
        case .everyNWeeks(let n, _):
            switch n {
            case 1: return "WEEKLY"
            case 2: return "EVERY 2 WKS"
            default: return "EVERY \(n) WKS"
            }
        case .lastWeekdayOfMonth(let wd):
            return "LAST \(RecurrenceRule.shortWeekday(wd))"
        }
    }
}

// MARK: - Persistence (App Group)

/// The single code path to the shared store. Used by the app's store and by the
/// widget's timeline provider so both see identical data.
enum EventStore {
    static let appGroupID = "group.foster.until"
    private static let eventsKey = "events"

    /// The App Group suite. Falls back to `.standard` only if the suite can't be
    /// opened (shouldn't happen once the App Group entitlement is present).
    static let shared: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    static func loadEvents(from defaults: UserDefaults = shared) -> [UntilEvent] {
        guard let data = defaults.data(forKey: eventsKey),
              let decoded = try? JSONDecoder().decode([UntilEvent].self, from: data)
        else { return [] }
        return decoded.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func saveEvents(_ events: [UntilEvent], to defaults: UserDefaults = shared) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: eventsKey)
    }

    static func event(id: UUID, from defaults: UserDefaults = shared) -> UntilEvent? {
        loadEvents(from: defaults).first { $0.id == id }
    }

    /// What a widget shows when no event is configured: the soonest upcoming
    /// countdown, else the first event in the list.
    static func defaultEvent(now: Date = Date(), from defaults: UserDefaults = shared) -> UntilEvent? {
        let events = loadEvents(from: defaults)
        let startOfToday = Calendar.current.startOfDay(for: now)
        let upcoming = events
            .filter { $0.mode == .until && $0.effectiveTarget(now: now) >= startOfToday }
            .sorted { $0.effectiveTarget(now: now) < $1.effectiveTarget(now: now) }
        return upcoming.first ?? events.first
    }

    /// Reset a `since` event's anchor to `now`, banking the run that just ended
    /// into its record. No-op for `until` events. Persists and returns the new list.
    @discardableResult
    static func resetSince(id: UUID, now: Date = Date(), from defaults: UserDefaults = shared) -> [UntilEvent] {
        var events = loadEvents(from: defaults)
        guard let i = events.firstIndex(where: { $0.id == id }), events[i].mode == .since else { return events }
        let run = max(0, now.timeIntervalSince(events[i].date))
        events[i].recordSeconds = max(events[i].recordSeconds, run)
        events[i].date = now
        saveEvents(events, to: defaults)
        return events
    }

    static func accentColor(for id: UUID, from defaults: UserDefaults = shared) -> Color {
        (event(id: id, from: defaults)?.accent ?? .vermilion).color
    }
}

// MARK: - Accent palette

/// The curated palette an event can wear.
enum AccentChoice: String, Codable, CaseIterable, Identifiable {
    case vermilion, amber, green, cobalt, violet, pink, ink

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .vermilion: return Color(red: 0.91, green: 0.27, blue: 0.13)
        case .amber:     return Color(red: 0.95, green: 0.62, blue: 0.07)
        case .green:     return Color(red: 0.20, green: 0.65, blue: 0.33)
        case .cobalt:    return Color(red: 0.15, green: 0.39, blue: 0.92)
        case .violet:    return Color(red: 0.49, green: 0.23, blue: 0.93)
        case .pink:      return Color(red: 0.86, green: 0.15, blue: 0.47)
        case .ink:       return Color.primary
        }
    }

    /// Readable text color on a filled accent background. Amber is light enough that
    /// white fails WCAG contrast, so it gets near-black ink instead.
    var onColor: Color {
        switch self {
        case .amber: return Color(red: 0.15, green: 0.12, blue: 0.05)
        default:     return .white
        }
    }
}

extension Bundle {
    /// "1.2.0 (4)" from the build settings — so the About screen never drifts.
    var displayVersion: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// UserDefaults keys for app-only settings.
enum SettingsKeys {
    static let appearance = "appearance"
    static let accent = "defaultAccent"
    static let haptics = "haptics"
    static let reminderHour = "reminderHour"   // hour-of-day (0–23) recurring reminders fire
    static let layout = "layout"               // list vs grid
}

// MARK: - Smart-units logic (pure, testable)

enum CountLogic {
    /// Past this many days, a countdown/up reads in years + months + days instead
    /// of a single day number.
    static let breakdownThresholdDays = 90

    /// The rendered numbers for one event at a moment in time.
    struct Readout: Equatable {
        var big: String      // the large primary numeral ("12", "2", "Today")
        var unit: String     // "days until", "hours since", "day ago", ""
        var detail: String   // secondary line — a date or spelled-out remainder
        var reached: Bool    // an `until` whose target has arrived/passed
    }

    /// Signed whole calendar days between two instants, using day boundaries.
    static func calendarDays(from: Date, to: Date, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: from)
        let b = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func readout(for event: UntilEvent, now: Date = Date(), calendar: Calendar = .current) -> Readout {
        switch event.mode {
        case .until:
            // Recurring events count to their next occurrence, so they never read
            // "days ago" — on the day itself the target is today (→ "Today").
            let target = event.effectiveTarget(now: now, calendar: calendar)
            let dateStr = target.formatted(date: .abbreviated, time: event.includeTime ? .shortened : .omitted)
            let remaining = target.timeIntervalSince(now)
            if remaining <= 0 {
                let ago = calendarDays(from: target, to: now, calendar: calendar)
                if ago <= 0 { return Readout(big: "Today", unit: "", detail: dateStr, reached: true) }
                return Readout(big: "\(ago)", unit: ago == 1 ? "day ago" : "days ago", detail: dateStr, reached: true)
            }
            if event.includeTime && remaining < 86_400 {
                return subDay(seconds: remaining, suffix: "until", detail: dateStr)
            }
            return dayReadout(from: now, to: target, suffix: "until", detail: dateStr, calendar: calendar)

        case .since:
            let dateStr = event.date.formatted(date: .abbreviated, time: event.includeTime ? .shortened : .omitted)
            let elapsed = max(0, now.timeIntervalSince(event.date))
            if event.includeTime && elapsed < 86_400 {
                return subDay(seconds: elapsed, suffix: "since", detail: dateStr)
            }
            return dayReadout(from: event.date, to: now, suffix: "since", detail: dateStr, calendar: calendar)
        }
    }

    /// 0…1 fill for ring widgets.
    static func progress(for event: UntilEvent, now: Date = Date()) -> Double {
        // Recurring: fill across the current period (previous → next occurrence).
        if event.isRecurring {
            let cal = Calendar.current
            let next = event.effectiveTarget(now: now, calendar: cal)
            guard let prev = event.recurrence.previousOccurrence(before: next, calendar: cal) else { return 0 }
            let total = next.timeIntervalSince(prev)
            guard total > 0 else { return 0 }
            return min(1, max(0, now.timeIntervalSince(prev) / total))
        }
        switch event.mode {
        case .until:
            let origin = event.progressOrigin
            let total = event.date.timeIntervalSince(origin)
            guard total > 0 else { return event.date <= now ? 1 : 0 }
            return min(1, max(0, now.timeIntervalSince(origin) / total))
        case .since:
            let run = max(0, now.timeIntervalSince(event.date))
            if event.recordSeconds > 0 { return min(1, run / event.recordSeconds) }
            return run > 0 ? 1 : 0
        }
    }

    /// Seconds since a `since` event's anchor.
    static func currentRun(for event: UntilEvent, now: Date = Date()) -> Double {
        max(0, now.timeIntervalSince(event.date))
    }

    /// Compact human duration, e.g. "14 days", "6h", "12m".
    static func durationText(_ seconds: Double) -> String {
        let days = Int(seconds / 86_400)
        if days >= 1 { return days == 1 ? "1 day" : "\(days) days" }
        let h = Int(seconds / 3_600)
        if h >= 1 { return "\(h)h" }
        let m = Int(seconds / 60)
        return "\(m)m"
    }

    // MARK: Builders

    private static func dayReadout(from: Date, to: Date, suffix: String, detail: String, calendar: Calendar) -> Readout {
        let days = max(0, calendarDays(from: from, to: to, calendar: calendar))
        if days >= breakdownThresholdDays {
            let c = calendar.dateComponents([.year, .month, .day],
                                            from: calendar.startOfDay(for: from),
                                            to: calendar.startOfDay(for: to))
            return breakdown(y: c.year ?? 0, m: c.month ?? 0, d: c.day ?? 0, suffix: suffix, dateStr: detail)
        }
        return Readout(big: "\(days)", unit: noun(days, "day") + " " + suffix, detail: detail, reached: false)
    }

    private static func subDay(seconds: Double, suffix: String, detail: String) -> Readout {
        let s = Int(seconds)
        if s < 60 {
            return Readout(big: "\(s)", unit: noun(s, "second") + " " + suffix, detail: detail, reached: false)
        }
        if s < 3_600 {
            let m = s / 60
            return Readout(big: "\(m)", unit: noun(m, "minute") + " " + suffix, detail: "\(s % 60) sec", reached: false)
        }
        let h = s / 3_600
        let m = (s % 3_600) / 60
        return Readout(big: "\(h)", unit: noun(h, "hour") + " " + suffix, detail: m > 0 ? "\(m) min" : detail, reached: false)
    }

    private static func breakdown(y: Int, m: Int, d: Int, suffix: String, dateStr: String) -> Readout {
        if y > 0 {
            var parts: [String] = []
            if m > 0 { parts.append(qty(m, "month")) }
            if d > 0 { parts.append(qty(d, "day")) }
            return Readout(big: "\(y)", unit: noun(y, "year") + " " + suffix,
                           detail: parts.isEmpty ? dateStr : parts.joined(separator: ", "), reached: false)
        }
        if m > 0 {
            return Readout(big: "\(m)", unit: noun(m, "month") + " " + suffix,
                           detail: d > 0 ? qty(d, "day") : dateStr, reached: false)
        }
        return Readout(big: "\(d)", unit: noun(d, "day") + " " + suffix, detail: dateStr, reached: false)
    }

    /// "1 day" → "day", "3 days" → "days". Returns the bare noun (caller adds the count).
    private static func noun(_ n: Int, _ word: String) -> String { n == 1 ? word : word + "s" }

    /// Count + pluralized noun, e.g. "1 day", "3 months".
    private static func qty(_ n: Int, _ word: String) -> String { "\(n) " + noun(n, word) }
}

// MARK: - Theme

/// Editorial monochrome. A single accent per event; everything else is primary /
/// secondary. Defined in code so the app and widget share it without duplicating an
/// asset across two catalogs.
enum Theme {
    /// Continuous rounded-square corner radius for a card of side `side`.
    static func cardCorner(_ side: CGFloat) -> CGFloat { min(28, side * 0.18) }

    /// The display face for headlines (titles, big numbers). SF Rounded — soft and
    /// warm, the app's only "voice" font. Swap `design:` to restyle every headline.
    static func display(_ style: Font.TextStyle) -> Font { .system(style, design: .rounded) }
}
