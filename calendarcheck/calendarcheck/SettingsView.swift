//
//  SettingsView.swift
//  calendarcheck
//
//  App target only. Native Form (picks up iOS 26 Liquid Glass chrome automatically).
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let store: CheckStore

    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false

    private var calendar: Calendar { settings.calendar }
    private var thisYear: Int { calendar.component(.year, from: Date()) }

    var body: some View {
        NavigationStack {
            Form {
                remindersSection
                personalizationSection
                goalSection
                statsSection
                quotesSection
                feelSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onDisappear { store.scheduleSummaries() }
        }
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    // MARK: Reminders

    private var reminderTime: Binding<Date> {
        Binding {
            calendar.date(from: DateComponents(hour: settings.reminderHour, minute: settings.reminderMinute)) ?? Date()
        } set: { newValue in
            let c = calendar.dateComponents([.hour, .minute], from: newValue)
            settings.reminderHour = c.hour ?? 20
            settings.reminderMinute = c.minute ?? 0
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            Toggle("Daily check-in", isOn: $settings.reminderEnabled)
            if settings.reminderEnabled {
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
            Toggle("Month-end summary", isOn: $settings.monthlySummary)
            Toggle("Year-end summary", isOn: $settings.yearlySummary)
        }
    }

    // MARK: Personalization

    private var personalizationSection: some View {
        Section("Personalization") {
            Picker("Check color", selection: $settings.accent) {
                ForEach(AccentChoice.allCases) { choice in
                    HStack {
                        Circle().fill(choice.color).frame(width: 14, height: 14)
                        Text(choice.label)
                    }
                    .tag(choice)
                }
            }
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(Appearance.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Start week on Monday", isOn: $settings.weekStartsMonday)
        }
    }

    // MARK: Goal

    private var goalSection: some View {
        Section("Monthly goal") {
            Stepper(value: $settings.monthlyGoal, in: 0...31) {
                Text(settings.monthlyGoal == 0 ? "No goal" : "\(settings.monthlyGoal) days / month")
                    .monospacedDigit()
            }
            if settings.monthlyGoal > 0 {
                let c = calendar.dateComponents([.year, .month], from: Date())
                let done = CheckLogic.daysPassed(in: store.days, year: c.year ?? 0, month: c.month ?? 0)
                ProgressView(value: Double(min(done, settings.monthlyGoal)), total: Double(settings.monthlyGoal)) {
                    Text("This month")
                } currentValueLabel: {
                    Text("\(done) / \(settings.monthlyGoal)").monospacedDigit()
                }
                .tint(settings.accent.color)
            }
        }
    }

    // MARK: Stats

    private var statsSection: some View {
        Section("Stats") {
            stat("Current streak", CheckLogic.currentStreak(passed: store.days, calendar: calendar))
            stat("Longest streak", CheckLogic.longestStreak(passed: store.days, calendar: calendar))
            stat("Total days", store.days.count)
            stat("This year", CheckLogic.daysPassed(in: store.days, year: thisYear))
            if let best = CheckLogic.bestMonth(passed: store.days) {
                LabeledContent("Best month") {
                    Text("\(calendar.monthSymbols[best.month - 1]) \(String(best.year)) · \(best.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        LabeledContent(label) {
            Text("\(value)").monospacedDigit().foregroundStyle(.secondary)
        }
    }

    // MARK: Quotes

    private var quotesSection: some View {
        Section("\"Not yet\" quotes") {
            Toggle("Show a quote on future taps", isOn: $settings.quotesEnabled)
            NavigationLink("Edit quotes") {
                QuotesEditor(settings: settings)
            }
        }
    }

    // MARK: Feel

    private var feelSection: some View {
        Section("Feel") {
            Toggle("Haptics", isOn: $settings.haptics)
            Toggle("Require Face ID to open", isOn: $settings.appLock)
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section("Data") {
            ShareLink(item: exportText) {
                Label("Export checks", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Text("Reset all checks")
            }
            .alert("Reset all checks?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) { store.clearAll() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently clears every checked day. Your name and note are kept.")
            }
        }
    }

    private var exportText: String {
        let sorted = store.days.sorted {
            ($0.year, $0.month, $0.day) < ($1.year, $1.month, $1.day)
        }
        let lines = sorted.map { String(format: "%04d-%02d-%02d", $0.year, $0.month, $0.day) }
        return "calendarcheck — \(store.habitTitle)\n\(store.days.count) days\n\n" + lines.joined(separator: "\n")
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(appVersion).foregroundStyle(.secondary)
            }
            LabeledContent("Made by") {
                Text("tope").foregroundStyle(.secondary)
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

// MARK: - Quotes editor

struct QuotesEditor: View {
    @Bindable var settings: AppSettings
    @State private var newQuote = ""

    var body: some View {
        List {
            Section {
                ForEach(Array(settings.activeQuotes.enumerated()), id: \.offset) { _, quote in
                    Text(quote)
                }
                .onDelete { offsets in
                    var quotes = settings.activeQuotes
                    quotes.remove(atOffsets: offsets)
                    settings.customQuotes = quotes
                }
            }
            Section("Add your own") {
                HStack {
                    TextField("A line about patience…", text: $newQuote, axis: .vertical)
                    Button("Add") {
                        let trimmed = newQuote.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        settings.customQuotes = settings.activeQuotes + [trimmed]
                        newQuote = ""
                    }
                    .disabled(newQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationTitle("Quotes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }
}
