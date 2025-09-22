//
//  OSMDetroitSpeedLimitDownloader.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

class OSMDetroitSpeedLimitDownloader {
    private let baseURL = "https://overpass-api.de/api/interpreter"
    
    // Detroit Metro Area bounds
    private let detroitBounds = (
        south: 42.2, north: 42.6,
        west: -83.5, east: -82.8
    )
    
    func downloadAllDetroitSpeedLimits() async -> [OSMSpeedLimitData] {
        print("🚀 Starting comprehensive Detroit speed limit download...")
        
        let overpassQuery = """
        [out:json][timeout:300];
        (
          way["highway"]["maxspeed"](\(detroitBounds.south),\(detroitBounds.west),\(detroitBounds.north),\(detroitBounds.east));
          relation["highway"]["maxspeed"](\(detroitBounds.south),\(detroitBounds.west),\(detroitBounds.north),\(detroitBounds.east));
        );
        out geom;
        """
        
        do {
            let data = try await performOverpassQuery(overpassQuery)
            let speedLimits = try parseOSMResponse(data)
            
            print("✅ Downloaded \(speedLimits.count) speed limit records for Detroit")
            return speedLimits
            
        } catch {
            print("❌ Error downloading Detroit speed limits: \(error)")
            return []
        }
    }
    
    private func performOverpassQuery(_ query: String) async throws -> Data {
        guard let url = URL(string: baseURL) else {
            throw OSMError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OSMError.requestFailed
        }
        
        return data
    }
    
    private func parseOSMResponse(_ data: Data) throws -> [OSMSpeedLimitData] {
        let response = try JSONDecoder().decode(OSMResponse.self, from: data)
        var speedLimits: [OSMSpeedLimitData] = []
        
        for element in response.elements {
            if let speedLimit = parseSpeedLimit(from: element) {
                speedLimits.append(speedLimit)
            }
        }
        
        return speedLimits
    }
    
    private func parseSpeedLimit(from element: OSMElement) -> OSMSpeedLimitData? {
        guard let maxspeed = element.tags["maxspeed"],
              let speedValue = Double(maxspeed.replacingOccurrences(of: " mph", with: "")) else {
            return nil
        }
        
        let roadName = element.tags["name"] ?? element.tags["ref"] ?? "Unknown"
        let roadType = element.tags["highway"] ?? "unknown"
        
        // Get center point of the road segment
        let centerPoint = calculateCenterPoint(from: element.geometry)
        
        return OSMSpeedLimitData(
            coordinate: centerPoint,
            speedLimit: speedValue,
            roadName: roadName,
            roadType: roadType
        )
    }
    
    private func calculateCenterPoint(from geometry: [OSMGeometry]?) -> CLLocationCoordinate2D {
        guard let geometry = geometry, !geometry.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        let sumLat = geometry.reduce(0) { $0 + $1.lat }
        let sumLon = geometry.reduce(0) { $0 + $1.lon }
        
        return CLLocationCoordinate2D(
            latitude: sumLat / Double(geometry.count),
            longitude: sumLon / Double(geometry.count)
        )
    }
}

// MARK: - Error Types

enum OSMError: Error {
    case invalidURL
    case requestFailed
    case parsingFailed
}
