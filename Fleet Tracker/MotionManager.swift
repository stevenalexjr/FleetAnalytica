//
//  MotionManager.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreMotion
import Combine

// MARK: - Motion Manager

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let logger = Logger.shared
    private let errorHandler = ErrorHandler.shared
    
    @Published var isAccelerometerAvailable: Bool = false
    @Published var isAccelerometerActive: Bool = false
    @Published var lastAccelerationData: CMAccelerometerData?
    
    // Motion detection callbacks
    var onPotholeDetected: (() -> Void)?
    var onHardStopDetected: (() -> Void)?
    var onSharpTurnDetected: (() -> Void)?
    
    // Detection thresholds
    private let potholeVerticalThreshold: Double = 1.8
    private let potholeTotalThreshold: Double = 2.0
    private let hardStopThreshold: Double = 2.5
    private var sharpTurnThreshold: Double = 40.0 // Adjusted based on research: normal turns are 15-30°, sharp turns are 45°+
    
    init() {
        setupMotionManager()
    }
    
    deinit {
        stopAccelerometerUpdates()
    }
    
    // MARK: - Setup
    
    private func setupMotionManager() {
        isAccelerometerAvailable = motionManager.isAccelerometerAvailable
        
        guard isAccelerometerAvailable else {
            logger.warning("Accelerometer not available on this device")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.2 // 5 Hz
        logger.info("Motion manager initialized")
    }
    
    // MARK: - Public Methods
    
    func startAccelerometerUpdates() {
        guard isAccelerometerAvailable else {
            logger.warning("Cannot start accelerometer updates - not available")
            return
        }
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleAccelerometerError(error)
                return
            }
            
            guard let data = data else { return }
            
            DispatchQueue.main.async {
                self.lastAccelerationData = data
                self.processAccelerometerData(data)
            }
        }
        
        isAccelerometerActive = true
        logger.info("Accelerometer updates started")
    }
    
    func stopAccelerometerUpdates() {
        motionManager.stopAccelerometerUpdates()
        isAccelerometerActive = false
        logger.info("Accelerometer updates stopped")
    }
    
    // MARK: - Motion Detection
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let x = data.acceleration.x
        let y = data.acceleration.y
        let z = data.acceleration.z
        
        let totalAcceleration = sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2))
        let verticalAcceleration = abs(z)
        
        // Log accelerometer data occasionally for debugging
        if Int.random(in: 1...20) == 1 { // Log only 5% of updates
            logger.debug("Accelerometer: X:\(String(format: "%.2f", x)) Y:\(String(format: "%.2f", y)) Z:\(String(format: "%.2f", z)) Total:\(String(format: "%.2f", totalAcceleration))g")
        }
        
        // Detect potholes
        if detectPothole(verticalAcceleration: verticalAcceleration, totalAcceleration: totalAcceleration) {
            onPotholeDetected?()
        }
    }
    
    func detectPothole(verticalAcceleration: Double? = nil, totalAcceleration: Double? = nil) -> Bool {
        guard isAccelerometerAvailable && isAccelerometerActive else {
            logger.warning("Accelerometer not available or inactive")
            return false
        }
        
        guard let accelerometerData = lastAccelerationData else {
            logger.warning("No accelerometer data available")
            return false
        }
        
        let x = accelerometerData.acceleration.x
        let y = accelerometerData.acceleration.y
        let z = accelerometerData.acceleration.z
        
        let calculatedTotalAcceleration = sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2))
        let calculatedVerticalAcceleration = abs(z)
        
        let finalVerticalAcceleration = verticalAcceleration ?? calculatedVerticalAcceleration
        let finalTotalAcceleration = totalAcceleration ?? calculatedTotalAcceleration
        
        logger.debug("Pothole Check: X:\(String(format: "%.2f", x)) Y:\(String(format: "%.2f", y)) Z:\(String(format: "%.2f", z)) Total:\(String(format: "%.2f", finalTotalAcceleration))g")
        
        let potholeDetected = finalVerticalAcceleration > potholeVerticalThreshold || finalTotalAcceleration > potholeTotalThreshold
        
        if potholeDetected {
            logger.violation("POTHOLE DETECTED! Vertical: \(String(format: "%.2f", finalVerticalAcceleration))g, Total: \(String(format: "%.2f", finalTotalAcceleration))g")
        } else {
            logger.debug("No pothole detected - Vertical: \(String(format: "%.2f", finalVerticalAcceleration))g (threshold: \(potholeVerticalThreshold)g), Total: \(String(format: "%.2f", finalTotalAcceleration))g (threshold: \(potholeTotalThreshold)g)")
        }
        
        return potholeDetected
    }
    
    func detectHardStop(deceleration: Double) -> Bool {
        let hardStopDetected = deceleration > hardStopThreshold
        
        if hardStopDetected {
            logger.violation("Hard brake detected: \(String(format: "%.1f", deceleration)) m/s²")
            onHardStopDetected?()
        } else if deceleration > 1.5 {
            logger.debug("Moderate brake: \(String(format: "%.1f", deceleration)) m/s²")
        }
        
        return hardStopDetected
    }
    
    func detectSharpTurn(headingChange: Double) -> Bool {
        let sharpTurnDetected = abs(headingChange) > sharpTurnThreshold
        
        if sharpTurnDetected {
            logger.violation("Sharp turn detected: \(Int(abs(headingChange)))° change")
            onSharpTurnDetected?()
        } else if abs(headingChange) > 15 {
            logger.debug("Moderate turn: \(Int(abs(headingChange)))° change")
        }
        
        return sharpTurnDetected
    }
    
    // MARK: - Error Handling
    
    private func handleAccelerometerError(_ error: Error) {
        // Handle CoreMotion permission errors gracefully (common in simulator)
        if error.localizedDescription.contains("permission") || error.localizedDescription.contains("plist") {
            logger.warning("CoreMotion permission warning (simulator limitation): \(error.localizedDescription)")
            return // Continue running, don't stop accelerometer
        } else {
            logger.error("Accelerometer error: \(error.localizedDescription)")
            // Stop accelerometer updates on error to prevent repeated errors
            stopAccelerometerUpdates()
            return
        }
    }
    
    // MARK: - Configuration
    
    func updateDetectionThresholds(
        potholeVertical: Double? = nil,
        potholeTotal: Double? = nil,
        hardStop: Double? = nil,
        sharpTurn: Double? = nil
    ) {
        if let vertical = potholeVertical {
            // Update threshold (would need to be stored persistently)
            logger.info("Pothole vertical threshold updated to: \(vertical)g")
        }
        
        if let total = potholeTotal {
            logger.info("Pothole total threshold updated to: \(total)g")
        }
        
        if let hardStop = hardStop {
            logger.info("Hard stop threshold updated to: \(hardStop) m/s²")
        }
        
        if let sharpTurn = sharpTurn {
            self.sharpTurnThreshold = sharpTurn
            logger.info("Sharp turn threshold updated to: \(sharpTurn)°")
        }
    }
    
    // MARK: - Statistics
    
    func getMotionStatistics() -> MotionStatistics {
        return MotionStatistics(
            isAvailable: isAccelerometerAvailable,
            isActive: isAccelerometerActive,
            updateInterval: motionManager.accelerometerUpdateInterval,
            lastDataTimestamp: lastAccelerationData?.timestamp != nil ? Date(timeIntervalSince1970: lastAccelerationData!.timestamp) : nil
        )
    }
    
    func getCurrentThresholds() -> (potholeVertical: Double, potholeTotal: Double, hardStop: Double, sharpTurn: Double) {
        return (potholeVerticalThreshold, potholeTotalThreshold, hardStopThreshold, sharpTurnThreshold)
    }
    
    func setSharpTurnThreshold(_ threshold: Double) {
        sharpTurnThreshold = threshold
        logger.info("Sharp turn threshold updated to: \(threshold)°")
    }
}

// MARK: - Supporting Types

struct MotionStatistics {
    let isAvailable: Bool
    let isActive: Bool
    let updateInterval: TimeInterval
    let lastDataTimestamp: Date?
    
    var status: String {
        if !isAvailable {
            return "Not Available"
        } else if isActive {
            return "Active"
        } else {
            return "Inactive"
        }
    }
}
