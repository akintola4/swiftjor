//
//  EventEditor.swift
//  until
//
//  Create / edit one event. Native Form picks up Liquid Glass chrome automatically.
//

import SwiftUI

struct EventEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UntilEvent

    // Recurrence is an enum with associated values; SwiftUI binds more cleanly to a
    // flat "kind" + per-kind params, reassembled into a RecurrenceRule on change/save.
    @State private var recurrenceKind: RecurrenceKind
    @State private var monthlyDay: Int
    @State private var biweeklyAnchor: Date
    @State private var lastWeekday: Int
    @State private var hasStart: Bool
    @State private var startDate: Date

    private let isNew: Bool
    private let onSave: (UntilEvent) -> Void
    private let onDelete: (() -> Void)?

    init(
        event: UntilEvent?,
        defaultAccent: AccentChoice,
        onSave: @escaping (UntilEvent) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.isNew = event == nil
        self.onSave = onSave
        self.onDelete = onDelete
        let initial = event ?? UntilEvent(
            title: "",
            symbol: "calendar",
            accent: defaultAccent,
            mode: .until,
            date: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        )
        _draft = State(initialValue: initial)

        _hasStart = State(initialValue: initial.startDate != nil)
        _startDate = State(initialValue: initial.startDate ?? Calendar.current.startOfDay(for: initial.createdAt))

        // Seed the recurrence controls from the event's rule.
        switch initial.recurrence {
        case .none:
            _recurrenceKind = State(initialValue: .none)
            _monthlyDay = State(initialValue: Calendar.current.component(.day, from: initial.date))
            _biweeklyAnchor = State(initialValue: Calendar.current.startOfDay(for: Date()))
            _lastWeekday = State(initialValue: 6)   // Friday
        case .monthlyDay(let day):
            _recurrenceKind = State(initialValue: .monthly)
            _monthlyDay = State(initialValue: day)
            _biweeklyAnchor = State(initialValue: Calendar.current.startOfDay(for: Date()))
            _lastWeekday = State(initialValue: 6)
        case .everyNWeeks(_, let anchor):
            _recurrenceKind = State(initialValue: .biweekly)
            _monthlyDay = State(initialValue: Calendar.current.component(.day, from: initial.date))
            _biweeklyAnchor = State(initialValue: anchor)
            _lastWeekday = State(initialValue: 6)
        case .lastWeekdayOfMonth(let weekday):
            _recurrenceKind = State(initialValue: .lastWeekday)
            _monthlyDay = State(initialValue: Calendar.current.component(.day, from: initial.date))
            _biweeklyAnchor = State(initialValue: Calendar.current.startOfDay(for: Date()))
            _lastWeekday = State(initialValue: weekday)
        }
    }

    /// The recurrence choices the editor offers (biweekly is fixed at 2 weeks).
    enum RecurrenceKind: String, CaseIterable, Identifiable {
        case none, monthly, biweekly, lastWeekday
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none:        return "Never"
            case .monthly:     return "Monthly on a day"
            case .biweekly:    return "Every 2 weeks"
            case .lastWeekday: return "Last weekday"
            }
        }
    }

    /// Build a RecurrenceRule from the flat editor state.
    private var currentRule: RecurrenceRule {
        switch recurrenceKind {
        case .none:        return .none
        case .monthly:     return .monthlyDay(day: monthlyDay)
        case .biweekly:    return .everyNWeeks(n: 2, anchor: Calendar.current.startOfDay(for: biweeklyAnchor))
        case .lastWeekday: return .lastWeekdayOfMonth(weekday: lastWeekday)
        }
    }

    private let weekdaySymbols = Calendar.current.weekdaySymbols   // ["Sunday", … "Saturday"]

    private let symbols = [
        "calendar", "flag.checkered", "airplane", "gift", "birthday.cake", "heart.fill",
        "star.fill", "graduationcap.fill", "briefcase.fill", "hammer.fill", "figure.run", "cup.and.saucer.fill",
        "arrow.up.circle", "moon.stars.fill", "sparkles", "sun.max.fill", "leaf.fill", "cross.case.fill",
    ]

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                    Picker("Mode", selection: $draft.mode) {
                        Text("Count down").tag(EventMode.until)
                        Text("Count up").tag(EventMode.since)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Date") {
                    if draft.mode == .until && recurrenceKind != .none {
                        LabeledContent("Next") {
                            Text(currentRule.nextOccurrence(onOrAfter: Date())?
                                    .formatted(date: .abbreviated, time: .omitted) ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        DatePicker(
                            draft.mode == .until ? "Target" : "Since",
                            selection: $draft.date,
                            displayedComponents: draft.includeTime ? [.date, .hourAndMinute] : [.date]
                        )
                        Toggle("Include time of day", isOn: $draft.includeTime)
                        if draft.mode == .until {
                            Toggle("Set a start date", isOn: $hasStart.animation())
                            if hasStart {
                                DatePicker("Countdown starts", selection: $startDate,
                                           in: ...draft.date, displayedComponents: [.date])
                            }
                            Toggle("Milestone alerts", isOn: $draft.milestoneAlerts)
                        }
                    }
                }

                if draft.mode == .until {
                    Section("Repeat") {
                        Picker("Repeat", selection: $recurrenceKind) {
                            ForEach(RecurrenceKind.allCases) { Text($0.label).tag($0) }
                        }
                        switch recurrenceKind {
                        case .none:
                            EmptyView()
                        case .monthly:
                            Picker("Day of month", selection: $monthlyDay) {
                                ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                            }
                        case .biweekly:
                            DatePicker("First payday", selection: $biweeklyAnchor, displayedComponents: [.date])
                        case .lastWeekday:
                            Picker("Weekday", selection: $lastWeekday) {
                                ForEach(1...7, id: \.self) { wd in
                                    Text(weekdaySymbols[wd - 1]).tag(wd)
                                }
                            }
                        }
                        if recurrenceKind != .none {
                            Toggle("Remind me on the day", isOn: $draft.reminder)
                        }
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: iconColumns, spacing: 10) {
                        ForEach(symbols, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .font(.title3)
                                .frame(width: 42, height: 42)
                                .foregroundStyle(draft.symbol == symbol ? .white : .primary)
                                .background(
                                    draft.symbol == symbol ? AnyShapeStyle(draft.accent.color) : AnyShapeStyle(.fill.tertiary),
                                    in: .circle
                                )
                                .onTapGesture { draft.symbol = symbol }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Category") {
                    TextField("e.g. Work, Travel, Birthdays", text: $draft.category)
                        .autocorrectionDisabled()
                }

                Section("Notes") {
                    TextField("Add a note…", text: $draft.notes, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("Color") {
                    HStack {
                        ForEach(AccentChoice.allCases) { choice in
                            Circle()
                                .fill(choice.color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().stroke(Color.primary, lineWidth: draft.accent == choice ? 2 : 0)
                                        .padding(-3)
                                )
                                .frame(maxWidth: .infinity)
                                .contentShape(.circle)
                                .onTapGesture { draft.accent = choice }
                        }
                    }
                    .padding(.vertical, 4)
                    Toggle("Filled cover", isOn: $draft.filled)
                }

                if let onDelete {
                    Section {
                        Button("Delete event", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        var event = draft
        event.title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.recurrence = draft.mode == .until ? currentRule : .none
        if event.recurrence.isRecurring {
            // Recurring targets are day-granular and computed; store the next
            // occurrence as a sensible fallback and drop time-of-day precision.
            event.includeTime = false
            event.date = event.recurrence.nextOccurrence(onOrAfter: Date()) ?? event.date
            event.startDate = nil
        } else {
            event.reminder = false
        }
        // A custom start date only applies to a one-shot countdown.
        event.startDate = (draft.mode == .until && !event.recurrence.isRecurring && hasStart)
            ? Calendar.current.startOfDay(for: startDate) : nil
        if !event.includeTime {
            event.date = Calendar.current.startOfDay(for: event.date)
        }
        onSave(event)
        dismiss()
    }
}
