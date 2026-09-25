/*
 ItemCard.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikel-Karte der Liste: Höhe 94, Padding 14, Radius 24.
   Bild 64 (Radius 18) · Name Outfit 19/600 · Mengen-Chip · rechts der Abhak-Kreis 44.

 🔰 Notes for Beginners:
 - Abgehakt: Bild und Text auf 55 %, Name durchgestrichen, Kreis wird zum gefüllten Haken.
 - „Nicht verfügbar“ (Famlist-Ergänzung, im Design nicht gezeichnet): Inhalt auf 55 % und ein
   orangefarbener Chip in den Farben der Wisch-Aktion. Sonst steht hier die Marke, falls vorhanden.
 - Tippen aufs Bild öffnet das Produktbild-Sheet.
 - Remote-Sync (FAM-XX): kurzes Aufleuchten, wenn der Artikel gerade von einem anderen Gerät kam.
 - Sync endgültig fehlgeschlagen (FAM-23): Warn-Dreieck; Tippen fragt nach einem erneuten Versuch.
 - Die ganze Karte ist per contentShape treffbar (sonst erreicht ein Wisch von der freien Fläche die Geste nicht).
 - Bild und Abhak-Kreis sind bewusst keine SwiftUI-Buttons (swipeFriendlyTap): Ein Button hält die
   Berührung fest, dann ließe sich die Zeile nicht wischen, wenn der Daumen dort aufsetzt.

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen, an ItemModel angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Card for a single list item.
struct ItemCard: View {
    let t: ListTheme
    let item: ItemModel
    var onToggleChecked: () -> Void = {}
    var onTapImage: () -> Void = {}
    /// Plays the one-shot glow for items just applied from Realtime / IncrementalSync.
    var isRecentlySynced: Bool = false
    /// Manual retry after a permanently failed sync; nil hides the warning action.
    var onRetry: (() -> Void)? = nil

    @State private var showRetryConfirmation = false
    /// Einstellungen → Liste → „Preise anzeigen“.
    @AppStorage(PriceDisplaySetting.storageKey) private var showPrices = PriceDisplaySetting.defaultValue

    private var dimmed: Bool { item.isChecked || item.isUnavailable }

    var body: some View {
        HStack(spacing: 16) {
            ItemThumbnailTile(t: t, image: item.image)
                .swipeFriendlyTap("Produktbild von \(item.name)", action: onTapImage)
                .opacity(dimmed ? 0.55 : 1)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(AppFont.outfit(19, 600))
                    .foregroundStyle(t.text)
                    .strikethrough(item.isChecked, color: t.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                detailRow
            }
            .opacity(dimmed ? 0.55 : 1)

            Spacer(minLength: 0)

            if item.isSyncFailed { syncFailedIcon }
            checkButton
        }
        .padding(15)                      // 1 border + 14 padding
        .frame(maxWidth: .infinity)
        .frame(height: 94)
        // Ganze Karte treffbar machen: CSSBox ist allowsHitTesting(false). Ohne diese Zeile landete eine
        // Berührung auf der freien Fläche zwischen Name und Kreis beim ScrollView statt bei der Wischgeste
        // (auf dem Gerät per UI-Test nachgewiesen: Links-Wisch aus der Kartenmitte bewegte nichts).
        .contentShape(RR(24))
        .background(CSSBox(shape: RR(24), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
        .remoteSyncHighlight(isActive: isRecentlySynced, cornerRadius: 24)
        .confirmationDialog("Sync fehlgeschlagen", isPresented: $showRetryConfirmation, titleVisibility: .visible) {
            Button("Erneut synchronisieren") { onRetry?() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Artikel konnte nicht synchronisiert werden. Soll ein neuer Versuch gestartet werden?")
        }
    }

    /// Warn-Dreieck bei endgültig fehlgeschlagenem Sync (wie zuvor in ListRowView).
    private var syncFailedIcon: some View {
        // Dreieck aus dem Design-Paket (wie „Konto löschen?“) statt SF Symbol; Farben unverändert.
        SVGIcon(ListAccountIcon.warning, size: 20, color: t.isDark ? .hex("#FFC08A") : .hex("#BD5F0E"), lineWidth: 2)
            .frame(width: 32, height: 44)
            .contentShape(Rectangle())
            .swipeFriendlyTap("Sync fehlgeschlagen. Tippen zum erneuten Synchronisieren.") {
                if onRetry != nil { showRetryConfirmation = true }
            }
    }

    private var detailRow: some View {
        HStack(spacing: 8) {
            Text(item.quantityText)
                .font(AppFont.dm(13, 600))
                .foregroundStyle(t.accentText)
                .padding(.vertical, 4)
                .padding(.horizontal, 11)
                .background(CSSBox(shape: Pill, paint: .color(t.chipBg), shadows: t.chipInset))
                .fixedSize()
            if showPrices && item.price > 0 {
                // Hybrid.dc.html: Gesamtpreis Outfit 15/600 t.text, 10 neben dem Mengen-Chip (8 + 2);
                // dahinter Einzelpreis „je 1,49 €“ DM Sans 12/500 t.sub, Abstand 6.
                let perUnit = PriceDisplaySetting.multiplier(for: item) > 1
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(PriceDisplaySetting.euro(PriceDisplaySetting.lineTotal(item)))
                        .font(AppFont.outfit(15, 600))
                        .foregroundStyle(t.text)
                    if perUnit {                                  // „je …“ nur bei mehreren Stück
                        Text("je \(PriceDisplaySetting.euro(item.price))")
                            .font(AppFont.dm(12, 500))
                            .foregroundStyle(t.sub)
                    }
                }
                .padding(.leading, 2)
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(perUnit
                    ? "Gesamt \(PriceDisplaySetting.euro(PriceDisplaySetting.lineTotal(item))), je \(PriceDisplaySetting.euro(item.price))"
                    : "Preis \(PriceDisplaySetting.euro(item.price))")
            }
            if item.isUnavailable {
                Text("Nicht verfügbar")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(t.isDark ? Color.hex("#FFC08A") : Color.hex("#BD5F0E"))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 11)
                    .background(CSSBox(shape: Pill, paint: .color(.rgba(240, 138, 44, t.isDark ? 0.18 : 0.12)),
                                       shadows: [.inner(0, 0, 0, 1, .rgba(240, 138, 44, 0.3))]))
                    .fixedSize()
            } else if let brand = item.brand, !brand.isEmpty {
                Text(brand)
                    .font(AppFont.dm(13, 500))
                    .foregroundStyle(t.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    @ViewBuilder
    private var checkButton: some View {
        if item.isChecked {
            SVGIcon(Icon.check, size: 20, color: .white, lineWidth: 2.6)
                .frame(width: 44, height: 44)
                .background(CSSBox(shape: Circle(), paint: t.fabBg,
                                   shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.45)),
                                             .drop(0, 6, 14, -6, t.accentGlow)]))
                .contentShape(Circle())
                .swipeFriendlyTap("\(item.name) ist abgehakt. Tippen macht es wieder offen.", action: onToggleChecked)
        } else {
            Color.clear
                .frame(width: 44, height: 44)
                .background(CSSBox(shape: Circle(), paint: .color(t.checkBg), border: 2,
                                   borderColor: t.checkRing, shadows: t.checkShadow))
                .contentShape(Circle())
                .swipeFriendlyTap("\(item.name) abhaken", action: onToggleChecked)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ItemCard(t: ListTheme(.light), item: ItemModel(name: "Butter", units: 1, measure: "pack", brand: "Kerrygold"))
        ItemCard(t: ListTheme(.light), item: ItemModel(name: "Milch", units: 2, measure: "l", isUnavailable: true))
        ItemCard(t: ListTheme(.light), item: ItemModel(name: "Eier", units: 10, isChecked: true))
    }
    .padding(20)
}

#Preview("Dark") {
    VStack(spacing: 12) {
        ItemCard(t: ListTheme(.dark), item: ItemModel(name: "Butter", units: 1, measure: "pack", brand: "Kerrygold"))
        ItemCard(t: ListTheme(.dark), item: ItemModel(name: "Milch", units: 2, measure: "l", isUnavailable: true))
        ItemCard(t: ListTheme(.dark), item: ItemModel(name: "Eier", units: 10, isChecked: true))
    }
    .padding(20)
    .background(Color.hex("#0A1416"))
}
