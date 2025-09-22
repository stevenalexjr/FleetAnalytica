# Real Speed Limit Data Setup Guide

This guide shows you how to get real speed limit data for your Fleet Tracker app using various APIs and services.

## 🚀 **Quick Setup Options**

### **Option 1: Google Roads API (Recommended)**

**Pros:**
- Most accurate speed limit data
- Excellent global coverage
- Real-time data
- Easy to implement

**Cons:**
- Requires API key and billing setup
- Costs money per request
- Requires internet connection

#### **Setup Steps:**

1. **Get Google API Key:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one
   - Enable billing (required for Roads API)
   - Go to "APIs & Services" > "Library"
   - Enable "Roads API" and "Maps JavaScript API"

2. **Create API Key:**
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copy your API key

3. **Update Your App:**
   ```swift
   // In LocationViewModel.swift, line 67:
   speedLimitService = SpeedLimitService(googleAPIKey: "YOUR_API_KEY_HERE")
   ```

4. **Test the Integration:**
   - Run your app
   - Drive around and check if speed limits appear
   - Check Xcode console for any API errors

### **Option 2: HERE Maps API**

**Pros:**
- Good alternative to Google
- Competitive pricing
- Good coverage

**Cons:**
- Requires API key and billing
- Different API structure

#### **Setup Steps:**

1. **Get HERE API Key:**
   - Go to [HERE Developer Portal](https://developer.here.com/)
   - Create account and project
   - Get your API key

2. **Implement HERE API:**
   ```swift
   // Add this method to SpeedLimitService.swift
   private func getSpeedLimitFromHERE(for coordinate: CLLocationCoordinate2D) -> Double? {
       guard let apiKey = hereAPIKey else { return nil }
       
       let urlString = "https://route.ls.hereapi.com/routing/7.2/calculateroute.json?waypoint0=\(coordinate.latitude),\(coordinate.longitude)&mode=fastest;car&apikey=\(apiKey)"
       
       // Implement HERE API call similar to Google implementation
       return nil // Placeholder
   }
   ```

### **Option 3: Apple MapKit (iOS 16+)**

**Pros:**
- No additional API key needed
- Integrated with iOS
- Free to use

**Cons:**
- Limited coverage
- Only available in certain regions
- iOS 16+ only

#### **Implementation:**

```swift
// This requires iOS 16+ and complex MapKit integration
// For now, we use the fallback estimation method
```

### **Option 4: OpenStreetMap (Free)**

**Pros:**
- Completely free
- Good for offline use
- Open source

**Cons:**
- Requires local data processing
- More complex implementation
- Data quality varies

## 🔧 **Current Implementation**

Your app currently uses a **location-based estimation** system that provides reasonable speed limits based on:

- **Urban Areas**: 30 mph (city centers, downtown)
- **Suburban Areas**: 40 mph (residential neighborhoods)
- **Rural Areas**: 50 mph (country roads)
- **Highways**: 65 mph (interstates, major highways)

## 📊 **API Comparison**

| Service | Accuracy | Cost | Coverage | Setup Difficulty |
|---------|----------|------|----------|------------------|
| Google Roads | ⭐⭐⭐⭐⭐ | $$$ | Global | Easy |
| HERE Maps | ⭐⭐⭐⭐ | $$ | Global | Medium |
| Apple MapKit | ⭐⭐⭐ | Free | Limited | Hard |
| OpenStreetMap | ⭐⭐ | Free | Variable | Hard |
| Estimation | ⭐ | Free | Global | None |

## 💡 **Recommendations**

### **For Development/Testing:**
- Use the current estimation system
- It's free and works everywhere
- Good enough for testing fleet tracking features

### **For Production:**
- **Google Roads API** for best accuracy
- **HERE Maps API** as a cost-effective alternative
- Keep estimation as fallback for offline scenarios

## 🛠️ **Implementation Tips**

### **Caching:**
The app includes intelligent caching to:
- Reduce API calls
- Improve performance
- Save costs
- Work offline for recently visited locations

### **Error Handling:**
- Graceful fallback to estimation
- Network error handling
- API rate limit management

### **Cost Optimization:**
- Cache results for 24 hours
- Only query when location changes significantly
- Batch requests when possible

## 🚨 **Important Notes**

1. **API Keys Security:**
   - Never commit API keys to version control
   - Use environment variables or secure storage
   - Consider using server-side proxy for production

2. **Rate Limits:**
   - Google Roads API: 2,500 requests/day (free tier)
   - HERE Maps API: 1,000 requests/day (free tier)
   - Implement proper rate limiting in your app

3. **Billing:**
   - Monitor your API usage
   - Set up billing alerts
   - Consider implementing usage limits

## 🔄 **Migration Path**

1. **Start with estimation** (current implementation)
2. **Add Google Roads API** for better accuracy
3. **Implement caching** for cost optimization
4. **Add offline fallback** for reliability
5. **Monitor and optimize** based on usage patterns

## 📱 **Testing**

To test speed limit detection:

1. **Enable location tracking**
2. **Drive around different areas:**
   - City centers (should show ~30 mph)
   - Residential areas (should show ~40 mph)
   - Country roads (should show ~50 mph)
   - Highways (should show ~65 mph)
3. **Check the map overlay** for speed limit display
4. **Verify speed violation detection**

The enhanced speed limit service is now ready to use with real API data when you're ready to set up the Google Roads API!
