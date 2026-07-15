//
//  HaloDetail.swift
//  halo
//
//  Full detail sheets for the Sun and the Moon — every time for the day, a live
//  countdown, a "Show on Lock Screen" button that starts the Live Activity, and a
//  shareable image. Mirrors the until app's detail page.
//

import SwiftUI

// MARK: - Sun detail

struct SunDetailView: View {
    let place: LocationSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var liveActive = false
    @State private var shareImage: Image?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                content(now: ctx.date)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("Sun · \(place.name)", image: shareImage)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                liveActive = HaloLiveActivityManager.isActive(.sun)
                renderShare()
            }
        }
    }

    @ViewBuilder private func content(now: Date) -> some View {
        let lat = place.latitude, lon = place.longitude
        let d = Solar.daylight(at: now, latitude: lat, longitude: lon)
        let t = Solar.times(on: now, latitude: lat, longitude: lon)

        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Image(systemName: "sun.max.fill").font(.largeTitle).foregroundStyle(Theme.sun)
                    Text(place.name).font(Theme.display(.title2).weight(.bold))
                    Text(bigLabel(d).uppercased())
                        .font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                Ring(progress: d.progress, tint: Theme.sun) {
                    VStack(spacing: 0) {
                        Text(bigValue(d))
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundStyle(Theme.sun)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text(bigLabel(d)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 250, height: 250)

                LazyVGrid(columns: tileColumns, spacing: 12) {
                    DetailTile("sunrise", "Sunrise", time: t.sunrise, tint: Theme.sun)
                    DetailTile("sunset", "Sunset", time: t.sunset, tint: Theme.sun)
                    DetailTile("sun.max", "Solar noon", time: t.solarNoon, tint: Theme.sun)
                    DetailTile("timer", "Day length", text: Theme.duration(t.dayLength), tint: Theme.sun)
                    DetailTile("camera.aperture", "Golden AM", time: t.goldenMorningEnd, tint: Theme.sun)
                    DetailTile("camera.aperture", "Golden PM", time: t.goldenEveningStart, tint: Theme.sun)
                }

                liveButton
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var liveButton: some View {
        Button {
            if liveActive { HaloLiveActivityManager.stop(.sun); liveActive = false }
            else { liveActive = HaloLiveActivityManager.startSun(place: place) }
        } label: {
            Label(liveActive ? "Stop Live Activity" : "Show on Lock Screen",
                  systemImage: liveActive ? "stop.circle" : "bolt.badge.clock")
                .font(.headline).padding(.vertical, 5).padding(.horizontal, 10)
        }
        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Theme.sun)
    }

    @MainActor private func renderShare() {
        let r = ImageRenderer(content: SunShareCard(place: place))
        r.scale = 3
        if let ui = r.uiImage { shareImage = Image(uiImage: ui) }
    }

    private func bigValue(_ d: Solar.Daylight) -> String {
        switch d.phase {
        case .polarDay: return "24h"
        case .polarNight: return "0h"
        default: return Theme.duration(d.remaining)
        }
    }
    private func bigLabel(_ d: Solar.Daylight) -> String {
        switch d.phase {
        case .daytime: return "of daylight left"
        case .beforeDawn, .afterDusk: return "until sunrise"
        case .polarDay: return "midnight sun"
        case .polarNight: return "polar night"
        }
    }
}

// MARK: - Moon detail

struct MoonDetailView: View {
    let place: LocationSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var liveActive = false
    @State private var shareImage: Image?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                content(now: ctx.date)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("Tonight's Moon", image: shareImage)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                liveActive = HaloLiveActivityManager.isActive(.moon)
                renderShare()
            }
        }
    }

    @ViewBuilder private func content(now: Date) -> some View {
        let illum = Lunar.illumination(now)
        let rs = Lunar.nextRiseSet(after: now, latitude: place.latitude, longitude: place.longitude)
        let full = Lunar.nextFullMoon(after: now)
        let new = Lunar.nextNewMoon(after: now)
        let tint = Theme.moon

        ScrollView {
            VStack(spacing: 24) {
                MoonDisc(illumination: illum, waxing: Lunar.isWaxing(now))
                    .frame(width: 190, height: 190)
                    .shadow(color: tint.opacity(0.4), radius: 30)
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    Text(Lunar.phaseName(now)).font(Theme.display(.title).weight(.bold))
                    Text("\(Int((illum * 100).rounded()))% illuminated · \(Lunar.fullMoonName(for: full))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                LazyVGrid(columns: tileColumns, spacing: 12) {
                    DetailTile("moon.stars", "Moonrise", time: rs.rise, tint: tint, glass: true)
                    DetailTile("moon", "Moonset", time: rs.set, tint: tint, glass: true)
                    DetailTile("moonphase.full.moon", "Full moon",
                               text: milestone(full, from: now).0, sub: milestone(full, from: now).1, tint: tint, glass: true)
                    DetailTile("moonphase.new.moon", "New moon",
                               text: milestone(new, from: now).0, sub: milestone(new, from: now).1, tint: tint, glass: true)
                }

                Button {
                    if liveActive { HaloLiveActivityManager.stop(.moon); liveActive = false }
                    else { liveActive = HaloLiveActivityManager.startMoon() }
                } label: {
                    Label(liveActive ? "Stop Live Activity" : "Track full moon",
                          systemImage: liveActive ? "stop.circle" : "bolt.badge.clock")
                        .font(.headline).padding(.horizontal, 22).padding(.vertical, 8)
                }
                .buttonStyle(.glass).buttonBorderShape(.capsule).tint(tint)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
        .background(LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.13),
                                            Color(red: 0.09, green: 0.10, blue: 0.22)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private func milestone(_ date: Date, from now: Date) -> (String, String) {
        let days = Theme.daysAway(to: date, now: now)
        let when = date.formatted(date: .abbreviated, time: .omitted)
        return (days == 0 ? "Today" : "in \(days)d", when)
    }

    @MainActor private func renderShare() {
        let r = ImageRenderer(content: MoonShareCard(date: Date()))
        r.scale = 3
        if let ui = r.uiImage { shareImage = Image(uiImage: ui) }
    }
}

// MARK: - Building blocks

/// A circular progress ring wrapping arbitrary centered content.
private struct Ring<Content: View>: View {
    let progress: Double
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: 16)
            Circle().trim(from: 0, to: min(1, max(0, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: progress)
            content
        }
    }
}

private let tileColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

/// A padded stat tile matching the home screens — no boring divider rows.
private struct DetailTile: View {
    let icon: String
    let label: String
    let value: String
    var sub: String?
    let tint: Color

    init(_ icon: String, _ label: String, time: Date?, tint: Color, glass: Bool = false) {
        self.icon = icon; self.label = label
        self.value = time.map { $0.formatted(date: .omitted, time: .shortened) } ?? "—"
        self.tint = tint; self.glass = glass
    }
    init(_ icon: String, _ label: String, text: String, sub: String? = nil, tint: Color, glass: Bool = false) {
        self.icon = icon; self.label = label; self.value = text; self.sub = sub; self.tint = tint; self.glass = glass
    }

    var glass = false   // dark glass (matches the Moon page) vs. a white card (Sun)

    static let ink = Color(red: 0.12, green: 0.13, blue: 0.17)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(label.uppercased()).font(.caption2.weight(.semibold)).tracking(0.6)
            }
            .foregroundStyle(glass ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(tint))

            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(glass ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .lineLimit(1).minimumScaleFactor(0.55)
                if let sub {
                    Text(sub).font(.caption2)
                        .foregroundStyle(glass ? AnyShapeStyle(.white.opacity(0.6)) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(16)
        .background {
            if glass {
                RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.12)))
            } else {
                RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemGroupedBackground))
            }
        }
    }
}

// MARK: - Share cards

/// A designed, shareable Sun graphic rendered to an image.
private struct SunShareCard: View {
    let place: LocationSnapshot

    var body: some View {
        let d = Solar.daylight(at: Date(), latitude: place.latitude, longitude: place.longitude)
        let t = Solar.times(on: Date(), latitude: place.latitude, longitude: place.longitude)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill").font(.title2)
                Text(place.name.uppercased()).font(.caption.weight(.bold)).tracking(2)
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text(Theme.duration(d.remaining))
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
            Text(d.phase == .daytime ? "of daylight left" : "until sunrise")
                .font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 18) {
                shareStat("Sunrise", t.sunrise)
                shareStat("Sunset", t.sunset)
            }
            .padding(.top, 18)
            Spacer()
            Text("halo").font(.caption.weight(.bold)).tracking(4).foregroundStyle(.white.opacity(0.5))
        }
        .padding(40)
        .frame(width: 440, height: 560, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.98, green: 0.55, blue: 0.20),
                                            Color(red: 0.90, green: 0.36, blue: 0.30)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func shareStat(_ label: String, _ date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.white.opacity(0.7))
            Text(date.map { $0.formatted(date: .omitted, time: .shortened) } ?? "—")
                .font(.title3.weight(.bold)).foregroundStyle(.white)
        }
    }
}

/// A designed, shareable Moon graphic — the real disc on a night sky.
private struct MoonShareCard: View {
    let date: Date

    var body: some View {
        let illum = Lunar.illumination(date)
        VStack(spacing: 0) {
            HStack {
                Text(Lunar.fullMoonName(for: Lunar.nextFullMoon(after: date)).uppercased())
                    .font(.caption.weight(.bold)).tracking(2).foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
            Spacer()
            MoonDisc(illumination: illum, waxing: Lunar.isWaxing(date))
                .frame(width: 240, height: 240)
                .shadow(color: Color(red: 0.7, green: 0.75, blue: 0.95).opacity(0.4), radius: 40)
            Spacer()
            VStack(spacing: 6) {
                Text(Lunar.phaseName(date))
                    .font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("\(Int((illum * 100).rounded()))% illuminated")
                    .font(.title3.weight(.medium)).foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Text("halo").font(.caption.weight(.bold)).tracking(4).foregroundStyle(.white.opacity(0.45))
        }
        .padding(40)
        .frame(width: 440, height: 560)
        .background(LinearGradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.13),
                                            Color(red: 0.11, green: 0.12, blue: 0.26)],
                                   startPoint: .top, endPoint: .bottom))
    }
}
