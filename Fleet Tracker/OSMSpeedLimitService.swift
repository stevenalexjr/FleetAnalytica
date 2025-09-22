//
//  OSMSpeedLimitService.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

class OSMSpeedLimitService {
    private let cache: NSCache<NSString, NSNumber> = NSCache()
    private let baseURL = "https://overpass-api.de/api/interpreter"
    private let localDatabase = LocalSpeedLimitDatabase.shared
    
    init() {
        cache.countLimit = 1000
    }
    
    func getSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double? {
        print("🔍 OSM Speed Limit Check - Lat: \(String(format: "%.6f", coordinate.latitude)), Lon: \(String(format: "%.6f", coordinate.longitude))")
        
        // First try local database (most accurate for Detroit)
        if let localSpeed = localDatabase.getSpeedLimit(for: coordinate) {
            // Cache with rounded coordinates for better hit rate
            let roundedKey = getRoundedCacheKey(for: coordinate)
            cache.setObject(NSNumber(value: localSpeed), forKey: roundedKey)
            print("🗺️ Using local OSM data: \(Int(localSpeed)) mph")
            return localSpeed
        }
        
        // Check cache for nearby results (within ~50m)
        if let cachedSpeed = getCachedSpeedLimit(for: coordinate) {
            print("🗺️ Using cached OSM data: \(Int(cachedSpeed)) mph")
            return cachedSpeed
        }
        
        // Fallback to live OSM query with better accuracy
        if let speedLimit = queryOSMSpeedLimit(for: coordinate) {
            let roundedKey = getRoundedCacheKey(for: coordinate)
            cache.setObject(NSNumber(value: speedLimit), forKey: roundedKey)
            print("🗺️ Using live OSM data: \(Int(speedLimit)) mph")
            return speedLimit
        }
        
        print("🗺️ No OSM speed limit data found for coordinate")
        return nil
    }
    
    private func getRoundedCacheKey(for coordinate: CLLocationCoordinate2D) -> NSString {
        // Use much higher precision to avoid cross-street contamination
        // Round to ~10m precision instead of 50m
        let roundedLat = round(coordinate.latitude * 10000) / 10000
        let roundedLon = round(coordinate.longitude * 10000) / 10000
        return "osm_\(roundedLat),\(roundedLon)" as NSString
    }
    
    private func getCachedSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double? {
        // Use much smaller search radius to avoid cross-street contamination
        let searchRadius = 0.0001 // ~10m radius instead of 50m
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // Check only very close coordinates to avoid highway speed limits on residential streets
        for latOffset in stride(from: -searchRadius, through: searchRadius, by: 0.00005) {
            for lonOffset in stride(from: -searchRadius, through: searchRadius, by: 0.00005) {
                let testCoord = CLLocationCoordinate2D(
                    latitude: lat + latOffset,
                    longitude: lon + lonOffset
                )
                let key = getRoundedCacheKey(for: testCoord)
                if let cachedSpeed = cache.object(forKey: key) {
                    print("🗂️ Found cached speed limit within 10m: \(Int(cachedSpeed.doubleValue)) mph")
                    return cachedSpeed.doubleValue
                }
            }
        }
        
        return nil
    }
    
    private func queryOSMSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double? {
        // Create smaller bounding box for more accurate results (0.001 degree ≈ 100m)
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let bbox = "\(lat-0.001),\(lon-0.001),\(lat+0.001),\(lon+0.001)"
        
        print("🌐 Querying OSM API for bbox: \(bbox)")
        
        // Enhanced OSM Overpass API query for speed limits with better road type coverage
        let query = """
        [out:json][timeout:25];
        (
          way["highway"]["maxspeed"](\(bbox));
          way["highway"]["maxspeed:forward"](\(bbox));
          way["highway"]["maxspeed:backward"](\(bbox));
          way["highway"="primary"]["maxspeed"](\(bbox));
          way["highway"="secondary"]["maxspeed"](\(bbox));
          way["highway"="tertiary"]["maxspeed"](\(bbox));
          way["highway"="residential"]["maxspeed"](\(bbox));
          way["highway"="trunk"]["maxspeed"](\(bbox));
          way["highway"="motorway"]["maxspeed"](\(bbox));
          way["highway"="unclassified"]["maxspeed"](\(bbox));
          way["highway"="service"]["maxspeed"](\(bbox));
        );
        out geom;
        """
        
        guard let url = URL(string: baseURL) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = query.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let data = try Data(contentsOf: request.url!)
            let response = try JSONDecoder().decode(OSMResponse.self, from: data)
            
            print("🌐 OSM API Response: \(response.elements.count) elements found")
            
            // Parse speed limits from OSM data, prioritizing closest matches
            var closestSpeedLimit: Double?
            var minDistance = Double.greatestFiniteMagnitude
            var foundRoads: [String] = []
            
            for element in response.elements {
                if let speedLimit = parseSpeedLimit(from: element) {
                    let roadName = element.tags["name"] ?? element.tags["ref"] ?? "Unknown"
                    let roadType = element.tags["highway"] ?? "unknown"
                    foundRoads.append("\(roadName) (\(roadType)): \(Int(speedLimit)) mph")
                    
                    // Calculate distance to coordinate for better accuracy
                    if let geometry = element.geometry {
                        for point in geometry {
                            let distance = sqrt(pow(point.lat - lat, 2) + pow(point.lon - lon, 2))
                            if distance < minDistance {
                                minDistance = distance
                                closestSpeedLimit = speedLimit
                            }
                        }
                    } else {
                        // If no geometry, use the first speed limit found
                        if closestSpeedLimit == nil {
                            closestSpeedLimit = speedLimit
                        }
                    }
                }
            }
            
            if !foundRoads.isEmpty {
                print("🛣️ Found roads: \(foundRoads.joined(separator: ", "))")
            }
            
            if let speedLimit = closestSpeedLimit {
                print("✅ Selected speed limit: \(Int(speedLimit)) mph (distance: \(String(format: "%.4f", minDistance)))")
            }
            
            return closestSpeedLimit
        } catch {
            print("❌ OSM API error: \(error)")
        }
        
        return nil
    }
    
    private func parseSpeedLimit(from element: OSMElement) -> Double? {
        // Parse maxspeed tag
        if let maxspeed = element.tags["maxspeed"] {
            return parseSpeedLimitString(maxspeed)
        }
        
        // Parse maxspeed:forward tag
        if let maxspeedForward = element.tags["maxspeed:forward"] {
            return parseSpeedLimitString(maxspeedForward)
        }
        
        // Parse maxspeed:backward tag
        if let maxspeedBackward = element.tags["maxspeed:backward"] {
            return parseSpeedLimitString(maxspeedBackward)
        }
        
        return nil
    }
    
    private func parseSpeedLimitString(_ speedString: String) -> Double? {
        let cleanSpeed = speedString.lowercased()
            .replacingOccurrences(of: "mph", with: "")
            .replacingOccurrences(of: "km/h", with: "")
            .replacingOccurrences(of: "kmh", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle common speed limit formats
        if let speed = Double(cleanSpeed) {
            // If original string contained km/h, convert to mph
            if speedString.lowercased().contains("km") {
                return speed * 0.621371 // Convert km/h to mph
            }
            return speed
        }
        
        // Handle special cases
        switch cleanSpeed {
        case "none", "unlimited":
            return 70.0 // Default highway speed
        case "walk", "walking":
            return 5.0 // Walking speed
        case "bicycle", "cycling":
            return 15.0 // Cycling speed
        default:
            return nil
        }
    }
}


// MARK: - Data Management Extension

extension OSMSpeedLimitService {
    
    func downloadAndStoreSpeedLimits(for region: CLLocationCoordinate2D, radius: Double = 1000) async {
        let downloader = OSMSpeedLimitDownloader()
        let newData = await downloader.downloadSpeedLimits(for: region, radius: radius)
        
        if !newData.isEmpty {
            localDatabase.addSpeedLimitData(newData)
            print("Downloaded and stored \(newData.count) speed limit records")
        } else {
            print("No speed limit data found for the specified region")
        }
    }
    
    func downloadDetroitSpeedLimits() async {
        let downloader = OSMSpeedLimitDownloader()
        let newData = await downloader.downloadDetroitSpeedLimits()
        
        if !newData.isEmpty {
            localDatabase.addSpeedLimitData(newData)
            print("Downloaded and stored \(newData.count) Detroit speed limit records")
        } else {
            print("No Detroit speed limit data found")
        }
    }
    
    func refreshSpeedLimitData(for coordinate: CLLocationCoordinate2D) async {
        // Download fresh data for the current area
        await downloadAndStoreSpeedLimits(for: coordinate, radius: 2000)
        
        // Clear cache to force fresh lookups
        cache.removeAllObjects()
        print("🔄 Speed limit data refreshed for current area")
    }
    
    func getDataStatistics() -> (total: Int, byRoadType: [String: Int], bySpeedRange: [String: Int]) {
        return localDatabase.getDataStatistics()
    }
    
    func hasLocalData() -> Bool {
        return localDatabase.hasData()
    }
    
    func clearLocalData() {
        localDatabase.clearAllData()
        cache.removeAllObjects()
    }
}
