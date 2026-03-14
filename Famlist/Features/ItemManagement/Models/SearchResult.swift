/*
 SearchResult.swift

 Famlist
 Created on: 14.03.2026
 Last updated on: 14.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unified search result model combining personal catalog and global OFF entries.
 - Used by ItemSearchViewModel and consumed by ItemSearchView.

 🛠 Includes:
 - SearchResultSource enum (personal / global).
 - SearchResult struct (Identifiable, Equatable) wrapping a normalised ItemCatalogEntry.

 🔰 Notes for Beginners:
 - The view never needs to branch on the entry type: everything is already an ItemCatalogEntry.
 - source drives the ★ badge (personal) vs. no badge (global) in ItemCatalogRow.
 - imageUrl is non-nil only for global results (OFF image URL); nil for personal entries
   (which use base64 imageData in the entry itself).

 📝 Last Change:
 - Initial creation for OpenFoodFacts integration.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides Identifiable, Equatable support.

// MARK: - SearchResultSource

/// Indicates whether a search result originates from the user's personal catalog or the global OFF catalog.
enum SearchResultSource: Equatable {
    /// Entry from the user's own item_catalog table (synced, RLS-protected).
    case personal
    /// Entry from the global_product_catalog table (read-only, OFF data).
    case global
}

// MARK: - SearchResult

/// A single item in the unified search results list.
/// Wraps an `ItemCatalogEntry` so the view does not need to handle two different types.
struct SearchResult: Identifiable, Equatable {

    // MARK: - Properties

    /// Stable identity — forwards the wrapped entry's id.
    var id: String { entry.id }

    /// Normalised item data ready to be added to a list via `ItemCatalogEntry.toItemModel()`.
    let entry: ItemCatalogEntry

    /// Indicates whether this result came from the personal or global catalog.
    let source: SearchResultSource

    /// Remote image URL (OpenFoodFacts CDN). Non-nil only for `.global` results.
    /// Personal results use base64 `imageData` embedded in the entry instead.
    let imageUrl: String?
}
