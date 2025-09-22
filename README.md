FleetAnalytica
===============

FleetAnalytica is an iOS app that monitors trips, analyzes driving behavior, and provides real‑time insights such as speed limit compliance, hard stops, sharp turns, and pothole detection. It automatically detects trips, calculates a dynamic driver score, and stores trip data in the cloud.

Contents
- Features
- Requirements
- Setup
- Running the App
- Using the App
- Secret Debug Menu
- Privacy & Permissions
- Troubleshooting

Features
- Automatic trip detection: starts when speed > 15 mph, ends when < 15 mph for 3 minutes
- Driver score: live deductions for speed violations, hard stops, sharp turns, potholes
- Speed limit detection: unified service with local cache, Apple MapKit, OSM fallbacks
- Background tracking: optional Always permission for background updates
- Search & navigation helpers: address suggestions, nearby POIs
- Dashboard: current status, average driver score across all trips, trend indicators
- Settings: trip detection thresholds, speed limit controls, driver score breakdown
- Cloud sync: Firebase Firestore for trips/location history
- Structured logging & error handling

Requirements
- macOS with Xcode (15+ recommended)
- iOS 16+ target device or simulator
- A Firebase project (Firestore enabled)
- Apple Developer account (for background modes and distribution)

Setup
1) Clone the repository.

2) Open the workspace/project in Xcode: `Fleet Tracker.xcodeproj`.

3) Firebase configuration:
   - Create a Firebase iOS app and download `GoogleService-Info.plist`.
   - Place it at `Fleet Tracker/GoogleService-Info.plist` (already tracked in the project).
   - Ensure Firestore is enabled in the Firebase console.

4) Info.plist background modes:
   - App uses background modes: `location` and `background-fetch` (already applied in `Fleet-Tracker-Info.plist`).

5) Dependencies:
   - Managed with Swift Package Manager (SPM). Xcode resolves packages on open.

Running the App
- Select a simulator or device and press Run in Xcode.
- On first launch, grant location permissions (When In Use or Always if you want background updates).

Using the App
- Dashboard shows current speed/status and average driver score across trips.
- Start driving: trips begin automatically when you exceed 15 mph.
- Trips end when you remain under 15 mph for at least 3 minutes.
- Violations reduce driver score in real time; view details in Settings → Driver Score.
- Speed limits are detected via the unified service; you can clear cache in Settings.

Secret Debug Menu
- Open Settings → App Information.
- Tap the version number 5 times quickly to reveal the Secret Debug Menu.
- Tools include:
  - Violation testing (speed, hard stop, sharp turn, pothole)
  - Firebase operations (force save, load trips, clear history)
  - Motion thresholds overview and reset
  - Debug info (device ID, counts, etc.)

Privacy & Permissions
- Location: required to record trips and determine speed/route.
- Motion (accelerometer): used for detecting potholes and harsh events.
- Background location: optional for continuous trip logging when the app is in the background.

Troubleshooting
- Missing dSYMs on upload: ensure Build Settings → Debug Information Format = “DWARF with dSYM File”, clean, re‑archive.
- App Store validation: Info.plist UIBackgroundModes should contain only valid values (e.g., `location`, `background-fetch`).
- Speed limits not updating: use Settings → Clear Speed Limit Cache, ensure network connectivity.

License
- See TECH_STACK.md for third‑party licenses and data source terms.

# Fleet Tracker iOS App

A comprehensive iOS location tracking application built with SwiftUI, following MVVM architecture, with Firebase integration for data persistence.

## Features

- **Real-time Location Tracking**: Continuously fetch GPS location with user permission
- **Interactive Map Display**: Show current location on an interactive SwiftUI Map
- **Firebase Integration**: Save location data to Firestore in real-time
- **MVVM Architecture**: Clean separation of Model, View, and ViewModel components
- **Background Tracking**: Optional background location updates with "Always" permission
- **Location History**: View and manage location tracking history
- **Settings Panel**: Comprehensive settings and status information

## Tech Stack

- **SwiftUI**: Modern iOS UI framework
- **CoreLocation**: GPS location services
- **MapKit**: Interactive map display
- **Firebase Firestore**: Cloud database for location persistence
- **Combine**: Reactive programming for location updates
- **MVVM Pattern**: Clean architecture separation

## Project Structure

```
Fleet Tracker/
├── Fleet_TrackerApp.swift          # App entry point with Firebase configuration
├── ContentView.swift               # Main tab view container
├── MapView.swift                   # Interactive map with location tracking
├── LocationViewModel.swift         # Core location and Firebase logic
├── LocationRecord.swift            # Data model for location records
├── Item.swift                      # Original SwiftData model (legacy)
└── Info.plist                      # Location permissions and background modes
```

## Setup Instructions

### 1. Firebase Configuration

1. **Create Firebase Project**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project named "Fleet Tracker"
   - Enable Google Analytics (optional)

2. **Add iOS App to Firebase**:
   - Click "Add app" and select iOS
   - Enter bundle identifier: `com.yourcompany.Fleet-Tracker`
   - Download `GoogleService-Info.plist`
   - Add `GoogleService-Info.plist` to your Xcode project

3. **Enable Firestore**:
   - In Firebase Console, go to Firestore Database
   - Click "Create database"
   - Choose "Start in test mode" for development
   - Select a location for your database

4. **Add Firebase SDK**:
   - In Xcode, go to File > Add Package Dependencies
   - Add: `https://github.com/firebase/firebase-ios-sdk`
   - Select: FirebaseFirestore, FirebaseCore

### 2. Xcode Project Configuration

1. **Configure Location Permissions**:
   - Select your project in Xcode navigator
   - Select the "Fleet Tracker" target
   - Go to the "Info" tab
   - Add these keys:
     - `NSLocationWhenInUseUsageDescription`: "This app needs your location to display your position on the map and track your movement."
     - `NSLocationAlwaysAndWhenInUseUsageDescription`: "This app needs your location to track your movement even when the app is in the background, providing continuous fleet tracking capabilities."

2. **Configure Background Modes**:
   - Select your project target
   - Go to "Signing & Capabilities"
   - Click "+ Capability"
   - Add "Background Modes"
   - Check "Location updates"

3. **Set Deployment Target**:
   - Ensure iOS deployment target is 15.0 or higher
   - This is required for SwiftUI Map functionality

### 3. Firebase Security Rules (Production)

For production, update your Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /locations/{document} {
      allow read, write: if request.auth != null;
      // Or for anonymous access with device ID validation:
      // allow read, write: if resource.data.deviceId == request.auth.uid;
    }
  }
}
```

## Usage

### Basic Location Tracking

1. **Launch the app** - Firebase will be automatically configured
2. **Grant location permission** when prompted
3. **Tap "Start Tracking"** to begin location updates
4. **View your location** on the interactive map
5. **Check "History" tab** to see location records

### Background Tracking

1. **Start tracking** with "When In Use" permission
2. **Tap "Enable Background"** to request "Always" permission
3. **Grant "Always" permission** when iOS prompts
4. **Background tracking** will now work when app is minimized

### Firebase Data Structure

Location data is stored in Firestore with this structure:

```json
{
  "id": "unique-uuid",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "timestamp": "2025-01-20T10:30:00Z",
  "deviceId": "device-uuid",
  "accuracy": 5.0,
  "altitude": 100.0,
  "speed": 2.5
}
```

## Architecture Details

### MVVM Pattern Implementation

- **Model (`LocationRecord`)**: Data structure for location information
- **ViewModel (`LocationViewModel`)**: Business logic, CoreLocation management, Firebase integration
- **View (`MapView`, `ContentView`)**: SwiftUI UI components that observe ViewModel state

### Key Components

#### LocationViewModel
- Manages `CLLocationManager` and location permissions
- Handles Firebase Firestore operations
- Publishes location updates via `@Published` properties
- Implements `CLLocationManagerDelegate` for location callbacks

#### MapView
- Displays interactive SwiftUI Map
- Shows current location with custom annotations
- Provides tracking controls (start/stop/background)
- Displays location history and settings

#### LocationRecord
- Codable struct for Firebase integration
- Includes comprehensive location data (coordinates, accuracy, speed, etc.)
- Conforms to `Identifiable` for SwiftUI list display

## Testing

### Simulator Testing
- Use Xcode's location simulation features
- Go to Debug > Location > Custom Location
- Test different scenarios (moving, stationary, etc.)

### Device Testing
- Test on physical device for accurate GPS
- Verify background tracking functionality
- Check Firebase data persistence

## Troubleshooting

### Common Issues

1. **Location Permission Denied**:
   - Check Info.plist has proper usage descriptions
   - Verify permission requests in LocationViewModel

2. **Firebase Connection Issues**:
   - Ensure `GoogleService-Info.plist` is properly added
   - Check Firebase project configuration
   - Verify Firestore security rules

3. **Background Tracking Not Working**:
   - Confirm "Background Modes" capability is enabled
   - Verify "Always" location permission is granted
   - Check `allowsBackgroundLocationUpdates` is set to true

4. **Map Not Displaying**:
   - Ensure iOS deployment target is 15.0+
   - Check MapKit import statements
   - Verify location permissions are granted

## Future Enhancements

- **Route Visualization**: Draw path lines on map
- **Geofencing**: Set up location-based alerts
- **Offline Support**: Cache location data locally
- **User Authentication**: Firebase Auth integration
- **Data Export**: Export location history to CSV/GPX
- **Real-time Sharing**: Share location with other users

## License

This project is available under the MIT License.
