// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// LockScreenView.swift
// Branded lock screen shown when device authentication is required (macOS)

import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Branded lock screen displayed when the device is locked and authentication
    /// is required to access the Keychain. Mirrors the iOS LockScreenView pattern:
    /// shows app branding with an "Unlock" button that triggers system auth
    /// (Touch ID / macOS login password).
    struct LockScreenView: View {
        let onUnlock: () -> Void

        @ObservedObject private var localizationService = LocalizationService.shared

        var body: some View {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.cyan)
                    .accessibilityHidden(true)

                Text(localizationService.t("lock.title"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                Text(localizationService.t("lock.subtitle"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: onUnlock) {
                    Label(unlockLabel, systemImage: unlockIcon)
                        .font(.headline)
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .controlSize(.large)
                .accessibilityHint(localizationService.t("lock.a11y_hint"))

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // Auto-trigger only when Touch ID is available.
                // On headless/CI runners (no biometrics), skip — let the user tap.
                // This prevents LAContext from showing a blocking system dialog.
                if BiometricService.shared.canUseBiometrics() {
                    onUnlock()
                }
            }
        }

        private var unlockLabel: String {
            switch BiometricService.shared.availableBiometricType {
            case .touchID: localizationService.t("lock.unlock_touchid_button")
            case .none: localizationService.t("lock.unlock_button")
            }
        }

        private var unlockIcon: String {
            switch BiometricService.shared.availableBiometricType {
            case .touchID: "touchid"
            case .none: "lock.open.fill"
            }
        }
    }

    #Preview("Lock Screen") {
        LockScreenView(onUnlock: {})
    }
#endif
