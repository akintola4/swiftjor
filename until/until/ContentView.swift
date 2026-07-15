//
//  ContentView.swift
//  until
//
//  One screen: a scrollable list of event cards, a floating glass header, and
//  two glass controls (add / settings). App target only.
//

import SwiftUI

struct ContentView: View {
    let store: EventsStore
    let settings: AppSettings
    @Binding var deepLinkedEventID: UUID?

    @State private var showSettings = false
    @State private var editing: UntilEvent?
    @State private var creating = false
    @State private var detail: UntilEvent?
    @State private var searchText = ""
    @State private var selectedCategory: String?

    // MARK: Filtering

    private var categories: [String] {
        Array(Set(store.events.map(\.category).filter { !$0.isEmpty })).sorted()
    }
    private var isFiltering: Bool { !searchText.isEmpty || selectedCategory != nil }
    private var filtered: [UntilEvent] {
        store.events.filter { e in
            (selectedCategory == nil || e.category == selectedCategory) &&
            (searchText.isEmpty
             || e.title.localizedCaseInsensitiveContains(searchText)
             || e.notes.localizedCaseInsensitiveContains(searchText)
             || e.category.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if !store.events.isEmpty {
                    searchAndFilter
                }
                content
            }
            .padding(.top, 4)
            .overlay(alignment: .bottomTrailing) { addButton }
            .overlay(alignment: .bottomLeading) { settingsButton }
            .sheet(item: $editing) { event in
                EventEditor(event: event, defaultAccent: settings.defaultAccent) { saved in
                    store.update(saved)
                } onDelete: {
                    store.delete(event)
                }
            }
            .sheet(isPresented: $creating) {
                EventEditor(event: nil, defaultAccent: settings.defaultAccent) { saved in
                    store.add(saved)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings)
            }
            .onChange(of: deepLinkedEventID) { _, id in
                guard let id, let match = store.events.first(where: { $0.id == id }) else { return }
                detail = match
                deepLinkedEventID = nil
            }
            .onChange(of: settings.reminderHour) { _, _ in
                store.rescheduleReminders()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $detail) { event in
                EventDetailView(eventID: event.id, store: store, settings: settings, onEdit: {
                    editing = event
                })
            }
        }
    }

    // MARK: Content (list / grid / empty)

    @ViewBuilder private var content: some View {
        if store.events.isEmpty {
            ScrollView { EmptyState { creating = true }.padding(.top, 120).padding(.horizontal, 32) }
        } else if filtered.isEmpty {
            ContentUnavailableView("No matches", systemImage: "magnifyingglass",
                                   description: Text("Try a different search or category."))
                .frame(maxHeight: .infinity)
        } else if settings.layout == .list {
            listView
        } else {
            gridView
        }
    }

    private var listView: some View {
        List {
            ForEach(filtered) { event in
                Button { detail = event } label: {
                    EventCard(event: event, settings: settings) { store.resetSince(event) }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button { editing = event } label: { Label("Edit", systemImage: "pencil") }
                        .tint(event.accent.color)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { store.delete(event) } label: { Label("Delete", systemImage: "trash") }
                }
                .contextMenu { menu(for: event) } preview: { EventPreview(event: event) }
            }
            .onMove { indices, dest in
                guard !isFiltering else { return }   // reorder only applies to the full list
                store.move(from: indices, to: dest)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 100, for: .scrollContent)
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(filtered) { event in
                    Button { detail = event } label: {
                        GridEventCard(event: event)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(for: event) } preview: { EventPreview(event: event) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder private func menu(for event: UntilEvent) -> some View {
        Button { detail = event } label: { Label("Open", systemImage: "arrow.up.forward.square") }
        Button { editing = event } label: { Label("Edit", systemImage: "pencil") }
        if event.mode == .since {
            Button { store.resetSince(event) } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
        }
        ShareLink(item: event.shareSummary()) { Label("Share", systemImage: "square.and.arrow.up") }
        Divider()
        Button(role: .destructive) { store.delete(event) } label: { Label("Delete", systemImage: "trash") }
    }

    // MARK: Header + controls

    private var searchAndFilter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search", text: $searchText)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(.fill.tertiary, in: .capsule)

                Button {
                    withAnimation(.snappy) { settings.layout = settings.layout == .list ? .grid : .list }
                } label: {
                    Image(systemName: settings.layout == .list ? "square.grid.2x2" : "rectangle.grid.1x2")
                        .font(.headline)
                        .frame(width: 44, height: 44)          // HIG: 44pt minimum tap target
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(settings.layout == .list ? "Switch to grid" : "Switch to list")
            }

            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("All", selected: selectedCategory == nil) { selectedCategory = nil }
                        ForEach(categories, id: \.self) { c in
                            chip(c, selected: selectedCategory == c) {
                                selectedCategory = (selectedCategory == c) ? nil : c
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary), in: .capsule)
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button { creating = true } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
        .padding(20)
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.title3.weight(.semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .padding(20)
    }
}

// MARK: - Event card

struct EventCard: View {
    let event: UntilEvent
    let settings: AppSettings
    let onReset: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: tick)) { ctx in
            card(readout: CountLogic.readout(for: event, now: ctx.date))
        }
    }

    /// Refresh cadence: live seconds within an hour, minutes within a day, else lazy.
    private var tick: TimeInterval {
        guard event.includeTime else { return 3_600 }
        let mag = abs(event.date.timeIntervalSinceNow)
        if mag < 3_600 { return 1 }
        if mag < 86_400 { return 60 }
        return 3_600
    }

    @ViewBuilder private func card(readout r: CountLogic.Readout) -> some View {
        let accent = event.accent.color
        let filled = event.filled
        let on = event.accent.onColor
        let title: Color = filled ? on : .primary
        let big: Color = filled ? on : accent
        let secondary: Color = filled ? on.opacity(0.85) : .secondary

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: event.symbol).font(.headline).foregroundStyle(filled ? .white : accent)
                Text(event.title)
                    .font(Theme.display(.title3).weight(.semibold)).lineLimit(1).foregroundStyle(title)
                Spacer()
                Text(event.displayBadge)
                    .font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(r.big)
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(big)
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 1) {
                    if !r.unit.isEmpty { Text(r.unit).font(.subheadline.weight(.medium)).foregroundStyle(title) }
                    Text(r.detail).font(.caption).foregroundStyle(secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            if r.reached || !event.category.isEmpty {
                HStack(spacing: 8) {
                    if r.reached {
                        Label("Reached", systemImage: "checkmark.seal.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(filled ? on : accent)
                    }
                    if !event.category.isEmpty {
                        Text(event.category)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(filled ? AnyShapeStyle(.white.opacity(0.2)) : AnyShapeStyle(.fill.tertiary),
                                        in: .capsule)
                    }
                    Spacer()
                }
            }

            if event.mode == .since {
                HStack {
                    if event.recordSeconds > 0 {
                        Label("Record \(CountLogic.durationText(event.recordSeconds))", systemImage: "trophy")
                            .font(.caption).foregroundStyle(secondary)
                    }
                    Spacer()
                    Button(action: onReset) {
                        Label("Reset", systemImage: "arrow.counterclockwise").font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.glass).buttonBorderShape(.capsule).controlSize(.small)
                    .tint(filled ? on : accent)
                }
                .sensoryFeedback(trigger: event.date) { _, _ in
                    settings.haptics ? .impact(weight: .medium) : nil
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackground(filled: filled, accent: accent))
        .animation(.snappy, value: r.big)
    }
}

/// Filled accent-gradient cover, or the default glass card.
private struct CardBackground: ViewModifier {
    let filled: Bool
    let accent: Color

    func body(content: Content) -> some View {
        if filled {
            content.background(
                LinearGradient(colors: [accent, accent.opacity(0.72)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 28)
            )
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
    }
}

// MARK: - Empty state

// MARK: - Grid card

struct GridEventCard: View {
    let event: UntilEvent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let r = CountLogic.readout(for: event, now: ctx.date)
            let accent = event.accent.color
            let filled = event.filled
            let on = event.accent.onColor
            let big: Color = filled ? on : accent
            let title: Color = filled ? on : .primary
            let secondary: Color = filled ? on.opacity(0.85) : .secondary

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: event.symbol).font(.subheadline).foregroundStyle(filled ? on : accent)
                    Spacer()
                    if r.reached {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(filled ? on : accent)
                    }
                }
                Spacer(minLength: 4)
                Text(r.big)
                    .font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(big).lineLimit(1).minimumScaleFactor(0.5)
                Text(r.unit.isEmpty ? r.detail : r.unit)
                    .font(.caption2).foregroundStyle(secondary).lineLimit(1)
                Text(event.title)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(title).lineLimit(1)
            }
            .padding(16)
            .frame(height: 150, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(CardBackground(filled: filled, accent: accent))
        }
    }
}

// MARK: - Long-press preview

private struct EventPreview: View {
    let event: UntilEvent

    var body: some View {
        let r = CountLogic.readout(for: event)
        VStack(spacing: 10) {
            Image(systemName: event.symbol).font(.title).foregroundStyle(event.accent.color)
            Text(event.title).font(Theme.display(.title2).weight(.bold)).multilineTextAlignment(.center)
            Text(r.big)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(event.accent.color)
            Text(r.unit.isEmpty ? r.detail : r.unit)
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 260)
    }
}

// MARK: - Empty state

private struct EmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Nothing yet")
                .font(Theme.display(.title2).weight(.semibold))
            Text("Add a date to count down to — or a moment to count up from.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onAdd) {
                Label("Add event", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .padding(.top, 4)
        }
    }
}
