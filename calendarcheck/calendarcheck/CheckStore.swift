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

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.days = CheckPersistence.loadDays()
        self.habitTitle = CheckPersistence.loadTitle()
        self.habitNote = CheckPersistence.loadNote()
    }

    func isPassed(_ day: DayKey) -> Bool { days.contains(day) }

    func toggle(_ day: DayKey) {
        if days.contains(day) {
            days.remove(day)
        } else {
            days.insert(day)
        }
        CheckPersistence.saveDays(days)
        WidgetCenter.shared.reloadAllTimelines()
        scheduleSummaries()
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
