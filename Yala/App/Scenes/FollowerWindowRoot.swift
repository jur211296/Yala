//
//  FollowerWindowRoot.swift
//  Yala
//
//  Lo que monta una ventana según sea líder o seguidora, y la ventana seguidora (fase 4 del carril adaptativo).
//

import SwiftUI
import UIKit

/// Decide qué monta esta ventana: `ContentView` si es la líder, `FollowerWindowRoot` si es otra, y nada (el fondo)
/// mientras todavía no se ha dado de alta. Ver `SceneRegistry`.
///
/// **Un solo `ContentView` por proceso.** Es el shell que lleva el arranque, el Welcome, los borrados remotos, el
/// cierre de sesión y las alertas de sistema; dos copias duplicarían esos flujos. Si la líder se cierra, la siguiente
/// asciende y monta `ContentView`: es el mismo camino que el remonte del swap de contenedor.
struct WindowRoleView<Leader: View>: View {
    @ViewBuilder let leader: () -> Leader

    @Environment(SceneNavigation.self) private var navigation
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        let registry = SceneRegistry.shared
        if registry.leaderID == navigation.id {
            leader()
        } else if registry.isAlive(navigation.id) {
            FollowerWindowRoot()
        } else {
            // El primer frame, antes del alta (un `onAppear`): sin nada que montar todavía.
            theme.background.ignoresSafeArea()
        }
    }
}

/// Una ventana que no es la líder: sus pestañas, su navegación y sus hojas, sin shell propio.
///
/// Lo que la app no deja hacer en ningún sitio —cerrar sesión, actualizar a la fuerza, borrar, contestar algo en la
/// líder— aquí se ve como su cover y **desmonta** el contenido (`FollowerWindowGateLogic`).
struct FollowerWindowRoot: View {
    @Environment(SceneNavigation.self) private var navigation
    @Environment(\.yalaTheme) private var theme
    @State private var languageVersion = 0

    private var state: FollowerWindowGateLogic.State {
        let registry = SceneRegistry.shared
        let phase = CloudSessionSignOut.shared.phase
        return FollowerWindowGateLogic.state(
            leaderBlocker: registry.leaderNavigation?.shellModalBlocker,
            hasLeader: registry.leaderID != nil,
            isWipingData: SessionState.shared.isWipingData,
            busyBySignOut: registry.isBusyBySignOut(navigation.id),
            signOutAwaitingRelaunch: phase == .awaitingRelaunch,
            forceUpdateRequired: ForceUpdateGate.shared.isUpdateRequired,
            // Lectura puntual a propósito: lo que la hace cambiar (el Welcome de la líder, un borrado) mueve antes el
            // bloqueo de la líder, que sí es observable y repinta esta vista.
            hasCompletedOnboarding: UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }

    var body: some View {
        content
            .onChange(of: state, initial: true) { _, newState in
                publish(newState)
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
                languageVersion &+= 1
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .operating:
            MainTabView()
                .modifier(TagCatalogProvider())
                .id(languageVersion)
                .accessibilityIdentifier("follower_window_root")
        case .busy:
            WindowBusyView()
        case .signOutRelaunch:
            SignOutRelaunchView()
                .yalaScreenBackground(.subtle)
        case .forceUpdate:
            ForceUpdateView()
                .yalaScreenBackground(.subtle)
        case .needsLeader:
            FollowerNeedsLeaderView()
        }
    }

    /// Lo que tapa esta ventana, para sus consumidores del router.
    private func publish(_ state: FollowerWindowGateLogic.State) {
        let blocker = state.blockerName
        if navigation.shellModalBlocker != blocker {
            navigation.shellModalBlocker = blocker
        }
    }
}

/// Fondo con progreso, sin nada que tocar.
struct WindowBusyView: View {
    var body: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .yalaScreenBackground(.panel)
            .accessibilityIdentifier("follower_window_busy")
    }
}

/// «Yala te espera en otra ventana»: la líder pregunta algo que hay que contestar allí.
private struct FollowerNeedsLeaderView: View {
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            Image(systemName: "macwindow.on.rectangle")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text(L10n.Window.followerTitle)
                .font(DS.Typography.title2)
                .multilineTextAlignment(.center)
            Text(L10n.Window.followerBody)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
            YalaPrimaryButton(L10n.Window.followerCta, icon: "arrow.up.forward.app") {
                bringLeaderToFront()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
            .accessibilityIdentifier("follower_window_show_leader")
        }
        .frame(maxWidth: DS.Adaptive.readableWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .yalaScreenBackground(.panel)
        .accessibilityIdentifier("follower_window_needs_leader")
    }

    /// Trae al frente la ventana líder. Si el sistema no puede (la escena ya no existe), no hay nada que hacer: la
    /// siguiente ventana asciende sola y esta deja de ser seguidora.
    private func bringLeaderToFront() {
        guard let session = SceneRegistry.shared.leaderSceneSession else { return }
        UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(session: session)) { error in
            #if DEBUG
            print("FollowerNeedsLeaderView: Error: no se pudo traer la ventana líder: \(error)")
            #endif
        }
    }
}

// MARK: - Quién lanzó el cierre de sesión

/// Decisión pura del cierre de sesión con varias ventanas. El dato lo guarda `SceneRegistry.signOutDriverID`.
enum SignOutDriverLogic {
    /// La ventana que lanzó el cierre: la que está delante al ENTRAR en `.working`; mientras dura, se conserva; al
    /// salir, se olvida.
    static func driver(
        previous: UUID?,
        oldPhase: CloudSessionSignOut.Phase,
        newPhase: CloudSessionSignOut.Phase,
        focused: UUID?
    ) -> UUID? {
        guard newPhase == .working else { return nil }
        return oldPhase == .working ? previous : focused
    }

    /// ¿Deja de operar la ventana `windowID`? Mientras dure `.working`, todas menos la que lo lanzó —subir los
    /// pendientes exige que nadie escriba más—, **también si la que lo lanzó ya se cerró**. Sin ventana conocida que
    /// lo lanzara y con una sola viva, es el iPhone de siempre: esa ventana lo lanzó y no se le desmonta nada.
    static func windowIsBusy(windowID: UUID, driverID: UUID?, aliveCount: Int, signOutWorking: Bool) -> Bool {
        guard signOutWorking else { return false }
        guard let driverID else { return aliveCount > 1 }
        return driverID != windowID
    }
}
