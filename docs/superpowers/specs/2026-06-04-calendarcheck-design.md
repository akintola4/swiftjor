# calendarcheck — Design Spec

**Date:** 2026-06-04
**Status:** Approved for planning

## Summary

A single-habit daily check tracker for iOS, built in SwiftUI. The user taps any day
on a calendar to mark it "passed" (toggle on/off). They see their history at a glance,
get two home-screen widgets, and receive end-of-month and end-of-year summary
notifications. It joins the `swiftjor` playground as a standalone Xcode project.

## Goals

- Tap any day (past or today) to toggle a "passed" check on/off.
- See all passed days at a glance in a month calendar.
- Two home-screen widgets that stay in sync with the app.
- An end-of-month notification summarizing how many days were passed.
- An end-of-year summary notification.
- Keep it simple — one habit, no accounts, no network.

## Non-Goals (YAGNI)

- Multiple habits.
- Notes / journaling per day.
- iCloud sync across devices.
- "Remind me to check in" daily reminders.
- Future-day checking is allowed by the toggle (no special restriction); the design
  does not add guardrails against it.

## Core Behavior

- **What's tracked:** one single thing (one habit). The habit has an editable title
  (e.g. "Meditate"), stored alongside the data.
- **Check rule:** any day can be toggled on or off. Tapping a passed day un-passes it.
  This supports backfilling missed days.
- **Granularity:** a day is identified by year/month/day only (no time of day).

## Architecture (Approach A: App Group + shared JSON)

Passed days are stored as a JSON-encoded collection in a **shared `UserDefaults`**
backed by an **App Group** (`group.com.<author>.calendarcheck`). Both the app and the
widget extension read/write through this shared container.

### Data model

- A passed day is represented as `DateComponents` with `year`, `month`, `day` set
  (calendar = `.current`). Internally stored as a `Set` for O(1) toggle/lookup.
- Persisted as JSON. Because `DateComponents` is `Codable`, encode the set directly
  (or a normalized `[String]` of `yyyy-MM-dd` keys — implementation detail decided in
  the plan; both are acceptable as long as it round-trips).
- The habit title is a separate `String` value in the same App Group `UserDefaults`.

### `CheckStore`

An `ObservableObject` that owns the passed-days set and the habit title. It is the
single source of truth for both the app and (via the same shared defaults) the widgets.

Public surface:

- `toggle(_ day: DateComponents)` — add if absent, remove if present; then persist
  and reload widget timelines.
- `isPassed(_ day: DateComponents) -> Bool`
- `passedDays(in month: Date) -> Set<DateComponents>` — days passed within a given
  month, for rendering.
- `currentStreak: Int` — number of consecutive passed days ending today (or ending
  yesterday if today isn't passed — decision: streak counts back from today; if today
  is not passed, the streak is the run ending yesterday). Must handle month/year
  boundaries.
- `daysPassed(inMonth:)` / `daysPassed(inYear:)` — counts for header + notifications.
- `habitTitle: String` — get/set, persisted.

Design for testability: `CheckStore` takes an injected `UserDefaults` (default = the
App Group suite). Tests pass a throwaway suite so they never touch the real container.

On every mutating write, `CheckStore`:
1. Encodes and saves JSON to the shared `UserDefaults`.
2. Calls `WidgetCenter.shared.reloadAllTimelines()`.

## App Targets

### 1. App — `calendarcheck`

- A scrollable month calendar (current month in focus; user can page to other months).
- Each day cell shows the day number; passed days are filled / checkmarked with a
  short animation on toggle.
- Header shows: habit title, current streak, and "N days this month."
- Toolbar button to edit the habit title (simple text field in a sheet or alert).
- Requests notification permission on first launch and schedules summaries (see below).

### 2. Widget Extension — `calendarcheckWidget`

Two widget kinds in one extension, both reading the shared `UserDefaults`:

- **Mini month calendar** (medium): current month grid with passed days filled. Tap
  opens the app.
- **Streak + count** (small): large current-streak number plus "N days this month."

Widgets use a timeline that refreshes daily (and immediately when the app calls
`reloadAllTimelines()` after a toggle).

## Notifications (`UserNotifications`)

- Permission requested on first launch.
- **End of month:** a local notification scheduled for the last day of the current
  month at ~20:00. Body: "You passed N days in <Month>! 🎉" where N is computed at
  schedule time from the store. Rescheduled on each app launch so it rolls forward
  month to month and reflects the latest count.
- **End of year:** scheduled for Dec 31 at ~20:00. Body: "<Year> recap: N days passed,
  longest streak M." Computed from the store at schedule time.
- Scheduling runs on app launch and after toggles (so embedded counts stay fresh).

## Data Flow

```
User taps day
  → CheckStore.toggle(day)
     → encode + save JSON to App Group UserDefaults
     → WidgetCenter.reloadAllTimelines()
        → both widgets re-read shared store and redraw
App launch / toggle
  → reschedule end-of-month + end-of-year notifications (counts read from store)
```

## Testing

Unit tests on `CheckStore` (using an injected throwaway `UserDefaults` suite):

- `toggle` adds a day when absent, removes it when present.
- `isPassed` reflects toggles.
- `passedDays(in:)` returns only days within the requested month.
- `currentStreak` is correct: zero when no days, counts consecutive days ending
  today, handles "today not passed" (run ending yesterday), and spans month/year
  boundaries correctly.
- `daysPassed(inMonth:)` and `daysPassed(inYear:)` count correctly.
- JSON persistence round-trips (save then load yields the same set).

## Project Setup Notes

- Standalone Xcode project `calendarcheck/calendarcheck.xcodeproj` under `swiftjor`,
  consistent with the other playground apps.
- Requires: App Group capability (app + widget targets share the same group id),
  a Widget Extension target, and the User Notifications capability.
- This is more setup than the single-target playground apps; the scaffold will be
  created as part of implementation.
- Update the repo `README.md` projects table with a `calendarcheck` row.

## Open Decisions Deferred to the Plan

- Exact JSON key format for stored days (`DateComponents` vs `yyyy-MM-dd` strings) —
  either is fine as long as it round-trips and is stable across launches.
- Whether month paging is infinite or bounded — default to a reasonable range
  (e.g. a few years back/forward) unless trivial to make unbounded.
