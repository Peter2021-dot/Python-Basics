# Firestore Database Setup Guide

## Overview
This guide explains how to set up your Firestore database for the WETHERE journey application system. The system allows users to create journeys, apply to journeys, and manage their applications.

## Collections Structure

### 1. `journeys` Collection
Stores all journey posts created by users.

**Document Structure:**
```javascript
{
  // Host Information
  "hostUserId": "string",           // Firebase Auth UID of the journey creator
  "hostName": "string",             // Display name of the host
  "hostAvatar": "string | null",    // URL to host's avatar image
  
  // Basic Information
  "title": "string",                // Journey title (e.g., "Join me for groceries shopping")
  "description": "string",          // Detailed description
  "imageUrl": "string",             // URL to journey image
  
  // Location
  "location": "string",             // Location name (e.g., "Costco in Union, NJ")
  "meetingPoint": "string",         // Specific meeting point
  "locationCoordinates": {          // GeoPoint (optional)
    "_latitude": 40.7128,
    "_longitude": -74.0060
  },
  
  // Timing
  "date": "timestamp",              // Journey date
  "startTime": "timestamp",         // Start time
  "endTime": "timestamp",           // End time
  "duration": 2,                    // Duration in hours (number)
  
  // Compensation
  "compensationType": "string",     // One of: "hourlyPay", "freeItem", "coveredExpense", "companionChoice"
  "hourlyRate": 15,                 // Number (optional, for hourlyPay and companionChoice)
  "freeItemDesc": "string",         // Description (optional, for freeItem and companionChoice)
  "freeItemEmoji": "🎫",           // Emoji (optional)
  "coveredExpenseDesc": "string",   // Description (optional, for coveredExpense)
  "coveredExpenseEmoji": "🍽️",    // Emoji (optional)
  
  // Status & Capacity
  "status": "string",               // One of: "open", "filled", "completed", "cancelled"
  "maxCompanions": 1,               // Number of companions needed
  "currentApplicants": 0,           // Current number of applicants
  "acceptedCompanionId": "string",  // UID of accepted companion (optional)
  
  // Metadata
  "createdAt": "timestamp",         // When journey was created
  "updatedAt": "timestamp",         // Last update time
  "views": 0,                       // View count (number)
  
  // Searchability
  "tags": ["shopping", "groceries"], // Array of strings
  "city": "Union",                  // City name
  "state": "NJ"                     // State code (optional)
}
```

### 2. `applications` Collection
Stores all applications from users to journeys.

**Document Structure:**
```javascript
{
  "journeyId": "string",            // Document ID from journeys collection
  "journeyTitle": "string",         // Title of the journey (for quick reference)
  "userId": "string",               // Firebase Auth UID of the applicant
  "userName": "string",             // Display name of the applicant
  "hostUserId": "string",           // Firebase Auth UID of the journey host
  "rewardChoice": "string | null",  // For companionChoice: "hourly" or "freeItem"
  "status": "string",               // One of: "applied", "accepted", "rejected", "cancelled"
  "createdAt": "timestamp"          // When application was submitted
}
```

## Firestore Security Rules

Add these security rules to your Firestore to ensure proper access control:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isSignedIn() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns a document
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    // Journeys Collection
    match /journeys/{journeyId} {
      // Anyone can read journeys
      allow read: if true;
      
      // Only authenticated users can create journeys
      allow create: if isSignedIn() 
                    && request.resource.data.hostUserId == request.auth.uid;
      
      // Only the host can update or delete their journey
      allow update, delete: if isOwner(resource.data.hostUserId);
    }
    
    // Applications Collection
    match /applications/{applicationId} {
      // Users can read their own applications (as applicant or host)
      allow read: if isSignedIn() 
                  && (request.auth.uid == resource.data.userId 
                      || request.auth.uid == resource.data.hostUserId);
      
      // Only authenticated users can create applications
      allow create: if isSignedIn() 
                    && request.resource.data.userId == request.auth.uid;
      
      // Applicants can update their own applications (e.g., cancel)
      // Hosts can update applications to their journeys (e.g., accept/reject)
      allow update: if isSignedIn() 
                    && (request.auth.uid == resource.data.userId 
                        || request.auth.uid == resource.data.hostUserId);
      
      // Only the applicant can delete their application
      allow delete: if isOwner(resource.data.userId);
    }

    // Chats Collection
    match /chats/{chatId} {
      // Allow read/update if user is a participant
      allow read, update: if isSignedIn() && resource.data.participants.hasAny([request.auth.uid]);
      // Allow create if user is in the participants list
      allow create: if isSignedIn() 
                    && request.resource.data.participants.hasAny([request.auth.uid]);

      // Messages Subcollection
      match /messages/{messageId} {
        // Allow read/write if the user is a participant of the parent chat
        // Note: For create, we check if the user is a participant of the chat document
        allow read, create: if isSignedIn() && 
          get(/databases/$(database)/documents/chats/$(chatId)).data.participants.hasAny([request.auth.uid]);
      }
    }

    // Reviews Collection
    match /reviews/{reviewId} {
      allow read: if true; // Anyone can read reviews
      allow create: if isSignedIn() && request.resource.data.reviewerId == request.auth.uid;
      // No updates allowed to reviews to prevent tampering
    }

    // Users Collection
    match /users/{userId} {
      allow read: if true;
      // Allow user to update their own profile
      allow update: if isOwner(userId);
      // Allow creation during sign up
      allow create: if isOwner(userId);
      
      // SPECIAL: Allow any authenticated user to update rating metrics (for reviews)
      // This allows updating ONLY 'rating' and 'reviewsCount' fields
      allow update: if isSignedIn() 
                    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['rating', 'reviewsCount']);
    }
  }
}
```

## Firestore Indexes

Create these composite indexes for optimal query performance:

### Index 1: Open Journeys by Creation Date
- **Collection:** `journeys`
- **Fields:**
  - `status` (Ascending)
  - `createdAt` (Descending)

### Index 2: Open Journeys by Start Time
- **Collection:** `journeys`
- **Fields:**
  - `status` (Ascending)
  - `startTime` (Ascending)

### Index 3: Open Journeys by Hourly Rate
- **Collection:** `journeys`
- **Fields:**
  - `status` (Ascending)
  - `hourlyRate` (Descending)

### Index 4: User's Created Journeys
- **Collection:** `journeys`
- **Fields:**
  - `hostUserId` (Ascending)
  - `createdAt` (Descending)

### Index 5: User's Active Journeys
- **Collection:** `journeys`
- **Fields:**
  - `hostUserId` (Ascending)
  - `status` (Ascending)
  - `createdAt` (Descending)

### Index 6: User's Past Journeys
- **Collection:** `journeys`
- **Fields:**
  - `hostUserId` (Ascending)
  - `updatedAt` (Descending)

### Index 7: Applications by User
- **Collection:** `applications`
- **Fields:**
  - `userId` (Ascending)
  - `createdAt` (Descending)

### Index 8: Applications by Journey
- **Collection:** `applications`
- **Fields:**
  - `journeyId` (Ascending)
  - `createdAt` (Descending)

### Index 9: User's Chats (Inbox)
- **Collection:** `chats`
- **Fields:**
  - `participants` (Arrays)
  - `updatedAt` (Descending)

## How to Create Indexes

### Method 1: Automatic (Recommended)
1. Run your app and perform the queries
2. Firebase will show error messages with links to create the required indexes
3. Click the links to automatically create the indexes

### Method 2: Manual
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Enter the collection name and fields as listed above
4. Click "Create"

## Testing Your Setup

After setting up the collections and indexes, test the following:

1. **Create a Journey:**
   - Navigate to "My Journeys" tab
   - Click "+ Create"
   - Fill out the form and submit
   - Verify the journey appears in Firestore

2. **View Journeys:**
   - Go to "Explore" tab
   - Verify journeys are loading
   - Test filters and sorting

3. **Apply to a Journey:**
   - Click "APPLY" on any journey
   - For "Companion's Choice" journeys, select a reward option
   - Verify application appears in Firestore `applications` collection

4. **View Applications:**
   - Go to "My Journeys" → "Applied" tab
   - Verify your applications appear

5. **View Created Journeys:**
   - Go to "My Journeys" → "Created" tab
   - Verify journeys you created appear

## Common Issues

### Issue: "Missing or insufficient permissions"
**Solution:** Check your Firestore security rules are correctly set up as shown above.

### Issue: "PERMISSION_DENIED: Missing or insufficient permissions"
**Solution:** Make sure the user is authenticated with Firebase Auth before trying to create/apply to journeys.

### Issue: Queries are slow
**Solution:** Create the composite indexes listed above.

### Issue: "whereIn" query limit exceeded
**Solution:** This happens when a user has applied to more than 10 journeys. The code handles this gracefully, but you may want to implement pagination for users with many applications.

## Next Steps

1. Set up Firebase Authentication if you haven't already
2. Create the Firestore collections (they'll be created automatically when you add the first document)
3. Add the security rules
4. Create the composite indexes
5. Test the application flow

## Support

If you encounter any issues:
1. Check the Flutter console for error messages
2. Check Firebase Console → Firestore → Usage tab for quota issues
3. Verify your security rules allow the operations you're trying to perform
4. Check that all required indexes are created
