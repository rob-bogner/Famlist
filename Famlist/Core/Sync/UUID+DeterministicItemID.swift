/*
 UUID+DeterministicItemID.swift

 Famlist
 Created on: 08.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Extends UUID with a deterministic ID generator for shopping list items.
 - Enables CRDT-based deduplication of items with the same name in the same list.

 🛠 Includes:
 - deterministicItemID(listId:name:) – SHA-256-based UUID derived from listId + name.

 🔰 Design Rationale (ADR-005):
 - When two devices simultaneously call createItem("Milch") for the same list,
   each generates a random UUID, resulting in two distinct CRDT entities and a duplicate.
 - By deriving the UUID deterministically from (listId, name), both devices produce
   the same UUID. The CRDT LWW-mechanism then treats it as a conflict on the same
   entity and resolves it via HLC – no duplicate is created.
 - See Confluence ADR-005 for full decision record.

 ⚠️ Trade-offs:
 - Items with the same name in the same list are treated as the same entity.
 - Intentional duplicates (e.g., "Milch" × 2 for different purposes) are not supported.
 - Name changes require the old item to be tombstoned and a new item created.
 ------------------------------------------------------------------------
*/

import CryptoKit
import Foundation

extension UUID {

    /// Derives a deterministic, stable UUID for a shopping list item
    /// based on the owning list's UUID and the item's normalized name.
    ///
    /// Both devices creating an item named "Milch" in the same list
    /// will produce the **same UUID**, allowing CRDT Last-Write-Wins
    /// to merge the concurrent creations into a single entity.
    ///
    /// - Parameters:
    ///   - listId: UUID of the list that owns this item.
    ///   - name: Display name of the item (case-insensitive, whitespace-trimmed).
    /// - Returns: A stable UUID v5-style identifier.
    static func deterministicItemID(listId: UUID, name: String) -> UUID {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespaces)
        let input = "\(listId.uuidString):\(normalizedName)"
        let hash = SHA256.hash(data: Data(input.utf8))

        // Map first 16 bytes of SHA-256 digest to a UUID
        var bytes = Array(hash.prefix(16))

        // Set version nibble to 5 (UUID v5 convention for name-based UUIDs)
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        // Set RFC 4122 variant bits
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0],  bytes[1],  bytes[2],  bytes[3],
            bytes[4],  bytes[5],  bytes[6],  bytes[7],
            bytes[8],  bytes[9],  bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
