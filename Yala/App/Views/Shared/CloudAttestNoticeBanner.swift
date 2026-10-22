//
//  CloudAttestNoticeBanner.swift
//  Yala
//
//  El aviso FIJO de que este teléfono no consigue App Attest y sus datos PERSONALES no están subiendo a la nube
//  (ticket `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`). Quién decide, en `CloudAttestNoticeLogic`.
//
//  **Por qué las tres piezas viven juntas y no dentro de una vista.** El aviso sale en DOS superficies —la pila de
//  banners del Panel, donde lo ve quien apunta gastos que no llegan, y la sección de estado de «Dónde viven tus
//  datos», que hasta hoy pintaba un check verde «Todo al día» con el motor parado— y las dos tienen que decir lo
//  mismo. Repetir el copy, el criterio o el cableado en dos vistas es exactamente cómo divergen.
//
//   - `CloudAttestNoticeBanner` — el CONTENIDO (icono + título + cuerpo), sin fondo ni padding: el chrome lo pone
//     cada superficie, porque el Panel lo quiere en glass y la card de Ajustes ya trae el suyo.
//   - `CloudAttestNotice.isShowing(verdictIsTerminal:)` — resuelve el entorno vivo (modo de almacenamiento y
//     sesión) y se lo pasa a la lógica pura. **Un solo sitio que leer** si alguna vez cambia un término.
//   - `.cloudAttestVerdictWatcher($flag)` — el cableado reactivo.
//
//  **Por qué el veredicto va en un `@State` y las otras dos condiciones NO.** Copiado del hermano de Grupos, que lo
//  midió: `isTerminal()` lee `UserDefaults`, que no repinta ninguna vista, y además depende del reloj —una racha de
//  ayer se vuelve terminal sin que nadie escriba nada—. Las otras dos se leen VIVAS al decidir, así que el body las
//  vuelve a mirar cada vez que se re-evalúa; congelarlas en un `@State` las dejaría rancias sin un gesto que las
//  refresque.
//

import SwiftUI

/// El contenido del aviso. Sin X y sin botón, a propósito: describe un estado que sigue ahí después de leerlo, así
/// que descartarlo solo serviría para ocultarlo, y no hay ninguna acción que lo arregle desde este teléfono
/// —reintentar es lo que lleva un día fallando—. El cuerpo ofrece lo único cierto: otro teléfono, o exportar.
///
/// Reusa el título de los gestos (`Settings.signOutAttestTitle`) para que la avería se llame igual en todas partes.
struct CloudAttestNoticeBanner: View {

    /// El id va en el CONTENEDOR y lo heredan sus textos. Distinto por superficie para que un test sepa cuál mira.
    let accessibilityID: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(DS.Semantic.warningForeground)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Settings.signOutAttestTitle)
                    .font(DS.Typography.labelSmall)
                Text(L10n.Settings.attestTerminalBanner)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier(accessibilityID)
    }
}

// MARK: - Decisión con el entorno vivo

enum CloudAttestNotice {

    /// ¿Se enseña el aviso AHORA? El veredicto lo mantiene la vista (ver `cloudAttestVerdictWatcher`); las otras
    /// tres condiciones se resuelven aquí, vivas.
    ///
    /// **El término del canal es `storageMode`, no un flag remoto**, por lo mismo que el aviso de Grupos lee la
    /// capacidad compilada: el remoto es fail-closed ante un snapshot ausente y no es testigo del corpus de este
    /// teléfono. Y `channelIsStable` lee el estado que el controller ya publica: es `@Observable`, así que el body
    /// se re-evalúa solo cuando la migración avanza. El porqué largo, en `CloudAttestNoticeLogic`.
    @MainActor
    static func isShowing(verdictIsTerminal: Bool) -> Bool {
        // **El guard no es microoptimización: sin él esto lee el Keychain en cada re-render.**
        // `hasLiveSession` es un ARGUMENTO, y Swift evalúa los argumentos antes de llamar, así que el
        // `&&` de `showsNotice` no lo cortocircuita — `CloudAuthService.hasSession` baja a
        // `CloudAuthKeychainStorage` (`SecItemCopyMatching`) y se pagaría también en el 100 % de
        // teléfonos que nunca tendrán veredicto. Duele en los dos call-sites: el body del Panel se
        // re-evalúa durante el scroll, y «Dónde viven tus datos» repinta ~1×/s por el tick del journal
        // — que es exactamente por lo que `signInDecision`, en esa misma pantalla, ya lleva el suyo.
        //
        // El veredicto es el término bueno para filtrar: es el más selectivo y el único gratis (un
        // `@State` que ya está en memoria). **No tapa a la lógica** —la tabla de `showsNotice` se
        // prueba llamándola directo en `CloudAttestNoticeLogicTests`, no a través de aquí—, así que un
        // mutante que se deje un operando muere igual.
        guard verdictIsTerminal else { return false }
        return CloudAttestNoticeLogic.showsNotice(
            verdictIsTerminal: verdictIsTerminal,
            personalDataLivesInCloud: CloudSyncFlags.storageMode == .cloud,
            channelIsStable: CloudMigrationController.shared?.uiState == .cloudActive,
            hasLiveSession: CloudAuthService.shared.hasSession)
    }
}

// MARK: - Cableado reactivo

/// Mantiene al día el veredicto del attest en el `@State` de quien lo aplique.
///
/// Los TRES momentos en que el resultado puede haber cambiado sin que la vista se entere:
///
///  1. **Al montar** — la racha pudo escribirse en otro arranque, o en otra pantalla.
///  2. **Cuando el store avisa** (`GroupsAttestStreakStore.didChangeNotification`) — el único que no depende de un
///     gesto, y el que cierra el hueco de verdad: el 401 llega con la pantalla delante. Medido en el hermano de
///     Grupos el 2026-09-15: sin esto, una racha escrita un segundo después del arranque no salía hasta salir y
///     volver.
///  3. **Al volver de background** — el veredicto depende del reloj: una racha de ayer se vuelve terminal sola,
///     sin que nadie escriba nada y por tanto sin notificación que lo anuncie.
private struct CloudAttestVerdictWatcher: ViewModifier {
    @Binding var verdictIsTerminal: Bool
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { refresh() }
            .onReceive(NotificationCenter.default.publisher(
                for: GroupsAttestStreakStore.didChangeNotification)) { _ in
                refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { refresh() }
            }
    }

    private func refresh() {
        verdictIsTerminal = GroupsAttestStreakStore.isTerminal()
    }
}

extension View {
    /// Aplica el cableado de `CloudAttestVerdictWatcher` sobre el `@State` que se le pase.
    func cloudAttestVerdictWatcher(_ verdictIsTerminal: Binding<Bool>) -> some View {
        modifier(CloudAttestVerdictWatcher(verdictIsTerminal: verdictIsTerminal))
    }
}
