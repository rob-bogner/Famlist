/*
 ReceiptFlowCropTests.swift
 FamlistTests

 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für den automatischen Zuschnitt im Kassenzettel-Ablauf: Aufnahme erscheint sofort,
   der Zuschnitt ersetzt sie, „Prüfen“ wartet darauf, Löschen während des Zuschnitts.

 🔰 Notes for Beginners:
 - Der Zuschnitt (Vision + Core Image) wird durch `cropPage` ersetzt. Ein Gate hält ihn an,
   bis der Test ihn freigibt – so lässt sich der Zustand „läuft noch“ prüfen.

 📝 Last Change:
 - Initial creation (automatischer Bon-Zuschnitt).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
final class ReceiptFlowCropTests: XCTestCase {
    /// Hält den Zuschnitt an, bis `open()` gerufen wird.
    private actor Gate {
        private var isOpen = false
        private var waiting: [CheckedContinuation<Void, Never>] = []
        func wait() async {
            if isOpen { return }
            await withCheckedContinuation { waiting.append($0) }
        }
        func open() {
            isOpen = true
            waiting.forEach { $0.resume() }
            waiting = []
        }
    }

    private let quad = ReceiptQuad(topLeft: CGPoint(x: 0.2, y: 0.1), topRight: CGPoint(x: 0.8, y: 0.1),
                                   bottomRight: CGPoint(x: 0.8, y: 0.9), bottomLeft: CGPoint(x: 0.2, y: 0.9))

    private func image(_ width: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: 100), format: format).image { _ in }
    }

    private func makeFlow(gate: Gate, cropped: UIImage) -> ReceiptFlowViewModel {
        let flow = ReceiptFlowViewModel(listItemNames: [], catalog: nil,
                                        priceBook: PriceBook(repository: InMemoryPricePointsRepository()))
        let quad = quad
        flow.cropPage = { _ in
            await gate.wait()
            return ReceiptPageCropper.Result(quad: quad, image: cropped)
        }
        return flow
    }

    func test_addPage_showsOriginalImmediately_thenCroppedImage() async {
        let gate = Gate(), original = image(300), cropped = image(120)
        let flow = makeFlow(gate: gate, cropped: cropped)
        flow.addPage(original)
        XCTAssertEqual(flow.scans.count, 1)
        XCTAssertTrue(flow.scans[0].isCropping)
        XCTAssertTrue(flow.pages[0] === original)

        await gate.open()
        await flow.finishCropping()
        XCTAssertFalse(flow.scans[0].isCropping)
        XCTAssertTrue(flow.pages[0] === cropped)
        XCTAssertTrue(flow.scans[0].original === original, "Das Original bleibt für „Ecken korrigieren“")
        XCTAssertEqual(flow.scans[0].quad, quad)
    }

    /// „Prüfen“ direkt nach der Aufnahme: Die Texterkennung bekommt den Zuschnitt, nicht das Original.
    func test_process_waitsForCrop() async {
        let gate = Gate(), cropped = image(120)
        let flow = makeFlow(gate: gate, cropped: cropped)
        var recognized: [UIImage] = []
        flow.recognize = { images in recognized = images; return [] }
        flow.addPage(image(300))
        Task { await gate.open() }
        await flow.process()
        XCTAssertEqual(recognized.count, 1)
        XCTAssertTrue(recognized.first === cropped)
    }

    /// ✕ während des Zuschnitts: Die Aufnahme bleibt gelöscht, das späte Ergebnis verfällt.
    func test_removePage_whileCropping_dropsResult() async {
        let gate = Gate()
        let flow = makeFlow(gate: gate, cropped: image(120))
        flow.addPage(image(300))
        let keep = image(200)
        flow.addPage(keep)
        flow.removePage(at: 0)
        await gate.open()
        await flow.finishCropping()
        XCTAssertEqual(flow.scans.count, 1)
        XCTAssertTrue(flow.scans[0].original === keep)
    }

    /// Reihenfolge bleibt, auch wenn der zweite Zuschnitt vor dem ersten fertig wird.
    func test_order_isKept_whenCropsFinishOutOfOrder() async {
        let flow = ReceiptFlowViewModel(listItemNames: [], catalog: nil,
                                        priceBook: PriceBook(repository: InMemoryPricePointsRepository()))
        let first = image(300), second = image(200)
        flow.cropPage = { image in
            if image === first { try? await Task.sleep(for: .milliseconds(150)) }
            return ReceiptPageCropper.Result(quad: nil, image: image)
        }
        flow.addPage(first)
        flow.addPage(second)
        await flow.finishCropping()
        XCTAssertTrue(flow.pages[0] === first)
        XCTAssertTrue(flow.pages[1] === second)
    }

    // MARK: - Ecken anpassen

    func test_adjustCorners_cropsOriginalWithGivenQuad() async {
        let gate = Gate(), original = image(300), manual = image(90)
        let flow = makeFlow(gate: gate, cropped: image(120))
        var croppedFrom: UIImage?
        flow.cropWithQuad = { image, _ in croppedFrom = image; return manual }
        flow.addPage(original)
        await gate.open()
        await flow.finishCropping()

        let newQuad = ReceiptQuad(topLeft: CGPoint(x: 0.1, y: 0.1), topRight: CGPoint(x: 0.9, y: 0.1),
                                  bottomRight: CGPoint(x: 0.9, y: 0.9), bottomLeft: CGPoint(x: 0.1, y: 0.9))
        await flow.adjustCorners(of: flow.scans[0].id, to: newQuad)
        XCTAssertTrue(croppedFrom === original, "Zugeschnitten wird immer das Original, nicht der alte Zuschnitt")
        XCTAssertTrue(flow.pages[0] === manual)
        XCTAssertEqual(flow.scans[0].quad, newQuad)
    }

    /// „Ganzes Foto“: Zuschnitt verwerfen.
    func test_adjustCorners_nil_usesWholePhoto() async {
        let gate = Gate(), original = image(300)
        let flow = makeFlow(gate: gate, cropped: image(120))
        flow.addPage(original)
        await gate.open()
        await flow.finishCropping()
        await flow.adjustCorners(of: flow.scans[0].id, to: nil)
        XCTAssertTrue(flow.pages[0] === original)
        XCTAssertNil(flow.scans[0].quad)
        XCTAssertFalse(flow.scans[0].isCropping)
    }

    /// Handkorrektur, während der automatische Zuschnitt noch läuft: Das späte Auto-Ergebnis überschreibt sie nicht.
    func test_adjustCorners_whileAutoCropRuns_keepsManualResult() async {
        let gate = Gate(), original = image(300)
        let flow = makeFlow(gate: gate, cropped: image(120))
        flow.addPage(original)
        await flow.adjustCorners(of: flow.scans[0].id, to: nil)
        await gate.open()
        await flow.finishCropping()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(flow.pages[0] === original)
        XCTAssertNil(flow.scans[0].quad)
    }
}
