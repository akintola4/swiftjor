//
//  AstroShared.swift
//  halo
//
//  Shared between the app AND the widget extension.
//  IMPORTANT: Target Membership must be checked for BOTH `halo` and
//     `haloWidgetExtension`, or the widget build fails with "Cannot find … in scope".
//
//  Everything here is pure / side-effect-free (no @Observable, no CoreLocation) so
//  the widget's timeline provider can call it directly. All angles in degrees at the
//  API surface; trig internally in radians.
//

import SwiftUI
import ActivityKit

// MARK: - Angle helpers

private func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }
private func deg(_ radians: Double) -> Double { radians * 180 / .pi }
private func mod360(_ x: Double) -> Double {
    let r = x.truncatingRemainder(dividingBy: 360)
    return r < 0 ? r + 360 : r
}

/// A fixed UTC gregorian calendar — solar times are computed in absolute UTC
/// minutes, then rendered in the viewer's local zone automatically (Date is absolute).
private let utcCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

// MARK: - Julian date

enum Astro {
    /// JD of the Unix epoch (1970-01-01 00:00 UTC) is 2440587.5.
    static func julianDay(_ date: Date) -> Double { date.timeIntervalSince1970 / 86_400 + 2_440_587.5 }
    static func julianCentury(_ jd: Double) -> Double { (jd - 2_451_545.0) / 36_525.0 }
    static func date(fromJD jd: Double) -> Date { Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400) }
}

// MARK: - Sun (NOAA solar equations)

enum Solar {
    /// Sun's declination (deg) and the equation of time (minutes) for a Julian century.
    struct Position {
        let declination: Double
        let eqTime: Double
    }

    static func position(julianCentury T: Double) -> Position {
        let L0 = mod360(280.46646 + T * (36000.76983 + T * 0.0003032))          // geom mean longitude
        let M  = 357.52911 + T * (35999.05029 - 0.0001537 * T)                  // geom mean anomaly
        let e  = 0.016708634 - T * (0.000042037 + 0.0000001267 * T)             // eccentricity
        let C  = sin(rad(M)) * (1.914602 - T * (0.004817 + 0.000014 * T))
               + sin(rad(2 * M)) * (0.019993 - 0.000101 * T)
               + sin(rad(3 * M)) * 0.000289                                     // equation of center
        let trueLong = L0 + C
        let omega  = 125.04 - 1934.136 * T
        let lambda = trueLong - 0.00569 - 0.00478 * sin(rad(omega))             // apparent longitude
        let eps0 = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60
        let eps  = eps0 + 0.00256 * cos(rad(omega))                             // corrected obliquity
        let decl = deg(asin(sin(rad(eps)) * sin(rad(lambda))))
        let y = tan(rad(eps / 2)) * tan(rad(eps / 2))
        let eqTime = 4 * deg(y * sin(2 * rad(L0)) - 2 * e * sin(rad(M))
                     + 4 * e * y * sin(rad(M)) * cos(2 * rad(L0))
                     - 0.5 * y * y * sin(4 * rad(L0)) - 1.25 * e * e * sin(2 * rad(M)))
        return Position(declination: decl, eqTime: eqTime)
    }

    /// Minutes-past-UTC-midnight of the morning/evening crossings of elevation `h`.
    /// Nil when the sun never reaches `h` on this day (polar case).
    private static func crossingMinutes(elevation h: Double, lat: Double, lon: Double, pos: Position)
        -> (morning: Double, evening: Double)? {
        let cosH = (sin(rad(h)) - sin(rad(lat)) * sin(rad(pos.declination)))
                 / (cos(rad(lat)) * cos(rad(pos.declination)))
        guard cosH <= 1, cosH >= -1 else { return nil }
        let H = deg(acos(cosH))
        let noon = 720.0 - 4.0 * lon - pos.eqTime          // lon east-positive
        return (noon - 4 * H, noon + 4 * H)
    }

    enum DayCondition { case normal, polarDay, polarNight }

    /// Everything the Sun face needs for one calendar day at a location.
    struct Times {
        let sunrise: Date?
        let sunset: Date?
        let solarNoon: Date
        let goldenMorningStart: Date?      // sun at -4° rising
        let goldenMorningEnd: Date?        // sun at +6° rising
        let goldenEveningStart: Date?      // sun at +6° setting
        let goldenEveningEnd: Date?        // sun at -4° setting
        let dayLength: TimeInterval        // 0 on polar night, 86400 on polar day
        let condition: DayCondition
    }

    static func times(on day: Date, latitude lat: Double, longitude lon: Double) -> Times {
        let midnightUTC = utcCal.startOfDay(for: day)
        let jdNoon = Astro.julianDay(midnightUTC.addingTimeInterval(12 * 3600))
        let pos = position(julianCentury: Astro.julianCentury(jdNoon))
        func at(_ minutes: Double) -> Date { midnightUTC.addingTimeInterval(minutes * 60) }

        let solarNoonMin = 720.0 - 4.0 * lon - pos.eqTime
        let solarNoon = at(solarNoonMin)

        let rise = crossingMinutes(elevation: -0.833, lat: lat, lon: lon, pos: pos)
        let condition: DayCondition
        if rise == nil {
            // Exact elevation at solar noon = 90 − |lat − declination|.
            let noonElevation = 90 - abs(lat - pos.declination)
            condition = noonElevation > -0.833 ? .polarDay : .polarNight
        } else {
            condition = .normal
        }

        let sunrise = rise.map { at($0.morning) }
        let sunset  = rise.map { at($0.evening) }
        let dayLength: TimeInterval = {
            if let sr = sunrise, let ss = sunset { return ss.timeIntervalSince(sr) }
            return condition == .polarDay ? 86_400 : 0
        }()

        let g6  = crossingMinutes(elevation: 6,  lat: lat, lon: lon, pos: pos)
        let gm4 = crossingMinutes(elevation: -4, lat: lat, lon: lon, pos: pos)

        return Times(
            sunrise: sunrise,
            sunset: sunset,
            solarNoon: solarNoon,
            goldenMorningStart: gm4.map { at($0.morning) },
            goldenMorningEnd: g6.map { at($0.morning) },
            goldenEveningStart: g6.map { at($0.evening) },
            goldenEveningEnd: gm4.map { at($0.evening) },
            dayLength: dayLength,
            condition: condition
        )
    }

    /// The sun's current elevation (deg) — drives the sky gradient and the arc marker.
    static func elevation(at now: Date, latitude lat: Double, longitude lon: Double) -> Double {
        let midnight = utcCal.startOfDay(for: now)
        let pos = position(julianCentury: Astro.julianCentury(Astro.julianDay(now)))
        let minutesUTC = now.timeIntervalSince(midnight) / 60
        let tst = (minutesUTC + pos.eqTime + 4 * lon).truncatingRemainder(dividingBy: 1440)
        let ha = tst / 4 - 180
        let cosZenith = sin(rad(lat)) * sin(rad(pos.declination))
                      + cos(rad(lat)) * cos(rad(pos.declination)) * cos(rad(ha))
        return 90 - deg(acos(min(1, max(-1, cosZenith))))
    }

    // MARK: Daylight countdown

    struct Daylight {
        enum Phase { case beforeDawn, daytime, afterDusk, polarDay, polarNight }
        let phase: Phase
        let remaining: TimeInterval    // to sunset (daytime), else to the next sunrise
        let dayLength: TimeInterval
        let progress: Double           // 0…1 fraction of daylight elapsed
    }

    static func daylight(at now: Date, latitude lat: Double, longitude lon: Double) -> Daylight {
        let today = times(on: now, latitude: lat, longitude: lon)
        switch today.condition {
        case .polarDay:
            return Daylight(phase: .polarDay, remaining: 0, dayLength: 86_400, progress: 1)
        case .polarNight:
            return Daylight(phase: .polarNight, remaining: 0, dayLength: 0, progress: 0)
        case .normal:
            guard let sr = today.sunrise, let ss = today.sunset else {
                return Daylight(phase: .polarNight, remaining: 0, dayLength: 0, progress: 0)
            }
            if now < sr {
                return Daylight(phase: .beforeDawn, remaining: sr.timeIntervalSince(now),
                                dayLength: today.dayLength, progress: 0)
            }
            if now < ss {
                let elapsed = now.timeIntervalSince(sr)
                return Daylight(phase: .daytime, remaining: ss.timeIntervalSince(now),
                                dayLength: today.dayLength,
                                progress: today.dayLength > 0 ? min(1, elapsed / today.dayLength) : 0)
            }
            let tomorrow = times(on: now.addingTimeInterval(86_400), latitude: lat, longitude: lon)
            let nextSunrise = tomorrow.sunrise ?? sr.addingTimeInterval(86_400)
            return Daylight(phase: .afterDusk, remaining: nextSunrise.timeIntervalSince(now),
                            dayLength: today.dayLength, progress: 1)
        }
    }
}

// MARK: - Moon (synodic model)

enum Lunar {
    static let synodicMonth = 29.530588853
    static let knownNewMoonJD = 2_451_550.1        // 2000-01-06 18:14 UTC, a reference new moon

    /// Days since the last new moon, in [0, synodicMonth).
    static func age(_ date: Date) -> Double {
        let a = (Astro.julianDay(date) - knownNewMoonJD).truncatingRemainder(dividingBy: synodicMonth)
        return a < 0 ? a + synodicMonth : a
    }

    /// Cycle position: 0 = new, ~0.5 = full, →1 back to new.
    static func phaseFraction(_ date: Date) -> Double { age(date) / synodicMonth }

    /// Illuminated fraction of the disc, 0…1.
    static func illumination(_ date: Date) -> Double { (1 - cos(2 * .pi * phaseFraction(date))) / 2 }

    static func isWaxing(_ date: Date) -> Bool { phaseFraction(date) < 0.5 }

    static func phaseName(_ date: Date) -> String {
        switch phaseFraction(date) {
        case ..<0.02:  return "New Moon"
        case ..<0.24:  return "Waxing Crescent"
        case ..<0.26:  return "First Quarter"
        case ..<0.48:  return "Waxing Gibbous"
        case ..<0.52:  return "Full Moon"
        case ..<0.74:  return "Waning Gibbous"
        case ..<0.76:  return "Last Quarter"
        case ..<0.98:  return "Waning Crescent"
        default:       return "New Moon"
        }
    }

    /// SF Symbol for the current phase (monochrome-friendly, scales cleanly).
    static func symbolName(_ date: Date) -> String {
        switch phaseFraction(date) {
        case ..<0.02:  return "moonphase.new.moon"
        case ..<0.24:  return "moonphase.waxing.crescent"
        case ..<0.26:  return "moonphase.first.quarter"
        case ..<0.48:  return "moonphase.waxing.gibbous"
        case ..<0.52:  return "moonphase.full.moon"
        case ..<0.74:  return "moonphase.waning.gibbous"
        case ..<0.76:  return "moonphase.last.quarter"
        case ..<0.98:  return "moonphase.waning.crescent"
        default:       return "moonphase.new.moon"
        }
    }

    static func nextNewMoon(after date: Date) -> Date {
        let n = ((Astro.julianDay(date) - knownNewMoonJD) / synodicMonth).rounded(.up)
        return Astro.date(fromJD: knownNewMoonJD + n * synodicMonth)
    }

    static func nextFullMoon(after date: Date) -> Date {
        let k = ((Astro.julianDay(date) - knownNewMoonJD) / synodicMonth - 0.5).rounded(.up)
        return Astro.date(fromJD: knownNewMoonJD + (k + 0.5) * synodicMonth)
    }

    // Accuracy note: the synodic model assumes uniform lunar motion, so the exact
    // full/new instant can be off by up to ~14h and illumination by a few percent —
    // invisible for a glyph + "Full in N days". A precise upgrade (Meeus ch. 49
    // periodic terms) can slot in behind nextFullMoon/nextNewMoon unchanged.

    /// Traditional full-moon name for the month it falls in (Farmer's Almanac).
    static func fullMoonName(for date: Date) -> String {
        let names = ["Wolf", "Snow", "Worm", "Pink", "Flower", "Strawberry",
                     "Buck", "Sturgeon", "Harvest", "Hunter", "Beaver", "Cold"]
        let mo = Calendar.current.component(.month, from: date)
        return names[((mo - 1) % 12 + 12) % 12] + " Moon"
    }
}

// MARK: - Sun: golden/blue hour + seasons

extension Solar {
    struct Window { let start: Date; let end: Date }
    struct GoldenBlue {
        var goldenMorning: Window?
        var goldenEvening: Window?
        var blueMorning: Window?
        var blueEvening: Window?
        var golden: [Window] { [goldenMorning, goldenEvening].compactMap { $0 } }
    }

    static func goldenBlue(on day: Date, latitude lat: Double, longitude lon: Double) -> GoldenBlue {
        let midnight = utcCal.startOfDay(for: day)
        let pos = position(julianCentury: Astro.julianCentury(Astro.julianDay(midnight.addingTimeInterval(12 * 3600))))
        func at(_ m: Double) -> Date { midnight.addingTimeInterval(m * 60) }
        // crossingMinutes is private but same-file extensions may use it.
        let c6  = crossing(6, lat, lon, pos)
        let cm4 = crossing(-4, lat, lon, pos)
        let cm6 = crossing(-6, lat, lon, pos)
        var gb = GoldenBlue()
        if let a = cm4, let b = c6 {
            gb.goldenMorning = Window(start: at(a.0), end: at(b.0))
            gb.goldenEvening = Window(start: at(b.1), end: at(a.1))
        }
        if let a = cm6, let b = cm4 {
            gb.blueMorning = Window(start: at(a.0), end: at(b.0))
            gb.blueEvening = Window(start: at(b.1), end: at(a.1))
        }
        return gb
    }

    // Small wrapper so the extension can reach the private crossing math cleanly.
    fileprivate static func crossing(_ h: Double, _ lat: Double, _ lon: Double, _ pos: Position) -> (Double, Double)? {
        crossingMinutes(elevation: h, lat: lat, lon: lon, pos: pos)
    }

    struct GoldenCountdown { enum Phase { case active, upcoming }; let phase: Phase; let window: Window }

    /// Whether golden hour is happening now (and when it ends), or the next one.
    static func nextGolden(at now: Date, latitude lat: Double, longitude lon: Double) -> GoldenCountdown? {
        let windows = (goldenBlue(on: now, latitude: lat, longitude: lon).golden
                     + goldenBlue(on: now.addingTimeInterval(86_400), latitude: lat, longitude: lon).golden)
            .sorted { $0.start < $1.start }
        if let active = windows.first(where: { $0.start <= now && now < $0.end }) {
            return GoldenCountdown(phase: .active, window: active)
        }
        if let next = windows.first(where: { $0.start > now }) {
            return GoldenCountdown(phase: .upcoming, window: next)
        }
        return nil
    }

    /// Sun's apparent ecliptic longitude (deg, 0…360) — 0=Mar equinox, 90=Jun solstice…
    static func apparentLongitude(_ date: Date) -> Double {
        let T = Astro.julianCentury(Astro.julianDay(date))
        let L0 = mod360(280.46646 + T * (36000.76983 + T * 0.0003032))
        let M  = 357.52911 + T * (35999.05029 - 0.0001537 * T)
        let C  = sin(rad(M)) * (1.914602 - T * (0.004817 + 0.000014 * T))
               + sin(rad(2 * M)) * (0.019993 - 0.000101 * T)
               + sin(rad(3 * M)) * 0.000289
        let omega = 125.04 - 1934.136 * T
        return mod360(L0 + C - 0.00569 - 0.00478 * sin(rad(omega)))
    }

    /// The next equinox/solstice after `now`, day-granular.
    static func nextSeason(after now: Date, calendar: Calendar = .current) -> (date: Date, name: String) {
        let names = [0: "March equinox", 90: "June solstice",
                     180: "September equinox", 270: "December solstice"]
        var d = calendar.startOfDay(for: now)
        let q0 = Int(apparentLongitude(d) / 90)
        for _ in 0..<400 {
            guard let n = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            let q = Int(apparentLongitude(n) / 90)
            if q != q0 { return (n, names[(q * 90) % 360] ?? "Season") }
            d = n
        }
        return (d, "Season")
    }
}

// MARK: - Moon: geocentric position + rise/set (Schlyter low-precision)

extension Lunar {
    struct Equatorial { let ra: Double; let dec: Double }   // degrees

    static func position(_ date: Date) -> Equatorial {
        func m(_ x: Double) -> Double { let r = x.truncatingRemainder(dividingBy: 360); return r < 0 ? r + 360 : r }
        let d = Astro.julianDay(date) - 2_451_543.5
        let N = 125.1228 - 0.0529538083 * d, incl = 5.1454, w = 318.0634 + 0.1643573223 * d
        let a = 60.2666, e = 0.054900
        let M  = m(115.3654 + 13.0649929509 * d)
        let Ms = m(356.0470 + 0.9856002585 * d)
        let ws = 282.9404 + 4.70935e-5 * d
        let Ls = m(ws + Ms), Lm = m(N + w + M)
        let Dm = m(Lm - Ls), F = m(Lm - N)
        var E = M + deg(e * sin(rad(M)) * (1 + e * cos(rad(M))))
        for _ in 0..<5 { E = E - (E - deg(e * sin(rad(E))) - M) / (1 - e * cos(rad(E))) }
        let x = a * (cos(rad(E)) - e), y = a * sqrt(1 - e * e) * sin(rad(E))
        let r = sqrt(x * x + y * y), v = m(deg(atan2(y, x)))
        let xe = r * (cos(rad(N)) * cos(rad(v + w)) - sin(rad(N)) * sin(rad(v + w)) * cos(rad(incl)))
        let ye = r * (sin(rad(N)) * cos(rad(v + w)) + cos(rad(N)) * sin(rad(v + w)) * cos(rad(incl)))
        let ze = r * sin(rad(v + w)) * sin(rad(incl))
        var lon = m(deg(atan2(ye, xe)))
        var lat = deg(atan2(ze, sqrt(xe * xe + ye * ye)))
        lon += -1.274 * sin(rad(M - 2 * Dm)) + 0.658 * sin(rad(2 * Dm)) - 0.186 * sin(rad(Ms))
             - 0.059 * sin(rad(2 * M - 2 * Dm)) - 0.057 * sin(rad(M - 2 * Dm + Ms)) + 0.053 * sin(rad(M + 2 * Dm))
             + 0.046 * sin(rad(2 * Dm - Ms)) + 0.041 * sin(rad(M - Ms)) - 0.035 * sin(rad(Dm))
             - 0.031 * sin(rad(M + Ms)) - 0.015 * sin(rad(2 * F - 2 * Dm)) + 0.011 * sin(rad(M - 4 * Dm))
        lat += -0.173 * sin(rad(F - 2 * Dm)) - 0.055 * sin(rad(M - F - 2 * Dm)) - 0.046 * sin(rad(M + F - 2 * Dm))
             + 0.033 * sin(rad(F + 2 * Dm)) + 0.017 * sin(rad(2 * M + F))
        let ecl = 23.4393 - 3.563e-7 * d
        let xg = cos(rad(lon)) * cos(rad(lat)), yg = sin(rad(lon)) * cos(rad(lat)), zg = sin(rad(lat))
        let xq = xg, yq = yg * cos(rad(ecl)) - zg * sin(rad(ecl)), zq = yg * sin(rad(ecl)) + zg * cos(rad(ecl))
        return Equatorial(ra: m(deg(atan2(yq, xq))), dec: deg(atan2(zq, sqrt(xq * xq + yq * yq))))
    }

    static func altitude(at date: Date, latitude lat: Double, longitude lon: Double) -> Double {
        func m(_ x: Double) -> Double { let r = x.truncatingRemainder(dividingBy: 360); return r < 0 ? r + 360 : r }
        let eq = position(date)
        let d = Astro.julianDay(date) - 2_451_543.5
        let ws = 282.9404 + 4.70935e-5 * d, Ms = m(356.0470 + 0.9856002585 * d), Ls = m(ws + Ms)
        let gmst0 = m(Ls + 180)
        let ut = date.timeIntervalSince(utcCal.startOfDay(for: date)) / 3600
        let lst = m(gmst0 + ut * 15.0 + lon)
        var ha = lst - eq.ra; ha = (ha + 540).truncatingRemainder(dividingBy: 360) - 180
        return deg(asin(sin(rad(lat)) * sin(rad(eq.dec)) + cos(rad(lat)) * cos(rad(eq.dec)) * cos(rad(ha))))
    }

    /// Next moonrise and moonset within 24h of `now`. Target altitude 0.125° folds in
    /// mean parallax + refraction (Meeus). ~10-min accuracy — plenty for a glance.
    static func nextRiseSet(after now: Date, latitude lat: Double, longitude lon: Double) -> (rise: Date?, set: Date?) {
        let h0 = 0.125, step = 5.0
        var rise: Date?, set: Date?
        var prev = altitude(at: now, latitude: lat, longitude: lon) - h0
        func interp(_ t0: Double, _ t1: Double, _ a0: Double, _ a1: Double) -> Date {
            now.addingTimeInterval((t0 + (t1 - t0) * (a0 / (a0 - a1))) * 60)
        }
        var t = step
        while t <= 1440 + step {
            let alt = altitude(at: now.addingTimeInterval(t * 60), latitude: lat, longitude: lon) - h0
            if rise == nil, prev < 0, alt >= 0 { rise = interp(t - step, t, prev, alt) }
            if set == nil, prev >= 0, alt < 0 { set = interp(t - step, t, prev, alt) }
            if rise != nil, set != nil { break }
            prev = alt; t += step
        }
        return (rise, set)
    }
}

// MARK: - Sky gradient

enum SkyGradient {
    /// Top→bottom sky colors for a given solar elevation (deg). Low-saturation so it
    /// stays in the app's editorial register rather than going cartoonish.
    static func colors(forElevation elevation: Double) -> [Color] {
        switch elevation {
        case 12...:           // high day — vivid
            return [Color(red: 0.16, green: 0.45, blue: 0.82), Color(red: 0.44, green: 0.68, blue: 0.92),
                    Color(red: 0.74, green: 0.86, blue: 0.96)]
        case 6..<12:          // low day
            return [Color(red: 0.24, green: 0.52, blue: 0.84), Color(red: 0.53, green: 0.74, blue: 0.93),
                    Color(red: 0.90, green: 0.84, blue: 0.74)]
        case 0..<6:           // golden hour (sun up)
            return [Color(red: 0.32, green: 0.44, blue: 0.72), Color(red: 0.90, green: 0.58, blue: 0.38),
                    Color(red: 0.98, green: 0.78, blue: 0.52)]
        case -4..<0:          // sunset glow
            return [Color(red: 0.22, green: 0.26, blue: 0.52), Color(red: 0.78, green: 0.40, blue: 0.42),
                    Color(red: 0.96, green: 0.62, blue: 0.44)]
        case -6..<(-4):       // blue hour
            return [Color(red: 0.12, green: 0.16, blue: 0.40), Color(red: 0.34, green: 0.34, blue: 0.60),
                    Color(red: 0.58, green: 0.46, blue: 0.62)]
        case -18..<(-6):      // twilight
            return [Color(red: 0.06, green: 0.08, blue: 0.24), Color(red: 0.14, green: 0.16, blue: 0.36)]
        default:              // night
            return [Color(red: 0.03, green: 0.04, blue: 0.12), Color(red: 0.08, green: 0.09, blue: 0.20)]
        }
    }

    /// Legible text color on the sky at a given elevation (dark ink by day, white by night).
    static func ink(forElevation elevation: Double) -> Color {
        elevation > 8 ? Color(red: 0.10, green: 0.13, blue: 0.22) : .white
    }
}

// MARK: - Location cache (App-Group-ready; app-local under free signing)

struct LocationSnapshot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var name: String
    var savedAt: Date
}

/// The shared store for the app's last-known location. Uses the App Group suite when
/// present (paid signing), else falls back to `.standard` — in which case the widget
/// can't read it and the Sun face uses `fallback`. The Moon face needs no location.
enum LocationCache {
    static let appGroupID = "group.foster.halo"
    static let shared: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard
    private static let key = "locationSnapshot"

    static let fallback = LocationSnapshot(latitude: 51.5074, longitude: -0.1278,
                                           name: "London", savedAt: .distantPast)

    static func load(from defaults: UserDefaults = shared) -> LocationSnapshot? {
        guard let data = defaults.data(forKey: key),
              let snap = try? JSONDecoder().decode(LocationSnapshot.self, from: data) else { return nil }
        return snap
    }

    static func save(_ snapshot: LocationSnapshot, to defaults: UserDefaults = shared) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: - Moon disc (realistic terminator)

/// A believable moon: a lit disc with a true curved terminator derived from the
/// illumination fraction, faint craters, and a thin rim. Shared by app + widget.
///
/// Geometry: the terminator is a half-ellipse of x-radius `R·|1−2f|`. Painting the
/// lit disc, then the un-lit semicircle, then that ellipse (shadow for a crescent,
/// light for a gibbous) reproduces the exact illuminated *area* fraction `f`.
struct MoonDisc: View {
    var illumination: Double        // 0…1
    var waxing: Bool                // lit on the right when waxing, mirrored when waning
    var lit: Color = Color(red: 0.95, green: 0.94, blue: 0.89)      // warm silver-cream
    var shadow: Color = Color(red: 0.17, green: 0.19, blue: 0.28)   // muted navy earthshine

    // Fixed "craters" (unit disc coords) so the face is stable frame-to-frame.
    private static let craters: [(x: Double, y: Double, r: Double)] = [
        (-0.30, -0.28, 0.13), (0.24, -0.12, 0.10), (-0.08, 0.30, 0.16),
        (0.34, 0.26, 0.08), (0.06, -0.02, 0.07), (-0.44, 0.06, 0.06),
    ]

    var body: some View {
        Canvas { ctx, size in
            let R = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let f = min(1, max(0, illumination))
            let rx = R * abs(1 - 2 * f)

            let disc = Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
            ctx.clip(to: disc)

            if !waxing {                                  // mirror so the lit limb is on the left
                ctx.translateBy(x: size.width, y: 0)
                ctx.scaleBy(x: -1, y: 1)
            }

            ctx.fill(disc, with: .color(lit))             // 1. lit base

            var leftHalf = Path()                         // 2. un-lit (left) semicircle
            leftHalf.addArc(center: c, radius: R, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            leftHalf.closeSubpath()
            ctx.fill(leftHalf, with: .color(shadow))

            // 3. terminator ellipse: shadow carves a crescent, light fills a gibbous
            let ellipse = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - R, width: 2 * rx, height: 2 * R))
            ctx.fill(ellipse, with: .color(f <= 0.5 ? shadow : lit))

            // 4. craters last, at low opacity: visible on the lit cream, imperceptible
            // over the near-matching navy shadow — so they show at full moon too.
            let craterColor = shadow.opacity(0.16)
            for cr in Self.craters {
                let rect = CGRect(x: c.x + cr.x * R - cr.r * R, y: c.y + cr.y * R - cr.r * R,
                                  width: cr.r * 2 * R, height: cr.r * 2 * R)
                ctx.fill(Path(ellipseIn: rect), with: .color(craterColor))
            }

            // 5. Earthshine — the "ashen glow" of Earth-lit night side. A soft cool
            // wash over the disc, strongest near new moon (fades to nothing by full),
            // so a thin crescent still reads as a whole sphere rather than a black dot.
            let ash = Color(red: 0.60, green: 0.68, blue: 0.86)
            let strength = 1 - f
            ctx.fill(disc, with: .radialGradient(
                Gradient(colors: [ash.opacity(0.24 * strength), ash.opacity(0.06 * strength), .clear]),
                center: c, startRadius: 0, endRadius: R * 1.05))
        }
        .aspectRatio(1, contentMode: .fit)
        // Rim light: a crisp edge so the sphere always separates from a dark sky,
        // brighter toward the upper-left as if catching the sun.
        .overlay(
            Circle().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.16)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1)
        )
    }
}

// MARK: - Live Activity signature visuals (shared by widget + app)

/// The sun riding its daily arc: a dashed horizon from sunrise (left) to sunset
/// (right), a bright filled segment up to the day's progress, and a glowing sun at
/// the current position. Sunrise/sunset labels sit under the endpoints.
struct SunArc: View {
    var progress: Double
    var tint: Color
    var startLabel: String
    var endLabel: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let inset: CGFloat = 6
            let baseY = geo.size.height - 20
            let t = min(1, max(0, progress))
            let sun = point(t, w: w, inset: inset, baseY: baseY)

            ZStack(alignment: .topLeading) {
                Path { p in p.move(to: CGPoint(x: 0, y: baseY)); p.addLine(to: CGPoint(x: w, y: baseY)) }
                    .stroke(tint.opacity(0.2), lineWidth: 1)

                arc(w: w, inset: inset, baseY: baseY, to: 1)
                    .stroke(tint.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [2, 5]))
                arc(w: w, inset: inset, baseY: baseY, to: t)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                Circle().fill(tint).frame(width: 11, height: 11)
                    .shadow(color: tint.opacity(0.9), radius: 6)
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1))
                    .position(sun)
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                Text(startLabel)
                Spacer(minLength: 8)
                Text(endLabel)
            }
            .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.bottom, 2)
        }
    }

    private func point(_ u: Double, w: CGFloat, inset: CGFloat, baseY: CGFloat) -> CGPoint {
        let x = inset + (w - 2 * inset) * u
        let rise = baseY - 4
        return CGPoint(x: x, y: baseY - sin(.pi * u) * rise)
    }

    private func arc(w: CGFloat, inset: CGFloat, baseY: CGFloat, to t: Double) -> Path {
        Path { p in
            guard t > 0 else { return }
            let steps = 48
            let last = min(steps, max(1, Int(Double(steps) * t)))
            for i in 0...last {
                let u = Double(i) / Double(steps)
                if u > t + 0.0001 { break }
                let pt = point(u, w: w, inset: inset, baseY: baseY)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
    }
}

/// A lunar-cycle strip: ticks at new / first-quarter / full / last-quarter, with a
/// glowing marker at tonight's position in the synodic month.
struct MoonPhaseTrack: View {
    var phaseFraction: Double        // 0 new · 0.5 full · 1 new
    var tint: Color
    var labeled = false

    private let ticks: [Double] = [0, 0.25, 0.5, 0.75, 1]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let midY = labeled ? 5.0 : geo.size.height / 2
            let f = min(1, max(0, phaseFraction))

            ZStack(alignment: .topLeading) {
                Capsule().fill(tint.opacity(0.22)).frame(width: w, height: 3).position(x: w / 2, y: midY)
                Capsule().fill(tint).frame(width: w * f, height: 3)
                    .position(x: w * f / 2, y: midY)

                ForEach(ticks, id: \.self) { v in
                    Circle().fill(tint.opacity(0.45)).frame(width: 4, height: 4)
                        .position(x: min(w - 2, max(2, w * v)), y: midY)
                }

                Circle().fill(tint).frame(width: 10, height: 10)
                    .shadow(color: tint.opacity(0.9), radius: 5)
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
                    .position(x: min(w - 5, max(5, w * f)), y: midY)
            }
        }
        .overlay(alignment: .bottom) {
            if labeled {
                HStack {
                    Text("NEW"); Spacer(); Text("FULL"); Spacer(); Text("NEW")
                }
                .font(.system(size: 8, weight: .bold)).tracking(0.5).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Settings keys

extension Bundle {
    /// "1.1.0 (5)" from the build settings — so the About screen never drifts.
    var displayVersion: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

enum SettingsKeys {
    static let appearance   = "appearance"
    static let useManualLoc = "useManualLocation"
    static let manualLat    = "manualLatitude"
    static let manualLon    = "manualLongitude"
    static let manualName   = "manualName"
}

// MARK: - Theme

enum Theme {
    /// SF Rounded display face — the app's only "voice" font, shared with the widget.
    static func display(_ style: Font.TextStyle) -> Font { .system(style, design: .rounded) }

    static let sun  = Color(red: 0.95, green: 0.62, blue: 0.07)   // amber
    static let moon = Color(red: 0.49, green: 0.51, blue: 0.78)   // soft indigo

    /// Compact "3h 12m" / "12m" / "45s" duration for countdowns.
    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600, m = (s % 3600) / 60
        if h >= 1 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        if m >= 1 { return "\(m)m" }
        return "\(s)s"
    }

    /// "in 3 days" / "in 12 days" from now to a future date (day-granular).
    static func daysAway(to date: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: now)
        let b = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: a, to: b).day ?? 0)
    }
}

// MARK: - Live Activity (Lock Screen + Dynamic Island)

/// Which face a Live Activity is tracking. Also the deep-link host (`halo://sun`).
enum HaloFace: String, Codable, Hashable {
    case sun, moon
    var tint: Color { self == .sun ? Theme.sun : Theme.moon }
    var url: URL? { URL(string: "halo://\(rawValue)") }
}

/// A self-updating Live Activity for the Sun (daylight → sunset countdown) or the
/// Moon (phase disc + days to the next full moon). No push: the target date is baked
/// in and `Text(timerInterval:)` / the day count tick on their own.
struct HaloActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var start: Date          // progress origin (sunrise / last full moon)
        var target: Date         // countdown target (sunset·sunrise / next full moon)
        var headline: String     // "Daylight left", "Until sunrise", "Full Moon"
        var caption: String      // "Sunset 20:41" / "Sat 9 Aug"
        var illumination: Double // moon only (0 for sun)
        var waxing: Bool
        var phaseFraction: Double = 0   // moon only: 0 new · 0.5 full · 1 new

        /// Elapsed fraction of the span, evaluated at render time (0…1).
        func progress(now: Date = Date()) -> Double {
            let total = target.timeIntervalSince(start)
            guard total > 0 else { return 1 }
            return min(1, max(0, now.timeIntervalSince(start) / total))
        }
    }

    var face: HaloFace
    var symbol: String
    var place: String
}
