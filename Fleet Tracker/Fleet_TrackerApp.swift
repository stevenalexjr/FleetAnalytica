//
//  Fleet_TrackerApp.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import SwiftUI
import SwiftData
import Firebase

@main
struct Fleet_TrackerApp: App {
    @StateObject private var locationViewModel = LocationViewModel()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Validate configuration before starting
        if ConfigurationManager.shared.validateConfiguration() {
            FirebaseApp.configure()
        } else {
            fatalError("Configuration validation failed")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
