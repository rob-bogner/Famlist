//  SearchScreen.swift
//  MyListUI
//
//  Sheet „Artikel suchen“ – Höhe 790 (oben 54 pt Luft auf 844), unten bündig.
//  Zwei Zustände:
//   • leer   – Leerzustand + „Neuen Artikel anlegen“ 14 pt über der Tastatur
//   • Treffer – „5 Treffer“ + Ergebnis-Karten + Fußleiste „Neu anlegen: „…““
//
//  Kopf: Innenabstand oben 10, seitlich 20 → Griff 5 → 12 → Titelzeile 44 → 16 → Suchfeld 54

import SwiftUI

struct SearchResult: Identifiable, Hashable {
    let name: String
    let brand: String
    let size: String
    var id: String { name }
}

extension SearchResult {
    static let milkSamples: [SearchResult] = [
        SearchResult(name: "Soyamilch", brand: "alpro", size: "1 l"),
        SearchResult(name: "Kerrygold, original irische Butter aus Weidemilch", brand: "Kerrygold", size: "250 g"),
        SearchResult(name: "Bio Vollmilch-Schokolade", brand: "Fairglobe", size: "100 g"),
        SearchResult(name: "Milch Mandel ohne Zucker", brand: "Lidl", size: "1 l"),
        SearchResult(name: "Kokosmilch", brand: "Freshona", size: "400 ml")
    ]
}

// MARK: - Leer

struct SearchEmptyScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    /// Nur für Vorschau/Abgleich mit dem Design. In der App zeichnet iOS die Tastatur;
    /// dann `false` setzen – der Button sitzt 14 pt über der Tastatur (siehe README).
    var showsKeyboardPlaceholder = true
    /// Statischer Cursor wie im Design (2 × 22, Akzent). In der App `false` – dann zeichnet iOS den Cursor.
    var showsDesignCursor = true
    var onClose: () -> Void = {}
    var onCreate: () -> Void = {}

    @State private var query = ""

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         showsKeyboardPlaceholder: Bool = true,
         showsDesignCursor: Bool = true,
         onClose: @escaping () -> Void = {},
         onCreate: @escaping () -> Void = {}) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.showsKeyboardPlaceholder = showsKeyboardPlaceholder
        self.showsDesignCursor = showsDesignCursor
        self.onClose = onClose
        self.onCreate = onCreate
    }

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let dark = k.isDark
        let a = k.a
        let thumbPaint: Paint = dark
            ? .linear(150, [stop(a.base.color(0.24), 0), stop(a.base.color(0.06), 1)])
            : .linear(150, [stop(.hex("#F4F8F8"), 0), stop(.hex("#E2ECED"), 1)])
        let thumbShadows: [BoxShadow] = dark
            ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.14))]
            : [.inner(0, 1, 0, 0, .white), .drop(0, 12, 24, -14, .rgba(12, 40, 44, 0.35))]
        let thumbIcon: Color = dark ? a.light.color() : .hex("#7D9498")
        let kbColor: Color = dark ? .hex("#1C1F22") : .hex("#D5D8DD")
        let kbText: Color = dark ? .hex("#7E858C") : .hex("#6B7280")
        let bodyFont = AppFont.ui(.dmSans, 15, 500)

        return SheetScreen(appearance: appearance, accentHex: accentHex) {
            SheetSurface(k: k, height: 790) {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        SheetHeader(title: "Artikel suchen", k: k, onClose: onClose)
                        FocusedSearchField(k: k, text: $query, placeholder: "Artikel suchen …", showsClear: false,
                                           showsDesignCursor: showsDesignCursor)
                            .padding(.top, 16)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                    // Leerzustand: top 150, bottom 384 innerhalb der Padding-Box (790 − 1 Rahmen) → Höhe 255
                    VStack(spacing: 14) {
                        SVGIcon(Icon.search, size: 30, color: thumbIcon, lineWidth: 1.8)
                            .frame(width: 72, height: 72)
                            .background(alignment: .topLeading) {
                                // left -20, top -30, 90×70
                                CSSRadialGradient(center: .center, extent: .ellipseClosestSide,
                                                  stops: [stop(.rgba(255, 255, 255, 0.5), 0), stop(.rgba(255, 255, 255, 0), 1)])
                                    .frame(width: 90, height: 70)
                                    .offset(x: -20, y: -30)
                            }
                            .clipShape(RR(24))
                            .background(CSSBox(shape: RR(24), paint: thumbPaint, shadows: thumbShadows))
                            .accessibilityHidden(true)
                        Text("Suche nach einem Artikel oder lege einen neuen an.")
                            .font(AppFont.dm(15, 500))
                            .foregroundStyle(k.sub)
                            .multilineTextAlignment(.center)
                            .cssLineHeight(21, font: bodyFont)          // line-height 1.4
                            .frame(maxWidth: 240)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 255)
                    .padding(.top, 150)

                    // CTA: links/rechts 20, unten 314 (= 300 Tastatur + 14)
                    CTAButton(title: "Neuen Artikel anlegen", k: k, action: onCreate)
                        .padding(.horizontal, 20)
                        .padding(.bottom, showsKeyboardPlaceholder ? 314 : 14)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    if showsKeyboardPlaceholder {
                        ZStack {
                            kbColor
                            Text("iOS-Tastatur")
                                .font(AppFont.dm(13, 600))
                                .tracking(0.78)                         // 0.06em × 13
                                .textCase(.uppercase)
                                .foregroundStyle(kbText)
                        }
                        .frame(height: 300)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

// MARK: - Treffer

struct SearchResultsScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var initialQuery = "Milch"
    var results: [SearchResult] = SearchResult.milkSamples
    var onClose: () -> Void = {}
    var onAdd: (SearchResult) -> Void = { _ in }
    var onCreate: (String) -> Void = { _ in }

    @State private var query: String? = nil

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         initialQuery: String = "Milch",
         results: [SearchResult] = SearchResult.milkSamples,
         onClose: @escaping () -> Void = {},
         onAdd: @escaping (SearchResult) -> Void = { _ in },
         onCreate: @escaping (String) -> Void = { _ in }) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.initialQuery = initialQuery
        self.results = results
        self.onClose = onClose
        self.onAdd = onAdd
        self.onCreate = onCreate
    }

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let dark = k.isDark
        let a = k.a
        let queryBinding = Binding<String>(get: { query ?? initialQuery }, set: { query = $0 })

        let card: Paint = dark
            ? .linear(180, [stop(.rgba(255, 255, 255, 0.07), 0), stop(.rgba(255, 255, 255, 0.03), 1)])
            : .color(.white)
        let cardBorder: Color = dark ? .rgba(255, 255, 255, 0.08) : .hex("#EDF2F2")
        let cardShadow: [BoxShadow] = dark
            ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08)), .drop(0, 12, 24, -14, .rgba(0, 0, 0, 0.7))]
            : [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 10, 22, -14, .rgba(12, 40, 44, 0.22))]
        let thumbPaint: Paint = dark
            ? .linear(150, [stop(a.base.color(0.22), 0), stop(a.base.color(0.06), 1)])
            : .linear(150, [stop(.hex("#F2F7F7"), 0), stop(.hex("#E4EEEF"), 1)])
        let thumbShadow: [BoxShadow] = dark
            ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.12))]
            : [.inner(0, 1, 0, 0, .white)]
        let thumbIcon: Color = dark ? a.light.color() : .hex("#7D9498")
        let addPaint: Paint = dark
            ? .color(a.base.color(0.14))
            : .linear(180, [stop(.white, 0), stop(a.base.color(0.1), 1)])
        let addBorder = a.base.color(dark ? 0.35 : 0.25)
        let addShadow: [BoxShadow] = dark
            ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.12))]
            : [.inner(0, 1, 0, 0, .white), .drop(0, 6, 14, -8, a.base.color(0.6))]
        let footer: [Gradient.Stop] = dark
            ? [stop(.rgba(10, 20, 22, 0), 0), stop(.hex("#0A1416"), 0.3)]
            : [stop(.rgba(255, 255, 255, 0), 0), stop(.white, 0.3)]
        let nameFont = AppFont.ui(.outfit, 16, 600)

        return SheetScreen(appearance: appearance, accentHex: accentHex) {
            SheetSurface(k: k, height: 790) {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            SheetHeader(title: "Artikel suchen", k: k, onClose: onClose)
                            FocusedSearchField(k: k, text: queryBinding, placeholder: "Artikel suchen …", showsClear: true)
                                .padding(.top, 16)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 20)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(results.count) Treffer")
                                    .font(AppFont.dm(13, 600))
                                    .tracking(0.52)                       // 0.04em × 13
                                    .textCase(.uppercase)
                                    .foregroundStyle(k.sub)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(results) { r in
                                    HStack(spacing: 14) {
                                        SVGIcon(Icon.cart, size: 22, color: thumbIcon, lineWidth: 1.8)
                                            .frame(width: 52, height: 52)
                                            .background(CSSBox(shape: RR(16), paint: thumbPaint, shadows: thumbShadow))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(r.name)
                                                .font(AppFont.outfit(16, 600))
                                                .foregroundStyle(k.text)
                                                .cssLineHeight(20, font: nameFont)   // line-height 1.25
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text("\(r.brand) · \(r.size)")
                                                .font(AppFont.dm(13, 400))
                                                .foregroundStyle(k.sub)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Button(action: { onAdd(r) }) {
                                            SVGIcon(Icon.plus, size: 20, color: k.accentText, lineWidth: 2.4)
                                                .frame(width: 44, height: 44)
                                                .background(CSSBox(shape: Circle(), paint: addPaint, border: 1,
                                                                   borderColor: addBorder, shadows: addShadow))
                                                .contentShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("\(r.name) hinzufügen")
                                    }
                                    .padding(11)                       // 10 padding + 1 border (content-box)
                                    .background(CSSBox(shape: RR(22), paint: card, border: 1,
                                                       borderColor: cardBorder, shadows: cardShadow))
                                }
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 128)   // Platz unter der Fußleiste
                        }
                        .scrollIndicators(.hidden)
                    }

                    // Fußleiste: Padding 18 / 20 / 34, Verlauf transparent → Sheet-Farbe bei 30 %
                    VStack(spacing: 0) {
                        CTAButton(title: "Neu anlegen: „\(queryBinding.wrappedValue)“", k: k,
                                  action: { onCreate(queryBinding.wrappedValue) })
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
                    .background(LinearGradient(stops: footer, startPoint: .top, endPoint: .bottom))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}
