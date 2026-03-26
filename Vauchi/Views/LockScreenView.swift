// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// LockScreenView.swift
// Branded lock screen shown when device authentication is required (macOS)

import SwiftUI

/// Branded lock screen displayed when the device is locked and authentication
/// is required to access the Keychain. Mirrors the iOS LockScreenView pattern:
/// shows app branding with an "Unlock" button that triggers system auth
/// (Touch ID / macOS login password).
struct LockScreenView: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.cyan)
                .accessibilityHidden(true)

            Text("Vauchi is Locked")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            Text("Authenticate to access your contacts")
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
            .accessibilityHint("Authenticate with Touch ID or password")

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
        case .touchID: return "Unlock with Touch ID"
        case .none: return "Unlock"
        }
    }

    private var unlockIcon: String {
        switch BiometricService.shared.availableBiometricType {
        case .touchID: return "touchid"
        case .none: return "lock.open.fill"
        }
    }
}

#Preview("Lock Screen") {
    LockScreenView(onUnlock: {})
}
