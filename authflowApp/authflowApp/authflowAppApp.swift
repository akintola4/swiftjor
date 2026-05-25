//
//  authflowAppApp.swift
//  authflowApp
//
//  Created by tope akintola on 13/12/2025.
//

import SwiftUI

@main
struct authflowAppApp: App {
    @AppStorage("hasCompletedOnboarding") var onboardingComplete: Bool = false
    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
                            // If complete, show the main app
                            MainView()
                        } else {
                            // If not complete, show the onboarding flow
                            ContentView()
                        }
        }
    }
}
