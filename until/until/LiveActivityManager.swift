//
//  LiveActivityManager.swift
//  until
//
//  App target only. Starts/stops a Live Activity for a countdown. Local-only
//  (no push), so it works under free personal-team signing.
//

import ActivityKit
import Foundation

enum LiveActivityManager {
    static func isActive(_ id: UUID) -> Bool {
        Activity<UntilActivityAttributes>.activities.contains { $0.attributes.eventID == id }
    }

    @discardableResult
    static func start(_ event: UntilEvent, now: Date = Date()) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        stop(event.id)
        let attributes = UntilActivityAttributes(eventID: event.id, title: event.title,
                                                 symbol: event.symbol, accent: event.accent)
        let state = UntilActivityAttributes.ContentState(
            startDate: min(event.progressOrigin, now),   // never after "now", so the bar is valid
            targetDate: event.effectiveTarget(now: now),
            mode: event.mode
        )
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
            return true
        } catch {
            return false
        }
    }

    static func stop(_ id: UUID) {
        for activity in Activity<UntilActivityAttributes>.activities where activity.attributes.eventID == id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
