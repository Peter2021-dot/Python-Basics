# Journey System Setup - Summary of Changes

## Overview
The journey system has been fully configured to allow both creators (hosts) and applicants (companions) to interact with journeys and save data to Firestore.

## Files Modified

### 1. **lib/services/application_service.dart**
- ✅ Added missing `import 'package:cloud_firestore/cloud_firestore.dart';`
- **Status:** Ready to use

### 2. **lib/providers/application_provider.dart**
- ✅ Added missing imports:
  - `import 'package:flutter/foundation.dart';`
  - `import 'package:cloud_firestore/cloud_firestore.dart';`
  - `import '../models/journey_model.dart';`
- **Status:** Ready to use

### 3. **lib/services/journey_service.dart**
- ✅ Moved standalone `getAppliedJourneys()` function into the `JourneyService` class
- ✅ Added error handling and empty check for applied journeys
- **Status:** Ready to use

### 4. **lib/providers/journey_provider.dart**
- ✅ Updated `getAppliedJourneysStream()` to call the instance method from `JourneyService`
- **Status:** Ready to use

### 5. **lib/screens/home_page.dart** (Major Updates)
- ✅ Added `import 'package:firebase_auth/firebase_auth.dart';`
- ✅ Added `import 'package:wethere/providers/application_provider.dart';`
- ✅ Added `_journeyModelsById` cache to store original JourneyModel objects
- ✅ Updated `_convertModelToJourney()` to cache JourneyModel by ID
- ✅ Updated Apply button to retrieve cached JourneyModel before applying
- ✅ Replaced hardcoded user IDs with `FirebaseAuth.instance.currentUser?.uid`
- ✅ Replaced hardcoded user names with `FirebaseAuth.instance.currentUser?.displayName`
- ✅ Updated `_handleApplyJourney()` signature to accept `jm.JourneyModel`
- ✅ Updated `_showRewardSelectionDialog()` signature to accept `jm.JourneyModel`
- ✅ Updated `_submitApplication()` signature to accept `jm.JourneyModel`
- ✅ Added authentication check before applying to journeys
- **Status:** Ready to use

## New Files Created

### 1. **FIRESTORE_SETUP.md**
Complete guide for setting up Firestore including:
- Collection structures (`journeys` and `applications`)
- Security rules
- Required composite indexes
- Testing procedures
- Common issues and solutions

## How It Works Now

### For Journey Creators (Hosts):
1. **Create Journey:**
   - Navigate to "My Journeys" tab → Click "+ Create"
   - Fill out journey details (title, location, compensation, etc.)
   - Journey is saved to Firestore `journeys` collection
   - Journey appears in "Created" tab

2. **View Created Journeys:**
   - "My Journeys" → "Created" tab shows all journeys created by the user
   - Real-time updates from Firestore

3. **View Active Journeys:**
   - "My Journeys" → "Active" tab shows open journeys that haven't ended yet
   - Automatically filters out past journeys

4. **View Past Journeys:**
   - "My Journeys" → "Past" tab shows completed journeys
   - Includes journeys that have ended or have status "completed"/"filled"

### For Journey Applicants (Companions):
1. **Browse Journeys:**
   - "Explore" tab shows all open journeys
   - Filter by compensation type, price range, date
   - Sort by recent, soonest, or highest pay

2. **Apply to Journey:**
   - Click "APPLY" button on any journey card
   - For "Companion's Choice" journeys: select preferred reward (hourly pay OR free item)
   - For other journeys: apply directly
   - Application saved to Firestore `applications` collection
   - Journey's `currentApplicants` count incremented

3. **View Applications:**
   - "My Journeys" → "Applied" tab shows all journeys the user has applied to
   - Real-time updates from Firestore

## Data Flow

### Creating a Journey:
```
User fills form → JourneyProvider.createJourney() 
→ JourneyService.createJourney() 
→ Firestore 'journeys' collection
→ Real-time stream updates all listeners
```

### Applying to a Journey:
```
User clicks APPLY → _handleApplyJourney() 
→ _submitApplication() 
→ ApplicationProvider.applyToJourney() 
→ Firestore transaction:
    1. Create document in 'applications' collection
    2. Increment 'currentApplicants' in journey document
→ Success/error message shown to user
```

### Viewing Journeys:
```
HomePage loads → JourneyProvider.getJourneysStream() 
→ JourneyService.getOpenJourneys() 
→ Firestore real-time listener 
→ Stream updates UI automatically
```

### Viewing Applications:
```
"Applied" tab selected → JourneyProvider.getAppliedJourneysStream() 
→ JourneyService.getAppliedJourneys() 
→ Query 'applications' where userId = current user 
→ Fetch corresponding journey documents 
→ Display in UI
```

## Authentication Requirements

The system now requires Firebase Authentication:
- Users must be logged in to create journeys
- Users must be logged in to apply to journeys
- User ID and display name are automatically retrieved from `FirebaseAuth.instance.currentUser`

## Firestore Setup Required

Before the system works, you need to:

1. **Set up Firestore collections** (auto-created on first write)
2. **Add security rules** (see FIRESTORE_SETUP.md)
3. **Create composite indexes** (see FIRESTORE_SETUP.md)

## Testing Checklist

- [ ] User can create a journey
- [ ] Created journey appears in Firestore
- [ ] Created journey appears in "My Journeys" → "Created" tab
- [ ] Journey appears in "Explore" tab for other users
- [ ] User can apply to a journey
- [ ] Application appears in Firestore
- [ ] Journey's `currentApplicants` count increases
- [ ] Applied journey appears in "My Journeys" → "Applied" tab
- [ ] Filters work correctly in Explore tab
- [ ] Sorting works correctly in Explore tab
- [ ] Real-time updates work (create journey in one device, see it on another)

## Known Limitations

1. **WhereIn Limit:** Firestore's `whereIn` query has a limit of 10 items. If a user applies to more than 10 journeys, only the first 10 will be shown. Consider implementing pagination if this becomes an issue.

2. **Image Upload:** Currently, journey images use asset paths. You'll need to implement image upload to Firebase Storage for user-uploaded images.

3. **Notifications:** The system doesn't send notifications when someone applies to a journey. Consider adding Firebase Cloud Messaging for this.

4. **Chat/Messaging:** The Inbox tab is currently a placeholder. You'll need to implement a messaging system.

## Next Steps

1. **Review FIRESTORE_SETUP.md** and set up your Firestore database
2. **Test the journey creation flow**
3. **Test the application flow**
4. **Implement image upload** (optional)
5. **Add notifications** (optional)
6. **Implement messaging** (optional)
7. **Add journey details page** (optional)
8. **Add application management for hosts** (accept/reject applications)

## Support

All the code is now properly connected and should work once Firestore is set up. If you encounter any issues:

1. Check that Firebase is properly initialized in your app
2. Verify Firestore security rules are set up
3. Create required composite indexes
4. Check Flutter console for error messages
5. Verify user is authenticated before trying to create/apply to journeys
