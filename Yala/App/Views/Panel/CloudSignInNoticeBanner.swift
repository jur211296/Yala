//
//  CloudSignInNoticeBanner.swift
//  Yala
//
//  Card pz4v (Jürgen, 2026-10-28): con la sesión de la nube caducada y miles de cambios sin subir, el Panel se veía
//  tranquilo —saldo en cero, «Aún no tienes registros»— y el único sitio que lo decía era Ajustes › «Dónde viven tus
//  datos». Este es el aviso FIJO del Panel, hermano de `CloudAttestNoticeBanner`: dice que algo no funciona, así que va
//  fuera de la cola «1 de N» y sin X (sigue siendo verdad después de leerlo). Quién decide, en
//  `SyncSignInBannerLogic.showsPanelNotice`; el botón lleva a la tarjeta de Ajustes y arranca allí la firma
//  (`SyncSignInRequest`).
//

import SwiftUI

struct CloudSignInNoticeBanner: View {

    @Environment(\.yalaTheme) private var theme

    /// Cuántos cambios esperan. `nil` = la cola no se dejó contar: el título va sin cifra, como en Ajustes.
    let pendingCount: Int?
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Semantic.warningForeground)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    // La misma frase que la tarjeta de Ajustes: el estado se llama igual en las dos superficies.
                    Text(pendingCount.map { L10n.Storage.Sync.needsSignIn($0) } ?? L10n.Storage.Sync.needsSignInUncounted)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.thPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.Storage.Sync.panelNoticeBody)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            Button(action: onSignIn) {
                Text(L10n.Storage.Sync.signInButton)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.thOnAccent)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("panel_sync_signin_button")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("panel_sync_signin_banner")
    }
}

// MARK: - Decisión y cableado

enum CloudSignInNotice {

    /// Lo que pinta el aviso AHORA: `nil` = no sale; si sale, la cifra (`nil` dentro = sin cifra). Lee el controller, y por
    /// eso lo llama el cableado tras cada `refresh()` y no el body: `CloudMigrationController.shared` es un estático que
    /// `@Observable` no rastrea, y con el Panel pintado antes de que el arranque lo cree (paso 14.6) el body no se habría
    /// suscrito a nada (review adversarial del 2026-10-28). Copiado a un `@State` del Panel, repinta siempre.
    @MainActor
    static func current() -> PanelValue? {
        guard let controller = CloudMigrationController.shared else { return nil }
        let shows = SyncSignInBannerLogic.showsPanelNotice(
            needsSignIn: controller.syncNeedsSignIn,
            channelIsStable: controller.uiState == .cloudActive,
            attestNoticeShowing: false)
        return shows ? PanelValue(pendingCount: controller.pendingUploadCount) : nil
    }

    struct PanelValue: Equatable {
        let pendingCount: Int?
    }
}

/// Mantiene al día lo que lee el aviso: `CloudMigrationController.refresh()`, la MISMA llamada que la pantalla de Ajustes
/// hace cada segundo, y copia el resultado al `@State` del Panel. Aquí no cada segundo —el Panel vive siempre montado—,
/// sino cuando puede haber cambiado algo:
///
///  1. **Al montar y al volver a primer plano.**
///  2. **Cuando el motor cambia de estado** (`CloudSyncRuntime.state`, que no es observable) o, parado sin sesión, cuando
///     la sesión vuelve: un sondeo de 2 s que solo lee valores en memoria y `UserDefaults` (el Llavero, solo en
///     `.idleSignedOut`), y refresca en la TRANSICIÓN. Es el momento decisivo: la sesión caduca en un ciclo con el Panel
///     delante, y al relanzar el motor arranca sin sesión después de que el Panel aparezca.
///  3. **Con el motor esperando a que se firme, cuando algo guardó** (`dataVersion`, en el mismo sondeo): la cifra pendiente
///     se mueve, y el primer cambio que entra en la cola es el que enciende el aviso.
///
/// Tres modificadores y cierres de una línea, a propósito: el compilador del CI (Xcode 26.6) no tipa más
/// (`swiftui-ds.md`).
private struct CloudSignInNoticeWatcher: ViewModifier {
    @Binding var value: CloudSignInNotice.PanelValue?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionState.self) private var sessionState
    @State private var lastRuntimeKey: String?
    @State private var lastDataVersion: Int?

    func body(content: Content) -> some View {
        content
            .onAppear { refresh() }
            .onChange(of: scenePhase) { _, newPhase in phaseChanged(newPhase) }
            .task { await poll() }
    }

    private func phaseChanged(_ phase: ScenePhase) {
        if phase == .active { refresh() }
    }

    private func poll() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            let dataMoved = Self.engineWaitsForSignIn && sessionState.dataVersion != lastDataVersion
            if dataMoved || runtimeKey() != lastRuntimeKey { refresh() }
        }
    }

    /// Los dos estados en los que el motor espera a que se firme (`SyncSignInBannerLogic.engineWaitsForSignIn`).
    private static var engineWaitsForSignIn: Bool {
        let state = CloudSyncRuntime.shared?.state
        return state == .stoppedUntilSignIn || state == .idleSignedOut
    }

    private func runtimeKey() -> String {
        let state = CloudSyncRuntime.shared?.state
        // La sesión solo cuenta parado sin ella: ahí volver a entrar no cambia el estado del motor hasta que arranca.
        let session = state == .idleSignedOut ? CloudAuthService.shared.hasSession : nil
        return "\(CloudSyncFlags.storageMode)|\(String(describing: state))|\(String(describing: session))"
    }

    private func refresh() {
        lastRuntimeKey = runtimeKey()
        lastDataVersion = sessionState.dataVersion
        CloudMigrationController.shared?.refresh()
        let now = CloudSignInNotice.current()
        if now != value { value = now }
    }
}

extension View {
    /// Aplica `CloudSignInNoticeWatcher` sobre el `@State` que se le pase.
    func cloudSignInNoticeWatcher(_ value: Binding<CloudSignInNotice.PanelValue?>) -> some View {
        modifier(CloudSignInNoticeWatcher(value: value))
    }
}

#Preview {
    CloudSignInNoticeBanner(pendingCount: 5006, onSignIn: {})
        .padding(DS.Spacing.md)
        .glassEffect(.regular)
        .padding()
}
