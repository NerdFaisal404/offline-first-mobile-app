# Mesh Networking Architecture for Distributed Todo App

## Overview

This document outlines the mesh networking architecture that extends the existing offline-first todo application to enable peer-to-peer synchronization when devices are on the same WiFi/WLAN network, without requiring internet connectivity.

## Table of Contents

1. [Mesh Networking Concepts](#mesh-networking-concepts)
2. [Architecture Overview](#architecture-overview)
3. [Core Components](#core-components)
4. [Network Topology](#network-topology)
5. [Data Synchronization Flow](#data-synchronization-flow)
6. [Implementation Plan](#implementation-plan)
7. [Integration with Existing System](#integration-with-existing-system)

## Mesh Networking Concepts

### What is Mesh Networking?
Mesh networking creates a decentralized network where devices communicate directly with each other without requiring a central server. In our context, devices on the same WiFi network can discover each other and synchronize todo data peer-to-peer.

### Key Benefits
- **Offline Operation**: Works without internet connectivity
- **Resilience**: No single point of failure
- **Low Latency**: Direct device-to-device communication
- **Scalability**: Automatically adapts to network changes
- **Privacy**: Data stays within local network

## Architecture Overview

```mermaid
graph TB
    %% Network Layer
    subgraph "Local WiFi Network"
        D1[Device 1<br/>iPhone]
        D2[Device 2<br/>Android]
        D3[Device 3<br/>Laptop]
        D4[Device 4<br/>iPad]
        
        D1 <--> D2
        D1 <--> D3
        D2 <--> D3
        D2 <--> D4
        D3 <--> D4
    end
    
    %% External Connectivity
    subgraph "Internet"
        FB[Firebase<br/>Cloud Sync]
    end
    
    %% Connection to internet when available
    D1 -.-> FB
    D2 -.-> FB
    D3 -.-> FB
    D4 -.-> FB
    
    style D1 fill:#e1f5fe
    style D2 fill:#e8f5e8
    style D3 fill:#fff3e0
    style D4 fill:#f3e5f5
    style FB fill:#ffebee
```

## Core Components

### 1. Mesh Discovery Service

Handles device discovery and network topology management.

```mermaid
classDiagram
    class MeshDiscoveryService {
        -NetworkScanner _scanner
        -List~MeshPeer~ _discoveredPeers
        -String _deviceId
        -Timer? _discoveryTimer
        -Timer? _heartbeatTimer
        +start() Future~void~
        +stop() void
        +scanForPeers() Future~List~MeshPeer~~
        +broadcastPresence() Future~void~
        +getAvailablePeers() List~MeshPeer~
        +onPeerDiscovered(peer) void
        +onPeerLost(peer) void
        -_startPeriodicDiscovery() void
        -_startHeartbeat() void
        -_validatePeer(peer) bool
    }
    
    class MeshPeer {
        +String deviceId
        +String deviceName
        +String ipAddress
        +int port
        +DateTime lastSeen
        +PeerCapabilities capabilities
        +PeerStatus status
        +toJson() Map
        +fromJson(json) MeshPeer
    }
    
    class NetworkScanner {
        +scanLocalNetwork() Future~List~String~~
        +pingHost(ip) Future~bool~
        +probePort(ip, port) Future~bool~
        +getLocalIP() Future~String~
        +getNetworkPrefix() Future~String~
    }
    
    MeshDiscoveryService --> MeshPeer
    MeshDiscoveryService --> NetworkScanner
```

### 2. Mesh Communication Layer

Handles peer-to-peer communication and message routing.

```mermaid
classDiagram
    class MeshCommunicationService {
        -ServerSocket? _server
        -Map~String,Socket~ _peerConnections
        -MessageRouter _router
        -EncryptionService _encryption
        +startServer(port) Future~void~
        +connectToPeer(peer) Future~bool~
        +sendMessage(peerId, message) Future~bool~
        +broadcastMessage(message) Future~void~
        +disconnectFromPeer(peerId) void
        +onMessageReceived(message) void
        -_handleIncomingConnection(socket) void
        -_maintainConnection(peerId) void
    }
    
    class MeshMessage {
        +String id
        +String senderId
        +String recipientId
        +MessageType type
        +Map~String,dynamic~ payload
        +DateTime timestamp
        +int ttl
        +List~String~ routingPath
        +String checksum
        +toJson() Map
        +fromJson(json) MeshMessage
    }
    
    class MessageRouter {
        +route(message, availablePeers) List~String~
        +isMessageForMe(message) bool
        +shouldForward(message) bool
        +updateRoutingTable(peerId, hop) void
        +getOptimalPath(targetId) List~String~
    }
    
    MeshCommunicationService --> MeshMessage
    MeshCommunicationService --> MessageRouter
```

### 3. Mesh Sync Service

Orchestrates data synchronization across the mesh network.

```mermaid
classDiagram
    class MeshSyncService {
        -MeshDiscoveryService _discovery
        -MeshCommunicationService _communication
        -TodoRepository _todoRepository
        -ConflictResolver _conflictResolver
        -SyncStrategy _strategy
        +startMeshSync() Future~void~
        +stopMeshSync() void
        +syncWithPeer(peerId) Future~SyncResult~
        +syncWithAllPeers() Future~List~SyncResult~~
        +handleSyncRequest(request) Future~SyncResponse~
        +handleSyncResponse(response) Future~void~
        -_negotiateSync(peerId) Future~SyncPlan~
        -_executeSync(plan) Future~SyncResult~
        -_handleConflicts(conflicts) Future~void~
    }
    
    class SyncStrategy {
        <<enumeration>>
        FULL_SYNC
        INCREMENTAL_SYNC
        VECTOR_CLOCK_SYNC
        GOSSIP_PROTOCOL
    }
    
    class SyncPlan {
        +String peerId
        +SyncStrategy strategy
        +List~String~ todosToSend
        +List~String~ todosToRequest
        +DateTime lastSyncTime
        +VectorClock lastKnownClock
    }
    
    MeshSyncService --> SyncStrategy
    MeshSyncService --> SyncPlan
```

## Network Topology

### 1. Flat Mesh Network
All devices are equal peers that can communicate directly.

```mermaid
graph LR
    A[Device A] <--> B[Device B]
    B <--> C[Device C]
    C <--> D[Device D]
    D <--> A
    A <--> C
    B <--> D
    
    style A fill:#e1f5fe
    style B fill:#e8f5e8
    style C fill:#fff3e0
    style D fill:#f3e5f5
```

### 2. Bridge Network (for larger deployments)
Some devices act as bridges to extend network reach.

```mermaid
graph TB
    subgraph "Network Segment 1"
        A[Device A] <--> B[Device B]
        B <--> C[Device C]
    end
    
    subgraph "Network Segment 2"
        D[Device D] <--> E[Device E]
        E <--> F[Device F]
    end
    
    C -.->|Bridge| D
    
    style C fill:#ffcdd2
    style D fill:#ffcdd2
```

## Data Synchronization Flow

### 1. Discovery and Connection Flow

```mermaid
sequenceDiagram
    participant A as Device A
    participant B as Device B
    participant C as Device C
    
    Note over A,C: Network Discovery Phase
    A->>+A: Start mesh discovery
    A->>Network: Broadcast presence
    B->>Network: Broadcast presence
    C->>Network: Broadcast presence
    
    A->>B: Discover peer B
    A->>C: Discover peer C
    B->>C: Discover peer C
    
    Note over A,C: Connection Establishment
    A->>B: Connect request
    B->>A: Accept connection
    A->>C: Connect request
    C->>A: Accept connection
    B->>C: Connect request
    C->>B: Accept connection
    
    Note over A,C: Ready for sync
```

### 2. Sync Negotiation Flow

```mermaid
sequenceDiagram
    participant A as Device A
    participant B as Device B
    
    Note over A,B: Sync Negotiation
    A->>B: SyncRequest(lastKnownClock)
    B->>B: Analyze local state
    B->>A: SyncResponse(plan, metadata)
    
    Note over A,B: Data Exchange
    A->>B: SendTodos(todoList)
    B->>B: Process & resolve conflicts
    B->>A: SendTodos(todoList)
    A->>A: Process & resolve conflicts
    
    Note over A,B: Confirmation
    A->>B: SyncComplete(status)
    B->>A: SyncAck(status)
```

### 3. Conflict Resolution in Mesh

```mermaid
flowchart TD
    A[Receive Todo from Peer] --> B{Local Todo Exists?}
    B -->|No| C[Add to Local DB]
    B -->|Yes| D{Vector Clock Comparison}
    
    D -->|Remote is newer| E[Update local with remote]
    D -->|Local is newer| F[Send local to peer]
    D -->|Concurrent| G[Conflict Resolution]
    
    G --> H{Auto-resolvable?}
    H -->|Yes| I[Apply auto-resolution]
    H -->|No| J[Store as conflict for manual resolution]
    
    C --> K[Update Vector Clock]
    E --> K
    I --> K
    F --> K
    J --> K
    
    K --> L[Propagate to other peers]
```

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1-2)

1. **Network Discovery**
   - Implement mDNS/Bonjour service discovery
   - Local network scanning functionality
   - Peer capabilities negotiation

2. **Basic Communication**
   - TCP socket server/client implementation
   - Message serialization/deserialization
   - Basic error handling and retries

### Phase 2: Sync Mechanism (Week 3-4)

1. **Extend Existing Sync Service**
   - Add mesh sync capabilities to existing `SyncService`
   - Implement peer-to-peer sync protocols
   - Integrate with existing vector clock system

2. **Conflict Resolution Enhancement**
   - Adapt existing `ConflictResolver` for mesh scenarios
   - Handle multi-peer conflicts
   - Implement gossip protocol for conflict propagation

### Phase 3: Advanced Features (Week 5-6)

1. **Topology Management**
   - Dynamic peer discovery
   - Connection health monitoring
   - Automatic reconnection

2. **Performance Optimization**
   - Incremental sync based on vector clocks
   - Data compression for large payloads
   - Connection pooling and reuse

### Phase 4: Integration & Testing (Week 7-8)

1. **UI Integration**
   - Mesh status indicators
   - Peer visibility in app
   - Manual sync triggers

2. **Comprehensive Testing**
   - Multi-device testing scenarios
   - Network failure simulation
   - Performance benchmarking

## Integration with Existing System

### 1. Enhanced Sync Service

```dart
class EnhancedSyncService extends SyncService {
  final MeshSyncService _meshSync;
  
  @override
  Future<void> start() async {
    await super.start(); // Start Firebase sync
    await _meshSync.startMeshSync(); // Start mesh sync
  }
  
  @override
  Future<SyncResult> forceSync() async {
    final results = await Future.wait([
      super.forceSync(), // Firebase sync
      _meshSync.syncWithAllPeers(), // Mesh sync
    ]);
    
    return SyncResult.combined(results);
  }
}
```

### 2. Extended Todo Entity

The existing `Todo` entity already has everything needed for mesh networking:
- Device ID tracking
- Vector clocks for causality
- Conflict resolution metadata
- Version management

### 3. Hybrid Sync Strategy

```mermaid
flowchart TD
    A[App Starts] --> B{Internet Available?}
    B -->|Yes| C[Start Firebase Sync]
    B -->|No| D[Start Mesh-Only Mode]
    
    C --> E{Peers Available?}
    E -->|Yes| F[Start Hybrid Mode<br/>Firebase + Mesh]
    E -->|No| G[Firebase-Only Mode]
    
    D --> H{Peers Available?}
    H -->|Yes| I[Mesh-Only Mode]
    H -->|No| J[Offline-Only Mode]
    
    F --> K[Optimal Sync Experience]
    G --> L[Cloud Sync Only]
    I --> M[Local Network Sync]
    J --> N[Local Storage Only]
    
    style K fill:#c8e6c9
    style L fill:#fff3e0
    style M fill:#e1f5fe
    style N fill:#ffcdd2
```

## Security Considerations

### 1. Network Security
- **Device Authentication**: Use device certificates or shared secrets
- **Message Encryption**: Encrypt all peer-to-peer communications
- **Network Isolation**: Only sync with trusted devices

### 2. Data Integrity
- **Message Signing**: Sign all sync messages with device keys
- **Checksums**: Verify data integrity during transmission
- **Version Validation**: Ensure vector clock consistency

### 3. Privacy Protection
- **Local Network Only**: Never expose data beyond local network
- **Opt-in Sharing**: Require explicit user consent for mesh participation
- **Data Minimization**: Only share necessary synchronization data

## Required Dependencies

Add these to `pubspec.yaml`:

```yaml
dependencies:
  # Networking
  network_info_plus: ^4.1.0  # Network interface discovery
  nsd: ^2.0.0               # Network service discovery (mDNS)
  
  # Security
  crypto: ^3.0.3            # Cryptographic functions
  pointycastle: ^3.7.3      # Advanced cryptography
  
  # Utilities
  uuid: ^4.1.0              # UUID generation
  collection: ^1.17.2       # Advanced collections
```

## Performance Considerations

### 1. Bandwidth Optimization
- **Delta Sync**: Only send changes since last sync
- **Compression**: Use gzip for large payloads
- **Batching**: Group multiple operations

### 2. Memory Management
- **Connection Pooling**: Reuse TCP connections
- **Message Queuing**: Buffer messages during network issues
- **Cache Management**: Smart caching of peer data

### 3. Battery Optimization
- **Adaptive Discovery**: Reduce scanning frequency when stable
- **Background Limits**: Minimize background network activity
- **Connection Reuse**: Avoid frequent connection establishment

This architecture provides a robust foundation for mesh networking while leveraging your existing sophisticated conflict resolution and vector clock systems. The implementation can be done incrementally, starting with basic peer discovery and building up to full mesh synchronization capabilities. 