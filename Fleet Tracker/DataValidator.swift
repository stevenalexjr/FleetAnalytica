//
//  DataValidator.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    
    init(isValid: Bool, errors: [ValidationError] = []) {
        self.isValid = isValid
        self.errors = errors
    }
    
    var hasErrors: Bool {
        return !errors.isEmpty
    }
    
    var errorMessages: [String] {
        return errors.map { $0.message }
    }
}

struct ValidationError {
    let field: String
    let message: String
    let severity: ValidationSeverity
    
    enum ValidationSeverity {
        case error
        case warning
        case info
    }
}

// MARK: - Data Validator

class DataValidator {
    static let shared = DataValidator()
    
    private init() {}
    
    // MARK: - Location Validation
    
    func validateLocation(_ location: CLLocation) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Check coordinate validity
        if !isValidCoordinate(location.coordinate) {
            errors.append(ValidationError(
                field: "coordinate",
                message: "Invalid coordinate values",
                severity: .error
            ))
        }
        
        // Check accuracy
        if location.horizontalAccuracy < 0 {
            errors.append(ValidationError(
                field: "accuracy",
                message: "Invalid accuracy value",
                severity: .error
            ))
        } else if location.horizontalAccuracy > 100 {
            errors.append(ValidationError(
                field: "accuracy",
                message: "Location accuracy is poor (\(Int(location.horizontalAccuracy))m)",
                severity: .warning
            ))
        }
        
        // Check timestamp
        let age = Date().timeIntervalSince(location.timestamp)
        if age > 300 { // 5 minutes
            errors.append(ValidationError(
                field: "timestamp",
                message: "Location data is stale (\(Int(age))s old)",
                severity: .warning
            ))
        }
        
        // Check speed
        if location.speed < 0 {
            errors.append(ValidationError(
                field: "speed",
                message: "Invalid speed value",
                severity: .error
            ))
        } else if location.speed > 200 { // 200 m/s = ~450 mph
            errors.append(ValidationError(
                field: "speed",
                message: "Unrealistic speed detected (\(Int(location.speed * 2.237)) mph)",
                severity: .warning
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    func validateLocationRecord(_ record: LocationRecord) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Validate coordinate
        if !isValidCoordinate(CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)) {
            errors.append(ValidationError(
                field: "coordinate",
                message: "Invalid coordinate values",
                severity: .error
            ))
        }
        
        // Validate timestamp
        if record.timestamp > Date() {
            errors.append(ValidationError(
                field: "timestamp",
                message: "Future timestamp detected",
                severity: .error
            ))
        }
        
        // Validate speed
        if let speed = record.speedInMph {
            if speed < 0 {
                errors.append(ValidationError(
                    field: "speed",
                    message: "Invalid speed value",
                    severity: .error
                ))
            } else if speed > 200 {
                errors.append(ValidationError(
                    field: "speed",
                    message: "Unrealistic speed detected (\(Int(speed)) mph)",
                    severity: .warning
                ))
            }
        }
        
        // Validate speed limit
        if let speedLimit = record.speedLimit {
            if speedLimit < 5 || speedLimit > 100 {
                errors.append(ValidationError(
                    field: "speedLimit",
                    message: "Unrealistic speed limit (\(Int(speedLimit)) mph)",
                    severity: .warning
                ))
            }
        }
        
        // Validate acceleration values
        if let acceleration = record.acceleration {
            if abs(acceleration) > 20 { // 20 m/s² = ~2g
                errors.append(ValidationError(
                    field: "acceleration",
                    message: "Extreme acceleration detected (\(String(format: "%.1f", acceleration)) m/s²)",
                    severity: .warning
                ))
            }
        }
        
        if let deceleration = record.deceleration {
            if abs(deceleration) > 20 {
                errors.append(ValidationError(
                    field: "deceleration",
                    message: "Extreme deceleration detected (\(String(format: "%.1f", deceleration)) m/s²)",
                    severity: .warning
                ))
            }
        }
        
        // Validate heading
        if let heading = record.heading {
            if heading < 0 || heading > 360 {
                errors.append(ValidationError(
                    field: "heading",
                    message: "Invalid heading value (\(heading)°)",
                    severity: .error
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Trip Validation
    
    func validateTrip(_ trip: Trip) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Validate trip ID
        if trip.id.isEmpty {
            errors.append(ValidationError(
                field: "id",
                message: "Trip ID cannot be empty",
                severity: .error
            ))
        }
        
        // Validate start time
        if trip.startTime > Date() {
            errors.append(ValidationError(
                field: "startTime",
                message: "Trip start time cannot be in the future",
                severity: .error
            ))
        }
        
        // Validate end time
        if let endTime = trip.endTime {
            if endTime < trip.startTime {
                errors.append(ValidationError(
                    field: "endTime",
                    message: "Trip end time cannot be before start time",
                    severity: .error
                ))
            }
            
            if endTime > Date() {
                errors.append(ValidationError(
                    field: "endTime",
                    message: "Trip end time cannot be in the future",
                    severity: .error
                ))
            }
        }
        
        // Validate distance
        if trip.totalDistance < 0 {
            errors.append(ValidationError(
                field: "totalDistance",
                message: "Trip distance cannot be negative",
                severity: .error
            ))
        } else if trip.totalDistance > 1000000 { // 1000 km
            errors.append(ValidationError(
                field: "totalDistance",
                message: "Unrealistic trip distance (\(String(format: "%.1f", trip.totalDistance/1000)) km)",
                severity: .warning
            ))
        }
        
        // Validate violation counts
        if trip.speedViolations < 0 {
            errors.append(ValidationError(
                field: "speedViolations",
                message: "Speed violations count cannot be negative",
                severity: .error
            ))
        }
        
        if trip.hardStops < 0 {
            errors.append(ValidationError(
                field: "hardStops",
                message: "Hard stops count cannot be negative",
                severity: .error
            ))
        }
        
        if trip.sharpTurns < 0 {
            errors.append(ValidationError(
                field: "sharpTurns",
                message: "Sharp turns count cannot be negative",
                severity: .error
            ))
        }
        
        if trip.potholesDetected < 0 {
            errors.append(ValidationError(
                field: "potholesDetected",
                message: "Potholes detected count cannot be negative",
                severity: .error
            ))
        }
        
        // Validate driver score
        if trip.driverScore < 0 || trip.driverScore > 100 {
            errors.append(ValidationError(
                field: "driverScore",
                message: "Driver score must be between 0 and 100",
                severity: .error
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Speed Limit Validation
    
    func validateSpeedLimit(_ speedLimit: Double, coordinate: CLLocationCoordinate2D) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Basic range validation
        if speedLimit < 5 {
            errors.append(ValidationError(
                field: "speedLimit",
                message: "Speed limit too low (\(Int(speedLimit)) mph)",
                severity: .warning
            ))
        }
        
        if speedLimit > 100 {
            errors.append(ValidationError(
                field: "speedLimit",
                message: "Speed limit too high (\(Int(speedLimit)) mph)",
                severity: .warning
            ))
        }
        
        // Context-aware validation
        if speedLimit > 70 && isUrbanArea(coordinate) {
            errors.append(ValidationError(
                field: "speedLimit",
                message: "High speed limit in urban area (\(Int(speedLimit)) mph)",
                severity: .warning
            ))
        }
        
        if speedLimit < 25 && isHighwayArea(coordinate) {
            errors.append(ValidationError(
                field: "speedLimit",
                message: "Low speed limit on highway (\(Int(speedLimit)) mph)",
                severity: .warning
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Address Validation
    
    func validateAddress(_ address: String) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Check if address is empty
        if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(
                field: "address",
                message: "Address cannot be empty",
                severity: .error
            ))
        }
        
        // Check minimum length
        if address.count < 3 {
            errors.append(ValidationError(
                field: "address",
                message: "Address too short",
                severity: .error
            ))
        }
        
        // Check maximum length
        if address.count > 200 {
            errors.append(ValidationError(
                field: "address",
                message: "Address too long",
                severity: .error
            ))
        }
        
        // Check for invalid characters
        let invalidCharacters = CharacterSet(charactersIn: "<>\"'&")
        if address.rangeOfCharacter(from: invalidCharacters) != nil {
            errors.append(ValidationError(
                field: "address",
                message: "Address contains invalid characters",
                severity: .error
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - API Response Validation
    
    func validateOSMResponse(_ data: Data) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Check if data is empty
        if data.isEmpty {
            errors.append(ValidationError(
                field: "response",
                message: "Empty response from OSM API",
                severity: .error
            ))
        }
        
        // Check if data is too large
        if data.count > 10 * 1024 * 1024 { // 10MB
            errors.append(ValidationError(
                field: "response",
                message: "Response too large (\(data.count / 1024 / 1024)MB)",
                severity: .warning
            ))
        }
        
        // Try to parse as JSON
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            guard let dict = json as? [String: Any] else {
                errors.append(ValidationError(
                    field: "response",
                    message: "Invalid JSON structure",
                    severity: .error
                ))
                return ValidationResult(isValid: false, errors: errors)
            }
            
            // Check for OSM-specific fields
            if dict["elements"] == nil {
                errors.append(ValidationError(
                    field: "response",
                    message: "Missing 'elements' field in OSM response",
                    severity: .error
                ))
            }
            
        } catch {
            errors.append(ValidationError(
                field: "response",
                message: "Invalid JSON format: \(error.localizedDescription)",
                severity: .error
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    func validateFirebaseDocument(_ data: [String: Any]) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Check required fields
        let requiredFields = ["id", "timestamp"]
        for field in requiredFields {
            if data[field] == nil {
                errors.append(ValidationError(
                    field: field,
                    message: "Missing required field: \(field)",
                    severity: .error
                ))
            }
        }
        
        // Validate timestamp
        if let timestamp = data["timestamp"] as? Date {
            if timestamp > Date() {
                errors.append(ValidationError(
                    field: "timestamp",
                    message: "Future timestamp in document",
                    severity: .error
                ))
            }
        }
        
        // Validate device ID
        if let deviceId = data["deviceId"] as? String {
            if deviceId.isEmpty {
                errors.append(ValidationError(
                    field: "deviceId",
                    message: "Device ID cannot be empty",
                    severity: .error
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Helper Methods
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180 &&
               !coordinate.latitude.isNaN && !coordinate.longitude.isNaN
    }
    
    private func isUrbanArea(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // Simplified urban area detection
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        
        // Major metropolitan areas
        let metropolitanAreas: [(lat: Double, lon: Double, radius: Double)] = [
            (42.3314, -83.0458, 0.3), // Detroit
            (40.7128, -74.0060, 0.3), // New York
            (34.0522, -118.2437, 0.4), // Los Angeles
            (41.8781, -87.6298, 0.3), // Chicago
        ]
        
        for area in metropolitanAreas {
            let distance = sqrt(pow(latitude - area.lat, 2) + pow(longitude - area.lon, 2))
            if distance <= area.radius {
                return true
            }
        }
        
        return false
    }
    
    private func isHighwayArea(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // Check if coordinates are near known highway corridors
        let highwayCorridors: [(lat: Double, lon: Double, radius: Double)] = [
            (42.0, -83.0, 0.5), // I-75 corridor
            (42.0, -84.0, 0.5), // I-96 corridor
            (41.0, -83.0, 0.5), // I-94 corridor
        ]
        
        for corridor in highwayCorridors {
            let distance = sqrt(pow(coordinate.latitude - corridor.lat, 2) + pow(coordinate.longitude - corridor.lon, 2))
            if distance <= corridor.radius {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Validation Extensions

extension DataValidator {
    
    func validateAll(_ locationRecord: LocationRecord) -> ValidationResult {
        let locationValidation = validateLocationRecord(locationRecord)
        var allErrors = locationValidation.errors
        
        // Additional cross-field validations
        if let speed = locationRecord.speedInMph, let speedLimit = locationRecord.speedLimit {
            if speed > speedLimit * 1.5 { // 50% over limit
                allErrors.append(ValidationError(
                    field: "speedViolation",
                    message: "Extreme speed violation (\(Int(speed)) mph vs \(Int(speedLimit)) mph limit)",
                    severity: .warning
                ))
            }
        }
        
        return ValidationResult(isValid: allErrors.isEmpty, errors: allErrors)
    }
    
    func validateBatch(_ records: [LocationRecord]) -> ValidationResult {
        var allErrors: [ValidationError] = []
        
        for (index, record) in records.enumerated() {
            let result = validateLocationRecord(record)
            for error in result.errors {
                let indexedError = ValidationError(
                    field: "\(error.field)[\(index)]",
                    message: error.message,
                    severity: error.severity
                )
                allErrors.append(indexedError)
            }
        }
        
        // Batch-level validations
        if records.count > 100 {
            allErrors.append(ValidationError(
                field: "batchSize",
                message: "Batch size too large (\(records.count) records)",
                severity: .warning
            ))
        }
        
        return ValidationResult(isValid: allErrors.isEmpty, errors: allErrors)
    }
}

// MARK: - Global Validator Instance

let dataValidator = DataValidator.shared
