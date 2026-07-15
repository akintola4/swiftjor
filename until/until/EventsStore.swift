//
//  EventsStore.swift
//  until
//
//  App target only. Reactive store over the shared App Group events list. Every
//  mutation persists and reloads widget timelines so both surfaces stay in sync.
//

import SwiftUI
import WidgetKit

@Observable
final class EventsStore {
    private let defaults: UserDefaults
    var events: [UntilEvent]

    init(defaults: UserDefaults = EventStore.shared) {
        self.defaults = defaults
        let loaded = EventStore.loadEvents(from: defaults)
        if loaded.isEmpty {
            events = EventsStore.seed()
            EventStore.saveEvents(events, to: defaults)
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            events = loaded
        }
    }

    func add(_ event: UntilEvent) {
        var e = event
        e.sortOrder = (events.map(\.sortOrder).max() ?? -1) + 1
        events.append(e)
        persist()
    }

    func update(_ event: UntilEvent) {
        guard let i = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[i] = event
        persist()
    }

    func delete(_ event: UntilEvent) {
        events.removeAll { $0.id == event.id }
        persist()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        events.move(fromOffsets: offsets, toOffset: destination)
        for i in events.indices { events[i].sortOrder = i }
        persist()
    }

    /// Reset a `since` event, banking its run into the record.
    func resetSince(_ event: UntilEvent) {
        events = EventStore.resetSince(id: event.id, from: defaults)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Re-read from the App Group (e.g. after a widget interaction mutated it).
    func reload() { events = EventStore.loadEvents(from: defaults) }

    /// Re-arm recurring-event reminders (e.g. after the reminder hour changes).
    func rescheduleReminders(now: Date = Date()) {
        UntilNotificationScheduler.reschedule(events: events, defaults: defaults, now: now)
    }

    private func persist() {
        EventStore.saveEvents(events, to: defaults)
        WidgetCenter.shared.reloadAllTimelines()
        rescheduleReminders()
    }

    /// Friendly first-run content that also showcases the app's features
    /// (recurring, filled covers, categories, count-up with a record, notes).
    private static func seed() -> [UntilEvent] {
        let cal = Calendar.current
        let now = Date()
        func day(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: cal.startOfDay(for: now)) ?? now }
        let newYear = cal.nextDate(after: now, matching: DateComponents(month: 1, day: 1), matchingPolicy: .nextTime) ?? now

        return [
            UntilEvent(title: "Payday", symbol: "banknote", accent: .green, mode: .until,
                       date: day(10), sortOrder: 0,
                       recurrence: .monthlyDay(day: 25),
                       category: "Money", filled: true),
            UntilEvent(title: "Roadtrip", symbol: "airplane", accent: .pink, mode: .until,
                       date: day(18), includeTime: true, sortOrder: 1,
                       notes: "Pick up the rental at 9am.", category: "Travel", filled: true),
            UntilEvent(title: "Product launch", symbol: "flag.checkered", accent: .cobalt, mode: .until,
                       date: day(46), sortOrder: 2,
                       notes: "Ship the App Store build.", startDate: day(-30),
                       category: "Work", filled: true),
            UntilEvent(title: "Birthday", symbol: "birthday.cake", accent: .amber, mode: .until,
                       date: day(72), sortOrder: 3, category: "Life", filled: true),
            UntilEvent(title: "New Year", symbol: "sparkles", accent: .violet, mode: .until,
                       date: cal.startOfDay(for: newYear), sortOrder: 4, category: "Life"),
            UntilEvent(title: "Smoke-free", symbol: "leaf.fill", accent: .green, mode: .since,
                       date: day(-46), recordSeconds: 60 * 86_400, sortOrder: 5, category: "Health"),
            UntilEvent(title: "Last deploy", symbol: "arrow.up.circle", accent: .vermilion, mode: .since,
                       date: cal.date(byAdding: .hour, value: -14, to: now) ?? now, includeTime: true,
                       sortOrder: 6, category: "Work"),
        ]
    }
}
