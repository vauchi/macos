// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// DeviceLinkSheet.swift
// State-driven sheet UI for the device link initiator flow

import CoreImage.CIFilterBuiltins
import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Sheet that drives the device link flow based on `AppViewModel.deviceLinkState`.
    struct DeviceLinkSheet: View {
        @ObservedObject var viewModel: AppViewModel

        var body: some View {
            VStack(spacing: 24) {
                sheetHeader()
                stateContent()
                Spacer()
                sheetActions()
            }
            .padding(24)
            .frame(width: 400, minHeight: 450)
        }

        // MARK: - Header

        private func sheetHeader() -> some View {
            VStack(spacing: 8) {
                Text("Link a Device")
                    .font(.title2.bold())

                Text("Scan this QR code from the new device")
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
                progressMessage("Generating QR code...")
            case let .waitingForRequest(qrData):
                waitingForRequestView(qrData: qrData)
            case let .confirmingDevice(name, code, _):
                confirmingDeviceView(name: name, code: code)
            case .completing:
                progressMessage("Completing device link...")
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
                        .accessibilityLabel("Device link QR code")
                } else {
                    Text("Failed to generate QR code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for other device...")
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
                Text("Device linked successfully!")
                    .font(.headline)
            }
        }

        private func failedView(message: String) -> some View {
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                Text("Device Link Failed")
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

                Text("New device wants to link")
                    .font(.headline)

                VStack(spacing: 8) {
                    HStack {
                        Text("Device:")
                            .foregroundColor(.secondary)
                        Text(name)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("Code:")
                            .foregroundColor(.secondary)
                        Text(code)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
                .padding(16)
                .background(
                    Color(nsColor: .controlBackgroundColor)
                )
                .cornerRadius(8)

                Text(
                    "Verify the code matches on both devices"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }

        // MARK: - Actions

        @ViewBuilder
        private func sheetActions() -> some View {
            switch viewModel.deviceLinkState {
            case .idle, .generatingQR, .waitingForRequest, .completing:
                Button("Cancel") {
                    viewModel.cancelDeviceLink()
                }
                .buttonStyle(.bordered)

            case .confirmingDevice:
                HStack(spacing: 16) {
                    Button("Reject") {
                        viewModel.cancelDeviceLink()
                    }
                    .buttonStyle(.bordered)

                    Button("Approve") {
                        viewModel.approveDeviceLink()
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .success:
                Button("Done") {
                    viewModel.cancelDeviceLink()
                }
                .buttonStyle(.borderedProminent)

            case .failed:
                HStack(spacing: 16) {
                    Button("Close") {
                        viewModel.cancelDeviceLink()
                    }
                    .buttonStyle(.bordered)

                    Button("Retry") {
                        viewModel.startDeviceLink()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }

        // MARK: - QR Code Generation

        private func generateQRCode(from string: String) -> NSImage? {
            let context = CIContext()
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(string.utf8)
            filter.correctionLevel = "M"

            guard let outputImage = filter.outputImage else {
                return nil
            }

            let scale = 10.0
            let scaledImage = outputImage.transformed(
                by: CGAffineTransform(scaleX: scale, y: scale)
            )

            guard let cgImage = context.createCGImage(
                scaledImage, from: scaledImage.extent
            ) else {
                return nil
            }

            let size = NSSize(
                width: cgImage.width, height: cgImage.height
            )
            return NSImage(cgImage: cgImage, size: size)
        }
    }
#endif
