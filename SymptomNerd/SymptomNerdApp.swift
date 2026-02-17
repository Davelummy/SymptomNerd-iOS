//
//  SymptomNerdApp.swift
//  SymptomNerd
//
//  Created by Dave Lummy on 1/31/26.
//

import SwiftUI
import SwiftData
import FirebaseCore
#if canImport(UIKit)
import UIKit
#endif

@main
struct SymptomNerdApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    private let container: DIContainer
    private let modelContainer: ModelContainer

    init() {
        if FirebaseApp.app() == nil {
            if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                FirebaseApp.configure()
            } else {
                NSLog("Missing GoogleService-Info.plist in app bundle target membership.")
            }
        }
        container = DIContainer()
        container.authManager.startListening()
        let schema = Schema([SymptomEntryRecord.self])
        modelContainer = Self.makeModelContainer(schema: schema)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container.appState)
                .environment(container.aiConsentManager)
                .environment(container.aiSettings)
                .environment(container.authManager)
                .environment(container.themeSettings)
                .environment(container.securitySettings)
                .task {
                    await NotificationClient().configureWellnessNotifications()
                }
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer(schema: Schema) -> ModelContainer {
        let diskConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [diskConfig])
        } catch {
            NSLog("SwiftData disk container failed, using in-memory fallback: \(error)")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Failed to create any ModelContainer: \(error)")
            }
        }
    }
}
