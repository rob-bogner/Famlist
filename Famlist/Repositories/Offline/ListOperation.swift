/*
 ListOperation.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein wartender Listen-Auftrag (Offline-First): Anlegen, Umbenennen, Löschen, Standard setzen,
   Verlassen. Wird lokal sofort angewendet und später an den Server gesendet.

 🔰 Notes for Beginners:
 - `apply(to:)` zeigt, wie die Listen NACH dem Auftrag aussehen – so sieht die Oberfläche offline
   denselben Stand, den sie online hätte.
 - Neue Listen bekommen ihre ID auf dem Gerät. Artikel dieser Liste hält die SyncEngine zurück,
   bis der Auftrag `create` angekommen ist (siehe OfflineListsRepository.isListReady).

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Listen offline).
 ------------------------------------------------------------------------
 */

import Foundation

enum ListOperation: Codable, Equatable {
    /// Neue Liste (auch die Standardliste beim allerersten Start ohne Netz).
    case create(ListModel)
    case rename(id: UUID, title: String)
    case delete(id: UUID)
    case setDefault(id: UUID, ownerId: UUID)
    /// Geteilte Liste verlassen (eigene Mitgliedschaft löschen).
    case leave(id: UUID, profileId: UUID)

    /// Die Liste, die dieser Auftrag betrifft.
    var listId: UUID {
        switch self {
        case .create(let list): return list.id
        case .rename(let id, _), .delete(let id), .setDefault(let id, _), .leave(let id, _): return id
        }
    }

    func apply(to lists: [ListModel]) -> [ListModel] {
        var result = lists
        switch self {
        case .create(let list):
            if list.isDefault {
                result = result.map { $0.ownerId == list.ownerId && $0.isDefault ? $0.with(isDefault: false) : $0 }
            }
            if !result.contains(where: { $0.id == list.id }) { result.append(list) }
        case .rename(let id, let title):
            result = result.map { $0.id == id ? $0.with(title: title) : $0 }
        case .delete(let id), .leave(let id, _):
            result.removeAll { $0.id == id }
        case .setDefault(let id, let ownerId):
            result = result.map { list in
                guard list.ownerId == ownerId else { return list }
                return list.with(isDefault: list.id == id)
            }
        }
        return result.sorted { $0.createdAt < $1.createdAt }
    }
}

extension ListModel {
    func with(title: String? = nil, isDefault: Bool? = nil) -> ListModel {
        ListModel(id: id, ownerId: ownerId, title: title ?? self.title, isDefault: isDefault ?? self.isDefault,
                  createdAt: createdAt, updatedAt: Date())
    }
}
