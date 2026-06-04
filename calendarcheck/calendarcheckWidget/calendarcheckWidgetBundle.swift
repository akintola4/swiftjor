//
//  calendarcheckWidgetBundle.swift
//  calendarcheckWidget
//
//  Created by tope akintola on 04/06/2026.
//

import WidgetKit
import SwiftUI

@main
struct calendarcheckWidgetBundle: WidgetBundle {
    var body: some Widget {
        MonthWidget()
        StreakWidget()
        LargeWidget()
        MilestoneWidget()
        HeatmapWidget()
        LockWidget()
    }
}
