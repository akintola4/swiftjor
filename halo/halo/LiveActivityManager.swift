//
//  LiveActivityManager.swift
//  halo
//
//  App target only. Starts / stops the Sun and Moon Live Activities from live
//  astronomy. State is frozen at start time (no push), so we re-arm on demand and
//  the built-in timer text keeps the countdown current until the target passes.
//

import ActivityKit
import Foundation

enum HaloLiveActivityManager {
    // MARK: Sun — daylight countdown

    /// Track the Sun on the Lock Screen: to sunset while it's up, else to the next
    /// sunrise. Returns whether an activity is now running.
    @discardableResult
    static func startSun(place: LocationSnapshot, now: Date = Date()) -> Bool {
        let lat = place.latitude, lon = place.longitude
        let d = Solar.daylight(at: now, latitude: lat, longitude: lon)
        let today = Solar.times(on: now, latitude: lat, longitude: lon)

        let state: HaloActivityAttributes.ContentState
        switch d.phase {
        case .daytime:
            guard let sr = today.sunrise, let ss = today.sunset else { return false }
            state = .init(start: sr, target: ss, headline: "Daylight left",
                          caption: "Sunset \(hm(ss))", illumination: 0, waxing: true)
        case .beforeDawn:
            guard let sr = today.sunrise else { return false }
            let start = today.sunset.map { $0.addingTimeInterval(-86_400) } ?? now
            state = .init(start: start, target: sr, headline: "Until sunrise",
                          caption: "Sunrise \(hm(sr))", illumination: 0, waxing: true)
        case .afterDusk:
            let tomorrow = Solar.times(on: now.addingTimeInterval(86_400), latitude: lat, longitude: lon)
            guard let nextSunrise = tomorrow.sunrise else { return false }
            let start = today.sunset ?? now
            state = .init(start: start, target: nextSunrise, headline: "Until sunrise",
                          caption: "Sunrise \(hm(nextSunrise))", illumination: 0, waxing: true)
        case .polarDay, .polarNight:
            return false   // no meaningful countdown
        }

        let attrs = HaloActivityAttributes(face: .sun, symbol: "sun.max.fill", place: place.name)
        return request(attrs, state)
    }

    // MARK: Moon — next full moon

    @discardableResult
    static func startMoon(now: Date = Date()) -> Bool {
        let target = Lunar.nextFullMoon(after: now)
        let start = target.addingTimeInterval(-Lunar.synodicMonth * 86_400)
        let state = HaloActivityAttributes.ContentState(
            start: start, target: target, headline: "Full Moon",
            caption: target.formatted(date: .abbreviated, time: .omitted),
            illumination: Lunar.illumination(now), waxing: Lunar.isWaxing(now),
            phaseFraction: Lunar.phaseFraction(now))
        let attrs = HaloActivityAttributes(face: .moon, symbol: "moon.stars.fill", place: "")
        return request(attrs, state)
    }

    // MARK: Lifecycle

    static func isActive(_ face: HaloFace) -> Bool {
        Activity<HaloActivityAttributes>.activities.contains {
            $0.attributes.face == face && $0.activityState == .active
        }
    }

    static func stop(_ face: HaloFace) {
        Task {
            for activity in Activity<HaloActivityAttributes>.activities where activity.attributes.face == face {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: Plumbing

    @discardableResult
    private static func request(_ attrs: HaloActivityAttributes,
                                _ state: HaloActivityAttributes.ContentState) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        // Snapshot any existing activity for this face BEFORE creating the new one, so
        // retiring the old ones can't race (and kill) the fresh request.
        let stale = Activity<HaloActivityAttributes>.activities.filter { $0.attributes.face == attrs.face }
        do {
            _ = try Activity.request(attributes: attrs,
                                     content: .init(state: state, staleDate: state.target.addingTimeInterval(3600)))
        } catch {
            return false
        }
        Task { for activity in stale { await activity.end(nil, dismissalPolicy: .immediate) } }
        return true
    }

    private static func hm(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
