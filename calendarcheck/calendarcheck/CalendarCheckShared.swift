//
//  CalendarCheckShared.swift
//  calendarcheck
//
//  Shared between the app AND the widget extension.
//  IMPORTANT: Target Membership must be checked for BOTH `calendarcheck` and
//     `calendarcheckWidgetExtension`, or the widget build will fail with
//     "Cannot find type ... in scope".
//
//  Everything here is observation-free and side-effect-free so the widget's
//  timeline provider can read it directly without an @Observable store.
//

import SwiftUI

// MARK: - DayKey

/// A single calendar day, identified by year/month/day only (no time-of-day).
/// Stored in a `Set` for O(1) toggle/lookup and encoded as JSON for the App Group.
struct DayKey: Hashable, Codable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year!
        self.month = c.month!
        self.day = c.day!
    }

    /// The midnight `Date` for this day, if representable in the given calendar.
    func date(in calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Stable string key for dictionaries / JSON (e.g. day notes).
    var storageKey: String { "\(year)-\(month)-\(day)" }
}

extension DayKey: Identifiable {
    var id: String { storageKey }
}

// MARK: - Persistence (App Group)

/// The single code path to the shared store. Used by the app's store and by the
/// widget's timeline provider so both see identical data.
enum CheckPersistence {
    static let appGroupID = "group.foster.calendarcheck"
    static let defaultTitle = "Daily Check"

    private static let daysKey = "passedDays"
    private static let titleKey = "habitTitle"
    private static let noteKey = "habitNote"
    private static let dayNotesKey = "dayNotes"

    /// The App Group suite. On the Simulator this resolves even without portal
    /// provisioning. Falls back to `.standard` only if the suite can't be opened
    /// (should never happen once the App Group entitlement is present).
    static let shared: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    static func loadDays(from defaults: UserDefaults = shared) -> Set<DayKey> {
        guard let data = defaults.data(forKey: daysKey),
              let decoded = try? JSONDecoder().decode(Set<DayKey>.self, from: data)
        else { return [] }
        return decoded
    }

    static func saveDays(_ days: Set<DayKey>, to defaults: UserDefaults = shared) {
        guard let data = try? JSONEncoder().encode(days) else { return }
        defaults.set(data, forKey: daysKey)
    }

    static func loadTitle(from defaults: UserDefaults = shared) -> String {
        defaults.string(forKey: titleKey) ?? defaultTitle
    }

    static func saveTitle(_ title: String, to defaults: UserDefaults = shared) {
        defaults.set(title, forKey: titleKey)
    }

    static func loadNote(from defaults: UserDefaults = shared) -> String {
        defaults.string(forKey: noteKey) ?? ""
    }

    static func saveNote(_ note: String, to defaults: UserDefaults = shared) {
        defaults.set(note, forKey: noteKey)
    }

    // Per-day notes, keyed by DayKey.storageKey.

    static func loadDayNotes(from defaults: UserDefaults = shared) -> [String: String] {
        guard let data = defaults.data(forKey: dayNotesKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    static func saveDayNotes(_ notes: [String: String], to defaults: UserDefaults = shared) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: dayNotesKey)
    }

    // Settings that the widget also needs to read directly.

    static func loadIcon(from defaults: UserDefaults = shared) -> String {
        defaults.string(forKey: SettingsKeys.habitIcon) ?? ""
    }

    static func weekStartsMonday(from defaults: UserDefaults = shared) -> Bool {
        if defaults.object(forKey: SettingsKeys.weekStartsMonday) == nil {
            return Calendar.current.firstWeekday == 2
        }
        return defaults.bool(forKey: SettingsKeys.weekStartsMonday)
    }

    /// A calendar honoring the user's week-start preference.
    static func calendar(from defaults: UserDefaults = shared) -> Calendar {
        var c = Calendar.current
        c.firstWeekday = weekStartsMonday(from: defaults) ? 2 : 1
        return c
    }

    /// The chosen check color (used by the widget, which has no AppSettings).
    static func accentColor(from defaults: UserDefaults = shared) -> Color {
        (AccentChoice(rawValue: defaults.string(forKey: SettingsKeys.accent) ?? "") ?? .vermilion).color
    }
}

/// The curated palette for the check color.
enum AccentChoice: String, CaseIterable, Identifiable {
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
}

/// UserDefaults keys for settings (shared so the widget can read the relevant ones).
enum SettingsKeys {
    static let habitIcon = "habitIcon"
    static let weekStartsMonday = "weekStartsMonday"
    static let reminderEnabled = "reminderEnabled"
    static let reminderHour = "reminderHour"
    static let reminderMinute = "reminderMinute"
    static let monthlySummary = "monthlySummary"
    static let yearlySummary = "yearlySummary"
    static let appearance = "appearance"
    static let accent = "accentColor"
    static let monthlyGoal = "monthlyGoal"
    static let haptics = "haptics"
    static let appLock = "appLock"
    static let quotesEnabled = "quotesEnabled"
    static let customQuotes = "customQuotes"
}

// MARK: - Pure logic

enum CheckLogic {
    /// Consecutive passed days ending today — or ending yesterday if today isn't
    /// passed yet. Uses `Calendar` day arithmetic so month/year/DST boundaries are
    /// handled automatically.
    static func currentStreak(
        passed: Set<DayKey>,
        calendar: Calendar = .current,
        asOf today: Date = Date()
    ) -> Int {
        let todayKey = DayKey(date: today, calendar: calendar)

        var cursor: Date
        if passed.contains(todayKey) {
            cursor = calendar.startOfDay(for: today)
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  passed.contains(DayKey(date: yesterday, calendar: calendar))
            else { return 0 }
            cursor = calendar.startOfDay(for: yesterday)
        }

        var count = 0
        while passed.contains(DayKey(date: cursor, calendar: calendar)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    static func daysPassed(in passed: Set<DayKey>, year: Int, month: Int) -> Int {
        passed.filter { $0.year == year && $0.month == month }.count
    }

    static func daysPassed(in passed: Set<DayKey>, year: Int) -> Int {
        passed.filter { $0.year == year }.count
    }

    /// Streak lengths worth celebrating.
    static let milestones = [7, 30, 100, 365]

    /// Longest run of consecutive passed days, anywhere in the history.
    static func longestStreak(passed: Set<DayKey>, calendar: Calendar = .current) -> Int {
        let dates = passed
            .compactMap { $0.date(in: calendar).map { calendar.startOfDay(for: $0) } }
            .sorted()
        guard !dates.isEmpty else { return 0 }
        var longest = 1, run = 1
        for i in 1..<dates.count {
            if let next = calendar.date(byAdding: .day, value: 1, to: dates[i - 1]),
               calendar.isDate(next, inSameDayAs: dates[i]) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }

    /// Lengths of every consecutive run in the history (for counting milestone hits).
    static func allStreaks(passed: Set<DayKey>, calendar: Calendar = .current) -> [Int] {
        let dates = passed
            .compactMap { $0.date(in: calendar).map { calendar.startOfDay(for: $0) } }
            .sorted()
        guard !dates.isEmpty else { return [] }
        var runs: [Int] = []
        var run = 1
        for i in 1..<dates.count {
            if let next = calendar.date(byAdding: .day, value: 1, to: dates[i - 1]),
               calendar.isDate(next, inSameDayAs: dates[i]) {
                run += 1
            } else {
                runs.append(run)
                run = 1
            }
        }
        runs.append(run)
        return runs
    }

    /// How many separate streaks reached at least `milestone` days.
    static func milestoneHits(_ milestone: Int, passed: Set<DayKey>, calendar: Calendar = .current) -> Int {
        allStreaks(passed: passed, calendar: calendar).filter { $0 >= milestone }.count
    }

    /// The month with the most checks, if any.
    static func bestMonth(passed: Set<DayKey>) -> (year: Int, month: Int, count: Int)? {
        var counts: [Int: Int] = [:]
        for d in passed { counts[d.year * 100 + d.month, default: 0] += 1 }
        guard let best = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (year: best.key / 100, month: best.key % 100, count: best.value)
    }

    /// Number of days in the given month (handles 28/29/30/31 correctly).
    static func lastDay(ofYear year: Int, month: Int, calendar: Calendar = .current) -> Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date)
        else { return 28 }
        return range.count
    }
}

// MARK: - Month layout

/// Calendar-aware layout for one month: weekday header order, leading blanks, and
/// the list of day numbers. Shared by the app's calendar and the widget grid.
struct MonthGrid {
    let year: Int
    let month: Int
    let leadingBlanks: Int
    let days: [Int]
    let weekdaySymbols: [String]

    init(year: Int, month: Int, calendar: Calendar = .current) {
        self.year = year
        self.month = month
        self.days = Array(1...CheckLogic.lastDay(ofYear: year, month: month, calendar: calendar))

        let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        self.leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        self.weekdaySymbols = Array(symbols[start...] + symbols[..<start])
    }

    func name(calendar: Calendar = .current) -> String { calendar.monthSymbols[month - 1] }
}

// MARK: - Theme

/// Editorial monochrome. The ONE accent (vermilion) appears only on a passed-day
/// check. Defined in code so the app and widget share it without duplicating an
/// asset across two catalogs.
enum Theme {
    /// Vermilion — saturated enough to sit confidently on both near-white and
    /// near-black. The only color in the app. Swap this one line to change it.
    static let accent = Color(red: 0.91, green: 0.27, blue: 0.13)

    /// Continuous rounded-square corner radius for a cell of side `side`.
    static func cellCorner(_ side: CGFloat) -> CGFloat { side * 0.30 }

    static func serif(_ style: Font.TextStyle) -> Font { .system(style, design: .serif) }
}
