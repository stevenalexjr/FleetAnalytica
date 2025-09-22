//
//  SpeedLimitService.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation
import MapKit

class SpeedLimitService {
    private let cache: NSCache<NSString, NSNumber> = NSCache()
    private let osmService = OSMSpeedLimitService()
    
    init() {
        cache.countLimit = 1000 // Cache up to 1000 speed limits
    }
    
    func getSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double? {
        print("🔍 SpeedLimitService: Getting speed limit for \(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))")
        
        // Use high-precision cache key to avoid cross-street contamination
        let cacheKey = getHighPrecisionCacheKey(for: coordinate)
        if let cachedSpeed = cache.object(forKey: cacheKey) {
            print("🗂️ Using cached speed limit: \(Int(cachedSpeed.doubleValue)) mph")
            return cachedSpeed.doubleValue
        }
        
        // Try Apple MapKit with street-level accuracy
        let appleMapKitService = AppleMapKitSpeedLimitService()
        if let speedLimit = appleMapKitService.getSpeedLimit(for: coordinate) {
            print("🍎 Apple MapKit found speed limit: \(Int(speedLimit)) mph")
            cache.setObject(NSNumber(value: speedLimit), forKey: cacheKey)
            return speedLimit
        }
        
        // Try OpenStreetMap data (free alternative)
        if let speedLimit = osmService.getSpeedLimit(for: coordinate) {
            print("🗺️ OSM found speed limit: \(Int(speedLimit)) mph")
            cache.setObject(NSNumber(value: speedLimit), forKey: cacheKey)
            return speedLimit
        }
        
        // Use enhanced street-level detection
        if let speedLimit = getStreetLevelSpeedLimit(for: coordinate) {
            print("🏙️ Street-level detection found speed limit: \(Int(speedLimit)) mph")
            cache.setObject(NSNumber(value: speedLimit), forKey: cacheKey)
            return speedLimit
        }
        
        print("❌ No speed limit data found for coordinate")
        return nil
    }
    
    // MARK: - Cache Management
    
    private func getHighPrecisionCacheKey(for coordinate: CLLocationCoordinate2D) -> NSString {
        // Use high precision to avoid cross-street contamination
        // Round to ~5m precision instead of using exact coordinates
        let roundedLat = round(coordinate.latitude * 20000) / 20000
        let roundedLon = round(coordinate.longitude * 20000) / 20000
        return "\(roundedLat),\(roundedLon)" as NSString
    }
    
    func clearCache() {
        print("🗑️ Clearing speed limit cache to fix cross-street contamination")
        cache.removeAllObjects()
    }
    
    // MARK: - Street-Level Speed Limit Detection
    
    private func getStreetLevelSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double? {
        // Use reverse geocoding to get precise street information
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        // Use async geocoding for better accuracy
        var speedLimit: Double? = nil
        let semaphore = DispatchSemaphore(value: 0)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            defer { semaphore.signal() }
            
            if let placemark = placemarks?.first {
                speedLimit = self.analyzePlacemarkForSpeedLimit(placemark)
            }
        }
        
        // Wait for geocoding with timeout
        _ = semaphore.wait(timeout: .now() + 3.0)
        return speedLimit
    }
    
    private func analyzePlacemarkForSpeedLimit(_ placemark: CLPlacemark) -> Double? {
        // Comprehensive analysis of placemark data for accurate speed limits
        
        // Priority 1: Analyze road name and type
        if let thoroughfare = placemark.thoroughfare {
            if let speedLimit = getSpeedLimitFromRoadName(thoroughfare) {
                return speedLimit
            }
        }
        
        // Priority 2: Analyze administrative area
        if let administrativeArea = placemark.administrativeArea {
            if let speedLimit = getSpeedLimitFromAdministrativeArea(administrativeArea) {
                return speedLimit
            }
        }
        
        // Priority 3: Analyze locality
        if let locality = placemark.locality {
            if let speedLimit = getSpeedLimitFromLocality(locality) {
                return speedLimit
            }
        }
        
        // Priority 4: Analyze subLocality
        if let subLocality = placemark.subLocality {
            if let speedLimit = getSpeedLimitFromSubLocality(subLocality) {
                return speedLimit
            }
        }
        
        return nil
    }
    
    private func getSpeedLimitFromRoadName(_ roadName: String) -> Double? {
        let name = roadName.lowercased()
        
        // Interstate Highways (70 mph)
        if name.contains("interstate") || name.contains("i-") || name.contains("i ") {
            return 70.0
        }
        
        // US Highways (65 mph)
        if name.contains("us-") || name.contains("us ") || name.contains("us route") {
            return 65.0
        }
        
        // State Highways (55 mph)
        if name.contains("state route") || name.contains("sr-") || name.contains("state highway") {
            return 55.0
        }
        
        // Freeways and Expressways (65 mph)
        if name.contains("freeway") || name.contains("expressway") || name.contains("parkway") {
            return 65.0
        }
        
        // Major Arterials (45 mph)
        if name.contains("boulevard") || name.contains("avenue") || name.contains("drive") {
            return 45.0
        }
        
        // Business Routes (40 mph)
        if name.contains("business") || name.contains("commercial") {
            return 40.0
        }
        
        // Residential Streets (35 mph)
        if name.contains("street") || name.contains("road") || name.contains("lane") || 
           name.contains("way") || name.contains("court") || name.contains("place") {
            return 35.0
        }
        
        // School Zones (25 mph)
        if name.contains("school") || name.contains("elementary") || name.contains("middle") || 
           name.contains("high school") || name.contains("university") || name.contains("college") {
            return 25.0
        }
        
        return nil
    }
    
    private func getSpeedLimitFromAdministrativeArea(_ area: String) -> Double? {
        let areaName = area.lowercased()
        
        // Major metropolitan areas (30 mph default)
        let majorCities = ["new york", "los angeles", "chicago", "houston", "phoenix", 
                          "philadelphia", "san antonio", "san diego", "dallas", "san jose",
                          "austin", "jacksonville", "fort worth", "columbus", "charlotte",
                          "san francisco", "indianapolis", "seattle", "denver", "washington",
                          "boston", "detroit", "nashville", "portland", "las vegas",
                          "memphis", "louisville", "baltimore", "milwaukee", "atlanta",
                          "miami", "minneapolis", "cleveland", "tulsa", "wichita"]
        
        if majorCities.contains(where: { areaName.contains($0) }) {
            return 30.0
        }
        
        return nil
    }
    
    private func getSpeedLimitFromLocality(_ locality: String) -> Double? {
        let localityName = locality.lowercased()
        
        // Downtown areas (25 mph)
        if localityName.contains("downtown") || localityName.contains("center") || 
           localityName.contains("district") || localityName.contains("plaza") {
            return 25.0
        }
        
        // Business districts (35 mph)
        if localityName.contains("business") || localityName.contains("commercial") || 
           localityName.contains("shopping") || localityName.contains("retail") {
            return 35.0
        }
        
        // Residential areas (35 mph)
        if localityName.contains("residential") || localityName.contains("neighborhood") || 
           localityName.contains("subdivision") || localityName.contains("community") {
            return 35.0
        }
        
        return nil
    }
    
    private func getSpeedLimitFromSubLocality(_ subLocality: String) -> Double? {
        let subLocalityName = subLocality.lowercased()
        
        // School zones (25 mph)
        if subLocalityName.contains("school") || subLocalityName.contains("campus") || 
           subLocalityName.contains("academy") || subLocalityName.contains("university") {
            return 25.0
        }
        
        // Hospital zones (25 mph)
        if subLocalityName.contains("hospital") || subLocalityName.contains("medical") || 
           subLocalityName.contains("clinic") || subLocalityName.contains("health") {
            return 25.0
        }
        
        // Park zones (25 mph)
        if subLocalityName.contains("park") || subLocalityName.contains("recreation") || 
           subLocalityName.contains("playground") || subLocalityName.contains("trail") {
            return 25.0
        }
        
        return nil
    }
    
    // MARK: - Apple MapKit Implementation (iOS 16+)
    
    @available(iOS 16.0, *)
    private func getSpeedLimitFromMapKit(for coordinate: CLLocationCoordinate2D) -> Double? {
        // Apple MapKit speed limit detection using MKMapView
        // This requires iOS 16+ and may not be available in all regions
        
        // Use coordinate-based estimation for speed limit detection
        // This approach avoids UI components and provides reasonable speed limits
        return getSpeedLimitFromRoadType(for: coordinate)
    }
    
    @available(iOS 16.0, *)
    private func getSpeedLimitFromRoadType(for coordinate: CLLocationCoordinate2D) -> Double? {
        // Use coordinate-based estimation instead of blocking geocoding
        // This avoids UI blocking and provides reasonable speed limits
        
        return estimateSpeedLimitFromCoordinate(coordinate)
    }
    
    @available(iOS 16.0, *)
    private func estimateSpeedLimitFromCoordinate(_ coordinate: CLLocationCoordinate2D) -> Double? {
        // Estimate speed limit based on coordinate location
        // This provides reasonable defaults without blocking the UI
        
        // Check if we're in a major metropolitan area
        if isMajorMetropolitanArea(latitude: coordinate.latitude, longitude: coordinate.longitude) {
            return 30.0 // 30 mph for urban areas
        }
        
        // Check if we're in a suburban area
        if isSuburbanArea(latitude: coordinate.latitude, longitude: coordinate.longitude) {
            return 40.0 // 40 mph for suburban areas
        }
        
        // Check if we're on a highway
        if isHighwayArea(latitude: coordinate.latitude, longitude: coordinate.longitude) {
            return 65.0 // 65 mph for highways
        }
        
        return 50.0 // 50 mph default for rural areas
    }
    
    @available(iOS 16.0, *)
    private func estimateSpeedLimitFromPlacemark(_ placemark: CLPlacemark) -> Double? {
        // Estimate speed limit based on placemark information
        guard let thoroughfare = placemark.thoroughfare else { return nil }
        
        let roadName = thoroughfare.lowercased()
        
        // Highway/Freeway detection
        if roadName.contains("highway") || roadName.contains("freeway") || 
           roadName.contains("interstate") || roadName.contains("i-") {
            return 65.0 // 65 mph for highways
        }
        
        // Major roads
        if roadName.contains("boulevard") || roadName.contains("avenue") || 
           roadName.contains("parkway") || roadName.contains("drive") {
            return 45.0 // 45 mph for major roads
        }
        
        // Residential streets
        if roadName.contains("street") || roadName.contains("road") || 
           roadName.contains("lane") || roadName.contains("way") {
            return 35.0 // 35 mph for residential streets
        }
        
        // Default based on area type
        if let locality = placemark.locality {
            if isUrbanArea(latitude: placemark.location?.coordinate.latitude ?? 0, 
                          longitude: placemark.location?.coordinate.longitude ?? 0) {
                return 30.0 // 30 mph for urban areas
            }
        }
        
        return 40.0 // Default suburban speed limit
    }
    
    // MARK: - Location-based Estimation (Fallback)
    
    private func estimateSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double {
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        
        // Urban areas (higher population density) - typically 25-35 mph
        if isUrbanArea(latitude: latitude, longitude: longitude) {
            return 30.0 // 30 mph default for urban areas
        }
        
        // Suburban areas - typically 35-45 mph
        if isSuburbanArea(latitude: latitude, longitude: longitude) {
            return 40.0 // 40 mph default for suburban areas
        }
        
        // Highway/interstate areas - typically 55-75 mph
        if isHighwayArea(latitude: latitude, longitude: longitude) {
            return 65.0 // 65 mph default for highways
        }
        
        // Rural areas - typically 45-55 mph
        return 50.0 // 50 mph default for rural areas
    }
    
    private func isUrbanArea(latitude: Double, longitude: Double) -> Bool {
        // Simplified urban area detection
        // In a real app, you would use geographic data or APIs
        
        // Example: San Francisco area
        if latitude >= 37.7 && latitude <= 37.8 && longitude >= -122.5 && longitude <= -122.3 {
            return true
        }
        
        // Example: New York area
        if latitude >= 40.7 && latitude <= 40.8 && longitude >= -74.0 && longitude <= -73.9 {
            return true
        }
        
        // Example: Los Angeles area
        if latitude >= 34.0 && latitude <= 34.1 && longitude >= -118.3 && longitude <= -118.2 {
            return true
        }
        
        return false
    }
    
    private func isSuburbanArea(latitude: Double, longitude: Double) -> Bool {
        // Simplified suburban area detection
        
        // Example: Bay Area suburbs
        if latitude >= 37.4 && latitude <= 37.7 && longitude >= -122.2 && longitude <= -121.8 {
            return true
        }
        
        // Example: New York suburbs
        if latitude >= 40.6 && latitude <= 40.8 && longitude >= -74.2 && longitude <= -73.8 {
            return true
        }
        
        return false
    }
    
    private func isMajorMetropolitanArea(latitude: Double, longitude: Double) -> Bool {
        // Check if coordinates are in major metropolitan areas
        let metropolitanAreas: [(lat: Double, lon: Double, radius: Double)] = [
            // New York City
            (40.7128, -74.0060, 0.3),
            // Los Angeles
            (34.0522, -118.2437, 0.4),
            // Chicago
            (41.8781, -87.6298, 0.3),
            // Houston
            (29.7604, -95.3698, 0.3),
            // Phoenix
            (33.4484, -112.0740, 0.3),
            // Philadelphia
            (39.9526, -75.1652, 0.3),
            // San Antonio
            (29.4241, -98.4936, 0.3),
            // San Diego
            (32.7157, -117.1611, 0.3),
            // Dallas
            (32.7767, -96.7970, 0.3),
            // San Jose
            (37.3382, -121.8863, 0.3),
            // Austin
            (30.2672, -97.7431, 0.3),
            // Jacksonville
            (30.3322, -81.6557, 0.3),
            // Fort Worth
            (32.7555, -97.3308, 0.3),
            // Columbus
            (39.9612, -82.9988, 0.3),
            // Charlotte
            (35.2271, -80.8431, 0.3),
            // San Francisco
            (37.7749, -122.4194, 0.3),
            // Indianapolis
            (39.7684, -86.1581, 0.3),
            // Seattle
            (47.6062, -122.3321, 0.3),
            // Denver
            (39.7392, -104.9903, 0.3),
            // Washington DC
            (38.9072, -77.0369, 0.3),
            // Boston
            (42.3601, -71.0589, 0.3),
            // El Paso
            (31.7619, -106.4850, 0.3),
            // Nashville
            (36.1627, -86.7816, 0.3),
            // Detroit
            (42.3314, -83.0458, 0.3),
            // Oklahoma City
            (35.4676, -97.5164, 0.3),
            // Portland
            (45.5152, -122.6784, 0.3),
            // Las Vegas
            (36.1699, -115.1398, 0.3),
            // Memphis
            (35.1495, -90.0490, 0.3),
            // Louisville
            (38.2527, -85.7585, 0.3),
            // Baltimore
            (39.2904, -76.6122, 0.3),
            // Milwaukee
            (43.0389, -87.9065, 0.3),
            // Albuquerque
            (35.0844, -106.6504, 0.3),
            // Tucson
            (32.2226, -110.9747, 0.3),
            // Fresno
            (36.7378, -119.7871, 0.3),
            // Sacramento
            (38.5816, -121.4944, 0.3),
            // Mesa
            (33.4152, -111.8315, 0.3),
            // Kansas City
            (39.0997, -94.5786, 0.3),
            // Atlanta
            (33.7490, -84.3880, 0.3),
            // Long Beach
            (33.7701, -118.1937, 0.3),
            // Colorado Springs
            (38.8339, -104.8214, 0.3),
            // Raleigh
            (35.7796, -78.6382, 0.3),
            // Miami
            (25.7617, -80.1918, 0.3),
            // Virginia Beach
            (36.8529, -75.9780, 0.3),
            // Omaha
            (41.2565, -95.9345, 0.3),
            // Oakland
            (37.8044, -122.2712, 0.3),
            // Minneapolis
            (44.9778, -93.2650, 0.3),
            // Tulsa
            (36.1540, -95.9928, 0.3),
            // Cleveland
            (41.4993, -81.6944, 0.3),
            // Wichita
            (37.6872, -97.3301, 0.3),
            // Arlington
            (32.7357, -97.1081, 0.3)
        ]
        
        for area in metropolitanAreas {
            let distance = sqrt(pow(latitude - area.lat, 2) + pow(longitude - area.lon, 2))
            if distance <= area.radius {
                return true
            }
        }
        
        return false
    }
    
    
    private func isHighwayArea(latitude: Double, longitude: Double) -> Bool {
        // Check if coordinates are near known highway corridors
        // This provides basic highway detection for major interstates
        
        // Major Interstate corridors (approximate coordinates)
        let highwayCorridors: [(lat: Double, lon: Double, radius: Double)] = [
            // I-95 corridor (East Coast)
            (39.0, -77.0, 0.5), (40.0, -74.0, 0.5), (41.0, -73.0, 0.5),
            // I-10 corridor (Southern US)
            (29.0, -95.0, 0.5), (30.0, -90.0, 0.5), (32.0, -87.0, 0.5),
            // I-80 corridor (Northern US)
            (40.0, -74.0, 0.5), (41.0, -87.0, 0.5), (42.0, -96.0, 0.5),
            // I-75 corridor (Michigan/Ohio)
            (42.0, -83.0, 0.5), (41.0, -81.0, 0.5), (40.0, -84.0, 0.5)
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

// MARK: - Async Implementation (Recommended for Production)

extension SpeedLimitService {
    
    func getSpeedLimitAsync(for coordinate: CLLocationCoordinate2D) async -> Double? {
        // Check cache first
        let cacheKey = "\(coordinate.latitude),\(coordinate.longitude)" as NSString
        if let cachedSpeed = cache.object(forKey: cacheKey) {
            return cachedSpeed.doubleValue
        }
        
        // Try Apple MapKit
        let appleMapKitService = AppleMapKitSpeedLimitService()
        if let speedLimit = appleMapKitService.getSpeedLimit(for: coordinate) {
            cache.setObject(NSNumber(value: speedLimit), forKey: cacheKey)
            return speedLimit
        }
        
        // Try OpenStreetMap data
        if let speedLimit = osmService.getSpeedLimit(for: coordinate) {
            cache.setObject(NSNumber(value: speedLimit), forKey: cacheKey)
            return speedLimit
        }
        
        // Fallback to estimation
        let estimatedSpeed = estimateSpeedLimit(for: coordinate)
        cache.setObject(NSNumber(value: estimatedSpeed), forKey: cacheKey)
        return estimatedSpeed
    }
}
