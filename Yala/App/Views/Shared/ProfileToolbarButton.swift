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

    @AppStorage("userProfileIcon") private var userProfileIcon: String = ""
    @Environment(\.yalaTheme) private var theme

    private var profileStorage: ProfileImageStorage { .shared }

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    /// The icon to display (custom or default)
    private var displayIcon: String {
        userProfileIcon.isEmpty ? "person.fill" : userProfileIcon
    }

    // MARK: - Properties

    let action: () -> Void

    // MARK: - Constants

    private let size: CGFloat = 40
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
        .coachMarkAnchor("profile")
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
                .strokeBorder(ringGradient, lineWidth: ringWidth)
        }
    }

    // MARK: - Ring Gradient

    private var ringGradient: LinearGradient {
        isProUser
            ? LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            : LinearGradient(
                colors: [theme.accent, theme.accent.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
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
struct ProfileToolbarItem: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ProfileToolbarButton(action: action)
        }
        .sharedBackgroundVisibility(.hidden)
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
}
