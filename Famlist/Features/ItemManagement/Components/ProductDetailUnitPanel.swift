/*
 ProductDetailUnitPanel.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Maßeinheit-Auswahl „Einheiten gruppiert“ (Prototyp PickH): klappt unter Kategorie · Maßeinheit auf,
   Reiter Zählen · Gewicht · Volumen · Länge, darunter die Einheiten als Chips.

 🔰 Notes for Beginners:
 - Fläche field, Rand 1,5 ring, Radius 20, Innenabstand 12 / 14 / 14. Reiter wie das Segment in den
   Einstellungen (segBg, Knopf 34 hoch, aktiv hell mit Schatten). Chips 34 hoch, gewählt = Akzent-Glas.
 - Antippen eines Chips speichert die Einheit und klappt die Fläche wieder zu (onDone).
 - „Länge“ (cm, m) ist im Canvas-Prototyp noch nicht zu sehen – nachziehen, wenn es übernommen wird.

 📝 Last Change:
 - Initial creation (Test vor Übernahme in die User Journey, Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Gruppen der Maßeinheiten für die Reiter.
enum MeasureGroup: String, CaseIterable, Identifiable {
    case count, weight, volume, length

    var id: String { rawValue }

    var label: String {
        switch self {
        case .count: return "Zählen"
        case .weight: return "Gewicht"
        case .volume: return "Volumen"
        case .length: return "Länge"
        }
    }

    var units: [Measure] {
        switch self {
        case .count: return [.piece, .pack, .net, .bag, .smallBag, .bunch, .box, .crate, .bottle, .can, .jar,
                             .cup, .carton, .pair, .sack, .slice, .bar, .tube]
        case .weight: return [.g, .kg]
        case .volume: return [.ml, .l]
        case .length: return [.cm, .m]
        }
    }

    static func of(_ measure: Measure) -> MeasureGroup {
        allCases.first { $0.units.contains(measure) } ?? .count
    }
}

/// Aufgeklappte Maßeinheit-Auswahl mit Reitern und Chips.
struct ProductDetailUnitPanel: View {
    let k: SheetTheme
    @Binding var measure: String
    let onDone: () -> Void

    @State private var group: MeasureGroup

    init(k: SheetTheme, measure: Binding<String>, onDone: @escaping () -> Void) {
        self.k = k
        _measure = measure
        self.onDone = onDone
        let raw = measure.wrappedValue
        _group = State(initialValue: raw.isEmpty ? .count : MeasureGroup.of(Measure.fromExternal(raw)))
    }

    private var selected: Measure? { measure.isEmpty ? nil : Measure.fromExternal(measure) }

    private var segBg: Color { k.isDark ? .rgba(255, 255, 255, 0.06) : .hex("#F1F5F5") }
    private var segOn: Color { k.isDark ? .rgba(255, 255, 255, 0.14) : .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SVGIcon(ProductDetailIcon.unit, size: 15, color: k.accentText, lineWidth: 2)
                Text("Maßeinheit")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(k.sub)
                Spacer(minLength: 0)
                if selected != nil {
                    Button("Ohne") { choose(nil) }
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(k.accentText)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Keine Maßeinheit")
                        .padding(.trailing, 8)
                }
                Text(selected?.localizedName ?? "Keine")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(selected == nil ? k.sub : k.text)
            }

            HStack(spacing: 3) {
                ForEach(MeasureGroup.allCases) { tab($0) }
            }
            .padding(3)
            .background(RR(13).fill(segBg))

            InsightChipFlow(spacing: 6) {
                ForEach(group.units, id: \.self) { chip($0) }
            }
            .id(group)
            .transition(.opacity)
        }
        .padding(.top, 13)
        .padding(.bottom, 15)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CSSBox(shape: RR(20), paint: .color(k.field), border: 1.5, borderColor: k.ring))
    }

    private func tab(_ option: MeasureGroup) -> some View {
        let isOn = option == group
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { group = option }
        } label: {
            Text(option.label)
                .font(AppFont.dm(13, isOn ? 600 : 500))
                .foregroundStyle(isOn ? k.text : k.sub)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background {
                    if isOn {
                        CSSBox(shape: RR(10), paint: .color(segOn), shadows: [.drop(0, 1, 3, 0, .rgba(0, 0, 0, 0.12))])
                    }
                }
                .contentShape(RR(10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func chip(_ unit: Measure) -> some View {
        let isOn = unit == selected
        return Button { choose(unit) } label: {
            Text(unit.localizedName)
                .font(AppFont.dm(13, isOn ? 600 : 500))
                .foregroundStyle(isOn ? Color.white : k.text)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background {
                    if isOn {
                        GlassPillBackground(style: .accent, appearance: k.appearance, accent: k.a, height: 34)
                    } else {
                        CSSBox(shape: Capsule(), paint: .color(k.fieldFocus), border: 1, borderColor: k.fieldBorder)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unit.localizedName)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func choose(_ unit: Measure?) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            measure = unit?.rawValue ?? ""
        }
        onDone()
    }
}

#Preview {
    @Previewable @State var measure = "net"
    ProductDetailUnitPanel(k: SheetTheme(.light), measure: $measure, onDone: {})
        .padding(20)
}

#Preview("Dark") {
    @Previewable @State var measure = "kg"
    ProductDetailUnitPanel(k: SheetTheme(.dark), measure: $measure, onDone: {})
        .padding(20)
        .background(Color.hex("#0A1416"))
}
