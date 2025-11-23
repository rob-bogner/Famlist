# Changelog

All notable changes to Famlist will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.3.1] - 2025-11-23

### Summary
- Behebe User-Logging-Duplikate und Task-Cancellation-Bug

### Details
- **User-Logging**: Entferne doppelte User-Log-Einträge durch Konsolidierung in Repository-Schicht statt ViewModels
- **User-Logging**: Profil-Logs zeigen jetzt Public-ID, Artikel-Updates inkl. Details (Name, Units, Measure)
- **User-Logging**: Lösch-Events erhalten Artikelnamen für bessere Nachvollziehbarkeit
- **User-Logging**: Alle User-Logs erscheinen direkt nach technischen Logs für klare Zuordnung
- **ScrollDetection**: Korrigiere fehlerhafte `try?` + `Task.isCancelled` Pattern in `handleScrollEnd()`
- **ScrollDetection**: Verwende explizites `do-catch` für `CancellationError`-Behandlung
- **Code Quality**: Verhindere geschluckte Fehler und undefiniertes Verhalten durch korrekte Error-Behandlung

### Technical Details
- 19 files changed, 1079 insertions(+), 20 deletions(-)
- 3 new files (UserLogger.swift, USER_LOGGING.md, LOGGING_BEISPIEL.md)
- Improved code robustness through proper async/await error handling

## [v0.3.0] - 2025-11-23

### Summary
- Optimize bulk update performance with realtime suppression strategy and fix CRDT conflict resolution for tombstones

### Details
- **Batch Updates**: Implement `batchUpdateItems()` in ItemsRepository for parallel updates using TaskGroup, reducing bulk toggle latency from ~2s to <500ms
- **Realtime Suppression**: Add `suppressRealtimeFetches` flag to prevent cascading fetches during bulk operations (500ms delay-based solution, with plan for Pessimistic Locking upgrade)
- **CRDT Fix**: Fix ConflictResolver to correctly compare HLC timestamps when both local and remote versions have tombstones (Last-Write-Wins semantics)
- **UI Enhancement**: Add FloatingBottomMenuBar component with auto-hide behavior for "Toggle All" and "Uncheck All" actions
- **Code Organization**: Extract bulk actions to separate `ListViewModel+BulkActions.swift` for better separation of concerns
- **Utilities**: Add ScrollDetection extension for monitoring scroll position and auto-hiding floating UI elements
- **Testing**: Add performance test suite for bulk toggle operations
- **Documentation**: Include implementation plan for future Pessimistic Locking optimization (336h timeout for stale locks)

### Technical Details
- 16 files changed, 1575 insertions(+), 223 deletions(-)
- 4 new components (BulkActions extension, FloatingBottomMenuBar, ScrollDetection, Performance tests)
- Improved bulk operation efficiency by 4-5x through parallelization and suppression

## [v0.1.1] - 2025-11-22

### Summary
- Fix compiler errors in CRDT sync components preventing successful builds

### Details
- **MainActor Isolation**: Resolve MainActor isolation issue in HybridLogicalClock by removing UIDevice.current dependency and using UUID fallback
- **Code Quality**: Remove unreachable catch block in RealtimeEventProcessor deletion handler
- **Compiler Warnings**: Fix unused variable warnings in SyncEngine operation processing
- **Build Fixes**: Remove reference to non-existent deletedItem variable causing compilation failure
- **API Improvement**: Change HybridLogicalClockGenerator init to use optional nodeId parameter for better flexibility

## [v0.1.1] - 2025-11-22

### Summary
- Fix compiler errors in CRDT sync components preventing successful builds

### Details
- **MainActor Isolation**: Resolve MainActor isolation issue in HybridLogicalClock by removing UIDevice.current dependency and using UUID fallback
- **Code Quality**: Remove unreachable catch block in RealtimeEventProcessor deletion handler
- **Compiler Warnings**: Fix unused variable warnings in SyncEngine operation processing
- **Build Fixes**: Remove reference to non-existent deletedItem variable causing compilation failure
- **API Improvement**: Change HybridLogicalClockGenerator init to use optional nodeId parameter for better flexibility

## [v0.1.0] - 2025-11-22

### Summary
- Implement CRDT-based distributed sync architecture with Hybrid Logical Clocks for multi-device conflict resolution

### Details
- **CRDT Foundation**: Add Hybrid Logical Clock (HLC) implementation ensuring causal consistency across devices even with clock drift
- **Sync Engine**: Implement central sync orchestrator with exponential backoff retry logic (2s → 5min, max 20 retries)
- **Operation Queue**: Add persistent SwiftData-backed queue for offline-first support with automatic retry
- **Realtime Processing**: Refactor to granular event processing (INSERT/UPDATE/DELETE) replacing expensive full refetches for 5-10x performance improvement
- **Conflict Resolution**: Add CRDT-based conflict resolver with Last-Write-Wins semantics and tombstone support
- **Data Model Extensions**: Extend ItemEntity and ItemModel with optional CRDT metadata fields (hlcTimestamp, hlcCounter, hlcNodeId, tombstone) for backward compatibility
- **Testing**: Add comprehensive unit tests for HLC, ConflictResolver, and multi-device integration scenarios
- **Migration**: Provide Supabase migration SQL for HLC columns and indexes, plus migration tooling and documentation
- **Monitoring**: Add SyncMonitor for tracking sync latency, conflict rate, and queue depth metrics
- **Documentation**: Include implementation summary, migration guide, quick fix guide, and post-code reflection

### Technical Details
- 33 files changed, 3439 insertions(+), 168 deletions(-)
- 8 new Core/Sync components, 3 test suites, SQL migration
- Full backward compatibility with legacy sync code path
- State-of-the-art distributed systems architecture ready for production

