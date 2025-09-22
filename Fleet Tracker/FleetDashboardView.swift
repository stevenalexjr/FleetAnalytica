//
//  FleetDashboardView.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import SwiftUI
import Charts

struct FleetDashboardView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingTripDetails = false
    @State private var selectedTrip: Trip?
    
    enum TimeRange: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Status Card
                    currentStatusCard
                    
                    // Driver Score Card
                    driverScoreCard
                    
                    // Violations Summary
                    violationsCard
                    
                    // Recent Trips
                    recentTripsCard
                    
                    // Improvement Suggestions
                    improvementSuggestionsCard
                }
                .padding()
            }
            .navigationTitle("Fleet Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Button(range.rawValue) {
                                selectedTimeRange = range
                            }
                        }
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
        }
        .sheet(isPresented: $showingTripDetails) {
            if let trip = selectedTrip {
                TripDetailView(trip: trip)
            }
        }
        .onAppear {
            // Load trips and refresh speed limit in background
            Task.detached(priority: .background) {
                await MainActor.run {
                    locationViewModel.loadTrips()
                    locationViewModel.refreshSpeedLimit()
                }
            }
        }
    }
    
    private var currentStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.blue)
                Text("Current Status")
                    .font(.headline)
                Spacer()
                
                Button(action: {
                    locationViewModel.refreshSpeedLimit()
                }) {
                    Image(systemName: locationViewModel.isFetchingSpeedLimit ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .rotationEffect(.degrees(locationViewModel.isFetchingSpeedLimit ? 360 : 0))
                        .animation(locationViewModel.isFetchingSpeedLimit ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: locationViewModel.isFetchingSpeedLimit)
                }
                .disabled(locationViewModel.isFetchingSpeedLimit)
                
                if locationViewModel.trackingIsActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(locationViewModel.currentSpeed)) mph")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Speed Limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if locationViewModel.isFetchingSpeedLimit {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Getting speed limit")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if let limit = locationViewModel.speedLimit {
                        Text("\(Int(limit)) mph")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(locationViewModel.speedViolation ? .red : .primary)
                        
                        // Show speed limit source
                        Text({
                            let dataInfo = SpeedLimitDataManager.shared.getDataInfo()
                            if dataInfo.hasData {
                                return "OSM Local (\(dataInfo.totalRecords) records)"
                            } else {
                                return "OSM Live API"
                            }
                        }())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Unknown")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Tap refresh")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if locationViewModel.speedViolation {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Speed Violation Detected")
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                        
                        if let speedLimit = locationViewModel.speedLimit {
                            let overSpeed = Int(locationViewModel.currentSpeed - speedLimit)
                            Text("\(overSpeed) mph over limit")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var driverScoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Average Driver Score")
                    .font(.headline)
                Spacer()
                Text("\(Int(locationViewModel.drivingSummary.overallDriverScore))/100")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(locationViewModel.drivingSummary.overallDriverScore))
            }
            
            // Show trip count and current trip score if available
            HStack {
                Text("Based on \(locationViewModel.drivingSummary.totalTrips) trips")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let currentTrip = locationViewModel.currentTrip {
                    Text("Current: \(Int(currentTrip.driverScore))/100")
                        .font(.caption)
                        .foregroundColor(scoreColor(currentTrip.driverScore))
                }
            }
            
            // Score visualization
            HStack {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(index < Int(locationViewModel.drivingSummary.overallDriverScore / 20) ? Color.yellow : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                }
                Spacer()
            }
            
            Text(scoreDescription(locationViewModel.drivingSummary.overallDriverScore))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var violationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Violations Summary")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ViolationStatView(
                    title: "Speed Violations",
                    count: locationViewModel.drivingSummary.speedViolations,
                    icon: "speedometer",
                    color: .red
                )
                
                ViolationStatView(
                    title: "Hard Stops",
                    count: locationViewModel.drivingSummary.hardStops,
                    icon: "stop.circle",
                    color: .orange
                )
                
                ViolationStatView(
                    title: "Sharp Turns",
                    count: locationViewModel.drivingSummary.sharpTurns,
                    icon: "arrow.turn.up.right",
                    color: .yellow
                )
                
                ViolationStatView(
                    title: "Potholes",
                    count: locationViewModel.drivingSummary.potholesDetected,
                    icon: "exclamationmark.triangle",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var recentTripsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("Recent Trips")
                    .font(.headline)
                Spacer()
                Button("View All") {
                    // Navigate to trips list
                }
                .font(.caption)
            }
            
            ForEach(Array(locationViewModel.trips.prefix(3))) { trip in
                TripRowView(trip: trip) {
                    selectedTrip = trip
                    showingTripDetails = true
                }
            }
            
            if locationViewModel.trips.isEmpty {
                Text("No trips recorded yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var improvementSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Improvement Suggestions")
                    .font(.headline)
                Spacer()
            }
            
            if locationViewModel.drivingSummary.improvementSuggestions.isEmpty {
                Text("Great driving! Keep up the good work.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(locationViewModel.drivingSummary.improvementSuggestions, id: \.self) { suggestion in
                    HStack(alignment: .top) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(suggestion)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100: return .green
        case 70..<90: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }
    
    private func scoreDescription(_ score: Double) -> String {
        switch score {
        case 90...100: return "Excellent driving!"
        case 70..<90: return "Good driving with room for improvement"
        case 50..<70: return "Needs improvement"
        default: return "Requires attention"
        }
    }
}

struct ViolationStatView: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct TripRowView: View {
    let trip: Trip
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.startTime, style: .date)
                        .font(.headline)
                    Text(trip.startTime, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(trip.totalDistance / 1609.34)) mi")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(trip.driverScore >= 80 ? Color.green : trip.driverScore >= 60 ? Color.yellow : Color.red)
                            .frame(width: 8, height: 8)
                        Text("\(Int(trip.driverScore))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FleetDashboardView()
        .environmentObject(LocationViewModel())
}