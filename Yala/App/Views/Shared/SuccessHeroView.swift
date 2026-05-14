//
//  SuccessHeroView.swift
//  Yala
//
//  Shared hero gradient circle + glass overlay + animated checkmark.
//  API con internal cascade: callsite pasa `appeared: Bool` y el shared maneja
//  el delay 150ms hero → checkmark internamente.
//
//  Used by:
//  - TransactionSuccessView (type color dynamic)
//  - InboxApproveSuccessView (isExpense ? hotPink : electricIndigo)
//  - InboxBulkApproveSuccessView (DS.Gradients.success preserved)
//

import SwiftUI

struct SuccessHeroView: View {

    // MARK: - Properties

    let icon: String
    let gradientColors: [Color]
    let glowColor: Color
    let iconSize: CGFloat
    let appeared: Bool
    let reduceMotion: Bool

    @State private var checkmarkVisible = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. Radial glow
            RadialGradient(
                colors: [glowColor, .clear],
                center: .center,
                startRadius: 0,
                endRadius: 90
            )
            .frame(width: 180, height: 180)
            .blur(radius: 12)
            .opacity(appeared ? 1 : 0)

            // 2. Main gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(
                    color: (gradientColors.first ?? .clear).opacity(0.4),
                    radius: 20,
                    y: 8
                )
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.3))
                .opacity(appeared ? 1 : 0)

            // 3. Glass overlay top half
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 100, height: 100)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(appeared ? 1 : 0)

            // 4. Icon
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(checkmarkVisible ? 1 : (reduceMotion ? 1 : 0))
                .opacity(checkmarkVisible ? 1 : 0)
        }
        .onChange(of: appeared) { _, new in
            guard new else {
                checkmarkVisible = false
                return
            }
            if reduceMotion {
                checkmarkVisible = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                        checkmarkVisible = true
                    }
                }
            }
        }
    }
}
