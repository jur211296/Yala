//
//  BiometricSecurityView.swift
//  Yala
//
//  Settings screen for biometric lock configuration.
//

import SwiftUI

struct BiometricSecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let authService = BiometricAuthService.shared

    @State private var isEnabled: Bool = false
    @State private var selectedTimeout: LockTimeout = .immediately
    @State private var showAuthError: Bool = false
    @State private var isProcessingToggle: Bool = false

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: authService.biometricType.icon)
                            .font(DS.Typography.amountLarge)
                            .foregroundStyle(.thAccent)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Biometric.title)
                            .font(.title2.bold())
                            .foregroundStyle(.thPrimaryText)

                        Text(L10n.Biometric.description)
                            .font(DS.Typography.body)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // Enable toggle
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text(L10n.Biometric.enableLock)
                                .font(DS.Typography.body)
                                .foregroundStyle(.thPrimaryText)

                            Spacer()

                            Toggle("", isOn: $isEnabled)
                                .labelsHidden()

                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(.thCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )

                        Text(L10n.Biometric.enableLockHint)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DS.Spacing.xs)
                    }

                    // Lock timeout selector (only when enabled)
                    if isEnabled {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            VStack(spacing: DS.Spacing.none) {
                                ForEach(Array(LockTimeout.allCases.enumerated()), id: \.element.id) { index, timeout in
                                    timeoutRow(for: timeout)

                                    if index < LockTimeout.allCases.count - 1 {
                                        Divider()
                                            .padding(.leading, DS.Spacing.lg)
                                    }
                                }
                            }
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )

                            Text(L10n.Biometric.lockAfterHint)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xs)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle(L10n.Biometric.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
        }
        .onAppear {
            isEnabled = authService.isEnabled
            selectedTimeout = authService.lockTimeout
        }
        .onChange(of: isEnabled) { _, newValue in
            guard !isProcessingToggle else { return }
            isProcessingToggle = true

            if newValue {
                Task {
                    let success = await authService.authenticateToEnable()
                    if success {
                        authService.isEnabled = true
                    } else {
                        isEnabled = false
                        showAuthError = true
                    }
                    isProcessingToggle = false
                }
            } else {
                authService.isEnabled = false
                isProcessingToggle = false
            }
        }
        .onChange(of: selectedTimeout) { _, newValue in
            authService.lockTimeout = newValue
        }
        .alert(L10n.Biometric.authFailed, isPresented: $showAuthError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(L10n.Biometric.authFailedMessage)
        }
    }

    @ViewBuilder
    private func timeoutRow(for timeout: LockTimeout) -> some View {
        let isSelected = selectedTimeout == timeout

        Button {
            dsWithAnimation(reduceMotion, .easeInOut(duration: 0.2)) {
                selectedTimeout = timeout
            }
        } label: {
            HStack {
                Text(timeout.label)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccent)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
