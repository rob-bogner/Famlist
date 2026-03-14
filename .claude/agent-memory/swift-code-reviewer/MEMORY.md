# Swift Code Reviewer -- Agent Memory

## Architecture Overview
- MVVM with SwiftData (local-first) + Supabase (remote)
- CRDT-based sync with HLC (Hybrid Logical Clock) for conflict resolution
- SyncEngine orchestrates offline queue, retry with exponential backoff
- Repository pattern: protocols in `Repositories/Protocols/`, Supabase impls in `Repositories/Implementations/`
- ListViewModel split into extensions: +Persistence, +RealtimeSync, +BulkActions, +Projections, +InputHelpers

## Key Patterns & Conventions
- `@MainActor` used extensively on ViewModels, stores, sync components
- Two logging systems: `logVoid`/`logResult` (dev) + `UserLog.*` (user-facing, German)
- `OperationQueue` name collides with Foundation's OperationQueue (custom SwiftData-based)
- `ConnectivityMonitor` and `ImageCache` are singletons
- Timer-based queue processing in SyncEngine (5s interval)
- Preview repos in `PreviewRepositories.swift` (multiple types in one file -- convention violation)

## Recurring Issues Found (2026-03-02 Full Review)
- Fire-and-forget `Task {}` without cancellation tracking (SupabaseClient, AppSessionViewModel, ListViewModel)
- `unowned` reference to ListViewModel in AppSessionViewModel without lifetime guarantee
- SupabaseItemsRepository not marked `@MainActor` but has `@MainActor` properties -- partial isolation
- `RealtimeEventProcessor` not `@MainActor` but calls `@MainActor` dependencies via method annotations
- ISO8601DateFormatter created inside loops (RealtimeEventProcessor.parseItemFromPayload)
- `SyncStatus` enum defined in same file as `SyncEngine` (one-type-per-file violation)
- `SortOrder` enum defined in same file as BulkActions extension
- `ListViewModel` is `class` not `final class`
- `ConflictResolver.resolveFieldLevel` has repetitive per-field code -- should use reflection or KeyPath
