//
//  MapView.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import SwiftUI
import MapKit
import Combine

struct MapView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingLocationHistory = false
    @State private var showingDestinationInput = false
    @State private var showingNavigationDetails = false
    @State private var showingRoutePreferences = false
    @State private var showingEnhancedSearch = false
    @State private var destinationText = ""
    @State private var showingSpeedViolationAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Map view with route support
            MapWithRoute(
                coordinateRegion: $mapRegion,
                annotationItems: annotationItems,
                route: locationViewModel.route,
                trackingIsActive: locationViewModel.trackingIsActive
            )
            .frame(maxHeight: .infinity)
            .onReceive(locationViewModel.$currentCoordinate) { coordinate in
                if let coordinate = coordinate {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        mapRegion.center = coordinate
                    }
                }
            }
            .overlay(
                // Location status overlay
                VStack {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            if let coordinate = locationViewModel.currentCoordinate {
                                Text("Lat: \(coordinate.latitude, specifier: "%.6f")")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                
                                Text("Lon: \(coordinate.longitude, specifier: "%.6f")")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            if locationViewModel.trackingIsActive {
                                HStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Tracking")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                            }
                            
                            // Speed and Speed Limit Display
                            if let speedLimit = locationViewModel.speedLimit {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Int(locationViewModel.currentSpeed)) mph")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(locationViewModel.speedViolation ? .red : .white)
                                    
                                    Text("Limit: \(Int(speedLimit)) mph")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    
                                    // Show speed limit source
                                    Text({
                                        let dataInfo = SpeedLimitDataManager.shared.getDataInfo()
                                        if dataInfo.hasData {
                                            return "OSM Local"
                                        } else {
                                            return "OSM Live"
                                        }
                                    }())
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                            }
                            
                            // Navigation Instructions
                            if locationViewModel.isNavigating && !locationViewModel.navigationInstructions.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Navigation")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    
                                    Text(locationViewModel.navigationInstructions.first ?? "Follow route")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                    Spacer()
                }
            )
            .overlay(alignment: .bottom) {
                // Bottom navigation banner
                if locationViewModel.isNavigating {
                    NavigationBannerView()
                        .environmentObject(locationViewModel)
                }
            }
            
            // Control panel
            VStack(spacing: 12) {
                // Tracking status and error messages
                if let error = locationViewModel.locationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Control buttons
                HStack(spacing: 20) {
                    
                    // Consolidated Navigation button
                    if locationViewModel.isNavigating {
                        Button(action: {
                            showingNavigationDetails = true
                        }) {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Directions")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            locationViewModel.stopNavigation()
                        }) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("Stop")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            showingDestinationInput = true
                        }) {
                            HStack {
                                Image(systemName: "location.magnifyingglass")
                                Text("Navigate")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    
                    if locationViewModel.authorizationStatus == .authorizedWhenInUse {
                        Button(action: {
                            locationViewModel.requestAlwaysPermission()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Background")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(10)
                        }
                    }
                }
                
                // Additional controls
                HStack(spacing: 20) {
                    Button(action: {
                        showingLocationHistory = true
                    }) {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text("History")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showingRoutePreferences = true
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Route Options")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showingEnhancedSearch = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                }
                
                // Trip status indicator (simplified)
                if locationViewModel.currentTrip != nil {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Trip Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
        .sheet(isPresented: $showingLocationHistory) {
            LocationHistoryView()
                .environmentObject(locationViewModel)
        }
        .sheet(isPresented: $showingDestinationInput) {
            DestinationInputView(destinationText: $destinationText) {
                locationViewModel.setDestination(destinationText)
                locationViewModel.getDirections(to: destinationText)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showingNavigationDetails) {
            NavigationDetailsView()
                .environmentObject(locationViewModel)
        }
        .sheet(isPresented: $showingRoutePreferences) {
            RoutePreferencesView()
                .environmentObject(locationViewModel)
        }
        .sheet(isPresented: $showingEnhancedSearch) {
            EnhancedSearchView()
                .environmentObject(locationViewModel)
        }
        .alert("Location Permission Required", isPresented: .constant(locationViewModel.authorizationStatus == .denied || locationViewModel.authorizationStatus == .restricted)) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location access in Settings for the app to track your location.")
        }
        .alert("Speed Violation Detected", isPresented: $showingSpeedViolationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let speedLimit = locationViewModel.speedLimit {
                let overSpeed = Int(locationViewModel.currentSpeed - speedLimit)
                Text("You are going \(overSpeed) mph over the speed limit of \(Int(speedLimit)) mph.")
            } else {
                Text("You are exceeding the speed limit.")
            }
        }
        .onReceive(locationViewModel.$speedViolation) { isViolating in
            if isViolating {
                showingSpeedViolationAlert = true
            }
        }
    }
    
    private var annotationItems: [LocationAnnotation] {
        guard let coordinate = locationViewModel.currentCoordinate else { return [] }
        return [LocationAnnotation(coordinate: coordinate)]
    }
}

struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct LocationHistoryView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if locationViewModel.trips.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Trips Yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Start tracking to see your driving history")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(locationViewModel.trips.sorted(by: { $0.startTime > $1.startTime })) { trip in
                        TripHistoryRow(trip: trip)
                    }
                }
            }
            .navigationTitle("Trip History")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationViewModel.loadTrips()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh") {
                        locationViewModel.loadTrips()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TripHistoryRow: View {
    let trip: Trip
    
    private var hasUnsafeDriving: Bool {
        trip.speedViolations > 0 || trip.hardStops > 0 || trip.sharpTurns > 0 || trip.potholesDetected > 0
    }
    
    private var unsafeDrivingCount: Int {
        trip.speedViolations + trip.hardStops + trip.sharpTurns + trip.potholesDetected
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trip header with status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.startTime, style: .date)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(trip.startTime, style: .time) - \(trip.endTime?.formatted(date: .omitted, time: .shortened) ?? "Ongoing")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let destination = trip.destination {
                        Text("To: \(destination)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Status indicator
                if hasUnsafeDriving {
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        Text("\(unsafeDrivingCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("Clean")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Trip metrics
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Distance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", trip.totalDistance / 1609.34)) mi")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let endTime = trip.endTime {
                        let duration = endTime.timeIntervalSince(trip.startTime)
                        Text("\(Int(duration / 60)) min")
                            .font(.caption)
                            .fontWeight(.medium)
                    } else {
                        Text("Ongoing")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(trip.driverScore))/100")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(trip.driverScore >= 80 ? .green : trip.driverScore >= 60 ? .orange : .red)
                }
                
                Spacer()
            }
            
            // Unsafe driving details (only show if there are violations)
            if hasUnsafeDriving {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unsafe Driving Notifications")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        if trip.speedViolations > 0 {
                            UnsafeDrivingBadge(
                                icon: "speedometer",
                                label: "Speed",
                                count: trip.speedViolations,
                                color: .red
                            )
                        }
                        
                        if trip.hardStops > 0 {
                            UnsafeDrivingBadge(
                                icon: "stop.circle",
                                label: "Hard Stops",
                                count: trip.hardStops,
                                color: .orange
                            )
                        }
                        
                        if trip.sharpTurns > 0 {
                            UnsafeDrivingBadge(
                                icon: "arrow.turn.up.right",
                                label: "Sharp Turns",
                                count: trip.sharpTurns,
                                color: .purple
                            )
                        }
                        
                        if trip.potholesDetected > 0 {
                            UnsafeDrivingBadge(
                                icon: "exclamationmark.triangle",
                                label: "Potholes",
                                count: trip.potholesDetected,
                                color: .brown
                            )
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
    }
}

struct UnsafeDrivingBadge: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct DestinationInputView: View {
    @Binding var destinationText: String
    let onNavigate: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationViewModel: LocationViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter your destination")
                .font(.headline)
                .padding(.top)
            
            VStack(spacing: 8) {
                TextField("Destination address or landmark", text: $destinationText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .focused($isTextFieldFocused)
                    .onAppear {
                        // Focus immediately without async to prevent XPC issues
                        isTextFieldFocused = true
                    }
                    .onChange(of: destinationText) { newValue in
                        // Search for address suggestions as user types
                        locationViewModel.searchAddresses(query: newValue)
                    }
                    .onSubmit {
                        // Handle return key press
                        if !destinationText.isEmpty {
                            dismissKeyboardAndNavigate()
                        }
                    }
                
                // Address suggestions - optimized for performance
                if !locationViewModel.addressSuggestions.isEmpty {
                    AddressSuggestionsList(
                        suggestions: locationViewModel.addressSuggestions,
                        onSelect: { mapItem in
                            locationViewModel.selectAddress(mapItem)
                            destinationText = mapItem.name ?? mapItem.placemark.title ?? "Selected Location"
                        }
                    )
                }
                
                // Loading indicator for address search
                if locationViewModel.isSearchingAddresses {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching addresses...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
            
            Button("Get Directions") {
                dismissKeyboardAndNavigate()
            }
            .disabled(destinationText.isEmpty)
            .foregroundColor(.white)
            .padding()
            .background(destinationText.isEmpty ? Color.gray : Color.blue)
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Navigation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismissKeyboard()
                }
            }
        }
        .onDisappear {
            // Cancel any ongoing address searches when view disappears
            locationViewModel.cancelAddressSearch()
        }
    }
    
    private func dismissKeyboardAndNavigate() {
        // Prevent multiple simultaneous operations
        guard !isProcessing else { return }
        isProcessing = true
        
        // Single function to handle keyboard dismissal and navigation
        isTextFieldFocused = false
        
        // Small delay to ensure keyboard dismissal completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onNavigate()
            self.dismiss()
        }
    }
    
    private func dismissKeyboard() {
        // Prevent multiple simultaneous operations
        guard !isProcessing else { return }
        isProcessing = true
        
        // Simple keyboard dismissal
        isTextFieldFocused = false
        
        // Small delay to ensure keyboard dismissal completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.dismiss()
        }
    }
}

// MARK: - Navigation Details View

struct NavigationDetailsView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Route summary header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("To: \(locationViewModel.destination)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(String(format: "%.1f", locationViewModel.routeDistance)) miles • \(Int(locationViewModel.routeDuration / 60)) min")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Stop Navigation") {
                            locationViewModel.stopNavigation()
                            dismiss()
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                
                // Current step highlight
                if let currentStep = locationViewModel.getCurrentNavigationStep() {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("Current Step")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        
                        Text(currentStep)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Turn-by-turn directions
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(locationViewModel.navigationInstructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 12) {
                                // Step number indicator
                                ZStack {
                                    Circle()
                                        .fill(index == locationViewModel.currentStepIndex ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(index == locationViewModel.currentStepIndex ? .white : .primary)
                                }
                                
                                // Instruction text
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(instruction)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    
                                    if let route = locationViewModel.route, index < route.steps.count {
                                        Text("\(String(format: "%.1f", route.steps[index].distance / 1609.34)) miles")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(index == locationViewModel.currentStepIndex ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Turn-by-Turn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Navigation Banner View

struct NavigationBannerView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Current step
            if let currentStep = locationViewModel.getCurrentNavigationStep() {
                HStack(spacing: 12) {
                    // Navigation icon
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    // Current instruction
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(currentStep)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Progress indicator
                    VStack(spacing: 4) {
                        Text("Step")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(locationViewModel.currentStepIndex + 1)/\(locationViewModel.navigationInstructions.count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    // Next step preview button
                    Button(action: {
                        // Could show next step or full directions
                    }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // Route progress bar
            if let route = locationViewModel.route {
                VStack(spacing: 4) {
                    HStack {
                        Text("Route Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", locationViewModel.routeDistance)) mi • \(Int(locationViewModel.routeDuration / 60)) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * CGFloat(locationViewModel.currentStepIndex) / CGFloat(locationViewModel.navigationInstructions.count), height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color(UIColor.systemBackground).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
    }
}

// MARK: - Map with Route Support

struct MapWithRoute: UIViewRepresentable {
    @Binding var coordinateRegion: MKCoordinateRegion
    let annotationItems: [LocationAnnotation]
    let route: MKRoute?
    let trackingIsActive: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Disable user location to prevent PPS/Maps usage tracking
        mapView.showsUserLocation = false
        mapView.userTrackingMode = .none
        
        // Disable unnecessary features that cause XPC connection issues
        mapView.showsBuildings = false
        mapView.showsPointsOfInterest = false
        mapView.showsTraffic = false
        mapView.showsScale = false
        mapView.showsCompass = false
        
        // Use standard map type to avoid additional services
        mapView.mapType = .standard
        
        // Optimize for performance
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region only if it has changed significantly
        let currentRegion = mapView.region
        let regionChanged = abs(currentRegion.center.latitude - coordinateRegion.center.latitude) > 0.001 ||
                           abs(currentRegion.center.longitude - coordinateRegion.center.longitude) > 0.001 ||
                           abs(currentRegion.span.latitudeDelta - coordinateRegion.span.latitudeDelta) > 0.001 ||
                           abs(currentRegion.span.longitudeDelta - coordinateRegion.span.longitudeDelta) > 0.001
        
        if regionChanged {
            mapView.setRegion(coordinateRegion, animated: true)
        }
        
        // Update annotations only if they have changed
        let currentAnnotations = mapView.annotations.compactMap { $0 as? MKPointAnnotation }
        var newAnnotations = annotationItems.map { item in
            let annotation = MKPointAnnotation()
            annotation.coordinate = item.coordinate
            annotation.title = "Current Location"
            return annotation
        }
        
        // Add a custom user location annotation
        let userLocationAnnotation = MKPointAnnotation()
        userLocationAnnotation.coordinate = coordinateRegion.center
        userLocationAnnotation.title = "Your Location"
        newAnnotations.append(userLocationAnnotation)
        
        // Only update if annotations have changed
        if currentAnnotations.count != newAnnotations.count ||
           !currentAnnotations.elementsEqual(newAnnotations, by: { $0.coordinate.latitude == $1.coordinate.latitude && $0.coordinate.longitude == $1.coordinate.longitude }) {
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotations(newAnnotations)
        }
        
        // Update route only if it has changed
        let currentOverlays = mapView.overlays
        if let route = route {
            let hasRouteOverlay = currentOverlays.contains { $0 is MKPolyline }
            if !hasRouteOverlay {
                mapView.removeOverlays(mapView.overlays)
                mapView.addOverlay(route.polyline)
                
                // Fit map to show entire route
                let rect = route.polyline.boundingMapRect
                let insets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
                mapView.setVisibleMapRect(rect, edgePadding: insets, animated: true)
            }
        } else if !currentOverlays.isEmpty {
            mapView.removeOverlays(mapView.overlays)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapWithRoute
        
        init(_ parent: MapWithRoute) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "LocationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Create custom annotation view
            let imageView = UIImageView()
            imageView.image = UIImage(systemName: "location.circle.fill")
            imageView.tintColor = .blue
            imageView.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            imageView.backgroundColor = .white
            imageView.layer.cornerRadius = 15
            
            if parent.trackingIsActive {
                let trackingView = UIImageView()
                trackingView.image = UIImage(systemName: "dot.circle.fill")
                trackingView.tintColor = .green
                trackingView.frame = CGRect(x: 20, y: 20, width: 15, height: 15)
                trackingView.backgroundColor = .white
                trackingView.layer.cornerRadius = 7.5
                imageView.addSubview(trackingView)
            }
            
            annotationView?.addSubview(imageView)
            annotationView?.frame = imageView.frame
            
            return annotationView
        }
    }
    
}

// MARK: - Optimized Address Suggestions Component

struct AddressSuggestionsList: View {
    let suggestions: [MKMapItem]
    let onSelect: (MKMapItem) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(suggestions.prefix(5).enumerated()), id: \.offset) { index, mapItem in
                    AddressSuggestionRow(mapItem: mapItem) {
                        onSelect(mapItem)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: 200)
    }
}

struct AddressSuggestionRow: View {
    let mapItem: MKMapItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "location.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mapItem.name ?? "Unknown Location")
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let address = mapItem.placemark.title {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Route Preferences View

struct RoutePreferencesView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Route Preferences") {
                    Toggle("Request Alternate Routes", isOn: $locationViewModel.routePreferences.requestsAlternateRoutes)
                }
                
                Section("Transport Type") {
                    Picker("Transport Type", selection: $locationViewModel.routePreferences.transportTypeRaw) {
                        Text("Automobile").tag(MKDirectionsTransportType.automobile.rawValue)
                        Text("Walking").tag(MKDirectionsTransportType.walking.rawValue)
                        Text("Transit").tag(MKDirectionsTransportType.transit.rawValue)
                    }
                    .pickerStyle(.segmented)
                }
                
                if !locationViewModel.availableRoutes.isEmpty {
                    Section("Available Routes") {
                        ForEach(Array(locationViewModel.availableRoutes.enumerated()), id: \.offset) { index, route in
                            RouteOptionRow(
                                route: route,
                                index: index,
                                isSelected: index == locationViewModel.selectedRouteIndex,
                                onSelect: {
                                    locationViewModel.selectRoute(at: index)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Route Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RouteOptionRow: View {
    let route: MKRoute
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var distance: Double {
        route.distance / 1609.34 // Convert to miles
    }
    
    private var duration: TimeInterval {
        route.expectedTravelTime / 60 // Convert to minutes
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Route \(index + 1)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(String(format: "%.1f", distance)) miles • \(String(format: "%.0f", duration)) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Search View

struct EnhancedSearchView: View {
    @EnvironmentObject var locationViewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: LocationViewModel.SearchCategory? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(LocationViewModel.SearchCategory.allCases, id: \.self) { category in
                            CategoryButton(
                                category: category,
                                isSelected: selectedCategory == category,
                                onTap: {
                                    selectedCategory = category
                                    locationViewModel.searchNearby(category: category)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Search Results
                if locationViewModel.isSearchingNearby {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !locationViewModel.searchResults.isEmpty {
                    List(locationViewModel.searchResults, id: \.self) { mapItem in
                        SearchResultRow(mapItem: mapItem) {
                            locationViewModel.selectAddress(mapItem)
                            dismiss()
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Select a category to search nearby")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Search Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CategoryButton: View {
    let category: LocationViewModel.SearchCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(category.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchResultRow: View {
    let mapItem: MKMapItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "location.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mapItem.name ?? "Unknown Location")
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let address = mapItem.placemark.title {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MapView()
        .environmentObject(LocationViewModel())
}
