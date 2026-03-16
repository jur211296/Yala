//
//  BiometricLockOverlay.swift
//  Yala
//
//  Fullscreen overlay that locks the app behind biometric/passcode authentication.
//

import SwiftUI

struct BiometricLockOverlay: View {
    @Environment(\.yalaTheme) private var theme
    private let authService = BiometricAuthService.shared

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 56 // A11Y-DT: @ScaledMetric

    @State private var isAuthenticating = false
    @State private var autoAuthTask: Task<Void, Never>?

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
                    .foregroundStyle(theme.accent)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Biometric.locked)
                    .font(.title2.bold())
                    .foregroundStyle(.thPrimaryText)

                Text(L10n.Biometric.unlockPrompt)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)

                Spacer()

                // Unlock button
                YalaPrimaryButton(
                    L10n.Biometric.unlock,
                    icon: authService.biometricType.icon,
                    isDisabled: isAuthenticating
                ) {
                    performAuth()
                }
                .accessibilityHint(isAuthenticating ? L10n.Accessibility.authenticating : "")
                .padding(.horizontal, DS.Spacing.xxxl)
                .padding(.bottom, DS.Spacing.xxxl)
            }
        }
        .onAppear {
            // Delay auto-auth to let fullScreenCover finish presenting
            autoAuthTask = Task {
                do {
                    try await Task.sleep(for: .seconds(0.5))
                    performAuth()
                } catch {
                    // Task cancelled — view disappeared before delay finished
                }
            }
        }
        .onDisappear {
            autoAuthTask?.cancel()
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
