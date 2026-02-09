//
//  BiometricLockOverlay.swift
//  Yala
//
//  Fullscreen overlay that locks the app behind biometric/passcode authentication.
//

import SwiftUI

struct BiometricLockOverlay: View {
    private let authService = BiometricAuthService.shared

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 56

    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            // Blurred background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                // Lock icon
                Image(systemName: authService.biometricType.icon)
                    .font(.system(size: heroSize))
                    .foregroundStyle(Color.brandPrimary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Biometric.locked)
                    .font(.title2.bold())
                    .foregroundStyle(Color.yalaPrimaryText)

                Text(L10n.Biometric.unlockPrompt)
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.yalaSecondaryText)
                    .multilineTextAlignment(.center)

                Spacer()

                // Unlock button
                Button {
                    performAuth()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: authService.biometricType.icon)
                            .font(DS.Typography.bodyBold)
                        Text(L10n.Biometric.unlock)
                            .font(DS.Typography.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Color.brandPrimary)
                    .clipShape(Capsule())
                }
                .disabled(isAuthenticating)
                .accessibilityHint(isAuthenticating ? "Autenticando" : "")
                .padding(.horizontal, DS.Spacing.xxxl)
                .padding(.bottom, DS.Spacing.xxxl)
            }
        }
        .onAppear {
            // Auto-trigger authentication on appear
            performAuth()
        }
    }

    private func performAuth() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            _ = await authService.authenticate()
            isAuthenticating = false
        }
    }
}
