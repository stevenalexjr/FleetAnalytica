# Firebase Setup Guide for Fleet Tracker

This guide will walk you through setting up Firebase for the Fleet Tracker iOS app.

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `Fleet Tracker`
4. Enable Google Analytics (recommended)
5. Choose Analytics account (or create new one)
6. Click "Create project"

## Step 2: Add iOS App to Firebase

1. In your Firebase project dashboard, click the iOS icon
2. Enter iOS bundle ID: `com.yourcompany.Fleet-Tracker`
   - **Important**: Replace `yourcompany` with your actual company/developer name
   - You can find your bundle ID in Xcode: Project Settings > General > Bundle Identifier
3. Enter App nickname: `Fleet Tracker iOS`
4. Enter App Store ID (optional, leave blank for now)
5. Click "Register app"

## Step 3: Download Configuration File

1. Download `GoogleService-Info.plist`
2. **Important**: Do not rename this file
3. In Xcode:
   - Right-click on "Fleet Tracker" folder in the project navigator
   - Select "Add Files to Fleet Tracker"
   - Choose the downloaded `GoogleService-Info.plist`
   - Make sure "Add to target" is checked for "Fleet Tracker"
   - Click "Add"

## Step 4: Add Firebase SDK via Swift Package Manager

1. In Xcode, go to **File > Add Package Dependencies**
2. Enter this URL: `https://github.com/firebase/firebase-ios-sdk`
3. Click "Add Package"
4. Select these products:
   - ✅ FirebaseCore
   - ✅ FirebaseFirestore
   - ✅ FirebaseAuth (optional, for future user authentication)
5. Click "Add Package"

## Step 5: Enable Firestore Database

1. In Firebase Console, go to **Firestore Database**
2. Click **"Create database"**
3. Choose **"Start in test mode"** (for development)
   - **Warning**: This allows anyone to read/write to your database
   - We'll secure it later for production
4. Select a location for your database (choose closest to your users)
5. Click **"Done"**

## Step 6: Configure Firestore Security Rules (Development)

For development, you can use these permissive rules:

1. In Firebase Console, go to **Firestore Database > Rules**
2. Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

3. Click **"Publish"**

⚠️ **Important**: These rules allow anyone to read/write your database. Only use for development!

## Step 7: Test Firebase Connection

1. Build and run your app in Xcode
2. Grant location permission when prompted
3. Start location tracking
4. Check Firebase Console > Firestore Database > Data
5. You should see a "locations" collection with your location data

## Step 8: Production Security Rules

When ready for production, update your Firestore rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /locations/{document} {
      // Allow read/write only for authenticated users
      allow read, write: if request.auth != null;
      
      // Or for anonymous access with device validation:
      // allow read, write: if resource.data.deviceId == request.auth.uid;
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **"Firebase not configured" error**:
   - Ensure `GoogleService-Info.plist` is added to your Xcode project
   - Check that the file is included in your app target
   - Verify the bundle ID matches between Firebase and Xcode

2. **"Permission denied" in Firestore**:
   - Check your Firestore security rules
   - Ensure you're using the correct rules for your development/production environment

3. **Location data not appearing in Firebase**:
   - Check Xcode console for error messages
   - Verify location permissions are granted
   - Ensure Firebase SDK is properly imported

4. **Build errors with Firebase**:
   - Clean your project (Product > Clean Build Folder)
   - Check that Firebase packages are properly added
   - Verify iOS deployment target is 12.0 or higher

### Verification Checklist

- [ ] Firebase project created
- [ ] iOS app added to Firebase project
- [ ] `GoogleService-Info.plist` downloaded and added to Xcode project
- [ ] Firebase SDK packages added via Swift Package Manager
- [ ] Firestore database created
- [ ] Security rules configured
- [ ] App builds and runs without errors
- [ ] Location data appears in Firestore

## Next Steps

Once Firebase is set up:

1. **Test location tracking** on a physical device
2. **Verify data persistence** in Firestore
3. **Test background tracking** functionality
4. **Configure production security rules**
5. **Set up Firebase Analytics** (optional)

## Support

If you encounter issues:

1. Check the [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
2. Review [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
3. Check Xcode console for specific error messages
4. Ensure all steps above are completed correctly
