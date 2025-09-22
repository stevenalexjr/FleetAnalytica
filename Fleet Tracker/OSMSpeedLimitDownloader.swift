//
//  OSMSpeedLimitDownloader.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

class OSMSpeedLimitDownloader {
    private let baseURL = "https://overpass-api.de/api/interpreter"
    
    // Download speed limit data for a specific region
    func downloadSpeedLimits(for region: CLLocationCoordinate2D, radius: Double = 1000) async -> [OSMSpeedLimitData] {
        let query = buildOverpassQuery(center: region, radius: radius)
        
        guard let url = URL(string: baseURL) else { return [] }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OSMResponse.self, from: data)
            return parseSpeedLimitData(from: response)
        } catch {
            print("OSM download error: \(error)")
            return []
        }
    }
    
    // Download speed limit data for Detroit area
    func downloadDetroitSpeedLimits() async -> [OSMSpeedLimitData] {
        let detroitCenter = CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458)
        return await downloadSpeedLimits(for: detroitCenter, radius: 5000) // 5km radius
    }
    
    // Build Overpass API query for speed limits
    private func buildOverpassQuery(center: CLLocationCoordinate2D, radius: Double) -> String {
        return """
        [out:json][timeout:25];
        (
          way["maxspeed"](around:\(radius),\(center.latitude),\(center.longitude));
          relation["maxspeed"](around:\(radius),\(center.latitude),\(center.longitude));
        );
        out geom;
        """
    }
    
    // Parse OSM response into speed limit data
    private func parseSpeedLimitData(from response: OSMResponse) -> [OSMSpeedLimitData] {
        var speedLimits: [OSMSpeedLimitData] = []
        
        for element in response.elements {
            if let maxspeed = element.tags["maxspeed"],
               let coordinates = element.geometry?.first,
               let speedLimit = parseSpeedLimitValue(maxspeed) {
                
                let coordinate = CLLocationCoordinate2D(
                    latitude: coordinates.lat,
                    longitude: coordinates.lon
                )
                
                speedLimits.append(OSMSpeedLimitData(
                    coordinate: coordinate,
                    speedLimit: speedLimit,
                    roadName: element.tags["name"] ?? element.tags["ref"] ?? "Unknown",
                    roadType: element.tags["highway"] ?? "unknown"
                ))
            }
        }
        
        return speedLimits
    }
    
    // Parse speed limit values (handles various formats)
    private func parseSpeedLimitValue(_ value: String) -> Double? {
        let cleaned = value.lowercased()
            .replacingOccurrences(of: "mph", with: "")
            .replacingOccurrences(of: "km/h", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        if let speed = Double(cleaned) {
            // If it's likely km/h (common in OSM), convert to mph
            if speed > 50 {
                return speed * 0.621371 // Convert km/h to mph
            }
            return speed
        }
        
        // Handle special cases
        switch cleaned {
        case "none", "unlimited":
            return 70.0 // Default highway speed
        case "walk", "walking":
            return 5.0 // Walking speed
        case "bicycle", "cycling":
            return 15.0 // Cycling speed
        default:
            print("⚠️ Could not parse speed limit: '\(value)'")
            return nil // No default fallback - return nil if can't parse
        }
    }
}

