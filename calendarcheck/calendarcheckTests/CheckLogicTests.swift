//
//  CheckLogicTests.swift
//  calendarcheckTests
//
//  OPTIONAL: requires a Unit Testing Bundle target. The pure logic in
//  CalendarCheckShared.swift (DayKey / CheckLogic) was also verified standalone.
//  To run: add a "Unit Testing Bundle" target named `calendarcheckTests`, then make
//  sure CalendarCheckShared.swift is a member of that test target too.
//

import Testing
import Foundation
@testable import calendarcheck

private var utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d))!
}
private func key(_ y: Int, _ m: Int, _ d: Int) -> DayKey {
    DayKey(year: y, month: m, day: d)
}

@Suite("Streak logic")
struct StreakTests {
    @Test func emptyIsZero() {
        #expect(CheckLogic.currentStreak(passed: [], calendar: utc, asOf: date(2026, 6, 4)) == 0)
    }

    @Test func runEndingToday() {
        let days: Set<DayKey> = [key(2026, 6, 2), key(2026, 6, 3), key(2026, 6, 4)]
        #expect(CheckLogic.currentStreak(passed: days, calendar: utc, asOf: date(2026, 6, 4)) == 3)
    }

    @Test func runEndingYesterdayWhenTodayMissing() {
        let days: Set<DayKey> = [key(2026, 6, 2), key(2026, 6, 3)]
        #expect(CheckLogic.currentStreak(passed: days, calendar: utc, asOf: date(2026, 6, 4)) == 2)
    }

    @Test func gapBreaksStreak() {
        let days: Set<DayKey> = [key(2026, 6, 1)]
        #expect(CheckLogic.currentStreak(passed: days, calendar: utc, asOf: date(2026, 6, 4)) == 0)
    }

    @Test func onlyCountsTailEndingToday() {
        let days: Set<DayKey> = [key(2026, 6, 1), key(2026, 6, 3), key(2026, 6, 4)]
        #expect(CheckLogic.currentStreak(passed: days, calendar: utc, asOf: date(2026, 6, 4)) == 2)
    }

    @Test func spansMonthBoundary() {
        let days: Set<DayKey> = [key(2026, 5, 31), key(2026, 6, 1), key(2026, 6, 2)]
        #expect(CheckLogic.currentStreak(passed: days, calendar: utc, asOf: date(2026, 6, 2)) == 3)
    }

    @Test func spansYearBoundary() {
        let days: Set<DayKey> = [key(2025, 12, 30), key(2025, 12, 31), key(2026, 1, 1)]
        #expect(CheckLogic.currentStreak(passed: days, calendar: utc, asOf: date(2026, 1, 1)) == 3)
    }
}

@Suite("Counts and month length")
struct CountTests {
    @Test func daysPassedInMonthFilters() {
        let days: Set<DayKey> = [key(2026, 6, 1), key(2026, 6, 9), key(2026, 7, 1)]
        #expect(CheckLogic.daysPassed(in: days, year: 2026, month: 6) == 2)
        #expect(CheckLogic.daysPassed(in: days, year: 2026) == 3)
    }

    @Test func lastDayOfMonth() {
        #expect(CheckLogic.lastDay(ofYear: 2024, month: 2, calendar: utc) == 29) // leap
        #expect(CheckLogic.lastDay(ofYear: 2026, month: 2, calendar: utc) == 28)
        #expect(CheckLogic.lastDay(ofYear: 2026, month: 4, calendar: utc) == 30)
        #expect(CheckLogic.lastDay(ofYear: 2026, month: 12, calendar: utc) == 31)
    }
}

@Suite("Persistence round-trip")
struct PersistenceTests {
    @Test func daysRoundTrip() throws {
        let suite = try #require(UserDefaults(suiteName: "test.calendarcheck.\(UUID().uuidString)"))
        let days: Set<DayKey> = [key(2026, 6, 1), key(2026, 6, 2)]
        CheckPersistence.saveDays(days, to: suite)
        #expect(CheckPersistence.loadDays(from: suite) == days)
    }

    @Test func titleRoundTripWithDefault() throws {
        let suite = try #require(UserDefaults(suiteName: "test.calendarcheck.\(UUID().uuidString)"))
        #expect(CheckPersistence.loadTitle(from: suite) == CheckPersistence.defaultTitle)
        CheckPersistence.saveTitle("Meditate", to: suite)
        #expect(CheckPersistence.loadTitle(from: suite) == "Meditate")
    }
}
