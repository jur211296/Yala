//
//  GroupsSignInView.swift
//  Yala
//
//  Sign-in SOLO-GRUPOS (G4-invites A2, §16d): un invitado por link backend sin sesión Nube firma con
//  Apple o Google para poder unirse. Autentica (SIWA/Google → JWT en `CloudAuthService`) y NADA MÁS — reglas duras:
//  NO `CloudMigrationController`, NO `startAdoptWithExistingSession`, NO `CrossAccountEntryGuardLogic`,
//  NO toca `StorageMode` ni flags de onboarding de migración. La cuenta queda como sesión viva que
//  `GroupsMembershipClient.tokenProvider` ya consume.
//
//  Invariante R9 (§2): el copy dice que esa será LA cuenta si algún día migra lo personal.
//  Si ya hay sesión viva, la vista JAMÁS se presenta (`GroupBackendInviteEntryLogic.nextStep` lo
//  garantiza en el productor) — y el belt de `onAppear` la cierra de inmediato si aparece igual.
//
//  DARK: solo la presenta el drain de `.presentGroupsSignIn` (flag `groupsBackendEnabled` OFF ⇒ el
//  intent jamás se submitea).
//

import AuthenticationServices
import SwiftUI

struct GroupsSignInView: View {
    /// Se invoca con la sesión VIVA (recién firmada o preexistente). El caller cierra el sheet y
    /// continúa el flujo encadenado (consent → join).
    var onAuthenticated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isSigningIn = false
    @State private var signInFailed = false
    /// Task del SIWA en vuelo — se cancela al desmontar (nace de un callback, no de `.task`).
    @State private var signInTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    Spacer(minLength: DS.Spacing.xxl)

                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 52)) // A11Y-DT: icono decorativo hero, tamaño fijo intencional (patrón GroupInviteOnboardingView)
                        .foregroundStyle(DS.Semantic.infoForeground)
                        .accessibilityHidden(true)

                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Groups.SignIn.title)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        Text(L10n.Groups.SignIn.body)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                    }

                    if signInFailed {
                        Text(L10n.Groups.SignIn.error)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.errorForeground)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                            .accessibilityIdentifier("groups_signin_error")
                    }

                    if isSigningIn {
                        ProgressView()
                            .controlSize(.large)
                            .accessibilityIdentifier("groups_signin_progress")
                    } else {
                        // Apple + Google con prominencia EQUIVALENTE (sesión 2; guideline 4.8).
                        VStack(spacing: DS.Spacing.md) {
                            GroupsAppleSignInButton(colorScheme: colorScheme) {
                                DS.Haptic.selection()
                                startSignIn(provider: .apple)
                            }
                            .frame(height: 50)
                            .accessibilityIdentifier("groups_signin_button")

                            GoogleSignInButton(variant: colorScheme == .dark ? .dark : .light) {
                                DS.Haptic.selection()
                                startSignIn(provider: .google)
                            }
                            .frame(height: 50)
                            .accessibilityIdentifier("groups_signin_button_google")
                        }
                        .padding(.horizontal, DS.Spacing.xl)
                    }

                    // Invariante R9: esta será LA cuenta si algún día migra lo personal.
                    Text(L10n.Groups.SignIn.accountNote)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)

                    Spacer(minLength: DS.Spacing.xxl)
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.SignIn.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .accessibilityIdentifier("groups_signin_cancel")
                }
            }
        }
        .onAppear {
            // Belt del productor: con sesión viva la vista nunca debió presentarse — cerrar
            // y continuar (jamás re-ofrecer sign-in con sesión).
            if CloudAuthService.shared.hasSession {
                onAuthenticated()
            }
        }
        .onDisappear {
            signInTask?.cancel()
            signInTask = nil
        }
    }

    /// Sign-in y NADA MÁS (reglas duras §16d) — Apple o Google, mismo contrato. Cancelación/fallo
    /// de Apple → volver al botón sin alarma (ASAuthorization no distingue); el cancel de Google
    /// llega TIPADO (`.cancelled`) → botón de vuelta SIN mensaje de error; fallo real → error visible.
    private func startSignIn(provider: CloudSignInProvider) {
        guard !isSigningIn else { return }
        isSigningIn = true
        signInFailed = false
        signInTask?.cancel()
        signInTask = Task { @MainActor in
            do {
                try await CloudAuthService.shared.signIn(with: provider)
                guard !Task.isCancelled else { return }
                isSigningIn = false
                onAuthenticated()
            } catch CloudAuthError.cancelled {
                guard !Task.isCancelled else { return }
                isSigningIn = false  // cancel silencioso: jamás signInFailed
            } catch {
                #if DEBUG
                print("GroupsSignInView: sign-in \(provider.rawValue) falló/cancelado: \(error)")
                #endif
                guard !Task.isCancelled else { return }
                isSigningIn = false
                signInFailed = true
            }
        }
    }
}

// MARK: - Botón SIWA nativo

/// `ASAuthorizationAppleIDButton` (obligado por HIG/App Review 4.8). El flujo real (nonce, exchange,
/// captura de perfil) vive en `CloudAuthService.signInWithApple()`; este botón es solo el afford
/// visual + target-action. Estilo según el scheme del sheet (fondo `.subtle`, no el hero oscuro
/// del Welcome — ahí vive el gemelo privado de `WelcomeCloudSignInView`).
private struct GroupsAppleSignInButton: UIViewRepresentable {
    let colorScheme: ColorScheme
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            type: .signIn,
            style: colorScheme == .dark ? .white : .black
        )
        button.cornerRadius = DS.Radius.lg
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
