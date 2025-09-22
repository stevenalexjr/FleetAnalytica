//
//  TripManager.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Trip Manager

class TripManager: ObservableObject {
    private let logger = Logger.shared
    private let errorHandler = ErrorHandler.shared
    private let dataPersistenceManager = DataPersistenceManager.shared
    private let dataValidator = DataValidator.shared
    
    @Published var currentTrip: Trip?
    @Published var trips: [Trip] = []
    @Published var drivingSummary: DrivingBehaviorSummary = DrivingBehaviorSummary()
    
    private let deviceId: String
    
    init(deviceId: String) {
        self.deviceId = deviceId
    }
    
    // MARK: - Trip Management
    
    func startNewTrip(destination: String = "") async {
        guard let startLocation = getCurrentLocation() else {
            logger.warning("Cannot start trip without current location")
            return
        }
        
        let newTrip = Trip(
            id: UUID().uuidString,
            deviceId: deviceId,
            startTime: Date(),
            endTime: nil,
            startLocation: startLocation,
            endLocation: nil,
            totalDistance: 0,
            averageSpeed: 0.0,
            maxSpeed: 0.0,
            speedViolations: 0,
            hardStops: 0,
            sharpTurns: 0,
            potholesDetected: 0,
            driverScore: 100.0,
            fuelUsed: 0.0,
            destination: destination.isEmpty ? nil : destination
        )
        
        logger.info("Starting new trip: \(newTrip.id)")
        logger.locationUpdate("Start location: \(startLocation.latitude), \(startLocation.longitude)")
        logger.info("Destination: \(destination.isEmpty ? "None" : destination)")
        
        DispatchQueue.main.async {
            self.currentTrip = newTrip
            self.logger.info("New trip created and set as current trip")
        }
    }
    
    func endCurrentTrip() async {
        guard var trip = currentTrip else {
            logger.warning("No current trip to end")
            return
        }
        
        logger.info("Ending trip: \(trip.id)")
        
        // Set end time and location
        trip.endTime = Date()
        if let endLocation = getCurrentLocation() {
            trip.endLocationLatitude = endLocation.latitude
            trip.endLocationLongitude = endLocation.longitude
        }
        
        // Calculate final statistics
        // duration is computed property, no need to set it
        trip.driverScore = calculateDriverScore(for: trip)
        
        logger.info("Final trip stats: Distance: \(String(format: "%.2f", trip.totalDistance/1609.34)) miles, Duration: \(String(format: "%.1f", trip.duration ?? 0))s")
        logger.info("Final violations: Speed: \(trip.speedViolations), Hard stops: \(trip.hardStops), Sharp turns: \(trip.sharpTurns), Potholes: \(trip.potholesDetected)")
        
        // Save trip
        await dataPersistenceManager.saveTrip(trip)
        
        DispatchQueue.main.async {
            self.trips.append(trip)
            self.currentTrip = nil
            self.updateDrivingSummary()
            self.logger.info("Trip added to local trips array. Total trips: \(self.trips.count)")
        }
    }
    
    func updateTripWithLocation(_ location: CLLocation, speedLimit: Double?, violations: LocationViolations) {
        guard var trip = currentTrip else { return }
        
        // Update distance
        if let previousLocation = getPreviousLocation() {
            let distance = location.distance(from: previousLocation)
            trip.totalDistance += distance
        }
        
        // Update speed statistics
        let speedMph = location.speed * 2.237 // Convert m/s to mph
        if speedMph > trip.maxSpeed {
            trip.maxSpeed = speedMph
        }
        
        // Update violations
        var violationAdded = false
        
        if violations.speedViolation {
            trip.speedViolations += 1
            violationAdded = true
            logger.violation("SPEED VIOLATION added to trip - Total: \(trip.speedViolations)")
        }
        
        if violations.hardStop {
            trip.hardStops += 1
            violationAdded = true
            logger.violation("HARD STOP added to trip - Total: \(trip.hardStops)")
        }
        
        if violations.sharpTurn {
            trip.sharpTurns += 1
            violationAdded = true
            logger.violation("SHARP TURN added to trip - Total: \(trip.sharpTurns)")
        }
        
        if violations.potholeDetected {
            trip.potholesDetected += 1
            violationAdded = true
            logger.violation("POTHOLE detected and added to trip - Total: \(trip.potholesDetected)")
        }
        
        // Update driver score
        trip.driverScore = calculateDriverScore(for: trip)
        
        DispatchQueue.main.async {
            self.currentTrip = trip
        }
    }
    
    // MARK: - Data Loading
    
    func loadTrips() async {
        logger.info("Loading trips from storage for device: \(deviceId)")
        
        let loadedTrips = await dataPersistenceManager.loadTrips(deviceId: deviceId)
        
        DispatchQueue.main.async {
            self.trips = loadedTrips
            self.updateDrivingSummary()
            self.logger.info("Total trips loaded: \(loadedTrips.count)")
        }
    }
    
    // MARK: - Statistics
    
    private func updateDrivingSummary() {
        let totalTrips = trips.count
        let totalSpeedViolations = trips.reduce(0) { $0 + $1.speedViolations }
        let totalHardStops = trips.reduce(0) { $0 + $1.hardStops }
        let totalSharpTurns = trips.reduce(0) { $0 + $1.sharpTurns }
        let totalPotholes = trips.reduce(0) { $0 + $1.potholesDetected }
        
        let averageScore = totalTrips > 0 ? trips.reduce(0) { $0 + $1.driverScore } / Double(totalTrips) : 100.0
        
        drivingSummary = DrivingBehaviorSummary(
            totalTrips: totalTrips,
            speedViolations: totalSpeedViolations,
            hardStops: totalHardStops,
            sharpTurns: totalSharpTurns,
            potholesDetected: totalPotholes,
            overallDriverScore: averageScore
        )
        
        logger.info("Driving summary updated: \(totalTrips) trips, Score: \(String(format: "%.1f", averageScore))")
    }
    
    private func calculateDriverScore(for trip: Trip) -> Double {
        var score = 100.0
        
        // Deduct points for violations
        score -= Double(trip.speedViolations) * 5.0 // 5 points per speed violation
        score -= Double(trip.hardStops) * 3.0 // 3 points per hard stop
        score -= Double(trip.sharpTurns) * 2.0 // 2 points per sharp turn
        score -= Double(trip.potholesDetected) * 1.0 // 1 point per pothole (not driver's fault)
        
        // Ensure score doesn't go below 0
        return max(0.0, score)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentLocation() -> CLLocationCoordinate2D? {
        // This would be injected from LocationManager
        // For now, return a default location
        return CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458)
    }
    
    private func getPreviousLocation() -> CLLocation? {
        // This would track the previous location
        // For now, return nil
        return nil
    }
    
    // MARK: - Testing Methods
    
    func testTripCreation() {
        logger.info("Testing trip creation...")
        
        Task {
            await startNewTrip(destination: "Test Destination")
            
            // Simulate some trip data
            if var trip = currentTrip {
                trip.speedViolations = 2
                trip.hardStops = 1
                trip.sharpTurns = 3
                trip.potholesDetected = 0
                trip.totalDistance = 5000 // 5km
                trip.maxSpeed = 65.0
                trip.driverScore = calculateDriverScore(for: trip)
                
                DispatchQueue.main.async {
                    self.currentTrip = trip
                }
                
                logger.info("Test trip created with violations: Speed: \(trip.speedViolations), Hard stops: \(trip.hardStops), Sharp turns: \(trip.sharpTurns)")
            }
        }
    }
    
    func getTripStatistics() -> TripStatistics {
        let totalDistance = trips.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = trips.compactMap { $0.duration }.reduce(0, +)
        let averageScore = trips.isEmpty ? 100.0 : trips.reduce(0) { $0 + $1.driverScore } / Double(trips.count)
        
        return TripStatistics(
            totalTrips: trips.count,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            averageScore: averageScore,
            currentTripActive: currentTrip != nil
        )
    }
}

// MARK: - Supporting Types

struct LocationViolations {
    var speedViolation: Bool
    var hardStop: Bool
    var sharpTurn: Bool
    var potholeDetected: Bool
    
    var hasAnyViolation: Bool {
        return speedViolation || hardStop || sharpTurn || potholeDetected
    }
}

struct TripStatistics {
    let totalTrips: Int
    let totalDistance: Double
    let totalDuration: TimeInterval
    let averageScore: Double
    let currentTripActive: Bool
    
    var formattedTotalDistance: String {
        return String(format: "%.2f mi", totalDistance / 1609.34)
    }
    
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
