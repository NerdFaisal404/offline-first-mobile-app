# 🚀 Offline-First Distributed Todo App

An advanced Flutter application that demonstrates **offline-first architecture** with sophisticated **conflict resolution** for distributed editing across multiple devices. This app handles the complex scenario where multiple devices edit the same data while offline, then sync when connectivity is restored.

## 📱 **Demo Scenario**

**The 3-Device Problem Solved:**
1. 3 POS devices are online and synced
2. All devices go offline
3. Each device edits the same todo differently:
   - Device A: "Coffee" → "Premium Coffee" ($4.50)
   - Device B: "Coffee" → "Iced Coffee" ($3.75)  
   - Device C: "Coffee" → "Hot Coffee" ($4.00)
4. When back online, the app detects conflicts and provides resolution options

## ✨ **Key Features**

### 🔄 **Offline-First Architecture**
- ✅ **Works completely offline** with local SQLite storage
- ✅ **Automatic sync** when connectivity is restored
- ✅ **No data loss** - all changes are preserved and resolvable
- ✅ **Queue-based sync** for reliable data transmission

### 🧠 **Smart Conflict Resolution**
- ✅ **Vector Clock System** for tracking causal relationships
- ✅ **Automatic resolution** for simple conflicts (completion status, deletions)
- ✅ **Manual resolution** with rich UI for complex conflicts
- ✅ **Field-by-field merging** for custom conflict resolution

### 🎨 **Rich User Interface**
- ✅ **Real-time sync status** indicators
- ✅ **Conflict badges** and notifications
- ✅ **Device identification** in UI
- ✅ **Side-by-side version comparison**
- ✅ **Manual merge dialogs** for complex conflicts

### 🏗️ **Clean Architecture**
- ✅ **Domain-driven design** with clear separation of concerns
- ✅ **Repository pattern** for data access abstraction
- ✅ **Dependency injection** with Riverpod
- ✅ **Testable code** with mocked dependencies

## 🛠️ **Technology Stack**

| Layer | Technology | Purpose |
|-------|------------|---------|
| **State Management** | Riverpod | Reactive state management and dependency injection |
| **Local Database** | Drift (SQLite) | Offline data storage with type-safe queries |
| **Cloud Sync** | Firebase Firestore | Real-time cloud synchronization |
| **Architecture** | Clean Architecture | Domain/Data/Presentation separation |
| **Conflict Resolution** | Vector Clocks | Distributed causality tracking |
| **Networking** | Connectivity Plus | Network status monitoring |

## 📦 **Installation**

### **Prerequisites**
- Flutter SDK (3.5.4+)
- Dart SDK (3.5.4+)
- Firebase project setup
- Android Studio / VS Code

### **Setup Steps**

1. **Clone the repository:**
```bash
git clone https://github.com/NerdFaisal404/offline-first-mobile-app.git
cd offline-first-mobile-app
```

2. **Install dependencies:**
```bash
flutter pub get
```

3. **Generate code:**
```bash
dart run build_runner build
```

4. **Firebase setup:**
   - Create a Firebase project
   - Enable Firestore Database
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in appropriate directories

5. **Run the app:**
```bash
flutter run
```

## 📖 **Documentation**

- **[📋 Architecture Documentation](ARCHITECTURE.md)** - Comprehensive UML diagrams, system architecture, and component interactions
- **[🏗️ Clean Architecture](ARCHITECTURE.md#functional-system-architecture)** - Layered architecture with separation of concerns
- **[⚖️ Conflict Resolution](ARCHITECTURE.md#conflict-resolution--sync-flow)** - Vector clock-based conflict detection and resolution
- **[📡 Real-time Sync](ARCHITECTURE.md#system-data-flow--component-interaction)** - Multi-device synchronization patterns

## 📁 **Project Structure**

```
lib/
├── 🎯 domain/                      # Business logic and entities
│   ├── entities/                   # Core business entities
│   │   ├── todo.dart              # Todo entity with conflict metadata
│   │   ├── conflict.dart          # Conflict representation
│   │   └── vector_clock.dart      # Distributed causality tracking
│   └── repositories/              # Abstract repository interfaces
│       └── todo_repository.dart   # Todo operations interface
│
├── 💾 data/                        # Data access and storage
│   ├── models/                    # Database table definitions
│   │   ├── todo_table.dart        # Drift todo table schema
│   │   └── conflict_table.dart    # Drift conflict table schema
│   ├── datasources/               # Data source implementations
│   │   ├── local_database.dart    # Drift SQLite database
│   │   └── firebase_datasource.dart # Firebase Firestore client
│   └── repositories/              # Repository implementations
│       └── todo_repository_impl.dart # Concrete repository with conflict logic
│
├── 🎨 presentation/                # UI and state management
│   ├── providers/                 # Riverpod providers
│   │   ├── app_providers.dart     # Core app dependencies
│   │   └── todo_providers.dart    # Todo-specific state management
│   ├── pages/                     # Full-screen pages
│   │   └── todo_home_page.dart    # Main application screen
│   └── widgets/                   # Reusable UI components
│       ├── todo_list.dart         # Todo list with sync indicators
│       ├── add_todo_dialog.dart   # Add new todo dialog
│       ├── sync_status_bar.dart   # Real-time sync status
│       └── conflicts_view.dart    # Conflict resolution interface
│
├── ⚙️ core/                        # Core utilities and services
│   ├── services/                  # Application services
│   │   └── sync_service.dart      # Bidirectional sync orchestration
│   └── utils/                     # Utility classes
│       └── conflict_resolver.dart # Conflict resolution algorithms
│
└── 📱 main.dart                    # Application entry point
```

## 🔄 **How Conflict Resolution Works**

### **1. Vector Clock Tracking**
Each todo maintains a vector clock that tracks logical time across devices:

```dart
// Initial state on all devices
VectorClock { "device-a": 1, "device-b": 1, "device-c": 1 }

// After offline edits
Device A: { "device-a": 2, "device-b": 1, "device-c": 1 }  // Updated name & price
Device B: { "device-a": 1, "device-b": 2, "device-c": 1 }  // Updated name & price  
Device C: { "device-a": 1, "device-b": 1, "device-c": 2 }  // Updated name & price
```

### **2. Conflict Detection Algorithm**
```dart
1. Compare vector clocks when syncing
2. If clocks are concurrent (neither dominates) + content differs = CONFLICT
3. Create conflict record with all versions
4. Present resolution options to user
```

### **3. Resolution Strategies**

| Conflict Type | Resolution Method |
|---------------|-------------------|
| **Completion only** | Auto-resolve: prefer completed state |
| **Delete vs Modify** | Auto-resolve: prefer deletion (safer) |
| **Name/Price changes** | Manual resolution required |
| **Multiple fields** | Field-by-field manual selection |

## 🎮 **How to Use**

### **Basic Operations**
1. **Add Todo**: Tap ➕ button to create new todos
2. **Edit Todo**: Tap on any todo to edit name/price
3. **Toggle Completion**: Tap checkbox to mark complete/incomplete
4. **Delete Todo**: Use menu → Delete (soft delete with conflict tracking)

### **Sync Status**
- 🟢 **Green**: All synced
- 🟡 **Yellow**: Pending uploads
- 🔵 **Blue**: Currently syncing
- 🟠 **Orange**: Conflicts detected
- 🔴 **Red**: Offline/error

### **Conflict Resolution**
1. **Conflict Detection**: Orange warning badge appears
2. **View Conflicts**: Tap warning badge to see conflict list
3. **Choose Resolution**:
   - **Select Version**: Choose any device's version
   - **Auto-Resolve**: Let system resolve simple conflicts
   - **Manual Merge**: Combine fields from different versions
4. **Apply Resolution**: Conflict disappears, data syncs

## 🧪 **Testing the 3-Device Scenario**

### **Method 1: Multiple Simulators**
```bash
# Terminal 1 - iOS Simulator
flutter run -d "iPhone 15 Pro"

# Terminal 2 - Android Emulator  
flutter run -d "Android Emulator"

# Terminal 3 - Web Browser
flutter run -d chrome
```

### **Method 2: Network Simulation**
1. Start app on multiple devices
2. Create same todo on all devices
3. Turn off WiFi/data on all devices
4. Edit same todo differently on each device
5. Turn network back on
6. Observe conflict resolution UI

### **Method 3: Development Testing**
Use the built-in conflict simulator in debug mode to inject test conflicts.

## 📊 **Database Schema**

### **Todos Table**
```sql
CREATE TABLE todos (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  vector_clock_json TEXT NOT NULL,    -- Serialized vector clock
  device_id TEXT NOT NULL,            -- Last editing device
  version INTEGER NOT NULL,           -- Local version number
  is_deleted BOOLEAN DEFAULT FALSE,   -- Soft delete flag
  sync_id TEXT,                      -- Firebase document ID
  needs_sync BOOLEAN DEFAULT TRUE     -- Pending sync flag
);
```

### **Conflicts Table**
```sql
CREATE TABLE conflicts (
  id TEXT PRIMARY KEY,
  todo_id TEXT NOT NULL,
  versions_json TEXT NOT NULL,        -- All conflicting versions
  detected_at DATETIME NOT NULL,
  conflict_type INTEGER NOT NULL,     -- Type of conflict
  is_resolved BOOLEAN DEFAULT FALSE,
  resolved_by TEXT,                   -- Device that resolved
  resolved_at DATETIME
);
```

## 🔧 **Configuration**

### **Firebase Setup**
1. Create Firestore database
2. Set up security rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /todos/{document} {
      allow read, write: if true; // Adjust based on your auth requirements
    }
  }
}
```

### **Sync Configuration**
```dart
// In sync_service.dart
static const Duration _syncInterval = Duration(minutes: 5);  // Auto-sync frequency
static const Duration _retryDelay = Duration(seconds: 30);   // Retry failed syncs
```

## 🚨 **Troubleshooting**

### **Common Issues**

| Problem | Solution |
|---------|----------|
| **Build errors** | Run `dart run build_runner build --delete-conflicting-outputs` |
| **Firebase not connecting** | Check `google-services.json` placement |
| **Conflicts not appearing** | Ensure different `deviceId` for each instance |
| **Sync not working** | Check internet connectivity and Firebase rules |

### **Debug Tools**
- Enable debug mode to see vector clock operations
- Use Flutter Inspector to examine widget state
- Check Firestore console for sync status

## 🤝 **Contributing**

### **Development Workflow**
1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Make changes following the architecture patterns
4. Add tests for new functionality
5. Run tests: `flutter test`
6. Submit pull request

### **Code Style**
- Follow Dart/Flutter conventions
- Use meaningful variable names
- Add documentation for complex algorithms
- Maintain clean architecture separation

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **Vector Clock Algorithm**: Based on Leslie Lamport's logical clocks
- **Conflict Resolution**: Inspired by Git's merge strategies
- **Offline-First**: Following CouchDB/PouchDB principles
- **Clean Architecture**: Robert C. Martin's architectural patterns

## 📞 **Support**

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/NerdFaisal404/offline-first-mobile-app/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/NerdFaisal404/offline-first-mobile-app/discussions)
- 📖 **Documentation**: [Conflict Resolution Guide](CONFLICT_RESOLUTION_GUIDE.md)

---

**Built with ❤️ for distributed systems enthusiasts**

This app demonstrates advanced concepts in distributed computing, offline-first architecture, and conflict resolution - perfect for learning how to build robust multi-device applications! 🚀
