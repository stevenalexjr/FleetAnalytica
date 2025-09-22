FleetAnalytica Tech Stack
=========================

Overview
FleetAnalytica is a native iOS application built with Swift and SwiftUI. It uses CoreLocation, MapKit, and CoreMotion on device; Firebase Firestore for cloud storage; and a unified speed limit service that prioritizes local data with fallbacks to Apple data and OpenStreetMap.

Architecture
- Pattern: MVVM (ViewModels coordinate managers/services)
- Modules/Managers:
  - `LocationViewModel` (coordinator), `TripManager`, `LocationManager`, `MotionManager`
  - `UnifiedSpeedLimitService` (local cache + Apple + OSM fallback)
  - `Logger`, `ErrorHandler`, `DataValidator`, `DataPersistenceManager`, `NetworkMonitor`
- UI: SwiftUI views (`FleetDashboardView`, `SettingsView`, `TripDetailView`)

Primary Technologies
- Language/UI: Swift, SwiftUI
- Location/Maps: CoreLocation, MapKit
- Motion: CoreMotion (accelerometer)
- Concurrency/Reactive: Combine, Swift Concurrency (async/await)
- Cloud: Firebase Firestore
- Data Sources: Apple MapKit, OpenStreetMap (via Overpass API), local JSON cache
- Build: Xcode + Swift Package Manager (SPM)

Backends & Services
- Firebase Firestore
  - Purpose: store trips and (optionally) recent location history
  - Security: use Firebase Security Rules; device‑scoped collections recommended
- Speed Limit Providers
  - Local cache (NSCache) and local JSON datasets
  - Apple MapKit (where available)
  - OpenStreetMap / Overpass API for supplemental coverage

APIs & Keys
- Firebase: `GoogleService-Info.plist` in `Fleet Tracker/`
- Apple MapKit: maps & routing via MapKit (bundled entitlement)
- OSM Overpass: HTTP access; see `GOOGLE_ROADS_API_SETUP.md` and OSM notes

Development Environment
- IDE: Xcode 15+
- Target: iOS 16+
- Scheme: `Fleet Tracker` (app target)
- Background Modes: `location`, `background-fetch` (see `Fleet-Tracker-Info.plist`)

Models & Data
- `LocationRecord`: latitude, longitude, timestamp, speed, heading, speedLimit, violations (speed, hardStop, sharpTurn, pothole), etc.
- `Trip`: start/end, locations, distance, speeds, counts of violations, `driverScore`, `fuelUsed`, optional `destination`
- Driver Score:
  - Per‑record score via `calculateDriverScore(for:)`
  - Trip score via `calculateTripDriverScore(for:)` with deductions: speed(5), hard stop(3), sharp turn(2), pothole(1)
  - Dashboard shows average driver score across all trips

Licenses & Terms
- Firebase iOS SDK: Google‑provided; see Firebase license
- gRPC, abseil, leveldb, nanopb, swift‑protobuf: respective OSS licenses
- Apple SDKs (MapKit, CoreLocation, CoreMotion): Apple developer terms
- OpenStreetMap data: ODbL; ensure attribution and compliance

Notable Files
- App entry: `Fleet Tracker/Fleet_TrackerApp.swift`
- Core VM: `Fleet Tracker/LocationViewModel.swift`
- Managers: `Fleet Tracker/MotionManager.swift`, `TripManager.swift`, `LocationManager.swift`
- Services: `Fleet Tracker/UnifiedSpeedLimitService.swift`
- Views: `Fleet Tracker/FleetDashboardView.swift`, `SettingsView.swift`, `TripDetailView.swift`
- Configuration: `Fleet Tracker/ConfigurationManager.swift`, `Fleet-Tracker-Info.plist`

Build & Distribution Notes
- dSYM Uploads: ensure “DWARF with dSYM” and re‑archive before App Store upload
- Background Modes: only valid values (`location`, `background-fetch`)
- Firebase: ensure Firestore is enabled and rules configured

Testing
- Unit tests in `Fleet TrackerTests/` for core utilities and services
- Manual validation via Secret Debug Menu (tap Settings → Version 5×)

Attribution
- OSM contributors (ODbL)
- Firebase, gRPC, abseil, nanopb, swift‑protobuf, leveldb projects


