//
//  ErrorHandler.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation
import FirebaseFirestore

// MARK: - Custom Error Types

enum FleetTrackerError: LocalizedError {
    case locationPermissionDenied
    case locationServicesDisabled
    case networkConnectionFailed
    case firebaseConfigurationError
    case firebaseOperationFailed(String)
    case speedLimitDetectionFailed
    case dataValidationFailed(String)
    case accelerometerUnavailable
    case geocodingFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "Location permission denied. Please enable location access in Settings."
        case .locationServicesDisabled:
            return "Location services are disabled. Please enable them in Settings."
        case .networkConnectionFailed:
            return "Network connection failed. Please check your internet connection."
        case .firebaseConfigurationError:
            return "Firebase configuration error. Please restart the app."
        case .firebaseOperationFailed(let operation):
            return "Firebase operation failed: \(operation)"
        case .speedLimitDetectionFailed:
            return "Unable to detect speed limit for current location."
        case .dataValidationFailed(let field):
            return "Data validation failed for field: \(field)"
        case .accelerometerUnavailable:
            return "Accelerometer is not available on this device."
        case .geocodingFailed:
            return "Unable to determine address from location."
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .locationPermissionDenied:
            return "Go to Settings > Privacy & Security > Location Services and enable location access for Fleet Tracker."
        case .locationServicesDisabled:
            return "Go to Settings > Privacy & Security > Location Services and enable location services."
        case .networkConnectionFailed:
            return "Check your Wi-Fi or cellular connection and try again."
        case .firebaseConfigurationError:
            return "Delete and reinstall the app, or contact support if the problem persists."
        case .firebaseOperationFailed:
            return "Try again in a few moments. If the problem persists, contact support."
        case .speedLimitDetectionFailed:
            return "Try moving to a different location or check your internet connection."
        case .dataValidationFailed:
            return "Please check your input and try again."
        case .accelerometerUnavailable:
            return "This feature requires a device with an accelerometer."
        case .geocodingFailed:
            return "Try again in a few moments or check your internet connection."
        case .unknown:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .locationPermissionDenied, .locationServicesDisabled:
            return .critical
        case .firebaseConfigurationError, .networkConnectionFailed:
            return .high
        case .firebaseOperationFailed, .speedLimitDetectionFailed, .geocodingFailed:
            return .medium
        case .dataValidationFailed, .accelerometerUnavailable:
            return .low
        case .unknown:
            return .medium
        }
    }
}

enum ErrorSeverity: String, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var priority: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

// MARK: - Error Handler

class ErrorHandler {
    static let shared = ErrorHandler()
    
    private let logger = Logger.shared
    private var errorCounts: [String: Int] = [:]
    private var lastErrorTimes: [String: Date] = [:]
    
    private init() {}
    
    // MARK: - Error Handling
    
    func handle(_ error: Error, context: String = "", userFacing: Bool = true) {
        let fleetError = mapToFleetTrackerError(error)
        
        // Log the error
        logError(fleetError, context: context)
        
        // Track error frequency
        trackErrorFrequency(fleetError)
        
        // Show user-facing error if needed
        if userFacing {
            showUserError(fleetError)
        }
        
        // Report critical errors
        if fleetError.severity == .critical {
            reportCriticalError(fleetError, context: context)
        }
    }
    
    func handleAsync(_ error: Error, context: String = "", userFacing: Bool = true) async {
        await MainActor.run {
            handle(error, context: context, userFacing: userFacing)
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapToFleetTrackerError(_ error: Error) -> FleetTrackerError {
        if let fleetError = error as? FleetTrackerError {
            return fleetError
        }
        
        // Map common system errors
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                return .locationPermissionDenied
            case .locationUnknown:
                return .speedLimitDetectionFailed
            case .network:
                return .networkConnectionFailed
            default:
                return .unknown("Location error: \(clError.localizedDescription)")
            }
        }
        
        // Map Firestore errors
        if let nsError = error as? NSError, nsError.domain == "FIRFirestoreErrorDomain" {
            return .firebaseOperationFailed(nsError.localizedDescription)
        }
        
        // Map network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkConnectionFailed
            case .timedOut:
                return .networkConnectionFailed
            default:
                return .unknown("Network error: \(urlError.localizedDescription)")
            }
        }
        
        return .unknown(error.localizedDescription)
    }
    
    // MARK: - Error Logging
    
    private func logError(_ error: FleetTrackerError, context: String) {
        let message = "Error in \(context): \(error.localizedDescription)"
        
        switch error.severity {
        case .critical:
            logger.error(message)
        case .high:
            logger.error(message)
        case .medium:
            logger.warning(message)
        case .low:
            logger.info(message)
        }
    }
    
    // MARK: - Error Tracking
    
    private func trackErrorFrequency(_ error: FleetTrackerError) {
        let errorKey = String(describing: error)
        errorCounts[errorKey, default: 0] += 1
        lastErrorTimes[errorKey] = Date()
        
        // Log if error frequency is high
        if let count = errorCounts[errorKey], count > 5 {
            logger.warning("High error frequency for \(errorKey): \(count) occurrences")
        }
    }
    
    // MARK: - User Error Display
    
    private func showUserError(_ error: FleetTrackerError) {
        // This would typically show an alert or toast notification
        // For now, we'll just log it
        logger.info("User-facing error: \(error.localizedDescription)")
        
        if let recoverySuggestion = error.recoverySuggestion {
            logger.info("Recovery suggestion: \(recoverySuggestion)")
        }
    }
    
    // MARK: - Critical Error Reporting
    
    private func reportCriticalError(_ error: FleetTrackerError, context: String) {
        // In a real app, this would send error reports to a crash reporting service
        logger.error("CRITICAL ERROR REPORT: \(error.localizedDescription) in \(context)")
        
        // Could integrate with services like:
        // - Firebase Crashlytics
        // - Sentry
        // - Bugsnag
        // - Custom error reporting API
    }
    
    // MARK: - Error Statistics
    
    func getErrorStatistics() -> (totalErrors: Int, errorBreakdown: [String: Int], recentErrors: [String]) {
        let totalErrors = errorCounts.values.reduce(0, +)
        
        var recentErrors: [String] = []
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        
        for (errorKey, lastTime) in lastErrorTimes {
            if lastTime > fiveMinutesAgo {
                recentErrors.append(errorKey)
            }
        }
        
        return (totalErrors, errorCounts, recentErrors)
    }
    
    func clearErrorStatistics() {
        errorCounts.removeAll()
        lastErrorTimes.removeAll()
        logger.info("Error statistics cleared")
    }
    
    // MARK: - Retry Logic
    
    func shouldRetry(_ error: Error, attemptCount: Int) -> Bool {
        guard attemptCount < 3 else { return false }
        
        if let fleetError = error as? FleetTrackerError {
            switch fleetError {
            case .networkConnectionFailed, .firebaseOperationFailed, .geocodingFailed:
                return true
            case .locationPermissionDenied, .locationServicesDisabled, .firebaseConfigurationError:
                return false
            case .speedLimitDetectionFailed, .dataValidationFailed, .accelerometerUnavailable:
                return attemptCount < 2
            case .unknown:
                return attemptCount < 1
            }
        }
        
        return attemptCount < 2
    }
    
    func getRetryDelay(for attemptCount: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s
        return TimeInterval(pow(2.0, Double(attemptCount)))
    }
}

// MARK: - Error Recovery Actions

extension ErrorHandler {
    
    func getRecoveryActions(for error: FleetTrackerError) -> [RecoveryAction] {
        switch error {
        case .locationPermissionDenied:
            return [
                RecoveryAction(title: "Open Settings", action: .openSettings),
                RecoveryAction(title: "Retry", action: .retry)
            ]
        case .locationServicesDisabled:
            return [
                RecoveryAction(title: "Open Settings", action: .openSettings)
            ]
        case .networkConnectionFailed:
            return [
                RecoveryAction(title: "Retry", action: .retry),
                RecoveryAction(title: "Check Connection", action: .checkConnection)
            ]
        case .firebaseConfigurationError:
            return [
                RecoveryAction(title: "Restart App", action: .restartApp),
                RecoveryAction(title: "Contact Support", action: .contactSupport)
            ]
        case .firebaseOperationFailed:
            return [
                RecoveryAction(title: "Retry", action: .retry)
            ]
        case .speedLimitDetectionFailed:
            return [
                RecoveryAction(title: "Retry", action: .retry),
                RecoveryAction(title: "Use Manual Entry", action: .manualEntry)
            ]
        case .dataValidationFailed:
            return [
                RecoveryAction(title: "Check Input", action: .checkInput),
                RecoveryAction(title: "Retry", action: .retry)
            ]
        case .accelerometerUnavailable:
            return [
                RecoveryAction(title: "Continue Without", action: .continueWithout)
            ]
        case .geocodingFailed:
            return [
                RecoveryAction(title: "Retry", action: .retry),
                RecoveryAction(title: "Enter Manually", action: .manualEntry)
            ]
        case .unknown:
            return [
                RecoveryAction(title: "Retry", action: .retry),
                RecoveryAction(title: "Contact Support", action: .contactSupport)
            ]
        }
    }
}

// MARK: - Recovery Actions

struct RecoveryAction {
    let title: String
    let action: RecoveryActionType
    
    enum RecoveryActionType {
        case retry
        case openSettings
        case checkConnection
        case restartApp
        case contactSupport
        case manualEntry
        case checkInput
        case continueWithout
    }
}

// MARK: - Global Error Handler

let errorHandler = ErrorHandler.shared
