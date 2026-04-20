// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AvatarPreviewComponentView.swift
// Renders an AvatarPreview component from core UI (macOS)

import SwiftUI

/// Renders a core `Component::AvatarPreview` as a circular avatar with
/// optional brightness adjustment. When editable, tapping emits
/// `ActionPressed("edit_avatar")`.
struct AvatarPreviewComponentView: View {
    let component: AvatarPreviewComponent
    let onAction: (UserAction) -> Void

    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        let content = avatarContent
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .brightness(Double(component.brightness))
            .accessibilityLabel(component.a11y?.label ?? "Avatar: \(component.initials)")
            .accessibilityHint(component.a11y?.hint ?? (component.editable ? "Tap to edit" : ""))

        if component.editable {
            Button {
                onAction(.actionPressed(actionId: "edit_avatar"))
            } label: {
                content
                    .overlay(editOverlay)
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let imageData = component.imageData,
           let nsImage = NSImage(data: Data(imageData))
        {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(backgroundGradient)
                .overlay(
                    Text(component.initials)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    private var backgroundGradient: LinearGradient {
        if let bgColor = component.bgColor, bgColor.count >= 3 {
            let color = Color(
                red: Double(bgColor[0]) / 255.0,
                green: Double(bgColor[1]) / 255.0,
                blue: Double(bgColor[2]) / 255.0
            )
            return LinearGradient(
                colors: [color, color.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [themeService.accent, themeService.accent.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var editOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            Circle()
                .fill(themeService.accent)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                )
                .offset(x: -4, y: -4)
        }
    }
}
