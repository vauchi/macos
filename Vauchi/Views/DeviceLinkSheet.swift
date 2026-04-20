// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// DeviceLinkSheet.swift
// State-driven sheet UI for the device link initiator flow

import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Sheet that drives the device link flow based on `AppViewModel.deviceLinkState`.
    struct DeviceLinkSheet: View {
        @ObservedObject var viewModel: AppViewModel
        @ObservedObject private var localizationService = LocalizationService.shared

        @Environment(\.designTokens) private var tokens

        var body: some View {
            VStack(spacing: 24) {
                sheetHeader()
                stateContent()
                Spacer()
                sheetActions()
            }
            .padding(CGFloat(tokens.spacing.lg))
            .frame(width: 400)
            .frame(minHeight: 450)
        }

        // MARK: - Header

        private func sheetHeader() -> some View {
            VStack(spacing: 8) {
                Text(localizationService.t("device_link.title"))
                    .font(.title2.bold())

                Text(localizationService.t("device_link.scan_instruction"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }

        // MARK: - State Content

        @ViewBuilder
        private func stateContent() -> some View {
            switch viewModel.deviceLinkState {
            case .idle, .generatingQR:
                progressMessage(localizationService.t("device_link.generating_qr"))
            case let .waitingForRequest(qrData):
                waitingForRequestView(qrData: qrData)
            case let .confirmingDevice(name, code, _):
                confirmingDeviceView(name: name, code: code)
            case .completing:
                progressMessage(localizationService.t("device_link.completing"))
            case .success:
                successView()
            case let .failed(message):
                failedView(message: message)
            }
        }

        // MARK: - State Sub-Views

        private func progressMessage(_ text: String) -> some View {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }

        private func waitingForRequestView(qrData: String) -> some View {
            VStack(spacing: 16) {
                if let qrImage = generateQRCode(from: qrData) {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 250, maxHeight: 250)
                        .accessibilityLabel(localizationService.t("device_link.a11y_qr"))
                } else {
                    Text(localizationService.t("device_link.failed_qr"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localizationService.t("device_link.waiting_other"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }

        private func successView() -> some View {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text(localizationService.t("device_link.success"))
                    .font(.headline)
            }
        }

        private func failedView(message: String) -> some View {
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                Text(localizationService.t("device_link.failed_title"))
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
        }

        // MARK: - Confirming Device

        private func confirmingDeviceView(
            name: String, code: String
        ) -> some View {
            VStack(spacing: 16) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.system(size: 36))
                    .foregroundColor(.cyan)

                Text(localizationService.t("device_link.request_title"))
                    .font(.headline)

                VStack(spacing: 8) {
                    HStack {
                        Text(localizationService.t("device_link.device_label"))
                            .foregroundColor(.secondary)
                        Text(name)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text(localizationService.t("device_link.code_label"))
                            .foregroundColor(.secondary)
                        Text(code)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
                .padding(CGFloat(tokens.spacing.md))
                .background(
                    Color(nsColor: .controlBackgroundColor)
                )
                .cornerRadius(CGFloat(tokens.borderRadius.md))

                Text(localizationService.t("device_link.verify_code_hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }

        // MARK: - Actions

        @ViewBuilder
        private func sheetActions() -> some View {
            switch viewModel.deviceLinkState {
            case .idle, .generatingQR, .waitingForRequest, .completing:
                Button(localizationService.t("action.cancel")) {
                    viewModel.cancelDeviceLink()
                }
                .buttonStyle(.bordered)

            case .confirmingDevice:
                HStack(spacing: 16) {
                    Button(localizationService.t("device_link.reject")) {
                        viewModel.cancelDeviceLink()
                    }
                    .buttonStyle(.bordered)

                    Button(localizationService.t("device_link.approve")) {
                        viewModel.approveDeviceLink()
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .success:
                Button(localizationService.t("action.done")) {
                    viewModel.cancelDeviceLink()
                }
                .buttonStyle(.borderedProminent)

            case .failed:
                HStack(spacing: 16) {
                    Button(localizationService.t("action.close")) {
                        viewModel.cancelDeviceLink()
                    }
                    .buttonStyle(.bordered)

                    Button(localizationService.t("action.retry")) {
                        viewModel.startDeviceLink()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }

        // MARK: - QR Code Generation

        /// Generates a QR code image using the Rust qrcode crate via UniFFI.
        private func generateQRCode(from string: String) -> NSImage? {
            guard let qrBitmap = try? generateQrBitmap(
                data: string, size: 512, ecc: .medium, dark: 0, light: 255, margin: 4
            ) else { return nil }
            let imageSize = Int(qrBitmap.size)
            let colorSpace = CGColorSpaceCreateDeviceGray()
            guard let provider = CGDataProvider(data: Data(qrBitmap.pixels) as CFData),
                  let cgImage = CGImage(
                      width: imageSize, height: imageSize,
                      bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: imageSize,
                      space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: 0),
                      provider: provider, decode: nil, shouldInterpolate: false,
                      intent: .defaultIntent
                  ) else { return nil }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }
#endif
