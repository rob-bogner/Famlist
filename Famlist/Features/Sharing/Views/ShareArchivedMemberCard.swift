/*
 ShareArchivedMemberCard.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karte für ein Mitglied mit gelöschtem Konto in „Mitglieder & Teilen“: ausgegraut, gestrichelt,
   „Konto gelöscht · bis 26.11. wiederherstellbar“ und Knopf „Entfernen“ (nur für den Besitzer).

 🔰 Notes for Beginners:
 - Vorlage: ShareMembers.dc.html, Variante archived (Board ShareMembersArchived).
   Karte wie die übrigen Mitglieder (padding 13 14, Radius 22, gap 14), Rahmen gestrichelt.
 - „Entfernen“ fragt per confirmationDialog nach (Board ArchivedMemberRemove); das erledigt ShareMembersSheet.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 4).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ShareArchivedMemberCard: View {
    let member: ArchivedListMember
    let t: ListAccountTokens
    var onRemove: () -> Void = {}

    var body: some View {
        let k = t.k
        HStack(spacing: 14) {
            // Avatar 44: field, Rahmen 1,5 gestrichelt fieldBorder (border-box), Initiale Outfit 18/600 in sub
            Text(initial)
                .font(AppFont.outfit(18, 600))
                .foregroundStyle(k.sub)
                .frame(width: 44, height: 44)
                .background(CSSBox(shape: Circle(), paint: .color(k.field), border: 1.5, borderColor: k.fieldBorder,
                                   dash: [4.5, 4.5]))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(AppFont.outfit(17, 600))
                    .foregroundStyle(k.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("Konto gelöscht · bis \(Self.shortDate(member.purgeAfter)) wiederherstellbar")
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(k.sub)
                    .cssLineHeight(17.55, font: AppFont.ui(.dmSans, 13, 400))    // line-height 1.35
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: onRemove) {
                Text("Entfernen")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(t.danger)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(GlassPillBackground(style: .neutral, appearance: k.appearance, accent: k.a, height: 36))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("\(member.name) entfernen")
        }
        .padding(.vertical, 14)                                              // 13 + 1 Rahmen
        .padding(.horizontal, 15)                                            // 14 + 1 Rahmen
        .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder,
                           dash: [3, 3], shadows: t.cardShadow))                // border-style: dashed (1 px)
    }

    private var initial: String { String(member.name.prefix(1)).uppercased() }

    /// „26.11.“ wie im Board.
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(Locale(identifier: "de_DE")))
    }
}

#Preview("Archiviertes Mitglied", traits: .fixedLayout(width: 390, height: 120)) {
    ShareArchivedMemberCard(member: ArchivedListMember(id: UUID(), name: "Sofie", purgeAfter: Date().addingTimeInterval(60 * 86_400)),
                            t: ListAccountTokens(.light))
        .padding(20)
}

#Preview("Archiviertes Mitglied – Dark", traits: .fixedLayout(width: 390, height: 120)) {
    ShareArchivedMemberCard(member: ArchivedListMember(id: UUID(), name: "Sofie", purgeAfter: Date().addingTimeInterval(60 * 86_400)),
                            t: ListAccountTokens(.dark))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
