//
//  CheckStore.swift
//  calendarcheck
//
//  App target ONLY. The reactive source of truth for the UI. Wraps the shared,
//  observation-free persistence/logic layer and adds the side effects: persist,
//  reload widgets, reschedule notifications.
//

import SwiftUI
import WidgetKit

@Observable
final class CheckStore {
    private(set) var days: Set<DayKey>
    private(set) var habitTitle: String
    private(set) var habitNote: String
    private(set) var dayNotes: [String: String]

    /// Set transiently when a toggle pushes the streak onto a milestone; the UI
    /// observes this to show a celebration, then clears it.
    var celebratedMilestone: Int?

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.days = CheckPersistence.loadDays()
        self.habitTitle = CheckPersistence.loadTitle()
        self.habitNote = CheckPersistence.loadNote()
        self.dayNotes = CheckPersistence.loadDayNotes()
    }

    func isPassed(_ day: DayKey) -> Bool { days.contains(day) }

    func toggle(_ day: DayKey) {
        let before = currentStreak
        if days.contains(day) {
            days.remove(day)
        } else {
            days.insert(day)
        }
        CheckPersistence.saveDays(days)
        let after = currentStreak
        if after > before, CheckLogic.milestones.contains(after) {
            celebratedMilestone = after
        }
        WidgetCenter.shared.reloadAllTimelines()
        scheduleSummaries()
    }

    func note(for day: DayKey) -> String { dayNotes[day.storageKey] ?? "" }

    func hasNote(_ day: DayKey) -> Bool { !(dayNotes[day.storageKey] ?? "").isEmpty }

    func setNote(_ text: String, for day: DayKey) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            dayNotes.removeValue(forKey: day.storageKey)
        } else {
            dayNotes[day.storageKey] = trimmed
        }
        CheckPersistence.saveDayNotes(dayNotes)
    }

    func clearAll() {
        days = []
        CheckPersistence.saveDays(days)
        WidgetCenter.shared.reloadAllTimelines()
        scheduleSummaries()
    }

    func setDetails(title newTitle: String, note newNote: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        habitTitle = trimmedTitle.isEmpty ? CheckPersistence.defaultTitle : trimmedTitle
        habitNote = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        CheckPersistence.saveTitle(habitTitle)
        CheckPersistence.saveNote(habitNote)
        WidgetCenter.shared.reloadAllTimelines()
    }

    var currentStreak: Int {
        CheckLogic.currentStreak(passed: days, calendar: calendar)
    }

    var daysThisMonth: Int {
        let c = calendar.dateComponents([.year, .month], from: Date())
        guard let year = c.year, let month = c.month else { return 0 }
        return CheckLogic.daysPassed(in: days, year: year, month: month)
    }

    /// Re-schedule the rolling end-of-month / end-of-year summaries with fresh counts.
    func scheduleSummaries() {
        NotificationScheduler.reschedule(days: days, calendar: calendar)
    }
}
