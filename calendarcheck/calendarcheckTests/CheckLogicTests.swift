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

@Suite("Longest streak and runs")
struct RunTests {
    // Runs of length 3, 1, 2 (by date order): Jun 1-3, Jun 5, Jun 8-9.
    private var mixed: Set<DayKey> {
        [key(2026, 6, 1), key(2026, 6, 2), key(2026, 6, 3),
         key(2026, 6, 5),
         key(2026, 6, 8), key(2026, 6, 9)]
    }

    @Test func longestPicksTheBiggestRun() {
        #expect(CheckLogic.longestStreak(passed: mixed, calendar: utc) == 3)
    }

    @Test func longestEmptyIsZero() {
        #expect(CheckLogic.longestStreak(passed: [], calendar: utc) == 0)
    }

    @Test func allStreaksListsEveryRunInDateOrder() {
        #expect(CheckLogic.allStreaks(passed: mixed, calendar: utc) == [3, 1, 2])
    }

    @Test func allStreaksEmptyIsEmpty() {
        #expect(CheckLogic.allStreaks(passed: [], calendar: utc).isEmpty)
    }

    @Test func runsSpanMonthBoundary() {
        // May 30, 31, Jun 1 = one run of 3.
        let days: Set<DayKey> = [key(2026, 5, 30), key(2026, 5, 31), key(2026, 6, 1)]
        #expect(CheckLogic.allStreaks(passed: days, calendar: utc) == [3])
        #expect(CheckLogic.longestStreak(passed: days, calendar: utc) == 3)
    }
}

@Suite("Milestone hits")
struct MilestoneTests {
    /// A single 100-day run from Jan 1.
    private var hundredRun: Set<DayKey> {
        var s = Set<DayKey>()
        var d = date(2026, 1, 1)
        for _ in 0..<100 { s.insert(DayKey(date: d, calendar: utc)); d = utc.date(byAdding: .day, value: 1, to: d)! }
        return s
    }

    @Test func longerRunCountsTowardEveryLowerTier() {
        // Documents the cumulative >= behavior: one 100-day run satisfies 7, 30, and 100.
        #expect(CheckLogic.milestoneHits(7, passed: hundredRun, calendar: utc) == 1)
        #expect(CheckLogic.milestoneHits(30, passed: hundredRun, calendar: utc) == 1)
        #expect(CheckLogic.milestoneHits(100, passed: hundredRun, calendar: utc) == 1)
        #expect(CheckLogic.milestoneHits(365, passed: hundredRun, calendar: utc) == 0)
    }

    @Test func separateRunsEachCount() {
        // Two distinct 7-day runs, separated by a gap.
        var s = Set<DayKey>()
        for d in 1...7 { s.insert(key(2026, 6, d)) }
        for d in 10...16 { s.insert(key(2026, 6, d)) }
        #expect(CheckLogic.milestoneHits(7, passed: s, calendar: utc) == 2)
        #expect(CheckLogic.milestoneHits(30, passed: s, calendar: utc) == 0)
    }

    @Test func shortRunHitsNothing() {
        let days: Set<DayKey> = [key(2026, 6, 1), key(2026, 6, 2), key(2026, 6, 3)]
        #expect(CheckLogic.milestoneHits(7, passed: days, calendar: utc) == 0)
    }
}

@Suite("Best month")
struct BestMonthTests {
    @Test func picksMonthWithMostChecks() {
        let days: Set<DayKey> = [
            key(2026, 6, 1), key(2026, 6, 2), key(2026, 6, 3),
            key(2026, 7, 1),
        ]
        let best = CheckLogic.bestMonth(passed: days)
        #expect(best?.year == 2026)
        #expect(best?.month == 6)
        #expect(best?.count == 3)
    }

    @Test func emptyIsNil() {
        #expect(CheckLogic.bestMonth(passed: []) == nil)
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
