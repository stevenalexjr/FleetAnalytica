//
//  ContentView.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import SwiftUI
import SwiftData
import CoreLocation

@available(iOS 17.0, *)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var locationViewModel: LocationViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Fleet Dashboard
            FleetDashboardView()
                .environmentObject(locationViewModel)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            // Main Map View
            MapView()
                .environmentObject(locationViewModel)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }
                .tag(1)
            
            // Location History
            LocationHistoryView()
                .environmentObject(locationViewModel)
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
                .tag(2)
            
            // Settings/Info
            SettingsView()
                .environmentObject(locationViewModel)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .onAppear {
            // Load location history in background to avoid blocking UI
            Task.detached(priority: .background) {
                await MainActor.run {
                    locationViewModel.loadLocationHistory()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationViewModel())
        .modelContainer(for: [], inMemory: true)
}