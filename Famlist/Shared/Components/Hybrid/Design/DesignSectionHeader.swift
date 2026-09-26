/*
 DesignSectionHeader.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sektions-Kopf (offen oder abgehakt) der statischen Design-Liste für DesignListScreen.

 📝 Last Change:
 - Aus DesignListScreen.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Sektions-Kopf

struct DesignSectionHeader: View {
    let t: ListTheme
    let checked: Bool

    var body: some View {
        if checked {
            HStack(spacing: 10) {
                SVGIcon(Icon.check, size: 16, color: t.sub, lineWidth: 2.2)
                    .frame(width: 30, height: 30)
                    .background(CSSBox(shape: RR(10), paint: .color(t.search), border: 1, borderColor: t.searchBorder))
                Text("Abgehakte Artikel")
                    .font(AppFont.outfit(20, 600))
                    .foregroundStyle(t.sub)
                Text("1")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(t.sub)
            }
            .frame(minHeight: 38)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    SVGIcon(Icon.tag, size: 16, color: .white, lineWidth: 2.1)
                        .frame(width: 30, height: 30)
                        .background(CSSBox(shape: RR(10), paint: t.chipGrad, shadows: t.chipShadow))
                    Text("Sonstiges")
                        .font(AppFont.outfit(20, 600))
                        .foregroundStyle(t.text)
                    Text("1")
                        .font(AppFont.dm(14, 600))
                        .foregroundStyle(t.sub)
                }
                Spacer(minLength: 0)
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text("Alle abhaken")
                            .font(AppFont.dm(14, 600))
                            .foregroundStyle(t.accentText)
                        SVGIcon(Icon.chevronRight, size: 16, color: t.accentText, lineWidth: 2.2)
                    }
                    .padding(.vertical, 10)
                    .padding(.leading, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("Abschnittskopf") {
    DesignSectionHeader(t: ListTheme(.light), checked: false)
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Abschnittskopf – Dark") {
    DesignSectionHeader(t: ListTheme(.dark), checked: true)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
