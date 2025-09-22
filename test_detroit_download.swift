#!/usr/bin/env swift

import Foundation
import CoreLocation

// Simple test script to download Detroit speed limit data
// Run with: swift test_detroit_download.swift

print("🚀 Starting Detroit Speed Limit Data Download Test...")

// Simulate the download process
let detroitCenter = CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458)
let radius = 5000.0 // 5km radius

print("📍 Downloading data for Detroit area:")
print("   Center: \(detroitCenter.latitude), \(detroitCenter.longitude)")
print("   Radius: \(radius) meters")

// Simulate the Overpass API query
let query = """
[out:json][timeout:25];
(
  way["maxspeed"](around:\(radius),\(detroitCenter.latitude),\(detroitCenter.longitude));
  relation["maxspeed"](around:\(radius),\(detroitCenter.latitude),\(detroitCenter.longitude));
);
out geom;
"""

print("\n📝 Overpass API Query:")
print(query)

print("\n🌐 Making request to OpenStreetMap Overpass API...")
print("   URL: https://overpass-api.de/api/interpreter")

// Simulate the request
let urlString = "https://overpass-api.de/api/interpreter"
guard let url = URL(string: urlString) else {
    print("❌ Invalid URL")
    exit(1)
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
request.httpBody = query.data(using: .utf8)

print("📤 Sending POST request with query...")

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        print("❌ Network error: \(error.localizedDescription)")
        return
    }
    
    guard let httpResponse = response as? HTTPURLResponse else {
        print("❌ Invalid HTTP response")
        return
    }
    
    print("📊 HTTP Status: \(httpResponse.statusCode)")
    
    if let data = data {
        print("📥 Received \(data.count) bytes of data")
        
        // Try to parse as JSON
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let elements = json["elements"] as? [[String: Any]] {
                print("✅ Successfully parsed \(elements.count) elements")
                
                var speedLimitCount = 0
                for element in elements {
                    if let tags = element["tags"] as? [String: String],
                       let _ = tags["maxspeed"] {
                        speedLimitCount += 1
                    }
                }
                
                print("🎯 Found \(speedLimitCount) speed limit records")
                
                if speedLimitCount > 0 {
                    print("✅ Detroit speed limit data download successful!")
                    print("💾 Data can now be stored locally for offline access")
                } else {
                    print("⚠️  No speed limit data found for this area")
                }
            } else {
                print("❌ Failed to parse JSON response")
            }
        } catch {
            print("❌ JSON parsing error: \(error)")
        }
    } else {
        print("❌ No data received")
    }
    
    exit(0)
}

task.resume()

// Keep the script running
RunLoop.main.run()
