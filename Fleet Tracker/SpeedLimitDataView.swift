//
//  SpeedLimitDataView.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import SwiftUI
import CoreLocation

struct SpeedLimitDataView: View {
    @State private var isLoading = false
    @State private var dataInfo = (hasData: false, totalRecords: 0, coverage: "No data")
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Data Status
                VStack(alignment: .leading, spacing: 10) {
                    Text("Speed Limit Data")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Image(systemName: dataInfo.hasData ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(dataInfo.hasData ? .green : .orange)
                        
                        Text(dataInfo.coverage)
                            .font(.subheadline)
                    }
                    
                    if dataInfo.hasData {
                        Text("\(dataInfo.totalRecords) speed limit records stored locally")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Action Buttons
                VStack(spacing: 15) {
                    Button(action: downloadDetroitData) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text("Download Detroit Data")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    
                    Button(action: testLocations) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                            Text("Test Detroit Locations")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    
                    if dataInfo.hasData {
                        Button(action: clearData) {
                            HStack {
                                Image(systemName: "trash.circle.fill")
                                Text("Clear Local Data")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading)
                    }
                }
                
                // Information
                VStack(alignment: .leading, spacing: 10) {
                    Text("About Speed Limit Data")
                        .font(.headline)
                    
                    Text("• Download speed limit data from OpenStreetMap")
                    Text("• Data is stored locally for offline access")
                    Text("• Covers Detroit area with high accuracy")
                    Text("• Updates automatically when you drive")
                    
                    Text("Note: First download may take a few minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Speed Limit Data")
            .onAppear {
                updateDataInfo()
            }
            .alert("Speed Limit Data", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func updateDataInfo() {
        dataInfo = SpeedLimitDataManager.shared.getDataInfo()
    }
    
    private func downloadDetroitData() {
        isLoading = true
        
        Task {
            await SpeedLimitDataManager.shared.setupDetroitData()
            
            await MainActor.run {
                isLoading = false
                updateDataInfo()
                alertMessage = "Detroit speed limit data downloaded successfully!"
                showingAlert = true
            }
        }
    }
    
    private func testLocations() {
        SpeedLimitDataManager.shared.testDetroitLocations()
        alertMessage = "Check the console for test results"
        showingAlert = true
    }
    
    private func clearData() {
        let osmService = OSMSpeedLimitService()
        osmService.clearLocalData()
        updateDataInfo()
        alertMessage = "Local speed limit data cleared"
        showingAlert = true
    }
}

#Preview {
    SpeedLimitDataView()
}
