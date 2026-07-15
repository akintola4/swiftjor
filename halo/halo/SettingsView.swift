//
//  SettingsView.swift
//  halo
//
//  Appearance + an optional manual location (used when device location is off/denied).
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    let location: LocationManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    Toggle("Set location manually", isOn: $settings.useManualLocation)
                    if settings.useManualLocation {
                        TextField("Place name", text: $settings.manualName)
                        LabeledContent("Latitude") {
                            TextField("Latitude", value: $settings.manualLatitude, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                        }
                        LabeledContent("Longitude") {
                            TextField("Longitude", value: $settings.manualLongitude, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    } else {
                        Button("Use my current location") { location.requestOrRefresh() }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("The Sun tab and Sun widget use this location. The Moon is the same everywhere on Earth.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.displayVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text("Sunrise, sunset, golden hour, and the phase of the moon — computed on device.")
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
}
