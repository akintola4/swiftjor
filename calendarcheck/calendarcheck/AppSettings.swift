//
//  AppSettings.swift
//  calendarcheck
//
//  App target ONLY. Reactive wrapper over the shared App Group store for all
//  user settings. Widget reads the few it needs (icon, week-start) via CheckPersistence.
//

import SwiftUI
import WidgetKit

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var habitIcon: String { didSet { defaults.set(habitIcon, forKey: SettingsKeys.habitIcon); reloadWidgets() } }
    var weekStartsMonday: Bool { didSet { defaults.set(weekStartsMonday, forKey: SettingsKeys.weekStartsMonday); reloadWidgets() } }
    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: SettingsKeys.appearance) } }
    var accent: AccentChoice { didSet { defaults.set(accent.rawValue, forKey: SettingsKeys.accent); reloadWidgets() } }
    var monthlyGoal: Int { didSet { defaults.set(monthlyGoal, forKey: SettingsKeys.monthlyGoal) } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: SettingsKeys.haptics) } }
    var appLock: Bool { didSet { defaults.set(appLock, forKey: SettingsKeys.appLock) } }

    var reminderEnabled: Bool { didSet { defaults.set(reminderEnabled, forKey: SettingsKeys.reminderEnabled) } }
    var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: SettingsKeys.reminderHour) } }
    var reminderMinute: Int { didSet { defaults.set(reminderMinute, forKey: SettingsKeys.reminderMinute) } }
    var monthlySummary: Bool { didSet { defaults.set(monthlySummary, forKey: SettingsKeys.monthlySummary) } }
    var yearlySummary: Bool { didSet { defaults.set(yearlySummary, forKey: SettingsKeys.yearlySummary) } }

    var quotesEnabled: Bool { didSet { defaults.set(quotesEnabled, forKey: SettingsKeys.quotesEnabled) } }
    var customQuotes: [String] { didSet { defaults.set(customQuotes, forKey: SettingsKeys.customQuotes) } }

    init(defaults: UserDefaults = CheckPersistence.shared) {
        self.defaults = defaults
        habitIcon = defaults.string(forKey: SettingsKeys.habitIcon) ?? ""
        weekStartsMonday = CheckPersistence.weekStartsMonday(from: defaults)
        appearance = Appearance(rawValue: defaults.string(forKey: SettingsKeys.appearance) ?? "") ?? .system
        accent = AccentChoice(rawValue: defaults.string(forKey: SettingsKeys.accent) ?? "") ?? .vermilion
        monthlyGoal = defaults.integer(forKey: SettingsKeys.monthlyGoal)
        haptics = defaults.object(forKey: SettingsKeys.haptics) as? Bool ?? true
        appLock = defaults.bool(forKey: SettingsKeys.appLock)
        reminderEnabled = defaults.bool(forKey: SettingsKeys.reminderEnabled)
        reminderHour = defaults.object(forKey: SettingsKeys.reminderHour) as? Int ?? 20
        reminderMinute = defaults.object(forKey: SettingsKeys.reminderMinute) as? Int ?? 0
        monthlySummary = defaults.object(forKey: SettingsKeys.monthlySummary) as? Bool ?? true
        yearlySummary = defaults.object(forKey: SettingsKeys.yearlySummary) as? Bool ?? true
        quotesEnabled = defaults.object(forKey: SettingsKeys.quotesEnabled) as? Bool ?? true
        customQuotes = defaults.stringArray(forKey: SettingsKeys.customQuotes) ?? AppSettings.defaultQuotes
    }

    /// Active quote pool: custom quotes if any, else the defaults.
    var activeQuotes: [String] {
        let trimmed = customQuotes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return trimmed.isEmpty ? AppSettings.defaultQuotes : trimmed
    }

    var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = weekStartsMonday ? 2 : 1
        return c
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static let defaultQuotes = [
        "Tomorrow isn't yours yet. Tend to today.",
        "You can only walk the day you're standing in.",
        "Don't borrow from a day that hasn't arrived.",
        "One day at a time — and this isn't that day yet.",
        "The future is a rumor. Today is the only day you can keep.",
        "Let tomorrow stay tomorrow.",
        "Patience is a discipline too.",
        "Can't check a box the sun hasn't risen on.",
    ]
}
