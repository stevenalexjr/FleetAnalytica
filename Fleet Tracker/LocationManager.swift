//
//  LocationManager.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let logger = Logger.shared
    private let errorHandler = ErrorHandler.shared
    private let configuration = ConfigurationManager.shared
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking: Bool = false
    @Published var locationError: String?
    @Published var isBackgroundTrackingEnabled: Bool = false
    
    // Location update callbacks
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = configuration.locationAccuracy
        locationManager.distanceFilter = configuration.locationDistanceFilter
        
        // Request initial authorization
        requestLocationPermission()
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            logger.warning("Location permission denied or restricted")
        case .authorizedWhenInUse:
            logger.info("Location permission granted for when in use")
            onAuthorizationChange?(authorizationStatus)
        case .authorizedAlways:
            logger.info("Location permission granted always")
            onAuthorizationChange?(authorizationStatus)
        @unknown default:
            logger.warning("Unknown location authorization status")
        }
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            logger.error("Cannot start tracking without location permission")
            return
        }
        
        locationManager.startUpdatingLocation()
        isTracking = true
        locationError = nil
        
        logger.info("Location tracking started")
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        isTracking = false
        
        logger.info("Location tracking stopped")
    }
    
    func enableBackgroundLocationUpdates() {
        guard authorizationStatus == .authorizedAlways else {
            logger.warning("Background location updates require 'Always' permission")
            return
        }
        
        DispatchQueue.main.async {
            do {
                self.locationManager.allowsBackgroundLocationUpdates = true
                self.locationManager.pausesLocationUpdatesAutomatically = false
                self.isBackgroundTrackingEnabled = true
                self.logger.info("Background location updates enabled")
            } catch {
                self.errorHandler.handle(error, context: "Background location setup", userFacing: true)
                self.isBackgroundTrackingEnabled = false
            }
        }
    }
    
    func disableBackgroundLocationUpdates() {
        locationManager.allowsBackgroundLocationUpdates = false
        isBackgroundTrackingEnabled = false
        
        logger.info("Background location updates disabled")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = newLocation
            self.onLocationUpdate?(newLocation)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse:
                self.logger.info("Location permission granted for when in use")
            case .authorizedAlways:
                self.logger.info("Location permission granted always")
            case .denied:
                self.logger.warning("Location permission denied")
                self.locationError = "Location access denied. Please enable in Settings."
            case .restricted:
                self.logger.warning("Location permission restricted")
                self.locationError = "Location access restricted."
            case .notDetermined:
                self.logger.info("Location permission not determined")
            @unknown default:
                self.logger.warning("Unknown location authorization status")
            }
            
            self.onAuthorizationChange?(status)
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
    
    // MARK: - Helper Methods
    
    func getCurrentCoordinate() -> CLLocationCoordinate2D? {
        return currentLocation?.coordinate
    }
    
    func getCurrentSpeed() -> Double {
        return currentLocation?.speed ?? 0.0
    }
    
    func getCurrentHeading() -> Double {
        return currentLocation?.course ?? -1.0
    }
    
    func getLocationAccuracy() -> Double {
        return currentLocation?.horizontalAccuracy ?? -1.0
    }
}
