//
//  ContentView.swift
//  calendarcheck
//
//  Editorial monochrome calendar. One color — vermilion — and only on a passed day.
//  Liquid Glass for the floating header + controls. App target only.
//

import SwiftUI

struct ContentView: View {
    let store: CheckStore
    let settings: AppSettings

    private let months: [MonthSpec] = MonthSpec.range(back: 36, forward: 24)

    @State private var headerHeight: CGFloat = 0
    @State private var editingDetails = false
    @State private var showSettings = false
    @State private var showFutureAlert = false
    @State private var futureQuote = ""
    @State private var didInitialScroll = false

    private var calendar: Calendar { settings.calendar }
    private var today: DayKey { DayKey(date: Date(), calendar: calendar) }

    private func isFuture(_ key: DayKey) -> Bool {
        (key.year, key.month, key.day) > (today.year, today.month, today.day)
    }

    private func handleTap(_ key: DayKey) {
        if isFuture(key) {
            if settings.quotesEnabled {
                let pool = settings.activeQuotes
                var q = pool.randomElement() ?? "That day hasn't arrived yet."
                while q == futureQuote && pool.count > 1 { q = pool.randomElement() ?? q }
                futureQuote = q
            } else {
                futureQuote = "That day hasn't arrived yet."
            }
            showFutureAlert = true
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
            store.toggle(key)
        }
    }

    private var currentMonthID: Int { MonthSpec(year: today.year, month: today.month).id }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 40) {
                    ForEach(months) { month in
                        MonthView(spec: month, store: store, today: today, calendar: calendar, onTap: handleTap)
                            .id(month.id)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, headerHeight + 16)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .top) { header }
            .overlay(alignment: .bottomTrailing) { todayButton(proxy: proxy) }
            .overlay(alignment: .bottomLeading) { settingsButton }
            .onAppear {
                guard !didInitialScroll else { return }
                didInitialScroll = true
                DispatchQueue.main.async {
                    proxy.scrollTo(currentMonthID, anchor: .center)
                }
            }
            .sensoryFeedback(trigger: store.days.count) { _, _ in
                settings.haptics ? .impact(weight: .light) : nil
            }
        }
        .sheet(isPresented: $editingDetails) {
            DetailsEditor(title: store.habitTitle, note: store.habitNote) { newTitle, newNote in
                store.setDetails(title: newTitle, note: newNote)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, store: store)
        }
        .alert("Not yet", isPresented: $showFutureAlert) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text(futureQuote)
        }
    }

    // MARK: Floating glass header

    private var header: some View {
        GlassEffectContainer {
            Button {
                editingDetails = true
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if !settings.habitIcon.isEmpty {
                                Text(settings.habitIcon)
                                    .font(Theme.serif(.title))
                            }
                            Text(store.habitTitle)
                                .font(Theme.serif(.title).weight(.semibold))
                                .foregroundStyle(.primary)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("\(store.daysThisMonth) this month")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer(minLength: 16)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(store.currentStreak)")
                            .font(.system(size: 36, weight: .bold))
                            .monospacedDigit()
                        Text("streak")
                            .font(.caption2)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HeaderHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeaderHeightKey.self) { headerHeight = $0 }
    }

    // MARK: Floating "today" control

    private func todayButton(proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.snappy) { proxy.scrollTo(currentMonthID, anchor: .center) }
        } label: {
            Image(systemName: "smallcircle.filled.circle")
                .font(.title2)
                .padding(14)
        }
        .buttonStyle(.glass)
        .tint(.primary)
        .padding(.trailing, 20)
        .padding(.bottom, 28)
        .accessibilityLabel("Jump to current month")
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.title2)
                .padding(14)
        }
        .buttonStyle(.glass)
        .tint(.primary)
        .padding(.leading, 20)
        .padding(.bottom, 28)
        .accessibilityLabel("Settings")
    }
}

// MARK: - Month

struct MonthSpec: Identifiable {
    let year: Int
    let month: Int
    var id: Int { year * 100 + month }

    static func range(back: Int, forward: Int) -> [MonthSpec] {
        let cal = Calendar.current
        let now = Date()
        guard let start = cal.date(byAdding: .month, value: -back, to: now) else { return [] }
        return (0...(back + forward)).compactMap { offset in
            guard let d = cal.date(byAdding: .month, value: offset, to: start) else { return nil }
            let c = cal.dateComponents([.year, .month], from: d)
            return MonthSpec(year: c.year!, month: c.month!)
        }
    }
}

struct MonthView: View {
    let spec: MonthSpec
    let store: CheckStore
    let today: DayKey
    let calendar: Calendar
    let onTap: (DayKey) -> Void

    private var grid: MonthGrid { MonthGrid(year: spec.year, month: spec.month, calendar: calendar) }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(grid.name(calendar: calendar))
                    .font(Theme.serif(.title2).weight(.semibold))
                Text(String(spec.year))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Rectangle()
                .fill(.primary.opacity(0.15))
                .frame(height: 1)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(grid.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.tertiary)
                }
                ForEach(Array(0..<grid.leadingBlanks), id: \.self) { _ in
                    Color.clear.frame(height: 1)
                }
                ForEach(grid.days, id: \.self) { dayNumber in
                    let key = DayKey(year: spec.year, month: spec.month, day: dayNumber)
                    DayCell(
                        dayNumber: dayNumber,
                        isToday: key == today,
                        isPassed: store.isPassed(key),
                        isFuture: (spec.year, spec.month, dayNumber) > (today.year, today.month, today.day)
                    ) {
                        onTap(key)
                    }
                }
            }
        }
    }
}

struct DayCell: View {
    let dayNumber: Int
    let isToday: Bool
    let isPassed: Bool
    let isFuture: Bool
    let onTap: () -> Void

    private var numberStyle: AnyShapeStyle {
        if isPassed { return AnyShapeStyle(.background) }
        if isFuture { return AnyShapeStyle(.tertiary) }
        return AnyShapeStyle(.primary)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 11, style: .continuous) }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isPassed {
                    shape.fill(Theme.accent)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                    if isToday {
                        shape.strokeBorder(.primary, lineWidth: 1.5)
                    }
                } else if isToday {
                    shape.strokeBorder(.primary.opacity(0.55), lineWidth: 1.5)
                }

                Text("\(dayNumber)")
                    .font(.system(size: 16, weight: isPassed ? .semibold : .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(numberStyle)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Details editor (name + note)

struct DetailsEditor: View {
    let title: String
    let note: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var titleText = ""
    @State private var noteText = ""
    @FocusState private var focus: Field?

    private enum Field { case title, note }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("What are you tracking?")
                .font(Theme.serif(.title2).weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            field(label: "NAME") {
                TextField("Daily Check", text: $titleText)
                    .font(.title3)
                    .focused($focus, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focus = .note }
            }

            field(label: "NOTE") {
                TextField("Why does this matter to you?", text: $noteText, axis: .vertical)
                    .font(.body)
                    .lineLimit(3...6)
                    .focused($focus, equals: .note)
            }

            Button(action: save) {
                Text("Save")
                    .font(.headline)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)
        }
        .padding(28)
        .presentationDetents([.medium, .large])
        .onAppear {
            titleText = title
            noteText = note
            focus = .title
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption2)
                .tracking(1.5)
                .foregroundStyle(.secondary)
            content()
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }
    }

    private func save() {
        onSave(titleText, noteText)
        dismiss()
    }
}

// MARK: - Header height plumbing

private struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    ContentView(store: CheckStore(), settings: AppSettings())
}
