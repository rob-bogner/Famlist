/*
 ReceiptArchive+Sync.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Senden der Archiv-Warteschlange an Supabase (Anlegen: Fotos, dann Zeile; Löschen: Fotos, dann Zeile).

 🔰 Notes for Beginners:
 - Netzfehler (URLError) → Auftrag bleibt, Senden stoppt; beim nächsten „wieder online“ geht es weiter.
 - Andere Fehler (z. B. vom Server abgelehnt, weil man die Liste verlassen hat) → nach `maxFailures`
   Versuchen verworfen, damit die Warteschlange nicht für immer hängen bleibt. Die lokalen Fotos eines
   verworfenen Bons werden gelöscht.
 - Es läuft immer nur ein Durchgang (`flushTask`); weitere Aufrufe warten auf ihn.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

extension ReceiptArchive {
    /// Sendet die Warteschlange der Reihe nach. Läuft schon ein Durchgang, wird auf ihn gewartet.
    func flush() async {
        while let running = flushTask { await running.value }
        guard repository != nil, !store.outbox.isEmpty else { return }
        let task = Task { await self.drain(); self.flushTask = nil }
        flushTask = task
        await task.value
    }

    private func drain() async {
        while let pending = store.outbox.first, !Task.isCancelled {
            do {
                try await send(pending.operation)
                store.remove(pending.operation)
                finish(pending.operation)
            } catch let error as URLError {
                logVoid(params: (action: "receiptArchive.flush.offline", code: error.code.rawValue,
                                 pending: store.outbox.count))
                return
            } catch {
                logVoid(params: (action: "receiptArchive.flush.rejected", failures: pending.failures + 1,
                                 error: (error as NSError).localizedDescription))
                guard pending.failures + 1 >= Self.maxFailures else { store.recordFailure(pending.operation); return }
                store.remove(pending.operation)
                store.removePhotos(paths: pending.operation.receipt.photoPaths)
                publish()
            }
        }
    }

    private func send(_ operation: ReceiptArchiveLocalStore.Operation) async throws {
        guard let repository else { throw URLError(.notConnectedToInternet) }
        let receipt = operation.receipt
        switch operation {
        case .create:
            for path in receipt.photoPaths {
                guard let data = store.photo(path: path) else { throw ReceiptArchiveError.photoMissing(path) }
                try await repository.uploadPhoto(data, path: path)
            }
            try await repository.insert(receipt)
        case .delete:
            try await repository.removePhotos(paths: receipt.photoPaths)
            try await repository.delete(id: receipt.id)
        }
    }

    /// Nach Erfolg: Fotos in den Cache (Anlegen) bzw. lokal löschen (Löschen), Anzeige aktualisieren.
    private func finish(_ operation: ReceiptArchiveLocalStore.Operation) {
        let receipt = operation.receipt
        mutations += 1
        switch operation {
        case .create:
            store.movePendingPhotosToCache(paths: receipt.photoPaths)
            // Wurde der Bon während des Hochladens gelöscht, wartet schon ein Löschauftrag → nicht anzeigen.
            let deleting = store.outbox.contains { if case .delete(let r) = $0.operation { r.id == receipt.id } else { false } }
            if !deleting {
                var uploaded = receipt
                uploaded.isPending = false
                store.addToCache(uploaded)
            }
        case .delete:
            store.removePhotos(paths: receipt.photoPaths)
        }
        publish()
    }
}
