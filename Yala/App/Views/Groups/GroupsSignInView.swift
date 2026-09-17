//
//  GroupsSignInView.swift
//  Yala
//
//  Sign-in SOLO-GRUPOS (G4-invites A2, §16d): un invitado por link backend sin sesión Nube firma con
//  Apple o Google para poder unirse. Autentica (SIWA/Google → JWT en `CloudAuthService`) y **pregunta al
//  backend qué hay detrás de esa identidad** — reglas duras que SIGUEN en pie: NO `CloudMigrationController`,
//  NO `startAdoptWithExistingSession`, NO `CrossAccountEntryGuardLogic`, NO toca `StorageMode` ni flags de
//  onboarding de migración. La cuenta queda como sesión viva que `GroupsMembershipClient.tokenProvider`
//  ya consume.
//
//  ## Bloque [I] (2026-09-10): esta puerta CAMBIÓ DE MOTOR, no de aspecto
//
//  Hasta hoy firmaba y nada más, así que trataba como solo-grupos a quien tenía años de finanzas en esa
//  misma cuenta. Ahora, con la sesión ya viva, `CloudIdentityDiscovery` pregunta `GET /account/exists` y
//  `CloudIdentityRoutingLogic` dice a dónde va la persona. Lo que esta vista NO hace es ejecutar ese
//  destino: se lo entrega al productor, que es el dueño del anchor.
//
//  **Por fuera no cambia nada** —decisión de Jürgen, 2026-09-09: «cambia de motor, no de aspecto»—. Los
//  dos botones, su verbo, el spinner y el mensaje de error son los mismos; el descubrimiento corre dentro
//  del MISMO `Task` del sign-in, así que lo único que ocurre es que el spinner gira un poco más — **y en
//  el camino del belt, que antes no tenía spinner, ahora lo hay**. Si algún día esta puerta debe
//  unificarse visualmente con el Welcome, eso es del ticket 12.
//
//  **Las tres reglas duras se conservan y siguen siendo ciertas**: el guard cross-cuenta y el adopt viven
//  en `WelcomeCloudSignInView`, y a esta puerta le llega el destino `adoptAsCompleteAndOpenGroups` para
//  que el productor la reencamine ALLÍ. Nada de eso se ejecuta aquí.
//
//  Invariante R9 (§2): el copy dice que esa será LA cuenta si algún día migra lo personal.
//  Si ya hay sesión viva, la vista JAMÁS se presenta (`GroupBackendInviteEntryLogic.nextStep` lo
//  garantiza en el productor) — y el belt de `onAppear` la cierra igual si aparece. **Ya no es
//  «de inmediato»**: desde el bloque [I] ese belt también descubre el tipo de cuenta, así que enciende el
//  spinner y cierra al volver la red. Sin el spinner, esa ventana re-ofrecería el sign-in con sesión viva,
//  que es justo lo que la regla dura prohíbe.
//
//  DARK: solo la presenta el drain de `.presentGroupsSignIn` (flag `groupsBackendEnabled` OFF ⇒ el
//  intent jamás se submitea).
//

import AuthenticationServices
import SwiftUI

struct GroupsSignInView: View {
    /// Se invoca con la sesión VIVA (recién firmada o preexistente) y con el **destino** que decidió el
    /// bloque [I]. El caller cierra el sheet y rutea: `continueGroupsSetup` / `associateGroupsAccount`
    /// siguen el flujo encadenado de siempre (consent → join), y los otros dos son las novedades.
    var onAuthenticated: (CloudIdentityRoutingLogic.Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    /// [I] · el eje de sesión privada se lee del espejo observable (rules de área: preferencias
    /// persistentes por `AppPreferences`, nunca `UserDefaults` a pelo en una vista).
    @Environment(AppPreferences.self) private var appPreferences

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
                        // C-10: el texto anterior ("no pudimos conectar tu cuenta, inténtalo de nuevo")
                        // era terminal — reintentar daba siempre lo mismo y no decía qué pasaba con el
                        // grupo. Ahora dice que no se pierde nada y que el grupo sigue accesible detrás.
                        Text(L10n.Groups.SignIn.retryLater)
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

                            // G3 (2026-08-11): el verbo pasa de `.continue` a `.signUp`. W4 enseñó al
                            // Welcome a distinguir alta de reentrada y este sheet se quedó en el neutro,
                            // pero sus dos entradas —el invitado por link y ahora el ORGANIZADOR que crea
                            // su primer grupo— son altas: nadie llega aquí con una sesión viva (el
                            // `onAppear` de abajo la cierra si la hay, y el productor lo garantiza).
                            GoogleSignInButton(variant: colorScheme == .dark ? .dark : .light,
                                               purpose: .signUp) {
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
            //
            // [I]: también por aquí hay que descubrir el destino. Sin esto, el único camino con sesión
            // preexistente se saltaría la tabla entera y seguiría tratando como solo-grupos a una cuenta
            // completa — el bug del ticket, entrando por la puerta de atrás.
            if CloudAuthService.shared.hasSession {
                // `isSigningIn` ANTES del await, y es lo que mantiene viva la regla dura del docblock
                // («jamás re-ofrecer sign-in con sesión»). Sin él, el descubrimiento convierte un frame en
                // un viaje de red con los dos botones y el «Cancelar» tapeables: un tap en Apple firmaría
                // ENCIMA de una sesión viva, y un tap en Cancelar mataría el Task y el productor trataría
                // como cancelada una sesión que era buena.
                isSigningIn = true
                signInTask?.cancel()
                signInTask = Task { @MainActor in
                    let destino = await resolveDestination()
                    guard !Task.isCancelled else { return }
                    isSigningIn = false
                    onAuthenticated(destino)
                }
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
                // [I] · el descubrimiento va DENTRO de este Task, antes de avisar al productor. Fuera
                // —en el closure del callback— habría carrera: el `onDismiss` del sheet corre en cuanto
                // `showGroupsSignIn` baja, y llegaría al ruteo con el destino todavía sin resolver.
                let destino = await resolveDestination()
                guard !Task.isCancelled else { return }
                isSigningIn = false
                onAuthenticated(destino)
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

// MARK: - Bloque [I] · el descubrimiento

extension GroupsSignInView {

    /// Pregunta al backend qué hay detrás de la identidad viva y consulta la tabla del ADR §7.
    ///
    /// **Un `exists` que no contesta NO bloquea la entrada al grupo.** Degrada a `groupsOnly`, que es lo
    /// que esta puerta hacía antes de que el dato existiera, y `AccountKindService.refresh()` corrige en el
    /// arranque siguiente. La alternativa —parar el recorrido— dejaría a un invitado sin poder unirse
    /// porque el gateway tosió, y la matriz de escenarios pide justo lo contrario para cualquier [I] sin
    /// red: «error reintentable, sin crear ni borrar nada». Aquí no hay nada que crear ni borrar todavía.
    ///
    /// El estado del dispositivo se lee VIVO, en el instante de la decisión: entre montar el sheet y firmar
    /// puede haber terminado un restore de iCloud, y con él aparece una sesión privada que no estaba.
    @MainActor
    func resolveDestination() async -> CloudIdentityRoutingLogic.Destination {
        let discovery: CloudIdentityRoutingLogic.Discovery
        var userID: String?
        switch await CloudIdentityDiscovery().discover(gate: .groups) {
        case .discovered(let resultado, let discoveredUserID):
            discovery = resultado
            userID = discoveredUserID
        case .unavailable:
            discovery = .groupsOnly
        }
        return CloudIdentityRoutingLogic.destination(
            gate: .groups,
            discovery: discovery,
            deviceState: CloudIdentityRoutingLogic.deviceState(
                // Por el espejo observable y no por `UserDefaults.standard`: es lo que piden las rules
                // de área para una vista, y `hasCompletedOnboarding` es la key más dispersa del árbol —
                // un lector nuevo a pelo la dispersa un poco más.
                hasCompletedOnboarding: appPreferences.hasCompletedOnboarding,
                storageMode: StorageModePersistence.read(),
                hasPrivateSession: PrivateSessionMark.hasPrivateSession()),
            // Paso 10 · desde aquí SÍ se puede contestar: la asociación es estado propio y persistido.
            // La tabla solo lo mira en la puerta de Ajustes, así que por ésta no cambia ningún destino —
            // se pasa igual porque el parámetro no tiene default a propósito y porque el día que la
            // tabla lo consulte aquí, la respuesta correcta ya estará puesta.
            //
            // `nil` solo cuando no hay asociación registrada. Con una registrada y sin `userID` (el descubrimiento no
            // lo dejó y no hay sesión) es `false`. Esta puerta no lo lee; en la de Ajustes `nil` deja seguir y `false`
            // bloquea (2026-09-16), así que la falta de `userID` cae del lado del bloqueo.
            isAssociatedGroupsAccount: GroupsAccountAssociation.shared.isAssociated(
                sub: userID ?? CloudAuthService.shared.currentUserID))
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
