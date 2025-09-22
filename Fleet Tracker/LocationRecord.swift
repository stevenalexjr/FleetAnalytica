//
//  LocationRecord.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

struct LocationRecord: Identifiable, Codable {
    var id: String = UUID().uuidString
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var deviceId: String?
    var accuracy: Double?
    var altitude: Double?
    var speed: Double? // m/s
    var heading: Double? // degrees
    var course: Double? // degrees
    
    // Fleet tracking metrics
    var speedLimit: Double? // mph
    var speedViolation: Bool = false
    var hardStop: Bool = false
    var sharpTurn: Bool = false
    var potholeDetected: Bool = false
    var acceleration: Double? // m/s²
    var deceleration: Double? // m/s²
    var tripId: String?
    
    // Business metrics
    var fuelEfficiency: Double? // mpg
    var engineLoad: Double? // percentage
    var driverBehaviorScore: Double? // 0-100
    
    init(latitude: Double, longitude: Double, timestamp: Date = Date(), deviceId: String? = nil, accuracy: Double? = nil, altitude: Double? = nil, speed: Double? = nil, heading: Double? = nil, course: Double? = nil, speedLimit: Double? = nil, speedViolation: Bool = false, hardStop: Bool = false, sharpTurn: Bool = false, potholeDetected: Bool = false, acceleration: Double? = nil, deceleration: Double? = nil, tripId: String? = nil, fuelEfficiency: Double? = nil, engineLoad: Double? = nil, driverBehaviorScore: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.accuracy = accuracy
        self.altitude = altitude
        self.speed = speed
        self.heading = heading
        self.course = course
        self.speedLimit = speedLimit
        self.speedViolation = speedViolation
        self.hardStop = hardStop
        self.sharpTurn = sharpTurn
        self.potholeDetected = potholeDetected
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.tripId = tripId
        self.fuelEfficiency = fuelEfficiency
        self.engineLoad = engineLoad
        self.driverBehaviorScore = driverBehaviorScore
    }
    
    init(from location: CLLocation, deviceId: String? = nil, speedLimit: Double? = nil, tripId: String? = nil) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.deviceId = deviceId
        self.accuracy = location.horizontalAccuracy
        self.altitude = location.altitude
        self.speed = location.speed >= 0 ? location.speed : nil
        self.heading = location.course >= 0 ? location.course : nil
        self.course = location.course >= 0 ? location.course : nil
        self.speedLimit = speedLimit
        self.tripId = tripId
        
        // Speed violation detection is now handled in LocationViewModel with smart state tracking
        // This ensures violations only trigger once until speed drops below limit
        self.speedViolation = false // Will be set by LocationViewModel if needed
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var speedInMph: Double? {
        guard let speed = speed else { return nil }
        return speed * 2.237 // Convert m/s to mph
    }
    
    var speedInKph: Double? {
        guard let speed = speed else { return nil }
        return speed * 3.6 // Convert m/s to km/h
    }
}

// MARK: - Trip Management
struct Trip: Identifiable, Codable {
    var id: String = UUID().uuidString
    var deviceId: String?
    var startTime: Date
    var endTime: Date?
    var startLocationLatitude: Double
    var startLocationLongitude: Double
    var endLocationLatitude: Double?
    var endLocationLongitude: Double?
    var totalDistance: Double = 0.0 // meters
    var averageSpeed: Double = 0.0 // mph
    var maxSpeed: Double = 0.0 // mph
    var speedViolations: Int = 0
    var hardStops: Int = 0
    var sharpTurns: Int = 0
    var potholesDetected: Int = 0
    var driverScore: Double = 100.0 // 0-100
    var fuelUsed: Double = 0.0 // gallons
    var destination: String?
    
    // Computed properties for CLLocationCoordinate2D
    var startLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLocationLatitude, longitude: startLocationLongitude)
    }
    
    var endLocation: CLLocationCoordinate2D? {
        guard let lat = endLocationLatitude, let lon = endLocationLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    var isActive: Bool {
        return endTime == nil
    }
    
    // Custom initializer for CLLocationCoordinate2D
    init(id: String = UUID().uuidString, deviceId: String? = nil, startTime: Date, endTime: Date? = nil, startLocation: CLLocationCoordinate2D, endLocation: CLLocationCoordinate2D? = nil, totalDistance: Double = 0.0, averageSpeed: Double = 0.0, maxSpeed: Double = 0.0, speedViolations: Int = 0, hardStops: Int = 0, sharpTurns: Int = 0, potholesDetected: Int = 0, driverScore: Double = 100.0, fuelUsed: Double = 0.0, destination: String? = nil) {
        self.id = id
        self.deviceId = deviceId
        self.startTime = startTime
        self.endTime = endTime
        self.startLocationLatitude = startLocation.latitude
        self.startLocationLongitude = startLocation.longitude
        self.endLocationLatitude = endLocation?.latitude
        self.endLocationLongitude = endLocation?.longitude
        self.totalDistance = totalDistance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.speedViolations = speedViolations
        self.hardStops = hardStops
        self.sharpTurns = sharpTurns
        self.potholesDetected = potholesDetected
        self.driverScore = driverScore
        self.fuelUsed = fuelUsed
        self.destination = destination
    }
}

// MARK: - Driving Behavior Summary
struct DrivingBehaviorSummary: Codable {
    var totalTrips: Int = 0
    var totalDistance: Double = 0.0 // miles
    var totalTime: TimeInterval = 0.0 // seconds
    var averageSpeed: Double = 0.0 // mph
    var maxSpeed: Double = 0.0 // mph
    var speedViolations: Int = 0
    var hardStops: Int = 0
    var sharpTurns: Int = 0
    var potholesDetected: Int = 0
    var overallDriverScore: Double = 100.0 // 0-100
    var fuelEfficiency: Double = 0.0 // mpg
    var mostFrequentViolations: [String] = []
    var improvementSuggestions: [String] = []
    
    var totalViolations: Int {
        return speedViolations + hardStops + sharpTurns + potholesDetected
    }
    
    var safetyScore: Double {
        let violationPenalty = Double(totalViolations) * 2.0
        return max(0, 100.0 - violationPenalty)
    }
}

// MARK: - Extensions
extension CLLocationCoordinate2D {
    func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}
