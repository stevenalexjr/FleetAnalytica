//
//  AppleMapKitSpeedLimitService.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation
import MapKit

class AppleMapKitSpeedLimitService {
    private let cache: NSCache<NSString, NSNumber> = NSCache()
    private let geocodingCache: NSCache<NSString, CLPlacemark> = NSCache()
    
    init() {
        cache.countLimit = 1000
        geocodingCache.countLimit = 500
    }
    
    func getSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double? {
        // Check cache first with high precision to avoid cross-street contamination
        let cacheKey = getHighPrecisionCacheKey(for: coordinate)
        if let cachedSpeed = cache.object(forKey: cacheKey) {
            print("🍎 Using cached Apple MapKit speed limit: \(Int(cachedSpeed.doubleValue)) mph")
            return cachedSpeed.doubleValue
        }
        
        // Try Detroit-specific detection first (most accurate for Detroit)
        if let detroitSpeedLimit = getDetroitSpeedLimit(for: coordinate) {
            cache.setObject(NSNumber(value: detroitSpeedLimit), forKey: cacheKey)
            return detroitSpeedLimit
        }
        
        // Use cached geocoding result if available
        if let cachedPlacemark = geocodingCache.object(forKey: cacheKey) {
            let speedLimit = analyzePlacemarkForSpeedLimit(cachedPlacemark)
            if let speedLimit = speedLimit {
                cache.setObject(NSNumber(value: speedLimit), forKey: cacheKey)
            }
            return speedLimit
        }
        
        // No fallback to inaccurate estimation - return nil for uncertain locations
        return nil
    }
    
    func getSpeedLimitAsync(for coordinate: CLLocationCoordinate2D) async -> Double? {
        // Check cache first with high precision to avoid cross-street contamination
        let cacheKey = getHighPrecisionCacheKey(for: coordinate)
        if let cachedSpeed = cache.object(forKey: cacheKey) {
            return cachedSpeed.doubleValue
        }
        
        // Try Detroit-specific detection first (most accurate for Detroit)
        if let detroitSpeedLimit = getDetroitSpeedLimit(for: coordinate) {
            cache.setObject(NSNumber(value: detroitSpeedLimit), forKey: cacheKey)
            return detroitSpeedLimit
        }
        
        // Use cached geocoding result if available
        if let cachedPlacemark = geocodingCache.object(forKey: cacheKey) {
            let speedLimit = analyzePlacemarkForSpeedLimit(cachedPlacemark)
            if let speedLimit = speedLimit {
                cache.setObject(NSNumber(value: speedLimit), forKey: cacheKey)
            }
            return speedLimit
        }
        
        // No fallback to inaccurate estimation - return nil for uncertain locations
        return nil
    }
    
    private func getHighPrecisionCacheKey(for coordinate: CLLocationCoordinate2D) -> NSString {
        // Use high precision to avoid cross-street contamination
        // Round to ~5m precision instead of using exact coordinates
        let roundedLat = round(coordinate.latitude * 20000) / 20000
        let roundedLon = round(coordinate.longitude * 20000) / 20000
        return "\(roundedLat),\(roundedLon)" as NSString
    }
    
    private func getDetroitSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double? {
        // Detroit-specific speed limit detection using coordinate
        return DetroitSpeedLimitDatabase.shared.getDetroitSpeedLimit(for: coordinate)
    }
    
    private func analyzePlacemarkForSpeedLimit(_ placemark: CLPlacemark) -> Double? {
        // Priority 1: Determine based on road name and type
        if let roadSpeedLimit = getSpeedLimitFromRoadName(placemark) {
            return roadSpeedLimit
        }
        
        // Priority 2: Determine based on administrative area
        if let adminSpeedLimit = getSpeedLimitFromAdministrativeArea(placemark) {
            return adminSpeedLimit
        }
        
        // Priority 3: Determine based on locality and area type
        if let localitySpeedLimit = getSpeedLimitFromLocality(placemark) {
            return localitySpeedLimit
        }
        
        // No fallback to inaccurate estimation - return nil for uncertain locations
        return nil
    }
    
    private func getSpeedLimitFromRoadName(_ placemark: CLPlacemark) -> Double? {
        guard let thoroughfare = placemark.thoroughfare else { return nil }
        let roadName = thoroughfare.lowercased()
        
        // Use comprehensive Detroit speed limit database
        if let detroitSpeedLimit = DetroitSpeedLimitDatabase.shared.getSpeedLimit(for: roadName) {
            return detroitSpeedLimit
        }
        
        // Interstate/Freeway detection (highest speed limits)
        if roadName.contains("interstate") || roadName.contains("i-") || 
           roadName.contains("freeway") || roadName.contains("expressway") {
            return 70.0 // 70 mph for interstates/freeways
        }
        
        // US Highway detection
        if roadName.contains("us route") || roadName.contains("us-") || 
           roadName.contains("us highway") {
            return 65.0 // 65 mph for US highways
        }
        
        // State Route detection
        if roadName.contains("state route") || roadName.contains("sr-") || 
           roadName.contains("state highway") {
            return 55.0 // 55 mph for state routes
        }
        
        // Major Arterial detection
        if roadName.contains("boulevard") || roadName.contains("avenue") || 
           roadName.contains("highway") || roadName.contains("parkway") {
            return 45.0 // 45 mph for major arterials
        }
        
        // Business Route detection
        if roadName.contains("business") || roadName.contains("commercial") ||
           roadName.contains("downtown") || roadName.contains("main street") {
            return 40.0 // 40 mph for business routes
        }
        
        // Residential Street detection (including "ave" but not "avenue")
        if roadName.contains("street") || roadName.contains("road") || 
           roadName.contains("lane") || roadName.contains("way") ||
           roadName.contains("court") || roadName.contains("place") ||
           (roadName.contains("ave") && !roadName.contains("avenue")) {
            return 25.0 // 25 mph for residential streets (more conservative)
        }
        
        // School Zone detection
        if roadName.contains("school") || roadName.contains("elementary") ||
           roadName.contains("high school") || roadName.contains("university") {
            return 25.0 // 25 mph for school zones
        }
        
        return nil
    }
    
    private func getSpeedLimitFromAdministrativeArea(_ placemark: CLPlacemark) -> Double? {
        guard let administrativeArea = placemark.administrativeArea else { return nil }
        let area = administrativeArea.lowercased()
        
        // Major metropolitan areas
        if area.contains("detroit") || area.contains("chicago") || area.contains("new york") ||
           area.contains("los angeles") || area.contains("houston") || area.contains("phoenix") {
            return 35.0 // 35 mph for major metropolitan areas
        }
        
        // Suburban areas
        if area.contains("suburb") || area.contains("township") || area.contains("village") {
            return 40.0 // 40 mph for suburban areas
        }
        
        return nil
    }
    
    private func getSpeedLimitFromLocality(_ placemark: CLPlacemark) -> Double? {
        guard let locality = placemark.locality else { return nil }
        let localityLower = locality.lowercased()
        
        // Downtown areas
        if localityLower.contains("downtown") || localityLower.contains("central") ||
           localityLower.contains("business district") || localityLower.contains("financial district") {
            return 30.0 // 30 mph for downtown areas
        }
        
        // Business districts
        if localityLower.contains("business") || localityLower.contains("commercial") ||
           localityLower.contains("office") || localityLower.contains("corporate") {
            return 35.0 // 35 mph for business districts
        }
        
        // Residential neighborhoods
        if localityLower.contains("residential") || localityLower.contains("neighborhood") ||
           localityLower.contains("subdivision") || localityLower.contains("estates") {
            return 35.0 // 35 mph for residential areas
        }
        
        // Shopping areas
        if localityLower.contains("shopping") || localityLower.contains("mall") ||
           localityLower.contains("plaza") || localityLower.contains("center") {
            return 30.0 // 30 mph for shopping areas
        }
        
        return nil
    }
}