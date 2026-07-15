//
//  NotificationScheduler.swift
//  until
//
//  App target ONLY. Local notifications need no entitlement — just runtime auth,
//  so this works under free personal-team signing. A calendar trigger freezes its
//  body when scheduled, so we schedule the *next* occurrence as a one-shot and
//  re-arm on every launch + mutation (mirrors calendarcheck's scheduler).
//

import Foundation
import UserNotifications

enum UntilNotificationScheduler {
    private static let prefix = "until.reminder."

    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationForegroundDelegate.shared
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Rebuild all pending reminders from the current event list. Only recurring
    /// events with `reminder == true` schedule anything.
    static func reschedule(
        events: [UntilEvent],
        defaults: UserDefaults = EventStore.shared,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        let center = UNUserNotificationCenter.current()
        // until schedules no other notifications, so clearing all is safe and simplest.
        center.removeAllPendingNotificationRequests()

        let recurringReminders = events.filter { $0.isRecurring && $0.reminder }
        let milestoneEvents = events.filter { $0.milestoneAlerts && $0.mode == .until }
        guard !recurringReminders.isEmpty || !milestoneEvents.isEmpty else { return }

        // A reminder is a user-visible commitment — make sure we're authorized.
        requestAuthorization()

        let hour = (defaults.object(forKey: SettingsKeys.reminderHour) as? Int) ?? 9

        // Day-of reminders for recurring events.
        for event in recurringReminders {
            guard let fireDate = nextFireDate(for: event, hour: hour, calendar: calendar, now: now) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            comps.calendar = calendar

            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = "Today's the day."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: prefix + event.id.uuidString, content: content, trigger: trigger)
            center.add(request)
        }

        // Milestone alerts counting down to the target.
        let milestones = [100, 30, 14, 7, 3, 1, 0]
        for event in milestoneEvents {
            let targetDay = calendar.startOfDay(for: event.effectiveTarget(now: now, calendar: calendar))
            for d in milestones {
                if d == 0 && event.isRecurring && event.reminder { continue }   // avoid duplicate "today"
                guard let day = calendar.date(byAdding: .day, value: -d, to: targetDay) else { continue }
                var comps = calendar.dateComponents([.year, .month, .day], from: day)
                comps.hour = hour; comps.minute = 0; comps.calendar = calendar
                guard let fire = calendar.date(from: comps), fire > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body = milestoneBody(daysBefore: d)
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "\(prefix)\(event.id.uuidString)-m\(d)",
                                                 content: content, trigger: trigger))
            }
        }
    }

    private static func milestoneBody(daysBefore d: Int) -> String {
        switch d {
        case 0:  return "Today's the day!"
        case 1:  return "Just 1 day to go."
        case 7:  return "One week to go."
        case 14: return "Two weeks to go."
        default: return "\(d) days to go."
        }
    }

    /// The next occurrence at `hour:00` that is still in the future. If today's
    /// occurrence hour has already passed, roll to the following occurrence.
    private static func nextFireDate(for event: UntilEvent, hour: Int, calendar: Calendar, now: Date) -> Date? {
        guard var occ = event.recurrence.nextOccurrence(onOrAfter: now, calendar: calendar) else { return nil }
        func at(_ day: Date) -> Date? {
            var c = calendar.dateComponents([.year, .month, .day], from: day)
            c.hour = hour; c.minute = 0
            return calendar.date(from: c)
        }
        if let fire = at(occ), fire > now { return fire }
        // Today's fire time already passed — step to the next occurrence.
        if let dayAfter = calendar.date(byAdding: .day, value: 1, to: occ),
           let next = event.recurrence.nextOccurrence(onOrAfter: dayAfter, calendar: calendar) {
            occ = next
        }
        return at(occ)
    }
}

/// Lets a reminder show as a banner even while the app is foregrounded.
final class NotificationForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationForegroundDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
