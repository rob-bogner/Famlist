//  OverlayPreviews.swift
//  MyListUI
//
//  Overlay-Artboards (6 Screens × Light/Dark) auf 390 × 844 pt.
//  Titel = Artboard-Titel aus Design/html/canvas.json.

import SwiftUI

// MARK: Kontext-Menü
#Preview("Kontext-Menü", traits: .fixedLayout(width: 390, height: 844)) { MenuOverlayScreen(appearance: .light) }
#Preview("Kontext-Menü – Dark", traits: .fixedLayout(width: 390, height: 844)) { MenuOverlayScreen(appearance: .dark) }

// MARK: Sortieren
#Preview("Sortieren", traits: .fixedLayout(width: 390, height: 844)) { SortMenuScreen(appearance: .light) }
#Preview("Sortieren – Dark", traits: .fixedLayout(width: 390, height: 844)) { SortMenuScreen(appearance: .dark) }

// MARK: In Zwischenablage kopieren
#Preview("In Zwischenablage kopieren", traits: .fixedLayout(width: 390, height: 844)) { CopyChoiceScreen(appearance: .light) }
#Preview("In Zwischenablage kopieren – Dark", traits: .fixedLayout(width: 390, height: 844)) { CopyChoiceScreen(appearance: .dark) }

// MARK: Kopiert – Bestätigung
#Preview("Kopiert – Bestätigung", traits: .fixedLayout(width: 390, height: 844)) { CopyDoneScreen(appearance: .light) }
#Preview("Kopiert – Bestätigung – Dark", traits: .fixedLayout(width: 390, height: 844)) { CopyDoneScreen(appearance: .dark) }

// MARK: Artikel löschen – Auswahl
#Preview("Artikel löschen – Auswahl", traits: .fixedLayout(width: 390, height: 844)) { DeleteChoiceScreen(appearance: .light) }
#Preview("Artikel löschen – Auswahl – Dark", traits: .fixedLayout(width: 390, height: 844)) { DeleteChoiceScreen(appearance: .dark) }

// MARK: Gelöscht – Rückgängig
#Preview("Gelöscht – Rückgängig", traits: .fixedLayout(width: 390, height: 844)) { UndoToastScreen(appearance: .light) }
#Preview("Gelöscht – Rückgängig – Dark", traits: .fixedLayout(width: 390, height: 844)) { UndoToastScreen(appearance: .dark) }
