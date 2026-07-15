//
//  RootView.swift
//  halo
//
//  Two immersive, full-bleed screens — an open sky for the Sun, a starfield night
//  for the Moon. No cards; content floats over atmospheric gradients. Live values
//  tick via TimelineView; the Moon screen can scrub the date.
//

import SwiftUI

struct RootView: View {
    let location: LocationManager
    let settings: AppSettings
    @Binding var selection: HaloFace
    @State private var showSettings = false
    @State private var showSunDetail = false
    @State private var showMoonDetail = false

    private var place: LocationSnapshot {
        if settings.useManualLocation { return settings.manualSnapshot }
        return location.snapshot ?? LocationCache.load() ?? LocationCache.fallback
    }
    private var needsLocation: Bool {
        !settings.useManualLocation && location.snapshot == nil && location.status != .authorized
    }

    var body: some View {
        TabView(selection: $selection) {
            SunScreen(place: place, needsLocation: needsLocation,
                      onEnable: { location.requestOrRefresh() },
                      onSettings: { showSettings = true },
                      onExpand: { showSunDetail = true })
                .tabItem { Label("Sun", systemImage: "sun.max.fill") }
                .tag(HaloFace.sun)

            MoonScreen(place: place, onSettings: { showSettings = true },
                       onExpand: { showMoonDetail = true })
                .tabItem { Label("Moon", systemImage: "moon.stars.fill") }
                .tag(HaloFace.moon)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, location: location)
        }
        .sheet(isPresented: $showSunDetail) { SunDetailView(place: place) }
        .sheet(isPresented: $showMoonDetail) { MoonDetailView(place: place) }
        .onAppear { if !settings.useManualLocation { location.requestOrRefresh() } }
    }
}

// MARK: - Shared bits

/// Minimal top bar drawn over the immersive background (no nav chrome).
private struct TopBar: View {
    let title: String
    var subtitle: String?
    let tint: Color
    let onSettings: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption.weight(.bold)).tracking(1.5)
                    .foregroundStyle(tint.opacity(0.75))
                if let subtitle {
                    Text(subtitle).font(.headline.weight(.semibold)).foregroundStyle(tint).lineLimit(1)
                }
            }
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .buttonStyle(.plain)
        }
    }
}

/// A padded stat tile for the 2-column grid. `solidWhite` gives an opaque white
/// card with dark text (needed on the bright Sun sky); otherwise a dark glass card
/// (readable on the Moon's night).
private struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    var sub: String?
    let tint: Color
    var solidWhite = false

    static let ink = Color(red: 0.12, green: 0.13, blue: 0.17)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(label.uppercased()).font(.caption2.weight(.semibold)).tracking(0.6)
            }
            .foregroundStyle(tint.opacity(solidWhite ? 1 : 0.75))

            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(solidWhite ? Self.ink : tint)
                    .lineLimit(1).minimumScaleFactor(0.55)
                if let sub {
                    Text(sub).font(.caption2)
                        .foregroundStyle(solidWhite ? Self.ink.opacity(0.55) : tint.opacity(0.6))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(16)
        .background {
            if solidWhite {
                RoundedRectangle(cornerRadius: 22).fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.black.opacity(0.05)))
            } else {
                RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(tint.opacity(0.1)))
            }
        }
    }
}

private let statColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

// MARK: - Sun

private struct SunScreen: View {
    let place: LocationSnapshot
    let needsLocation: Bool
    let onEnable: () -> Void
    let onSettings: () -> Void
    let onExpand: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            content(now: ctx.date)
        }
    }

    @ViewBuilder private func content(now: Date) -> some View {
        let lat = place.latitude, lon = place.longitude
        let elevation = Solar.elevation(at: now, latitude: lat, longitude: lon)
        let times = Solar.times(on: now, latitude: lat, longitude: lon)
        let daylight = Solar.daylight(at: now, latitude: lat, longitude: lon)
        let yesterday = Solar.times(on: now.addingTimeInterval(-86_400), latitude: lat, longitude: lon)
        let ink = SkyGradient.ink(forElevation: elevation)
        let (big, label) = readout(daylight)
        let golden = goldenValue(now: now, lat: lat, lon: lon)
        let sea = season(now)

        ZStack {
            LinearGradient(colors: SkyGradient.colors(forElevation: elevation),
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(title: "Sun", subtitle: place.name, tint: ink, onSettings: onSettings)
                    .padding(.top, 4)

                if needsLocation { locationPrompt(ink).padding(.top, 16) }

                Spacer(minLength: 12)

                VStack(spacing: 2) {
                    Text(big)
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                        .minimumScaleFactor(0.5).lineLimit(1)
                    HStack(spacing: 5) {
                        Text(label).font(.title3.weight(.medium)).foregroundStyle(ink.opacity(0.8))
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.footnote).foregroundStyle(ink.opacity(0.45))
                    }
                }
                .contentShape(.rect)
                .onTapGesture(perform: onExpand)

                SunHorizon(progress: daylight.progress,
                           sunrise: hm(times.sunrise), sunset: hm(times.sunset), tint: ink)
                    .frame(height: 190)
                    .padding(.top, 8)
                    .contentShape(.rect)
                    .onTapGesture(perform: onExpand)

                Spacer(minLength: 16)

                LazyVGrid(columns: statColumns, spacing: 12) {
                    StatTile(icon: "sun.max", label: "Solar noon", value: hm(times.solarNoon), tint: Theme.sun, solidWhite: true)
                    StatTile(icon: "camera.aperture", label: "Golden hour", value: golden.0, sub: golden.1, tint: Theme.sun, solidWhite: true)
                    StatTile(icon: "timer", label: "Daylight", value: Theme.duration(times.dayLength),
                             sub: dayLengthDelta(today: times.dayLength, yesterday: yesterday.dayLength), tint: Theme.sun, solidWhite: true)
                    StatTile(icon: "calendar", label: "Next season", value: sea.name, sub: sea.sub, tint: Theme.sun, solidWhite: true)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
        }
    }

    private func readout(_ d: Solar.Daylight) -> (String, String) {
        switch d.phase {
        case .daytime:    return (Theme.duration(d.remaining), "of daylight left")
        case .beforeDawn: return (Theme.duration(d.remaining), "until sunrise")
        case .afterDusk:  return (Theme.duration(d.remaining), "until sunrise")
        case .polarDay:   return ("24h", "midnight sun")
        case .polarNight: return ("0h", "polar night")
        }
    }

    private func goldenValue(now: Date, lat: Double, lon: Double) -> (String, String?) {
        guard let g = Solar.nextGolden(at: now, latitude: lat, longitude: lon) else { return ("—", nil) }
        switch g.phase {
        case .active:   return ("Now", "ends \(hm(g.window.end))")
        case .upcoming: return ("in \(Theme.duration(g.window.start.timeIntervalSince(now)))", hm(g.window.start))
        }
    }

    private func dayLengthDelta(today: TimeInterval, yesterday: TimeInterval) -> String {
        let d = Int((today - yesterday).rounded())
        let sign = d >= 0 ? "+" : "−"
        let a = abs(d), m = a / 60, s = a % 60
        let mag = m >= 1 ? "\(m)m \(s)s" : "\(s)s"
        return "\(sign)\(mag) vs yesterday"
    }

    private func season(_ now: Date) -> (name: String, sub: String) {
        let s = Solar.nextSeason(after: now)
        let days = Theme.daysAway(to: s.date, now: now)
        return (s.name, "in \(days) day\(days == 1 ? "" : "s")")
    }

    private func locationPrompt(_ ink: Color) -> some View {
        VStack(spacing: 8) {
            Text("Location needed").font(.headline).foregroundStyle(ink)
            Text("The Sun screen uses your location for sunrise, sunset, and golden hour.")
                .font(.subheadline).foregroundStyle(ink.opacity(0.8)).multilineTextAlignment(.center)
            HStack {
                Button("Enable location", action: onEnable).buttonStyle(.borderedProminent)
                Button("Manual", action: onSettings).buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }
}

/// Sunrise→sunset arc over a horizon line, with the sun glowing at its current spot.
private struct SunHorizon: View {
    var progress: Double
    var sunrise: String
    var sunset: String
    var tint: Color
    var accent: Color = Theme.sun

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let r = min(w / 2 - 16, h - 40)
            let cx = w / 2, cy = h - 34
            let t = min(1, max(0, progress))
            let sx = cx - r * cos(.pi * t), sy = cy - r * sin(.pi * t)

            ZStack(alignment: .topLeading) {
                Path { p in p.move(to: CGPoint(x: 0, y: cy)); p.addLine(to: CGPoint(x: w, y: cy)) }
                    .stroke(tint.opacity(0.25), lineWidth: 1)
                arc(cx: cx, cy: cy, r: r)
                    .stroke(tint.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [2, 6]))
                Circle()
                    .fill(accent)
                    .frame(width: 24, height: 24)
                    .shadow(color: accent.opacity(0.9), radius: 16)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                    .position(x: sx, y: sy)
                Text(sunrise).font(.caption2.weight(.bold)).foregroundStyle(tint.opacity(0.85))
                    .position(x: cx - r, y: cy + 16)
                Text(sunset).font(.caption2.weight(.bold)).foregroundStyle(tint.opacity(0.85))
                    .position(x: cx + r, y: cy + 16)
            }
        }
    }

    private func arc(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        Path { p in
            let steps = 72
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let pt = CGPoint(x: cx - r * cos(.pi * t), y: cy - r * sin(.pi * t))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
    }
}

// MARK: - Moon

private struct MoonScreen: View {
    let place: LocationSnapshot
    let onSettings: () -> Void
    let onExpand: () -> Void
    @State private var dayOffset: Double = 0

    // Always night, regardless of app appearance.
    private let sky = [Color(red: 0.03, green: 0.04, blue: 0.11), Color(red: 0.09, green: 0.10, blue: 0.22)]
    private let ink = Color.white

    var body: some View {
        TimelineView(.periodic(from: .now, by: 900)) { ctx in
            content(base: ctx.date)
        }
    }

    @ViewBuilder private func content(base: Date) -> some View {
        let date = base.addingTimeInterval(dayOffset * 86_400)
        let isPreview = Int(dayOffset) != 0
        let illum = Lunar.illumination(date)
        let rs = Lunar.nextRiseSet(after: base, latitude: place.latitude, longitude: place.longitude)

        ZStack {
            LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            Starfield().ignoresSafeArea().opacity(0.9)

            VStack(spacing: 0) {
                TopBar(title: "Moon", subtitle: Lunar.fullMoonName(for: Lunar.nextFullMoon(after: date)),
                       tint: ink, onSettings: onSettings)
                    .padding(.top, 4)

                Spacer(minLength: 8)

                MoonDisc(illumination: illum, waxing: Lunar.isWaxing(date))
                    .frame(width: 210, height: 210)
                    .shadow(color: Color(red: 0.7, green: 0.75, blue: 0.95).opacity(0.35), radius: 40)
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                    .contentShape(.rect)
                    .onTapGesture(perform: onExpand)

                VStack(spacing: 5) {
                    Text(Lunar.phaseName(date))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold)).foregroundStyle(ink)
                    HStack(spacing: 5) {
                        Text("\(Int((illum * 100).rounded()))% illuminated")
                            .font(.headline).foregroundStyle(ink.opacity(0.7))
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.footnote).foregroundStyle(ink.opacity(0.4))
                    }
                }
                .padding(.top, 18)
                .contentShape(.rect)
                .onTapGesture(perform: onExpand)

                scrubber(date: date, isPreview: isPreview).padding(.top, 16)

                Spacer(minLength: 16)

                let full = milestone(Lunar.nextFullMoon(after: date), from: date)
                let new = milestone(Lunar.nextNewMoon(after: date), from: date)
                LazyVGrid(columns: statColumns, spacing: 12) {
                    StatTile(icon: "moon.stars", label: "Moonrise", value: hm(rs.rise), tint: ink)
                    StatTile(icon: "moon", label: "Moonset", value: hm(rs.set), tint: ink)
                    StatTile(icon: "moonphase.full.moon", label: "Full moon", value: full.0, sub: full.1, tint: ink)
                    StatTile(icon: "moonphase.new.moon", label: "New moon", value: new.0, sub: new.1, tint: ink)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
        }
        .environment(\.colorScheme, .dark)
    }

    private func scrubber(date: Date, isPreview: Bool) -> some View {
        VStack(spacing: 8) {
            Text(date.formatted(date: .complete, time: .omitted))
                .font(.subheadline.weight(.semibold)).foregroundStyle(ink.opacity(0.9))
            Slider(value: $dayOffset, in: -20...20, step: 1).tint(Theme.moon)
            if isPreview {
                Button { withAnimation(.snappy) { dayOffset = 0 } } label: {
                    Label("Back to tonight", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                }
                .tint(ink)
            } else {
                Text("Drag to preview any night").font(.caption).foregroundStyle(ink.opacity(0.55))
            }
        }
    }

    private func milestone(_ date: Date, from ref: Date) -> (String, String) {
        let days = Theme.daysAway(to: date, now: ref)
        return (days == 0 ? "Today" : "in \(days)d", date.formatted(date: .abbreviated, time: .omitted))
    }
}

/// Deterministic starfield so the sky is stable frame-to-frame.
private struct Starfield: View {
    private static let stars: [(x: Double, y: Double, r: Double, o: Double)] = (0..<90).map { i in
        func frac(_ v: Double) -> Double { let x = sin(v) * 43758.5453; return x - x.rounded(.down) }
        return (x: frac(Double(i) * 12.9898),
                y: frac(Double(i) * 78.233),
                r: 0.4 + frac(Double(i) * 3.1415) * 1.4,
                o: 0.25 + frac(Double(i) * 5.77) * 0.6)
    }

    var body: some View {
        Canvas { ctx, size in
            for s in Self.stars {
                let rect = CGRect(x: s.x * size.width, y: s.y * size.height * 0.75,
                                  width: s.r, height: s.r)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(s.o)))
            }
        }
    }
}

// MARK: - Helpers

/// Short local time, or "—" when a value is absent (polar day/night, no rise/set).
private func hm(_ date: Date?) -> String {
    date.map { $0.formatted(date: .omitted, time: .shortened) } ?? "—"
}
