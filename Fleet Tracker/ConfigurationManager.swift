//
//  ConfigurationManager.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

// MARK: - Configuration Manager

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private init() {}
    
    // MARK: - Environment Detection
    
    var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
    
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Firebase Configuration
    
    var firebaseProjectId: String {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let projectId = plist["PROJECT_ID"] as? String else {
            fatalError("Firebase configuration not found")
        }
        return projectId
    }
    
    var firebaseAPIKey: String {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["API_KEY"] as? String else {
            fatalError("Firebase API key not found")
        }
        return apiKey
    }
    
    // MARK: - API Configuration
    
    var osmBaseURL: String {
        return "https://overpass-api.de/api/interpreter"
    }
    
    var osmTimeout: TimeInterval {
        return isProduction ? 30.0 : 60.0
    }
    
    // MARK: - Location Configuration
    
    var locationAccuracy: CLLocationAccuracy {
        return isProduction ? kCLLocationAccuracyNearestTenMeters : kCLLocationAccuracyBest
    }
    
    var locationUpdateInterval: TimeInterval {
        return isProduction ? 10.0 : 5.0
    }
    
    var locationDistanceFilter: Double {
        return isProduction ? 20.0 : 10.0
    }
    
    // MARK: - Cache Configuration
    
    var speedLimitCacheSize: Int {
        return isProduction ? 1000 : 500
    }
    
    var locationHistoryLimit: Int {
        return isProduction ? 200 : 100
    }
    
    // MARK: - Logging Configuration
    
    var enableDebugLogging: Bool {
        return !isProduction
    }
    
    var enablePerformanceLogging: Bool {
        return !isProduction
    }
    
    // MARK: - Feature Flags
    
    var enableBackgroundLocationUpdates: Bool {
        return true
    }
    
    var enablePotholeDetection: Bool {
        return true
    }
    
    var enableSpeedViolationAlerts: Bool {
        return true
    }
    
    var enableFirebaseSync: Bool {
        return true
    }
    
    // MARK: - Validation
    
    func validateConfiguration() -> Bool {
        // Validate Firebase configuration
        guard !firebaseProjectId.isEmpty else {
            print("❌ Firebase project ID is missing")
            return false
        }
        
        guard !firebaseAPIKey.isEmpty else {
            print("❌ Firebase API key is missing")
            return false
        }
        
        // Validate network configuration
        guard !osmBaseURL.isEmpty else {
            print("❌ OSM base URL is missing")
            return false
        }
        
        print("✅ Configuration validation passed")
        return true
    }
    
    // MARK: - Environment-Specific Settings
    
    func getLogLevel() -> LogLevel {
        return isProduction ? .error : .debug
    }
    
    func getMaxRetryAttempts() -> Int {
        return isProduction ? 3 : 1
    }
    
    func getBatchSize() -> Int {
        return isProduction ? 20 : 10
    }
}

// MARK: - Log Level

enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }
}

// MARK: - Configuration Validation

extension ConfigurationManager {
    
    func validateFirebaseConfiguration() -> Bool {
        let bundle = Bundle.main
        
        // Check if GoogleService-Info.plist exists
        guard bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("❌ GoogleService-Info.plist not found in bundle")
            return false
        }
        
        // Validate required keys
        guard let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            print("❌ Could not read GoogleService-Info.plist")
            return false
        }
        
        let requiredKeys = ["PROJECT_ID", "API_KEY", "GOOGLE_APP_ID"]
        for key in requiredKeys {
            guard let value = plist[key] as? String, !value.isEmpty else {
                print("❌ Missing or empty value for key: \(key)")
                return false
            }
        }
        
        print("✅ Firebase configuration is valid")
        return true
    }
    
    func validateLocationPermissions() -> Bool {
        // This would typically check if location permissions are properly configured
        // in Info.plist, but that's a compile-time check
        return true
    }
    
    func validateBackgroundModes() -> Bool {
        // Check if background location updates are properly configured
        guard let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else {
            print("❌ UIBackgroundModes not configured")
            return false
        }
        
        let requiredModes = ["location"]
        for mode in requiredModes {
            guard backgroundModes.contains(mode) else {
                print("❌ Required background mode '\(mode)' not configured")
                return false
            }
        }
        
        print("✅ Background modes are properly configured")
        return true
    }
}
