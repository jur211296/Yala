//
//  BiometricLockOverlay.swift
//  Yala
//
//  Fullscreen overlay that locks the app behind biometric/passcode authentication.
//

import SwiftUI

struct BiometricLockOverlay: View {
    private let authService = BiometricAuthService.shared

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
                    .font(.system(size: 56))
                    .foregroundStyle(Color.brandPrimary)

                Text(L10n.Biometric.locked)
                    .font(.title2.bold())
                    .foregroundStyle(Color.yalaPrimaryText)

                Text(L10n.Biometric.unlockPrompt)
                    .font(.body)
                    .foregroundStyle(Color.yalaSecondaryText)
                    .multilineTextAlignment(.center)

                Spacer()

                // Unlock button
                Button {
                    performAuth()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: authService.biometricType.icon)
                            .font(.body.weight(.medium))
                        Text(L10n.Biometric.unlock)
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                }
                .disabled(isAuthenticating)
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
