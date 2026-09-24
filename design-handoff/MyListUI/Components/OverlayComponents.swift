//  OverlayComponents.swift
//  MyListUI
//
//  Bausteine der Overlay-Screens (Kontext-Menü, Dock-Menüs, Toasts):
//  • OverlayTheme      – Tokens aus renderVals() von MenuOverlay / SortMenu / CopyChoice /
//                        CopyDone / DeleteChoice / UndoToast (identische Akzent-Mathematik)
//  • OverlayStage      – Liste (Hintergrund) → optional Scrim → optional Dock → Overlay
//  • OverlayScrim      – `backdrop-filter: blur(2px)` + Abdunkelung
//  • PopoverMenu       – Radius 24, Rahmen 1, padding 6, optionaler Zeiger (Raute 14 × 14)
//  • PopoverMenuHeading / PopoverMenuRow / PopoverMenuDivider / OverlaySwitch
//  • GlassToast        – dunkles Glas (Light und Dark), Rahmen 1
//
//  Nicht nachgebildet: `backdrop-filter: blur(24px) saturate(160%)` von Menü und Toast.
//  Die Flächen sind zu 94–97 % deckend, der Effekt ist im statischen Design nicht sichtbar
//  (vgl. README „Grenzen der Plattform“, Punkt 3).

import SwiftUI

// MARK: - Tokens

struct OverlayTheme {
    /// Menü-Deckkraft: Kontext-Menü oben (MenuOverlay) .95 / .94, Dock-Menüs .97 / .96.
    enum MenuVariant {
        case listMenu
        case dockMenu
    }

    let appearance: Appearance
    let a: AccentScale
    var isDark: Bool { appearance == .dark }

    let text: Color
    let sub: Color
    let scrim: Color
    let line: Color

    let menu: Color
    /// Deckende Menüfarbe für den Zeiger
    let menuSolid: Color
    let menuBorder: Color
    let menuShadow: [BoxShadow]

    let accentText: Color
    /// Hervorgehobene Zeile
    let hi: Color
    let field: Color
    let fieldBorder: Color
    let danger: Color
    let dangerSoft: Color
    let toggleOn: Paint

    let toast: Color
    let toastBorder: Color
    let toastShadow: [BoxShadow]
    let okBg: Color
    let undoBg: Color
    let timer: Color

    /// Aktiver Menü-Knopf (nur MenuOverlay)
    let btn: Color
    let btnRing: Color

    init(_ appearance: Appearance, accentHex: String? = nil, variant: MenuVariant = .dockMenu) {
        self.appearance = appearance
        let a = AccentScale(accentHex ?? appearance.defaultAccent, appearance)
        self.a = a
        let w = { (alpha: Double) in Color.rgba(255, 255, 255, alpha) }

        if appearance == .dark {
            text = .hex("#EAF5F6")
            sub = .hex("#93ADB1")
            scrim = .rgba(0, 0, 0, 0.45)
            line = w(0.08)
            menu = .rgba(20, 34, 37, variant == .listMenu ? 0.94 : 0.96)
            menuSolid = .hex("#142225")
            menuBorder = w(0.1)
            menuShadow = [.inner(0, 1, 0, 0, w(0.08)), .drop(0, 24, 48, -16, .rgba(0, 0, 0, 0.8))]
            accentText = a.light.color()
            hi = a.base.color(0.14)
            field = w(0.05)
            fieldBorder = w(0.08)
            danger = .hex("#FF7A7E")
            dangerSoft = .rgba(255, 122, 126, 0.1)
            toggleOn = .linear(180, [stop(a.light.color(), 0), stop(a.base.color(), 1)])
            toast = .rgba(30, 48, 52, 0.95)
            toastBorder = w(0.12)
            toastShadow = [.inner(0, 1, 0, 0, w(0.1)), .drop(0, 16, 32, -14, .rgba(0, 0, 0, 0.8))]
            okBg = a.base.color(0.18)
            undoBg = a.base.color(0.16)
            timer = a.base.color(0.8)
            btn = .rgba(20, 34, 37, 0.94)
            btnRing = a.base.color(0.6)
        } else {
            text = .hex("#0F2528")
            sub = .hex("#5F7579")
            scrim = .rgba(8, 24, 27, 0.18)
            line = .hex("#EDF1F2")
            menu = .rgba(255, 255, 255, variant == .listMenu ? 0.95 : 0.97)
            menuSolid = .white
            menuBorder = .rgba(15, 37, 40, 0.08)
            menuShadow = [.drop(0, 24, 48, -16, .rgba(12, 40, 44, 0.35))]
            accentText = a.deep.color()
            hi = a.base.color(0.08)
            field = .hex("#F4F7F7")
            fieldBorder = .hex("#E6EDEE")
            danger = .hex("#C8363B")
            dangerSoft = .rgba(200, 54, 59, 0.07)
            toggleOn = .linear(180, [stop(a.base.color(), 0), stop(a.deep.color(), 1)])
            toast = .rgba(15, 27, 29, 0.94)
            toastBorder = w(0.1)
            toastShadow = [.inner(0, 1, 0, 0, w(0.12)), .drop(0, 16, 32, -14, .rgba(12, 30, 33, 0.5))]
            okBg = a.base.color(0.22)
            undoBg = a.base.color(0.18)
            timer = a.base.color(0.9)
            btn = .white
            btnRing = a.base.color(0.55)
        }
    }

    // Toast-Inhalte sind in beiden Modi gleich (dunkles Glas)
    var toastText: Color { .white }
    var toastSub: Color { .rgba(255, 255, 255, 0.65) }
    var toastIcon: Color { .rgba(255, 255, 255, 0.75) }
    /// `light` = mix(accent → Weiß, .32) – Häkchen (CopyDone) und „Rückgängig“ (UndoToast)
    var toastAccent: Color { a.light.color() }
}

// MARK: - Bühne

/// Aufbau aller Overlay-Artboards (absolute Ebenen, 390 × 844):
/// ListScreen → (Scrim mit Blur) → (DockView erneut oben drauf, links 20 / unten 34) → Overlay.
/// Das Overlay positioniert sich selbst (z. B. per `.frame(maxWidth:maxHeight:alignment:)`).
struct OverlayStage<Overlay: View>: View {
    let appearance: Appearance
    var accentHex: String? = nil
    var listState: ListRowState = .normal
    var showsScrim = true
    /// `nil` → kein zusätzliches Dock über der Liste
    var dock: DockActive? = nil
    var dockPill: DockPill = .open
    var onDismiss: () -> Void = {}
    @ViewBuilder let overlay: () -> Overlay

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        ZStack {
            if showsScrim {
                OverlayScrim(color: k.scrim, onTap: onDismiss) {
                    ListScreen(appearance: appearance, accentHex: accentHex, state: listState)
                }
            } else {
                ListScreen(appearance: appearance, accentHex: accentHex, state: listState)
            }

            if let dock {
                OverlayDockLayer(appearance: appearance, accentHex: accentHex, active: dock, pill: dockPill)
            }

            overlay()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()                                   // overflow: hidden
        .ignoresSafeArea()
    }
}

/// Scrim: `backdrop-filter: blur(2px)` auf den Hintergrund + Abdunkelung darüber.
struct OverlayScrim<Background: View>: View {
    let color: Color
    var blur: CGFloat = 2
    var onTap: () -> Void = {}
    @ViewBuilder let background: () -> Background

    var body: some View {
        ZStack {
            (background as () -> Background)()   // eindeutig: nicht View.background(ignoresSafeAreaEdges:)
                .blur(radius: blur, opaque: true)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            color
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .accessibilityHidden(true)
        }
    }
}

/// Dock über der Abdunkelung: 350 × 64, links 20, unten 34.
struct OverlayDockLayer: View {
    let appearance: Appearance
    var accentHex: String? = nil
    let active: DockActive
    var pill: DockPill = .open

    var body: some View {
        DockView(appearance: appearance, accentHex: accentHex, active: active, pill: pill)
            .frame(width: 350, height: 64)
            .padding(.leading, 20)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

// MARK: - Popover-Menü

/// Menü-Fläche: feste Breite (border-box), Rahmen 1, padding 6, Radius 24, Schatten.
/// `pointerLeft` = CSS `left` des Zeigers relativ zur Padding-Box (innerhalb des Rahmens), `bottom: -7px`.
struct PopoverMenu<Content: View>: View {
    let k: OverlayTheme
    let width: CGFloat
    var pointerLeft: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(7)                                  // 1 Rahmen + 6 padding
        .frame(width: width)
        .background(CSSBox(shape: RR(24), paint: .color(k.menu), border: 1, borderColor: k.menuBorder,
                           shadows: k.menuShadow))
        .overlay(alignment: .bottomLeading) {
            if let pointerLeft {
                // Zeiger-Box 15 × 15 (content-box 14 + Rahmen 1): links = 1 Rahmen + left,
                // Unterkante = Padding-Box-Unterkante + 7 = Menü-Unterkante − 1 + 7.
                PopoverPointer(fill: k.menuSolid, border: k.menuBorder)
                    .offset(x: 1 + pointerLeft, y: 6)
            }
        }
    }
}

/// Zeiger-Raute: `width/height: 14px; border-right/bottom: 1px; transform: rotate(45deg)`.
/// Kein box-sizing → Rahmenbox 15 × 15, gedreht um ihre Mitte. Hintergrund liegt unter dem Rahmen.
struct PopoverPointer: View {
    let fill: Color
    let border: Color

    var body: some View {
        ZStack {
            Rectangle().fill(fill)
            PointerBorderShape().fill(border)
        }
        .frame(width: 15, height: 15)
        .rotationEffect(.degrees(45))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Rahmen rechts + unten als eine Fläche (Ecke nicht doppelt deckend, wie in CSS).
private struct PointerBorderShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRect(CGRect(x: r.maxX - 1, y: r.minY, width: 1, height: r.height))
        p.addRect(CGRect(x: r.minX, y: r.maxY - 1, width: r.width - 1, height: 1))
        return p
    }
}

/// Versal-Label: font-weight 600, letter-spacing .06em, text-transform uppercase.
struct OverlayCapsLabel: View {
    let text: String
    var size: CGFloat = 12
    let color: Color

    var body: some View {
        Text(text)
            .font(AppFont.dm(size, 600))
            .tracking(size * 0.06)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}

/// Menü-Überschrift (Dock-Menüs): padding 10 12 6 12, 12/600 Versalien, Farbe sub.
struct PopoverMenuHeading: View {
    let text: String
    let k: OverlayTheme

    var body: some View {
        OverlayCapsLabel(text: text, size: 12, color: k.sub)
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 6, trailing: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Trennlinie: height 1, margin 4px 10px → belegt 9 pt Höhe.
struct PopoverMenuDivider: View {
    let k: OverlayTheme

    var body: some View {
        Rectangle()
            .fill(k.line)
            .frame(height: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .accessibilityHidden(true)
    }
}

enum PopoverMenuTrailing {
    /// nichts rechts
    case empty
    /// Häkchen 18, Strich 2.4, Akzent
    case check
    /// Zähler/Meta-Text 13 pt; `color == nil` → sub
    case text(String, weight: CGFloat = 600, color: Color? = nil)
}

/// Menüzeile: Icon 20 (Strich 1.9) · 12 · Titel 15 (+ Untertitel 12, Abstand 1) · 12 · Trailing.
/// • `.regular` – min-height 56, padding 8 12 (Zeilen mit Untertitel)
/// • `.compact` – height 48, padding 0 12 (Kontext-Menü)
/// Radius 16, Hintergrund optional (Hervorhebung / Gefahr).
struct PopoverMenuRow: View {
    enum Size {
        case regular
        case compact
    }

    let k: OverlayTheme
    let icon: [SVGElement]
    let title: String
    var subtitle: String? = nil
    var trailing: PopoverMenuTrailing = .empty
    var size: Size = .regular
    var titleWeight: CGFloat = 500
    /// Text- und Icon-Farbe (z. B. `k.danger`); nil → Titel `text`, Icon `accentText`
    var tint: Color? = nil
    var background: Color = .clear
    var isSelected = false
    /// opacity .45 + nicht bedienbar
    var isDisabled = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SVGIcon(icon, size: 20, color: tint ?? k.accentText, lineWidth: 1.9)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AppFont.dm(15, titleWeight))
                        .foregroundStyle(tint ?? k.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.dm(12, 400))
                            .foregroundStyle(k.sub)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailingView
            }
            .padding(.horizontal, 12)
            .padding(.vertical, size == .regular ? 8 : 0)
            .frame(maxWidth: .infinity)
            .frame(minHeight: size == .regular ? 56 : 48)
            .frame(height: size == .compact ? 48 : nil)
            .background(RR(16).fill(background))
            .contentShape(RR(16))
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.45 : 1)
        // Kein `.disabled`: das System könnte den Inhalt zusätzlich abblenden.
        .allowsHitTesting(!isDisabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isDisabled ? .isButton : [])
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .empty:
            EmptyView()
        case .check:
            SVGIcon(Icon.check, size: 18, color: k.accentText, lineWidth: 2.4)
        case .text(let value, let weight, let color):
            Text(value)
                .font(AppFont.dm(13, weight))
                .foregroundStyle(color ?? k.sub)
        }
    }
}

/// Schalter (nur Zustand „an“ im Design): 51 × 31, Radius 16, Verlauf toggleOn,
/// Knopf 25 weiß, oben/rechts 3, Schatten 0 2 4 rgba(0,0,0,.2).
struct OverlaySwitch: View {
    let k: OverlayTheme

    var body: some View {
        CSSBox(shape: Pill, paint: k.toggleOn)
            .frame(width: 51, height: 31)
            .overlay(alignment: .topTrailing) {
                CSSBox(shape: Circle(), paint: .color(.white), shadows: [.drop(0, 2, 4, 0, .rgba(0, 0, 0, 0.2))])
                    .frame(width: 25, height: 25)
                    .padding(3)
            }
            .accessibilityElement()
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue("An")
    }
}

// MARK: - Toast

/// Dunkles Glas-Toast: feste Höhe, Radius, border-box mit Rahmen 1, Inhalt 12 auseinander.
/// `leading`/`trailing` = CSS-padding (ohne Rahmen).
struct GlassToast<Content: View>: View {
    let k: OverlayTheme
    let height: CGFloat
    let radius: CGFloat
    let leading: CGFloat
    let trailing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.leading, leading + 1)
        .padding(.trailing, trailing + 1)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(CSSBox(shape: RR(radius), paint: .color(k.toast), border: 1, borderColor: k.toastBorder,
                           shadows: k.toastShadow))
    }
}
