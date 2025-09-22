//
//  OSMDataModels.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

// MARK: - Shared OSM Data Models

struct OSMResponse: Codable {
    let elements: [OSMElement]
}

struct OSMElement: Codable {
    let type: String
    let id: Int
    let tags: [String: String]
    let geometry: [OSMGeometry]?
}

struct OSMGeometry: Codable {
    let lat: Double
    let lon: Double
}

struct OSMSpeedLimitData: Codable {
    let coordinate: CLLocationCoordinate2D
    let speedLimit: Double
    let roadName: String
    let roadType: String
    
    // Custom coding for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case latitude, longitude, speedLimit, roadName, roadType
    }
    
    init(coordinate: CLLocationCoordinate2D, speedLimit: Double, roadName: String, roadType: String) {
        self.coordinate = coordinate
        self.speedLimit = speedLimit
        self.roadName = roadName
        self.roadType = roadType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.speedLimit = try container.decode(Double.self, forKey: .speedLimit)
        self.roadName = try container.decode(String.self, forKey: .roadName)
        self.roadType = try container.decode(String.self, forKey: .roadType)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(speedLimit, forKey: .speedLimit)
        try container.encode(roadName, forKey: .roadName)
        try container.encode(roadType, forKey: .roadType)
    }
}
