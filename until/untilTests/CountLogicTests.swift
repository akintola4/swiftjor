//
//  CountLogicTests.swift
//  untilTests
//
//  OPTIONAL: requires a Unit Testing Bundle target. The pure logic in
//  UntilShared.swift (CountLogic / EventStore) was also verified by running the
//  app on the simulator. To run these: add a "Unit Testing Bundle" target named
//  `untilTests`, and make UntilShared.swift a member of that test target too.
//

import Testing
import Foundation
@testable import until

private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: day, hour: h, minute: min))!
}

private func event(mode: EventMode, date: Date, includeTime: Bool = false, record: Double = 0) -> UntilEvent {
    UntilEvent(title: "T", mode: mode, date: date, includeTime: includeTime,
               recordSeconds: record, createdAt: d(2026, 1, 1))
}

@Suite("Countdown readouts")
struct UntilReadouts {
    @Test func daysUntil() {
        let r = CountLogic.readout(for: event(mode: .until, date: d(2026, 6, 15)), now: d(2026, 6, 5), calendar: utc)
        #expect(r.big == "10")
        #expect(r.unit == "days until")
        #expect(r.reached == false)
    }

    @Test func oneDayIsSingular() {
        let r = CountLogic.readout(for: event(mode: .until, date: d(2026, 6, 6)), now: d(2026, 6, 5), calendar: utc)
        #expect(r.big == "1")
        #expect(r.unit == "day until")
    }

    @Test func farDateBreaksDownToMonths() {
        // 2026-06-29 → 2027-01-01 is 6 months, 3 days.
        let r = CountLogic.readout(for: event(mode: .until, date: d(2027, 1, 1)), now: d(2026, 6, 29), calendar: utc)
        #expect(r.big == "6")
        #expect(r.unit == "months until")
    }

    @Test func reachedTodayReadsToday() {
        let r = CountLogic.readout(for: event(mode: .until, date: d(2026, 6, 5)), now: d(2026, 6, 5, 10), calendar: utc)
        #expect(r.big == "Today")
        #expect(r.reached)
    }

    @Test func pastTargetCountsDaysAgo() {
        let r = CountLogic.readout(for: event(mode: .until, date: d(2026, 6, 1)), now: d(2026, 6, 5), calendar: utc)
        #expect(r.big == "4")
        #expect(r.unit == "days ago")
        #expect(r.reached)
    }
}

@Suite("Count-up readouts")
struct SinceReadouts {
    @Test func daysSince() {
        let r = CountLogic.readout(for: event(mode: .since, date: d(2026, 6, 1)), now: d(2026, 6, 6), calendar: utc)
        #expect(r.big == "5")
        #expect(r.unit == "days since")
    }

    @Test func subDayShowsHoursWhenTimed() {
        let e = event(mode: .since, date: d(2026, 6, 6, 8, 0), includeTime: true)
        let r = CountLogic.readout(for: e, now: d(2026, 6, 6, 9, 30), calendar: utc)
        #expect(r.big == "1")
        #expect(r.unit == "hour since")
    }
}

@Suite("Progress and duration")
struct ProgressTests {
    @Test func untilProgressIsHalfwayAtMidpoint() {
        let e = UntilEvent(title: "T", mode: .until, date: d(2026, 1, 11), createdAt: d(2026, 1, 1))
        #expect(abs(CountLogic.progress(for: e, now: d(2026, 1, 6)) - 0.5) < 0.01)
    }

    @Test func sinceProgressIsRunOverRecord() {
        let e = event(mode: .since, date: d(2026, 6, 6), includeTime: true, record: 2 * 86_400)
        #expect(abs(CountLogic.progress(for: e, now: d(2026, 6, 7)) - 0.5) < 0.01)
    }

    @Test func durationTextReadsNaturally() {
        #expect(CountLogic.durationText(14 * 86_400) == "14 days")
        #expect(CountLogic.durationText(86_400) == "1 day")
    }
}

@Suite("Recurrence")
struct RecurrenceTests {
    private func recurring(_ rule: RecurrenceRule) -> UntilEvent {
        UntilEvent(title: "Payday", mode: .until, date: d(2026, 1, 1),
                   createdAt: d(2026, 1, 1), recurrence: rule)
    }

    @Test func monthlyDayFindsThisMonth() {
        let next = RecurrenceRule.monthlyDay(day: 25).nextOccurrence(onOrAfter: d(2026, 6, 5), calendar: utc)
        #expect(next == d(2026, 6, 25))
    }

    @Test func monthlyDayRollsToNextMonthWhenPast() {
        let next = RecurrenceRule.monthlyDay(day: 25).nextOccurrence(onOrAfter: d(2026, 6, 26), calendar: utc)
        #expect(next == d(2026, 7, 25))
    }

    @Test func monthlyDay31ClampsToFebEnd() {
        // 2026 is not a leap year → Feb has 28 days.
        let next = RecurrenceRule.monthlyDay(day: 31).nextOccurrence(onOrAfter: d(2026, 2, 1), calendar: utc)
        #expect(next == d(2026, 2, 28))
    }

    @Test func biweeklyLandsOnAnchorPlusMultiplesOf14() {
        let rule = RecurrenceRule.everyNWeeks(n: 2, anchor: d(2026, 6, 5))
        #expect(rule.nextOccurrence(onOrAfter: d(2026, 6, 5), calendar: utc) == d(2026, 6, 5))
        #expect(rule.nextOccurrence(onOrAfter: d(2026, 6, 6), calendar: utc) == d(2026, 6, 19))
        #expect(rule.nextOccurrence(onOrAfter: d(2026, 6, 20), calendar: utc) == d(2026, 7, 3))
    }

    @Test func lastFridayOfJune2026() {
        // June 2026: last Friday is the 26th (Fridays fall on 5, 12, 19, 26).
        let next = RecurrenceRule.lastWeekdayOfMonth(weekday: 6).nextOccurrence(onOrAfter: d(2026, 6, 1), calendar: utc)
        #expect(next == d(2026, 6, 26))
    }

    @Test func recurringRollsForwardInsteadOfShowingDaysAgo() {
        // Even well past a nominal target, a recurring event reads a positive count.
        let e = recurring(.monthlyDay(day: 25))
        let r = CountLogic.readout(for: e, now: d(2026, 7, 1, 9), calendar: utc)
        #expect(r.big == "24")          // Jul 1 → Jul 25
        #expect(r.unit == "days until")
        #expect(r.reached == false)
    }

    @Test func previousOccurrenceBoundsTheProgressPeriod() {
        let rule = RecurrenceRule.everyNWeeks(n: 2, anchor: d(2026, 6, 5))
        let next = d(2026, 6, 19)
        #expect(rule.previousOccurrence(before: next, calendar: utc) == d(2026, 6, 5))
    }
}

@Suite("Reset banks the record")
struct ResetTests {
    @Test func resetUpdatesRecordAndAnchor() {
        let suite = UserDefaults(suiteName: "test.until.\(UUID().uuidString)")!
        let e = event(mode: .since, date: d(2026, 6, 1), includeTime: true)
        EventStore.saveEvents([e], to: suite)

        let now = d(2026, 6, 4) // a 3-day run
        let updated = EventStore.resetSince(id: e.id, now: now, from: suite)

        #expect(updated.first?.recordSeconds == 3 * 86_400)
        #expect(updated.first?.date == now)
    }
}
