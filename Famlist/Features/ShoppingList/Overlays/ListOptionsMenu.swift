/*
 ListOptionsMenu.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Listen-Optionen per langem Druck in „Meine Listen“: Umbenennen, Duplizieren, Favorit,
   Mitglieder & Teilen, Liste löschen (eigene) bzw. Liste verlassen (geteilte).

 🔰 Notes for Beginners:
 - Vorlage: ListOptionsScreen in design-handoff/MyListUI/Screens/ListManagementScreens.swift
   (ListOptions.dc.html): Menü rechts 20, oben 262, Breite 262, Radius 24.
 - Der Hinweis „Bei geteilten Listen: „Liste verlassen““ aus dem Design ist eine Anmerkung für
   Entwickler. In der App steht je nach Liste „Liste löschen“ oder „Liste verlassen“ mit eigenem Untertitel.
 - Umbenennen dürfen nur Besitzer (RLS list_update_owner); bei geteilten Listen ist der Eintrag gedimmt.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ListOptionsMenu: View {
    let appearance: Appearance
    var listName = "My List"
    var isFavorite = true
    var isOwner = true
    var topOffset: CGFloat = 262
    var onRename: () -> Void = {}
    var onDuplicate: () -> Void = {}
    var onToggleFavorite: () -> Void = {}
    var onMembers: () -> Void = {}
    var onDelete: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k

        ListAccountBackdrop(scrim: t.scrimMenu, alignment: .topTrailing) {
            DesignListScreen(appearance: appearance)
        } content: {
            ZStack(alignment: .topTrailing) {
                // Tippen außerhalb schließt das Menü
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text(listName)
                        .font(AppFont.dm(12, 600))
                        .tracking(0.72)                          // 0.06em × 12
                        .textCase(.uppercase)
                        .foregroundStyle(k.sub)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.top, 10)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .accessibilityAddTraits(.isHeader)

                    ListAccountMenuItem(t: t, icon: Icon.pencil, title: "Umbenennen", action: onRename)
                        .opacity(isOwner ? 1 : 0.45)
                        .allowsHitTesting(isOwner)
                    ListAccountMenuItem(t: t, icon: ListAccountIcon.copy, title: "Duplizieren", action: onDuplicate)
                    ListAccountMenuItem(t: t, icon: Icon.star,
                                        title: isFavorite ? "Favorit entfernen" : "Als Favorit markieren",
                                        action: onToggleFavorite)
                    ListAccountMenuItem(t: t, icon: ListAccountIcon.members, title: "Mitglieder & Teilen", action: onMembers)

                    Rectangle()
                        .fill(t.line)
                        .frame(height: 1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)

                    Button(action: onDelete) {
                        HStack(spacing: 12) {
                            SVGIcon(Icon.trash, size: 20, color: t.danger, lineWidth: 1.9)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(isOwner ? "Liste löschen" : "Liste verlassen")
                                    .font(AppFont.dm(15, 600))
                                    .foregroundStyle(t.danger)
                                Text(isOwner ? "Mit allen Artikeln, für alle Mitglieder" : "Die Liste bleibt für die anderen erhalten")
                                    .font(AppFont.dm(12, 400))
                                    .foregroundStyle(k.sub)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .background(RR(16).fill(t.dangerSoft))
                        .contentShape(RR(16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(7)                                          // 6 Padding + 1 Rahmen
                .frame(width: 262)
                .background(CSSBox(shape: RR(24), paint: .color(t.menu), border: 1, borderColor: t.menuBorder,
                                   shadows: t.menuShadow))
                .padding(.top, topOffset)
                .padding(.trailing, 20)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Optionen für \(listName)")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

#Preview("Listen-Optionen", traits: .fixedLayout(width: 390, height: 844)) { ListOptionsMenu(appearance: .light) }
#Preview("Listen-Optionen – Dark", traits: .fixedLayout(width: 390, height: 844)) { ListOptionsMenu(appearance: .dark) }
