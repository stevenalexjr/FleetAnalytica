//
//  SpeedLimitDataManager.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

class SpeedLimitDataManager {
    static let shared = SpeedLimitDataManager()
    
    private let osmService = OSMSpeedLimitService()
    
    private init() {}
    
    // MARK: - Data Management
    
    /// Download and store speed limit data for Detroit area
    func setupDetroitData() async {
        print("🚀 Setting up Detroit speed limit data...")
        
        if osmService.hasLocalData() {
            let stats = osmService.getDataStatistics()
            print("✅ Local data already exists: \(stats.total) records")
            return
        }
        
        print("📥 Downloading Detroit speed limit data...")
        await osmService.downloadDetroitSpeedLimits()
        
        let stats = osmService.getDataStatistics()
        print("✅ Download complete: \(stats.total) speed limit records")
        print("📊 Road types: \(stats.byRoadType)")
        print("📊 Speed ranges: \(stats.bySpeedRange)")
    }
    
    /// Download data for a specific region
    func setupRegionData(center: CLLocationCoordinate2D, radius: Double = 2000) async {
        print("🚀 Setting up speed limit data for region...")
        print("📍 Center: \(center.latitude), \(center.longitude)")
        print("📏 Radius: \(radius) meters")
        
        await osmService.downloadAndStoreSpeedLimits(for: center, radius: radius)
        
        let stats = osmService.getDataStatistics()
        print("✅ Region setup complete: \(stats.total) total records")
    }
    
    /// Get speed limit for a coordinate
    func getSpeedLimit(for coordinate: CLLocationCoordinate2D) -> Double? {
        return osmService.getSpeedLimit(for: coordinate)
    }
    
    /// Get detailed speed limit information
    func getSpeedLimitDetails(for coordinate: CLLocationCoordinate2D) -> (speedLimit: Double?, roadName: String?, roadType: String?) {
        let localDB = LocalSpeedLimitDatabase.shared
        if let data = localDB.getSpeedLimitWithDetails(for: coordinate) {
            return (data.speedLimit, data.roadName, data.roadType)
        }
        return (nil, nil, nil)
    }
    
    // MARK: - Data Statistics
    
    func getDataInfo() -> (hasData: Bool, totalRecords: Int, coverage: String) {
        let hasData = osmService.hasLocalData()
        let stats = osmService.getDataStatistics()
        
        let coverage: String
        if hasData {
            coverage = "Local database with \(stats.total) records"
        } else {
            coverage = "No local data - using live queries"
        }
        
        return (hasData, stats.total, coverage)
    }
    
    // MARK: - Testing Functions
    
    /// Test speed limit detection at various Detroit locations
    func testDetroitLocations() {
        let testLocations = [
            ("Downtown Detroit", CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458)),
            ("Woodward Avenue", CLLocationCoordinate2D(latitude: 42.3384, longitude: -83.0458)),
            ("I-75 Freeway", CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0358)),
            ("Residential Area", CLLocationCoordinate2D(latitude: 42.3214, longitude: -83.0558))
        ]
        
        print("🧪 Testing speed limit detection...")
        
        for (name, coordinate) in testLocations {
            if let speedLimit = getSpeedLimit(for: coordinate) {
                let details = getSpeedLimitDetails(for: coordinate)
                print("📍 \(name): \(Int(speedLimit)) mph")
                if let roadName = details.roadName {
                    print("   Road: \(roadName)")
                }
                if let roadType = details.roadType {
                    print("   Type: \(roadType)")
                }
            } else {
                print("📍 \(name): No speed limit data found")
            }
        }
    }
}
