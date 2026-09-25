/*
 SyncEngine+Images.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hochladen geänderter Artikelfotos nach Supabase Storage, bevor die SyncEngine einen Auftrag sendet.

 📝 Last Change:
 - Aus SyncEngine.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension SyncEngine {
    /// Lädt das Foto eines Auftrags hoch und liefert seinen Storage-Pfad (nil = kein Foto).
    /// Der Pfad wird auch lokal eingetragen, solange dort noch dasselbe Foto liegt.
    func uploadImage(of snapshot: ItemModel) async throws -> String? {
        guard let base64 = snapshot.imageData, let listIdString = snapshot.listId,
              let listId = UUID(uuidString: listIdString),
              let object = ProductImageCodec.storageObject(folder: listId, base64: base64) else { return nil }
        guard let imageStorage else { return snapshot.imagePath }
        try await imageStorage.upload(object.data, bucket: ProductImageCodec.itemBucket, path: object.path)
        if let uuid = UUID(uuidString: snapshot.id), let entity = try? itemStore.fetchItem(id: uuid),
           entity.imageData == base64 {
            entity.imagePath = object.path
        }
        return object.path
    }
}
