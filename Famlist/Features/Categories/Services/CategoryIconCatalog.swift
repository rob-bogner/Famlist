/*
 CategoryIconCatalog.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Icon-Schlüssel ↔ SVG-Pfade für Kategorien (gespeichert in categories.icon).

 🔰 Notes for Beginners:
 - `groups` ist das Raster in „Kategorie bearbeiten“: 60 Icons in 8 Gruppen (Design: EditCategory.dc.html,
   Übersicht CategoryIcons.dc.html). Alle Icons: 24 × 24, Strich 1,9, runde Enden – wie die übrigen Hybrid-Icons.
 - `suggestedKey(for:)` schlägt beim Tippen des Namens ein passendes Icon vor („Milch…“ → milk).
 - `displayKey(name:icon:)` zeigt für die Standard-Kategorien die neuen, passenderen Icons, solange der
   Nutzer das alte Standard-Icon nicht selbst geändert hat (gespeicherte Daten bleiben unverändert).

 📝 Last Change:
 - Icon-Set von 14 auf 60 erweitert (Milch & Eier, Fleisch & Fisch, Getränke, Vorrat, Drogerie …).
 ------------------------------------------------------------------------
 */

import Foundation

enum CategoryIconCatalog {
    struct Choice: Hashable { let key: String; let label: String }
    struct Group: Hashable { let title: String; let choices: [Choice] }

    /// Raster in „Kategorie bearbeiten“ (gruppiert, Reihenfolge wie im Design).
    static let groups: [Group] = [
        Group(title: "Obst & Gemüse", choices: [
            Choice(key: "apple", label: "Apfel"), Choice(key: "carrot", label: "Karotte"), Choice(key: "broccoli", label: "Brokkoli"), Choice(key: "grapes", label: "Trauben"), Choice(key: "citrus", label: "Zitrus"), Choice(key: "tomato", label: "Tomate"), Choice(key: "mushroom", label: "Pilze"), Choice(key: "avocado", label: "Avocado"), Choice(key: "leaf", label: "Blatt")
        ]),
        Group(title: "Milch & Eier", choices: [
            Choice(key: "milk", label: "Milch"), Choice(key: "cheese", label: "Käse"), Choice(key: "egg", label: "Eier"), Choice(key: "yogurt", label: "Joghurt"), Choice(key: "butter", label: "Butter"), Choice(key: "drop", label: "Tropfen")
        ]),
        Group(title: "Fleisch & Fisch", choices: [
            Choice(key: "meat", label: "Fleisch"), Choice(key: "drumstick", label: "Geflügel"), Choice(key: "fish", label: "Fisch"), Choice(key: "sausage", label: "Wurst"), Choice(key: "flame", label: "Grillen")
        ]),
        Group(title: "Backwaren", choices: [
            Choice(key: "bread", label: "Brot"), Choice(key: "croissant", label: "Croissant"), Choice(key: "cupcake", label: "Kuchen"), Choice(key: "wheat", label: "Getreide"), Choice(key: "cutlery", label: "Besteck")
        ]),
        Group(title: "Getränke", choices: [
            Choice(key: "bottle", label: "Wasser"), Choice(key: "wine", label: "Wein"), Choice(key: "beer", label: "Bier"), Choice(key: "juice", label: "Saft"), Choice(key: "cup", label: "Kaffee & Tee"), Choice(key: "glass", label: "Glas")
        ]),
        Group(title: "Vorrat", choices: [
            Choice(key: "can", label: "Konserven"), Choice(key: "jar", label: "Gläser"), Choice(key: "pasta", label: "Nudeln & Reis"), Choice(key: "flour", label: "Backzutaten"), Choice(key: "salt", label: "Gewürze"), Choice(key: "oil", label: "Öl & Essig"), Choice(key: "pizza", label: "Fertiggerichte"), Choice(key: "bowl", label: "Müsli"), Choice(key: "snowflake", label: "Tiefkühl")
        ]),
        Group(title: "Süßes & Snacks", choices: [
            Choice(key: "candy", label: "Süßigkeiten"), Choice(key: "chocolate", label: "Schokolade"), Choice(key: "cookie", label: "Kekse"), Choice(key: "icecream", label: "Eis"), Choice(key: "fruit", label: "Obst")
        ]),
        Group(title: "Haushalt & Drogerie", choices: [
            Choice(key: "spray", label: "Putzmittel"), Choice(key: "toiletpaper", label: "Toilettenpapier"), Choice(key: "soap", label: "Körperpflege"), Choice(key: "tooth", label: "Zahnpflege"), Choice(key: "pill", label: "Apotheke"), Choice(key: "baby", label: "Baby"), Choice(key: "paw", label: "Tierbedarf"), Choice(key: "flower", label: "Blumen"), Choice(key: "bulb", label: "Technik"), Choice(key: "gift", label: "Geschenke"), Choice(key: "home", label: "Haushalt"), Choice(key: "dropSmall", label: "Reinigung"), Choice(key: "umbrella", label: "Saisonal"), Choice(key: "bag", label: "Einkauf"), Choice(key: "tag", label: "Sonstiges")
        ]),
    ]

    /// Alle wählbaren Schlüssel (flach).
    static let allKeys: [String] = groups.flatMap { $0.choices.map(\.key) }

    /// Bisheriges 5 × 2-Raster (bleibt für Kompatibilität erhalten).
    static let designChoices = ["leaf", "drop", "cutlery", "tag", "bag", "dropSmall", "bowl", "fruit", "umbrella", "cup"]

    static func label(for key: String) -> String {
        groups.lazy.flatMap(\.choices).first { $0.key == key }?.label ?? "Icon"
    }

    static func icon(for key: String) -> [SVGElement] {
        switch key {
        case "apple": return CategoryGlyph.apple
        case "carrot": return CategoryGlyph.carrot
        case "broccoli": return CategoryGlyph.broccoli
        case "grapes": return CategoryGlyph.grapes
        case "citrus": return CategoryGlyph.citrus
        case "tomato": return CategoryGlyph.tomato
        case "mushroom": return CategoryGlyph.mushroom
        case "avocado": return CategoryGlyph.avocado
        case "leaf": return Icon.leaf
        case "milk": return CategoryGlyph.milk
        case "cheese": return CategoryGlyph.cheese
        case "egg": return CategoryGlyph.egg
        case "yogurt": return CategoryGlyph.yogurt
        case "butter": return CategoryGlyph.butter
        case "drop": return Icon.drop
        case "meat": return CategoryGlyph.meat
        case "drumstick": return CategoryGlyph.drumstick
        case "fish": return CategoryGlyph.fish
        case "sausage": return CategoryGlyph.sausage
        case "flame": return Icon.flame
        case "bread": return CategoryGlyph.bread
        case "croissant": return CategoryGlyph.croissant
        case "cupcake": return CategoryGlyph.cupcake
        case "wheat": return CategoryGlyph.wheat
        case "cutlery": return Icon.cutlery
        case "bottle": return CategoryGlyph.bottle
        case "wine": return CategoryGlyph.wine
        case "beer": return CategoryGlyph.beer
        case "juice": return CategoryGlyph.juice
        case "cup": return EKKIcon.cup
        case "glass": return Icon.glass
        case "can": return CategoryGlyph.can
        case "jar": return CategoryGlyph.jar
        case "pasta": return CategoryGlyph.pasta
        case "flour": return CategoryGlyph.flour
        case "salt": return CategoryGlyph.salt
        case "oil": return CategoryGlyph.oil
        case "pizza": return CategoryGlyph.pizza
        case "bowl": return EKKIcon.bowl
        case "snowflake": return Icon.snowflake
        case "candy": return CategoryGlyph.candy
        case "chocolate": return CategoryGlyph.chocolate
        case "cookie": return CategoryGlyph.cookie
        case "icecream": return CategoryGlyph.icecream
        case "fruit": return EKKIcon.fruit
        case "spray": return CategoryGlyph.spray
        case "toiletpaper": return CategoryGlyph.toiletpaper
        case "soap": return CategoryGlyph.soap
        case "tooth": return CategoryGlyph.tooth
        case "pill": return CategoryGlyph.pill
        case "baby": return CategoryGlyph.baby
        case "paw": return CategoryGlyph.paw
        case "flower": return CategoryGlyph.flower
        case "bulb": return CategoryGlyph.bulb
        case "gift": return CategoryGlyph.gift
        case "home": return Icon.home
        case "dropSmall": return EKKIcon.dropSmall
        case "umbrella": return EKKIcon.umbrella
        case "bag": return EKKIcon.bag
        case "tag": return EKKIcon.tag
        default: return EKKIcon.tag
        }
    }

    static func key(for category: ItemCategory) -> String {
        switch category {
        case .obstGemuese: return "apple"
        case .milch: return "milk"
        case .backwaren: return "bread"
        case .getraenke: return "bottle"
        case .haushalt: return "spray"
        case .tiefkuehl: return "snowflake"
        case .fleisch: return "meat"
        case .sonstiges: return "tag"
        }
    }

    /// Alte Standard-Icons (vor dem erweiterten Set) je Standard-Kategorie.
    private static func legacyKey(for category: ItemCategory) -> String {
        switch category {
        case .obstGemuese: return "leaf"
        case .milch: return "drop"
        case .backwaren: return "cutlery"
        case .getraenke: return "glass"
        case .haushalt: return "home"
        case .tiefkuehl: return "snowflake"
        case .fleisch: return "flame"
        case .sonstiges: return "tag"
        }
    }

    /// Anzeige-Icon: Standard-Kategorie mit unverändertem alten Standard-Icon → neues Icon.
    static func displayKey(name: String, icon: String) -> String {
        guard let category = ItemCategory.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(name) == .orderedSame }),
              legacyKey(for: category) == icon else { return icon }
        return key(for: category)
    }

    /// Vorschlag beim Tippen eines Namens (Wortanfänge, ohne Groß-/Kleinschreibung).
    static func suggestedKey(for name: String) -> String? {
        let n = name.lowercased()
        guard n.count >= 3 else { return nil }
        for (words, key) in keywords where words.contains(where: { n.contains($0) }) { return key }
        return nil
    }

    private static let keywords: [([String], String)] = [
        (["milch", "molkerei", "dairy"], "milk"), (["käse", "kaese"], "cheese"), (["eier"], "egg"),
        (["joghurt", "quark"], "yogurt"), (["butter"], "butter"),
        (["fisch", "meeres"], "fish"), (["geflügel", "hähnchen", "huhn", "pute"], "drumstick"),
        (["wurst", "aufschnitt", "salami"], "sausage"), (["fleisch", "metzger"], "meat"), (["grill"], "flame"),
        (["obst", "frucht", "früchte"], "apple"), (["gemüse", "salat"], "carrot"), (["pilz"], "mushroom"),
        (["brot", "bäcker", "backw"], "bread"), (["kuchen", "gebäck"], "cupcake"), (["müsli", "cereal", "frühstück"], "bowl"),
        (["getränk", "wasser"], "bottle"), (["wein", "sekt"], "wine"), (["bier"], "beer"), (["saft"], "juice"),
        (["kaffee", "tee"], "cup"), (["konserve", "dose"], "can"), (["nudel", "reis", "pasta"], "pasta"),
        (["gewürz", "salz"], "salt"), (["öl", "essig"], "oil"), (["backzutat", "mehl", "zucker"], "flour"),
        (["fertig", "pizza"], "pizza"), (["tiefkühl", "tk", "gefror"], "snowflake"),
        (["süß", "suess", "snack", "naschen"], "candy"), (["schoko"], "chocolate"), (["keks"], "cookie"), (["eis"], "icecream"),
        (["putz", "reinig"], "spray"), (["toilett", "papier"], "toiletpaper"), (["drogerie", "pflege", "kosmetik", "hygiene"], "soap"),
        (["zahn"], "tooth"), (["apothek", "medizin"], "pill"), (["baby", "kind"], "baby"), (["tier", "hund", "katze"], "paw"),
        (["blume", "garten", "pflanze"], "flower"), (["technik", "elektro"], "bulb"), (["geschenk"], "gift"), (["haushalt"], "home")
    ]
}

/// Neue Kategorie-Icons (24 × 24, Strich 1,9, runde Enden). Quelle: CategoryIcons.dc.html.
enum CategoryGlyph {
    static let apple: [SVGElement] = [.path("M12 7.5c-1.5-1-5-1.3-6.3 1.6-1.4 3.1.2 7.4 2.3 9.4 1.2 1.1 2.4 1 4 .3 1.6.7 2.8.8 4-.3 2.1-2 3.7-6.3 2.3-9.4-1.3-2.9-4.8-2.6-6.3-1.6zM12 7.5c0-1.9.8-3.3 2.5-4.3")]
    static let carrot: [SVGElement] = [.path("M15.5 8.5c-1.8-1.8-4.7-1.6-6.2.5L3.5 20.5l11.5-5.8c2.1-1.5 2.3-4.4.5-6.2zM15.5 8.5 20 4M15 7.2c.2-1.8 1.2-3 2.8-3.6M16.8 9c1.8-.2 3-1.2 3.6-2.8M9.6 13.1l1.4 1.4M7.1 16.6l1.2 1.2")]
    static let broccoli: [SVGElement] = [.path("M8 13a3 3 0 0 1-.6-5.9A3.5 3.5 0 0 1 14 5.3a3 3 0 0 1 4 3.6A3 3 0 0 1 16 13zM10 13l.8 7.5h2.4L14 13M12 13v3.5")]
    static let grapes: [SVGElement] = [.circle(8, 10, 2), .circle(12, 10, 2), .circle(16, 10, 2), .circle(10, 13.8, 2), .circle(14, 13.8, 2), .circle(12, 17.6, 2), .path("M12 8V5.8c0-1 .7-2 2-2.3")]
    static let citrus: [SVGElement] = [.circle(12, 12, 8), .path("M12 6.5v11M6.5 12h11M8.1 8.1l7.8 7.8M15.9 8.1l-7.8 7.8")]
    static let tomato: [SVGElement] = [.path("M12 7c-4.4 0-7.5 2.7-7.5 6.3S7.6 20 12 20s7.5-3.1 7.5-6.7S16.4 7 12 7zM12 7 9.8 4.8M12 7l2.2-2.2M12 7V3.8M12 7l-3.5.6M12 7l3.5.6")]
    static let mushroom: [SVGElement] = [.path("M4 12a8 8 0 0 1 16 0zM9.5 12v6.5a2.5 2.5 0 0 0 5 0V12M9.5 8.3h.01M14.2 7.5h.01")]
    static let avocado: [SVGElement] = [.path("M12 2.5c-2.3 0-3.7 2.8-4.6 5.7-.7 2.3-2.4 4.2-2.4 6.8a7 7 0 0 0 14 0c0-2.6-1.7-4.5-2.4-6.8C15.7 5.3 14.3 2.5 12 2.5z"), .circle(12, 15, 2.8)]
    static let milk: [SVGElement] = [.path("M7.5 9 9 5.5h6L16.5 9v11.5h-9zM7.5 9h9M9 5.5V3h6v2.5M7.5 13.5c1.5-.8 3-.8 4.5 0s3 .8 4.5 0")]
    static let cheese: [SVGElement] = [.path("M4 18.5V12l10-7 6 6v7.5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1zM4 12h16"), .circle(8.5, 15.5, 1.3), .circle(14.5, 16, 1.6)]
    static let egg: [SVGElement] = [.path("M12 3.5c-3.3 0-6 5-6 9.5a6 6 0 0 0 12 0c0-4.5-2.7-9.5-6-9.5z")]
    static let yogurt: [SVGElement] = [.path("M6 8h12l-1.5 11.5a1.5 1.5 0 0 1-1.5 1.3H9a1.5 1.5 0 0 1-1.5-1.3zM5 5h14v3H5zM8 12.5c1.3.7 2.7.7 4 0s2.7-.7 4 0")]
    static let butter: [SVGElement] = [.path("M3.5 13 9 8.5h11.5V16L15 20.5H3.5zM3.5 13H15v7.5M15 13l5.5-4.5")]
    static let meat: [SVGElement] = [.path("M6 18.5c-2.8-2.1-3.2-6-1-9.4C7.3 5.6 11.7 3.8 15.4 4.6c3.3.7 5.3 3.7 4.3 7-.6 2-2.1 3-3.7 3.6-1.8.7-2.6 1.6-3.2 3.1-1 2.4-4.1 2.3-6.8.2z"), .circle(14.8, 9.6, 1.9)]
    static let drumstick: [SVGElement] = [.path("M15.2 3.5a5.3 5.3 0 0 1 5.3 5.3c0 3.8-3.6 6.1-6.8 5.3l-3.3 3.3-1 1a2.1 2.1 0 1 1-2.8 2.8 2.1 2.1 0 1 1-2.8-2.8 2.1 2.1 0 1 1 2.8-2.8l1-1 3.3-3.3c-.8-3.2 1.5-6.8 5.3-6.8z")]
    static let fish: [SVGElement] = [.path("M6.5 12c2.2-3.3 5-5 8-5s5.2 1.8 7 5c-1.8 3.2-4 5-7 5s-5.8-1.7-8-5zM6.5 12 2.5 8.5v7zM17 11h.01")]
    static let sausage: [SVGElement] = [.path("M6.3 17.7a3 3 0 0 1 0-4.2l7.2-7.2a3 3 0 0 1 4.2 4.2l-7.2 7.2a3 3 0 0 1-4.2 0zM6.3 17.7l-2 2M17.7 6.3l2-2M10.3 11.7l1.5 1.5M12.8 9.2l1.5 1.5")]
    static let bread: [SVGElement] = [.path("M5 11.5a3.5 3.5 0 0 1 0-7h14a3.5 3.5 0 0 1 0 7v8a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1zM9.5 13.5l2-2M12.5 16l2-2")]
    static let croissant: [SVGElement] = [.path("M12 7c-3 0-5 1.6-5.8 3.7L9 16h6l2.8-5.3C17 8.6 15 7 12 7zM6.2 10.7C3.8 11 2.5 13 2.5 15.3l4.3 2.2L9 16M17.8 10.7c2.4.3 3.7 2.3 3.7 4.6l-4.3 2.2L15 16M10.5 7.4 11 16M13.5 7.4 13 16")]
    static let cupcake: [SVGElement] = [.path("M5.5 11h13l-1.5 8.5a1 1 0 0 1-1 .8H8a1 1 0 0 1-1-.8zM5.5 11a3 3 0 0 1 1.5-5.5 5 5 0 0 1 10 0 3 3 0 0 1 1.5 5.5M10 11l.5 9.3M14 11l-.5 9.3")]
    static let wheat: [SVGElement] = [.path("M12 21V7M12 11c-2.5 0-4-1.5-4-4 2.5 0 4 1.5 4 4zM12 11c2.5 0 4-1.5 4-4-2.5 0-4 1.5-4 4zM12 15.5c-2.5 0-4-1.5-4-4 2.5 0 4 1.5 4 4zM12 15.5c2.5 0 4-1.5 4-4-2.5 0-4 1.5-4 4zM12 7c-1-1-1.2-2.5-.1-4 1.1 1.5.9 3 .1 4z")]
    static let bottle: [SVGElement] = [.path("M10 2.5h4M10.5 2.5v3l-2 3v11.5A1.5 1.5 0 0 0 10 21.5h4a1.5 1.5 0 0 0 1.5-1.5V8.5l-2-3v-3M8.5 12h7M8.5 16.5h7")]
    static let wine: [SVGElement] = [.path("M7.5 3h9l-.5 5a4 4 0 0 1-8 0zM12 12v8.5M8.5 20.5h7M7.8 6.5h8.4")]
    static let beer: [SVGElement] = [.path("M5 8h10v11.5a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1zM15 10.5h2.5A1.5 1.5 0 0 1 19 12v3.5a1.5 1.5 0 0 1-1.5 1.5H15M5 8a2.5 2.5 0 0 1 2.3-3.5A3 3 0 0 1 12.5 4 2.5 2.5 0 0 1 15 8M8.5 11.5v6M11.5 11.5v6")]
    static let juice: [SVGElement] = [.path("M7 7h10v13a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1zM7 7l1.5-2.5h7L17 7M14 4.5l1-2.5h2.5"), .circle(12, 14, 2.2)]
    static let can: [SVGElement] = [.path("M5.5 6c0-1.4 2.9-2.5 6.5-2.5s6.5 1.1 6.5 2.5v12c0 1.4-2.9 2.5-6.5 2.5s-6.5-1.1-6.5-2.5zM5.5 6c0 1.4 2.9 2.5 6.5 2.5s6.5-1.1 6.5-2.5M5.5 10c0 1.4 2.9 2.5 6.5 2.5s6.5-1.1 6.5-2.5M5.5 14.5c0 1.4 2.9 2.5 6.5 2.5s6.5-1.1 6.5-2.5")]
    static let jar: [SVGElement] = [.path("M8 3.5h8V7H8zM7 7h10a1.5 1.5 0 0 1 1.5 1.5V19a2 2 0 0 1-2 2h-9a2 2 0 0 1-2-2V8.5A1.5 1.5 0 0 1 7 7zM5.5 12h13M5.5 16.5h13")]
    static let pasta: [SVGElement] = [.path("M3.5 11.5h17a8.5 8.5 0 0 1-17 0zM8 11.5V4M11 11.5V3.5M14 11.5 16.5 4")]
    static let flour: [SVGElement] = [.path("M7 6.5 8.5 3.5h7L17 6.5M6.5 7h11c1 3.5 1.5 7 1 10.5a2.5 2.5 0 0 1-2.5 2h-8a2.5 2.5 0 0 1-2.5-2C5 14 5.5 10.5 6.5 7zM9.5 12.5h5")]
    static let salt: [SVGElement] = [.path("M8 8.5h8l1 11a1.5 1.5 0 0 1-1.5 1.5h-7A1.5 1.5 0 0 1 7 19.5zM8.5 8.5a3.5 3.5 0 0 1 7 0M10.5 6.5h.01M13.5 6.5h.01M12 5h.01")]
    static let oil: [SVGElement] = [.path("M10.5 2.5h3v3l2.5 3.5v11a1.5 1.5 0 0 1-1.5 1.5h-5A1.5 1.5 0 0 1 8 20V9l2.5-3.5zM12 12.5c-1.2 1.5-1.8 2.6-1.8 3.4a1.8 1.8 0 0 0 3.6 0c0-.8-.6-1.9-1.8-3.4z")]
    static let pizza: [SVGElement] = [.path("M12 21.5 3.5 7a13 13 0 0 1 17 0zM5 9.5a10 10 0 0 1 14 0M10 11.5h.01M14 12.5h.01M12 16h.01")]
    static let candy: [SVGElement] = [.circle(12, 12, 3.5), .path("M8.6 11 4 7.5 3 12l1 4.5 4.6-3.5M15.4 11 20 7.5l1 4.5-1 4.5-4.6-3.5")]
    static let chocolate: [SVGElement] = [.path("M7 3.5h10a1 1 0 0 1 1 1v15a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1v-15a1 1 0 0 1 1-1zM6 9h12M6 15h12M12 3.5v17")]
    static let cookie: [SVGElement] = [.circle(12, 12, 8.5), .path("M9 9h.01M14.5 8.5h.01M15.5 14h.01M9.5 15h.01M12 12h.01")]
    static let icecream: [SVGElement] = [.path("M7.5 11 12 21.5 16.5 11M7 11a5 5 0 1 1 10 0zM9.5 11c0-1.6.9-3 2.5-3.5")]
    static let spray: [SVGElement] = [.path("M9 8h5v2.5l2 2V20a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1v-7.5l2-2zM9.5 8V5.5H14l3 1.5M14 5.5V4h-4M19.5 5h.01M20 8h.01")]
    static let toiletpaper: [SVGElement] = [.path("M8 4c-2.2 0-4 2.2-4 5s1.8 5 4 5 4-2.2 4-5-1.8-5-4-5zM8 4h8c2.2 0 4 2.2 4 5v10.5h-8V9M8 9h.01")]
    static let soap: [SVGElement] = [.path("M8 10h8a1.5 1.5 0 0 1 1.5 1.5v8A1.5 1.5 0 0 1 16 21H8a1.5 1.5 0 0 1-1.5-1.5v-8A1.5 1.5 0 0 1 8 10zM10.5 10V7h3v3M12 7V4h4.5v1.5M9.5 14.5h5")]
    static let tooth: [SVGElement] = [.path("M7.5 4C5.5 4 4 5.5 4 8c0 3 1.5 4 2 6.5.5 2.6.8 6 2.5 6 1.3 0 1.5-4 3.5-4s2.2 4 3.5 4c1.7 0 2-3.4 2.5-6 .5-2.5 2-3.5 2-6.5 0-2.5-1.5-4-3.5-4-2 0-2.7 1-4.5 1S9.5 4 7.5 4z")]
    static let pill: [SVGElement] = [.path("M10.3 20.2a4.8 4.8 0 0 1-6.8-6.8l9.9-9.9a4.8 4.8 0 0 1 6.8 6.8zM8.5 8.5l7 7")]
    static let baby: [SVGElement] = [.path("M9 9h6v10a2 2 0 0 1-2 2h-2a2 2 0 0 1-2-2zM8.5 9h7M10 9V7a2 2 0 0 1 4 0v2M12 5V3.5M9 13h2M9 16h2")]
    static let paw: [SVGElement] = [.circle(6.5, 10, 1.8), .circle(10, 6, 1.8), .circle(14, 6, 1.8), .circle(17.5, 10, 1.8), .path("M12 11c-2.8 0-5.5 3.6-5.5 6.2 0 1.6 1.3 2.3 2.8 2.3 1.2 0 1.8-.6 2.7-.6s1.5.6 2.7.6c1.5 0 2.8-.7 2.8-2.3 0-2.6-2.7-6.2-5.5-6.2z")]
    static let flower: [SVGElement] = [.path("M12 13c-3 0-5-2.5-5-6V4l2.5 2L12 3.5 14.5 6 17 4v3c0 3.5-2 6-5 6zM12 13v8M12 17.5c-2.5 0-4.5-1.5-5-3.5M12 19.5c2.5 0 4.5-1.5 5-3.5")]
    static let bulb: [SVGElement] = [.path("M9 18h6M10 21h4M12 3a6 6 0 0 0-3.6 10.8c.6.5 1.1 1.3 1.1 2.2v.1h5V16c0-.9.5-1.7 1.1-2.2A6 6 0 0 0 12 3z")]
    static let gift: [SVGElement] = [.path("M4 9h16v3.5H4zM5.5 12.5h13v8h-13zM12 9v11.5M12 9c-1.5-3-5.5-4-5.5-1.5S10 9 12 9zM12 9c1.5-3 5.5-4 5.5-1.5S14 9 12 9z")]
}
