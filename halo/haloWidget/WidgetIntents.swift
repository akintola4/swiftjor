//
//  WidgetIntents.swift
//  haloWidget
//
//  One configurable widget covers both faces — long-press to switch Sun ↔ Moon.
//

import AppIntents
import WidgetKit

enum WidgetFace: String, AppEnum {
    case sun, moon

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Face" }
    static var caseDisplayRepresentations: [WidgetFace: DisplayRepresentation] {
        [.sun: "Sun", .moon: "Moon"]
    }

    /// Deep link so a tapped widget opens the matching tab (`halo://sun`).
    var url: URL? { URL(string: "halo://\(rawValue)") }
}

struct SelectFaceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Select Face" }
    static var description: IntentDescription { IntentDescription("Show the Sun or the Moon.") }

    // Moon needs no location, so it's the safe default under free signing.
    @Parameter(title: "Face", default: .moon)
    var face: WidgetFace

    init() {}
    init(face: WidgetFace) { self.face = face }
}
