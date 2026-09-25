//  ItemPreviews.swift
//  MyListUI
//
//  Gruppe „Artikel“: alle Artboards auf 390 × 844 pt (Titel = Artboard-Titel aus canvas.json).
//  BarcodeScan existiert nur als Light-Artboard (Kamera immer dunkel).

import SwiftUI

// MARK: Produktbild – Quelle: Design/html/ProductImage.dc.html
#Preview("Produktbild", traits: .fixedLayout(width: 390, height: 844)) { ProductImageScreen(appearance: .light) }
#Preview("Produktbild – Dark", traits: .fixedLayout(width: 390, height: 844)) { ProductImageScreen(appearance: .dark) }

// MARK: Artikel suchen – leer – Quelle: Design/html/SearchEmpty.dc.html
#Preview("Artikel suchen – leer", traits: .fixedLayout(width: 390, height: 844)) { SearchEmptyScreen(appearance: .light) }
#Preview("Artikel suchen – leer – Dark", traits: .fixedLayout(width: 390, height: 844)) { SearchEmptyScreen(appearance: .dark) }

// MARK: Artikel suchen – Treffer – Quelle: Design/html/SearchResults.dc.html
#Preview("Artikel suchen – Treffer", traits: .fixedLayout(width: 390, height: 844)) { SearchResultsScreen(appearance: .light) }
#Preview("Artikel suchen – Treffer – Dark", traits: .fixedLayout(width: 390, height: 844)) { SearchResultsScreen(appearance: .dark) }

// MARK: Neuer Artikel – Quelle: Design/html/NewItem.dc.html
#Preview("Neuer Artikel", traits: .fixedLayout(width: 390, height: 844)) { NewItemScreen(appearance: .light) }
#Preview("Neuer Artikel – Dark", traits: .fixedLayout(width: 390, height: 844)) { NewItemScreen(appearance: .dark) }

// MARK: Artikel bearbeiten – Quelle: Design/html/EditItem.dc.html
#Preview("Artikel bearbeiten", traits: .fixedLayout(width: 390, height: 844)) { EditItemScreen(appearance: .light) }
#Preview("Artikel bearbeiten – Dark", traits: .fixedLayout(width: 390, height: 844)) { EditItemScreen(appearance: .dark) }

// MARK: Artikel verwalten – Quelle: Design/html/ManageItems.dc.html
#Preview("Artikel verwalten", traits: .fixedLayout(width: 390, height: 844)) { ManageItemsScreen(appearance: .light) }
#Preview("Artikel verwalten – Dark", traits: .fixedLayout(width: 390, height: 844)) { ManageItemsScreen(appearance: .dark) }

// MARK: Barcode-Scanner – Quelle: Design/html/BarcodeScan.dc.html (nur Light)
#Preview("Barcode-Scanner (Kamera, immer dunkel)", traits: .fixedLayout(width: 390, height: 844)) { BarcodeScanScreen(appearance: .light) }

// MARK: Preisverlauf – Quelle: Design/html/PriceHistory.dc.html
#Preview("Preisverlauf", traits: .fixedLayout(width: 390, height: 844)) { PriceHistoryScreen(appearance: .light) }
#Preview("Preisverlauf – Dark", traits: .fixedLayout(width: 390, height: 844)) { PriceHistoryScreen(appearance: .dark) }
