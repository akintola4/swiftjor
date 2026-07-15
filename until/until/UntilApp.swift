//
//  UntilApp.swift
//  until
//
//  Count down to a date, or up from one. Widget-first, App-Group backed.
//

import SwiftUI

@main
struct UntilApp: App {
    @State private var store = EventsStore()
    @State private var settings = AppSettings()
    @State private var deepLinkedEventID: UUID?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, settings: settings, deepLinkedEventID: $deepLinkedEventID)
                .preferredColorScheme(settings.appearance.colorScheme)
                // Support Dynamic Type, but clamp the extremes so the display
                // numerals and cards don't overflow (HIG-friendly middle ground).
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .onChange(of: scenePhase) { _, phase in
                    // The widget (via interactive reset) can mutate the store while
                    // the app is backgrounded — re-read on return, and re-arm reminders
                    // so a just-fired one-shot rolls to its next occurrence.
                    if phase == .active {
                        store.reload()
                        store.rescheduleReminders()
                    }
                }
                .onOpenURL { url in
                    // until://event/<uuid> — delivered when a widget is tapped.
                    guard url.scheme == "until", url.host == "event",
                          let id = UUID(uuidString: url.lastPathComponent) else { return }
                    deepLinkedEventID = id
                }
        }
    }
}
