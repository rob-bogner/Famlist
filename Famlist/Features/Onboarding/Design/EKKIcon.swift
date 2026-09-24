/*
 EKKIcon.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Icons der Gruppe „Einstieg, Kategorien, Kassenzettel“ (Pfade exakt aus den Artboards).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OnboardingScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum EKKIcon {
    static let apple: [SVGElement] = [.path("M16.4 12.6c0-2.4 2-3.6 2.1-3.7-1.2-1.7-3-1.9-3.6-2-1.5-.2-3 .9-3.8.9-.8 0-2-.9-3.3-.9-1.7 0-3.3 1-4.1 2.5-1.8 3.1-.5 7.6 1.3 10.1.8 1.2 1.8 2.6 3.1 2.5 1.2 0 1.7-.8 3.2-.8s1.9.8 3.2.8c1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.8 0 0-2.4-1-2.4-4.2zM14 5.3c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4z")]
    static let camera: [SVGElement] = [.path("M4 8a2 2 0 0 1 2-2h2l1.5-2h5L16 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8z"),
                                       .path("M15.5 12.5a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0z")]
    static let map: [SVGElement] = [.path("M3 7l6-3 6 3 6-3v13l-6 3-6-3-6 3zM9 4v13M15 7v13")]
    static let grip: [SVGElement] = [.path("M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01")]
    static let tag: [SVGElement] = [.path("M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8zM8 7.2v1.6")]
    static let bag: [SVGElement] = [.path("M4 9h16l-1.5 10.5a2 2 0 0 1-2 1.5h-9a2 2 0 0 1-2-1.5zM8 9V6a4 4 0 0 1 8 0v3")]
    static let dropSmall: [SVGElement] = [.path("M12 3c3 3 5 6 5 9a5 5 0 0 1-10 0c0-3 2-6 5-9z")]
    static let bowl: [SVGElement] = [.path("M5 10h14v4a7 7 0 0 1-14 0zM9 6c0-1 1-2 1-3M13 6c0-1 1-2 1-3")]
    static let fruit: [SVGElement] = [.path("M7 20c-2-4-2-9 1-12 2-2 6-2 8 0 3 3 3 8 1 12zM12 8V4")]
    static let umbrella: [SVGElement] = [.path("M4 12a8 8 0 0 1 16 0zM12 12v8M9 20h6")]
    static let cup: [SVGElement] = [.path("M6 3h12l-1 18H7zM6 8h12")]
    static let alert: [SVGElement] = [.path("M12 8v5M12 16.5v.3")]
    static let trend: [SVGElement] = [.path("M4 19h16M6 15l4-4 3 3 5-6")]
    static let flash: [SVGElement] = [.path("M13 2 4 14h7l-1 8 9-12h-7z")]
    static let gallery: [SVGElement] = [.path("M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2zM4 16l4.5-4.5 4 4 3-3L20 17"),
                                        .path("M16 8.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0z")]
}
