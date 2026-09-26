//
//  GroupsAssociationSection.swift
//  Yala
//
//  Paso 10 · la sección «Grupos» de «¿Dónde viven tus datos?».
//
//  Hasta aquí esa pantalla solo hablaba del almacenamiento PERSONAL (iCloud o nube, migrar, revertir,
//  estado del sync). El ADR §4 le añade la otra mitad: **la cuenta que esta sesión privada usa para
//  grupos se ve, se deshace y se rehace aquí**.
//
//  Vive en su propio fichero por dos razones y ninguna es de tamaño: (1) el estado que pinta lo decide
//  una tabla pura (`GroupsAssociationLogic.sectionState`) que se fija aparte, y (2) el gesto destructivo
//  tiene DOS salidas —conservar o quitar los movimientos del Panel, decisión de Jürgen del 2026-09-09— y
//  mezclarlas con las cuatro confirmaciones de la migración haría de `StorageConfirmations` un nudo.
//

import SwiftData
import SwiftUI

struct GroupsAssociationSection: View {

    /// Qué hace el CTA de asociar. Lo cablea `ProfileView`, que es quien puede cerrar su sheet: el sheet
    /// del sign-in de Grupos tiene **dueño único** (`GroupsBackendInviteModifier`, anclado en
    /// `ContentView`) y presentarlo encima de Ajustes sería un segundo anchor del mismo sheet, que es lo
    /// que el contrato de presentaciones prohíbe. Opcional para previews y para el resto de call-sites.
    var onAssociate: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences

    @State private var confirmDetach = false
    /// El aviso de bloqueo de ESTE gesto. **Propio y no el de `ProfileView`**: aquel dice «No pudimos
    /// cerrar tu sesión», que es otra cosa y en una secundaria llega a ofrecer salir de la sesión entera a
    /// quien solo pidió soltar una cuenta de grupos. Y sin él, `phase` se queda en `.blocked` y el toque
    /// siguiente cae en el `guard phase == .idle` de `detachGroupsAccount`: **no pasa nada, sin un solo
    /// mensaje**. Cerrarlo llama a `acknowledgeBlocked()`, que es lo que devuelve la fase a `.idle`.
    @State private var blockedReason: CloudSignOutFlowLogic.BlockReason?
    /// **El borrado local falló y la cuenta ya se cerró en la nube.** Aviso propio, separado del de
    /// bloqueo: aquél dice «no se soltó nada» y éste dice «se soltó todo menos lo que importa» —los
    /// grupos siguen aquí—. Y lo que ofrecen es distinto: aquél que lo intente en un momento, éste un
    /// reintento del borrado, que es lo único que queda por hacer. Ver `CloudSessionSignOut.DetachOutcome`.
    @State private var purgeFailed = false
    /// ¿Quedó un desasociar a medias **de la cuenta que sigue asociada aquí**? Estado DURABLE
    /// (`GroupsDetachPendingPurge`), no `@State`: la fase del coordinador muere con el proceso y esto no.
    /// Se re-lee con cada `refreshTick`, igual que el resto de la sección — y al montar, porque un
    /// computed se evalúa en cada evaluación del `body`.
    ///
    /// **Las dos condiciones de más son las que impiden terminar lo que no toca**: el sello por `sub`
    /// descarta una marca de otra cuenta o una asociación que ya no está, y la sesión viva **de esa misma
    /// cuenta** cancela el ofrecimiento —quien vuelve a entrar usa el gesto entero, que sí hace teardown
    /// y cierra la sesión; terminar a secas la dejaría dentro de una cuenta cuyos datos acaba de borrar—.
    /// Sin ellas, este botón salía también en `.sameAccountAsPersonal` y en `.noAccount` —dos celdas que
    /// por contrato no ofrecen soltar nada— y llegaba a purgar la cuenta en la que la persona acababa de
    /// entrar. Lo cazó la lente del 2026-09-11 sobre este mismo arreglo.
    private var hasPendingPurge: Bool {
        _ = refreshTick
        guard GroupsDetachPendingPurge.isArmed(for: GroupsAccountAssociation.shared.associatedSub) else {
            return false
        }
        return CloudAuthService.shared.currentUserID != GroupsDetachPendingPurge.armedSub()
    }
    /// Re-lee el estado tras cada gesto. La sesión en la nube NO es observable
    /// (`CloudAuthService` no publica nada), así que la pantalla se refresca por toques, igual que el
    /// resto de esta fila, que vive de un poll de 1 s.
    @State private var refreshTick = false

    private var signOutCoordinator: CloudSessionSignOut { CloudSessionSignOut.shared }

    /// **La lectura vive en `GroupsAssociationPresence` y no aquí, desde el 2026-09-11.** La fila de
    /// Ajustes que lleva a esta sección se abre bajo el kill-switch de la nube justo cuando esta sección
    /// tiene algo que soltar, así que las dos preguntas tienen que salir de la MISMA lectura: cuando cada
    /// una leía lo suyo, divergían en dos celdas y en las dos el usuario se quedaba sin puerta o con una
    /// puerta a nada. El porqué entero, en la cabecera de ese fichero.
    private var state: GroupsAssociationLogic.SectionState {
        _ = refreshTick
        return GroupsAssociationPresence.sectionState(
            hasCompletedOnboarding: appPreferences.hasCompletedOnboarding)
    }

    var body: some View {
        if state != .notApplicable {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // **El identifier va en el TÍTULO y no en el `VStack`.** Aplicado al contenedor pisa el
                // de todos sus hijos, y los botones de la sección dejan de existir con su propio id en el
                // árbol de accesibilidad: es la regla medida en `.claude/rules/testing.md`, y aquí costó
                // una corrida de XCUITest con tres rojos mudos.
                Text(L10n.Storage.Groups.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("storage_groups_section")

                Text(bodyText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .storageGroupsCardStyle()
            .confirmationDialog(
                L10n.Storage.Groups.detachTitle,
                isPresented: $confirmDetach,
                titleVisibility: .visible
            ) {
                // Las DOS salidas son botones de la MISMA hoja, y el orden no es casual: conservar va
                // primero porque es la que no destruye nada. Ninguna de las dos es `.destructive` a
                // secas — quitar sí lo es, conservar no lo es en absoluto.
                Button(L10n.Storage.Groups.detachKeep) { detach(.keep) }
                    .accessibilityIdentifier("storage_groups_detach_keep")
                Button(L10n.Storage.Groups.detachRemove, role: .destructive) { detach(.remove) }
                    .accessibilityIdentifier("storage_groups_detach_remove")
                Button(L10n.Common.cancel, role: .cancel) {}
                    .accessibilityIdentifier("storage_groups_detach_cancel")
            } message: {
                Text(L10n.Storage.Groups.detachBody)
            }
            .alert(
                L10n.Storage.Groups.detachBlockedTitle,
                isPresented: Binding(
                    get: { blockedReason != nil },
                    set: { if !$0 { dismissBlocked() } })
            ) {
                // Texto LITERAL en los botones del alert: un label que dependa del `@State` rompe flujos
                // de la app que no tienen nada que ver con esta pantalla (medido el 2026-09-06).
                Button(L10n.Common.ok) { dismissBlocked() }
            } message: {
                Text(blockedMessage)
            }
            // **Segundo alert de la misma cadena, y los dos no pueden encenderse a la vez**: el de arriba
            // sale de `.blocked`, que es un abort ANTES del punto de no retorno, y éste de `.purgeFailed`,
            // que solo existe después. El molde de encadenar alerts en un mismo anchor es el de
            // `ShellDataAlertsModifier`, que lleva cuatro.
            .alert(L10n.Storage.Groups.detachPurgeFailedTitle, isPresented: $purgeFailed) {
                // Labels LITERALES, igual que en el alert de arriba y por lo mismo: un label que dependa
                // del `@State` rompe flujos que no tienen nada que ver con esta pantalla (2026-09-06).
                //
                // **Y sin `accessibilityIdentifier`, a propósito**: SwiftUI NO lo propaga a los botones
                // del closure de un `.alert` — llegan al árbol con el id VACÍO (medido el 2026-09-04,
                // `docs/aprendizajes-tecnicos.md`). Dejarlo puesto es peor que no ponerlo: el siguiente
                // lo lee, da por hecho que la pantalla es targeteable por ahí, y escribe un
                // `XCTAssertFalse(…exists)` que pasa SIEMPRE. El XCUITest llega por posición
                // (`app.alerts.buttons.element(boundBy:)`), molde de `WelcomeFreshStartAlertUITests`.
                Button(L10n.Action.retry) { retryPurge() }
                Button(L10n.Action.later, role: .cancel) { purgeFailed = false }
            } message: {
                Text(L10n.Storage.Groups.detachPurgeFailedBody)
            }
        }
    }

    /// El aviso se cierra soltando TAMBIÉN la fase del coordinador. Si solo se bajara el `@State`, el
    /// `guard phase == .idle` dejaría inertes el desasociar Y el cierre de sesión de Ajustes.
    private func dismissBlocked() {
        // **Una sola vez por aviso** (review adversarial, 2026-09-15). Lo llaman el botón y el `set` del binding, y SwiftUI
        // escribe `false` al pulsar CUALQUIER botón: la segunda llamada llegaba con `blockedReason` ya a `nil`, leía «no
        // ajeno» y reconocía el bloqueo de un cierre de sesión que no era suyo.
        guard blockedReason != nil else { return }
        // `.detachBusy` es el ÚNICO motivo que NO puso este gesto: la fase es de un cierre de sesión
        // ajeno, y soltarla aquí lo dejaría a medias —sin fase y sin `blockedExit`— con sus dos botones
        // de «Esperar» / «Cerrar igualmente» saliendo por su `guard let` sin hacer nada.
        let ajeno = blockedReason == .detachBusy
        blockedReason = nil
        if !ajeno { signOutCoordinator.acknowledgeBlocked() }
    }

    /// **Exhaustivo a propósito: sin `default`.** Con uno, un motivo nuevo caía en «inténtalo en un
    /// momento» sin que nada lo dijera, que es exactamente cómo el canal en pausa acabó anunciándose como
    /// un problema de la cuenta. Aquí el compilador obliga a que cada motivo se pronuncie, y ninguna
    /// prueba puede dar esa garantía: el mapeo vive dentro de la vista.
    private var blockedMessage: String {
        switch blockedReason {
        case .sessionExpired: return L10n.Storage.Groups.detachBlockedSession
        case .permanent: return L10n.Storage.Groups.detachBlockedPermanent
        case .bridgeUnreadable: return L10n.Storage.Groups.detachBlockedBridge
        case .detachBusy: return L10n.Storage.Groups.detachBusy
        // El kill-switch de Grupos no es un problema de la cuenta ni de la conexión, y `.permanent` le
        // decía las dos cosas. Copy compartido con el cierre de sesión: el hecho es el mismo y el título
        // de arriba ya dice cuál de los dos gestos falló.
        case .channelPaused: return L10n.Groups.Errors.channelPaused
        // El teléfono sin App Attest (2026-09-15): «inténtalo en un momento» dejó de ser verdad. Aquí va el texto SIN
        // salida, y es la decisión de Jürgen: el desasociar no ofrece soltar la cuenta perdiendo los cambios
        // (`CloudSessionSignOut.detachGroupsAccount` le pasa `lossExit: nil`). El título ya dice qué gesto falló.
        case .attestUnavailable: return L10n.Groups.Errors.attestUnavailable
        // **La subida que no llegó al servidor** (2026-09-16). Desde que `classify` separa las dos mitades de
        // lo pasajero, este gesto también lo recibe: sin red, con un 5xx o con un cortafuegos delante. Antes
        // caía en el texto de abajo, que dice «inténtalo de nuevo en un momento» —un momento no basta cuando
        // no hay cobertura— y no cuenta lo único que tranquiliza, que los cambios siguen en el teléfono.
        // Copy compartido con el cierre de sesión: el hecho es el mismo y el título de arriba ya dice cuál de
        // los dos gestos falló, igual que con el canal en pausa.
        case .uploadRetryLater: return L10n.Groups.Errors.uploadRetryLater
        // `.transient` es el caso corriente, y desde el 2026-09-16 es SOLO el outbox que aún drena: aquí
        // «inténtalo de nuevo en un momento» es exacto. `.exportUnconfirmed` es del cierre PRIVADO y no puede
        // llegar a este gesto —el desasociar no espera a iCloud—, y `nil` tampoco con el aviso presentado (el
        // binding lo enciende justo con el motivo puesto); los dos caen en el copy que no afirma ninguna
        // causa concreta, que es lo correcto si alguna vez llegaran.
        // `.personalAttestUnavailable` tampoco llega: lo pone solo el paso 1 del cierre en la NUBE, sobre el outbox personal,
        // y el desasociar no sube nada personal (2026-09-15). Los tres del motor parado, igual (2026-09-25): solo los pone ese
        // mismo paso 1, y la subida personal que no llegó también.
        case .transient, .exportUnconfirmed, .personalAttestUnavailable, .syncStoppedNeedsUpdate, .syncStoppedMidMigration,
             .syncStoppedNeedsRelaunch, .personalUploadRetryLater, .none:
            return L10n.Storage.Groups.detachBlockedTransient
        }
    }

    // MARK: - Cuerpo

    private var bodyText: String {
        // El estado a medias gana al de la celda: la persona ya no está eligiendo cuenta, está esperando
        // a que termine un gesto suyo. Y decirlo es la única forma de que se entere quien pulsó «Más
        // tarde» y volvió otro día: el aviso no sobrevive a salir de la pantalla.
        if hasPendingPurge { return L10n.Storage.Groups.detachPendingBody }
        switch state {
        case .noAccount:
            return L10n.Storage.Groups.noAccountBody
        case .associated:
            guard let cuenta = accountDisplayName else { return L10n.Storage.Groups.associatedUnnamedBody }
            return L10n.Storage.Groups.associatedBody(cuenta)
        case .associatedNeedsSignIn:
            guard let cuenta = accountDisplayName else { return L10n.Storage.Groups.needsSignInUnnamedBody }
            return L10n.Storage.Groups.needsSignInBody(cuenta)
        case .sameAccountAsPersonal:
            return L10n.Storage.Groups.sameAccountBody
        case .notApplicable:
            return ""
        }
    }

    /// Cómo se nombra la cuenta, o `nil` si no hay con qué. **Nunca se inventa un correo**: ver
    /// `GroupsAssociationLogic.DisplayName`.
    ///
    /// Devuelve el NOMBRE y no aplica la plantilla, aunque eso obligue a repetir el `guard` en los dos
    /// casos que la usan: pasar `L10n.Storage.Groups.associatedBody` como valor de primera clase convierte
    /// una función aislada al `MainActor` en un closure, y eso deja un warning de aislamiento en cada
    /// call-site.
    private var accountDisplayName: String? {
        let record = GroupsAccountAssociation.shared.read()
        switch GroupsAssociationLogic.displayName(
            email: record?.email ?? CloudAuthService.shared.capturedEmail(),
            provider: record?.provider ?? CloudAuthService.shared.storedProvider()
        ) {
        case .email(let correo):
            return correo
        case .provider(let metodo):
            return metodo == .apple
                ? L10n.Settings.yalaAccountMethodApple
                : L10n.Settings.yalaAccountMethodGoogle
        case .unnamed:
            return nil
        }
    }

    // MARK: - Acciones

    @ViewBuilder
    private var actions: some View {
        if isWorking {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                Text(signOutCoordinator.waitingForPending
                     ? L10n.Storage.Groups.detachWaiting
                     : L10n.Storage.Groups.detachWorking)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("storage_groups_working")
        } else {
            if GroupsAssociationLogic.offersAssociate(state), let onAssociate {
                Button(action: onAssociate) {
                    Text(L10n.Storage.Groups.associateButton)
                        .font(DS.Typography.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("storage_groups_associate_button")
            }
            if state == .associatedNeedsSignIn, let onAssociate {
                // La sesión no viajó, la asociación sí: entrar es el MISMO gesto que asociar (pasa por
                // [I] con la cuenta que ya está registrada), así que no hay un camino nuevo que probar.
                Button(action: onAssociate) {
                    Text(L10n.Storage.Groups.signInButton)
                        .font(DS.Typography.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("storage_groups_signin_button")
            }
            if hasPendingPurge {
                // **Sin hoja de confirmación, y es lo que distingue TERMINAR de repetir.** El puente ya
                // se soltó con la salida que la persona eligió; volver a preguntárselo ofrecería una
                // elección que ya no puede aplicarse —un `.remove` no encontraría nada que quitar y el
                // gesto diría que sí—. Lo cazaron las tres lentes del 2026-09-11.
                Button {
                    retryPurge()
                } label: {
                    Text(L10n.Storage.Groups.detachFinishButton)
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(DS.Semantic.warningForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(DS.Semantic.warningForeground)
                .accessibilityIdentifier("storage_groups_detach_finish_button")
            } else if GroupsAssociationLogic.offersDetach(state) {
                Button {
                    confirmDetach = true
                } label: {
                    Text(L10n.Storage.Groups.detachButton)
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(DS.Semantic.warningForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(DS.Semantic.warningForeground)
                .accessibilityIdentifier("storage_groups_detach_button")
            }
        }
    }

    /// `phase` es del coordinador, que también lleva el cierre de sesión: un cierre en curso pintaría
    /// «Desasociando…» aquí. `detachInFlight` acota el spinner a NUESTRO gesto.
    @State private var detachInFlight = false

    private var isWorking: Bool { detachInFlight && signOutCoordinator.phase == .working }

    /// **El veredicto viene por el RETORNO, no de leer la fase.** Un `.purgeFailed` deja el coordinador
    /// en `.idle` —es verdad: no está haciendo nada— así que mirar `phase` no lo distinguiría del éxito.
    /// Es exactamente la confusión que este ticket arregla, y leerla aquí la reintroduciría en la única
    /// pantalla que la sufre.
    private func detach(_ choice: GroupsAssociationDetach.BridgedRowsChoice) {
        detachInFlight = true
        Task { @MainActor in
            defer { detachInFlight = false }
            apply(await signOutCoordinator.detachGroupsAccount(context: modelContext, choice: choice))
        }
    }

    /// Terminar el borrado que quedó pendiente. **No repite el gesto**: ver
    /// `CloudSessionSignOut.retryDetachPurge`.
    private func retryPurge() {
        detachInFlight = true
        Task { @MainActor in
            defer { detachInFlight = false }
            apply(await signOutCoordinator.retryDetachPurge(context: modelContext))
        }
    }

    private func apply(_ outcome: CloudSessionSignOut.DetachOutcome) {
        switch outcome {
        case .blockedBeforeWriting:
            // La fase se lee DESPUÉS del `await`, que es cuando el coordinador ya la dejó puesta.
            if case .blocked(_, let reason) = signOutCoordinator.phase { blockedReason = reason }
        case .purgeFailed:
            purgeFailed = true
        case .busy:
            // **No se traga, y ése es exactamente el defecto que el alert de bloqueo existe para
            // cerrar.** El coordinador estaba ocupado con el cierre de sesión del Perfil: la persona
            // confirmaba y no pasaba absolutamente nada.
            //
            // Motivo PROPIO y no `.transient`, por lo mismo que `.bridgeUnreadable`: aquí no queda nada
            // sin subir —el gesto ni siquiera arrancó— así que «inténtalo en un momento» describe otro
            // problema. Y su cierre **no toca la fase del coordinador**: la puso un gesto ajeno, y
            // `acknowledgeBlocked()` le borraría además el `blockedExit`, que es lo que recuerda dónde
            // retomar un cierre parado en la espera del export.
            blockedReason = .detachBusy
        case .detached:
            break
        }
        refreshTick.toggle()
    }
}

// MARK: - Estilo

private extension View {
    /// Mismo estilo que las cards de esta pantalla. Duplicado del `storageCardStyle` de
    /// `StorageSettingsView`, que es `fileprivate` allí; unificarlo movería un helper de estilo a un
    /// tercer sitio sin que nadie más lo pida.
    func storageGroupsCardStyle() -> some View {
        self
            .padding(DS.Spacing.lg)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .padding(.horizontal, DS.Spacing.lg)
    }
}
