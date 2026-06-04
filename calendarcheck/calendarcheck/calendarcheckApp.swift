//
//  calendarcheckApp.swift
//  calendarcheck
//
//  Created by tope akintola on 04/06/2026.
//

import SwiftUI
import LocalAuthentication

@main
struct calendarcheckApp: App {
    @State private var store = CheckStore()
    @State private var settings = AppSettings()
    @State private var isUnlocked = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(store: store, settings: settings)

                if settings.appLock && !isUnlocked {
                    LockView { authenticate() }
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(settings.appearance.colorScheme)
            .animation(.easeInOut(duration: 0.2), value: isUnlocked)
            .onAppear {
                NotificationScheduler.requestAuthorization()
                store.scheduleSummaries()
                gate()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: gate()
                case .background: if settings.appLock { isUnlocked = false }
                default: break
                }
            }
        }
    }

    /// Decide whether to show content or prompt for Face ID.
    private func gate() {
        if settings.appLock {
            if !isUnlocked { authenticate() }
        } else {
            isUnlocked = true
        }
    }

    private func authenticate() {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock calendarcheck") { success, _ in
                DispatchQueue.main.async {
                    if success { isUnlocked = true }
                }
            }
        } else {
            // No biometrics or passcode set up — don't lock the user out.
            isUnlocked = true
        }
    }
}

// MARK: - Lock screen

struct LockView: View {
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .semibold))
                Text("Locked")
                    .font(Theme.display(.title2).weight(.semibold))
                Button(action: onUnlock) {
                    Label("Unlock", systemImage: "faceid")
                        .font(.headline)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
                .tint(.primary)
            }
        }
    }
}
