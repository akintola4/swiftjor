//
//  AppSettings.swift
//  until
//
//  App target only. Reactive wrapper over the shared App Group store for the
//  handful of global preferences.
//

import SwiftUI

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

enum EventLayout: String, CaseIterable { case list, grid }

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: SettingsKeys.appearance) } }
    var defaultAccent: AccentChoice { didSet { defaults.set(defaultAccent.rawValue, forKey: SettingsKeys.accent) } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: SettingsKeys.haptics) } }
    var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: SettingsKeys.reminderHour) } }
    var layout: EventLayout { didSet { defaults.set(layout.rawValue, forKey: SettingsKeys.layout) } }

    init(defaults: UserDefaults = EventStore.shared) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: SettingsKeys.appearance) ?? "") ?? .system
        defaultAccent = AccentChoice(rawValue: defaults.string(forKey: SettingsKeys.accent) ?? "") ?? .vermilion
        haptics = defaults.object(forKey: SettingsKeys.haptics) as? Bool ?? true
        reminderHour = defaults.object(forKey: SettingsKeys.reminderHour) as? Int ?? 9
        layout = EventLayout(rawValue: defaults.string(forKey: SettingsKeys.layout) ?? "") ?? .list
    }
}
