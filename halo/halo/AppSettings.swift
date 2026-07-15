//
//  AppSettings.swift
//  halo
//
//  App target only. Reactive prefs: appearance + an optional manual location that
//  overrides CoreLocation (the fallback when permission is denied).
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

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: SettingsKeys.appearance) } }
    var useManualLocation: Bool { didSet { defaults.set(useManualLocation, forKey: SettingsKeys.useManualLoc) } }
    var manualLatitude: Double { didSet { defaults.set(manualLatitude, forKey: SettingsKeys.manualLat) } }
    var manualLongitude: Double { didSet { defaults.set(manualLongitude, forKey: SettingsKeys.manualLon) } }
    var manualName: String { didSet { defaults.set(manualName, forKey: SettingsKeys.manualName) } }

    init(defaults: UserDefaults = LocationCache.shared) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: SettingsKeys.appearance) ?? "") ?? .system
        useManualLocation = defaults.bool(forKey: SettingsKeys.useManualLoc)
        manualLatitude = defaults.object(forKey: SettingsKeys.manualLat) as? Double ?? 51.5074
        manualLongitude = defaults.object(forKey: SettingsKeys.manualLon) as? Double ?? -0.1278
        manualName = defaults.string(forKey: SettingsKeys.manualName) ?? "London"
    }

    var manualSnapshot: LocationSnapshot {
        LocationSnapshot(latitude: manualLatitude, longitude: manualLongitude,
                         name: manualName.isEmpty ? "Custom" : manualName, savedAt: .distantPast)
    }
}
