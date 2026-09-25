/*
 DesignListTabs.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tabs „Alle · Offen · Erledigt“ der statischen Design-Liste für DesignListScreen.

 📝 Last Change:
 - Aus DesignListScreen.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Tabs

struct DesignListTabs: View {
    let t: ListTheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 26) {
                tab("Alle", active: true)
                tab("Offen", active: false)
                tab("Erledigt", active: false)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zIndex(1) // Unterstrich liegt über der Trennlinie
            Rectangle()
                .fill(t.line)
                .frame(height: 1)
        }
    }

    private func tab(_ title: String, active: Bool) -> some View {
        Button(action: {}) {
            Text(title)
                .font(AppFont.dm(15, active ? 600 : 500))
                .foregroundStyle(active ? t.accentText : t.sub)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    if active {
                        UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3, style: .circular)
                            .fill(t.accent)
                            .frame(height: 3)
                            .shadow(color: t.accentGlow, radius: 6)   // 0 0 12px rgba(accent,.6)
                            .offset(y: 1)                              // bottom: -1px
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

#Preview("Filter-Reiter") {
    DesignListTabs(t: ListTheme(.light))
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Filter-Reiter – Dark") {
    DesignListTabs(t: ListTheme(.dark))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
