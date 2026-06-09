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
    @State private var selectedTimeout: LockTimeout = .tenSeconds
    @State private var showAuthError: Bool = false
    @State private var isProcessingToggle: Bool = false
    @State private var didLoadInitialState: Bool = false

    var body: some View {
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

                            Toggle(L10n.Biometric.enableLock, isOn: $isEnabled)
                                .labelsHidden()

                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.Spacing.sm)
                        .solidCard(radius: DS.Radius.lg)

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
                            .solidCard(radius: DS.Radius.lg)

                            Text(L10n.Biometric.lockAfterHint)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xs)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer()
                }
                .padding(DS.Spacing.lg)
            }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Biometric.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
        .onAppear {
            isEnabled = authService.isEnabled
            selectedTimeout = authService.lockTimeout
            // Diferir el flag a un ciclo posterior: si lo seteáramos síncrono aquí, el onChange
            // disparado por la asignación de `isEnabled` de arriba ya lo vería en true y no
            // quedaría bloqueado → prompt biométrico espurio al abrir con el bloqueo ya activo.
            Task { @MainActor in didLoadInitialState = true }
        }
        .onChange(of: isEnabled) { _, newValue in
            guard didLoadInitialState else { return }
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
            Button(L10n.Common.ok, role: .cancel) {}
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
