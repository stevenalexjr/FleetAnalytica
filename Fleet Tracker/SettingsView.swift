//
//  SettingsView.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    @State private var showingLocationPermissionAlert = false
    @State private var showingBackgroundPermissionAlert = false
    @State private var showingDataManagement = false
    @State private var showingAbout = false
    
    // Secret debug menu
    @State private var debugTapCount = 0
    @State private var showingSecretDebugMenu = false
    @State private var lastDebugTapTime = Date()
    
    var body: some View {
        NavigationView {
            List {
                // Location Status Section
                locationStatusSection
                
                // Device Information Section
                deviceInfoSection
                
                // Location Data Section
                locationDataSection
                
                // Speed Limit Data Section
                speedLimitDataSection
                
                // Automatic Trip Detection Section
                automaticTripDetectionSection
                
                // Driver Score Section
                driverScoreSection
                
                // Motion Detection Thresholds Section
                motionDetectionSection
                
                // Data Management Section
                dataManagementSection
                
                // App Information Section
                appInfoSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingDataManagement) {
                DataManagementView()
                    .environmentObject(locationViewModel)
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingSecretDebugMenu) {
                SecretDebugMenuView()
                    .environmentObject(locationViewModel)
            }
            .alert("Location Permission Required", isPresented: $showingLocationPermissionAlert) {
                Button("Open Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable location access in Settings to use Fleet Tracker.")
            }
            .alert("Background Location Required", isPresented: $showingBackgroundPermissionAlert) {
                Button("Open Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable background location updates in Settings for continuous tracking.")
            }
        }
    }
    
    // MARK: - Location Status Section
    
    private var locationStatusSection: some View {
        Section("Location Status") {
            HStack {
                Image(systemName: locationStatusIcon)
                    .foregroundColor(locationStatusColor)
                Text("Location Services")
                Spacer()
                Text(locationStatusText)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: trackingStatusIcon)
                    .foregroundColor(trackingStatusColor)
                Text("Tracking Status")
                Spacer()
                Text(trackingStatusText)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: backgroundStatusIcon)
                    .foregroundColor(backgroundStatusColor)
                Text("Background Updates")
                Spacer()
                Text(backgroundStatusText)
                    .foregroundColor(.secondary)
            }
            
            if let error = locationViewModel.locationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Error")
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
    
    // MARK: - Device Information Section
    
    private var deviceInfoSection: some View {
        Section("Device Information") {
            HStack {
                Text("Device ID")
                Spacer()
                Text(locationViewModel.deviceId.prefix(8) + "...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            HStack {
                Text("Current Speed")
                Spacer()
                Text("\(Int(locationViewModel.currentSpeed)) mph")
                    .foregroundColor(.secondary)
            }
            
            if let speedLimit = locationViewModel.speedLimit {
                HStack {
                    Text("Speed Limit")
                    Spacer()
                    Text("\(Int(speedLimit)) mph")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Location Count")
                Spacer()
                Text("\(locationViewModel.locationHistory.count)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Trip Count")
                Spacer()
                Text("\(locationViewModel.trips.count)")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Location Data Section
    
    private var locationDataSection: some View {
        Section("Location Data") {
            Button("Start Tracking") {
                locationViewModel.startTracking()
            }
            .disabled(locationViewModel.trackingIsActive)
            
            Button("Stop Tracking") {
                locationViewModel.stopTracking()
            }
            .disabled(!locationViewModel.trackingIsActive)
            
            Button("Request Location Permission") {
                if locationViewModel.authorizationStatus == .denied {
                    showingLocationPermissionAlert = true
                } else {
                    locationViewModel.requestLocationPermission()
                }
            }
            
            Button("Enable Background Tracking") {
                if locationViewModel.authorizationStatus != .authorizedAlways {
                    showingBackgroundPermissionAlert = true
                } else {
                    locationViewModel.enableBackgroundLocationUpdates()
                }
            }
            
            Button("Refresh Speed Limit") {
                locationViewModel.refreshSpeedLimit()
            }
            .disabled(locationViewModel.isFetchingSpeedLimit)
        }
    }
    
    // MARK: - Speed Limit Data Section
    
    private var speedLimitDataSection: some View {
        Section("Speed Limit Data") {
            Button("Download Detroit Speed Limits") {
                Task {
                    await SpeedLimitDataManager.shared.setupDetroitData()
                }
            }
            
            Button("Test Detroit Locations") {
                Task {
                    await SpeedLimitDataManager.shared.testDetroitLocations()
                }
            }
            
            Button("Clear Speed Limit Cache") {
                locationViewModel.clearSpeedLimitCache()
            }
            
            Button("Download All Detroit Speed Limits") {
                Task {
                    await locationViewModel.downloadAllDetroitSpeedLimits()
                }
            }
        }
    }
    
    // MARK: - Automatic Trip Detection Section
    
    private var automaticTripDetectionSection: some View {
        Section("Automatic Trip Detection") {
            let status = locationViewModel.getAutomaticTripStatus()
            
            HStack {
                Text("Status")
                Spacer()
                Text(status.isEnabled ? (status.isDriving ? "Driving" : "Monitoring") : "Disabled")
                    .foregroundColor(status.isEnabled ? (status.isDriving ? .green : .blue) : .gray)
            }
            
            HStack {
                Text("Start Threshold")
                Spacer()
                Text("\(Int(status.startThreshold)) mph")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Stop Threshold")
                Spacer()
                Text("\(Int(status.stopThreshold)) mph")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Stop Duration")
                Spacer()
                Text("\(Int(status.stopDuration / 60)) minutes")
                    .foregroundColor(.secondary)
            }
            
            Button(status.isEnabled ? "Disable Auto Trip Detection" : "Enable Auto Trip Detection") {
                if status.isEnabled {
                    locationViewModel.disableAutomaticTripDetection()
                } else {
                    locationViewModel.enableAutomaticTripDetection()
                }
            }
            .foregroundColor(status.isEnabled ? .red : .green)
            
            Button("Configure Speed Thresholds") {
                // TODO: Add configuration UI
            }
            
            Button("Configure Stop Duration") {
                // TODO: Add configuration UI
            }
        }
    }
    
    // MARK: - Driver Score Section
    
    private var driverScoreSection: some View {
        Section("Driver Score") {
            let currentScore = locationViewModel.getCurrentDriverScore()
            let impact = locationViewModel.getDriverScoreImpact()
            
            HStack {
                Text("Current Score")
                Spacer()
                Text("\(Int(currentScore))/100")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(currentScore))
            }
            
            if impact.totalDeduction > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Violation Impact")
                        .font(.headline)
                    
                    HStack {
                        Text("Speed Violations")
                        Spacer()
                        Text("\(impact.speedViolations) × 5 = -\(Int(Double(impact.speedViolations) * 5.0))")
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Hard Stops")
                        Spacer()
                        Text("\(impact.hardStops) × 3 = -\(Int(Double(impact.hardStops) * 3.0))")
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Text("Sharp Turns")
                        Spacer()
                        Text("\(impact.sharpTurns) × 2 = -\(Int(Double(impact.sharpTurns) * 2.0))")
                            .foregroundColor(.yellow)
                    }
                    
                    HStack {
                        Text("Potholes")
                        Spacer()
                        Text("\(impact.potholes) × 1 = -\(Int(Double(impact.potholes) * 1.0))")
                            .foregroundColor(.purple)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total Deduction")
                            .fontWeight(.bold)
                        Spacer()
                        Text("-\(Int(impact.totalDeduction))")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Button("Reset Current Trip Score") {
                locationViewModel.resetCurrentTripScore()
            }
            .foregroundColor(.blue)
            .disabled(locationViewModel.currentTrip == nil)
            
            // Show average score breakdown
            let breakdown = locationViewModel.getDriverScoreBreakdown()
            if breakdown.totalTrips > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average Score Breakdown")
                        .font(.headline)
                    
                    HStack {
                        Text("Average Score")
                        Spacer()
                        Text("\(String(format: "%.1f", breakdown.average))/100")
                            .foregroundColor(scoreColor(breakdown.average))
                    }
                    
                    HStack {
                        Text("Score Range")
                        Spacer()
                        Text("\(Int(breakdown.scoreRange.min)) - \(Int(breakdown.scoreRange.max))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Trips")
                        Spacer()
                        Text("\(breakdown.totalTrips)")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var motionDetectionSection: some View {
        Section("Motion Detection Thresholds") {
            let thresholds = locationViewModel.customMotionManager.getCurrentThresholds()
            
            HStack {
                Text("Sharp Turn Threshold")
                Spacer()
                Text("\(Int(thresholds.sharpTurn))°")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Hard Stop Threshold")
                Spacer()
                Text("\(String(format: "%.1f", thresholds.hardStop)) m/s²")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Pothole Vertical Threshold")
                Spacer()
                Text("\(String(format: "%.1f", thresholds.potholeVertical))g")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Pothole Total Threshold")
                Spacer()
                Text("\(String(format: "%.1f", thresholds.potholeTotal))g")
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Research-Based Adjustments")
                    .font(.headline)
                
                Text("• Sharp turns: Adjusted from 25° to 40° based on research")
                Text("• Normal turns: 15-30° heading changes")
                Text("• Sharp turns: 45°+ heading changes")
                Text("• Reduces false positives from normal driving")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Button("Reset to Research-Based Defaults") {
                locationViewModel.customMotionManager.setSharpTurnThreshold(40.0)
            }
            .foregroundColor(.blue)
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100: return .green
        case 70..<90: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }
    
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        Section("Data Management") {
            Button("Data Management") {
                showingDataManagement = true
            }
            
            Button("Export Data") {
                // Implementation for data export
                logger.info("Exporting data")
            }
            
            Button("Clear Local Data") {
                // Implementation for clearing local data
                logger.info("Clearing local data")
            }
        }
    }
    
    // MARK: - App Information Section
    
    private var appInfoSection: some View {
        Section("App Information") {
            Button("About Fleet Tracker") {
                showingAbout = true
            }
            
            Button("Privacy Policy") {
                // Open privacy policy
                logger.info("Opening privacy policy")
            }
            
            Button("Terms of Service") {
                // Open terms of service
                logger.info("Opening terms of service")
            }
            
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            .onTapGesture {
                handleSecretDebugTap()
            }
        }
    }
    
    // MARK: - Secret Debug Menu
    
    private func handleSecretDebugTap() {
        let now = Date()
        
        // Reset counter if more than 2 seconds have passed since last tap
        if now.timeIntervalSince(lastDebugTapTime) > 2.0 {
            debugTapCount = 0
        }
        
        debugTapCount += 1
        lastDebugTapTime = now
        
        // Show secret debug menu after 5 taps
        if debugTapCount >= 5 {
            showingSecretDebugMenu = true
            debugTapCount = 0 // Reset counter
            logger.info("🔓 Secret debug menu activated!")
        }
    }
    
    // MARK: - Helper Properties
    
    private var locationStatusIcon: String {
        switch locationViewModel.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "location.fill"
        case .denied, .restricted:
            return "location.slash.fill"
        case .notDetermined:
            return "location.circle"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var locationStatusColor: Color {
        switch locationViewModel.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var locationStatusText: String {
        switch locationViewModel.authorizationStatus {
        case .authorizedWhenInUse:
            return "When In Use"
        case .authorizedAlways:
            return "Always"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var trackingStatusIcon: String {
        locationViewModel.trackingIsActive ? "play.circle.fill" : "pause.circle.fill"
    }
    
    private var trackingStatusColor: Color {
        locationViewModel.trackingIsActive ? .green : .gray
    }
    
    private var trackingStatusText: String {
        locationViewModel.trackingIsActive ? "Active" : "Inactive"
    }
    
    private var backgroundStatusIcon: String {
        locationViewModel.isBackgroundTrackingEnabled ? "moon.fill" : "moon"
    }
    
    private var backgroundStatusColor: Color {
        locationViewModel.isBackgroundTrackingEnabled ? .blue : .gray
    }
    
    private var backgroundStatusText: String {
        locationViewModel.isBackgroundTrackingEnabled ? "Enabled" : "Disabled"
    }
    
    // MARK: - Helper Methods
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Local Data") {
                    HStack {
                        Text("Location Records")
                        Spacer()
                        Text("\(locationViewModel.locationHistory.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Trips")
                        Spacer()
                        Text("\(locationViewModel.trips.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Recent Violations")
                        Spacer()
                        Text("\(locationViewModel.recentViolations.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Actions") {
                    Button("Clear Location History") {
                        locationViewModel.locationHistory.removeAll()
                    }
                    .foregroundColor(.red)
                    
                    Button("Clear Trips") {
                        locationViewModel.trips.removeAll()
                    }
                    .foregroundColor(.red)
                    
                    Button("Clear Recent Violations") {
                        locationViewModel.recentViolations.removeAll()
                    }
                    .foregroundColor(.red)
                }
                
                Section("Cache") {
                    Button("Clear Speed Limit Cache") {
                        locationViewModel.clearSpeedLimitCache()
                    }
                    
                    Button("Clear All Caches") {
                        // Clear all caches
                        logger.info("Clearing all caches")
                    }
                }
            }
            .navigationTitle("Data Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "car.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Fleet Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Professional fleet tracking and driver behavior analysis")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Text("Features:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "location.fill", text: "Real-time location tracking")
                        FeatureRow(icon: "speedometer", text: "Speed limit detection")
                        FeatureRow(icon: "exclamationmark.triangle", text: "Violation monitoring")
                        FeatureRow(icon: "chart.bar", text: "Driver behavior analysis")
                        FeatureRow(icon: "map", text: "Route optimization")
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
        }
    }
}

// MARK: - Secret Debug Menu View

struct SecretDebugMenuView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("🔓 Secret Debug Menu") {
                    Text("Welcome to the secret debug menu!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Tap the version number 5 times to access this menu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Violation Testing Section (moved from main settings)
                violationTestingSection
                
                // Firebase Operations Section (moved from main settings)
                firebaseOperationsSection
                
                // Advanced Motion Detection Section
                advancedMotionDetectionSection
                
                // Debug Information Section
                debugInfoSection
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Debug Sections (moved from main SettingsView)
    
    private var violationTestingSection: some View {
        Section("Violation Testing") {
            Button("Test Speed Violation Detection") {
                locationViewModel.testSpeedViolationDetection()
            }
            
            Button("Test Hard Stop Detection") {
                locationViewModel.testHardStopDetection()
            }
            
            Button("Test Sharp Turn Detection") {
                locationViewModel.testSharpTurnDetection()
            }
            
            Button("Test Pothole Detection") {
                locationViewModel.testPotholeDetection()
            }
            
            Button("Show Violation Statistics") {
                locationViewModel.showViolationStats()
            }
        }
    }
    
    private var firebaseOperationsSection: some View {
        Section("Firebase Operations") {
            Button("Force Save to Firebase") {
                locationViewModel.forceFirebaseSave()
            }
            
            Button("Load Trips from Firebase") {
                locationViewModel.loadTrips()
            }
            
            Button("Clear Location History") {
                locationViewModel.clearLocationHistory()
            }
            
            Button("Clear Speed Limit Cache") {
                locationViewModel.clearSpeedLimitCache()
            }
        }
    }
    
    private var advancedMotionDetectionSection: some View {
        Section("Advanced Motion Detection") {
            let thresholds = locationViewModel.customMotionManager.getCurrentThresholds()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Thresholds")
                    .font(.headline)
                
                HStack {
                    Text("Sharp Turn:")
                    Spacer()
                    Text("\(Int(thresholds.sharpTurn))°")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Hard Stop:")
                    Spacer()
                    Text("\(String(format: "%.1f", thresholds.hardStop)) m/s²")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Pothole Vertical:")
                    Spacer()
                    Text("\(String(format: "%.1f", thresholds.potholeVertical))g")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Pothole Total:")
                    Spacer()
                    Text("\(String(format: "%.1f", thresholds.potholeTotal))g")
                        .foregroundColor(.secondary)
                }
            }
            
            Button("Reset All Thresholds to Defaults") {
                locationViewModel.customMotionManager.setSharpTurnThreshold(40.0)
            }
        }
    }
    
    private var debugInfoSection: some View {
        Section("Debug Information") {
            HStack {
                Text("Device ID")
                Spacer()
                Text(locationViewModel.deviceId)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            HStack {
                Text("Current Trip")
                Spacer()
                Text(locationViewModel.currentTrip?.id ?? "None")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            HStack {
                Text("Location Records")
                Spacer()
                Text("\(locationViewModel.locationHistory.count)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Total Trips")
                Spacer()
                Text("\(locationViewModel.trips.count)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Recent Violations")
                Spacer()
                Text("\(locationViewModel.recentViolations.count)")
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LocationViewModel())
}
