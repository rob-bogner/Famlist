/*
 SupabaseReceiptsRepository.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-Umsetzung von ReceiptsRepository (Tabelle `receipts`, Bucket `receipt-images`, Migration 021).

 🔰 Notes for Beginners:
 - `created_by` kommt aus der aktiven Sitzung; die Zugriffsregel lässt nur die eigene ID zu.
 - Listen- und Personennamen werden über die Fremdschlüssel gleich mitgeladen (`lists(title)`,
   `profiles(username, full_name)`). Ist das Konto gelöscht, fehlt die Person (created_by = NULL).
 - purchased_at ist eine DATE-Spalte („yyyy-MM-dd“), created_at ein Zeitstempel mit Mikrosekunden:
   Der Bruchteil wird vor dem Lesen abgeschnitten (ISO8601DateFormatter kennt nur Millisekunden).

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

@MainActor
final class SupabaseReceiptsRepository: ReceiptsRepository {
    private let client: SupabaseClienting
    static let fetchLimit = 500

    init(client: SupabaseClienting) {
        self.client = client
    }

    private struct NameRow: Codable { let title: String? ; let username: String? ; let full_name: String? }

    private struct Row: Codable {
        let id: UUID
        let list_id: UUID
        let created_by: UUID?
        let store_name: String
        let purchased_at: String
        let total: Decimal
        let line_count: Int
        let saved_price_count: Int
        let photo_paths: [String]
        let bytes: Int
        var created_at: String?
        var lists: NameRow?
        var profiles: NameRow?
    }

    func fetchAll() async throws -> [ArchivedReceipt] {
        let rows: [Row] = try await client.from("receipts")
            .select("id, list_id, created_by, store_name, purchased_at, total, line_count, saved_price_count, "
                    + "photo_paths, bytes, created_at, lists(title), profiles(username, full_name)")
            .order("purchased_at", ascending: false)
            .order("created_at", ascending: false)
            .limit(Self.fetchLimit)
            .execute().value
        return rows.map(Self.receipt)
    }

    func uploadPhoto(_ data: Data, path: String) async throws {
        try await client.storageUpload(bucket: ReceiptPhotoCodec.bucket, path: path, data: data, contentType: "image/jpeg")
    }

    func insert(_ receipt: ArchivedReceipt) async throws {
        let uid: UUID
        if let current = client.auth.currentUser?.id { uid = current } else { uid = try await client.auth.session.user.id }
        let row = Row(id: receipt.id, list_id: receipt.listId, created_by: uid, store_name: receipt.storeName,
                      purchased_at: ReceiptDay.string(receipt.purchasedAt), total: receipt.total,
                      line_count: receipt.lineCount, saved_price_count: receipt.savedPriceCount,
                      photo_paths: receipt.photoPaths, bytes: receipt.bytes)
        // ON CONFLICT DO NOTHING: wiederholtes Senden nach verlorener Antwort ist harmlos.
        try await client.from("receipts").upsert(row, onConflict: "id", ignoreDuplicates: true).execute()
    }

    func downloadPhoto(path: String) async throws -> Data {
        try await client.storageDownload(bucket: ReceiptPhotoCodec.bucket, path: path)
    }

    func removePhotos(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        try await client.storageRemove(bucket: ReceiptPhotoCodec.bucket, paths: paths)
    }

    func delete(id: UUID) async throws {
        try await client.from("receipts").delete().eq("id", value: id.uuidString.lowercased()).execute()
    }

    private static func receipt(_ row: Row) -> ArchivedReceipt {
        let creator = [row.profiles?.full_name, row.profiles?.username].compactMap { $0 }.first { !$0.isEmpty }
        return ArchivedReceipt(id: row.id, listId: row.list_id, listTitle: row.lists?.title, createdBy: row.created_by,
                               creatorName: creator, storeName: row.store_name,
                               purchasedAt: ReceiptDay.date(row.purchased_at) ?? Date(), total: row.total,
                               lineCount: row.line_count, savedPriceCount: row.saved_price_count,
                               photoPaths: row.photo_paths, bytes: row.bytes,
                               createdAt: row.created_at.flatMap(ReceiptDay.timestamp) ?? Date())
    }
}
