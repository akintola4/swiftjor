//
//  NotificationScheduler.swift
//  calendarcheck
//
//  App target ONLY. Local notifications need no entitlement — just runtime auth.
//  A calendar trigger freezes its body text when scheduled, so we embed the count
//  now and reschedule on every launch + toggle to keep it fresh.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
    private static let endOfMonthID = "endOfMonth"
    private static let endOfYearID = "endOfYear"
    private static let dailyReminderID = "dailyReminder"

    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationForegroundDelegate.shared
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func reschedule(days: Set<DayKey>, calendar: Calendar = .current, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [endOfMonthID, endOfYearID, dailyReminderID])

        let d = CheckPersistence.shared
        let title = CheckPersistence.loadTitle()

        // Daily check-in reminder (repeating) — opt-in.
        if d.bool(forKey: SettingsKeys.reminderEnabled) {
            var rem = DateComponents()
            rem.hour = (d.object(forKey: SettingsKeys.reminderHour) as? Int) ?? 20
            rem.minute = (d.object(forKey: SettingsKeys.reminderMinute) as? Int) ?? 0
            rem.calendar = calendar
            schedule(
                id: dailyReminderID,
                title: title,
                body: "A quiet nudge — have you checked in today?",
                dateComponents: rem,
                calendar: calendar,
                repeats: true
            )
        }

        let c = calendar.dateComponents([.year, .month], from: now)
        guard let year = c.year, let month = c.month else { return }

        // End of month — last day at 20:00.
        if (d.object(forKey: SettingsKeys.monthlySummary) as? Bool) ?? true {
            let monthCount = CheckLogic.daysPassed(in: days, year: year, month: month)
            let lastDay = CheckLogic.lastDay(ofYear: year, month: month, calendar: calendar)
            var eom = DateComponents()
            eom.year = year; eom.month = month; eom.day = lastDay; eom.hour = 20; eom.minute = 0
            schedule(
                id: endOfMonthID,
                title: "\(calendar.monthSymbols[month - 1]) wrapped",
                body: "You passed \(monthCount) day\(monthCount == 1 ? "" : "s") this month.",
                dateComponents: eom,
                calendar: calendar
            )
        }

        // End of year — Dec 31 at 20:00.
        if (d.object(forKey: SettingsKeys.yearlySummary) as? Bool) ?? true {
            let yearCount = CheckLogic.daysPassed(in: days, year: year)
            let streak = CheckLogic.currentStreak(passed: days, calendar: calendar, asOf: now)
            var eoy = DateComponents()
            eoy.year = year; eoy.month = 12; eoy.day = 31; eoy.hour = 20; eoy.minute = 0
            schedule(
                id: endOfYearID,
                title: "\(year) recap",
                body: "\(yearCount) day\(yearCount == 1 ? "" : "s") passed this year. Current streak: \(streak).",
                dateComponents: eoy,
                calendar: calendar
            )
        }
    }

    private static func schedule(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        calendar: Calendar,
        repeats: Bool = false
    ) {
        var comps = dateComponents
        comps.calendar = calendar

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Lets notifications show as banners even while the app is in the foreground.
final class NotificationForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationForegroundDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
