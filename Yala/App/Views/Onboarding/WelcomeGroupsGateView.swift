//
//  WelcomeGroupsGateView.swift
//  Yala
//
//  G3 de Grupos-first · **el primer paso de la rama organizador no pide nada: comprueba la puerta.**
//
//  Es un STEP del `WelcomeFlowContainer` y no una pantalla propia de `ContentView`, por las tres razones
//  medidas que el spec fija para `.groupsChooser` y `.mirrorRelaunch`: el portal `leaveWelcome` es el
//  único punto de salida del cover, una presentación nueva del anchor de `ContentView` tendría que entrar
//  a la matriz de readiness (regla 3 de Presentaciones), y un step que se queda DENTRO ya está cubierto
//  por `showWelcomeFlow`, que es el blocker de la cadena entera.
//
//  Y **no puede ser un `.alert(`**: `WelcomeHeroReentryTests` lo prohíbe por source-scan en el container.
//  Aquí no hace falta ninguna excepción — un alert además contaría como camino muerto en un flujo que el
//  spec exige que jamás lo tenga.
//
//  **El `force: true` del refresh no es cosmético.** Sin él, `refreshIfDue` es un no-op exactamente en el
//  caso del bug: el min-interval es de 6 h y el arranque ya gastó la ventana con su propio refresh
//  fire-and-forget. La regla —«la intención del usuario ES evidencia de que el canal debería estar
//  encendido»— está escrita en `GroupInviteChannelRoutingLogic`, que la aplica al recibir un link backend.
//

import SwiftUI

struct WelcomeGroupsGateView: View {

    /// Fetch VIVO del corpus local, no un snapshot: es el mismo argumento (y el mismo closure) que el
    /// guard cross-cuenta del Welcome usa, porque el mirror de iCloud puede estar re-importando mientras
    /// el usuario mira estas pantallas.
    let hasLocalDataNow: @MainActor @Sendable () -> Bool
    /// La puerta abrió: seguir a `leaveWelcome(to: .groupsOrganizer)`.
    var onProceed: () -> Void
    /// Vuelta al step de los dos caminos. También es el CTA de las dos pantallas de bloqueo — «vuelve al
    /// chooser con todas las demás vías intactas», que es la mitad de «ningún camino muerto».
    var onBack: () -> Void

    /// `nil` mientras se comprueba. No se inicializa a `.proceed` a propósito: un default optimista pinta
    /// medio frame de la rama buena antes de bloquear.
    @State private var decision: GroupsOrganizerGateLogic.Decision?

    var body: some View {
        WelcomeFlowScreen { logoTopSpacing in
            VStack(spacing: 0) {
                Spacer(minLength: logoTopSpacing)

                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .colorMultiply(.white)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.xl)

                switch decision {
                case nil, .proceed:
                    // `.proceed` no pinta nada propio: el step se desmonta en la misma vuelta en que se
                    // decide, así que enseñar una pantalla de éxito sería un parpadeo.
                    checkingContent
                case .blockedChannelOff:
                    blockedContent(
                        icon: "person.2.slash",
                        title: L10n.Welcome.Groups.channelOffTitle,
                        body: L10n.Welcome.Groups.channelOffBody,
                        identifier: "welcome_groups_gate_channel_off")
                case .blockedSecondarySession:
                    // C3 · estás de visita en el móvil de otra persona. Copy PROPIO: el hecho no es «hay
                    // datos de otro humano» sino «esta sesión no es de este dispositivo», y aquí sí hay
                    // salida (cerrar la sesión de invitado y volver desde el suyo).
                    blockedContent(
                        icon: "person.crop.circle.badge.clock",
                        title: L10n.Welcome.Groups.secondaryTitle,
                        body: L10n.Welcome.Groups.secondaryBody,
                        identifier: "welcome_groups_gate_secondary_session")
                case .blockedForeignData:
                    // Copy PROPIO, como las otras dos razones. Hasta el 2026-08-12 esta rama pedía
                    // prestado el del guard cross-cuenta del sign-in (`welcome.cloud.blocked*`), que
                    // dice «este dispositivo tiene datos de OTRA cuenta … no podemos conectar una
                    // cuenta distinta aquí» — y quien llega hasta aquí no está conectando ninguna
                    // cuenta, sino intentando crear un grupo, muchas veces sobre datos SUYOS. El
                    // detector cuenta filas y no puede saber de quién son (`CloudClaimActionStore`,
                    // la única prueba de propiedad, no se consulta en esta puerta y además muere con
                    // la reinstalación), así que el copy nombra el hecho que sí es cierto.
                    // El bloqueo NO cambia: sigue siendo el de la ventana M1 del docblock del gate.
                    blockedContent(
                        icon: "square.stack.3d.up.slash",
                        title: L10n.Welcome.Groups.existingDataTitle,
                        body: L10n.Welcome.Groups.existingDataBody,
                        identifier: "welcome_groups_gate_foreign_data")
                }

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        .welcomeBackButton(tint: .white, action: onBack)
        .task {
            await evaluate()
        }
    }

    // MARK: - Contenido

    private var checkingContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text(L10n.Welcome.Groups.checking)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
        .accessibilityIdentifier("welcome_groups_gate_checking")
    }

    private func blockedContent(icon: String, title: String, body: String, identifier: String) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 44)) // A11Y-DT: icono decorativo hero, tamaño fijo (patrón del flow)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.lg)

            YalaPrimaryButton(L10n.Welcome.Groups.gateBack) {
                onBack()
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - La puerta

    /// El orden es el del spec y **no se puede reordenar**: primero se re-mide el canal (con `force`),
    /// después se decide, y **solo `.proceed` continúa**. Esta función no escribe nada en `UserDefaults`
    /// — ni ella ni ninguna a la que llame — y eso es la mitad del chip: `onboardingMode` es
    /// never-downgrade cross-device, así que una escritura prematura viaja al iKV y no vuelve.
    private func evaluate() async {
        // Hermeticidad: bajo `-uitest` no se toca red, igual que el `.task` del container. Los getters ya
        // devuelven su default (ON bajo `Yala Dev`), así que el XCUITest recorre la rama buena.
        if !SwiftDataConfiguration.isUITesting {
            await RemoteConfigClient.shared.refreshIfDue(force: true)
        }

        // El `.task` se cancela al desmontar el step, pero la CANCELACIÓN ES COOPERATIVA: `refreshIfDue`
        // no la mira, así que sin este guard un usuario que tapea «volver» durante el refresh saldría del
        // Welcome igual cuando la red conteste. Es el único punto de suspensión de la rama.
        guard !Task.isCancelled else { return }

        let verdict = GroupsOrganizerGateLogic.decide(
            channelEnabled: CloudSyncFlags.groupsBackendEnabled,
            // C3 · el descriptor, no el corpus: en secundaria el detector de abajo mide el store de la
            // INVITADA (vacío en una sesión recién montada) y daría vía libre justo donde el alta escribe
            // las seis preferencias en el `UserDefaults` del DUEÑO.
            isSecondarySession: SecondarySessionStore.isActive(),
            hasExistingData: hasLocalDataNow())

        decision = verdict
        if verdict == .proceed {
            onProceed()
        }
    }
}
