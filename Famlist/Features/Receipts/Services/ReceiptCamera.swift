/*
 ReceiptCamera.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Rückkamera für „Kassenzettel“: Vorschau, Foto aufnehmen, Licht (Taschenlampe).

 🔰 Notes for Beginners:
 - Die Kamera ist eine Systemkomponente; das Design-UI (Sucher, Knöpfe) liegt in ReceiptCaptureView darüber.
 - Die Session läuft auf einer eigenen Warteschlange (startRunning blockiert sonst die Oberfläche).
 - Im Simulator gibt es keine Kamera → `isAvailable` false; Fotos können dann aus der Mediathek kommen.
 - Kamera-Berechtigung: NSCameraUsageDescription (Build-Setting), Text in PLAN.md §9.

 📝 Last Change:
 - Live-Erkennung: zweiter Ausgang für Kamerabilder, sucht den Bon bis zu 10-mal pro Sekunde (nur mit Handler).
 ------------------------------------------------------------------------
 */

@preconcurrency import AVFoundation
import UIKit

/// `@unchecked Sendable`: `pending` und `documentHandler` ändern sich nur unter `lock`,
/// `lastAnalysis` nur auf `videoQueue`. Session und Ausgaben werden nur auf `queue` konfiguriert
/// (Apples Vorgabe für AVCaptureSession).
final class ReceiptCamera: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "famlist.receiptCamera")
    /// Wartende Aufnahmen je `AVCapturePhotoSettings.uniqueID`. Vorher gab es nur eine Wartestelle:
    /// Zwei schnelle Aufnahmen überschrieben sie, die erste wartete dann für immer (Audit 25.09.2026).
    private let lock = NSLock()
    private var pending: [Int64: CheckedContinuation<UIImage?, Never>] = [:]

    /// Live-Erkennung: Kamerabilder für die Suche nach dem Bon (eigene Warteschlange, verspätete Bilder verfallen).
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "famlist.receiptCamera.video")
    private var documentHandler: (@Sendable (ReceiptQuad?, TimeInterval) -> Void)?
    private var lastAnalysis: TimeInterval = -.infinity
    /// Höchstens 10 Analysen pro Sekunde: reicht für einen ruhigen Rahmen und schont den Akku.
    static let analysisInterval: TimeInterval = 0.1

    static var isAvailable: Bool { AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil }

    /// Fragt die Berechtigung an und startet die Vorschau.
    func start() async -> Bool {
        guard Self.isAvailable else { return false }
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        queue.async { [self] in
            if session.inputs.isEmpty, let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device) {
                session.beginConfiguration()
                session.sessionPreset = .photo
                if session.canAddInput(input) { session.addInput(input) }
                if session.canAddOutput(output) { session.addOutput(output) }
                if session.canAddOutput(videoOutput) {
                    videoOutput.alwaysDiscardsLateVideoFrames = true
                    videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
                    session.addOutput(videoOutput)
                }
                session.commitConfiguration()
            }
            if !session.isRunning { session.startRunning() }
        }
        return true
    }

    func stop() {
        setTorch(false)
        queue.async { [self] in if session.isRunning { session.stopRunning() } }
    }

    func capture() async -> UIImage? {
        guard session.isRunning else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                // Einstellungen entstehen auf der Kamera-Warteschlange (nicht thread-sicher, nicht Sendable).
                let settings = AVCapturePhotoSettings()
                lock.withLock { pending[settings.uniqueID] = continuation }
                output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    /// Live-Erkennung ein (Handler) oder aus (nil). Der Handler läuft auf der Video-Warteschlange und bekommt
    /// die Ecken in Sensor-Koordinaten (siehe ReceiptDocumentDetector) samt Zeitstempel des Bildes.
    func setDocumentHandler(_ handler: (@Sendable (ReceiptQuad?, TimeInterval) -> Void)?) {
        lock.withLock { documentHandler = handler }
    }

    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

extension ReceiptCamera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        let waiting = lock.withLock { pending.removeValue(forKey: photo.resolvedSettings.uniqueID) }
        waiting?.resume(returning: image)
    }

    /// Letzter Rückruf jeder Aufnahme. Kam kein Bild (Fehler, Session gestoppt), endet das Warten mit nil.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        let waiting = lock.withLock { pending.removeValue(forKey: resolvedSettings.uniqueID) }
        waiting?.resume(returning: nil)
    }
}

extension ReceiptCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let handler = lock.withLock({ documentHandler }) else { return }
        let time = sampleBuffer.presentationTimeStamp.seconds
        guard time - lastAnalysis >= Self.analysisInterval,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = time
        handler(ReceiptDocumentDetector.detect(in: buffer), time)
    }
}
