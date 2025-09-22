//
//  LocalSpeedLimitDatabase.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

class LocalSpeedLimitDatabase {
    static let shared = LocalSpeedLimitDatabase()
    
    private var speedLimitData: [OSMSpeedLimitData] = []
    private let fileManager = FileManager.default
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let dataFileName = "speed_limits.json"
    
    private init() {
        loadSpeedLimitData()
    }
    
    // MARK: - Data Management
    
    func loadSpeedLimitData() {
        let fileURL = documentsDirectory.appendingPathComponent(dataFileName)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                speedLimitData = try JSONDecoder().decode([OSMSpeedLimitData].self, from: data)
                print("Loaded \(speedLimitData.count) speed limit records from local storage")
            } catch {
                print("Error loading speed limit data: \(error)")
                speedLimitData = []
            }
        } else {
            print("No local speed limit data found. Run download to populate.")
            speedLimitData = []
        }
    }
    
    func saveSpeedLimitData() {
        let fileURL = documentsDirectory.appendingPathComponent(dataFileName)
        
        do {
            let data = try JSONEncoder().encode(speedLimitData)
            try data.write(to: fileURL)
            print("Saved \(speedLimitData.count) speed limit records to local storage")
        } catch {
            print("Error saving speed limit data: \(error)")
        }
    }
    
    func addSpeedLimitData(_ newData: [OSMSpeedLimitData]) {
        // Merge with existing data, avoiding duplicates
        for newItem in newData {
            if !speedLimitData.contains(where: { 
                $0.coordinate.latitude == newItem.coordinate.latitude && 
                $0.coordinate.longitude == newItem.coordinate.longitude 
            }) {
                speedLimitData.append(newItem)
            }
        }
        saveSpeedLimitData()
    }
    
    // MARK: - Speed Limit Lookup
    
    func getSpeedLimit(for coordinate: CLLocationCoordinate2D, searchRadius: Double = 100) -> Double? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        var closestData: OSMSpeedLimitData?
        var closestDistance: Double = Double.infinity
        
        for data in speedLimitData {
            let dataLocation = CLLocation(latitude: data.coordinate.latitude, longitude: data.coordinate.longitude)
            let distance = location.distance(from: dataLocation)
            
            if distance <= searchRadius && distance < closestDistance {
                closestDistance = distance
                closestData = data
            }
        }
        
        return closestData?.speedLimit
    }
    
    func getSpeedLimitWithDetails(for coordinate: CLLocationCoordinate2D, searchRadius: Double = 100) -> OSMSpeedLimitData? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        var closestData: OSMSpeedLimitData?
        var closestDistance: Double = Double.infinity
        
        for data in speedLimitData {
            let dataLocation = CLLocation(latitude: data.coordinate.latitude, longitude: data.coordinate.longitude)
            let distance = location.distance(from: dataLocation)
            
            if distance <= searchRadius && distance < closestDistance {
                closestDistance = distance
                closestData = data
            }
        }
        
        return closestData
    }
    
    // MARK: - Data Statistics
    
    func getDataStatistics() -> (total: Int, byRoadType: [String: Int], bySpeedRange: [String: Int]) {
        var byRoadType: [String: Int] = [:]
        var bySpeedRange: [String: Int] = [:]
        
        for data in speedLimitData {
            // Count by road type
            byRoadType[data.roadType, default: 0] += 1
            
            // Count by speed range
            let speedRange: String
            switch data.speedLimit {
            case 0..<25: speedRange = "0-24 mph"
            case 25..<35: speedRange = "25-34 mph"
            case 35..<45: speedRange = "35-44 mph"
            case 45..<55: speedRange = "45-54 mph"
            case 55..<65: speedRange = "55-64 mph"
            case 65...: speedRange = "65+ mph"
            default: speedRange = "Unknown"
            }
            bySpeedRange[speedRange, default: 0] += 1
        }
        
        return (total: speedLimitData.count, byRoadType: byRoadType, bySpeedRange: bySpeedRange)
    }
    
    // MARK: - Data Management
    
    func clearAllData() {
        speedLimitData.removeAll()
        saveSpeedLimitData()
        print("Cleared all speed limit data")
    }
    
    func getDataCount() -> Int {
        return speedLimitData.count
    }
    
    func hasData() -> Bool {
        return !speedLimitData.isEmpty
    }
}
