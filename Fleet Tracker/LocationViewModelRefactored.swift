//
//  LocationViewModelRefactored.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation
import Combine
import MapKit

// MARK: - Refactored Location View Model

class LocationViewModelRefactored: ObservableObject {
    // MARK: - Managers
    private let locationManager = LocationManager()
    private let motionManager = MotionManager()
    private let tripManager: TripManager
    private let speedLimitService = UnifiedSpeedLimitService.shared
    private let dataPersistenceManager = DataPersistenceManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - Published Properties
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var currentSpeed: Double = 0.0
    @Published var speedLimit: Double?
    @Published var speedViolation: Bool = false
    @Published var locationHistory: [LocationRecord] = []
    @Published var recentViolations: [LocationRecord] = []
    @Published var isFetchingSpeedLimit: Bool = false
    
    // MARK: - Navigation Properties
    @Published var destination: String = ""
    @Published var route: MKRoute?
    @Published var isNavigating: Bool = false
    @Published var navigationInstructions: [String] = []
    @Published var currentStepIndex: Int = 0
    @Published var routeDistance: Double = 0.0
    @Published var routeDuration: TimeInterval = 0.0
    @Published var availableRoutes: [MKRoute] = []
    @Published var selectedRouteIndex: Int = 0
    
    // MARK: - Route Preferences
    @Published var transportType: MKDirectionsTransportType = .automobile
    @Published var avoidHighways: Bool = false
    @Published var avoidTolls: Bool = false
    @Published var avoidFerries: Bool = false
    
    // MARK: - Private Properties
    private let deviceId: String
    private var cancellables = Set<AnyCancellable>()
    private var previousLocation: CLLocation?
    private var previousHeading: Double?
    
    // Speed limit checking
    private var lastSpeedLimitCheck: Date = Date()
    private var lastSpeedLimitCoordinate: CLLocationCoordinate2D?
    private let speedLimitCheckInterval: TimeInterval = 10.0
    private let speedLimitDistanceThreshold: Double = 100.0
    
    // Speed violation state tracking
    private var isCurrentlySpeeding: Bool = false
    private var lastSpeedViolationTime: Date?
    
    init() {
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.tripManager = TripManager(deviceId: deviceId)
        
        setupBindings()
        setupCallbacks()
        
        // Load initial data
        Task {
            await loadLocationHistory()
            await tripManager.loadTrips()
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind location manager properties
        locationManager.$currentLocation
            .map { $0?.coordinate }
            .assign(to: &$currentCoordinate)
        
        locationManager.$currentLocation
            .map { $0?.speed ?? 0.0 }
            .assign(to: &$currentSpeed)
        
        locationManager.$authorizationStatus
            .sink { [weak self] status in
                self?.handleAuthorizationChange(status)
            }
            .store(in: &cancellables)
        
        // Bind trip manager properties
        tripManager.$currentTrip
            .sink { [weak self] trip in
                // Handle trip changes
            }
            .store(in: &cancellables)
        
        tripManager.$trips
            .sink { [weak self] trips in
                // Handle trips changes
            }
            .store(in: &cancellables)
        
        tripManager.$drivingSummary
            .sink { [weak self] summary in
                // Handle driving summary changes
            }
            .store(in: &cancellables)
    }
    
    private func setupCallbacks() {
        // Location update callback
        locationManager.onLocationUpdate = { [weak self] location in
            self?.processLocationUpdate(location)
        }
        
        // Motion detection callbacks
        motionManager.onPotholeDetected = { [weak self] in
            self?.handlePotholeDetected()
        }
        
        motionManager.onHardStopDetected = { [weak self] in
            self?.handleHardStopDetected()
        }
        
        motionManager.onSharpTurnDetected = { [weak self] in
            self?.handleSharpTurnDetected()
        }
    }
    
    // MARK: - Public Methods
    
    func startTracking() {
        locationManager.startTracking()
        motionManager.startAccelerometerUpdates()
    }
    
    func stopTracking() {
        locationManager.stopTracking()
        motionManager.stopAccelerometerUpdates()
    }
    
    func requestLocationPermission() {
        locationManager.requestLocationPermission()
    }
    
    func enableBackgroundLocationUpdates() {
        locationManager.enableBackgroundLocationUpdates()
    }
    
    // MARK: - Location Processing
    
    private func processLocationUpdate(_ newLocation: CLLocation) {
        // Validate location data
        let validationResult = dataValidator.validateLocation(newLocation)
        if !validationResult.isValid {
            for error in validationResult.errors {
                if error.severity == .error {
                    logger.error("Location validation failed: \(error.message)")
                    return
                } else {
                    logger.warning("Location validation warning: \(error.message)")
                }
            }
        }
        
        // Create location record
        let record = createLocationRecord(from: newLocation)
        
        // Analyze driving behavior
        let violations = analyzeDrivingBehavior(for: record, previousLocation: previousLocation)
        
        // Update trip with violations
        tripManager.updateTripWithLocation(newLocation, speedLimit: speedLimit, violations: violations)
        
        // Update speed limit
        Task {
            await fetchSpeedLimit(for: newLocation.coordinate)
        }
        
        // Add to history
        locationHistory.append(record)
        
        // Keep only last 200 locations
        if locationHistory.count > 200 {
            locationHistory.removeFirst()
        }
        
        // Add violations to recent violations
        if violations.hasAnyViolation {
            recentViolations.append(record)
            
            // Keep only last 10 violations
            if recentViolations.count > 10 {
                recentViolations.removeFirst()
            }
        }
        
        // Save to persistence
        Task {
            await dataPersistenceManager.saveLocationRecord(record)
        }
        
        // Update previous location
        previousLocation = newLocation
    }
    
    private func createLocationRecord(from location: CLLocation) -> LocationRecord {
        let speedMph = location.speed >= 0 ? location.speed * 2.237 : nil
        let heading = location.course >= 0 ? location.course : nil
        
        return LocationRecord(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            deviceId: deviceId,
            speed: location.speed >= 0 ? location.speed : nil, // m/s
            heading: heading,
            speedLimit: speedLimit,
            speedViolation: false, // Will be set by analyzeDrivingBehavior
            hardStop: false,
            sharpTurn: false,
            potholeDetected: false,
            acceleration: nil,
            deceleration: nil,
            driverBehaviorScore: 100.0
        )
    }
    
    private func analyzeDrivingBehavior(for record: LocationRecord, previousLocation: CLLocation?) -> LocationViolations {
        var violations = LocationViolations(
            speedViolation: false,
            hardStop: false,
            sharpTurn: false,
            potholeDetected: false
        )
        
        // Speed violation detection
        if let speed = record.speedInMph, let limit = speedLimit {
            violations.speedViolation = speed > limit
        }
        
        // Hard stop detection
        if let deceleration = calculateDeceleration(from: previousLocation, to: record) {
            violations.hardStop = motionManager.detectHardStop(deceleration: deceleration)
        }
        
        // Sharp turn detection
        if let headingChange = calculateHeadingChange(from: previousHeading, to: record.heading) {
            violations.sharpTurn = motionManager.detectSharpTurn(headingChange: headingChange)
        }
        
        // Pothole detection
        violations.potholeDetected = motionManager.detectPothole()
        
        return violations
    }
    
    // MARK: - Speed Limit Management
    
    private func fetchSpeedLimit(for coordinate: CLLocationCoordinate2D) async {
        // Check if enough time has passed or we've moved significantly
        let timeSinceLastCheck = Date().timeIntervalSince(lastSpeedLimitCheck)
        let distanceFromLastCheck = lastSpeedLimitCoordinate?.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
        
        guard timeSinceLastCheck >= speedLimitCheckInterval || distanceFromLastCheck >= speedLimitDistanceThreshold else {
            return
        }
        
        lastSpeedLimitCheck = Date()
        lastSpeedLimitCoordinate = coordinate
        
        DispatchQueue.main.async {
            self.isFetchingSpeedLimit = true
        }
        
        if let result = await speedLimitService.getSpeedLimit(for: coordinate) {
            await MainActor.run {
                self.speedLimit = result.speedLimit
                self.isFetchingSpeedLimit = false
                
                // Update speed violation state
                self.updateSpeedViolationState()
            }
        } else {
            await MainActor.run {
                self.isFetchingSpeedLimit = false
            }
        }
    }
    
    private func updateSpeedViolationState() {
        guard let speedLimitValue = speedLimit else { return }
        
        let isSpeeding = currentSpeed > speedLimitValue
        
        if isSpeeding && !isCurrentlySpeeding {
            // New speed violation
            speedViolation = true
            isCurrentlySpeeding = true
            lastSpeedViolationTime = Date()
        } else if !isSpeeding && isCurrentlySpeeding {
            // Speed dropped below limit
            speedViolation = false
            isCurrentlySpeeding = false
        } else if isSpeeding && isCurrentlySpeeding {
            // Still speeding
            speedViolation = true
        }
    }
    
    // MARK: - Trip Management
    
    func startNewTrip() {
        Task {
            await tripManager.startNewTrip(destination: destination)
        }
    }
    
    func endCurrentTrip() {
        Task {
            await tripManager.endCurrentTrip()
        }
    }
    
    // MARK: - Navigation
    
    func setDestination(_ destination: String) {
        self.destination = destination
    }
    
    func getDirections() {
        guard !destination.isEmpty,
              let currentLocation = locationManager.currentLocation else {
            return
        }
        
        Task {
            await calculateRoute(from: currentLocation.coordinate, to: destination)
        }
    }
    
    private func calculateRoute(from startCoordinate: CLLocationCoordinate2D, to destination: String) async {
        // Geocode destination
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(destination)
            guard let placemark = placemarks.first,
                  let destinationCoordinate = placemark.location?.coordinate else {
                return
            }
            
            // Calculate route
            await calculateRoute(from: startCoordinate, to: destinationCoordinate)
            
        } catch {
            errorHandler.handle(error, context: "Geocoding destination: \(destination)", userFacing: true)
        }
    }
    
    private func calculateRoute(from startCoordinate: CLLocationCoordinate2D, to endCoordinate: CLLocationCoordinate2D) async {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endCoordinate))
        request.transportType = transportType
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            await MainActor.run {
                if let route = response.routes.first {
                    self.route = route
                    self.availableRoutes = response.routes
                    self.selectedRouteIndex = 0
                    self.routeDistance = route.distance / 1609.34 // Convert to miles
                    self.routeDuration = route.expectedTravelTime
                    self.isNavigating = true
                }
            }
            
        } catch {
            await errorHandler.handleAsync(error, context: "Directions calculation", userFacing: true)
        }
    }
    
    // MARK: - Data Loading
    
    func loadLocationHistory() async {
        let records = await dataPersistenceManager.loadLocationRecords(deviceId: deviceId)
        
        await MainActor.run {
            self.locationHistory = records
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateDeceleration(from previousLocation: CLLocation?, to record: LocationRecord) -> Double? {
        guard let previous = previousLocation,
              let currentSpeed = record.speedInMph else { return nil }
        
        let previousSpeed = previous.speed * 2.237 // Convert to mph
        let timeInterval = record.timestamp.timeIntervalSince(previous.timestamp)
        
        guard timeInterval > 0 else { return nil }
        
        let speedChange = currentSpeed - previousSpeed
        return -speedChange / timeInterval // Negative because it's deceleration
    }
    
    private func calculateHeadingChange(from previousHeading: Double?, to currentHeading: Double?) -> Double? {
        guard let previous = previousHeading,
              let current = currentHeading else { return nil }
        
        var change = current - previous
        
        // Normalize to -180 to 180
        while change > 180 { change -= 360 }
        while change < -180 { change += 360 }
        
        return change
    }
    
    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        // Handle authorization changes
    }
    
    private func handlePotholeDetected() {
        // Handle pothole detection
    }
    
    private func handleHardStopDetected() {
        // Handle hard stop detection
    }
    
    private func handleSharpTurnDetected() {
        // Handle sharp turn detection
    }
    
    // MARK: - Computed Properties
    
    var currentTrip: Trip? {
        return tripManager.currentTrip
    }
    
    var trips: [Trip] {
        return tripManager.trips
    }
    
    var drivingSummary: DrivingBehaviorSummary {
        return tripManager.drivingSummary
    }
    
    var authorizationStatus: CLAuthorizationStatus {
        return locationManager.authorizationStatus
    }
    
    var trackingIsActive: Bool {
        return locationManager.isTracking
    }
    
    var locationError: String? {
        return locationManager.locationError
    }
    
    var isBackgroundTrackingEnabled: Bool {
        return locationManager.isBackgroundTrackingEnabled
    }
}

// MARK: - Extensions

// CLLocationCoordinate2D distance extension is defined in LocationRecord.swift
