/*
 UITestFixture.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Startmodus für UI-Tests: Mit dem Launch-Argument `-uiTestFixture` zeigt die App direkt den echten
   ShoppingListView mit 16 In-Memory-Artikeln – ohne Anmeldung und ohne Supabase.

 🔰 Notes for Beginners:
 - Nur in DEBUG-Builds enthalten; Release-Builds kennen diesen Typ nicht.
 - Genutzt von FamlistUITests/SwipeUITests (Wischgeste auf Gerät oder Simulator).
 - Die Artikelnamen („Äpfel“, „Butter“ …) und Listen („My List“, „Drogerie“, geteilte „WG-Einkauf“)
   sind Teil des Test-Vertrags; beim Ändern die UI-Tests anpassen.

 📝 Last Change:
 - Drei Listen und ein angemeldetes Testprofil für das Sheet „Meine Listen“.
 ------------------------------------------------------------------------
 */

#if DEBUG
import SwiftUI

/// In-memory list and session for UI tests (launch argument `-uiTestFixture`).
@MainActor
enum UITestFixture {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-uiTestFixture")
    private static let args = ProcessInfo.processInfo.arguments
    /// `-designFixture`: Beispieldaten exakt wie in den Design-Artboards (für den Pixel-Abgleich).
    static let designMode = args.contains("-designFixture")

    static let listVM: ListViewModel = {
        let repo = PreviewItemsRepository()
        let container = PersistenceController.preview.container
        let vm = ListViewModel(listId: UUID(), repository: repo,
                               itemStore: SwiftDataItemStore(context: container.mainContext),
                               listStore: SwiftDataListStore(context: container.mainContext))
        vm.configure(syncEngine: PreviewSyncEngine(repository: repo))
        vm.configure(catalogRepository: PreviewItemCatalogRepository())
        let active = ListModel(id: vm.listId, ownerId: ownerId, title: "My List", isDefault: true,
                               createdAt: Date(), updatedAt: Date())
        vm.defaultList = active
        vm.allLists = [active,
                       ListModel(id: UUID(), ownerId: ownerId, title: "Drogerie", isDefault: false,
                                 createdAt: Date(), updatedAt: Date()),
                       ListModel(id: UUID(), ownerId: UUID(), title: "WG-Einkauf", isDefault: false,
                                 createdAt: Date(), updatedAt: Date())]
        if designMode {
            // Design-Abgleich (Hybrid.dc.html): genau ein Artikel „Butter · 1 Packung“ in Milchprodukte.
            // -designEmpty: leere Liste, -designChecked: Butter abgehakt.
            if !args.contains("-designEmpty") {
                vm.addItem(ItemModel(name: "Butter", units: 1, measure: "pack", isChecked: args.contains("-designChecked"),
                                     category: ItemCategory.sonstiges.rawValue, listId: vm.listId.uuidString))
            }
        } else {
            for (name, category) in sampleItems {
                // `-fixtureLargeImage`: „Brot“ mit großem Foto (~600 KB Base64 wie auf dem Gerät).
                let image = name == "Brot" && args.contains("-fixtureLargeImage") ? largeImageBase64 : nil
                vm.addItem(ItemModel(imageData: image, name: name, units: 1, category: category.rawValue,
                                     listId: vm.listId.uuidString))
            }
        }
        vm.listItemCounts = Dictionary(uniqueKeysWithValues: vm.allLists.map { ($0.id, $0.id == vm.listId ? sampleItems.count : 2) })
        return vm
    }()

    /// Startscreen der Fixture. `-designScreen signIn|profileSetup|acceptInvite` zeigt einen Einstiegs-Screen
    /// statt der Liste (Pixel-Abgleich gegen design-handoff/Design/png).
    static var rootView: some View {
        FixtureAppearance { screen }
    }

    @ViewBuilder
    private static var screen: some View {
        switch UserDefaults.standard.string(forKey: "designScreen") {
        case "signIn": SignInView()
        case "profileSetup": ProfileSetupView()
        case "acceptInvite":
            let _ = setDesignInvitePreview()
            AcceptInviteView(invite: .init(token: designInviteToken, listTitle: "Edeka"))
        default: ShoppingListView()
        }
    }

    private static let designInviteToken = "design-invite"

    /// Rauschbild 1200 × 1200 als JPEG → Base64 (groß wie ein Kamerafoto im Artikelstamm).
    private static var largeImageBase64: String {
        let size = CGSize(width: 1200, height: 1200)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            for y in stride(from: 0, to: 1200, by: 6) {
                for x in stride(from: 0, to: 1200, by: 6) {
                    UIColor(hue: CGFloat((x * 7 + y * 13) % 360) / 360, saturation: 0.6, brightness: 0.9, alpha: 1).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 6, height: 6))
                }
            }
        }
        return image.jpegData(compressionQuality: 0.9)?.base64EncodedString() ?? ""
    }

    /// Kategorien im Speicher (Standard-Kategorien, kein Supabase).
    static let categoryStore = CategoryStore(repository: InMemoryCategoryDefinitionsRepository(), defaults: UserDefaults(suiteName: "uiTestFixture") ?? .standard)

    /// Preise im Speicher; im Design-Modus die Werte aus PriceHistory.dc.html („Butter“, Mär … Sep).
    static let priceBook: PriceBook = designMode
        ? .designSample
        : PriceBook(repository: InMemoryPricePointsRepository(), defaults: UserDefaults(suiteName: "uiTestFixture") ?? .standard)

    /// Kassenzettel-Archiv im Speicher, Dateien in einem eigenen Ordner (bei jedem Start leer);
    /// im Design-Modus die Bons aus ReceiptArchive.dc.html.
    static let receiptArchive: ReceiptArchive = {
        if designMode {                     // Bons von „Rob“ gehören dem Fixture-Konto → „Löschen“ sichtbar
            return .preview(ArchivedReceipt.designSamples.map { sample in
                var receipt = sample
                if receipt.creatorName == "Rob" { receipt.createdBy = ownerId }
                return receipt
            })
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("uiTestFixture-receipts", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let store = ReceiptArchiveLocalStore(directory: root.appendingPathComponent("support"),
                                             photoCache: root.appendingPathComponent("caches"))
        return ReceiptArchive(repository: InMemoryReceiptsRepository(), store: store,
                              defaults: UserDefaults(suiteName: "uiTestFixture") ?? .standard)
    }()

    /// Beispielwerte aus AcceptInvite.dc.html, bevor der Screen erscheint.
    private static func setDesignInvitePreview() {
        guard session.invitePreview?.token != designInviteToken else { return }
        session.invitePreview = InvitePreviewInfo(token: designInviteToken, listId: UUID(), inviterName: "Rob",
                                                  listName: "Edeka", itemCount: 4, memberCount: 1)
    }

    /// Owner of "My List" and "Drogerie"; "WG-Einkauf" belongs to someone else (shared list).
    private static let ownerId = UUID()

    static let session: AppSessionViewModel = {
        let session = AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                          lists: PreviewListsRepository(), listViewModel: listVM)
        session.currentProfile = Profile(id: ownerId, publicId: "ui-test", username: "uitest", fullName: "UI Test",
                                         avatarUrl: nil, createdAt: nil, updatedAt: nil)
        return session
    }()

    private static let sampleItems: [(String, ItemCategory)] = [
        ("Butter", .milch), ("Joghurt", .milch), ("Käse", .milch),
        ("Äpfel", .obstGemuese), ("Bananen", .obstGemuese), ("Tomaten", .obstGemuese),
        ("Brot", .backwaren), ("Brötchen", .backwaren),
        ("Wasser", .getraenke), ("Saft", .getraenke),
        ("Spülmittel", .haushalt), ("Pizza", .tiefkuehl),
        ("Hähnchen", .fleisch), ("Lachs", .fleisch),
        ("Batterien", .sonstiges), ("Kerzen", .sonstiges)
    ]
}

/// Wendet wie RootView die gespeicherte Wahl „System/Hell/Dunkel“ an (vorher zeigte die Fixture immer
/// das Systemschema, die Dunkel-Tour lief deshalb hell).
private struct FixtureAppearance<Content: View>: View {
    @AppStorage(ListAccountAppearanceChoice.storageKey) private var appearanceRaw = ListAccountAppearanceChoice.system.rawValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .preferredColorScheme(ListAccountAppearanceChoice(rawValue: appearanceRaw)?.colorScheme)
    }
}

#endif
