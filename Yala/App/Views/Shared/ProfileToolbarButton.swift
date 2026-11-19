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

    // MARK: - Properties

    let action: () -> Void

    // MARK: - Constants

    private let size: CGFloat = DS.Icon.badgeLarge
    private let ringWidth: CGFloat = 2
    private let sparkBadgeSize: CGFloat = 14

    // MARK: - Body

    var body: some View {
        Button {
            LoadTimeMarks.begin(.settings)
            action()
        } label: {
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

    /// El avatar elegido en «Detalles personales» (foto, símbolo, emoji o iniciales, y su color). Sin color elegido, el de
    /// siempre: fondo blanco con tema de degradado o el fondo del tema, y el símbolo en el color de acento.
    private var avatar: some View {
        // La foto ya llega decodificada y reducida (YALA-IOS-9/A): decodificarla aquí, en cada pestaña y cada dibujado, era 1 GB.
        ProfileAvatarView(
            appearance: .stored(appPreferences, photo: profileStorage.image),
            size: size,
            defaultFill: theme.hasGradient ? Color.white : theme.background,
            defaultForeground: theme.accentText,
            symbolFont: DS.Typography.bodyBold
        )
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
/// iPhone Duo: es una vista propia, y sin pedirlo se quedaba en una barra horizontal arriba, aparte de la vertical, y
/// ocupaba una franja que le quitaba alto a la página. Va en la barra vertical en las siete páginas que lo llevan (opción
/// 2 de Jürgen, 2026-10-24) donde la haya: el Duo cerrado y, desde el 2026-10-30, también el abierto en horizontal
/// (card a5kf). De lo último en irse a «···», donde una vista propia no se pinta: para que quepa, las pestañas ceden
/// (`prefersToolbarItemsInVerticalBar`). Sin barra vertical (iPhone, iPad, Duo abierto en vertical) no cambia nada.
struct ProfileToolbarItem: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ProfileToolbarButton(action: action)
        }
        .sharedBackgroundVisibility(.hidden)
        .joinsVerticalBar()
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
