/*
 WatchScreens.swift
 Famlist Watch – Design-Referenz

 Alle Watch-Screens aus dem Canvas (Seite „Watch“), 208 × 248 pt, pixelgenau aus Watch*.dc.html übersetzt.
 Beispieldaten und leere Callbacks – bei der Übernahme durch echte Daten ersetzen. Eine Type je Datei aufteilen.
 Kopfzeile (Titel + Uhrzeit) ist im Design gezeichnet; in watchOS übernimmt das System die Uhrzeit →
 Titel als navigationTitle / Toolbar setzen, Farbe accentText (Outfit 17/600).
 */

import SwiftUI

// MARK: - Einkaufsliste (WatchList.dc.html)

struct WatchListScreen: View {
    var w = WatchTheme()
    var title = "My List"
    var checked = 2
    var total = 6
    var onToggle: (String) -> Void = { _ in }
    var onCheckAll: () -> Void = {}
    var onAdd: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    // Fortschritt: „2 von 6 erledigt“ (DM 12, Zahl weiß 600) + Balken 5, Abstand 5, Innenabstand 0 4 2 4
                    VStack(alignment: .leading, spacing: 5) {
                        (Text("\(checked)").foregroundStyle(.white).fontWeight(.semibold)
                         + Text(" von \(total) erledigt").foregroundStyle(w.sub))
                            .font(WatchFont.dm(12))
                        WatchProgressBar(w: w, fraction: total == 0 ? 0 : Double(checked) / Double(total))
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)

                    WatchSectionLabel(w: w, text: "Obst & Gemüse")
                    WatchItemRow(w: w, name: "Bananen", quantity: "6 Stück")
                    WatchItemRow(w: w, name: "Tomaten", quantity: "500 g")
                    WatchItemRow(w: w, name: "Äpfel", quantity: "1 kg", isChecked: true)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 58)                     // Platz für die Knöpfe unten
            }
            // Verlauf unten: 70 hoch, transparent → schwarz .85 bei 55 %
            LinearGradient(stops: [.init(color: .black.opacity(0), location: 0), .init(color: .black.opacity(0.85), location: 0.55)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 70)
                .allowsHitTesting(false)
            HStack {
                WatchGlassButton(w: w, systemImage: "checkmark.circle", label: "Alle abhaken", action: onCheckAll)
                Spacer()
                WatchFab(w: w, action: onAdd)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .background(WatchBackground(w: w))
        .navigationTitle { Text(title).font(WatchFont.outfit(17)).foregroundStyle(w.accentText) }
    }
}

// MARK: - Artikel (WatchItem.dc.html)

struct WatchItemScreen: View {
    var w = WatchTheme()
    var name = "Butter"
    var category = "Milchprodukte"
    @State var units = 1
    var unitName = "Packung"
    var onCheck: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 6) {
                Text(name).font(WatchFont.outfit(22)).tracking(-0.22).lineSpacing(0)
                Text(category)
                    .font(WatchFont.dm(12, .semibold)).foregroundStyle(w.accentText)
                    .padding(.vertical, 3).padding(.horizontal, 9)
                    .background(Capsule().fill(w.chip))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            // Mengen-Stepper: 56 hoch, Innenabstand 0 6, Radius 18; Knöpfe 40 (weiß .12), Zahl Outfit 24 accentText
            HStack {
                stepButton("minus", label: "Weniger") { units = max(1, units - 1) }
                Spacer()
                VStack(spacing: 0) {
                    Text("\(units)").font(WatchFont.outfit(24)).foregroundStyle(w.accentText)
                    Text(unitName).font(WatchFont.dm(11)).foregroundStyle(w.sub)
                }
                Spacer()
                stepButton("plus", label: "Mehr") { units += 1 }
            }
            .padding(.horizontal, 6)
            .frame(height: 56)
            .background(WatchCardBackground(w: w))
            .focusable()
            .digitalCrownRotation(detent: $units, from: 1, through: 99, by: 1, sensitivity: .low,
                                  isContinuous: false, isHapticFeedbackEnabled: true)

            Text("Menge mit der Krone ändern").font(WatchFont.dm(11)).foregroundStyle(w.faint)

            // CTA „Abhaken“: 44 hoch, Radius 22, Verlauf light → accent, Text #04262A 15/600, Haken 16
            Button(action: onCheck) {
                Label("Abhaken", systemImage: "checkmark")
                    .font(WatchFont.dm(15, .semibold)).foregroundStyle(w.ctaText)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Capsule().fill(w.ctaGradient))
                    .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1).mask(Rectangle().frame(height: 2).frame(maxHeight: .infinity, alignment: .top)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .background(WatchBackground(w: w))
        .navigationTitle { Text("My List").font(WatchFont.outfit(17)).foregroundStyle(w.accentText) }   // „‹ My List“
    }

    private func stepButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 40, height: 40).background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Hinzufügen (WatchAdd.dc.html)

struct WatchAddScreen: View {
    var w = WatchTheme()
    var frequent: [(name: String, detail: String)] = [("Milch", "Milchprodukte"), ("Brot", "Backwaren"), ("Eier", "10 Stück")]
    var onDictate: () -> Void = {}
    var onAdd: (String) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                // Eingabe: 48 hoch, Radius 24, Innenabstand 0 6 0 14, Platzhalter weiß .6, Mikrofon-Orb 36
                Button(action: onDictate) {
                    HStack(spacing: 8) {
                        Text("Artikel …").font(WatchFont.dm(15)).foregroundStyle(w.sub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "mic").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(w.orb())).shadow(color: w.fabGlow, radius: 7)
                    }
                    .padding(.leading, 14).padding(.trailing, 6)
                    .frame(height: 48)
                    .background(WatchCardBackground(w: w, radius: 24))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Artikel diktieren oder eingeben")

                WatchSectionLabel(w: w, text: "Oft gekauft")
                ForEach(frequent, id: \.name) { item in
                    Button { onAdd(item.name) } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name).font(WatchFont.dm(15, .medium)).lineLimit(1)
                                Text(item.detail).font(WatchFont.dm(12)).foregroundStyle(w.sub).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "plus").font(.system(size: 12, weight: .heavy)).foregroundStyle(w.accentText)
                                .frame(width: 28, height: 28).background(Circle().fill(w.chip))
                        }
                        .padding(.horizontal, 12).frame(height: 46)
                        .background(WatchCardBackground(w: w))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.name) hinzufügen")
                }
            }
            .padding(.horizontal, 12)
        }
        .background(WatchBackground(w: w))
        .navigationTitle { Text("Hinzufügen").font(WatchFont.outfit(17)).foregroundStyle(w.accentText) }
    }
}

// MARK: - Alles erledigt (WatchDone.dc.html)

struct WatchDoneScreen: View {
    var w = WatchTheme()
    var count = 6
    var listName = "My List"
    var onReset: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            // Ring 96: r 42, Strich 9, voll; Verlauf light → accent (diagonal); Haken weiß Strich 6
            ZStack {
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 9)
                Circle().stroke(LinearGradient(colors: [w.accentText, w.accent.color()], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                Image(systemName: "checkmark").font(.system(size: 30, weight: .heavy)).foregroundStyle(.white)
            }
            .padding(4.5)
            .frame(width: 96, height: 96)
            Text("Alles erledigt").font(WatchFont.outfit(19)).padding(.top, 2)
            Text("\(count) Artikel · \(listName)").font(WatchFont.dm(12)).foregroundStyle(w.sub)
            Spacer(minLength: 0)
            Button(action: onReset) {
                Text("Zurücksetzen").font(WatchFont.dm(14, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(Capsule().fill(LinearGradient(colors: [w.glassTop, w.glassBottom], startPoint: .top, endPoint: .bottom)))
                    .overlay(Capsule().strokeBorder(w.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .background(WatchBackground(w: w))
        .navigationTitle { Text(listName).font(WatchFont.outfit(17)).foregroundStyle(w.accentText) }
    }
}

// MARK: - Listen (WatchLists.dc.html)

struct WatchListsScreen: View {
    struct Entry: Identifiable { let id = UUID(); let name: String; let status: String; let fraction: Double; var favorite = false }
    var w = WatchTheme()
    var lists: [Entry] = [.init(name: "My List", status: "4 von 6 offen", fraction: 1.0 / 3.0, favorite: true),
                          .init(name: "Drogerie", status: "3 offen", fraction: 0),
                          .init(name: "Getränke", status: "erledigt", fraction: 1)]
    var onSelect: (Entry) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(lists) { list in
                    // Zeile 56, Innenabstand 0 12, Ring 30, Name Outfit 16/600, Status DM 12 .6, Stern 14 accentText
                    Button { onSelect(list) } label: {
                        HStack(spacing: 10) {
                            WatchRing(w: w, fraction: list.fraction)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(list.name).font(WatchFont.outfit(16)).lineLimit(1)
                                Text(list.status).font(WatchFont.dm(12)).foregroundStyle(w.sub)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if list.favorite {
                                Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(w.accentText)
                                    .accessibilityLabel("Favorit")
                            }
                        }
                        .padding(.horizontal, 12).frame(height: 56)
                        .background(WatchCardBackground(w: w))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .background(WatchBackground(w: w))
        .navigationTitle { Text("Listen").font(WatchFont.outfit(17)).foregroundStyle(w.accentText) }
    }
}

#Preview("Liste") { NavigationStack { WatchListScreen() } }
#Preview("Artikel") { NavigationStack { WatchItemScreen() } }
#Preview("Hinzufügen") { NavigationStack { WatchAddScreen() } }
#Preview("Erledigt") { NavigationStack { WatchDoneScreen() } }
#Preview("Listen") { NavigationStack { WatchListsScreen() } }
