// filepath: GroceryGenius/Service/DefaultUserIdService.swift
// MARK: - DefaultUserIdService
// Provides stable public id provisioning with persistence in Keychain and optional iCloud KVS fallback.

import Foundation

final class DefaultUserIdService: UserIdService {
    private let allocationRepo: IdAllocationRepository
    private let keychainKey = "gg.publicId"
    private let ubiquitousKey = "publicId"
    private let deviceKeyKey = "gg.deviceKey"

    init(allocationRepo: IdAllocationRepository = FirestoreIdAllocationRepository()) {
        self.allocationRepo = allocationRepo
    }

    func currentLocalId() -> PublicUserId? {
        if let raw = KeychainHelper.getString(keychainKey), !raw.isEmpty { return PublicUserId(raw) }
        return nil
    }

    func getOrCreatePublicId() async throws -> PublicUserId {
        // 1) Keychain
        if let existing = currentLocalId() { return existing }
        // 2) iCloud KVS
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.synchronize()
        if let cloud = kvs.string(forKey: ubiquitousKey), !cloud.isEmpty {
            // mirror to keychain and return
            _ = KeychainHelper.setString(cloud, keychainKey)
            return PublicUserId(cloud)
        }
        // 3) Allocate via backend atomically
        let deviceKey = ensureDeviceKey()
        let fresh = try await allocationRepo.allocatePublicId(deviceKey: deviceKey)
        // Persist locally
        _ = KeychainHelper.setString(fresh.value, keychainKey)
        kvs.set(fresh.value, forKey: ubiquitousKey)
        kvs.synchronize()
        return fresh
    }

    // Generate or retrieve a stable device key for audit mapping (no UIKit)
    private func ensureDeviceKey() -> String {
        if let dk = KeychainHelper.getString(deviceKeyKey), !dk.isEmpty { return dk }
        let new = UUID().uuidString
        _ = KeychainHelper.setString(new, deviceKeyKey)
        return new
    }
}
