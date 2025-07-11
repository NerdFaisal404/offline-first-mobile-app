# Offline-First Todo App - Conflict Resolution Guide

## Overview

This Flutter app implements a sophisticated offline-first architecture with distributed conflict resolution. It handles the exact scenario you described: **3 devices editing the same todo offline, then syncing when connectivity is restored**.

## Architecture Summary

### Core Components

1. **Vector Clock System** - Tracks causal ordering across devices
2. **Conflict Detection** - Identifies concurrent edits that need resolution
3. **Auto-Resolution** - Handles simple conflicts automatically
4. **Manual Resolution UI** - Provides user interface for complex conflicts
5. **Operational Transform** - Merges concurrent changes intelligently

### The 3-Device Scenario

**Initial State:**
- 3 POS devices online, all synced via Firebase
- Single todo: "Coffee" with price $3.50

**Offline Phase:**
1. All 3 devices go offline
2. Device A updates: name="Premium Coffee", price=$4.50  
3. Device B updates: name="Iced Coffee", price=$3.75
4. Device C updates: name="Hot Coffee", price=$4.00

**Sync Resolution:**
When connectivity is restored, the system:
1. Detects concurrent edits using vector clocks
2. Creates conflict records for manual resolution
3. Presents all versions to the user
4. Allows selection or manual merge of conflicting data

## How Conflict Resolution Works

### 1. Vector Clock Tracking

Each todo maintains a vector clock that tracks logical time across devices:

```dart
VectorClock {
  "device-a": 2,
  "device-b": 1, 
  "device-c": 1
}
```

When devices edit offline, they increment their own clock:
- Device A: `{"device-a": 3, "device-b": 1, "device-c": 1}`
- Device B: `{"device-a": 2, "device-b": 2, "device-c": 1}`
- Device C: `{"device-a": 2, "device-b": 1, "device-c": 2}`

### 2. Conflict Detection

During sync, the system compares vector clocks:
- **Sequential**: One clock dominates another (A → B)
- **Concurrent**: Neither clock dominates (A ↔ B)

Concurrent changes with different content = CONFLICT

### 3. Resolution Strategies

#### Auto-Resolution (No User Intervention)
- **Completion status only**: Prefer completed state
- **Delete vs modify**: Prefer deletion (safer)
- **Identical content**: Use latest timestamp

#### Manual Resolution (User Choice Required)
- **Name/price conflicts**: Show all versions
- **Multiple field conflicts**: Allow custom merge

### 4. Resolution UI Flow

1. **Conflict Detection**: Red warning badge appears
2. **Conflict List**: Shows all unresolved conflicts
3. **Version Comparison**: Displays each device's version
4. **Resolution Options**:
   - Choose specific version
   - Auto-resolve (if available)
   - Manual merge (combine fields)

## Testing the 3-Device Scenario

### Method 1: Simulated Testing

1. **Setup**: Run app on 3 different devices/simulators
2. **Sync**: Ensure all devices have the same todo
3. **Go Offline**: Disable internet on all devices
4. **Edit**: Modify the same todo on each device differently
5. **Go Online**: Re-enable internet
6. **Observe**: Conflict resolution UI appears

### Method 2: Development Testing

Use the built-in device simulator to test conflicts:

```dart
// In your test code
final todo1 = Todo.create(id: "test", name: "Coffee", price: 3.50, deviceId: "device-a");
final todo2 = todo1.updateWith(name: "Premium Coffee", price: 4.50, updatingDeviceId: "device-a");
final todo3 = todo1.updateWith(name: "Iced Coffee", price: 3.75, updatingDeviceId: "device-b");
final todo4 = todo1.updateWith(name: "Hot Coffee", price: 4.00, updatingDeviceId: "device-c");

// Simulate sync conflict
final conflict = Conflict.create(id: uuid.v4(), conflictingTodos: [todo2, todo3, todo4]);
```

## Key Features

### 1. Offline-First Design
- Works completely offline
- Local SQLite database with Drift
- Queue changes for later sync

### 2. Distributed Sync
- Firebase Firestore for cloud sync
- Bidirectional synchronization
- Conflict-aware merge logic

### 3. Smart Conflict Resolution
- Vector clock-based causality tracking
- Automatic resolution for simple conflicts
- Rich UI for manual conflict resolution

### 4. Real-time Status
- Sync status indicators
- Conflict badges and notifications
- Device identification in UI

## Conflict Resolution UI Components

### 1. Sync Status Bar
- Shows connection status
- Indicates pending syncs
- Displays conflict count

### 2. Conflict View
- Lists all unresolved conflicts
- Shows version differences
- Provides resolution options

### 3. Version Selection
- Compare side-by-side
- See device and timestamp info
- One-click resolution

### 4. Manual Merge Dialog
- Field-by-field selection
- Custom value combination
- Preview final result

## Technical Implementation Details

### Database Schema
```sql
-- Todos table with conflict metadata
CREATE TABLE todos (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  vector_clock_json TEXT NOT NULL,
  device_id TEXT NOT NULL,
  version INTEGER NOT NULL,
  is_deleted BOOLEAN DEFAULT FALSE,
  sync_id TEXT,
  needs_sync BOOLEAN DEFAULT TRUE
);

-- Conflicts table
CREATE TABLE conflicts (
  id TEXT PRIMARY KEY,
  todo_id TEXT NOT NULL,
  versions_json TEXT NOT NULL,
  detected_at DATETIME NOT NULL,
  conflict_type INTEGER NOT NULL,
  is_resolved BOOLEAN DEFAULT FALSE,
  resolved_by TEXT,
  resolved_at DATETIME
);
```

### Sync Algorithm
```dart
1. Upload local changes to Firebase
2. Download remote changes from Firebase  
3. For each remote change:
   a. Check if local version exists
   b. Compare vector clocks
   c. If concurrent + different content → Create conflict
   d. If sequential → Apply update
   e. If identical → Ignore
4. Present conflicts to user
5. Apply resolved changes
```

### Vector Clock Operations
```dart
// Increment on local edit
clock = clock.increment(currentDeviceId);

// Merge on sync
mergedClock = localClock.merge(remoteClock);

// Compare for conflicts
relationship = localClock.compareTo(remoteClock);
// Returns: before, after, or concurrent
```

## Benefits of This Approach

1. **True Offline Support**: Works without any network connectivity
2. **No Data Loss**: All changes are preserved and can be resolved
3. **Flexible Resolution**: Auto-resolve simple conflicts, manual for complex ones
4. **Distributed**: No central authority needed for conflict resolution
5. **Scalable**: Handles any number of concurrent devices
6. **User-Friendly**: Clear UI for understanding and resolving conflicts

## Edge Cases Handled

1. **Network partitions**: Devices can sync when reconnected
2. **Clock skew**: Uses logical time, not wall clock time
3. **Device deletion**: Soft deletes with vector clock tracking
4. **Partial syncs**: Handles incomplete sync operations
5. **Rapid changes**: Queues multiple local changes correctly

This implementation provides a robust solution for the distributed todo editing scenario you described, with a clean UI for resolving the inevitable conflicts that arise in offline-first systems. 