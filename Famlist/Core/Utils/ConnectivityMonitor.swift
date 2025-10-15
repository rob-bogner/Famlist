/*
 ConnectivityMonitor.swift
 GroceryGenius
 Created on: 15.10.2025
 Last updated on: 15.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Lightweight network reachability monitor that publishes online/offline state across the app.
 🛠 Includes: Shared ConnectivityMonitor singleton using NWPathMonitor and a published isOnline flag.
 🔰 Notes for Beginners: Use the shared instance to observe connectivity changes and trigger sync retries when connectivity returns.
 📝 Last Change: Initial creation to support automatic resubscription of realtime sync after backgrounding or offline periods.
 ------------------------------------------------------------------------
*/

import Foundation // Provides base types like DispatchQueue used for the monitor queue.
import Network // Exposes NWPathMonitor for reachability callbacks.
import Combine // Supplies @Published and ObservableObject conformance.

/// Publishes connectivity changes so view models can resume realtime sync when the device comes back online.
@MainActor
final class ConnectivityMonitor: ObservableObject { // ObservableObject lets SwiftUI/Combine subscribers react to network status.
    /// Shared instance used throughout the app to avoid multiple NWPathMonitor instances.
    static let shared = ConnectivityMonitor() // Static singleton to keep monitor lifetime tied to app lifecycle.

    /// Indicates whether the current network path is considered online (.satisfied).
    @Published private(set) var isOnline: Bool = true // Published property emits changes to subscribers.

    private let monitor: NWPathMonitor // Underlying system reachability monitor.
    private let queue: DispatchQueue // Serial queue where NWPathMonitor delivers updates.

    /// Sets up the NWPathMonitor and begins listening for path updates.
    private init() { // Private to enforce singleton usage via ConnectivityMonitor.shared.
        self.monitor = NWPathMonitor() // Instantiate monitor with default interface filter (all interfaces).
        self.queue = DispatchQueue(label: "ConnectivityMonitorQueue") // Serial queue for monitor callbacks.
        monitor.pathUpdateHandler = { [weak self] path in // Receive connectivity changes from the monitor.
            guard let self else { return } // Ensure self still exists.
            Task { @MainActor in // Hop back to main actor to update published state safely.
                self.isOnline = path.status == .satisfied // Update online flag when path is satisfied.
            }
        }
        monitor.start(queue: queue) // Begin monitoring on the dedicated queue.
    }
}
