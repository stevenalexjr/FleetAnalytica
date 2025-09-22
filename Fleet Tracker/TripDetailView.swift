//
//  TripDetailView.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import SwiftUI
import MapKit

struct TripDetailView: View {
    let trip: Trip
    @EnvironmentObject var locationViewModel: LocationViewModel
    @State private var showingMap = false
    @State private var showingViolations = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Trip Header
                tripHeaderCard
                
                // Trip Statistics
                tripStatisticsCard
                
                // Violations Summary
                violationsCard
                
                // Route Information
                routeCard
                
                // Actions
                actionsCard
            }
            .padding()
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingMap) {
            TripMapView(trip: trip)
        }
        .sheet(isPresented: $showingViolations) {
            TripViolationsView(trip: trip)
        }
    }
    
    // MARK: - Trip Header Card
    
    private var tripHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Trip #\(trip.id.prefix(8))")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(trip.driverScore))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(trip.driverScore))
                }
            }
            
            if let endTime = trip.endTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("Duration: \(formatDuration(trip.duration ?? 0))")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Trip Statistics Card
    
    private var tripStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trip Statistics")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatisticItem(
                    title: "Distance",
                    value: String(format: "%.2f mi", trip.totalDistance / 1609.34),
                    icon: "location.fill",
                    color: .blue
                )
                
                StatisticItem(
                    title: "Avg Speed",
                    value: String(format: "%.1f mph", trip.averageSpeed ?? 0),
                    icon: "speedometer",
                    color: .green
                )
                
                StatisticItem(
                    title: "Max Speed",
                    value: String(format: "%.1f mph", trip.maxSpeed ?? 0),
                    icon: "gauge.high",
                    color: .orange
                )
                
                StatisticItem(
                    title: "Fuel Used",
                    value: String(format: "%.1f gal", trip.fuelUsed),
                    icon: "fuelpump.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Violations Card
    
    private var violationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Violations")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("View All") {
                    showingViolations = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ViolationItem(
                    title: "Speed",
                    count: trip.speedViolations,
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
                
                ViolationItem(
                    title: "Hard Stops",
                    count: trip.hardStops,
                    icon: "stop.circle.fill",
                    color: .orange
                )
                
                ViolationItem(
                    title: "Sharp Turns",
                    count: trip.sharpTurns,
                    icon: "arrow.turn.up.right",
                    color: .yellow
                )
                
                ViolationItem(
                    title: "Potholes",
                    count: trip.potholesDetected,
                    icon: "circle.fill",
                    color: .brown
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Route Card
    
    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Information")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                
                VStack(alignment: .leading) {
                    Text("Start Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.4f", trip.startLocation.latitude)), \(String(format: "%.4f", trip.startLocation.longitude))")
                        .font(.subheadline)
                }
                
                Spacer()
            }
            
            if let endLocation = trip.endLocation {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text("End Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.4f", endLocation.latitude)), \(String(format: "%.4f", endLocation.longitude))")
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
            }
            
            if let destination = trip.destination {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Destination")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(destination)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
            }
            
            Button(action: {
                showingMap = true
            }) {
                HStack {
                    Image(systemName: "map.fill")
                    Text("View Route on Map")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Actions Card
    
    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack(spacing: 12) {
                Button(action: {
                    // Share trip details
                    shareTrip()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    // Export trip data
                    exportTrip()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Export")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100:
            return .green
        case 70..<90:
            return .yellow
        case 50..<70:
            return .orange
        default:
            return .red
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func shareTrip() {
        // Implementation for sharing trip details
        logger.info("Sharing trip: \(trip.id)")
    }
    
    private func exportTrip() {
        // Implementation for exporting trip data
        logger.info("Exporting trip: \(trip.id)")
    }
}

// MARK: - Supporting Views

struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct ViolationItem: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Trip Map View

struct TripMapView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Trip Map View")
                    .font(.title)
                    .padding()
                
                Text("Map implementation would go here")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Trip Route")
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

// MARK: - Trip Violations View

struct TripViolationsView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Trip Violations View")
                    .font(.title)
                    .padding()
                
                Text("Detailed violations would be shown here")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Violations")
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

#Preview {
    NavigationView {
        TripDetailView(trip: Trip.sampleTrip)
            .environmentObject(LocationViewModel())
    }
}

// MARK: - Trip Extension for Preview

extension Trip {
    static let sampleTrip = Trip(
        id: "sample-trip-123",
        deviceId: "sample-device",
        startTime: Date().addingTimeInterval(-3600),
        endTime: Date(),
        startLocation: CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458),
        endLocation: CLLocationCoordinate2D(latitude: 42.2808, longitude: -83.7430),
        totalDistance: 50000, // 50km
        averageSpeed: 45.0,
        maxSpeed: 65.0,
        speedViolations: 2,
        hardStops: 1,
        sharpTurns: 3,
        potholesDetected: 0,
        driverScore: 85.0,
        fuelUsed: 2.5,
        destination: "456 Oak Ave, Ann Arbor, MI"
    )
}
