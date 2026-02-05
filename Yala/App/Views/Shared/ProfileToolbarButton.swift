//
//  ProfileToolbarButton.swift
//  Yala
//
//  Toolbar button showing user avatar with Pro status ring and spark badge.
//

import SwiftUI
import UIKit

struct ProfileToolbarButton: View {
    // MARK: - Data Access

    @AppStorage("userProfileImageData") private var userProfileImageData: Data?

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    // MARK: - Properties

    let action: () -> Void

    // MARK: - Constants

    private let avatarSize: CGFloat = 32
    private let ringWidth: CGFloat = 2
    private let sparkBadgeSize: CGFloat = 14
    private let sparkOffset: CGFloat = 4

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                // Avatar with ring
                avatarView

                // Spark badge (only PRO)
                if isProUser {
                    sparkBadge
                }
            }
            // Frame extended to include the spark badge offset
            .frame(width: avatarSize + sparkOffset, height: avatarSize + sparkOffset)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Avatar View

    private var avatarView: some View {
        ZStack {
            // Outer ring (golden for PRO, electricIndigo for Free)
            Circle()
                .stroke(
                    isProUser
                        ? LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [.electricIndigo, .electricIndigo.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ),
                    lineWidth: ringWidth
                )
                .frame(width: avatarSize, height: avatarSize)

            // Inner content
            if let imageData = userProfileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: avatarSize - ringWidth * 2, height: avatarSize - ringWidth * 2)
                    .clipShape(Circle())
            } else {
                // Fallback: person.fill icon
                Circle()
                    .fill(Color.electricIndigo.opacity(0.1))
                    .frame(width: avatarSize - ringWidth * 2, height: avatarSize - ringWidth * 2)

                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.electricIndigo)
            }
        }
    }

    // MARK: - Spark Badge

    private var sparkBadge: some View {
        ZStack {
            Circle()
                .fill(Color.yalaCard)
                .frame(width: sparkBadgeSize, height: sparkBadgeSize)

            YalaSpark(size: .small, animated: false)
                .scaleEffect(0.8)
        }
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .offset(x: sparkOffset, y: sparkOffset)
    }
}

// MARK: - Preview

#Preview("States") {
    HStack(spacing: DS.Spacing.xxl) {
        VStack {
            Text("Free\nNo photo").font(.caption).multilineTextAlignment(.center)
            ProfileToolbarButton { }
        }
        VStack {
            Text("PRO\nNo photo").font(.caption).multilineTextAlignment(.center)
            ProfileToolbarButton { }
        }
    }
    .padding()
    .background(Color.yalaBackground)
}
