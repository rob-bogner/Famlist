/*
 ListViewModel+RemoteImage.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Produktbild aus dem globalen Katalog nachladen (Suche „Weitere Produkte“, Barcode-Scanner, Artikelstamm
   mit gemerkter Bildadresse).

 🔰 Notes for Beginners:
 - Offline-First: addItem legt den Artikel sofort an und ruft danach `loadRemoteImageIfNeeded` auf. Das Bild
   wird im Hintergrund geladen und über updateItem nachgetragen – damit landet es auch im Artikelstamm und wird
   wie ein Kamerafoto synchronisiert.
 - Nachgetragen wird nur, wenn der offene Artikel mit diesem Namen dann noch kein Foto hat. So überschreibt
   das Katalogbild nie ein eigenes Foto (auch nicht eines, das inzwischen ein Familienmitglied gesetzt hat).
 - Klappt das Laden nicht (kein Netz), bleibt die Adresse im Artikelstamm (Migration 035); beim nächsten
   Hinzufügen wird es erneut versucht.

 📝 Last Change:
 - 30.09.2026: Einstieg über addItem(remoteImageURL:) statt eigener Methode; Adresse im Artikelstamm.
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {
    /// Lädt das Bild von `remoteImageURL` und trägt es beim Artikel ein – nur, wenn `item` kein Foto hat.
    func loadRemoteImageIfNeeded(for item: ItemModel, from remoteImageURL: String?) {
        guard Self.hasNoImage(item), let remoteImageURL, RemoteProductImage.allowedURL(remoteImageURL) != nil else { return }
        let key = ItemIdentity.normalizedKey(item.name)
        let loader = remoteImageLoader
        Task { [weak self] in
            guard let base64 = await loader(remoteImageURL) else { return }
            self?.attachRemoteImage(base64, toItemWithKey: key)
        }
    }

    /// Trägt das geladene Bild beim offenen Artikel mit diesem Namen ein – nur, wenn er noch kein Foto hat.
    func attachRemoteImage(_ base64: String, toItemWithKey key: String) {
        guard let current = items.first(where: { ItemIdentity.normalizedKey($0.name) == key && !$0.isChecked }),
              Self.hasNoImage(current) else { return }
        var updated = current
        updated.imageData = base64
        logVoid(params: (action: "attachRemoteImage", itemId: updated.id))
        updateItem(updated, suppressUserLog: true)
    }

    private static func hasNoImage(_ item: ItemModel) -> Bool {
        let data = item.imageData?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let path = item.imagePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return data.isEmpty && path.isEmpty
    }
}
