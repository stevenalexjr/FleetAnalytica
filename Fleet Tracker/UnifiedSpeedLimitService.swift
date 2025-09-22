//
//  UnifiedSpeedLimitService.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Speed Limit Data Model

class SpeedLimitResult {
    let speedLimit: Double
    let confidence: SpeedLimitConfidence
    let source: SpeedLimitSource
    let roadName: String?
    let roadType: String?
    let timestamp: Date
    
    init(speedLimit: Double, confidence: SpeedLimitConfidence, source: SpeedLimitSource, roadName: String? = nil, roadType: String? = nil, timestamp: Date = Date()) {
        self.speedLimit = speedLimit
        self.confidence = confidence
        self.source = source
        self.roadName = roadName
        self.roadType = roadType
        self.timestamp = timestamp
    }
}

enum SpeedLimitConfidence: Double, CaseIterable {
    case high = 1.0
    case medium = 0.7
    case low = 0.4
    case veryLow = 0.1
}

enum SpeedLimitSource: String, CaseIterable {
    case detroitDatabase = "Detroit Database"
    case localOSM = "Local OSM"
    case liveOSM = "Live OSM"
    case appleMapKit = "Apple MapKit"
    case estimation = "Estimation"
    case reverseGeocoding = "Reverse Geocoding"
}

// MARK: - Unified Speed Limit Service

class UnifiedSpeedLimitService {
    static let shared = UnifiedSpeedLimitService()
    
    private let cache: NSCache<NSString, SpeedLimitResult> = NSCache()
    private let localDatabase = LocalSpeedLimitDatabase.shared
    private let detroitDatabase = DetroitSpeedLimitDatabase.shared
    private let geocoder = CLGeocoder()
    
    private init() {
        cache.countLimit = 1000
        cache.name = "SpeedLimitCache"
    }
    
    // MARK: - Public Interface
    
    func getSpeedLimit(for coordinate: CLLocationCoordinate2D) async -> SpeedLimitResult? {
        let cacheKey = getCacheKey(for: coordinate)
        
        // Check cache first
        if let cachedResult = cache.object(forKey: cacheKey) {
            return cachedResult
        }
        
        // Try different sources in order of preference
        let sources: [(CLLocationCoordinate2D) async -> SpeedLimitResult?] = [
            getDetroitSpeedLimit,
            getLocalOSMSpeedLimit,
            getLiveOSMSpeedLimit,
            getAppleMapKitSpeedLimit,
            getEstimatedSpeedLimit
        ]
        
        for source in sources {
            if let result = await source(coordinate) {
                cache.setObject(result, forKey: cacheKey)
                return result
            }
        }
        
        return nil
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    func getCacheStatistics() -> (count: Int, totalCapacity: Int) {
        return (count: cache.countLimit, totalCapacity: cache.countLimit)
    }
    
    // MARK: - Private Methods
    
    private func getCacheKey(for coordinate: CLLocationCoordinate2D) -> NSString {
        // Use high precision to avoid cross-street contamination
        let roundedLat = round(coordinate.latitude * 20000) / 20000
        let roundedLon = round(coordinate.longitude * 20000) / 20000
        return "\(roundedLat),\(roundedLon)" as NSString
    }
    
    // MARK: - Source Methods
    
    private func getDetroitSpeedLimit(for coordinate: CLLocationCoordinate2D) async -> SpeedLimitResult? {
        guard let speedLimit = detroitDatabase.getDetroitSpeedLimit(for: coordinate) else {
            return nil
        }
        
        return SpeedLimitResult(
            speedLimit: speedLimit,
            confidence: .high,
            source: .detroitDatabase,
            roadName: nil,
            roadType: nil,
            timestamp: Date()
        )
    }
    
    private func getLocalOSMSpeedLimit(for coordinate: CLLocationCoordinate2D) async -> SpeedLimitResult? {
        guard let data = localDatabase.getSpeedLimitWithDetails(for: coordinate) else {
            return nil
        }
        
        return SpeedLimitResult(
            speedLimit: data.speedLimit,
            confidence: .medium,
            source: .localOSM,
            roadName: data.roadName,
            roadType: data.roadType,
            timestamp: Date()
        )
    }
    
    private func getLiveOSMSpeedLimit(for coordinate: CLLocationCoordinate2D) async -> SpeedLimitResult? {
        // This would call the live OSM API
        // For now, return nil to avoid network calls
        return nil
    }
    
    private func getAppleMapKitSpeedLimit(for coordinate: CLLocationCoordinate2D) async -> SpeedLimitResult? {
        // Use reverse geocoding to get road information
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            
            if let speedLimit = estimateSpeedLimitFromPlacemark(placemark) {
                return SpeedLimitResult(
                    speedLimit: speedLimit,
                    confidence: .medium,
                    source: .reverseGeocoding,
                    roadName: placemark.thoroughfare,
                    roadType: placemark.subThoroughfare,
                    timestamp: Date()
                )
            }
        } catch {
            // Handle geocoding error silently
        }
        
        return nil
    }
    
    private func getEstimatedSpeedLimit(for coordinate: CLLocationCoordinate2D) async -> SpeedLimitResult? {
        let estimatedSpeed = estimateSpeedLimitFromCoordinate(coordinate)
        
        return SpeedLimitResult(
            speedLimit: estimatedSpeed,
            confidence: .veryLow,
            source: .estimation,
            roadName: nil,
            roadType: nil,
            timestamp: Date()
        )
    }
    
    // MARK: - Helper Methods
    
    private func estimateSpeedLimitFromPlacemark(_ placemark: CLPlacemark) -> Double? {
        guard let thoroughfare = placemark.thoroughfare else { return nil }
        let roadName = thoroughfare.lowercased()
        
        // Interstate/Freeway detection
        if roadName.contains("interstate") || roadName.contains("i-") || 
           roadName.contains("freeway") || roadName.contains("expressway") {
            return 70.0
        }
        
        // US Highway detection
        if roadName.contains("us route") || roadName.contains("us-") {
            return 65.0
        }
        
        // State Route detection
        if roadName.contains("state route") || roadName.contains("sr-") {
            return 55.0
        }
        
        // Major Arterial detection
        if roadName.contains("boulevard") || roadName.contains("avenue") {
            return 45.0
        }
        
        // Residential Street detection
        if roadName.contains("street") || roadName.contains("road") || 
           roadName.contains("lane") || roadName.contains("way") {
            return 35.0
        }
        
        return nil
    }
    
    private func estimateSpeedLimitFromCoordinate(_ coordinate: CLLocationCoordinate2D) -> Double {
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        
        // Urban areas (higher population density) - typically 25-35 mph
        if isUrbanArea(latitude: latitude, longitude: longitude) {
            return 30.0
        }
        
        // Suburban areas - typically 35-45 mph
        if isSuburbanArea(latitude: latitude, longitude: longitude) {
            return 40.0
        }
        
        // Highway/interstate areas - typically 55-75 mph
        if isHighwayArea(latitude: latitude, longitude: longitude) {
            return 65.0
        }
        
        // Rural areas - typically 45-55 mph
        return 50.0
    }
    
    private func isUrbanArea(latitude: Double, longitude: Double) -> Bool {
        // Major metropolitan areas
        let metropolitanAreas: [(lat: Double, lon: Double, radius: Double)] = [
            (42.3314, -83.0458, 0.3), // Detroit
            (40.7128, -74.0060, 0.3), // New York
            (34.0522, -118.2437, 0.4), // Los Angeles
            (41.8781, -87.6298, 0.3), // Chicago
        ]
        
        for area in metropolitanAreas {
            let distance = sqrt(pow(latitude - area.lat, 2) + pow(longitude - area.lon, 2))
            if distance <= area.radius {
                return true
            }
        }
        
        return false
    }
    
    private func isSuburbanArea(latitude: Double, longitude: Double) -> Bool {
        // Simplified suburban area detection
        return latitude >= 42.0 && latitude <= 42.8 && longitude >= -83.5 && longitude <= -82.5
    }
    
    private func isHighwayArea(latitude: Double, longitude: Double) -> Bool {
        // Check if coordinates are near known highway corridors
        let highwayCorridors: [(lat: Double, lon: Double, radius: Double)] = [
            (42.0, -83.0, 0.5), // I-75 corridor
            (42.0, -84.0, 0.5), // I-96 corridor
            (41.0, -83.0, 0.5), // I-94 corridor
        ]
        
        for corridor in highwayCorridors {
            let distance = sqrt(pow(latitude - corridor.lat, 2) + pow(longitude - corridor.lon, 2))
            if distance <= corridor.radius {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Extensions for NSCache

// SpeedLimitResult is now a class, so it automatically conforms to AnyObject for NSCache

// MARK: - Data Model Extensions

extension SpeedLimitResult {
    var confidencePercentage: Int {
        return Int(confidence.rawValue * 100)
    }
    
    var isReliable: Bool {
        return confidence.rawValue >= 0.7
    }
    
    var ageInMinutes: Int {
        return Int(Date().timeIntervalSince(timestamp) / 60)
    }
}
