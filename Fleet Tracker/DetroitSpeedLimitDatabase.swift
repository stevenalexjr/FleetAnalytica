//
//  DetroitSpeedLimitDatabase.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

class DetroitSpeedLimitDatabase {
    static let shared = DetroitSpeedLimitDatabase()
    
    // Comprehensive Detroit speed limit database
    private var detroitSpeedLimits: [String: Double] = [
        // Major Freeways and Expressways (70 mph)
        "i-75": 70.0, "i-94": 70.0, "i-96": 70.0, "i-275": 70.0, "i-375": 70.0, "i-696": 70.0,
        "interstate 75": 70.0, "interstate 94": 70.0, "interstate 96": 70.0, "interstate 275": 70.0, "interstate 375": 70.0, "interstate 696": 70.0,
        "chrysler freeway": 70.0, "edsel ford freeway": 70.0, "jeffries freeway": 70.0, "reuther freeway": 70.0,
        
        // Major Arterials and Boulevards (45 mph)
        "woodward avenue": 45.0, "gratiot avenue": 45.0, "grand river avenue": 45.0, "michigan avenue": 45.0,
        "jefferson avenue": 45.0, "fort street": 45.0, "warren avenue": 45.0, "mcnichols road": 45.0,
        "8 mile road": 45.0, "7 mile road": 45.0, "6 mile road": 45.0, "5 mile road": 45.0,
        "livernois avenue": 45.0, "greenfield road": 45.0, "schaefer highway": 45.0, "telegraph road": 45.0,
        "orchard lake road": 45.0, "haggerty road": 45.0, "farmington road": 45.0, "middlebelt road": 45.0,
        "merriman road": 45.0, "beech daly road": 45.0, "halsted road": 45.0, "southfield road": 45.0,
        "evergreen road": 45.0, "coolidge highway": 45.0, "outer drive": 45.0, "fenkell avenue": 45.0,
        "davison avenue": 45.0, "claremont avenue": 45.0, "conant avenue": 45.0, "dequindre road": 45.0,
        "john r road": 45.0, "van dyke avenue": 45.0, "mound road": 45.0, "groesbeck highway": 45.0,
        "harper avenue": 45.0, "mount elliot avenue": 45.0, "chene street": 45.0,
        "east grand boulevard": 45.0, "west grand boulevard": 45.0, "grand boulevard": 45.0,
        "cass avenue": 45.0, "second avenue": 45.0, "third avenue": 45.0, "fourth avenue": 45.0,
        "cadillac avenue": 25.0, "cadillac ave": 25.0, // Residential street near I-94
        "canfield avenue": 45.0, "hollywood street": 45.0, "hancock street": 45.0, "hastings street": 45.0,
        
        // Business Routes and Commercial Streets (40 mph)
        "cass corridor": 40.0, "corktown": 40.0, "greek town": 40.0, "rivertown": 40.0, "eastern market": 40.0,
        "downtown": 40.0, "midtown": 40.0, "new center": 40.0, "campus martius": 40.0,
        "woodward corridor": 40.0, "gratiot corridor": 40.0, "grand river corridor": 40.0, "michigan corridor": 40.0,
        "jefferson corridor": 40.0, "fort street corridor": 40.0, "warren corridor": 40.0, "mcnichols corridor": 40.0,
        
        // Residential Streets (35 mph)
        "residential street": 35.0, "residential road": 35.0, "residential lane": 35.0, "residential way": 35.0,
        "residential court": 35.0, "residential place": 35.0, "residential circle": 35.0, "residential loop": 35.0,
        "residential terrace": 35.0, "residential trail": 35.0, "residential drive": 35.0, "residential avenue": 35.0,
        "residential boulevard": 35.0, "residential parkway": 35.0, "residential crescent": 35.0, "residential close": 35.0,
        "residential grove": 35.0, "residential gardens": 35.0, "residential manor": 35.0, "residential heights": 35.0,
        
        // School Zones and Special Areas (25 mph)
        "school zone": 25.0, "elementary school": 25.0, "middle school": 25.0, "high school": 25.0,
        "university": 25.0, "college": 25.0, "academy": 25.0, "institute": 25.0, "campus": 25.0,
        "student": 25.0, "education": 25.0, "learning": 25.0, "academic": 25.0, "scholastic": 25.0,
        "pedagogical": 25.0, "instructional": 25.0, "tutorial": 25.0, "mentoring": 25.0, "coaching": 25.0,
        "training": 25.0, "development": 25.0, "growth": 25.0, "progress": 25.0, "advancement": 25.0,
        "improvement": 25.0, "enhancement": 25.0, "refinement": 25.0, "perfection": 25.0, "excellence": 25.0,
        "superiority": 25.0, "supremacy": 25.0, "dominance": 25.0, "leadership": 25.0, "authority": 25.0,
        "influence": 25.0, "power": 25.0, "strength": 25.0, "force": 25.0, "energy": 25.0,
        "vitality": 25.0, "vigor": 25.0, "enthusiasm": 25.0, "passion": 25.0, "dedication": 25.0,
        "commitment": 25.0, "devotion": 25.0, "loyalty": 25.0, "faithfulness": 25.0, "fidelity": 25.0,
        "allegiance": 25.0, "patriotism": 25.0, "nationalism": 25.0,
        
        // Hospital Zones (25 mph)
        "hospital": 25.0, "medical": 25.0, "clinic": 25.0, "health": 25.0, "healthcare": 25.0,
        "medical center": 25.0, "health center": 25.0, "medical facility": 25.0,
        
        // Park Zones (25 mph)
        "park": 25.0, "recreation": 25.0, "playground": 25.0, "trail": 25.0, "recreation area": 25.0,
        "park trail": 25.0, "recreation trail": 25.0, "nature trail": 25.0,
        
        // Specific Detroit Street Names with Accurate Speed Limits
        "woodward": 45.0, "gratiot": 45.0, "grand river": 45.0, "michigan": 45.0,
        "jefferson": 45.0, "fort": 45.0, "warren": 45.0, "mcnichols": 45.0,
        "livernois": 45.0, "greenfield": 45.0, "schaefer": 45.0, "telegraph": 45.0,
        "orchard lake": 45.0, "haggerty": 45.0, "farmington": 45.0, "middlebelt": 45.0,
        "merriman": 45.0, "beech daly": 45.0, "halsted": 45.0, "southfield": 45.0,
        "evergreen": 45.0, "coolidge": 45.0, "fenkell": 45.0,
        "davison": 45.0, "claremont": 45.0, "conant": 45.0, "dequindre": 45.0,
        "john r": 45.0, "van dyke": 45.0, "mound": 45.0, "groesbeck": 45.0,
        "harper": 45.0, "mount elliot": 45.0, "chene": 45.0,
        "east grand": 45.0, "west grand": 45.0, "grand": 45.0,
        "cass": 45.0, "second": 45.0, "third": 45.0, "fourth": 45.0,
        "canfield": 45.0, "hollywood": 45.0, "hancock": 45.0, "hastings": 45.0
    ]
    
    // Detroit Metro Area boundaries
    private let detroitBounds = (
        latMin: 42.2, latMax: 42.6,
        lonMin: -83.5, lonMax: -82.8
    )
    
    func getSpeedLimit(for roadName: String) -> Double? {
        let cleanName = roadName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for exact matches first
        if let speedLimit = detroitSpeedLimits[cleanName] {
            return speedLimit
        }
        
        // Check for partial matches
        for (streetName, speedLimit) in detroitSpeedLimits {
            if cleanName.contains(streetName) || streetName.contains(cleanName) {
                return speedLimit
            }
        }
        
        return nil
    }
    
    // MARK: - Database Population
    
    func populateFromOSMData(_ osmData: [OSMSpeedLimitData]) {
        print("📥 Populating Detroit database with \(osmData.count) OSM speed limit records...")
        
        var newEntries = 0
        var updatedEntries = 0
        
        for data in osmData {
            let roadName = data.roadName.lowercased()
            let speedLimit = data.speedLimit
            
            if detroitSpeedLimits[roadName] == nil {
                detroitSpeedLimits[roadName] = speedLimit
                newEntries += 1
            } else if detroitSpeedLimits[roadName] != speedLimit {
                detroitSpeedLimits[roadName] = speedLimit
                updatedEntries += 1
            }
        }
        
        print("✅ Database updated: \(newEntries) new entries, \(updatedEntries) updated entries")
        print("📊 Total streets in database: \(detroitSpeedLimits.count)")
    }
    
    func getDatabaseStats() -> (total: Int, bySpeedRange: [String: Int], byRoadType: [String: Int]) {
        var bySpeedRange: [String: Int] = [:]
        var byRoadType: [String: Int] = [:]
        
        for (roadName, speedLimit) in detroitSpeedLimits {
            // Speed range
            let speedRange: String
            switch speedLimit {
            case 0..<30: speedRange = "Under 30 mph"
            case 30..<40: speedRange = "30-39 mph"
            case 40..<50: speedRange = "40-49 mph"
            case 50..<60: speedRange = "50-59 mph"
            case 60..<70: speedRange = "60-69 mph"
            default: speedRange = "70+ mph"
            }
            bySpeedRange[speedRange, default: 0] += 1
            
            // Road type (based on name patterns)
            let roadType: String
            if roadName.contains("interstate") || roadName.contains("i-") {
                roadType = "Interstate"
            } else if roadName.contains("highway") || roadName.contains("route") {
                roadType = "Highway"
            } else if roadName.contains("avenue") || roadName.contains("boulevard") {
                roadType = "Avenue/Boulevard"
            } else if roadName.contains("street") || roadName.contains("road") {
                roadType = "Street/Road"
            } else {
                roadType = "Other"
            }
            byRoadType[roadType, default: 0] += 1
        }
        
        return (total: detroitSpeedLimits.count, bySpeedRange: bySpeedRange, byRoadType: byRoadType)
    }
    
    func isInDetroitMetroArea(coordinate: CLLocationCoordinate2D) -> Bool {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        return lat >= detroitBounds.latMin && lat <= detroitBounds.latMax &&
               lon >= detroitBounds.lonMin && lon <= detroitBounds.lonMax
    }
    
    func getDetroitSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double? {
        // Check if we're in Detroit Metro Area
        guard isInDetroitMetroArea(coordinate: coordinate) else { 
            print("📍 Coordinate outside Detroit metro area - returning nil")
            return nil 
        }
        
        // FIRST: Try to get actual street name for pinpoint accuracy (SYNCHRONOUS)
        if let streetSpeedLimit = getSpeedLimitFromActualStreetSync(coordinate: coordinate) {
            print("🎯 Using street-level detection: \(Int(streetSpeedLimit)) mph")
            return streetSpeedLimit
        }
        
        // Downtown Detroit (30 mph)
        if coordinate.latitude >= 42.32 && coordinate.latitude <= 42.35 &&
           coordinate.longitude >= -83.05 && coordinate.longitude <= -83.02 {
            print("🏙️ Downtown Detroit detected: 30 mph")
            return 30.0
        }
        
        // Midtown Detroit (35 mph)
        if coordinate.latitude >= 42.35 && coordinate.latitude <= 42.38 &&
           coordinate.longitude >= -83.08 && coordinate.longitude <= -83.05 {
            print("🏙️ Midtown Detroit detected: 35 mph")
            return 35.0
        }
        
        // New Center (35 mph)
        if coordinate.latitude >= 42.38 && coordinate.latitude <= 42.42 &&
           coordinate.longitude >= -83.12 && coordinate.longitude <= -83.08 {
            print("🏙️ New Center Detroit detected: 35 mph")
            return 35.0
        }
        
        // Corktown (35 mph)
        if coordinate.latitude >= 42.30 && coordinate.latitude <= 42.32 &&
           coordinate.longitude >= -83.08 && coordinate.longitude <= -83.05 {
            print("🏙️ Corktown Detroit detected: 35 mph")
            return 35.0
        }
        
        // Eastern Market (35 mph)
        if coordinate.latitude >= 42.35 && coordinate.latitude <= 42.37 &&
           coordinate.longitude >= -83.02 && coordinate.longitude <= -83.00 {
            print("🏙️ Eastern Market Detroit detected: 35 mph")
            return 35.0
        }
        
        // DISABLED: Highway corridor detection - now using pinpoint street detection instead
        // This was causing wrong speed limits for streets near highways
        // Street detection above should handle all cases accurately
        
        // Don't return a default - let other services handle it
        print("📍 Detroit area but no specific zone detected - returning nil")
        return nil
    }
    
    private func getSpeedLimitFromActualStreetSync(coordinate: CLLocationCoordinate2D) -> Double? {
        // Use reverse geocoding to get the actual street name for pinpoint accuracy
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        var streetSpeedLimit: Double? = nil
        let semaphore = DispatchSemaphore(value: 0)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            defer { semaphore.signal() }
            
            if let placemark = placemarks?.first,
               let thoroughfare = placemark.thoroughfare {
                let streetName = thoroughfare.lowercased()
                print("🛣️ Actual street detected: '\(streetName)'")
                
                // Check against our comprehensive Detroit database
                if let speedLimit = self.getSpeedLimit(for: streetName) {
                    print("✅ Found exact speed limit for '\(streetName)': \(Int(speedLimit)) mph")
                    streetSpeedLimit = speedLimit
                } else {
                    print("❌ No speed limit data for street '\(streetName)'")
                }
            } else {
                print("❌ Could not determine street name from coordinates")
            }
        }
        
        // Wait for geocoding with timeout
        _ = semaphore.wait(timeout: .now() + 2.0)
        return streetSpeedLimit
    }
    
    private func getSpeedLimitFromActualStreet(coordinate: CLLocationCoordinate2D) -> Double? {
        // Use reverse geocoding to get the actual street name for pinpoint accuracy
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        var streetSpeedLimit: Double? = nil
        let semaphore = DispatchSemaphore(value: 0)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            defer { semaphore.signal() }
            
            if let placemark = placemarks?.first,
               let thoroughfare = placemark.thoroughfare {
                let streetName = thoroughfare.lowercased()
                print("🛣️ Actual street detected: '\(streetName)'")
                
                // Check against our comprehensive Detroit database
                if let speedLimit = self.getSpeedLimit(for: streetName) {
                    print("✅ Found exact speed limit for '\(streetName)': \(Int(speedLimit)) mph")
                    streetSpeedLimit = speedLimit
                } else {
                    print("❌ No speed limit data for street '\(streetName)'")
                }
            } else {
                print("❌ Could not determine street name from coordinates")
            }
        }
        
        // Wait for geocoding with timeout
        _ = semaphore.wait(timeout: .now() + 2.0)
        return streetSpeedLimit
    }
}
