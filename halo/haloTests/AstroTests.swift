//
//  AstroTests.swift
//  haloTests
//
//  OPTIONAL: requires a Unit Testing Bundle target with AstroShared.swift as a member.
//  These assert the astronomy against known almanac values — the key safeguard, since
//  a wrong formula fails silently. (Also verified via a standalone script during dev.)
//

import Testing
import Foundation
@testable import halo

private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()
private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: day, hour: h, minute: min))!
}

@Suite("Sun")
struct SunTests {
    @Test func londonEquinoxIsAboutTwelveHours() {
        let t = Solar.times(on: d(2026, 3, 20), latitude: 51.5074, longitude: -0.1278)
        #expect(abs(t.dayLength - 12 * 3600) < 20 * 60)
    }

    @Test func londonSolsticeIsLong() {
        let t = Solar.times(on: d(2026, 6, 21), latitude: 51.5074, longitude: -0.1278)
        #expect(t.dayLength > 16 * 3600 && t.dayLength < 17 * 3600)
        #expect(t.sunrise! < t.solarNoon)
        #expect(t.solarNoon < t.sunset!)
    }

    @Test func londonMidwinterIsShort() {
        let t = Solar.times(on: d(2026, 12, 21), latitude: 51.5074, longitude: -0.1278)
        #expect(t.dayLength > 7 * 3600 && t.dayLength < 8.5 * 3600)
    }

    @Test func equatorIsAlwaysAboutTwelveHours() {
        let t = Solar.times(on: d(2026, 6, 21), latitude: 0, longitude: 0)
        #expect(abs(t.dayLength - 12 * 3600) < 15 * 60)
    }

    @Test func polesFlipWithSeason() {
        #expect(Solar.times(on: d(2026, 6, 21), latitude: 89.9, longitude: 0).condition == .polarDay)
        #expect(Solar.times(on: d(2026, 12, 21), latitude: 89.9, longitude: 0).condition == .polarNight)
    }

    @Test func daylightBeforeDawnCountsToSunrise() {
        // 02:00 UTC on a London summer day is before the ~03:43 sunrise.
        let dl = Solar.daylight(at: d(2026, 6, 21, 2, 0), latitude: 51.5074, longitude: -0.1278)
        #expect(dl.phase == .beforeDawn)
        #expect(dl.remaining > 0)
    }
}

@Suite("Moon")
struct MoonTests {
    @Test func fullMoonIsFullyLit() {
        // 2000-01-21 total lunar eclipse; 2024-01-25 full moon.
        #expect(Lunar.illumination(d(2000, 1, 21, 4, 40)) > 0.98)
        #expect(Lunar.illumination(d(2024, 1, 25, 17, 54)) > 0.97)
    }

    @Test func newMoonIsDark() {
        #expect(Lunar.illumination(d(2000, 1, 6, 18, 14)) < 0.02)
        #expect(Lunar.illumination(d(2024, 1, 11, 11, 57)) < 0.03)
    }

    @Test func nextFullMoonIsInTheFuture() {
        let now = d(2026, 1, 1)
        #expect(Lunar.nextFullMoon(after: now) > now)
    }
}
