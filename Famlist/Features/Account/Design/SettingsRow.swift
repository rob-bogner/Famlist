/*
 SettingsRow.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeile in den Einstellungen: Titel, optional Unterzeile, rechts Schalter oder Chevron.

 🔰 Notes for Beginners:
 - Aus SettingsSheet.swift ausgelagert (Datei über 300 Zeilen); unverändert übernommen.

 📝 Last Change:
 - Ausgelagert aus SettingsSheet.swift (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Zeile: min. 56 (inkl. border-top 1 bei Folgezeilen), padding 8 14, gap 12;
/// Titel 15/500, darunter optional 12 sub (gap 2), rechts optional Schalter.
struct SettingsRow<Trailing: View>: View {
    let t: ListAccountTokens
    let title: String
    let titleColor: Color
    let subtitle: String?
    let hasTopLine: Bool
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.dm(15, 500))
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)        // umbrechen statt abschneiden
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(t.k.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(minHeight: hasTopLine ? 55 : 56)
        .padding(.top, hasTopLine ? 1 : 0)
        .overlay(alignment: .top) {
            if hasTopLine {
                Rectangle().fill(t.line).frame(height: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    let t = ListAccountTokens(.light)
    SettingsRow(t: t, title: "Gespeicherte Kassenzettel", titleColor: t.k.text, subtitle: "12 Bons · 38 MB",
                hasTopLine: true) {
        SVGIcon(Icon.chevronRight, size: 18, color: t.k.sub, lineWidth: 2.2)
    }
    .padding(20)
}

#Preview("Dark") {
    let t = ListAccountTokens(.dark)
    SettingsRow(t: t, title: "Gespeicherte Kassenzettel", titleColor: t.k.text, subtitle: "12 Bons · 38 MB",
                hasTopLine: true) {
        SVGIcon(Icon.chevronRight, size: 18, color: t.k.sub, lineWidth: 2.2)
    }
    .padding(20)
    .background(Color.hex("#0A1416"))
}
