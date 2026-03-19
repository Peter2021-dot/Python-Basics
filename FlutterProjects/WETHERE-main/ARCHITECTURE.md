# Journey System Architecture

## System Components

```
┌─────────────────────────────────────────────────────────────────────┐
│                            USER INTERFACE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────┐ │
│  │   Explore    │  │ My Journeys  │  │    Inbox     │  │ Profile │ │
│  │              │  │              │  │              │  │         │ │
│  │ - Browse     │  │ - Active     │  │ (Placeholder)│  │ - Stats │ │
│  │ - Filter     │  │ - Created    │  │              │  │ - Edit  │ │
│  │ - Sort       │  │ - Applied    │  │              │  │         │ │
│  │ - Apply      │  │ - Past       │  │              │  │         │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └─────────┘ │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ User Actions
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         PROVIDER LAYER                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌────────────────────────┐         ┌──────────────────────────┐   │
│  │   JourneyProvider      │         │  ApplicationProvider     │   │
│  │                        │         │                          │   │
│  │ - createJourney()      │         │ - applyToJourney()       │   │
│  │ - getJourneysStream()  │         │                          │   │
│  │ - getMyJourneysStream()│         │                          │   │
│  │ - getAppliedJourneys() │         │                          │   │
│  └────────────────────────┘         └──────────────────────────┘   │
│              │                                    │                  │
│              │ Delegates to                       │                  │
│              ▼                                    ▼                  │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         SERVICE LAYER                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌────────────────────────┐         ┌──────────────────────────┐   │
│  │   JourneyService       │         │  ApplicationService      │   │
│  │                        │         │                          │   │
│  │ - createJourney()      │         │ - applyToJourney()       │   │
│  │ - getOpenJourneys()    │         │                          │   │
│  │ - getMyCreatedJourneys│         │                          │   │
│  │ - getMyPastJourneys()  │         │                          │   │
│  │ - getAppliedJourneys() │         │                          │   │
│  │ - updateJourney()      │         │                          │   │
│  │ - cancelJourney()      │         │                          │   │
│  └────────────────────────┘         └──────────────────────────┘   │
│              │                                    │                  │
│              │ Firestore Operations               │                  │
│              ▼                                    ▼                  │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         FIREBASE LAYER                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌────────────────────────┐         ┌──────────────────────────┐   │
│  │  Firestore Database    │         │   Firebase Auth          │   │
│  │                        │         │                          │   │
│  │  Collections:          │         │ - currentUser            │   │
│  │  - journeys            │         │ - uid                    │   │
│  │  - applications        │         │ - displayName            │   │
│  │                        │         │                          │   │
│  └────────────────────────┘         └──────────────────────────┘   │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Models

```
┌──────────────────────────────────────────────────────────────────┐
│                        JourneyModel                               │
├──────────────────────────────────────────────────────────────────┤
│ Host Info:                                                        │
│ - hostUserId: String                                             │
│ - hostName: String                                               │
│ - hostAvatar: String?                                            │
│                                                                   │
│ Basic Info:                                                       │
│ - title: String                                                  │
│ - description: String                                            │
│ - imageUrl: String                                               │
│                                                                   │
│ Location:                                                         │
│ - location: String                                               │
│ - meetingPoint: String                                           │
│ - locationCoordinates: GeoPoint?                                 │
│                                                                   │
│ Timing:                                                           │
│ - date: DateTime                                                 │
│ - startTime: DateTime                                            │
│ - endTime: DateTime                                              │
│ - duration: int                                                  │
│                                                                   │
│ Compensation:                                                     │
│ - compensationType: CompensationType                             │
│ - hourlyRate: int?                                               │
│ - freeItemDesc: String?                                          │
│ - freeItemEmoji: String?                                         │
│ - coveredExpenseDesc: String?                                    │
│ - coveredExpenseEmoji: String?                                   │
│                                                                   │
│ Status:                                                           │
│ - status: String (open/filled/completed/cancelled)               │
│ - maxCompanions: int                                             │
│ - currentApplicants: int                                         │
│ - acceptedCompanionId: String?                                   │
│                                                                   │
│ Metadata:                                                         │
│ - createdAt: DateTime                                            │
│ - updatedAt: DateTime                                            │
│ - views: int                                                     │
│ - tags: List<String>                                             │
│ - city: String                                                   │
│ - state: String?                                                 │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                      ApplicationModel                             │
├──────────────────────────────────────────────────────────────────┤
│ - id: String                                                     │
│ - journeyId: String                                              │
│ - journeyTitle: String                                           │
│ - userId: String (applicant)                                     │
│ - userName: String                                               │
│ - hostUserId: String                                             │
│ - rewardChoice: String? (for companionChoice type)               │
│ - status: String (applied/accepted/rejected/cancelled)           │
│ - createdAt: DateTime                                            │
└──────────────────────────────────────────────────────────────────┘
```

## User Flows

### Flow 1: Creating a Journey

```
User                    HomePage              JourneyProvider       JourneyService       Firestore
  │                        │                         │                    │                  │
  │  Click "+ Create"      │                         │                    │                  │
  ├───────────────────────>│                         │                    │                  │
  │                        │                         │                    │                  │
  │  Navigate to           │                         │                    │                  │
  │  CreateJourneyPage     │                         │                    │                  │
  │                        │                         │                    │                  │
  │  Fill form & Submit    │                         │                    │                  │
  ├───────────────────────>│                         │                    │                  │
  │                        │  createJourney()        │                    │                  │
  │                        ├────────────────────────>│                    │                  │
  │                        │                         │  createJourney()   │                  │
  │                        │                         ├───────────────────>│                  │
  │                        │                         │                    │  add document    │
  │                        │                         │                    ├─────────────────>│
  │                        │                         │                    │                  │
  │                        │                         │                    │  document ID     │
  │                        │                         │                    │<─────────────────┤
  │                        │                         │  journey ID        │                  │
  │                        │                         │<───────────────────┤                  │
  │                        │  journey ID             │                    │                  │
  │                        │<────────────────────────┤                    │                  │
  │  Success message       │                         │                    │                  │
  │<───────────────────────┤                         │                    │                  │
  │                        │                         │                    │                  │
  │                        │  Real-time stream update (all listeners notified)              │
  │                        │<───────────────────────────────────────────────────────────────┤
```

### Flow 2: Applying to a Journey

```
User                    HomePage              ApplicationProvider   Firestore
  │                        │                         │                  │
  │  Browse journeys       │                         │                  │
  │  in Explore tab        │                         │                  │
  │                        │                         │                  │
  │  Click "APPLY"         │                         │                  │
  ├───────────────────────>│                         │                  │
  │                        │                         │                  │
  │  (If companionChoice)  │                         │                  │
  │  Select reward option  │                         │                  │
  ├───────────────────────>│                         │                  │
  │                        │                         │                  │
  │                        │  applyToJourney()       │                  │
  │                        ├────────────────────────>│                  │
  │                        │                         │  Transaction:    │
  │                        │                         │  1. Create app   │
  │                        │                         │  2. Increment    │
  │                        │                         │     applicants   │
  │                        │                         ├─────────────────>│
  │                        │                         │                  │
  │                        │                         │  Success         │
  │                        │                         │<─────────────────┤
  │                        │  Success                │                  │
  │                        │<────────────────────────┤                  │
  │  Success message       │                         │                  │
  │<───────────────────────┤                         │                  │
```

### Flow 3: Viewing Applied Journeys

```
User                    HomePage              JourneyProvider       JourneyService       Firestore
  │                        │                         │                    │                  │
  │  Navigate to           │                         │                    │                  │
  │  "Applied" tab         │                         │                    │                  │
  ├───────────────────────>│                         │                    │                  │
  │                        │  getAppliedJourneys()   │                    │                  │
  │                        ├────────────────────────>│                    │                  │
  │                        │                         │  getAppliedJourneys│                  │
  │                        │                         ├───────────────────>│                  │
  │                        │                         │                    │  Query apps      │
  │                        │                         │                    │  where userId    │
  │                        │                         │                    ├─────────────────>│
  │                        │                         │                    │                  │
  │                        │                         │                    │  App docs        │
  │                        │                         │                    │<─────────────────┤
  │                        │                         │                    │                  │
  │                        │                         │                    │  Fetch journeys  │
  │                        │                         │                    │  by IDs          │
  │                        │                         │                    ├─────────────────>│
  │                        │                         │                    │                  │
  │                        │                         │                    │  Journey docs    │
  │                        │                         │                    │<─────────────────┤
  │                        │                         │  Journey list      │                  │
  │                        │                         │<───────────────────┤                  │
  │                        │  Journey list           │                    │                  │
  │                        │<────────────────────────┤                    │                  │
  │  Display journeys      │                         │                    │                  │
  │<───────────────────────┤                         │                    │                  │
```

## Compensation Types

```
┌─────────────────────────────────────────────────────────────────┐
│                    Compensation Types                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. HOURLY PAY                                                   │
│     ├─ Host pays companion by the hour                          │
│     ├─ Badge: "$15/h"                                           │
│     └─ Color: Orange (#FF6B35)                                  │
│                                                                  │
│  2. FREE ITEM                                                    │
│     ├─ Host provides free ticket/item                           │
│     ├─ Badge: "🎫 Free Ticket"                                  │
│     └─ Color: Green (#4CAF50)                                   │
│                                                                  │
│  3. COVERED EXPENSE                                              │
│     ├─ Host covers companion's expenses                         │
│     ├─ Badge: "🍽️ Dinner Covered"                              │
│     └─ Color: Teal (#26A69A)                                    │
│                                                                  │
│  4. COMPANION'S CHOICE                                           │
│     ├─ Companion chooses between hourly pay OR free item        │
│     ├─ Badge: "$20/h OR 🎫 Free"                                │
│     ├─ Color: Purple (#7C4DFF)                                  │
│     └─ Requires selection dialog before applying                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Real-time Updates

The system uses Firestore's real-time listeners to keep the UI synchronized:

```
Firestore Change → Stream Update → Provider Notifies → UI Rebuilds
```

**Example:**
1. User A creates a journey
2. Firestore adds the document
3. All active listeners receive the update
4. User B's Explore tab automatically shows the new journey
5. No manual refresh needed!

## Caching Strategy

To prevent UI flickering when Firestore temporarily returns empty results:

```
┌─────────────────────────────────────────────────────────────┐
│  Stream receives data → Update cache → Display data         │
│                                                              │
│  Stream returns empty → Keep cache → Display cached data    │
│                                                              │
│  Stream explicitly empty → Clear cache → Show empty state   │
└─────────────────────────────────────────────────────────────┘
```

This ensures a smooth user experience even with network fluctuations.
