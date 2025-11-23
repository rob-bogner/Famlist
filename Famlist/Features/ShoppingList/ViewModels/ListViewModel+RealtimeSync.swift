/*
 ListViewModel+RealtimeSync.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Extension managing real-time observation of items via repository streams.

 🛠 Includes:
 - startObserving (initiates background observation task)
 - handleAppDidBecomeActive/Background (lifecycle-driven sync control)
 - resumeRealtimeSync (reconnection logic when connectivity returns)

 🔰 Notes for Beginners:
 - Real-time observation runs in a background Task that yields item snapshots.
 - Pausing on background transition saves device resources.
 - Resume logic ensures the stream restarts when app becomes active or network reconnects.

 📝 Last Change:
 - Extracted from ListViewModel.swift to follow one-type-per-file rule and reduce file size.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides Task and async/await support.

// MARK: - Real-time Observation

extension ListViewModel {
    /// Starts (or restarts) the background observation of items for the current listId.
    internal func startObserving() {
        observeTask?.cancel()
        loadLocalSnapshot()
        hasObservedActiveList = true
        
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in repository.observeItems(listId: listId) {
                await MainActor.run {
                    // Note: Bulk operation suppression is now handled at the repository level
                    // via suppressRealtimeFetches flag, so snapshots won't arrive during bulk ops.
                    let merged = self.mergeRemoteSnapshot(snapshot)
                    
                    // Prevent unnecessary UI updates if the data hasn't effectively changed.
                    // This is crucial for avoiding "double jumps" or jitters when the server
                    // confirms an optimistic update that is already displayed correctly.
                    if self.items != merged {
                        self.applyItems(merged)
                    }
                    
                    self.persistRemoteSnapshot(snapshot)
                }
            }
        }
    }
    
    /// Signals that the app moved into the foreground so realtime sync should resume if it was suspended.
    func handleAppDidBecomeActive() {
        resumeRealtimeSync(trigger: .appForeground)
    }
    
    /// Signals that the app transitioned to background so realtime observation can pause to save resources.
    func handleAppDidEnterBackground() {
        guard observeTask != nil else { return }
        logVoid(params: (
            action: "pauseRealtimeSync",
            listId: listId,
            reason: "background"
        ))
        UserLog.Sync.realtimePaused(listName: defaultList?.title)
        observeTask?.cancel()
        observeTask = nil
    }
    
    /// Restarts realtime observation if a prior observation existed and logs the trigger for debugging.
    internal func resumeRealtimeSync(trigger: ResumeTrigger) {
        guard hasObservedActiveList else { return }
        logVoid(params: (
            action: "resumeRealtimeSync",
            listId: listId,
            trigger: trigger.rawValue
        ))
        UserLog.Sync.realtimeResumed(listName: defaultList?.title)
        startObserving()
    }
}

