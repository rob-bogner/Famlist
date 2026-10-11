# Design-Prompt: Märkte & Einkaufsroute

Empfänger: Claude Design im Canvas „Famlist“. Stand: 11.10.2026.

```
Gestalte für Famlist die neue Funktion „Märkte & Einkaufsroute“ im bestehenden Stil „Hybrid“.
Es geht nur um Design-Boards im Canvas „Famlist“. Es wird kein App-Code geschrieben.

## Was die Funktion tut
- Der Nutzer speichert einen Supermarkt, während er dort steht. Die App merkt sich Name und Standort.
- Öffnet der Nutzer die App später in diesem Markt, erkennt die App den Markt am Standort.
- Die App lernt die Route durch den Markt selbst: Sie merkt sich, in welcher Reihenfolge der Nutzer
  die Kategorien abhakt. Beispiel: erst „Obst & Gemüse“, dann „Backwaren“, dann „Milchprodukte“.
- Beim nächsten Besuch sortiert „Nach Kategorie“ die Liste in genau dieser Reihenfolge.
- Die Route gilt je Markt. Sie verbessert sich mit jedem Einkauf.
- Ein Markt gehört zu einem Konto und gilt in allen Listen dieses Kontos. Mitglieder einer geteilten
  Liste sehen und nutzen die Märkte der anderen Mitglieder mit.
- Ohne erkannten Markt bleibt alles wie heute: Es gilt die Reihenfolge aus „Kategorien verwalten“.

## Feste Entscheidungen (nicht anders gestalten)
- Ein Markt wird nur am Ort gespeichert („Markt hier speichern“). Es gibt keine Karte und keine
  Adress-Suche.
- Die Route besteht nur aus Kategorien. Innerhalb einer Kategorie bleibt die Liste alphabetisch.
- Die App erkennt den Markt nur, während sie offen ist. Es gibt keine Mitteilung im Hintergrund.
- Es gibt keinen fünften Sortier-Modus. Die Route wirkt innerhalb von „Nach Kategorie“.
- Die gelernte Route kann der Nutzer ansehen und zurücksetzen. Er kann sie nicht von Hand umsortieren.

## Lies zuerst (bestehende Boards, an denen sich alles orientiert)
- Einkaufsliste: Hybrid, ListCompact (Kopf kompakt beim Scrollen), ListShared.
- Sortieren: SortMenu.
- Menü ☰: MenuOverlay.
- Verwandte Sheets: ManageCategories (Liste mit Kopf), EditCategory (Detail mit Name).
- Aktionskarten: DeleteListDialog, SignOutDialog, ReceiptStoreAlert. Baustein SlideToDelete.
- Hinweise: UndoToast, MemberDeletedToast.
- Einkauf abschließen: ShoppingDone.
- Einstellungen: Settings, SettingsCheckMode.

## Boards, die ich brauche
Jedes Board gibt es in Light und als eigenes Board `<Name>Dark`. Artboard 390 × 844, 1 px = 1 pt.

1. ListStoreRoute – Einkaufsliste, Markt erkannt, Route vorhanden.
   - Der Listenkopf zeigt einen Hinweis mit Markt-Symbol und dem Text „EDEKA · Route aktiv“.
   - Der Hinweis ist antippbar (öffnet StoreSwitch).
   - Die Kategorien stehen in der gelernten Reihenfolge.
   - Zeige zusätzlich, wie der Hinweis im kompakten Kopf aussieht (wie ListCompact): ListStoreRouteCompact.

2. ListStoreLearning – Einkaufsliste, Markt erkannt, noch keine Route (erster Einkauf).
   - Hinweis: „EDEKA · Route wird gelernt“.
   - Die Kategorien stehen in der Reihenfolge aus „Kategorien verwalten“.

3. StoreSwitch – Auswahl nach Tipp auf den Hinweis (Aktionskarte oder Popover, deine Wahl).
   - Titel „Wo kaufst du ein?“.
   - Zeilen: gespeicherte Märkte in der Nähe mit Entfernung („EDEKA · 20 m“, „dm · 60 m“), der aktive
     Markt trägt ein Häkchen. Darunter „Anderer Markt …“ (öffnet ManageStores) und „Ohne Route“.
   - Zweck: Zwei Märkte liegen nebeneinander, oder der Standort ist im Gebäude ungenau.

4. SortMenuStore – das Popover „Sortieren“, während ein Markt aktiv ist.
   - Zeile „Nach Kategorie“ mit Unterzeile „Route: EDEKA“ statt „Reihenfolge wie im Laden“.
   - Alle anderen Zeilen wie in SortMenu.

5. MenuOverlayStores – das Menü ☰ mit dem neuen Eintrag „Märkte“.
   - Vorschlag für die Position: direkt unter „Kategorien verwalten“.

6. ManageStores – Sheet „Märkte“.
   - Oben der Hauptknopf „Markt hier speichern“.
   - Darunter die Liste der Märkte. Jede Zeile zeigt: Name, eine Unterzeile und rechts einen Pfeil.
   - Unterzeilen: „Route aus 4 Einkäufen“, „Noch keine Route“.
   - Der Markt, in dem der Nutzer gerade steht, trägt die Markierung „Du bist hier“.
   - Ein Markt eines anderen Mitglieds trägt den Zusatz „von Sofie“.
   - Beispielzeilen: „EDEKA“ (Du bist hier, Route aus 4 Einkäufen), „Lidl“ (Route aus 1 Einkauf),
     „dm“ (Noch keine Route), „REWE“ (von Sofie, Route aus 7 Einkäufen).

7. ManageStoresEmpty – Sheet „Märkte“ ohne gespeicherten Markt.
   - Kurze Erklärung in zwei bis drei Sätzen: Markt am Ort speichern, Artikel beim Einlegen abhaken,
     beim nächsten Einkauf ist die Liste nach der Route sortiert.
   - Hauptknopf „Markt hier speichern“.

8. StoreSave – Markt speichern.
   - Feld „Name“. Darunter Vorschläge als Chips: EDEKA, REWE, Lidl, ALDI, Netto, Penny, Kaufland, dm.
   - Zeile zum Standort mit drei Zuständen, je ein Board:
     - StoreSave: „Standort gefunden · auf 12 m genau“.
     - StoreSaveLocating: „Standort wird gesucht …“, Hauptknopf inaktiv.
     - StoreSaveInaccurate: „Standort ungenau (auf 90 m). Geh näher zum Eingang.“, mit „Erneut versuchen“.
   - Hauptknopf „Markt speichern“.

9. StoreSaveExists – Aktionskarte, wenn es an diesem Ort schon einen Markt gibt.
   - Text: „Hier gibt es schon „EDEKA“ (von Sofie).“
   - Aktionen: „Diesen Markt verwenden“ (Hauptaktion), „Trotzdem neu speichern“.

10. StoreLocationIntro – Aktionskarte vor der Standort-Abfrage von iOS.
    - Titel „Standort für Märkte“.
    - Text: Famlist nutzt den Standort nur, während die App offen ist, und nur, um gespeicherte Märkte
      zu erkennen.
    - Hauptaktion „Weiter“.

11. StoreLocationDenied – Aktionskarte, wenn der Standort nicht erlaubt ist.
    - Text: Ohne Standort kann Famlist keinen Markt speichern oder erkennen.
    - Hauptaktion „Einstellungen öffnen“.

12. StoreDetail – Sheet für einen Markt (Tipp auf eine Zeile in ManageStores).
    - Name, änderbar.
    - Abschnitt „Route“: nummerierte Liste der Kategorien in der gelernten Reihenfolge, je Zeile die
      Kategorie-Kachel (Farbe und Icon wie in der Einkaufsliste) und der Name. Nur Anzeige, kein Ziehen.
    - Zeile darunter: „Gelernt aus 4 Einkäufen · zuletzt am 08.10.2026“.
    - Aktionen: „Standort neu setzen“ (nimmt den aktuellen Standort), „Route zurücksetzen“,
      „Markt löschen“.
    - Variante StoreDetailNoRoute: Abschnitt „Route“ zeigt den Hinweis „Noch keine Route. Hake beim
      nächsten Einkauf die Artikel beim Einlegen ab.“
    - Variante StoreDetailShared: Markt eines anderen Mitglieds. Name und Route sind sichtbar,
      Umbenennen, Standort, Zurücksetzen und Löschen fehlen. Hinweis „Gespeichert von Sofie“.

13. StoreResetDialog – Aktionskarte „Route zurücksetzen?“.
    - Text: Die gelernte Reihenfolge für „EDEKA“ wird gelöscht. Der Markt bleibt gespeichert.
    - Bestätigen mit dem Baustein „Schieben zum Löschen“.

14. StoreDeleteDialog – Aktionskarte „Markt löschen?“ mit „Schieben zum Löschen“.

15. ShoppingDoneRoute – „Einkauf erledigt“ mit einer zusätzlichen Zeile „Route für EDEKA gelernt“
    (erster Einkauf) bzw. „Route für EDEKA aktualisiert“.

16. SettingsStores – Einstellungen, Abschnitt „Liste“, neuer Schalter „Markt automatisch erkennen“
    mit der Unterzeile „Sortiert die Liste im Markt nach deiner Route“.

## Regeln
- Verwende nur vorhandene Bausteine, Farben, Schriften und Abstände aus dem Canvas (Glas-Knöpfe,
  Sheets mit Radius 34 und Griff, Aktionskarten, Toasts, Chips). Erfinde keine neuen Bauformen.
- Rückfragen sind immer Aktionskarten. Kein iOS-Systemdialog, kein „Abbrechen“-Knopf.
- Endgültiges Löschen läuft über „Schieben zum Löschen“.
- Icons: keine SF Symbols. Neue Icons (Markt, Standort, Route) als eigene SVG-Pfade im Stil der
  vorhandenen Icons zeichnen.
- Akzentfarbe Light #0FA3AE, Dark #1FC2CC. Schriften Outfit (Titel) und DM Sans (Text).
- Der Hinweis im Listenkopf darf den Kopf nicht höher machen als nötig und muss auch im kompakten
  Kopf Platz haben.
- Alle Texte sind Deutsch und duzen den Nutzer.

## Ausdrücklich nicht gestalten
- Karte, Adress-Suche, Lageplan des Marktes.
- Reihenfolge einzelner Artikel innerhalb einer Kategorie.
- Route von Hand umsortieren.
- Apple-Watch-Boards.
- Mitteilungen im Hintergrund („Du bist bei EDEKA“ als Push).

## Ablage
- Neuer Abschnitt auf der Seite „User Journey“: „8 · Märkte & Route“, Boards in der Reihenfolge oben.
- Board-Namen genau wie oben, Dark-Boards mit der Endung „Dark“.
- Wenn du von einer Vorgabe abweichst oder etwas offen ist, schreib es als kurze Liste unter die Boards.
```
