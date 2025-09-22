# Xcode Project Setup Guide

This guide will help you configure the Fleet Tracker project in Xcode to resolve the Info.plist conflict and properly set up location permissions.

## Fix Info.plist Conflict

The error you encountered happens because modern Xcode projects automatically generate Info.plist files, and adding a custom one creates a conflict. Here's how to fix it:

### Option 1: Configure Permissions in Project Settings (Recommended)

1. **Open your project in Xcode**
2. **Select your project** in the navigator (the blue "Fleet Tracker" icon at the top)
3. **Select the "Fleet Tracker" target** (under TARGETS)
4. **Go to the "Info" tab**
5. **Add the following keys** by clicking the "+" button:

#### Add Location Permissions:

**Key**: `NSLocationWhenInUseUsageDescription`
**Type**: String
**Value**: `This app needs your location to display your position on the map and track your movement.`

**Key**: `NSLocationAlwaysAndWhenInUseUsageDescription`
**Type**: String
**Value**: `This app needs your location to track your movement even when the app is in the background, providing continuous fleet tracking capabilities.`

### Option 2: Configure Background Modes

1. **Select your project** in the navigator
2. **Select the "Fleet Tracker" target**
3. **Go to the "Signing & Capabilities" tab**
4. **Click "+ Capability"**
5. **Add "Background Modes"**
6. **Check "Location updates"**

## Alternative: Manual Info.plist Configuration

If you prefer to use a custom Info.plist file, follow these steps:

1. **Remove the Info.plist from the project** (if it's still there)
2. **In Xcode, select your project**
3. **Go to Build Settings**
4. **Search for "Info.plist File"**
5. **Set the path to your custom Info.plist** (if you want to use one)

## Verify Configuration

After making these changes:

1. **Clean your project**: Product → Clean Build Folder (⌘+Shift+K)
2. **Build the project**: Product → Build (⌘+B)
3. **Check for errors**: The Info.plist conflict should be resolved

## Firebase Setup Reminder

Don't forget to:

1. **Add Firebase SDK** via Swift Package Manager:
   - File → Add Package Dependencies
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Select: FirebaseCore, FirebaseFirestore

2. **Add GoogleService-Info.plist**:
   - Download from Firebase Console
   - Add to your Xcode project
   - Ensure it's added to the target

3. **Configure Firebase** in `Fleet_TrackerApp.swift` (already done)

## Testing Location Permissions

Once configured:

1. **Run the app on a device** (simulator works but real device is better for GPS)
2. **Grant location permission** when prompted
3. **Test location tracking** functionality
4. **Verify background tracking** works

## Troubleshooting

If you still encounter issues:

1. **Check Build Settings**:
   - Ensure iOS Deployment Target is 15.0 or higher
   - Verify Swift Language Version is Swift 5

2. **Clean and Rebuild**:
   - Product → Clean Build Folder
   - Delete DerivedData folder
   - Rebuild the project

3. **Check Target Membership**:
   - Ensure all source files are added to the correct target
   - Verify GoogleService-Info.plist is included in the target

## Project Structure Verification

Your project should now have:
- ✅ Location permissions configured in project settings
- ✅ Background modes capability enabled
- ✅ Firebase SDK added via Swift Package Manager
- ✅ GoogleService-Info.plist added to project
- ✅ All Swift files properly configured

The app should now build and run without the Info.plist conflict error.
