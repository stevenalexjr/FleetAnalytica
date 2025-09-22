#!/usr/bin/env swift

import Foundation

// Test script for Google Roads API
// Run with: swift test_google_api.swift

struct GoogleAPITest {
    static func testSpeedLimitAPI(apiKey: String, latitude: Double, longitude: Double) {
        let urlString = "https://roads.googleapis.com/v1/speedLimits?path=\(latitude),\(longitude)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }
        
        print("🔍 Testing Google Roads API...")
        print("📍 Location: \(latitude), \(longitude)")
        print("🌐 URL: \(urlString)")
        print()
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ Response received:")
                    print(prettyPrintJSON(json))
                    
                    if let speedLimits = json["speedLimits"] as? [[String: Any]],
                       let firstLimit = speedLimits.first,
                       let speedLimit = firstLimit["speedLimit"] as? Int {
                        let mph = Double(speedLimit) * 0.621371 // Convert km/h to mph
                        print()
                        print("🚗 Speed Limit: \(speedLimit) km/h (\(String(format: "%.1f", mph)) mph)")
                    } else {
                        print("⚠️  No speed limit data found")
                    }
                } else {
                    print("❌ Invalid JSON response")
                    print(String(data: data, encoding: .utf8) ?? "No data")
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                print(String(data: data, encoding: .utf8) ?? "No data")
            }
        }
        
        task.resume()
        
        // Wait for response
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))
    }
    
    static func prettyPrintJSON(_ json: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "Invalid JSON"
        }
        return string
    }
}

// Test locations in Detroit
let testLocations = [
    ("Woodward Avenue", 42.3314, -83.0458),
    ("I-75 Freeway", 42.3314, -83.0458),
    ("Downtown Detroit", 42.3314, -83.0458),
    ("Residential Street", 42.3314, -83.0458)
]

// Get API key from command line or environment
let apiKey = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ProcessInfo.processInfo.environment["GOOGLE_ROADS_API_KEY"] ?? ""

if apiKey.isEmpty {
    print("❌ Please provide your Google Roads API key:")
    print("   swift test_google_api.swift YOUR_API_KEY")
    print("   or set GOOGLE_ROADS_API_KEY environment variable")
    exit(1)
}

print("🚀 Google Roads API Test")
print("🔑 API Key: \(String(apiKey.prefix(10)))...")
print()

for (name, lat, lon) in testLocations {
    print("📍 Testing: \(name)")
    GoogleAPITest.testSpeedLimitAPI(apiKey: apiKey, latitude: lat, longitude: lon)
    print("---")
}
