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
    @State private var showYear = false
    @State private var noteDay: DayKey?
    @State private var milestone: Int?
    @State private var showFutureAlert = false
    @State private var futureQuote = ""
    @State private var didInitialScroll = false

    private func handleLongPress(_ key: DayKey) {
        guard !isFuture(key) else { return }
        noteDay = key
    }

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
                        MonthView(spec: month, passed: store.days, notedKeys: Set(store.dayNotes.keys), today: today, calendar: calendar, accent: settings.accent.color, onTap: handleTap, onLongPress: handleLongPress)
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
            .overlay { milestoneOverlay }
            .onChange(of: store.celebratedMilestone) { _, value in
                guard let value else { return }
                store.celebratedMilestone = nil
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { milestone = value }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { milestone = nil }
                }
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
        .sheet(isPresented: $showYear) {
            YearView(store: store, settings: settings)
        }
        .sheet(item: $noteDay) { day in
            DayNoteEditor(day: day, initial: store.note(for: day)) { text in
                store.setNote(text, for: day)
            }
        }
        .alert("Not yet", isPresented: $showFutureAlert) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text(futureQuote)
        }
    }

    @ViewBuilder private var milestoneOverlay: some View {
        ZStack {
            if milestone != nil {
                Rectangle()
                    .fill(.black.opacity(0.35))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { withAnimation { milestone = nil } }
            }
            if let m = milestone {
                VStack(spacing: 8) {
                    Text("\(m)")
                        .font(.system(size: 64, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(settings.accent.color)
                    Text("day streak")
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(.secondary)
                }
                .padding(40)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }

    // MARK: Floating glass header

    private var header: some View {
        GlassEffectContainer {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    editingDetails = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(store.habitTitle)
                                .font(Theme.display(.title).weight(.semibold))
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
                }
                .buttonStyle(.plain)

                Spacer(minLength: 16)

                Button {
                    showYear = true
                } label: {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(store.days.count)")
                            .font(.system(size: 36, weight: .bold))
                            .monospacedDigit()
                        Text("total days")
                            .font(.caption2)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .contentShape(Rectangle())
            .onTapGesture { }
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
    let passed: Set<DayKey>
    let notedKeys: Set<String>
    let today: DayKey
    let calendar: Calendar
    let accent: Color
    let onTap: (DayKey) -> Void
    let onLongPress: (DayKey) -> Void

    private var grid: MonthGrid { MonthGrid(year: spec.year, month: spec.month, calendar: calendar) }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    /// One flat, uniquely-identified list of grid cells. A single `ForEach` over
    /// this avoids the id collisions that occur when several `ForEach` loops share a
    /// `LazyVGrid` (weekday offsets, blank indices, and day numbers would otherwise
    /// overlap, and SwiftUI silently drops the duplicates).
    private enum Cell: Identifiable {
        case weekday(Int, String)
        case blank(Int)
        case day(Int)

        var id: String {
            switch self {
            case .weekday(let i, _): return "wd-\(i)"
            case .blank(let i):      return "blank-\(i)"
            case .day(let d):        return "day-\(d)"
            }
        }
    }

    private var cells: [Cell] {
        var result: [Cell] = grid.weekdaySymbols.enumerated().map { .weekday($0.offset, $0.element) }
        result += (0..<grid.leadingBlanks).map { .blank($0) }
        result += grid.days.map { .day($0) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(grid.name(calendar: calendar))
                    .font(Theme.display(.title2).weight(.semibold))
                Text(String(spec.year))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Rectangle()
                .fill(.primary.opacity(0.15))
                .frame(height: 1)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(cells) { cell in
                    switch cell {
                    case .weekday(_, let symbol):
                        Text(symbol)
                            .font(.caption2)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(.tertiary)
                    case .blank:
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    case .day(let dayNumber):
                        let key = DayKey(year: spec.year, month: spec.month, day: dayNumber)
                        DayCell(
                            dayNumber: dayNumber,
                            isToday: key == today,
                            isPassed: passed.contains(key),
                            isFuture: (spec.year, spec.month, dayNumber) > (today.year, today.month, today.day),
                            hasNote: notedKeys.contains(key.storageKey),
                            accent: accent,
                            onTap: { onTap(key) },
                            onLongPress: { onLongPress(key) }
                        )
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
    let hasNote: Bool
    let accent: Color
    let onTap: () -> Void
    let onLongPress: () -> Void

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
                    shape.fill(accent)
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

                if hasNote {
                    Circle()
                        .fill(isPassed ? AnyShapeStyle(.background) : AnyShapeStyle(.secondary))
                        .frame(width: 3, height: 3)
                        .offset(y: 13)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in onLongPress() }
        )
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
                .font(Theme.display(.title2).weight(.semibold))
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

// MARK: - Year heatmap

struct YearView: View {
    let store: CheckStore
    let settings: AppSettings

    @Environment(\.dismiss) private var dismiss
    @State private var year = Calendar.current.component(.year, from: Date())

    private var calendar: Calendar { settings.calendar }
    private var total: Int { CheckLogic.daysPassed(in: store.days, year: year) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Button { year -= 1 } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        VStack(spacing: 2) {
                            Text(verbatim: "\(year)")
                                .font(Theme.display(.title2).weight(.semibold))
                            Text("\(total) day\(total == 1 ? "" : "s") passed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer()
                        Button { year += 1 } label: { Image(systemName: "chevron.right") }
                    }
                    .tint(.primary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                    ForEach(1...12, id: \.self) { month in
                        monthRow(month)
                    }

                    milestonesRow
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    private var milestonesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MILESTONES")
                .font(.caption2)
                .tracking(1.5)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(CheckLogic.milestones, id: \.self) { m in
                    let hits = CheckLogic.milestoneHits(m, passed: store.days, calendar: calendar)
                    let earned = hits > 0
                    VStack(spacing: 5) {
                        ZStack(alignment: .topTrailing) {
                            ZStack {
                                Circle()
                                    .fill(earned ? AnyShapeStyle(settings.accent.color) : AnyShapeStyle(.quaternary))
                                    .frame(width: 46, height: 46)
                                Text("\(m)")
                                    .font(.system(size: 14, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(earned ? AnyShapeStyle(.background) : AnyShapeStyle(.secondary))
                            }
                            if hits > 0 {
                                Text("×\(hits)")
                                    .font(.system(size: 10, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.background)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(.primary))
                                    .offset(x: 6, y: -2)
                            }
                        }
                        Text(milestoneLabel(m))
                            .font(.caption2)
                            .foregroundStyle(earned ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func milestoneLabel(_ m: Int) -> String {
        switch m {
        case 7: return "Week"
        case 30: return "Month"
        case 365: return "Year"
        default: return "\(m) days"
        }
    }

    private func monthRow(_ month: Int) -> some View {
        let lastDay = CheckLogic.lastDay(ofYear: year, month: month, calendar: calendar)
        return HStack(spacing: 3) {
            Text(calendar.shortMonthSymbols[month - 1])
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            ForEach(1...31, id: \.self) { day in
                if day <= lastDay {
                    let passed = store.days.contains(DayKey(year: year, month: month, day: day))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(passed ? AnyShapeStyle(settings.accent.color) : AnyShapeStyle(.quaternary))
                        .frame(width: 7, height: 7)
                } else {
                    Color.clear.frame(width: 7, height: 7)
                }
            }
        }
    }
}

// MARK: - Per-day note editor

struct DayNoteEditor: View {
    let day: DayKey
    let initial: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var dateLabel: String {
        guard let date = day.date() else { return day.storageKey }
        let f = DateFormatter()
        f.dateStyle = .full
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(dateLabel)
                .font(Theme.display(.title3).weight(.semibold))
                .padding(.top, 8)

            TextField("What did you do?", text: $text, axis: .vertical)
                .font(.body)
                .lineLimit(3...8)
                .focused($focused)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))

            Button {
                onSave(text)
                dismiss()
            } label: {
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
        .presentationDetents([.height(340)])
        .onAppear {
            text = initial
            focused = true
        }
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
