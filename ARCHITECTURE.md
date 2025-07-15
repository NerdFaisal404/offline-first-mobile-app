# Architecture Documentation

## Offline-First Distributed Todo Application

This document provides comprehensive architectural diagrams and explanations for the offline-first distributed todo application built with Flutter, Firebase, and sophisticated conflict resolution capabilities.

## Table of Contents

1. [UML Class Diagram](#1-uml-class-diagram)
2. [Functional System Architecture](#2-functional-system-architecture)
3. [Conflict Resolution & Sync Flow](#3-conflict-resolution--sync-flow)
4. [System Data Flow & Component Interaction](#4-system-data-flow--component-interaction)
5. [Key Architectural Features](#key-architectural-features)

---

## 1. UML Class Diagram

This diagram shows the complete class structure and relationships within the application, following clean architecture principles.

```mermaid
classDiagram
    %% Domain Layer - Core Entities
    class Todo {
        +String id
        +String name
        +double price
        +bool isCompleted
        +DateTime createdAt
        +DateTime updatedAt
        +VectorClock vectorClock
        +String deviceId
        +int version
        +bool isDeleted
        +String? syncId
        +create() Todo
        +updateWith() Todo
        +markDeleted() Todo
        +conflictsWith() bool
        +getChanges() TodoChanges
        +toJson() Map
        +fromJson() Todo
    }
    
    class VectorClock {
        -Map~String,int~ _clocks
        +clockFor(deviceId) int
        +deviceIds Set~String~
        +increment(deviceId) VectorClock
        +merge(other) VectorClock
        +compareTo(other) ComparisonResult
        +happensBefore() bool
        +isConcurrentWith() bool
        +toJson() Map
        +fromJson() VectorClock
    }
    
    class Conflict {
        +String id
        +String todoId
        +List~ConflictVersion~ versions
        +DateTime detectedAt
        +ConflictType type
        +bool isResolved
        +String? resolvedBy
        +DateTime? resolvedAt
        +create() Conflict
        +resolve() Conflict
        +getAutoResolutionWinner() ConflictVersion?
        +getDescription() String
    }
    
    class ConflictVersion {
        +String id
        +String name
        +double price
        +bool isCompleted
        +bool isDeleted
        +VectorClock vectorClock
        +String deviceId
        +DateTime updatedAt
        +fromTodo() ConflictVersion
    }
    
    %% Repository Interface
    class TodoRepository {
        <<interface>>
        +getAllTodos() Future~List~Todo~~
        +getActiveTodos() Future~List~Todo~~
        +getTodoById(id) Future~Todo?~
        +createTodo(todo) Future~void~
        +updateTodo(todo) Future~void~
        +deleteTodo(id) Future~void~
        +getUnresolvedConflicts() Future~List~Conflict~~
        +createConflict(conflict) Future~void~
        +resolveConflict(conflict) Future~void~
        +deleteConflict(id) Future~void~
        +getTodosNeedingSync() Future~List~Todo~~
        +markTodoSynced(id, syncId) Future~void~
        +syncFromRemote(todos) Future~void~
        +getCurrentDeviceId() Future~String~
        +updateCurrentDevice(id, name) Future~void~
        +watchTodos() Stream~List~Todo~~
        +watchConflicts() Stream~List~Conflict~~
    }
    
    %% Data Layer - Implementation
    class TodoRepositoryImpl {
        -LocalDatabase _localDatabase
        -FirebaseDataSource _firebaseDataSource
        -ConflictResolver _conflictResolver
        -StreamController~List~Todo~~ _todosController
        -StreamController~List~Conflict~~ _conflictsController
        -Timer? _updateTimer
        -void Function()? _onDataChanged
        +setDataChangeCallback() void
        +getAllTodos() Future~List~Todo~~
        +createTodo() Future~void~
        +updateTodo() Future~void~
        +deleteTodo() Future~void~
        +syncFromRemote() Future~void~
        -_processRemoteTodo() Future~void~
        -_emitTodosUpdate() void
        -_emitConflictsUpdate() void
        -_triggerSync() void
    }
    
    class LocalDatabase {
        +getAllTodos() Future~List~Todo~~
        +getActiveTodos() Future~List~Todo~~
        +getTodoById(id) Future~Todo?~
        +insertTodo(todo) Future~void~
        +updateTodo(todo) Future~void~
        +deleteTodo(id) Future~void~
        +markTodoSynced(id, syncId) Future~void~
        +getAllConflicts() Future~List~Conflict~~
        +getUnresolvedConflicts() Future~List~Conflict~~
        +insertConflict(conflict) Future~void~
        +updateConflict(conflict) Future~void~
        +deleteConflict(id) Future~void~
        +updateCurrentDevice(id, name) Future~void~
        +getCurrentDeviceId() Future~String?~
        -_todoDataToEntity() Todo
        -_todoEntityToData() TodosCompanion
        -_conflictDataToEntity() Conflict
        -_conflictEntityToData() ConflictsCompanion
    }
    
    class FirebaseDataSource {
        -FirebaseFirestore _firestore
        +uploadTodos(todos) Future~void~
        +downloadTodos() Future~List~Todo~~
        +uploadTodo(todo) Future~String~
        +deleteTodo(syncId) Future~void~
        +watchTodos() Stream~List~Todo~~
        +getTodosModifiedAfter(timestamp) Future~List~Todo~~
        +uploadDevice(device) Future~String~
        +downloadDevices() Future~List~DeviceData~~
        +watchDevices() Stream~List~DeviceData~~
        +updateDeviceLastSeen(id) Future~void~
        +uploadConflict(conflict) Future~String~
        +downloadConflicts() Future~List~Conflict~~
        +watchConflicts() Stream~List~Conflict~~
        +deleteConflict(id) Future~void~
        +isAvailable() Future~bool~
    }
    
    %% Core Services
    class SyncService {
        -TodoRepository _todoRepository
        -FirebaseDataSource _firebaseDataSource
        -LocalDatabase _localDatabase
        -Connectivity _connectivity
        -Timer? _syncTimer
        -StreamSubscription? _connectivitySubscription
        -StreamSubscription? _firebaseTodosSubscription
        -StreamSubscription? _firebaseDevicesSubscription
        -StreamSubscription? _firebaseConflictsSubscription
        -bool _isSyncing
        -bool _isRealTimeSyncActive
        +start() Future~void~
        +stop() void
        +forcSync() Future~SyncResult~
        -_onConnectivityChanged() void
        -_performInitialSync() Future~void~
        -_startRealTimeSync() Future~void~
        -_startPeriodicSync() void
        -_performSync() Future~SyncResult~
        -_uploadLocalChanges() Future~UploadResult~
        -_downloadRemoteChanges() Future~DownloadResult~
        -_processTodosFromFirebase() Future~void~
        -_processDevicesFromFirebase() Future~void~
        -_processConflictsFromFirebase() Future~void~
        -_syncCurrentDevice() Future~void~
        -_startDeviceHeartbeat() void
        -_cleanupDeletedTodos() Future~void~
        -_isConnected() Future~bool~
    }
    
    class ConflictResolver {
        +resolveConflict() ConflictResolution
        -_resolveConcurrentConflict() ConflictResolution
        -_useLatestByClock() ConflictResolution
        -_attemptSmartMerge() Todo
        -_todosAreIdentical() bool
        -_onlyCompletionDiffers() bool
        -_contentFieldsDiffer() bool
        -_getVectorClockSum() int
    }
    
    %% Database Tables
    class Todos {
        +TextColumn id
        +TextColumn name
        +RealColumn price
        +BoolColumn isCompleted
        +DateTimeColumn createdAt
        +DateTimeColumn updatedAt
        +TextColumn vectorClockJson
        +TextColumn deviceId
        +IntColumn version
        +BoolColumn isDeleted
        +TextColumn? syncId
        +BoolColumn needsSync
    }
    
    class Conflicts {
        +TextColumn id
        +TextColumn todoId
        +TextColumn versionsJson
        +DateTimeColumn detectedAt
        +IntColumn conflictType
        +BoolColumn isResolved
        +TextColumn? resolvedBy
        +DateTimeColumn? resolvedAt
    }
    
    class Devices {
        +TextColumn id
        +TextColumn name
        +DateTimeColumn lastSeen
        +BoolColumn isCurrentDevice
    }
    
    %% Presentation Layer
    class TodoHomePage {
        +build() Widget
        -_showAddTodoDialog() void
    }
    
    class TodoList {
        +build() Widget
    }
    
    class TodoItem {
        +Todo todo
        +build() Widget
        -_handleMenuAction() void
        -_showEditDialog() void
        -_showDeleteConfirmation() void
    }
    
    class ConflictsView {
        -bool _compactView
        +build() Widget
        -_buildCompactList() Widget
        -_buildDetailedList() Widget
        -_autoResolveAll() void
        -_useLatestVersions() void
        -_dismissAll() void
    }
    
    class AddTodoDialog {
        -TextEditingController _nameController
        -TextEditingController _priceController
        -GlobalKey~FormState~ _formKey
        +build() Widget
        -_submitTodo() void
    }
    
    class SyncStatusBar {
        +build() Widget
        -_getStatusColor() Color
        -_buildStatusIcon() Widget
        -_buildPrimaryText() Widget
        -_buildSecondaryText() Widget
        -_buildActionButton() Widget
        -_formatLastSync() String
    }
    
    %% State Management
    class TodoNotifier {
        -TodoRepository _repository
        -String _deviceId
        -Uuid _uuid
        +createTodo() Future~void~
        +updateTodo() Future~void~
        +deleteTodo() Future~void~
        +toggleTodoCompletion() Future~void~
    }
    
    class ConflictNotifier {
        -TodoRepository _repository
        -String _deviceId
        +resolveConflict() Future~void~
        +dismissConflict() Future~void~
        +autoResolveAll() Future~void~
        +resolveWithMerge() Future~void~
    }
    
    class SyncNotifier {
        -SyncService _syncService
        +forcSync() Future~void~
    }
    
    %% Enums
    class ConflictType {
        <<enumeration>>
        noConflict
        nameOnly
        priceOnly
        nameAndPrice
        completionOnly
        deleteModify
        multipleFields
    }
    
    class ResolutionType {
        <<enumeration>>
        useLocal
        useRemote
        useAutoMerged
        requiresManualResolution
    }
    
    class ComparisonResult {
        <<enumeration>>
        before
        after
        concurrent
    }
    
    %% Relationships
    Todo --* VectorClock : contains
    Conflict --* ConflictVersion : contains
    ConflictVersion --* VectorClock : contains
    TodoRepositoryImpl ..|> TodoRepository : implements
    TodoRepositoryImpl --> LocalDatabase : uses
    TodoRepositoryImpl --> FirebaseDataSource : uses
    TodoRepositoryImpl --> ConflictResolver : uses
    LocalDatabase --> Todos : manages
    LocalDatabase --> Conflicts : manages
    LocalDatabase --> Devices : manages
    SyncService --> TodoRepository : uses
    SyncService --> FirebaseDataSource : uses
    SyncService --> LocalDatabase : uses
    ConflictResolver --> Todo : processes
    ConflictResolver --> VectorClock : analyzes
    TodoHomePage --> TodoList : contains
    TodoHomePage --> ConflictsView : contains
    TodoHomePage --> SyncStatusBar : contains
    TodoList --> TodoItem : contains
    TodoNotifier --> TodoRepository : uses
    ConflictNotifier --> TodoRepository : uses
    SyncNotifier --> SyncService : uses
```

### Key Components:

- **Domain Entities**: Core business objects with rich behavior
- **Repository Pattern**: Clean separation between domain and data layers
- **Vector Clocks**: Distributed system causality tracking
- **Conflict Resolution**: Sophisticated automatic and manual resolution
- **State Management**: Reactive UI with Riverpod providers
- **Data Persistence**: SQLite with Drift ORM and Firebase Firestore

---

## 2. Functional System Architecture

This diagram illustrates the layered architecture and real-time data flow between components.

```mermaid
graph TD
    %% User Interface Layer
    subgraph "📱 Presentation Layer"
        UI[TodoHomePage]
        TL[TodoList & TodoItem]
        CV[ConflictsView]
        AD[AddTodoDialog]
        SSB[SyncStatusBar]
        UI --> TL
        UI --> CV
        UI --> AD
        UI --> SSB
    end
    
    %% State Management Layer
    subgraph "🔄 State Management (Riverpod)"
        TN[TodoNotifier]
        CN[ConflictNotifier]
        SN[SyncNotifier]
        TP[TodoProviders]
        AP[AppProviders]
        TL --> TN
        CV --> CN
        SSB --> SN
        TN --> TP
        CN --> TP
        SN --> AP
    end
    
    %% Domain Layer
    subgraph "🏗️ Domain Layer"
        TE[Todo Entity]
        CE[Conflict Entity]
        VC[VectorClock Entity]
        TR[TodoRepository Interface]
        TE --> VC
        CE --> TE
        CE --> VC
    end
    
    %% Core Services Layer
    subgraph "⚙️ Core Services"
        SS[SyncService]
        CR[ConflictResolver]
        
        subgraph "🔄 Real-time Sync Engine"
            RS[Real-time Streams]
            PS[Periodic Sync]
            DH[Device Heartbeat]
            CC[Connection Manager]
        end
        
        SS --> RS
        SS --> PS
        SS --> DH
        SS --> CC
    end
    
    %% Data Layer
    subgraph "💾 Data Layer"
        TRI[TodoRepositoryImpl]
        
        subgraph "🏠 Local Storage"
            LD[LocalDatabase<br/>SQLite + Drift]
            TT[Todos Table]
            CT[Conflicts Table]
            DT[Devices Table]
            LD --> TT
            LD --> CT
            LD --> DT
        end
        
        subgraph "☁️ Remote Storage"
            FD[FirebaseDataSource]
            FS[Firestore Collections]
            TC[todos]
            DC[devices]
            CC[conflicts]
            FD --> FS
            FS --> TC
            FS --> DC
            FS --> CC
        end
        
        TRI --> LD
        TRI --> FD
        TRI --> CR
    end
    
    %% External Dependencies
    subgraph "🌐 External Services"
        FB[Firebase/Firestore]
        CN[Connectivity Plus]
        ID[Device ID]
    end
    
    %% Data Flow Connections
    TP --> TR
    TR --> TRI
    SS --> TRI
    SS --> FD
    SS --> LD
    SS --> CN
    TRI --> CR
    FD --> FB
    SS --> ID
    
    %% Real-time Data Flow
    FB -.->|"📡 Real-time streams"| RS
    RS -.->|"🔄 Live updates"| TRI
    TRI -.->|"📊 State changes"| TP
    TP -.->|"🖼️ UI updates"| UI
    
    %% Offline Data Flow
    UI -->|"👆 User actions"| TN
    TN -->|"💾 Local writes"| TRI
    TRI -->|"📝 Store locally"| LD
    TRI -->|"⏰ Schedule sync"| SS
    SS -->|"📤 Upload when online"| FD
    
    %% Conflict Resolution Flow
    TRI -->|"⚠️ Detect conflicts"| CR
    CR -->|"🤖 Auto-resolve or<br/>🧑 Manual resolution"| CE
    CE -->|"✅ Resolved"| TRI
    TRI -->|"🗑️ Clean up"| LD
    
    %% Sync Flow
    SS -->|"📥 Download"| FD
    SS -->|"📤 Upload"| FD
    SS -->|"💓 Heartbeat"| DH
    DH -->|"👋 Update presence"| FD
    
    %% Connection Management
    CN -->|"📶 Connection status"| CC
    CC -->|"🌐 Online: Real-time sync"| RS
    CC -->|"📵 Offline: Local-only"| PS
    
    %% Styling
    classDef uiLayer fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef stateLayer fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef domainLayer fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef coreLayer fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef dataLayer fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef externalLayer fill:#f1f8e9,stroke:#33691e,stroke-width:2px
    
    class UI,TL,CV,AD,SSB uiLayer
    class TN,CN,SN,TP,AP stateLayer
    class TE,CE,VC,TR domainLayer
    class SS,CR,RS,PS,DH,CC coreLayer
    class TRI,LD,FD,TT,CT,DT,FS,TC,DC dataLayer
    class FB,CN,ID externalLayer
```

### Architecture Highlights:

- **📱 Clean UI Layer**: Flutter widgets with reactive state management
- **🔄 Reactive State**: Riverpod providers with real-time updates
- **🏗️ Domain-Driven**: Rich entities with business logic
- **⚙️ Smart Services**: Real-time sync with intelligent fallbacks
- **💾 Dual Persistence**: Local-first with cloud synchronization
- **🌐 External Integration**: Firebase, connectivity, and device management

---

## 3. Conflict Resolution & Sync Flow

This flowchart details the sophisticated conflict resolution workflow and synchronization strategies.

```mermaid
flowchart TD
    %% Starting Points
    Start1[👤 User Action on Device A]
    Start2[👤 User Action on Device B]
    Start3[📡 Real-time Firebase Update]
    Start4[🔄 Periodic Sync Trigger]
    
    %% Local Operations
    LocalWrite1[📝 Write to Local DB<br/>with Vector Clock]
    LocalWrite2[📝 Write to Local DB<br/>with Vector Clock]
    
    %% Sync Decision Points
    ConnCheck{🌐 Connected?}
    RealTimeActive{📡 Real-time<br/>Sync Active?}
    
    %% Upload Process
    UploadLocal[📤 Upload Local Changes]
    MarkSynced[✅ Mark as Synced]
    
    %% Download Process
    DownloadRemote[📥 Download Remote Changes]
    ProcessRemote[🔍 Process Each Remote Todo]
    
    %% Conflict Detection
    ConflictCheck{⚖️ Conflict<br/>Detected?}
    VectorClockCompare{🕐 Vector Clock<br/>Comparison}
    
    %% Conflict Resolution Paths
    Before[⬅️ Local Before Remote<br/>Use Remote]
    After[➡️ Local After Remote<br/>Use Local]
    Concurrent[🔄 Concurrent Changes<br/>Analyze Conflict]
    
    %% Concurrent Conflict Analysis
    DeleteConflict{🗑️ Delete vs<br/>Modify?}
    ContentConflict{📝 Content<br/>Conflicts?}
    CompletionOnly{✅ Only Completion<br/>Different?}
    
    %% Resolution Types
    AutoResolve[🤖 Auto-Resolve<br/>Smart Merge]
    ManualResolve[👤 Manual Resolution<br/>Create Conflict Record]
    PreferDelete[🗑️ Prefer Deletion]
    PreferComplete[✅ Prefer Completed]
    SmartMerge[🧠 Smart Field Merge<br/>• Longer name<br/>• Higher price<br/>• Completed state]
    
    %% Conflict UI Flow
    ConflictUI[⚠️ Show Conflicts View]
    UserChoice{👤 User Choice}
    AutoChoice[🤖 Auto-resolve All]
    LatestChoice[⏰ Use Latest Versions]
    ManualChoice[✏️ Manual Selection]
    DismissChoice[❌ Dismiss Conflicts]
    
    %% Final Actions
    UpdateLocal[💾 Update Local Database]
    UpdateRemote[☁️ Update Remote Database]
    CleanupConflicts[🧹 Cleanup Resolved Conflicts]
    NotifyUI[🔔 Notify UI of Changes]
    
    %% Real-time Stream Handling
    FirebaseStream[📡 Firebase Stream Event]
    StreamProcess[🔄 Process Stream Update]
    LocalUpdate[📊 Update Local State]
    
    %% Device Heartbeat
    DeviceHeartbeat[💓 Device Heartbeat<br/>Every 2 minutes]
    UpdatePresence[👋 Update Device Presence]
    
    %% Error Handling
    SyncError[❌ Sync Error]
    RetrySync[🔄 Retry After Delay]
    OfflineMode[📵 Switch to Offline Mode]
    
    %% Flow Connections
    Start1 --> LocalWrite1
    Start2 --> LocalWrite2
    LocalWrite1 --> ConnCheck
    LocalWrite2 --> ConnCheck
    
    ConnCheck -->|Yes| RealTimeActive
    ConnCheck -->|No| OfflineMode
    
    RealTimeActive -->|Yes| FirebaseStream
    RealTimeActive -->|No| UploadLocal
    
    Start3 --> FirebaseStream
    Start4 --> DownloadRemote
    
    FirebaseStream --> StreamProcess
    StreamProcess --> ConflictCheck
    
    UploadLocal --> MarkSynced
    MarkSynced --> DownloadRemote
    
    DownloadRemote --> ProcessRemote
    ProcessRemote --> ConflictCheck
    
    ConflictCheck -->|No Conflict| UpdateLocal
    ConflictCheck -->|Conflict Found| VectorClockCompare
    
    VectorClockCompare -->|Before| Before
    VectorClockCompare -->|After| After
    VectorClockCompare -->|Concurrent| Concurrent
    
    Before --> UpdateLocal
    After --> UpdateLocal
    Concurrent --> DeleteConflict
    
    DeleteConflict -->|Yes| PreferDelete
    DeleteConflict -->|No| ContentConflict
    
    ContentConflict -->|Yes| ManualResolve
    ContentConflict -->|No| CompletionOnly
    
    CompletionOnly -->|Yes| PreferComplete
    CompletionOnly -->|No| SmartMerge
    
    PreferDelete --> AutoResolve
    PreferComplete --> AutoResolve
    SmartMerge --> AutoResolve
    
    AutoResolve --> UpdateLocal
    ManualResolve --> ConflictUI
    
    ConflictUI --> UserChoice
    UserChoice -->|Auto-resolve| AutoChoice
    UserChoice -->|Latest| LatestChoice
    UserChoice -->|Manual| ManualChoice
    UserChoice -->|Dismiss| DismissChoice
    
    AutoChoice --> AutoResolve
    LatestChoice --> AutoResolve
    ManualChoice --> UpdateLocal
    DismissChoice --> CleanupConflicts
    
    UpdateLocal --> UpdateRemote
    UpdateRemote --> CleanupConflicts
    CleanupConflicts --> NotifyUI
    
    StreamProcess --> LocalUpdate
    LocalUpdate --> NotifyUI
    
    DeviceHeartbeat --> UpdatePresence
    UpdatePresence --> NotifyUI
    
    UploadLocal -->|Error| SyncError
    DownloadRemote -->|Error| SyncError
    SyncError --> RetrySync
    RetrySync --> DownloadRemote
    
    OfflineMode --> LocalUpdate
    
    %% Styling
    classDef userAction fill:#bbdefb,stroke:#1976d2,stroke-width:2px
    classDef localOp fill:#c8e6c9,stroke:#388e3c,stroke-width:2px
    classDef remoteOp fill:#ffcdd2,stroke:#d32f2f,stroke-width:2px
    classDef decision fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef conflict fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef resolution fill:#e1f5fe,stroke:#0288d1,stroke-width:2px
    classDef error fill:#ffebee,stroke:#f44336,stroke-width:2px
    
    class Start1,Start2,UserChoice userAction
    class LocalWrite1,LocalWrite2,UpdateLocal,LocalUpdate,OfflineMode localOp
    class UploadLocal,DownloadRemote,UpdateRemote,FirebaseStream,StreamProcess remoteOp
    class ConnCheck,RealTimeActive,ConflictCheck,VectorClockCompare,DeleteConflict,ContentConflict,CompletionOnly decision
    class Concurrent,ManualResolve,ConflictUI,AutoChoice,LatestChoice,ManualChoice,DismissChoice conflict
    class Before,After,AutoResolve,PreferDelete,PreferComplete,SmartMerge resolution
    class SyncError,RetrySync error
```

### Conflict Resolution Features:

- **🕐 Vector Clock Analysis**: Determines causal ordering between changes
- **🤖 Smart Auto-Resolution**: 85% expected auto-resolution rate
- **👤 Manual Resolution UI**: User-friendly conflict resolution interface
- **📡 Real-time Streams**: Instant conflict detection and resolution
- **🔄 Fallback Mechanisms**: Graceful degradation to periodic sync
- **💓 Device Heartbeat**: Presence tracking and coordination

---

## 4. System Data Flow & Component Interaction

This diagram shows the distributed system behavior across multiple devices with real-time synchronization.

```mermaid
graph LR
    %% User Devices
    subgraph "📱 Device A"
        UA[User A]
        UIA[Flutter UI]
        LDA[Local SQLite DB]
        VCA[Vector Clock A]
        UA --> UIA
        UIA --> LDA
        LDA --> VCA
    end
    
    subgraph "📱 Device B"
        UB[User B]
        UIB[Flutter UI]
        LDB[Local SQLite DB]
        VCB[Vector Clock B]
        UB --> UIB
        UIB --> LDB
        LDB --> VCB
    end
    
    subgraph "📱 Device C"
        UC[User C]
        UIC[Flutter UI]
        LDC[Local SQLite DB]
        VCC[Vector Clock C]
        UC --> UIC
        UIC --> LDC
        LDC --> VCC
    end
    
    %% Cloud Infrastructure
    subgraph "☁️ Firebase Cloud"
        FS[Firestore Database]
        
        subgraph "📊 Collections"
            TC[todos]
            DC[devices]
            CC[conflicts]
        end
        
        FS --> TC
        FS --> DC
        FS --> CC
        
        subgraph "📡 Real-time Features"
            RS[Real-time Streams]
            PS[Push Notifications]
            OH[Offline Handling]
        end
        
        FS --> RS
        FS --> PS
        FS --> OH
    end
    
    %% Network Layer
    subgraph "🌐 Network Layer"
        HTTP[HTTP/HTTPS]
        WS[WebSocket Streams]
        CM[Connection Manager]
        
        HTTP --> WS
        WS --> CM
    end
    
    %% Core System Processes
    subgraph "⚙️ System Processes"
        SS[Sync Service]
        CR[Conflict Resolver]
        VCM[Vector Clock Manager]
        DM[Device Manager]
        
        subgraph "🔄 Sync Strategies"
            RTS[Real-time Sync<br/>📡 Live streams]
            PBS[Periodic Batch Sync<br/>⏰ Every 5 minutes]
            ES[Emergency Sync<br/>🚨 On connection restore]
        end
        
        SS --> RTS
        SS --> PBS
        SS --> ES
    end
    
    %% Data Flow Arrows
    %% Bidirectional sync between devices and cloud
    LDA <-->|"📤📥<br/>Sync & Stream"| HTTP
    LDB <-->|"📤📥<br/>Sync & Stream"| HTTP
    LDC <-->|"📤📥<br/>Sync & Stream"| HTTP
    
    HTTP <--> FS
    WS <--> RS
    
    %% Vector Clock Synchronization
    VCA -.->|"🕐 Causal Order"| VCM
    VCB -.->|"🕐 Causal Order"| VCM
    VCC -.->|"🕐 Causal Order"| VCM
    VCM -.->|"⚖️ Conflict Detection"| CR
    
    %% Conflict Resolution Flow
    CR -->|"🤖 Auto-resolve"| SS
    CR -->|"👤 Manual resolve"| UIA
    CR -->|"👤 Manual resolve"| UIB
    CR -->|"👤 Manual resolve"| UIC
    
    %% Device Management
    DM -->|"💓 Heartbeat"| DC
    LDA -->|"📱 Device Info"| DM
    LDB -->|"📱 Device Info"| DM
    LDC -->|"📱 Device Info"| DM
    
    %% Connection Management
    CM -->|"📶 Status"| LDA
    CM -->|"📶 Status"| LDB
    CM -->|"📶 Status"| LDC
    
    %% Offline Scenarios
    subgraph "📵 Offline Scenarios"
        OA[Device A Offline]
        OB[Device B Offline]
        OC[Device C Offline]
        LS[Local Storage Only]
        QS[Queue for Sync]
    end
    
    OA -.->|"💾 Store locally"| LS
    OB -.->|"💾 Store locally"| LS
    OC -.->|"💾 Store locally"| LS
    LS -.->|"⏳ Queue changes"| QS
    QS -.->|"🔄 Sync when online"| SS
    
    %% Conflict Scenarios
    subgraph "⚠️ Conflict Scenarios"
        S1[Scenario 1:<br/>Same todo edited<br/>on different devices]
        S2[Scenario 2:<br/>Delete vs Modify<br/>conflict]
        S3[Scenario 3:<br/>Field-level<br/>conflicts]
        CD[Conflict Detection<br/>via Vector Clocks]
    end
    
    S1 --> CD
    S2 --> CD
    S3 --> CD
    CD --> CR
    
    %% Data Consistency
    subgraph "✅ Data Consistency"
        EC[Eventual Consistency]
        CP[Causal Preservation]
        CD[Conflict Detection]
        AR[Automatic Resolution]
    end
    
    VCM --> CP
    CP --> EC
    CR --> CD
    CD --> AR
    AR --> EC
    
    %% Performance Optimizations
    subgraph "🚀 Performance Features"
        LC[Local Caching]
        IU[Incremental Updates]
        BS[Batch Synchronization]
        CD[Change Detection]
    end
    
    LDA --> LC
    LDB --> LC
    LDC --> LC
    LC --> IU
    IU --> BS
    BS --> CD
    
    %% Styling
    classDef device fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef cloud fill:#f1f8e9,stroke:#558b2f,stroke-width:2px
    classDef network fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef process fill:#fce4ec,stroke:#ad1457,stroke-width:2px
    classDef offline fill:#efebe9,stroke:#5d4037,stroke-width:2px
    classDef conflict fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef consistency fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef performance fill:#f3e5f5,stroke:#6a1b9a,stroke-width:2px
    
    class UA,UIA,LDA,VCA,UB,UIB,LDB,VCB,UC,UIC,LDC,VCC device
    class FS,TC,DC,CC,RS,PS,OH cloud
    class HTTP,WS,CM network
    class SS,CR,VCM,DM,RTS,PBS,ES process
    class OA,OB,OC,LS,QS offline
    class S1,S2,S3,CD conflict
    class EC,CP,AR consistency
    class LC,IU,BS performance
```

### Distributed System Features:

- **📱 Multi-Device Support**: Seamless synchronization across devices
- **📡 Real-time Updates**: Instant propagation of changes
- **📵 Offline Resilience**: Local-first architecture with sync queuing
- **⚖️ Conflict Management**: Vector clock-based conflict detection
- **💓 Device Presence**: Heartbeat and coordination mechanisms
- **🚀 Performance Optimization**: Caching, batching, and incremental updates

---

## Key Architectural Features

### 🏗️ **Clean Architecture**
- **Domain Layer**: Pure business logic with rich entities
- **Data Layer**: Repository pattern with multiple data sources
- **Presentation Layer**: Reactive UI with state management
- **Dependency Inversion**: Interfaces define contracts

### 📵 **Offline-First Design**
- **Local-First Operations**: All actions work offline immediately
- **Background Synchronization**: Intelligent sync strategies
- **Conflict-Aware**: Handles concurrent offline modifications
- **Queue Management**: Pending changes stored locally

### ⚖️ **Sophisticated Conflict Resolution**
- **Vector Clock Tracking**: Causal ordering of distributed events
- **Smart Auto-Resolution**: 85% expected automatic resolution rate
- **Field-Level Analysis**: Granular conflict detection
- **User-Friendly UI**: Intuitive manual resolution interface

### 📡 **Real-Time Synchronization**
- **Firebase Streams**: Live updates via WebSocket connections
- **Fallback Mechanisms**: Graceful degradation to periodic sync
- **Connection Management**: Adaptive sync strategies based on connectivity
- **Device Heartbeat**: Presence tracking and coordination

### 🚀 **Performance Optimizations**
- **Local Caching**: SQLite database with Drift ORM
- **Incremental Updates**: Only sync changed data
- **Batch Operations**: Efficient bulk synchronization
- **Stream Controllers**: Reactive data flow management

### 🔒 **Data Consistency**
- **Eventual Consistency**: Guaranteed convergence across devices
- **Causal Preservation**: Maintains operation ordering
- **Conflict Detection**: Automatic identification of concurrent changes
- **Transaction Safety**: ACID properties in local database

### 🛠️ **Developer Experience**
- **Type Safety**: Strong typing with Dart and code generation
- **Code Generation**: Drift database, Riverpod providers, JSON serialization
- **Comprehensive Logging**: Detailed sync and conflict resolution logs
- **Testable Architecture**: Clean separation of concerns

---

## Technology Stack

- **Frontend**: Flutter with Material Design 3
- **State Management**: Riverpod with code generation
- **Local Database**: SQLite with Drift ORM
- **Remote Database**: Firebase Firestore
- **Real-time**: Firebase Firestore streams
- **Connectivity**: connectivity_plus package
- **Architecture**: Clean Architecture with Repository pattern
- **Conflict Resolution**: Custom vector clock implementation

---

## Getting Started

1. **Clone the repository**
2. **Install dependencies**: `flutter pub get`
3. **Set up Firebase**: Configure Firebase project and add configuration files
4. **Run the app**: `flutter run`
5. **Test multi-device**: Run on multiple devices/emulators to see sync in action

---

*This architecture provides a production-ready, enterprise-grade solution for offline-first collaborative applications with sophisticated conflict resolution capabilities.* 