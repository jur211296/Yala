//
//  ProfileToolbarButton.swift
//  Yala
//
//  Toolbar button showing user avatar with Pro status ring and spark badge.
//

import SwiftUI
import UIKit

// MARK: - ProfileToolbarButton

struct ProfileToolbarButton: View {
    // MARK: - Data Access

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private var profileStorage: ProfileImageStorage { .shared }

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    /// The icon to display (custom or default)
    private var displayIcon: String {
        appPreferences.userProfileIcon.isEmpty ? "person.fill" : appPreferences.userProfileIcon
    }

    // MARK: - Properties

    let action: () -> Void

    // MARK: - Constants

    private let size: CGFloat = DS.Icon.badgeLarge
    private let ringWidth: CGFloat = 2
    private let sparkBadgeSize: CGFloat = 14

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            avatar
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive())
        .overlay(alignment: .bottomTrailing) {
            if isProUser {
                sparkBadge
                    .offset(x: 4, y: 4)
            }
        }
        // UX 2.2 · L16-1: el avatar abre Ajustes, y así se llama la hoja que abre.
        .accessibilityLabel(L10n.Profile.title)
        .accessibilityIdentifier("profile_avatar")
    }

    // MARK: - Avatar

    private var avatar: some View {
        Group {
            if let imageData = profileStorage.imageData,
               let uiImage = UIImage(data: imageData) {
                // User photo
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                // Adaptive background with icon (custom or default)
                // Light mode: white background / Dark mode: yalaBackground
                // Icon: electricIndigo in both modes
                (theme.hasGradient ? Color.white : theme.background)
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: displayIcon)
                            .font(DS.Typography.bodyBold)
                            .foregroundStyle(theme.accent)
                    }
            }
        }
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(ringColor, lineWidth: ringWidth)
        }
    }

    // MARK: - Ring

    /// Aro sólido, el mismo que la cabecera de Ajustes (UX 2.2 · L16-12): dorado con Pro, color de acento sin él.
    private var ringColor: Color {
        isProUser ? Color.proGold : theme.accent
    }

    // MARK: - Spark Badge

    private var sparkBadge: some View {
        ZStack {
            Circle()
                .fill(theme.card)
                .frame(width: sparkBadgeSize, height: sparkBadgeSize)

            YalaSpark(size: .small, animated: false)
                .scaleEffect(0.8)
        }
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - ProfileToolbarItem

/// ToolbarContent wrapper that applies .sharedBackgroundVisibility(.hidden)
/// to remove toolbar's default glass (button has its own glass effect).
///
/// iPhone Duo cerrado: es una vista propia, y sin pedirlo se quedaba en una barra horizontal arriba, aparte de la
/// vertical. Ahí va en la vertical, en las siete páginas que lo llevan (opción 2 de Jürgen, 2026-10-24), y de lo último
/// en irse a «···». Solo en ancho compacto: abierto en horizontal, con siete pestañas, no cabía y acababa en «···»,
/// donde una vista propia no se pinta; ahí se queda arriba, como estaba.
struct ProfileToolbarItem: ToolbarContent {
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ProfileToolbarButton(action: action)
        }
        .sharedBackgroundVisibility(.hidden)
        .joinsVerticalBar(horizontalSizeClass == .compact)
        .overflowsLast()
    }
}

// MARK: - Preview

#Preview("States") {
    HStack(spacing: DS.Spacing.xxl) {
        VStack {
            Text("Free\nNo photo").font(DS.Typography.caption).multilineTextAlignment(.center)
            ProfileToolbarButton { }
        }
        VStack {
            Text("PRO\nNo photo").font(DS.Typography.caption).multilineTextAlignment(.center)
            ProfileToolbarButton { }
        }
    }
    .padding()
    .background(.thBackground)
    .previewAppPreferences()
}
