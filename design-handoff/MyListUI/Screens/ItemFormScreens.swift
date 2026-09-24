//  ItemFormScreens.swift
//  MyListUI
//
//  „Neuer Artikel“ (Sheet-Höhe 790) und „Artikel bearbeiten“ (Sheet-Höhe 726), beide unten bündig.
//  Innenabstand oben 10, seitlich 20. Primär-Button: unten 34, links/rechts 20.

import SwiftUI

// MARK: - Neuer Artikel
//
//  Griff 5 → 12 → Titelzeile 44 → 18 →
//  [Foto 104 | 14 | Name-Label 13 · 6 · Feld 52 (vertikal zentriert)] → 20 →
//  Label „Menge“ · 6 · [Stepper 148 | 10 | Maßeinheit] → 20 →
//  Label „Kategorie“ · 8 · Chips 42

struct NewItemScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var initialName = "Milch"
    var onClose: () -> Void = {}
    var onSubmit: () -> Void = {}

    @State private var name: String? = nil
    @State private var quantity = 1

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         initialName: String = "Milch",
         onClose: @escaping () -> Void = {},
         onSubmit: @escaping () -> Void = {}) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.initialName = initialName
        self.onClose = onClose
        self.onSubmit = onSubmit
    }

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let nameBinding = Binding<String>(get: { name ?? initialName }, set: { name = $0 })

        return SheetScreen(appearance: appearance, accentHex: accentHex) {
            SheetSurface(k: k, height: 790) {
                ZStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        SheetHeader(title: "Neuer Artikel", k: k, onClose: onClose)

                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .center, spacing: 14) {
                                PhotoAddTile(k: k)
                                VStack(alignment: .leading, spacing: 6) {
                                    FieldLabel(text: "Name", k: k)
                                    // Fokus-Zustand: Rahmen 1,5 Akzent + 4-pt-Ring
                                    TextField("", text: nameBinding)
                                        .font(AppFont.dm(16, 500))
                                        .foregroundStyle(k.text)
                                        .tint(k.accent)
                                        .padding(.horizontal, 17.5)            // 1,5 border + 16 padding
                                        .frame(height: 52)
                                        .background(CSSBox(shape: RR(16), paint: .color(k.fieldFocus), border: 1.5,
                                                           borderColor: k.ring, shadows: [.drop(0, 0, 0, 4, k.ringSoft)]))
                                        .accessibilityLabel("Name")
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                FieldLabel(text: "Menge", k: k)
                                HStack(spacing: 10) {
                                    QuantityStepper(k: k, quantity: $quantity)
                                    UnitPickerButton(k: k, value: nil)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                FieldLabel(text: "Kategorie", k: k)
                                CategoryChipRow(k: k)
                            }
                        }
                        .padding(.top, 18)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                    CTAButton(title: "Zur Liste hinzufügen", k: k, action: onSubmit)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 34)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

// MARK: - Artikel bearbeiten
//
//  Griff 5 → 12 → Titelzeile 44 → 16 →
//  [Foto 104 | 14 | Name 48 · 8 · Marke 48] → 10 → Beschreibung 48 → 16 →
//  „Kategorie“ · 8 · Chips 42 → 16 → „Menge“ · 6 · [Stepper | Einheit „Packung“] → 16 →
//  „Preis“ · 6 · Feld 148 × 52 („0,00 €“)

struct EditItemScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var onClose: () -> Void = {}
    var onSave: () -> Void = {}

    @State private var name = "Butter"
    @State private var brand = ""
    @State private var details = ""
    @State private var quantity = 1
    @State private var price = "0,00"

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         onClose: @escaping () -> Void = {},
         onSave: @escaping () -> Void = {}) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.onClose = onClose
        self.onSave = onSave
    }

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)

        return SheetScreen(appearance: appearance, accentHex: accentHex) {
            SheetSurface(k: k, height: 726) {
                ZStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        SheetHeader(title: "Artikel bearbeiten", k: k, onClose: onClose)

                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .center, spacing: 14) {
                                PhotoAddTile(k: k)
                                VStack(spacing: 8) {
                                    PlainField(k: k, text: $name, placeholder: "Name", weight: 500, textColor: k.text)
                                    PlainField(k: k, text: $brand, placeholder: "Marke", weight: 400, textColor: k.sub)
                                }
                            }

                            PlainField(k: k, text: $details, placeholder: "Beschreibung", weight: 400, textColor: k.sub)
                                .padding(.top, -6)                       // margin-top: -6 → Abstand 10

                            VStack(alignment: .leading, spacing: 8) {
                                FieldLabel(text: "Kategorie", k: k)
                                CategoryChipRow(k: k)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                FieldLabel(text: "Menge", k: k)
                                HStack(spacing: 10) {
                                    QuantityStepper(k: k, quantity: $quantity)
                                    UnitPickerButton(k: k, value: "Packung")
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                FieldLabel(text: "Preis", k: k)
                                HStack(spacing: 8) {
                                    TextField("", text: $price)
                                        .keyboardType(.decimalPad)
                                        .font(AppFont.dm(16, 500))
                                        .foregroundStyle(k.text)
                                        .tint(k.accent)
                                        .accessibilityLabel("Preis")
                                    Text("€")
                                        .font(AppFont.dm(16, 600))
                                        .foregroundStyle(k.sub)
                                }
                                .padding(.horizontal, 17)                // 1 border + 16 padding
                                .frame(width: 148, height: 52)
                                .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                    CTAButton(title: "Speichern", k: k, action: onSave)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 34)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

/// Einfaches Eingabefeld: Höhe 48, Radius 16, Rahmen 1, Innenabstand 16.
/// Platzhalter = Textfarbe mit 75 % Deckkraft (`input::placeholder { color: inherit; opacity: .75 }`).
private struct PlainField: View {
    let k: SheetTheme
    @Binding var text: String
    let placeholder: String
    let weight: CGFloat
    let textColor: Color

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(textColor.opacity(0.75)))
            .font(AppFont.dm(16, weight))
            .foregroundStyle(textColor)
            .tint(k.accent)
            .padding(.horizontal, 17)                                    // 1 border + 16 padding
            .frame(height: 48)
            .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
            .accessibilityLabel(placeholder)
    }
}
