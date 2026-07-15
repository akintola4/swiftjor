//
//  HaloApp.swift
//  halo
//
//  Sun & Moon, at a glance. On-device astronomy (CoreLocation + math), widget-first.
//

import SwiftUI
import WidgetKit

@main
struct HaloApp: App {
    @State private var location = LocationManager()
    @State private var settings = AppSettings()
    @State private var selection: HaloFace = .sun
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(location: location, settings: settings, selection: $selection)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        location.refresh()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                .onOpenURL { url in
                    // halo://sun or halo://moon — from a tapped widget or Live Activity.
                    if let face = url.host.flatMap({ HaloFace(rawValue: $0) }) { selection = face }
                }
        }
    }
}
