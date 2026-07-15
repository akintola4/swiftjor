//
//  EventDetailView.swift
//  until
//
//  A full page for one event: a progress ring around the day count, a live
//  hours/minutes/seconds clock, the target date, and edit/reset actions. Reads the
//  event live from the store by id so edits and resets reflect immediately.
//

import SwiftUI

struct EventDetailView: View {
    let eventID: UUID
    let store: EventsStore
    let settings: AppSettings
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?
    @State private var liveActive = false
    @State private var showConfetti = false

    var body: some View {
        Group {
            if let event = store.events.first(where: { $0.id == eventID }) {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    detail(event: event, now: ctx.date)
                }
            } else {
                // Deleted while open — pop back.
                Color.clear.onAppear { dismiss() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showConfetti { ConfettiView().ignoresSafeArea() }
        }
        .sensoryFeedback(.success, trigger: showConfetti) { _, now in now }
        .onAppear {
            if let event = store.events.first(where: { $0.id == eventID }) {
                makeShareImage(event)
                if CountLogic.readout(for: event).reached {
                    showConfetti = true
                }
            }
            liveActive = LiveActivityManager.isActive(eventID)
        }
        .task {
            // Let the burst play, then stop the animation timeline.
            try? await Task.sleep(for: .seconds(4))
            showConfetti = false
        }
        .toolbar {
            if let event = store.events.first(where: { $0.id == eventID }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(item: event.shareSummary()) {
                            Label("Share text", systemImage: "textformat")
                        }
                        if let shareImage {
                            ShareLink(item: shareImage, preview: SharePreview(event.title, image: shareImage)) {
                                Label("Share image", systemImage: "photo")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", action: onEdit)
            }
        }
    }

    @MainActor private func makeShareImage(_ event: UntilEvent) {
        let renderer = ImageRenderer(content: ShareCard(event: event))
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }

    @ViewBuilder private func detail(event: UntilEvent, now: Date) -> some View {
        let accent = event.accent.color
        let isCountdown = event.mode == .until
        let ref = isCountdown ? event.effectiveTarget(now: now) : event.date
        let signed = isCountdown ? ref.timeIntervalSince(now) : now.timeIntervalSince(ref)
        let reached = isCountdown && signed <= 0 && !event.isRecurring
        let bd = breakdown(abs(signed))
        let progress = CountLogic.progress(for: event, now: now)

        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Image(systemName: event.symbol).font(.largeTitle).foregroundStyle(accent)
                    Text(event.title)
                        .font(Theme.display(.title).weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(event.displayBadge)
                        .font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                ZStack {
                    Circle().stroke(accent.opacity(0.15), lineWidth: 16)
                    Circle().trim(from: 0, to: progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.snappy, value: progress)
                    VStack(spacing: 0) {
                        Text("\(bd.d)")
                            .font(.system(size: 76, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundStyle(accent)
                            .contentTransition(.numericText())
                        Text(dayLabel(reached: reached, countdown: isCountdown, days: bd.d))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 250, height: 250)

                HStack(spacing: 12) {
                    UnitCell(value: bd.h, label: "hours", accent: accent)
                    UnitCell(value: bd.m, label: "mins", accent: accent)
                    UnitCell(value: bd.s, label: "secs", accent: accent)
                }

                VStack(spacing: 3) {
                    Text(isCountdown ? (reached ? "Was" : "Counting to") : "Since")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(ref.formatted(date: .complete, time: event.includeTime ? .shortened : .omitted))
                        .font(.headline).multilineTextAlignment(.center)
                    if isCountdown, let start = event.startDate {
                        Text("Started \(start.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(16)
                        .background(.fill.quaternary, in: .rect(cornerRadius: 18))
                }

                if event.mode == .until {
                    Button {
                        if liveActive {
                            LiveActivityManager.stop(event.id); liveActive = false
                        } else {
                            liveActive = LiveActivityManager.start(event)
                        }
                    } label: {
                        Label(liveActive ? "Stop Live Activity" : "Show on Lock Screen",
                              systemImage: liveActive ? "stop.circle" : "bolt.badge.clock")
                            .font(.headline)
                            .padding(.horizontal, 22).padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .tint(accent)
                }

                if event.mode == .since {
                    VStack(spacing: 12) {
                        if event.recordSeconds > 0 {
                            Label("Record \(CountLogic.durationText(event.recordSeconds))", systemImage: "trophy")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Button {
                            store.resetSince(event)
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .padding(.horizontal, 24).padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .tint(accent)
                    }
                    .sensoryFeedback(trigger: event.date) { _, _ in settings.haptics ? .impact(weight: .medium) : nil }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private func dayLabel(reached: Bool, countdown: Bool, days: Int) -> String {
        let noun = days == 1 ? "day" : "days"
        if reached { return "\(noun) ago" }
        return countdown ? "\(noun) left" : "\(noun) so far"
    }

    private func breakdown(_ seconds: Double) -> (d: Int, h: Int, m: Int, s: Int) {
        let t = max(0, Int(seconds))
        return (t / 86_400, (t % 86_400) / 3_600, (t % 3_600) / 60, t % 60)
    }
}

/// A designed, shareable countdown graphic rendered to an image.
private struct ShareCard: View {
    let event: UntilEvent

    var body: some View {
        let r = CountLogic.readout(for: event)
        let accent = event.accent.color
        let on = event.accent.onColor
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: event.symbol).font(.title2)
                Text(event.displayBadge).font(.caption.weight(.bold)).tracking(2)
                Spacer()
            }
            .foregroundStyle(on.opacity(0.9))

            Spacer()

            Text(r.big)
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(on)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(r.unit.isEmpty ? r.detail : r.unit)
                .font(.title2.weight(.semibold)).foregroundStyle(on.opacity(0.9))
            Text(event.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(on)
                .padding(.top, 6)

            Spacer()

            Text("until")
                .font(.caption.weight(.bold)).tracking(4).foregroundStyle(on.opacity(0.5))
        }
        .padding(40)
        .frame(width: 440, height: 560, alignment: .leading)
        .background(
            LinearGradient(colors: [accent, accent.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

private struct UnitCell: View {
    let value: Int
    let label: String
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.primary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 92, height: 84)
        .background(.fill.quaternary, in: .rect(cornerRadius: 20))
    }
}
