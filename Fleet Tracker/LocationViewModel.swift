//
//  LocationViewModel.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import Combine
import CoreMotion
import MapKit

class LocationViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    let customMotionManager = MotionManager() // Public access to custom MotionManager
    private let db = Firestore.firestore()
    private let speedLimitService = UnifiedSpeedLimitService.shared
    let deviceId: String
    
    @Published var currentCoordinate: CLLocationCoordinate2D? = nil
    @Published var trackingIsActive: Bool = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String? = nil
    @Published var locationHistory: [LocationRecord] = []
    @Published var isBackgroundTrackingEnabled: Bool = false
    
    // Fleet tracking properties
    @Published var currentTrip: Trip?
    @Published var trips: [Trip] = []
    @Published var drivingSummary: DrivingBehaviorSummary = DrivingBehaviorSummary()
    @Published var currentSpeed: Double = 0.0 // mph
    @Published var speedLimit: Double? = nil
    @Published var speedViolation: Bool = false
    @Published var recentViolations: [LocationRecord] = []
    @Published var isFetchingSpeedLimit: Bool = false
    
    // Speed violation state tracking
    private var isCurrentlySpeeding: Bool = false
    private var lastSpeedViolationTime: Date?
    
    // Navigation properties
    @Published var destination: String = ""
    @Published var route: MKRoute?
    @Published var isNavigating: Bool = false
    @Published var navigationInstructions: [String] = []
    @Published var currentStepIndex: Int = 0
    @Published var routeDistance: Double = 0.0 // in miles
    @Published var routeDuration: TimeInterval = 0.0 // in seconds
    @Published var addressSuggestions: [MKMapItem] = []
    @Published var isSearchingAddresses: Bool = false
    
    // Route preferences
    @Published var routePreferences = RoutePreferences()
    @Published var availableRoutes: [MKRoute] = []
    @Published var selectedRouteIndex: Int = 0
    
    // Private tracking variables
    private var previousLocation: CLLocation?
    private var previousHeading: Double?
    private var lastAccelerationData: CMAccelerometerData?
    
    // Automatic trip detection
    private var isAutoTripDetectionEnabled: Bool = true
    private var tripStartSpeedThreshold: Double = 15.0 // mph
    private var tripStopSpeedThreshold: Double = 15.0 // mph
    private var tripStopDurationThreshold: TimeInterval = 180.0 // 3 minutes
    private var lowSpeedStartTime: Date?
    private var lowSpeedTimer: Timer?
    private var isCurrentlyDriving: Bool = false
    
    override init() {
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        super.init()
        setupLocationManager()
        
        // Download Detroit speed limit data in background - don't block UI
        Task.detached(priority: .background) {
            await SpeedLimitDataManager.shared.setupDetroitData()
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters // More efficient than Best
        locationManager.distanceFilter = 20 // Update every 20 meters - more efficient
        authorizationStatus = locationManager.authorizationStatus
        
        // Disable unnecessary location services that cause XPC issues
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = false // Disable initially
        
        // Setup motion manager for accelerometer data
        setupMotionManager()
        
        // Request initial authorization
        requestLocationPermission()
    }
    
    private func setupMotionManager() {
        // Only set up motion manager if accelerometer is available
        // Don't start updates here - wait until tracking starts
        guard motionManager.isAccelerometerAvailable else {
            logger.warning("Accelerometer not available on this device")
            return
        }
        motionManager.accelerometerUpdateInterval = 0.2 // Reduced frequency to 5 Hz to reduce XPC calls
    }
    
    private func requestMotionPermission() {
        // CoreMotion doesn't require explicit permission on iOS
        // But we should check availability before using
        guard motionManager.isAccelerometerAvailable else {
            logger.warning("Accelerometer not available on this device")
            return
        }
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable location access in Settings."
        case .authorizedWhenInUse:
            // Already have when-in-use permission
            break
        case .authorizedAlways:
            // Already have always permission
            break
        @unknown default:
            break
        }
    }
    
    func requestAlwaysPermission() {
        if authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func startTracking() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = "Location services are disabled."
            return
        }
        
        switch authorizationStatus {
        case .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            trackingIsActive = true
            locationError = nil
            
            // Start new trip if none is active
            if currentTrip == nil {
                startNewTrip()
            }
            
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
            
            // Enable background location updates if properly configured
            DispatchQueue.main.async {
                do {
                    self.locationManager.allowsBackgroundLocationUpdates = true
                    self.locationManager.pausesLocationUpdatesAutomatically = false
                    self.isBackgroundTrackingEnabled = true
                    logger.info("Background location updates enabled")
                } catch {
                    logger.error("Failed to enable background location updates: \(error.localizedDescription)")
                    logger.error("Make sure Background Modes capability is enabled in Xcode project settings")
                    self.isBackgroundTrackingEnabled = false
                }
            }
            
            trackingIsActive = true
            locationError = nil
            
            // Start new trip if none is active
            if currentTrip == nil {
                startNewTrip()
            }
            
        case .denied, .restricted:
            locationError = "Location access denied. Please enable location access in Settings."
        case .notDetermined:
            requestLocationPermission()
        @unknown default:
            break
        }
        
        // Start accelerometer for pothole detection (if available and safe)
        startAccelerometerUpdates()
    }
    
    private func startAccelerometerUpdates() {
        // Check if accelerometer is available and not already active
        guard motionManager.isAccelerometerAvailable && !motionManager.isAccelerometerActive else {
            return
        }
        
        // Start accelerometer updates with error handling
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            if let error = error {
                // Handle CoreMotion permission errors gracefully (common in simulator)
                if error.localizedDescription.contains("permission") || error.localizedDescription.contains("plist") {
                    logger.warning("CoreMotion permission warning (simulator limitation): \(error.localizedDescription)")
                    return // Continue running, don't stop accelerometer
                } else {
                    logger.error("Accelerometer error: \(error.localizedDescription)")
                    // Stop accelerometer updates on error to prevent repeated errors
                    self?.motionManager.stopAccelerometerUpdates()
                    return
                }
            }
            
            // Store the latest accelerometer data for pothole detection
            if let data = data {
                self?.lastAccelerationData = data
                
                // Log accelerometer data occasionally for testing
                if Int.random(in: 1...20) == 1 { // Log only 5% of updates
                    let x = data.acceleration.x
                    let y = data.acceleration.y
                    let z = data.acceleration.z
                    let total = sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2))
                    logger.debug("Accelerometer: X:\(String(format: "%.2f", x)) Y:\(String(format: "%.2f", y)) Z:\(String(format: "%.2f", z)) Total:\(String(format: "%.2f", total))g")
                }
                
                // Check for potholes in real-time (not just during location updates)
                self?.checkForPotholeInRealTime(data)
            }
        }
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        
        // Disable background location updates
        if isBackgroundTrackingEnabled {
            locationManager.allowsBackgroundLocationUpdates = false
        }
        
        trackingIsActive = false
        isBackgroundTrackingEnabled = false
        
        // Stop accelerometer updates
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
    }
    
    func enableBackgroundLocationUpdates() {
        guard authorizationStatus == .authorizedAlways else {
            logger.warning("Cannot enable background location updates without 'Always' permission")
            return
        }
        
        DispatchQueue.main.async {
            do {
                self.locationManager.allowsBackgroundLocationUpdates = true
                self.locationManager.pausesLocationUpdatesAutomatically = false
                self.isBackgroundTrackingEnabled = true
                logger.info("Background location updates enabled")
            } catch {
                logger.error("Failed to enable background location updates: \(error.localizedDescription)")
                logger.error("Make sure Background Modes capability is enabled in Xcode project settings")
                self.isBackgroundTrackingEnabled = false
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Update published coordinate (UI will update map) - do this first for responsiveness
        DispatchQueue.main.async {
            self.currentCoordinate = newLocation.coordinate
            
            // Check if we need to start a trip now that we have location
            if self.shouldStartTripOnNextLocation {
                self.shouldStartTripOnNextLocation = false
                self.createTripWithCoordinate(newLocation.coordinate)
            }
        }
        
        // Update navigation progress if navigating
        if isNavigating {
            updateNavigationProgress()
        }
        
        // Process location in background to avoid blocking UI
        Task.detached(priority: .userInitiated) {
            await self.processLocationUpdate(newLocation)
        }
    }
    
    @MainActor
    private func processLocationUpdate(_ newLocation: CLLocation) async {
        // Analyze driving behavior
        let analyzedRecord = analyzeDrivingBehavior(newLocation: newLocation)
        
        // Update current speed
        self.currentSpeed = analyzedRecord.speedInMph ?? 0.0
        self.speedViolation = analyzedRecord.speedViolation
        
        // Automatic trip detection based on speed
        if isAutoTripDetectionEnabled {
            await handleAutomaticTripDetection(speed: self.currentSpeed, location: newLocation)
        }
        
        // Fetch speed limit for current location (throttled)
        await fetchSpeedLimit(for: newLocation.coordinate)
        
        // Add to history
        self.locationHistory.append(analyzedRecord)
        // Keep only last 200 locations to prevent memory issues
        if self.locationHistory.count > 200 {
            self.locationHistory.removeFirst()
        }
        
        // Log location history
        logger.locationUpdate("Added to history - Total: \(self.locationHistory.count), Speed: \(analyzedRecord.speedInMph?.rounded() ?? 0) mph, Violations: \(analyzedRecord.speedViolation ? "SPEED" : "")\(analyzedRecord.hardStop ? "BRAKE" : "")\(analyzedRecord.sharpTurn ? "TURN" : "")\(analyzedRecord.potholeDetected ? "POTHOLE" : "")")
        
        // Add violations to recent violations
        if analyzedRecord.speedViolation || analyzedRecord.hardStop || analyzedRecord.sharpTurn || analyzedRecord.potholeDetected {
            self.recentViolations.append(analyzedRecord)
            // Keep only last 10 violations
            if self.recentViolations.count > 10 {
                self.recentViolations.removeFirst()
            }
            
            // Log violations added to recent violations
            var violationTypes: [String] = []
            if analyzedRecord.speedViolation { violationTypes.append("SPEED") }
            if analyzedRecord.hardStop { violationTypes.append("BRAKE") }
            if analyzedRecord.sharpTurn { violationTypes.append("TURN") }
            if analyzedRecord.potholeDetected { violationTypes.append("POTHOLE") }
            logger.violation("Added to recent violations: \(violationTypes.joined(separator: ", ")) - Total recent: \(self.recentViolations.count)")
        }
        
        // Update current trip
        updateCurrentTrip(with: analyzedRecord)
        
        // Save to Firebase in batches to improve performance
        saveLocationToFirebaseBatch(analyzedRecord)
        
        // Update previous location for next analysis
        previousLocation = newLocation
        
        // Log current speed and course for troubleshooting (only occasionally)
        if Int.random(in: 1...10) == 1 { // Log only 10% of updates
            if let speed = analyzedRecord.speedInMph {
                logger.locationUpdate("Speed: \(Int(speed)) mph, Course: \(newLocation.course >= 0 ? String(format: "%.1f", newLocation.course) : "N/A")°")
            }
        }
    }
    
    private func analyzeDrivingBehavior(newLocation: CLLocation) -> LocationRecord {
        var record = LocationRecord(from: newLocation, deviceId: deviceId, speedLimit: speedLimit, tripId: currentTrip?.id)
        
        // Set speed violation from our smart state tracking
        record.speedViolation = speedViolation
        
        // Detect speed limit using Apple MapKit
        if let speedLimit = detectSpeedLimit(at: newLocation.coordinate) {
            record.speedLimit = speedLimit
            DispatchQueue.main.async {
                self.speedLimit = speedLimit
            }
        }
        
        // Analyze acceleration/deceleration for braking detection
        if let previous = previousLocation {
            let timeInterval = newLocation.timestamp.timeIntervalSince(previous.timestamp)
            if timeInterval > 0 {
                let speedChange = (newLocation.speed - previous.speed) / timeInterval
                record.acceleration = speedChange > 0 ? speedChange : nil
                record.deceleration = speedChange < 0 ? abs(speedChange) : nil
                
                // Detect hard stops/braking (deceleration > 2.5 m/s²)
                // Reduced threshold for better detection
                if let deceleration = record.deceleration, deceleration > 2.5 {
                    record.hardStop = true
                    logger.violation("Hard brake detected: \(String(format: "%.1f", deceleration)) m/s²")
                }
                
                // Detect moderate braking (deceleration > 1.5 m/s²)
                if let deceleration = record.deceleration, deceleration > 1.5 {
                    logger.debug("Moderate brake: \(String(format: "%.1f", deceleration)) m/s²")
                }
            }
        }
        
        // Analyze heading changes for sharp turns
        if newLocation.course >= 0 {
            if let previousHeading = previousHeading {
                let currentHeading = newLocation.course
                let headingChange = abs(currentHeading - previousHeading)
                // Normalize heading change (account for 360° wraparound)
                let normalizedChange = min(headingChange, 360 - headingChange)
                
                // Detect sharp turns (heading change > 40°)
                // Adjusted threshold based on research: normal turns are 15-30°, sharp turns are 45°+
                if normalizedChange > 40 {
                    record.sharpTurn = true
                    logger.violation("Sharp turn detected: \(Int(normalizedChange))° change")
                }
                
                // Detect moderate turns (heading change > 15°)
                if normalizedChange > 15 {
                    logger.debug("Moderate turn: \(Int(normalizedChange))° change")
                }
            }
            // Update previous heading for next analysis
            previousHeading = newLocation.course
        }
        
        // Detect potholes using accelerometer data
        if motionManager.isAccelerometerActive {
            record.potholeDetected = detectPothole()
            if record.potholeDetected {
                logger.violation("POTHOLE DETECTED in location update!")
            }
        } else {
            logger.warning("Accelerometer not active during location update")
        }
        
        // Calculate driver behavior score
        record.driverBehaviorScore = calculateDriverScore(for: record)
        
        return record
    }
    
    
    private func detectSpeedLimit(at coordinate: CLLocationCoordinate2D) -> Double? {
        // Use unified speed limit service
        Task {
            if let result = await speedLimitService.getSpeedLimit(for: coordinate) {
                await MainActor.run {
                    self.speedLimit = result.speedLimit
                }
            }
        }
        return nil // Will be updated asynchronously
    }
    
    private func detectPothole() -> Bool {
        // Enhanced pothole detection using accelerometer
        // Check if accelerometer is available and active
        guard motionManager.isAccelerometerAvailable && motionManager.isAccelerometerActive else {
            logger.warning("Accelerometer not available or inactive")
            return false
        }
        
        // Use stored accelerometer data instead of accessing directly
        guard let accelerometerData = lastAccelerationData else { 
            logger.warning("No accelerometer data available")
            return false 
        }
        
        // Skip timestamp check - accelerometer data is updated continuously
        // The timestamp from CoreMotion appears to be unreliable
        
        let x = accelerometerData.acceleration.x
        let y = accelerometerData.acceleration.y
        let z = accelerometerData.acceleration.z
        
        // Calculate total acceleration magnitude
        let totalAcceleration = sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2))
        
        // Focus on vertical acceleration (Z-axis) for pothole detection
        let verticalAcceleration = abs(z)
        
        // Log accelerometer values for pothole detection
        logger.debug("Pothole Check: X:\(String(format: "%.2f", x)) Y:\(String(format: "%.2f", y)) Z:\(String(format: "%.2f", z)) Total:\(String(format: "%.2f", totalAcceleration))g")
        
        // Detect sudden vertical acceleration changes (potholes cause upward jolts)
        // Lowered threshold for better detection sensitivity
        let potholeDetected = verticalAcceleration > 1.8 || totalAcceleration > 2.0
        
        if potholeDetected {
            logger.violation("POTHOLE DETECTED! Vertical: \(String(format: "%.2f", verticalAcceleration))g, Total: \(String(format: "%.2f", totalAcceleration))g")
        } else {
            logger.debug("No pothole detected - Vertical: \(String(format: "%.2f", verticalAcceleration))g (threshold: 1.8g), Total: \(String(format: "%.2f", totalAcceleration))g (threshold: 2.0g)")
        }
        
        return potholeDetected
    }
    
    private func checkForPotholeInRealTime(_ accelerometerData: CMAccelerometerData) {
        let x = accelerometerData.acceleration.x
        let y = accelerometerData.acceleration.y
        let z = accelerometerData.acceleration.z
        
        // Calculate total acceleration magnitude
        let totalAcceleration = sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2))
        
        // Focus on vertical acceleration (Z-axis) for pothole detection
        let verticalAcceleration = abs(z)
        
        // Detect sudden vertical acceleration changes (potholes cause upward jolts)
        let potholeDetected = verticalAcceleration > 1.8 || totalAcceleration > 2.0
        
        if potholeDetected {
            logger.violation("POTHOLE DETECTED IN REAL-TIME! Vertical: \(String(format: "%.2f", verticalAcceleration))g, Total: \(String(format: "%.2f", totalAcceleration))g")
            
            // Add to recent violations for tracking
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                var violation = LocationRecord(
                    latitude: self.currentCoordinate?.latitude ?? 0,
                    longitude: self.currentCoordinate?.longitude ?? 0,
                    timestamp: Date(),
                    deviceId: self.deviceId
                )
                violation.potholeDetected = true
                self.recentViolations.append(violation)
                
                // Keep only last 10 violations
                if self.recentViolations.count > 10 {
                    self.recentViolations.removeFirst()
                }
                
                // Update current trip if active
                if var trip = self.currentTrip {
                    trip.potholesDetected += 1
                    self.currentTrip = trip
                    logger.debug("Pothole added to current trip - Total: \(trip.potholesDetected)")
                }
            }
            DispatchQueue.main.async(execute: workItem)
        }
    }
    
    
    private func calculateDriverScore(for record: LocationRecord) -> Double {
        var score = 100.0 // Start with perfect score
        
        // Deduct points for violations
        if record.speedViolation {
            score -= 5.0 // Speed violations are serious
        }
        if record.hardStop {
            score -= 3.0 // Hard stops indicate aggressive driving
        }
        if record.sharpTurn {
            score -= 2.0 // Sharp turns indicate poor planning
        }
        if record.potholeDetected {
            score -= 1.0 // Potholes are often unavoidable
        }
        
        // Ensure score doesn't go below 0
        return max(0.0, score)
    }
    
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse:
                self.locationError = nil
                self.startTracking()
            case .authorizedAlways:
                self.locationError = nil
                self.isBackgroundTrackingEnabled = true
                self.startTracking()
            case .denied, .restricted:
                self.locationError = "Location access denied. Please enable location access in Settings."
                self.stopTracking()
            case .notDetermined:
                self.locationError = nil
            @unknown default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorHandler.handle(error, context: "LocationManager.didFailWithError", userFacing: true)
        
        DispatchQueue.main.async {
            if let fleetError = error as? FleetTrackerError {
                self.locationError = fleetError.localizedDescription
            } else {
                self.locationError = "Location error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Firebase Integration
    
    private var locationBatch: [LocationRecord] = []
    private var lastBatchSave: Date = Date()
    
    private func saveLocationToFirebaseBatch(_ record: LocationRecord) {
        locationBatch.append(record)
        
        // Log Firebase batch
        logger.firebase("LOCATION added to batch - Batch size: \(locationBatch.count), Speed: \(record.speedInMph?.rounded() ?? 0) mph, Violations: \(record.speedViolation ? "SPEED" : "")\(record.hardStop ? "BRAKE" : "")\(record.sharpTurn ? "TURN" : "")\(record.potholeDetected ? "POTHOLE" : "")")
        
        // Save batch every 20 records or every 60 seconds - more efficient
        let shouldSaveBatch = locationBatch.count >= 20 || 
                             Date().timeIntervalSince(lastBatchSave) > 60
        
        if shouldSaveBatch {
            logger.firebase("TRIGGERING batch save - Batch size: \(locationBatch.count)")
            Task.detached(priority: .background) {
                await self.saveBatchToFirebase()
            }
        }
    }
    
    private func saveBatchToFirebase() async {
        guard !locationBatch.isEmpty else { 
            logger.warning("Firebase batch save called but batch is empty")
            return 
        }
        
        let batch = db.batch()
        let recordsToSave = locationBatch
        locationBatch.removeAll() // Clear immediately to prevent memory buildup
        
        logger.firebase("STARTING batch save - \(recordsToSave.count) records")
        
        var violationCount = 0
        for record in recordsToSave {
            do {
                let data = try Firestore.Encoder().encode(record)
                let docRef = db.collection("locations").document()
                batch.setData(data, forDocument: docRef)
                
                // Count violations in this batch
                if record.speedViolation || record.hardStop || record.sharpTurn || record.potholeDetected {
                    violationCount += 1
                }
            } catch {
                errorHandler.handle(error, context: "Firebase data encoding", userFacing: false)
            }
        }
        
        do {
            try await batch.commit()
            logger.firebase("Batch saved successfully - \(recordsToSave.count) records, \(violationCount) violations")
        } catch {
            await errorHandler.handleAsync(error, context: "Firebase batch commit", userFacing: false)
        }
        
        lastBatchSave = Date()
    }
    
    private func saveLocationToFirebase(_ record: LocationRecord) {
        do {
            let data = try Firestore.Encoder().encode(record)
            db.collection("locations").addDocument(data: data) { error in
                if let error = error {
                    errorHandler.handle(error, context: "Firebase single document save", userFacing: false)
                } else {
                    logger.firebase("Location saved to Firebase successfully")
                }
            }
        } catch {
            errorHandler.handle(error, context: "Firebase data encoding", userFacing: false)
        }
    }
    
    func loadLocationHistory() {
        logger.info("Loading location history from Firebase...")
        
        // Load both trips and individual location records
        loadTrips()
        
        db.collection("locations")
            .whereField("deviceId", isEqualTo: deviceId)
            .limit(to: 500) // Reduced limit for better performance
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    errorHandler.handle(error, context: "Firebase load location history", userFacing: true)
                    
                    // If it's an index error, provide helpful message
                    if let nsError = error as NSError?, nsError.domain == "FIRFirestoreErrorDomain" {
                        logger.error("Firestore index required. Consider creating the index or using a simpler query.")
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { 
                    logger.warning("No documents found in Firebase")
                    return 
                }
                
                DispatchQueue.main.async {
                    let records = documents.compactMap { document in
                        try? Firestore.Decoder().decode(LocationRecord.self, from: document.data())
                    }
                    
                    // Count violations in loaded records
                    let violationCount = records.filter { $0.speedViolation || $0.hardStop || $0.sharpTurn || $0.potholeDetected }.count
                    
                    // Sort by timestamp in descending order (most recent first) on the client side
                    self?.locationHistory = records.sorted { $0.timestamp > $1.timestamp }
                    logger.info("Loaded \(records.count) location records from Firebase (\(violationCount) violations)")
                    
                    // Log sample of loaded data
                    if let firstRecord = self?.locationHistory.first {
                        logger.debug("Sample record: Speed: \(firstRecord.speedInMph?.rounded() ?? 0) mph, Violations: \(firstRecord.speedViolation ? "SPEED" : "")\(firstRecord.hardStop ? "BRAKE" : "")\(firstRecord.sharpTurn ? "TURN" : "")\(firstRecord.potholeDetected ? "POTHOLE" : "")")
                    }
                }
            }
    }
    
    // MARK: - Utility Methods
    
    func clearLocationHistory() {
        locationHistory.removeAll()
        recentViolations.removeAll()
    }
    
    // Manual trigger for testing Firebase saves
    func forceFirebaseSave() {
        logger.info("MANUAL Firebase save triggered")
        Task.detached(priority: .background) {
            await self.saveBatchToFirebase()
        }
    }
    
    func getCurrentLocationString() -> String {
        guard let coordinate = currentCoordinate else {
            return "Location not available"
        }
        return String(format: "Lat: %.6f, Lon: %.6f", coordinate.latitude, coordinate.longitude)
    }
    
    func refreshSpeedLimit() {
        guard let coordinate = currentCoordinate else { return }
        
        DispatchQueue.main.async {
            self.isFetchingSpeedLimit = true
        }
        
        // Use unified speed limit service
        Task {
            if let result = await speedLimitService.getSpeedLimit(for: coordinate) {
                await MainActor.run {
                    self.speedLimit = result.speedLimit
                    self.isFetchingSpeedLimit = false
                }
            } else {
                await MainActor.run {
                    self.isFetchingSpeedLimit = false
                }
            }
        }
    }
    
    // MARK: - Trip Management
    
    func startNewTrip() {
        // Try to get current coordinate, or wait for location if not available
        if let coordinate = currentCoordinate {
            createTripWithCoordinate(coordinate)
        } else {
            print("⚠️ No current coordinate - waiting for location update")
            // Set a flag to create trip when location becomes available
            shouldStartTripOnNextLocation = true
        }
    }
    
    private var shouldStartTripOnNextLocation = false
    
    private func createTripWithCoordinate(_ coordinate: CLLocationCoordinate2D) {
        // Reset speed violation state for new trip
        isCurrentlySpeeding = false
        speedViolation = false
        lastSpeedViolationTime = nil
        
        var newTrip = Trip(
            deviceId: deviceId,
            startTime: Date(),
            startLocation: coordinate,
            destination: destination.isEmpty ? nil : destination
        )
        newTrip.driverScore = 100.0 // Start with perfect score
        
        logger.info("Starting new trip: \(newTrip.id)")
        logger.locationUpdate("Start location: \(coordinate.latitude), \(coordinate.longitude)")
        logger.info("Destination: \(destination.isEmpty ? "None" : destination)")
        
        DispatchQueue.main.async {
            self.currentTrip = newTrip
            logger.info("New trip created and set as current trip")
        }
    }
    
    func endCurrentTrip() {
        guard var trip = currentTrip else { 
            logger.warning("No current trip to end")
            return 
        }
        
        logger.info("Ending trip: \(trip.id)")
        trip.endTime = Date()
        if let coordinate = currentCoordinate {
            trip.endLocationLatitude = coordinate.latitude
            trip.endLocationLongitude = coordinate.longitude
        }
        
        // Calculate final statistics
        if let duration = trip.duration {
            trip.averageSpeed = trip.totalDistance / (duration / 3600) // Convert to mph
        }
        
        logger.info("Final trip stats: Distance: \(String(format: "%.2f", trip.totalDistance/1609.34)) miles, Duration: \(String(format: "%.1f", trip.duration ?? 0))s")
        logger.info("Final violations: Speed: \(trip.speedViolations), Hard stops: \(trip.hardStops), Sharp turns: \(trip.sharpTurns), Potholes: \(trip.potholesDetected)")
        
        DispatchQueue.main.async {
            self.trips.append(trip)
            self.currentTrip = nil
            self.updateDrivingSummary()
            logger.info("Trip added to local trips array. Total trips: \(self.trips.count)")
        }
        
        // Save trip to Firebase
        saveTripToFirebase(trip)
    }
    
    private func updateDrivingSummary() {
        var summary = DrivingBehaviorSummary()
        
        for trip in trips {
            summary.totalTrips += 1
            summary.totalDistance += trip.totalDistance / 1609.34 // Convert meters to miles
            summary.totalTime += trip.duration ?? 0
            summary.speedViolations += trip.speedViolations
            summary.hardStops += trip.hardStops
            summary.sharpTurns += trip.sharpTurns
            summary.potholesDetected += trip.potholesDetected
            summary.maxSpeed = max(summary.maxSpeed, trip.maxSpeed)
        }
        
        if summary.totalTrips > 0 {
            summary.averageSpeed = summary.totalDistance / (summary.totalTime / 3600)
            
            // Calculate average driver score across all trips
            let totalScore = trips.map { $0.driverScore }.reduce(0, +)
            summary.overallDriverScore = totalScore / Double(trips.count)
            
            logger.info("📊 Updated driving summary - Average driver score: \(String(format: "%.1f", summary.overallDriverScore)) from \(trips.count) trips")
        } else {
            // No trips yet - set default values
            summary.overallDriverScore = 100.0
            logger.info("📊 No trips available - using default driver score: 100.0")
        }
        
        // Generate improvement suggestions
        summary.improvementSuggestions = generateImprovementSuggestions(from: summary)
        
        DispatchQueue.main.async {
            self.drivingSummary = summary
        }
    }
    
    private func updateCurrentTrip(with record: LocationRecord) {
        guard var trip = currentTrip else { return }
        
        // Update violation counts
        if record.speedViolation {
            trip.speedViolations += 1
            logger.violation("Speed violation added to trip - Total: \(trip.speedViolations)")
        }
        if record.hardStop {
            trip.hardStops += 1
            logger.violation("Hard stop added to trip - Total: \(trip.hardStops)")
        }
        if record.sharpTurn {
            trip.sharpTurns += 1
            logger.violation("Sharp turn added to trip - Total: \(trip.sharpTurns)")
        }
        if record.potholeDetected {
            trip.potholesDetected += 1
            logger.violation("Pothole added to trip - Total: \(trip.potholesDetected)")
        }
        
        // Update distance
        if let previous = previousLocation {
            let currentLocation = CLLocation(latitude: record.latitude, longitude: record.longitude)
            let distance = currentLocation.distance(from: previous)
            trip.totalDistance += distance
        }
        
        // Update max speed
        if let speedMph = record.speedInMph, speedMph > trip.maxSpeed {
            trip.maxSpeed = speedMph
        }
        
        // Calculate and update driver score based on violations
        trip.driverScore = calculateTripDriverScore(for: trip)
        
        // Update the current trip
        DispatchQueue.main.async {
            self.currentTrip = trip
        }
        
        // Log updated trip stats
        logger.info("Trip updated - Violations: Speed:\(trip.speedViolations) Hard:\(trip.hardStops) Turn:\(trip.sharpTurns) Pothole:\(trip.potholesDetected) Score:\(Int(trip.driverScore))")
    }
    
    private func calculateTripDriverScore(for trip: Trip) -> Double {
        var score = 100.0 // Start with perfect score
        
        // Deduct points for violations
        score -= Double(trip.speedViolations) * 5.0 // Speed violations are serious
        score -= Double(trip.hardStops) * 3.0 // Hard stops indicate aggressive driving
        score -= Double(trip.sharpTurns) * 2.0 // Sharp turns indicate poor planning
        score -= Double(trip.potholesDetected) * 1.0 // Potholes are often unavoidable
        
        // Ensure score doesn't go below 0
        return max(0.0, score)
    }
    
    private func generateImprovementSuggestions(from summary: DrivingBehaviorSummary) -> [String] {
        var suggestions: [String] = []
        
        if summary.speedViolations > summary.totalTrips {
            suggestions.append("Reduce speeding - consider using cruise control")
        }
        
        if summary.hardStops > Int(Double(summary.totalTrips) * 0.5) {
            suggestions.append("Improve braking technique - brake earlier and more gradually")
        }
        
        if summary.sharpTurns > Int(Double(summary.totalTrips) * 0.3) {
            suggestions.append("Take turns more smoothly - reduce speed before turning")
        }
        
        if summary.potholesDetected > 0 {
            suggestions.append("Avoid potholes when possible - they can damage your vehicle")
        }
        
        if summary.overallDriverScore < 80 {
            suggestions.append("Focus on overall driving smoothness and safety")
        }
        
        return suggestions
    }
    
    // MARK: - Automatic Trip Detection
    
    @MainActor
    private func handleAutomaticTripDetection(speed: Double, location: CLLocation) async {
        // Only process if we have a valid speed reading
        guard speed > 0 else { return }
        
        if speed >= tripStartSpeedThreshold && !isCurrentlyDriving {
            // Start driving - begin a new trip
            await startAutomaticTrip(at: location.coordinate)
        } else if speed < tripStopSpeedThreshold && isCurrentlyDriving {
            // Low speed detected - start timer for trip end
            await handleLowSpeedDetection()
        } else if speed >= tripStopSpeedThreshold && isCurrentlyDriving {
            // Speed picked up again - cancel trip end timer
            await cancelTripEndTimer()
        }
    }
    
    @MainActor
    private func startAutomaticTrip(at coordinate: CLLocationCoordinate2D) async {
        guard !isCurrentlyDriving else { return }
        
        logger.info("🚗 Automatic trip start detected at \(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude))")
        
        // Cancel any existing trip end timer
        await cancelTripEndTimer()
        
        // Create new trip with perfect driver score
        var newTrip = Trip(
            deviceId: deviceId,
            startTime: Date(),
            startLocation: coordinate,
            destination: destination.isEmpty ? nil : destination
        )
        newTrip.driverScore = 100.0 // Start with perfect score
        
        currentTrip = newTrip
        isCurrentlyDriving = true
        
        logger.info("✅ Automatic trip started: \(newTrip.id)")
    }
    
    @MainActor
    private func handleLowSpeedDetection() async {
        guard isCurrentlyDriving else { return }
        
        if lowSpeedStartTime == nil {
            // First time detecting low speed
            lowSpeedStartTime = Date()
            logger.info("🐌 Low speed detected - starting 3-minute timer")
            
            // Start timer to end trip after 3 minutes of low speed
            lowSpeedTimer = Timer.scheduledTimer(withTimeInterval: tripStopDurationThreshold, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    await self?.endAutomaticTrip()
                }
            }
        }
        // If lowSpeedStartTime already exists, timer is already running
    }
    
    @MainActor
    private func cancelTripEndTimer() async {
        if lowSpeedTimer != nil {
            lowSpeedTimer?.invalidate()
            lowSpeedTimer = nil
            lowSpeedStartTime = nil
            logger.info("🚗 Speed picked up - trip end timer cancelled")
        }
    }
    
    @MainActor
    private func endAutomaticTrip() async {
        guard var trip = currentTrip, isCurrentlyDriving else { return }
        
        logger.info("🛑 Automatic trip end detected after 3 minutes of low speed")
        
        // End the trip
        trip.endTime = Date()
        if let coordinate = currentCoordinate {
            trip.endLocationLatitude = coordinate.latitude
            trip.endLocationLongitude = coordinate.longitude
        }
        
        // Calculate final statistics
        if let duration = trip.duration {
            trip.averageSpeed = trip.totalDistance / (duration / 3600) // Convert to mph
        }
        
        logger.info("Final automatic trip stats: Distance: \(String(format: "%.2f", trip.totalDistance/1609.34)) miles, Duration: \(String(format: "%.1f", trip.duration ?? 0))s")
        logger.info("Final violations: Speed: \(trip.speedViolations), Hard stops: \(trip.hardStops), Sharp turns: \(trip.sharpTurns), Potholes: \(trip.potholesDetected)")
        
        // Add to trips array and update summary
        trips.append(trip)
        currentTrip = nil
        isCurrentlyDriving = false
        updateDrivingSummary()
        
        // Clean up timer state
        lowSpeedTimer = nil
        lowSpeedStartTime = nil
        
        logger.info("✅ Automatic trip ended and saved. Total trips: \(trips.count)")
        
        // Save trip to Firebase
        saveTripToFirebase(trip)
    }
    
    // MARK: - Automatic Trip Detection Controls
    
    func enableAutomaticTripDetection() {
        isAutoTripDetectionEnabled = true
        logger.info("✅ Automatic trip detection enabled")
    }
    
    func disableAutomaticTripDetection() {
        isAutoTripDetectionEnabled = false
        logger.info("❌ Automatic trip detection disabled")
    }
    
    func setTripSpeedThresholds(start: Double, stop: Double) {
        tripStartSpeedThreshold = start
        tripStopSpeedThreshold = stop
        logger.info("⚙️ Trip speed thresholds updated: Start: \(start) mph, Stop: \(stop) mph")
    }
    
    func setTripStopDuration(_ duration: TimeInterval) {
        tripStopDurationThreshold = duration
        logger.info("⏱️ Trip stop duration threshold updated: \(duration) seconds")
    }
    
    func getAutomaticTripStatus() -> (isEnabled: Bool, isDriving: Bool, startThreshold: Double, stopThreshold: Double, stopDuration: TimeInterval) {
        return (isAutoTripDetectionEnabled, isCurrentlyDriving, tripStartSpeedThreshold, tripStopSpeedThreshold, tripStopDurationThreshold)
    }
    
    // MARK: - Driver Score Management
    
    func getCurrentDriverScore() -> Double {
        return currentTrip?.driverScore ?? 100.0
    }
    
    func getDriverScoreImpact() -> (speedViolations: Int, hardStops: Int, sharpTurns: Int, potholes: Int, totalDeduction: Double) {
        guard let trip = currentTrip else {
            return (0, 0, 0, 0, 0.0)
        }
        
        let speedDeduction = Double(trip.speedViolations) * 5.0
        let hardStopDeduction = Double(trip.hardStops) * 3.0
        let sharpTurnDeduction = Double(trip.sharpTurns) * 2.0
        let potholeDeduction = Double(trip.potholesDetected) * 1.0
        let totalDeduction = speedDeduction + hardStopDeduction + sharpTurnDeduction + potholeDeduction
        
        return (trip.speedViolations, trip.hardStops, trip.sharpTurns, trip.potholesDetected, totalDeduction)
    }
    
    func resetCurrentTripScore() {
        guard var trip = currentTrip else { return }
        
        trip.driverScore = 100.0
        trip.speedViolations = 0
        trip.hardStops = 0
        trip.sharpTurns = 0
        trip.potholesDetected = 0
        
        DispatchQueue.main.async {
            self.currentTrip = trip
        }
        
        logger.info("🔄 Current trip score reset to 100.0")
    }
    
    func getAverageDriverScore() -> Double {
        guard !trips.isEmpty else { return 100.0 } // Default perfect score if no trips
        
        let totalScore = trips.map { $0.driverScore }.reduce(0, +)
        let averageScore = totalScore / Double(trips.count)
        
        logger.info("📊 Average driver score calculated: \(String(format: "%.1f", averageScore)) from \(trips.count) trips")
        
        return averageScore
    }
    
    func getDriverScoreBreakdown() -> (average: Double, current: Double?, totalTrips: Int, scoreRange: (min: Double, max: Double)) {
        let average = getAverageDriverScore()
        let current = currentTrip?.driverScore
        let totalTrips = trips.count
        
        let scores = trips.map { $0.driverScore }
        let minScore = scores.min() ?? 100.0
        let maxScore = scores.max() ?? 100.0
        
        return (average, current, totalTrips, (min: minScore, max: maxScore))
    }
    
    // MARK: - Speed Limit Detection
    
    private var lastSpeedLimitCheck: Date = Date()
    private var lastSpeedLimitCoordinate: CLLocationCoordinate2D?
    private let speedLimitCheckInterval: TimeInterval = 10.0 // Check every 10 seconds - more efficient
    private let speedLimitDistanceThreshold: Double = 100.0 // Check if moved 100+ meters
    
    private func fetchSpeedLimit(for coordinate: CLLocationCoordinate2D) async {
        // Only check speed limit if enough time has passed or we've moved significantly
        let timeSinceLastCheck = Date().timeIntervalSince(lastSpeedLimitCheck)
        let distanceFromLastCheck: Double
        if let lastCoordinate = lastSpeedLimitCoordinate {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            distanceFromLastCheck = lastLocation.distance(from: currentLocation)
        } else {
            distanceFromLastCheck = Double.greatestFiniteMagnitude
        }
        
        guard timeSinceLastCheck >= speedLimitCheckInterval || distanceFromLastCheck >= speedLimitDistanceThreshold else {
            return
        }
        
        lastSpeedLimitCheck = Date()
        lastSpeedLimitCoordinate = coordinate
        
        // Fetch speed limit using unified service
        if let result = await speedLimitService.getSpeedLimit(for: coordinate) {
            let previousSpeedLimit = self.speedLimit
            self.speedLimit = result.speedLimit
            
            // Smart speed violation detection - only trigger once until speed drops below limit
            let currentSpeed = self.currentSpeed
            let speedLimitValue = result.speedLimit
            let isSpeeding = currentSpeed > speedLimitValue
            
            if isSpeeding && !self.isCurrentlySpeeding {
                // New speed violation - trigger alert
                self.speedViolation = true
                self.isCurrentlySpeeding = true
                self.lastSpeedViolationTime = Date()
            } else if !isSpeeding && self.isCurrentlySpeeding {
                // Speed dropped below limit - reset violation state
                self.speedViolation = false
                self.isCurrentlySpeeding = false
            } else if isSpeeding && self.isCurrentlySpeeding {
                // Still speeding - keep violation state but don't trigger new alert
                self.speedViolation = true
            }
        }
    }
    
    
    // MARK: - Navigation
    
    func setDestination(_ destination: String) {
        self.destination = destination
    }
    
    func getDirections(to destination: String) {
        guard let currentLocation = currentCoordinate else { 
            print("No current location available for navigation")
            return 
        }
        
        // First, geocode the destination string to get coordinates
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(destination) { [weak self] placemarks, error in
            if let error = error {
                errorHandler.handle(error, context: "Geocoding destination: \(destination)", userFacing: true)
                DispatchQueue.main.async {
                    self?.locationError = "Could not find destination: \(destination)"
                }
                return
            }
            
            guard let placemark = placemarks?.first,
                  let destinationCoordinate = placemark.location?.coordinate else {
                let error = FleetTrackerError.geocodingFailed
                errorHandler.handle(error, context: "Geocoding destination: \(destination)", userFacing: true)
                DispatchQueue.main.async {
                    self?.locationError = "Could not find coordinates for: \(destination)"
                }
                return
            }
            
            // Now calculate directions with the geocoded destination
            self?.calculateRoute(from: currentLocation, to: destinationCoordinate)
        }
    }
    
    private func calculateRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        
        // Apply route preferences
        request.transportType = routePreferences.transportType
        request.requestsAlternateRoutes = routePreferences.requestsAlternateRoutes
        
        // Note: AvoidOptions API not available in iOS 17
        // Route preferences will be handled by transport type and alternate routes only
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorHandler.handle(error, context: "Directions calculation", userFacing: true)
                    self?.locationError = "Could not calculate route: \(error.localizedDescription)"
                    return
                }
                
                guard let response = response, !response.routes.isEmpty else {
                    let error = FleetTrackerError.unknown("No routes found to destination")
                    errorHandler.handle(error, context: "Directions calculation", userFacing: true)
                    self?.locationError = "No route found to destination"
                    return
                }
                
                // Store all available routes
                self?.availableRoutes = response.routes
                self?.selectedRouteIndex = 0
                
                // Select the first route by default
                let selectedRoute = response.routes.first!
                self?.route = selectedRoute
                self?.isNavigating = true
                self?.navigationInstructions = selectedRoute.steps.map { $0.instructions }
                self?.routeDistance = selectedRoute.distance / 1609.34 // Convert meters to miles
                self?.routeDuration = selectedRoute.expectedTravelTime // Keep in seconds
                self?.currentStepIndex = 0
                self?.locationError = nil
                
                print("✅ Route calculated successfully - \(response.routes.count) routes available")
                print("Route distance: \(selectedRoute.distance / 1609.34) miles") // Convert meters to miles
                print("Route duration: \(selectedRoute.expectedTravelTime / 60) minutes") // Convert seconds to minutes
            }
        }
    }
    
    func stopNavigation() {
        DispatchQueue.main.async {
            self.isNavigating = false
            self.route = nil
            self.navigationInstructions = []
            self.currentStepIndex = 0
            self.routeDistance = 0.0
            self.routeDuration = 0.0
            self.availableRoutes = []
            self.selectedRouteIndex = 0
        }
    }
    
    func selectRoute(at index: Int) {
        guard index >= 0 && index < availableRoutes.count else { return }
        
        selectedRouteIndex = index
        let selectedRoute = availableRoutes[index]
        
        route = selectedRoute
        navigationInstructions = selectedRoute.steps.map { $0.instructions }
        routeDistance = selectedRoute.distance / 1609.34
        routeDuration = selectedRoute.expectedTravelTime
        currentStepIndex = 0
        
        print("🔄 Route selected: \(index + 1)/\(availableRoutes.count) - Distance: \(routeDistance) miles, Duration: \(routeDuration/60) minutes")
    }
    
    // MARK: - Address Suggestions
    
    private var addressSearchTask: Task<Void, Never>?
    private var addressSearchWorkItem: DispatchWorkItem?
    
    func searchAddresses(query: String) {
        // Cancel previous search
        addressSearchTask?.cancel()
        addressSearchWorkItem?.cancel()
        
        guard !query.isEmpty, query.count > 2 else {
            DispatchQueue.main.async {
                self.addressSuggestions = []
                self.isSearchingAddresses = false
            }
            return
        }
        
        // Debounce the search to prevent excessive API calls
        let workItem = DispatchWorkItem { [weak self] in
            self?.performAddressSearch(query: query)
        }
        
        addressSearchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    private func performAddressSearch(query: String) {
        DispatchQueue.main.async {
            self.isSearchingAddresses = true
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: currentCoordinate ?? CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458), // Detroit default
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearchingAddresses = false
                
                if let error = error {
                    print("Address search error: \(error.localizedDescription)")
                    self?.addressSuggestions = []
                    return
                }
                
                self?.addressSuggestions = response?.mapItems ?? []
            }
        }
    }
    
    func selectAddress(_ mapItem: MKMapItem) {
        DispatchQueue.main.async {
            self.destination = mapItem.name ?? mapItem.placemark.title ?? "Selected Location"
            self.addressSuggestions = []
        }
    }
    
    func cancelAddressSearch() {
        addressSearchTask?.cancel()
        addressSearchWorkItem?.cancel()
        DispatchQueue.main.async {
            self.addressSuggestions = []
            self.isSearchingAddresses = false
        }
    }
    
    // MARK: - Enhanced Search Functionality
    
    enum SearchCategory: String, CaseIterable {
        case gasStations = "Gas Stations"
        case restaurants = "Restaurants"
        case parking = "Parking"
        case hospitals = "Hospitals"
        case police = "Police Stations"
        case hotels = "Hotels"
        case banks = "Banks"
        case pharmacies = "Pharmacies"
        case grocery = "Grocery Stores"
        case autoRepair = "Auto Repair"
        
        var mapKitCategory: MKPointOfInterestCategory? {
            switch self {
            case .gasStations: return .gasStation
            case .restaurants: return .restaurant
            case .parking: return .parking
            case .hospitals: return .hospital
            case .police: return .police
            case .hotels: return .hotel
            case .banks: return .bank
            case .pharmacies: return .pharmacy
            case .grocery: return .store
            case .autoRepair: return .store // Use store category as fallback for auto repair
            }
        }
    }
    
    @Published var searchResults: [MKMapItem] = []
    @Published var selectedSearchCategory: SearchCategory? = nil
    @Published var isSearchingNearby: Bool = false
    
    func searchNearby(category: SearchCategory, radius: Double = 5000) {
        guard let currentLocation = currentCoordinate else {
            print("No current location for nearby search")
            return
        }
        
        isSearchingNearby = true
        selectedSearchCategory = category
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.rawValue
        request.region = MKCoordinateRegion(
            center: currentLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        // Add category filter if available
        if let mapKitCategory = category.mapKitCategory {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [mapKitCategory])
        }
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearchingNearby = false
                
                if let error = error {
                    print("Nearby search error: \(error.localizedDescription)")
                    return
                }
                
                guard let response = response else {
                    print("No search results")
                    return
                }
                
                self?.searchResults = response.mapItems
                print("🔍 Found \(response.mapItems.count) \(category.rawValue) nearby")
            }
        }
    }
    
    func searchForDestination(_ query: String, category: SearchCategory? = nil) {
        guard !query.isEmpty else { return }
        
        isSearchingAddresses = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        // Add category filter if specified
        if let category = category, let mapKitCategory = category.mapKitCategory {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [mapKitCategory])
        }
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearchingAddresses = false
                
                if let error = error {
                    print("Destination search error: \(error.localizedDescription)")
                    return
                }
                
                guard let response = response else {
                    print("No destination search results")
                    return
                }
                
                self?.addressSuggestions = response.mapItems
                print("🎯 Found \(response.mapItems.count) destinations for '\(query)'")
            }
        }
    }
    
    // MARK: - Enhanced Navigation
    
    func getCurrentNavigationStep() -> String? {
        guard isNavigating, 
              let route = route,
              currentStepIndex < route.steps.count else {
            return nil
        }
        
        return route.steps[currentStepIndex].instructions
    }
    
    func getNextNavigationStep() -> String? {
        guard isNavigating,
              let route = route,
              currentStepIndex + 1 < route.steps.count else {
            return nil
        }
        
        return route.steps[currentStepIndex + 1].instructions
    }
    
    func updateNavigationProgress() {
        guard isNavigating,
              let route = route,
              let currentLocation = currentCoordinate else {
            return
        }
        
        // Find the closest step to current location
        var closestStepIndex = 0
        var minDistance = Double.greatestFiniteMagnitude
        
        for (index, step) in route.steps.enumerated() {
            let stepLocation = CLLocation(latitude: step.polyline.coordinate.latitude, 
                                        longitude: step.polyline.coordinate.longitude)
            let currentLocationObj = CLLocation(latitude: currentLocation.latitude, 
                                             longitude: currentLocation.longitude)
            let distance = currentLocationObj.distance(from: stepLocation)
            
            if distance < minDistance {
                minDistance = distance
                closestStepIndex = index
            }
        }
        
        DispatchQueue.main.async {
            self.currentStepIndex = closestStepIndex
        }
    }
    
    // MARK: - Firebase Integration
    
    private func saveTripToFirebase(_ trip: Trip) {
        logger.firebase("Saving trip to Firebase: \(trip.id)")
        logger.firebase("Trip details: Start: \(trip.startTime), End: \(trip.endTime?.formatted() ?? "N/A"), Distance: \(String(format: "%.2f", trip.totalDistance/1609.34)) miles")
        logger.firebase("Violations: Speed: \(trip.speedViolations), Hard stops: \(trip.hardStops), Sharp turns: \(trip.sharpTurns), Potholes: \(trip.potholesDetected)")
        
        do {
            let data = try Firestore.Encoder().encode(trip)
            db.collection("trips").addDocument(data: data) { [weak self] error in
                if let error = error {
                    errorHandler.handle(error, context: "Firebase trip save", userFacing: false)
                } else {
                    logger.firebase("Trip saved to Firebase successfully with ID: \(trip.id)")
                    // Reload trips after saving to ensure UI is updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.loadTrips()
                    }
                }
            }
        } catch {
            errorHandler.handle(error, context: "Firebase trip data encoding", userFacing: false)
        }
    }
    
    func loadTrips() {
        logger.info("Loading trips from Firebase for device: \(deviceId)")
        db.collection("trips")
            .whereField("deviceId", isEqualTo: deviceId)
            .limit(to: 100)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    errorHandler.handle(error, context: "Firebase load trips", userFacing: true)
                    return
                }
                
                guard let documents = snapshot?.documents else { 
                    logger.warning("No trip documents found")
                    return 
                }
                
                logger.debug("Found \(documents.count) trip documents")
                
                DispatchQueue.main.async {
                    let loadedTrips = documents.compactMap { document -> Trip? in
                        do {
                            let trip = try Firestore.Decoder().decode(Trip.self, from: document.data())
                            logger.debug("Loaded trip: \(trip.startTime) - \(trip.endTime?.formatted() ?? "Ongoing")")
                            return trip
                        } catch {
                            errorHandler.handle(error, context: "Firebase trip decoding", userFacing: false)
                            return nil
                        }
                    }
                    
                    self?.trips = loadedTrips.sorted { $0.startTime > $1.startTime }
                    logger.info("Total trips loaded: \(self?.trips.count ?? 0)")
                    
                    self?.updateDrivingSummary()
                }
            }
    }
    
    func clearSpeedLimitCache() {
        speedLimitService.clearCache()
        
        // Also clear the current speed limit to force re-detection
        DispatchQueue.main.async {
            self.speedLimit = nil
            self.isFetchingSpeedLimit = true
        }
        
        // Force re-detection after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let coordinate = self.currentCoordinate {
                Task {
                    await self.fetchSpeedLimit(for: coordinate)
                }
            }
        }
    }
    
    func downloadAllDetroitSpeedLimits() async {
        logger.info("Starting comprehensive Detroit speed limit download...")
        
        let downloader = OSMDetroitSpeedLimitDownloader()
        let osmData = await downloader.downloadAllDetroitSpeedLimits()
        
        if !osmData.isEmpty {
            // Populate the Detroit database with OSM data
            DetroitSpeedLimitDatabase.shared.populateFromOSMData(osmData)
            
            // Get statistics
            let stats = DetroitSpeedLimitDatabase.shared.getDatabaseStats()
            logger.info("Detroit Database Statistics:")
            logger.info("   Total streets: \(stats.total)")
            logger.info("   Speed ranges: \(stats.bySpeedRange)")
            logger.info("   Road types: \(stats.byRoadType)")
            
            // Clear cache to use new data
            DispatchQueue.main.async {
                self.clearSpeedLimitCache()
            }
        } else {
            logger.warning("No speed limit data downloaded")
        }
    }
    
    // MARK: - Violation Testing
    
    func testSpeedViolationDetection() {
        logger.info("TESTING Speed Violation Detection")
        logger.info("Current speed limit: \(speedLimit?.formatted() ?? "None") mph")
        logger.info("Current speed: \(String(format: "%.1f", currentSpeed)) mph")
        logger.info("Speed violation state: \(speedViolation ? "VIOLATING" : "OK")")
        logger.info("To test: Drive above the speed limit")
        logger.info("Look for: 'Speed violation detected: X.X mph (limit: Y mph)' in logs")
        logger.info("Recent violations: \(recentViolations.filter { $0.speedViolation }.count) speed violations")
    }
    
    func testHardStopDetection() {
        logger.info("TESTING Hard Stop Detection")
        logger.info("Current threshold: > 2.5 m/s² deceleration")
        logger.info("Moderate braking threshold: > 1.5 m/s²")
        logger.info("To test: Drive normally, then brake hard (like emergency stop)")
        logger.info("Look for: 'Hard brake detected: X.X m/s²' in logs")
        logger.info("Recent violations: \(recentViolations.filter { $0.hardStop }.count) hard stops")
    }
    
    func testSharpTurnDetection() {
        logger.info("TESTING Sharp Turn Detection")
        logger.info("Current threshold: > 40° heading change (adjusted based on research)")
        logger.info("Moderate turn threshold: > 15°")
        logger.info("Research: Normal turns are 15-30°, sharp turns are 45°+")
        logger.info("To test: Drive straight, then make sharp turns (like 90° turns)")
        logger.info("Look for: 'Sharp turn detected: XX° change' in logs")
        logger.info("Recent violations: \(recentViolations.filter { $0.sharpTurn }.count) sharp turns")
    }
    
    func testPotholeDetection() {
        logger.info("TESTING Pothole Detection")
        logger.info("Current threshold: Vertical > 1.8g OR Total > 2.0g")
        logger.info("Accelerometer status: \(customMotionManager.isAccelerometerAvailable ? "Available" : "Not Available")")
        logger.info("Accelerometer active: \(customMotionManager.isAccelerometerActive ? "Active" : "Inactive")")
        logger.info("To test: Drive over bumps, potholes, or rough road surfaces")
        logger.info("Look for: 'POTHOLE DETECTED! Vertical: X.XXg, Total: X.XXg' in logs")
        logger.info("Recent violations: \(recentViolations.filter { $0.potholeDetected }.count) potholes")
    }
    
    func showViolationStats() {
        logger.info("VIOLATION DETECTION STATISTICS")
        logger.info(String(repeating: "=", count: 50))
        
        let totalViolations = recentViolations.count
        let speedViolations = recentViolations.filter { $0.speedViolation }.count
        let hardStops = recentViolations.filter { $0.hardStop }.count
        let sharpTurns = recentViolations.filter { $0.sharpTurn }.count
        let potholes = recentViolations.filter { $0.potholeDetected }.count
        
        logger.info("Recent Violations (last 10):")
        logger.info("   Total: \(totalViolations)")
        logger.info("   Speed Violations: \(speedViolations)")
        logger.info("   Hard Stops: \(hardStops)")
        logger.info("   Sharp Turns: \(sharpTurns)")
        logger.info("   Potholes: \(potholes)")
        
        if let currentTrip = currentTrip {
            logger.info("Current Trip Violations:")
            logger.info("   Speed Violations: \(currentTrip.speedViolations)")
            logger.info("   Hard Stops: \(currentTrip.hardStops)")
            logger.info("   Sharp Turns: \(currentTrip.sharpTurns)")
            logger.info("   Potholes: \(currentTrip.potholesDetected)")
            logger.info("   Driver Score: \(Int(currentTrip.driverScore))")
        }
        
        logger.info("All-Time Trip Violations:")
        let allSpeedViolations = trips.reduce(0) { $0 + $1.speedViolations }
        let allHardStops = trips.reduce(0) { $0 + $1.hardStops }
        let allSharpTurns = trips.reduce(0) { $0 + $1.sharpTurns }
        let allPotholes = trips.reduce(0) { $0 + $1.potholesDetected }
        
        logger.info("   Total Speed Violations: \(allSpeedViolations)")
        logger.info("   Total Hard Stops: \(allHardStops)")
        logger.info("   Total Sharp Turns: \(allSharpTurns)")
        logger.info("   Total Potholes: \(allPotholes)")
        
        logger.info("Driving Summary (UI Display):")
        logger.info("   Total Trips: \(drivingSummary.totalTrips)")
        logger.info("   Speed Violations: \(drivingSummary.speedViolations)")
        logger.info("   Hard Stops: \(drivingSummary.hardStops)")
        logger.info("   Sharp Turns: \(drivingSummary.sharpTurns)")
        logger.info("   Potholes: \(drivingSummary.potholesDetected)")
        logger.info("   Overall Score: \(Int(drivingSummary.overallDriverScore))")
        
        logger.info(String(repeating: "=", count: 50))
    }
    
    func testViolationsAndTrips() {
        logger.info("TESTING Violations Summary & Trip History")
        logger.info(String(repeating: "=", count: 50))
        
        // Test 1: Check if trips are loading
        logger.info("Test 1: Trip Loading")
        logger.info("   Total trips in memory: \(trips.count)")
        logger.info("   Recent violations count: \(recentViolations.count)")
        
        // Test 2: Check driving summary calculation
        logger.info("Test 2: Driving Summary")
        logger.info("   Summary total trips: \(drivingSummary.totalTrips)")
        logger.info("   Summary speed violations: \(drivingSummary.speedViolations)")
        logger.info("   Summary hard stops: \(drivingSummary.hardStops)")
        logger.info("   Summary sharp turns: \(drivingSummary.sharpTurns)")
        logger.info("   Summary potholes: \(drivingSummary.potholesDetected)")
        
        // Test 3: Check if summary matches actual trips
        let calculatedSpeedViolations = trips.reduce(0) { $0 + $1.speedViolations }
        let calculatedHardStops = trips.reduce(0) { $0 + $1.hardStops }
        let calculatedSharpTurns = trips.reduce(0) { $0 + $1.sharpTurns }
        let calculatedPotholes = trips.reduce(0) { $0 + $1.potholesDetected }
        
        logger.info("Test 3: Summary Accuracy")
        logger.info("   Speed violations match: \(drivingSummary.speedViolations == calculatedSpeedViolations)")
        logger.info("   Hard stops match: \(drivingSummary.hardStops == calculatedHardStops)")
        logger.info("   Sharp turns match: \(drivingSummary.sharpTurns == calculatedSharpTurns)")
        logger.info("   Potholes match: \(drivingSummary.potholesDetected == calculatedPotholes)")
        
        // Test 4: Check Firebase connection
        logger.info("Test 4: Firebase Status")
        logger.info("   Device ID: \(deviceId)")
        logger.info("   Firebase connected: \(db != nil)")
        
        // Test 5: Force reload trips
        logger.info("Test 5: Force Reload Trips")
        loadTrips()
        
        logger.info(String(repeating: "=", count: 50))
    }
}

// MARK: - Route Preferences

struct RoutePreferences: Codable {
    var transportType: MKDirectionsTransportType = .automobile
    var requestsAlternateRoutes: Bool = true
    
    // Custom coding keys for MKDirectionsTransportType
    private enum CodingKeys: String, CodingKey {
        case transportTypeRaw, requestsAlternateRoutes
    }
    
    var transportTypeRaw: Int {
        get { Int(transportType.rawValue) }
        set { transportType = MKDirectionsTransportType(rawValue: UInt(newValue)) ?? .automobile }
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requestsAlternateRoutes = try container.decode(Bool.self, forKey: .requestsAlternateRoutes)
        transportTypeRaw = try container.decode(Int.self, forKey: .transportTypeRaw)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestsAlternateRoutes, forKey: .requestsAlternateRoutes)
        try container.encode(transportTypeRaw, forKey: .transportTypeRaw)
    }
}
