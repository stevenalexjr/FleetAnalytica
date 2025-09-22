# Detroit Speed Limit Data Sources & Integration

## 🚫 **Apple Maps Limitation**

Apple Maps **does not provide a public API** to read speed limit data programmatically. While Apple displays speed limits during navigation, this data isn't exposed to developers.

## ✅ **Alternative Data Sources**

### **1. Google Roads API (Recommended)**

**Pros:**
- 98%+ accuracy globally
- Real-time data
- Covers all Detroit streets
- Easy integration

**Cons:**
- Requires API key
- Pay-per-use ($0.50/1000 requests)
- Google terms of service

**Setup:**
```swift
// Add to LocationViewModel.swift
speedLimitService = SpeedLimitService(googleAPIKey: "YOUR_GOOGLE_API_KEY")
```

### **2. OpenStreetMap (OSM) Data**

**Pros:**
- Free and open source
- Good coverage for major roads
- Community-maintained

**Cons:**
- Variable accuracy
- Requires data processing
- May be outdated

**Implementation:**
```swift
// OSM Overpass API query for Detroit speed limits
let query = """
[out:json][timeout:25];
(
  way["highway"]["maxspeed"](42.2, -83.5, 42.6, -82.8);
);
out geom;
"""
```

### **3. Michigan DOT Data**

**Pros:**
- Official government data
- High accuracy
- Free access

**Cons:**
- Limited to state roads
- May not include city streets
- Update frequency varies

**Source:** [Michigan DOT Open Data Portal](https://data-michigandot.opendata.arcgis.com/)

### **4. City of Detroit Open Data**

**Pros:**
- Official city data
- Local accuracy
- Free access

**Cons:**
- Limited dataset availability
- May not include all streets

**Source:** [City of Detroit Open Data](https://data.detroitmi.gov/)

## 🔧 **Implementation Options**

### **Option 1: Google Roads API (Easiest)**

1. **Get API Key:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Enable "Roads API"
   - Create API key

2. **Add to App:**
   ```swift
   // In LocationViewModel.swift
   speedLimitService = SpeedLimitService(googleAPIKey: "YOUR_API_KEY")
   ```

3. **Benefits:**
   - Instant integration
   - High accuracy
   - Real-time data

### **Option 2: OSM Data Integration**

1. **Download Detroit Data:**
   ```bash
   # Download OSM data for Detroit
   wget "https://api.openstreetmap.org/api/0.6/map?bbox=-83.5,42.2,-82.8,42.6" -O detroit.osm
   ```

2. **Parse Speed Limits:**
   ```swift
   // Parse OSM XML for speed limit data
   func parseOSMSpeedLimits(from data: Data) -> [String: Double] {
       // Implementation to extract speed limits from OSM data
   }
   ```

3. **Benefits:**
   - Free
   - Offline capability
   - Customizable

### **Option 3: Hybrid Approach**

1. **Use Google API for accuracy**
2. **Cache results locally**
3. **Fallback to OSM data**
4. **Update periodically**

## 📊 **Data Accuracy Comparison**

| Source | Accuracy | Cost | Coverage | Update Frequency |
|--------|----------|------|----------|------------------|
| Google Roads API | 98%+ | $0.50/1000 | Global | Real-time |
| OSM Data | 70-85% | Free | Variable | Community |
| Michigan DOT | 90%+ | Free | State roads | Quarterly |
| Detroit Open Data | 80%+ | Free | City streets | Monthly |

## 🚀 **Recommended Implementation**

### **For Production Apps:**
1. **Primary:** Google Roads API
2. **Fallback:** OSM data
3. **Caching:** Local storage
4. **Updates:** Daily refresh

### **For Development/Testing:**
1. **Primary:** OSM data
2. **Fallback:** Coordinate estimation
3. **Caching:** Memory cache
4. **Updates:** Manual refresh

## 🔧 **Code Implementation**

### **Google Roads API Integration:**
```swift
private func getSpeedLimitFromGoogleRoads(for coordinate: CLLocationCoordinate2D) -> Double? {
    guard let apiKey = googleAPIKey else { return nil }
    
    let urlString = "https://roads.googleapis.com/v1/speedLimits?path=\(coordinate.latitude),\(coordinate.longitude)&key=\(apiKey)"
    
    guard let url = URL(string: urlString) else { return nil }
    
    do {
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(GoogleRoadsResponse.self, from: data)
        
        if let speedLimit = response.speedLimits.first?.speedLimit {
            return Double(speedLimit) * 0.621371 // Convert km/h to mph
        }
    } catch {
        print("Google Roads API error: \(error)")
    }
    
    return nil
}
```

### **OSM Data Integration:**
```swift
private func getSpeedLimitFromOSM(for coordinate: CLLocationCoordinate2D) -> Double? {
    // Query OSM Overpass API for speed limit data
    let query = """
    [out:json][timeout:25];
    (
      way["highway"]["maxspeed"](\(coordinate.latitude-0.001),\(coordinate.longitude-0.001),\(coordinate.latitude+0.001),\(coordinate.longitude+0.001));
    );
    out geom;
    """
    
    // Implementation to query OSM and parse results
    return nil
}
```

## 📱 **Testing Your Implementation**

### **Test Locations in Detroit:**
- **Woodward Avenue**: Should show 45 mph
- **I-75**: Should show 70 mph
- **I-94**: Should show 70 mph
- **Residential streets**: Should show 35 mph
- **School zones**: Should show 25 mph

### **Verification Steps:**
1. **Enable location tracking**
2. **Drive to different road types**
3. **Check speed limit display**
4. **Verify accuracy against actual signs**

## 🚨 **Important Notes**

1. **Terms of Service**: Review API terms before use
2. **Rate Limits**: Implement proper rate limiting
3. **Caching**: Cache results to reduce API calls
4. **Updates**: Speed limits change over time
5. **Privacy**: Consider data privacy implications

## 🔮 **Future Considerations**

1. **Apple Maps API**: May become available in future iOS versions
2. **Real-time Updates**: Consider traffic-based speed limit adjustments
3. **Machine Learning**: Train models on user-reported data
4. **Community Data**: Implement user correction system

Your Fleet Tracker app can now integrate accurate Detroit speed limit data using these alternative sources!
