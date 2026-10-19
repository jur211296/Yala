//
//  StorageSignInChooserView.swift
//  Yala
//
//  Elección del método de sign-in (Apple | Google) en la entrada de migración/adopt de Almacenamiento
//  (Bloque C 2026-07-17: la entrada forzaba SIWA; decisión owner: "el usuario debería poder elegir
//  Google también aquí"). Desde UX 2.2 · L20-11 solo lo abre «Usar otra cuenta» del aviso de bloqueo (la entrada normal elige método en
//  `CloudActivationSheet`). Antes era el ÚLTIMO paso antes de la auth: migración = consent → doble confirmación
//  → chooser; adopt = consent → chooser.
//
//  Sheet de SELECCIÓN PURA: no corre auth ni muta nada — `onSelect` solo comunica el provider elegido
//  y el caller (StorageSettingsView) cierra el sheet y conduce `startMigration(consentPath:signIn:)`
//  desde su `onDismiss` (la máquina conserva `consent → authenticating → …` intacta, y Google resuelve
//  su presenter con el anchor YA estable — jamás sobre un VC a medio dismissal).
//
//  Botones con prominencia EQUIVALENTE (guideline 4.8) — patrón apilado de GroupsSignInView §16d.
//
//  C-7 (2026-07-27): la pantalla solo se presenta SIN sesión de nube. El productor
//  (`StorageSettingsView.proceedToSignInStep`) ya lo decide con `StorageMigrationSignInLogic`, y aquí
//  vive el BELT —molde `GroupsSignInView` §16d—: con sesión viva la vista se cierra sin ofrecer nada.
//  Ofrecer la elección con una cuenta ya dentro sería mentir: el controller la reusaría igual, así que
//  el usuario habría "elegido" un método que no se usa.
//

import AuthenticationServices
import SwiftUI

struct StorageSignInChooserView: View {
    /// Decisión YA evaluada por el caller (inyectada, no leída del singleton: la vista sigue siendo
    /// pura y el belt queda explícito en el call-site).
    let decision: StorageMigrationSignInLogic.Decision
    /// Se invoca con el provider ELEGIDO. El caller baja el sheet y arranca la migración en `onDismiss`.
    var onSelect: (CloudSignInProvider) -> Void
    /// Belt: hay sesión viva ⇒ el caller baja el sheet y arranca con `.reuseLiveSession`.
    var onReuseLiveSession: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    Spacer(minLength: DS.Spacing.xxl)

                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 52)) // A11Y-DT: icono decorativo hero, tamaño fijo intencional (patrón GroupsSignInView)
                        .foregroundStyle(DS.Semantic.infoForeground)
                        .accessibilityHidden(true)

                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Storage.SignIn.title)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        Text(L10n.Storage.SignIn.body)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                    }

                    VStack(spacing: DS.Spacing.md) {
                        StorageAppleSignInButton(colorScheme: colorScheme) {
                            DS.Haptic.selection()
                            onSelect(.apple)
                        }
                        .frame(height: 50)
                        .accessibilityIdentifier("storage_signin_apple")

                        // W4: verbo NEUTRO — desde aquí se llega tanto a una cuenta que ya existe
                        // (adopt) como a una que se crea al migrar, así que ni «crear» ni «iniciar
                        // sesión» valen para las dos. El `.signIn` del botón de Apple de al lado se
                        // conserva: esta pantalla queda fuera del punto 15.
                        GoogleSignInButton(variant: colorScheme == .dark ? .dark : .light,
                                           purpose: .continue) {
                            DS.Haptic.selection()
                            onSelect(.google)
                        }
                        .frame(height: 50)
                        .accessibilityIdentifier("storage_signin_google")
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    // UX 2.2 · L20-9: la MISMA frase que «Tu cuenta de Yala», y la misma key, para que no vuelvan a
                    // decir cosas distintas. La nota de antes («queda ligada al método») contradecía al backend: con
                    // Apple y Google activos y el vínculo manual apagado, GoTrue une las dos entradas por el correo
                    // verificado (H4; medido en producción el 2026-10-19, `security_manual_linking_enabled = false`).
                    Text(L10n.Settings.yalaAccountLinkingNote)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)

                    Spacer(minLength: DS.Spacing.xxl)
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Storage.SignIn.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .accessibilityIdentifier("storage_signin_cancel")
                }
            }
        }
        .accessibilityIdentifier("storage_signin_chooser")
        .onAppear {
            // Belt del productor (C-7): con sesión viva esta vista nunca debió presentarse.
            // `.reuseLiveSession` → cerrar y continuar con la cuenta que ya está dentro.
            // `.blockedOtherAccount` → cerrar sin arrancar nada: la card explica por qué (firmar
            // aquí no ayudaría — el belt de la máquina reusaría la sesión viva igualmente).
            switch decision {
            case .reuseLiveSession:     onReuseLiveSession()
            case .blockedOtherAccount:  dismiss()
            case .askProvider:          break
            }
        }
    }
}

// MARK: - Botón SIWA nativo

/// `ASAuthorizationAppleIDButton` (obligado por HIG/App Review 4.8). El flujo real (nonce, exchange,
/// captura de perfil) vive en `CloudAuthService.signInWithApple()`; este botón es solo el afford
/// visual + target-action. Estilo según el scheme del sheet `.subtle` (patrón GroupsAppleSignInButton).
/// `type` es el verbo: `.signIn` aquí (fuera del punto 15) y `.continue` en la hoja única de Ajustes (L20-11), que dice
/// «Continuar con Apple» como su pareja de Google.
struct StorageAppleSignInButton: UIViewRepresentable {
    let colorScheme: ColorScheme
    var type: ASAuthorizationAppleIDButton.ButtonType = .signIn
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            type: type,
            style: colorScheme == .dark ? .white : .black
        )
        button.cornerRadius = DS.Radius.lg
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    /// La acción se renueva en cada render: el `Coordinator` se crea una vez, y con la del primero el botón seguiría con
    /// el plan y la ruta de entonces (review del 2026-10-19).
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
