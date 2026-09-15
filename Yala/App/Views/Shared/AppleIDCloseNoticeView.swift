//
//  AppleIDCloseNoticeView.swift
//  Yala
//
//  La hoja «Cambiaste de cuenta de iCloud»: pregunta, cierra y, si el cierre se bloquea, lo cuenta.
//
//  **Una sola presentación con FASES, y no un `.alert`** (ticket
//  `apple-id-close-blocked-has-no-visible-outcome`). Hasta el 2026-09-15 era un alert de
//  `ShellDataAlertsModifier` cuyo botón lanzaba el cierre y se cerraba. Si el cierre se bloqueaba no se
//  veía nada —ni progreso, ni motivo, ni salida— y el coordinador se quedaba en `.blocked` el resto del
//  lanzamiento, cerrándole la puerta a todo gesto que empieza con `guard phase == .idle`. Encender un
//  segundo alert desde el botón del primero es el molde de brick de `.claude/rules/swiftui-ds.md`; lo que
//  la rule prescribe es esto, el criterio de `LateICloudMirrorNoticeView` y `WelcomePrivateICloudGateView`.
//
//  Dos piezas, y cada una tiene un solo trabajo:
//   · `AppleIDCloseNoticeModifier` es el DUEÑO de la presentación: la hoja, la red que verifica que UIKit
//     la montó y el relevo del anchor al cover del relanzamiento.
//   · `AppleIDCloseNoticeView` es el contenido: lee la condición viva y la fase del coordinador, y sus
//     botones piden el cierre. Qué enseña y qué hace cada botón lo decide `AppleIDCloseNoticeLogic`.
//

import SwiftData
import SwiftUI

// MARK: - La presentación

struct AppleIDCloseNoticeModifier: ViewModifier {

    /// La CONDICIÓN VIVA. Vive en `ContentView`, que la mete en la matriz de readiness.
    @Binding var notice: AppleIDCloseNotice?

    /// **Red VISUAL, no condición**: el `isPresented` de la hoja. La red lo apaga y lo enciende para
    /// re-presentar, y por eso la matriz no cuelga de él.
    @State private var showSheet = false
    /// `true` solo cuando el `onAppear` del contenido real disparó: la única prueba de que UIKit presentó.
    @State private var sheetDidAppear = false
    /// La red de presentación efectiva. Vive mientras dura la verificación.
    @State private var netTask: Task<Void, Never>?

    /// La fase del coordinador. Se lee en el `body` para que `@Observable` la rastree.
    private var coordinatorPhase: CloudSessionSignOut.Phase { CloudSessionSignOut.shared.phase }

    func body(content: Content) -> some View {
        content
            .onChange(of: notice, initial: true) { _, newNotice in
                if newNotice == nil {
                    stopPresenting()
                } else if !showSheet {
                    arm()
                }
            }
            // **El relevo al cover terminal.** Con el borrado armado, la hoja se retira y suelta la condición
            // viva. La matriz sigue retenida por `showSignOutRelaunch`, y el cover —dueño único del anchor en
            // esa fase— reintenta solo hasta montar. Sin esto, los dos competirían por el mismo anchor.
            .onChange(of: coordinatorPhase) { _, newPhase in
                if AppleIDCloseNoticeLogic.releasesOnPhaseChange(notice: notice, phase: newPhase) {
                    notice = nil
                }
            }
            .sheet(isPresented: $showSheet, onDismiss: {
                let wasPresented = sheetDidAppear
                sheetDidAppear = false
                // UIKit tumbó una hoja que SÍ estaba en pantalla y el aviso sigue pendiente: se vuelve a
                // presentar (regla «toolbar muerta»). El toggle de la propia red sobre una hoja que nunca
                // montó no cuenta: re-armar ahí reiniciaría el cap y la red no se agotaría jamás.
                if AppleIDCloseNoticeLogic.rearmsOnDismiss(
                    wasPresented: wasPresented, notice: notice, phase: CloudSessionSignOut.shared.phase) {
                    arm()
                }
            }) {
                AppleIDCloseNoticeView(notice: $notice)
                    .onAppear {
                        // Presentación REAL confirmada. Jamás se toggla una hoja viva.
                        sheetDidAppear = true
                        netTask?.cancel()
                        netTask = nil
                    }
            }
    }

    private func arm() {
        showSheet = true
        // Un solo bucle vivo: dos togglando el mismo binding reproducirían la carrera que la red existe
        // para impedir.
        netTask?.cancel()
        netTask = Task { @MainActor in await verifyPresentation() }
    }

    private func stopPresenting() {
        netTask?.cancel()
        netTask = nil
        showSheet = false
    }

    /// **Verificación de presentación EFECTIVA, y su desarme.** Molde `SignOutRelaunchNetModifier` —el
    /// `onAppear` del contenido es la prueba y `RelaunchNetLogic` pone las cadencias— con el desarme del aviso
    /// de vaciado remoto: al agotarse el cap, el aviso se SUELTA, porque quedarse retenido cuesta la sesión
    /// entera. Qué se suelta y qué se reconoce lo decide `AppleIDCloseNoticeLogic.onPresentationExhausted`.
    private func verifyPresentation() async {
        do {
            try await Task.sleep(for: RelaunchNetLogic.initialVerifyDelay)
        } catch {
            return  // Cancelada: el aviso se contestó, o otro armado la relevó.
        }
        var attempt = 0
        while !Task.isCancelled {
            let armed = AppleIDCloseNoticeLogic.presentationArmed(
                notice: notice, phase: CloudSessionSignOut.shared.phase)
            switch RelaunchNetLogic.verdict(armed: armed, coverDidAppear: sheetDidAppear, attempt: attempt) {
            case .standDown, .satisfied:
                return
            case .retry:
                // Cede un turno y vuelve a mirar antes de togglar: el `onAppear` pudo encolarse justo antes.
                await Task.yield()
                guard !Task.isCancelled, !sheetDidAppear else { return }
                attempt += 1
                showSheet = false
                do {
                    try await Task.sleep(for: RelaunchNetLogic.toggleGap)
                } catch {
                    return
                }
                // La CONDICIÓN VIVA, no solo la cancelación: si el aviso se soltó en esos 50 ms, volver a
                // encender la hoja la presentaría con la matriz ya libre.
                guard AppleIDCloseNoticeLogic.presentationArmed(
                    notice: notice, phase: CloudSessionSignOut.shared.phase) else { return }
                showSheet = true
                do {
                    try await Task.sleep(for: RelaunchNetLogic.retryInterval)
                } catch {
                    return
                }
            case .exhausted:
                switch AppleIDCloseNoticeLogic.onPresentationExhausted(
                    notice: notice, phase: CloudSessionSignOut.shared.phase) {
                case .keepTrying:
                    attempt = 0
                case .release(let acknowledgingBlocked):
                    if acknowledgingBlocked { CloudSessionSignOut.shared.acknowledgeBlocked() }
                    MetricsService.canary(.appleIDCloseNoticeNotPresented)
                    notice = nil
                    showSheet = false
                    return
                }
            }
        }
    }
}

// MARK: - El contenido

struct AppleIDCloseNoticeView: View {

    /// La condición viva de `ContentView`. Se lee por `Binding` y no por valor: la hoja sigue montada
    /// mientras cambia, y una copia se quedaría con lo de antes.
    @Binding var notice: AppleIDCloseNotice?

    @Environment(\.modelContext) private var modelContext

    /// **La última etapa enseñada con el aviso pendiente, congelada.** Cuando la hoja se retira, el aviso ya
    /// es `nil` y la fase del coordinador puede haber cambiado en el mismo gesto: «Ahora no» reconoce el
    /// bloqueo antes de soltar. Recalcular ahí pintaría un progreso o un «un momento más» durante la animación
    /// de salida, lo contrario de lo que la persona eligió. Por eso se congela la ETAPA y no el aviso (review
    /// adversarial del 2026-09-15).
    @State private var lastStage: AppleIDCloseNoticeLogic.Stage = .asking

    /// El coordinador del cierre. Su fase se lee en el `body` para que `@Observable` la rastree.
    private var coordinator: CloudSessionSignOut { CloudSessionSignOut.shared }

    /// La etapa de ahora, o `nil` si el aviso ya se soltó. Lleva dentro la salida que pierde los cambios de grupos, para
    /// que se congele con ella (ver `AppleIDCloseNoticeLogic.stage(notice:phase:offersGroupsLossExit:)`).
    private var liveStage: AppleIDCloseNoticeLogic.Stage? {
        notice.map {
            AppleIDCloseNoticeLogic.stage(notice: $0, phase: coordinator.phase,
                                          offersGroupsLossExit: coordinator.offersGroupsLossExit)
        }
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer(minLength: DS.Spacing.lg)
            content
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .yalaScreenBackground(.subtle)
        // Como un alert: se sale por sus botones. Un swipe no dice si es «Ahora no», y a mitad del cierre
        // no hay abandono posible.
        .interactiveDismissDisabled()
        .onChange(of: liveStage, initial: true) { _, stage in
            if let stage { lastStage = stage }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch liveStage ?? lastStage {
        case .asking:
            // Primero visualmente la salida que NO destruye, como en `LateICloudMirrorNoticeView`: el borrado
            // tiene que ser un gesto deliberado.
            noticeBody(
                icon: "exclamationmark.icloud",
                title: L10n.iCloud.appleIDChangedTitle,
                message: L10n.iCloud.appleIDChangedMessage,
                identifier: "apple_id_close_asking") {
                YalaPrimaryButton(L10n.iCloud.appleIDChangedLater) { later() }
                    .accessibilityIdentifier("apple_id_close_later")
                Button(role: .destructive) {
                    requestClose()
                } label: {
                    Text(L10n.iCloud.appleIDChangedConfirm)
                        .font(DS.Typography.label)
                        .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("apple_id_close_confirm")
            }
        case .working:
            VStack(spacing: DS.Spacing.lg) {
                Text(L10n.iCloud.appleIDChangedTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)
                ProgressView()
                    .controlSize(.large)
                // Solo cuando es verdad: el caption sale mientras el coordinador ESPERA a que se asienten sus
                // cambios de grupos, igual que en Ajustes. En la celda C el cierre no sube nada y dura un
                // parpadeo; decir «guardando» ahí sería falso.
                if coordinator.waitingForPending {
                    Text(L10n.Settings.signOutWorking)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .accessibilityIdentifier("apple_id_close_working")
        case .blocked(let reason):
            blockedBody(reason: reason)
        case .losingGroupChanges(let pending):
            attestLossBody(pending: pending)
        case .busy:
            // Ni cierre en vuelo ni bloqueo que enseñar: no arrancó, u otra pantalla ya reconoció el bloqueo.
            // «Un momento más» es lo cierto, y las dos salidas siguen ahí.
            blockedBody(reason: .transient, identifierOverride: "apple_id_close_busy")
        }
    }

    /// El bloqueo, con el copy que Ajustes ya enseña para el mismo motivo (`SignOutBlockedCopy`).
    ///
    /// **El identificador sale del MISMO motivo que el texto.** Calculado fuera, pasar aquí otro motivo dejaría
    /// el identificador bien y el texto mal, y el XCUITest —que mira el identificador— no lo vería.
    private func blockedBody(reason: CloudSignOutFlowLogic.BlockReason,
                             identifierOverride: String? = nil) -> some View {
        noticeBody(
            icon: "exclamationmark.triangle",
            title: SignOutBlockedCopy.title(for: reason),
            message: SignOutBlockedCopy.message(for: reason),
            identifier: identifierOverride ?? "apple_id_close_blocked_\(reason.breadcrumbSlug)") {
            // «Reintentar» es el mismo gesto que la persona ya confirmó.
            YalaPrimaryButton(L10n.Action.retry) { requestClose() }
                .accessibilityIdentifier("apple_id_close_retry")
            YalaSecondaryButton(L10n.iCloud.appleIDChangedLater) { later() }
                .accessibilityIdentifier("apple_id_close_later")
        }
    }

    /// **El teléfono sin App Attest** (2026-09-15): el aviso cuenta lo que se pierde con el texto de Ajustes
    /// (`SignOutBlockedCopy.attestLossMessage`) y ofrece cerrar igualmente. «Ahora no» va primero, como en la pregunta:
    /// perder cambios tiene que ser un gesto deliberado. Sin «Reintentar»: tras un día sin attest no es lo que ayuda.
    private func attestLossBody(pending: Int) -> some View {
        noticeBody(
            icon: "exclamationmark.triangle",
            title: SignOutBlockedCopy.title(for: .attestUnavailable),
            message: SignOutBlockedCopy.attestLossMessage(pending: pending),
            // Identificador propio: el mismo motivo sin salida lleva `apple_id_close_blocked_attest-unavailable`, y los dos
            // textos son distintos.
            identifier: "apple_id_close_losing_group_changes") {
            YalaPrimaryButton(L10n.iCloud.appleIDChangedLater) { later() }
                .accessibilityIdentifier("apple_id_close_later")
            Button(role: .destructive) {
                discardUnsyncedGroups()
            } label: {
                Text(L10n.Groups.Errors.attestUnavailableSignOutLossButton)
                    .font(DS.Typography.label)
                    .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("apple_id_close_discard_groups")
        }
    }

    /// «Cerrar sesión y perderlos»: el cierre retoma donde paró aceptando la cifra enseñada
    /// (`CloudSessionSignOut.exitDiscardingUnsyncedGroups`). En un `Task` suelto por lo mismo que `requestClose`: si UIKit
    /// desmontara la hoja, el cierre sigue y la red la vuelve a presentar con la fase que tenga.
    private func discardUnsyncedGroups() {
        guard coordinator.offersGroupsLossExit else { return }
        notice = .closing
        let context = modelContext
        let pending = $notice
        Task { @MainActor in
            await CloudSessionSignOut.shared.exitDiscardingUnsyncedGroups(context: context)
            if pending.wrappedValue == .closing {
                pending.wrappedValue = AppleIDCloseNoticeLogic.noticeAfterClose(
                    phaseAfter: CloudSessionSignOut.shared.phase)
            }
        }
    }

    /// El identificador va en la cabecera (icono y textos) y NO en el contenedor entero: aplicado ahí,
    /// pisaría el de los botones (`.claude/rules/testing.md`).
    private func noticeBody<Actions: View>(
        icon: String, title: String, message: String, identifier: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 44)) // A11Y-DT: icono decorativo hero, tamaño fijo (patrón del flow)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(spacing: DS.Spacing.sm) {
                    Text(title)
                        .font(DS.Typography.title2)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityIdentifier(identifier)

            VStack(spacing: DS.Spacing.sm) {
                actions()
            }
        }
    }

    // MARK: - Los botones

    /// «Ahora no». Suelta el aviso, que vuelve en el arranque siguiente: el latch de `AppBootstrapper` es por
    /// proceso. Si el cierre de ESTE aviso paró en un bloqueo, antes lo reconoce: la hoja es la única
    /// pantalla que lo enseña, y un `.blocked` que sobrevive a ella tapia al coordinador.
    private func later() {
        if AppleIDCloseNoticeLogic.laterAcknowledgesBlocked(notice: notice, phase: coordinator.phase) {
            coordinator.acknowledgeBlocked()
        }
        notice = nil
    }

    /// «Cerrar sesión y quitarlos», y «Reintentar».
    ///
    /// **La celda se resuelve AQUÍ, con los mismos getters que el coordinador** —la capacidad COMPILADA de
    /// Grupos, como `ProfileView.signOutRowPath` y `WelcomeGroupsGateView.exitCell`— y viaja como
    /// `confirmedPath`. El alert de antes leía el getter compuesto: con el kill remoto de Grupos, o sin
    /// snapshot de remote-config, y una sesión de grupos viva, el tap resolvía la celda C y el coordinador la
    /// D, `confirmedPath` no casaba y `signOut` volvía sin hacer nada. Se mide en el tap, y no en la
    /// detección, porque el intent no es transitorio y puede haber esperado en cola a través de un background.
    ///
    /// **`confirmedWithoutICloudCopy: true` es lo que la persona acaba de confirmar**, no un flag heredado. La
    /// cuenta de destino ya no está y el propio cambio de cuenta invalidó el ancla del export, así que esperar
    /// serían 45 s para acabar bloqueado. El mensaje del aviso lo dice con esas palabras.
    ///
    /// **El cierre corre en un `Task` suelto y no en el `.task` de la vista.** Si UIKit desmontara la hoja,
    /// cancelar la subida de grupos fabricaría un `.blocked(.transient)`. Suelto, el cierre sigue, y la red
    /// vuelve a presentar la hoja con la fase que tenga.
    private func requestClose() {
        let cell = CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode,
            hasLiveSession: CloudAuthService.shared.hasSession,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability,
            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
        switch AppleIDCloseNoticeLogic.closeRequest(cell: cell, phase: coordinator.phase) {
        case .release:
            notice = nil
        case .couldNotStart:
            notice = .couldNotStart
        case .start(let acknowledgingBlockedFirst):
            if acknowledgingBlockedFirst { coordinator.acknowledgeBlocked() }
            notice = .closing
            let context = modelContext
            let pending = $notice
            Task { @MainActor in
                await CloudSessionSignOut.shared.signOut(
                    context: context, confirmedPath: cell, confirmedWithoutICloudCopy: true)
                // Vuelto el cierre, el aviso deja de estar EN VUELO. Sin esto, un bloqueo que otra pantalla
                // reconociera después dejaría la hoja en un progreso que no avanza, sin botones y reteniendo
                // el router.
                if pending.wrappedValue == .closing {
                    pending.wrappedValue = AppleIDCloseNoticeLogic.noticeAfterClose(
                        phaseAfter: CloudSessionSignOut.shared.phase)
                }
            }
        }
    }
}
