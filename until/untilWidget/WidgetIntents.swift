//
//  Intents.swift
//  untilWidget
//
//  Configurable-widget plumbing: an entity per event, the selection intent the
//  widget gallery edits, and the interactive reset for `since` events.
//

import AppIntents
import WidgetKit

// MARK: - Event entity (for widget configuration)

struct EventEntity: AppEntity {
    let id: UUID
    let title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Event" }
    static var defaultQuery = EventQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct EventQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [EventEntity] {
        EventStore.loadEvents()
            .filter { identifiers.contains($0.id) }
            .map { EventEntity(id: $0.id, title: $0.title) }
    }

    func suggestedEntities() async throws -> [EventEntity] {
        EventStore.loadEvents().map { EventEntity(id: $0.id, title: $0.title) }
    }
}

// MARK: - Widget configuration intent

struct SelectEventIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Select Event" }
    static var description: IntentDescription { IntentDescription("Choose which event this widget shows.") }

    @Parameter(title: "Event")
    var event: EventEntity?

    init() {}
    init(event: EventEntity?) { self.event = event }
}

// MARK: - Interactive reset (since events)

struct ResetSinceIntent: AppIntent {
    static var title: LocalizedStringResource { "Reset Counter" }
    // Not a user-facing Shortcuts action — only invoked from the widget button.
    // Leaving it discoverable makes ExtensionKit treat the widget extension as an
    // intents extension and fail to launch ("EXExtensionContextClass not defined").
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Event ID", default: "")
    var eventID: String

    init() {}
    init(eventID: UUID) { self.eventID = eventID.uuidString }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: eventID) {
            EventStore.resetSince(id: id)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}
