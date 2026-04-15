// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// QrCodeComponentView.swift
// Renders a QrCode component from core UI (macOS)

import AVFoundation
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Renders a core `Component::QrCode` as a QR code display or camera scanner.
struct QrCodeComponentView: View {
    let component: QrCodeComponent
    let onAction: (UserAction) -> Void
    var onQrScanned: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            switch component.mode {
            case .display:
                qrDisplayView()

            case .scan:
                QrScannerView { scannedData in
                    if let onQrScanned {
                        onQrScanned(scannedData)
                    } else {
                        // Fallback for contexts without hardware event routing (e.g. snapshots)
                        onAction(.textChanged(componentId: "scanned_data", value: scannedData))
                    }
                }
            }

            if let label = component.label {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityLabel(component.a11y?.label ?? component.label ?? "QR code")
        .accessibilityHint(component.a11y?.hint ?? "")
    }

    @ViewBuilder
    private func qrDisplayView() -> some View {
        if let qrImage = generateQRCode(from: component.data) {
            Image(nsImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 250, maxHeight: 250)
                .accessibilityLabel("QR code")
        } else {
            Text("Failed to generate QR code")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 10.0
        let scaledImage = outputImage.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }
}

// MARK: - QR Scanner View (camera + paste fallback)

/// Scans QR codes via the Mac camera, with a paste fallback.
struct QrScannerView: View {
    let onScanned: (String) -> Void

    @State private var showPasteField = false
    @State private var cameraAvailable = true
    @State private var scannedCode: String?

    var body: some View {
        VStack(spacing: 12) {
            if cameraAvailable, !showPasteField {
                CameraQrScannerRepresentable { code in
                    guard scannedCode == nil else { return }
                    scannedCode = code
                    onScanned(code)
                }
                .frame(width: 300, height: 250)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                )

                Text("Point your camera at the QR code")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Or paste QR data instead") {
                    showPasteField = true
                }
                .buttonStyle(.link)
                .font(.caption)
            } else {
                QrPasteField(onSubmit: onScanned)

                if cameraAvailable {
                    Button("Use camera instead") {
                        showPasteField = false
                        scannedCode = nil
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
        .onAppear {
            let hasDevice = AVCaptureDevice.default(for: .video) != nil
            let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
            cameraAvailable = hasDevice && authStatus != .denied && authStatus != .restricted
            if !cameraAvailable {
                showPasteField = true
            }
        }
    }
}

/// Text field for pasting QR code data (fallback when camera unavailable).
struct QrPasteField: View {
    let onSubmit: (String) -> Void
    @State private var pastedText = ""

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.cyan)
                .accessibilityHidden(true)

            TextField("Paste QR data (wb://...)", text: $pastedText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .onSubmit { submitIfValid() }

            HStack(spacing: 12) {
                Button("Submit") { submitIfValid() }
                    .buttonStyle(.borderedProminent)
                    .disabled(pastedText.isEmpty)

                Button("Paste from Clipboard") { pasteFromClipboard() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func submitIfValid() {
        let trimmed = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }

    private func pasteFromClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            pastedText = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

// MARK: - AVFoundation Camera QR Scanner

/// NSViewRepresentable wrapping AVCaptureSession for QR code detection.
struct CameraQrScannerRepresentable: NSViewRepresentable {
    let onCodeDetected: (String) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = CameraPreviewView()
        context.coordinator.setup(previewView: view, onDetected: onCodeDetected)
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}

    func makeCoordinator() -> CameraQrCoordinator {
        CameraQrCoordinator()
    }

    static func dismantleNSView(_: NSView, coordinator: CameraQrCoordinator) {
        coordinator.stop()
    }
}

class CameraPreviewView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) not supported")
    }
}

class CameraQrCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private var captureSession: AVCaptureSession?
    private var onDetected: ((String) -> Void)?
    private var hasDetected = false

    func setup(previewView: CameraPreviewView, onDetected: @escaping (String) -> Void) {
        self.onDetected = onDetected

        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }

        session.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = previewView.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        previewView.layer?.addSublayer(previewLayer)

        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
    }

    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        guard !hasDetected,
              let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue
        else { return }

        hasDetected = true
        stop()
        onDetected?(stringValue)
    }
}
