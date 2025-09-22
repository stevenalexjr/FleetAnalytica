//
//  Logger.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation
import os.log

// MARK: - Logger

class Logger {
    static let shared = Logger()
    
    private let configuration = ConfigurationManager.shared
    private let osLog = OSLog(subsystem: "com.fleettracker.app", category: "general")
    
    private init() {}
    
    // MARK: - Public Logging Methods
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, file: file, function: function, line: line)
    }
    
    func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard configuration.enablePerformanceLogging else { return }
        log(.info, message: "PERF: \(message)", file: file, function: function, line: line)
    }
    
    // MARK: - Location Tracking
    
    func locationUpdate(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard configuration.enableDebugLogging else { return }
        log(.debug, message: "📍 \(message)", file: file, function: function, line: line)
    }
    
    func speedLimit(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard configuration.enableDebugLogging else { return }
        log(.debug, message: "🚦 \(message)", file: file, function: function, line: line)
    }
    
    func violation(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: "⚠️ \(message)", file: file, function: function, line: line)
    }
    
    func firebase(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard configuration.enableDebugLogging else { return }
        log(.debug, message: "🔥 \(message)", file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private func log(_ level: LogLevel, message: String, file: String, function: String, line: Int) {
        guard level.priority >= configuration.getLogLevel().priority else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function): \(message)"
        
        // Log to console in debug builds
        if configuration.enableDebugLogging {
            print(logMessage)
        }
        
        // Log to system log
        let osLogType: OSLogType
        switch level {
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warning:
            osLogType = .default
        case .error:
            osLogType = .error
        }
        
        os_log("%{public}@", log: osLog, type: osLogType, logMessage)
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Convenience Extensions

extension Logger {
    
    func logLocationUpdate(coordinate: CLLocationCoordinate2D, accuracy: Double, speed: Double?) {
        let speedText = speed != nil ? String(format: "%.1f m/s", speed!) : "N/A"
        locationUpdate("Lat: \(String(format: "%.6f", coordinate.latitude)), Lon: \(String(format: "%.6f", coordinate.longitude)), Accuracy: \(String(format: "%.1f", accuracy))m, Speed: \(speedText)")
    }
    
    func logSpeedLimitDetection(coordinate: CLLocationCoordinate2D, speedLimit: Double?, source: String) {
        if let limit = speedLimit {
            self.speedLimit("Detected \(Int(limit)) mph from \(source) at \(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))")
        } else {
            self.speedLimit("No speed limit found from \(source) at \(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))")
        }
    }
    
    func logViolation(type: String, details: String) {
        violation("\(type): \(details)")
    }
    
    func logFirebaseOperation(operation: String, success: Bool, details: String? = nil) {
        let status = success ? "✅" : "❌"
        let message = "\(operation): \(status)"
        let fullMessage = details != nil ? "\(message) - \(details!)" : message
        firebase(fullMessage)
    }
    
    func logPerformance(operation: String, duration: TimeInterval, details: String? = nil) {
        let message = "\(operation) took \(String(format: "%.3f", duration))s"
        let fullMessage = details != nil ? "\(message) - \(details!)" : message
        performance(fullMessage)
    }
}

// MARK: - Global Logger Instance

let logger = Logger.shared
