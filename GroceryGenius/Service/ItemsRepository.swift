// ItemsRepository.swift
// Abstraktion + Fehlerdefinition für Item-Datenzugriff
import Foundation

enum ItemsRepositoryError: Error, LocalizedError {
    case notFound
    case decodingFailed
    case encodingFailed
    case network(String)
    case unknown
    var errorDescription: String? {
        switch self {
        case .notFound: return "Item nicht gefunden"
        case .decodingFailed: return "Dekodierung fehlgeschlagen"
        case .encodingFailed: return "Kodierung fehlgeschlagen"
        case .network(let msg): return "Netzwerkfehler: \(msg)"
        case .unknown: return "Unbekannter Fehler"
        }
    }
}

protocol ItemsRepository {
    typealias ListenerToken = AnyObject
    @discardableResult
    func addListener(onUpdate: @escaping ([ItemModel]) -> Void) -> ListenerToken
    func addItem(_ item: ItemModel, completion: ((Error?) -> Void)?)
    func updateItem(_ item: ItemModel, completion: ((Error?) -> Void)?)
    func deleteItem(_ item: ItemModel, completion: ((Error?) -> Void)?)
}
