//
//  SettingsView.swift
//  until
//
//  A small Form of global preferences. Native chrome → automatic Liquid Glass.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Default color", selection: $settings.defaultAccent) {
                        ForEach(AccentChoice.allCases) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                }

                Section("Feel") {
                    Toggle("Haptics", isOn: $settings.haptics)
                }

                Section {
                    Picker("Time", selection: $settings.reminderHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(Self.hourLabel(hour)).tag(hour)
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Recurring events with “Remind me” on notify at this hour.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.displayVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text("Count down to what matters — and up from what you've kept.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// "9:00 AM" for an hour-of-day, respecting the user's 12/24-hour locale.
    private static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: 0)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
