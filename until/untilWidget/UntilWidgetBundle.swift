//
//  UntilWidgetBundle.swift
//  untilWidget
//
//  The widget extension's entry point. Without an @main WidgetBundle the
//  extension has no principal class and ExtensionKit crashes it at launch.
//

import WidgetKit
import SwiftUI

@main
struct UntilWidgetBundle: WidgetBundle {
    var body: some Widget {
        UntilWidget()
        UntilLiveActivity()
    }
}
