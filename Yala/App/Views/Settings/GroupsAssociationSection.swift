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
//  **Desde el 2026-11-11 (G1 de la revisión 2.3, decisión 55)**, con una cuenta que se puede soltar la sección deja de ser
//  la tarjeta «Grupos» con «Desasociar» en naranja encima de «Activar la nube»: es una fila de datos —«Tu cuenta de Yala»,
//  con qué se entra y el correo, «La usan tus grupos»— y un enlace «Cambiar de cuenta». El enlace abre la hoja de
//  consecuencias (`GroupsDetachSheet`, decisión 59), igual que el botón del aviso de bloqueo, que la pide por
//  `changeAccountRequest`. La hoja no se salta nunca: soltar la cuenta mueve datos de grupos.
//

import SwiftData
import SwiftUI

struct GroupsAssociationSection: View {

    /// Qué hace el CTA de asociar. Lo cablea `ProfileView`, que es quien puede cerrar su sheet: el sheet
    /// del sign-in de Grupos tiene **dueño único** (`GroupsBackendInviteModifier`, anclado en
    /// `ContentView`) y presentarlo encima de Ajustes sería un segundo anchor del mismo sheet, que es lo
    /// que el contrato de presentaciones prohíbe. Opcional para previews y para el resto de call-sites.
    var onAssociate: (() -> Void)?
    /// Sube cada vez que el aviso de bloqueo de «Activar la nube» pide «Cambiar de cuenta» (G1). La sección abre su hoja de
    /// consecuencias, la misma del enlace: un solo dueño de esa presentación. Un contador y no un `Binding`: la pantalla no
    /// necesita saber cuándo se cierra, y un valor que solo sube no se queda «pedido» si la sección no estaba montada.
    var changeAccountRequest: Int = 0

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences

    /// La hoja de consecuencias abierta, con la cifra de lo que «Dejar en mis cuentas lo que pagué» dejaría (L19-14), leída
    /// al pedirla. `.sheet(item:)` y no `isPresented` con la cifra en otro `@State`: así la hoja nunca sale vacía
    /// (`.claude/rules/swiftui-ds.md`).
    @State private var detachSheet: DetachSheetRequest?
    /// La salida elegida en la hoja. Se aplica en su `onDismiss`, con la hoja ya abajo: el aviso de bloqueo o de borrado que
    /// pueda salir después no choca con una hoja bajando en el mismo anchor.
    @State private var chosenDetach: GroupsAssociationDetach.BridgedRowsChoice?
    /// El aviso de bloqueo de ESTE gesto. **Propio y no el de `ProfileView`**: aquel dice «No pudimos
    /// cerrar tu sesión», que es otra cosa y en una secundaria llega a ofrecer salir de la sesión entera a
    /// quien solo pidió soltar una cuenta de grupos. **El motivo llega por el retorno del gesto, y cerrar el
    /// aviso no toca la fase del coordinador** (2026-10-02, ticket
    /// `detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait`): el coordinador ya la devolvió a
    /// `.idle` al bloquear. Hasta ese día la soltaba este aviso, y con la hoja cerrada a mitad de la espera no salía
    /// nunca: la fase se quedaba en `.blocked` y «Cerrar sesión» y el desasociar siguiente no hacían nada.
    ///
    /// **Es el aviso entero y no solo el motivo** (2026-10-05): con la captura de grupos atascada y la sesión caducada, sin
    /// App Attest o con cambios de otra cuenta, nombra las dos causas (`CloudSignOutFlowLogic.DetachBlockedNotice`).
    @State private var blockedNotice: CloudSignOutFlowLogic.DetachBlockedNotice?
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
    /// El canal de Grupos salió apagado al tocar «Asociar» / «Entrar». Alerta con el copy que ya existe para
    /// este hecho en la puerta del tab (`welcome.groups.channelOff*`): es transitorio, es cosa nuestra y no
    /// se guardó nada.
    @State private var showChannelOff = false
    /// La comprobación del canal que lanzó el último toque. Mientras corre, el botón no acepta otro (dos
    /// toques serían dos intents de sign-in), y si la sección se va antes de que termine se cancela: un
    /// sign-in que aparece cuando la persona ya se fue de Ajustes no lo pidió nadie.
    @State private var channelCheck: Task<Void, Never>?

    /// El canal de Grupos, COMPUESTO (compilado && kill remoto): asociar o entrar son ENTRADAS al canal, y
    /// las entradas leen el compuesto (`CloudSyncFlags.groupsBackendEnabled`, su docblock). Se re-lee con
    /// cada `refreshTick`, como el resto de la sección.
    private var channelOn: Bool {
        _ = refreshTick
        return CloudSyncFlags.groupsBackendEnabled
    }

    private var signInEntry: GroupsAssociationLogic.SignInEntry {
        GroupsAssociationLogic.signInEntry(state, channelOn: channelOn)
    }

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
                if showsAccountRow {
                    accountRow
                } else {
                    Text(L10n.Storage.Groups.title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("storage_groups_section")

                    Text(bodyText)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .storageGroupsCardStyle()
            // Las DOS salidas en la MISMA hoja, cada una con su consecuencia debajo y lo común arriba (decisión 59). Hasta el
            // 2026-11-11 era un `confirmationDialog` con la diferencia en un párrafo. La hoja es pura: devuelve la elección
            // y el gesto corre aquí, al cerrarse.
            .sheet(item: $detachSheet, onDismiss: applyChosenDetach) { request in
                GroupsDetachSheet(
                    keepCountLine: request.keepCountLine,
                    onChoose: { choice in
                        chosenDetach = choice
                        detachSheet = nil
                    },
                    onCancel: { detachSheet = nil })
            }
            .onChange(of: changeAccountRequest) { _, _ in openDetachSheet() }
            .alert(
                L10n.Storage.Groups.detachBlockedTitle,
                isPresented: Binding(
                    get: { blockedNotice != nil },
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
            // Tercer alert de la cadena, y tampoco coincide con los otros dos: sale de un toque en «Asociar» /
            // «Entrar», y esos botones no conviven con un desasociar en vuelo.
            .alert(L10n.Welcome.Groups.channelOffTitle, isPresented: $showChannelOff) {
                Button(L10n.Common.ok) { showChannelOff = false }
            } message: {
                Text(L10n.Welcome.Groups.channelOffBody)
            }
            // **Con la sección en pausa, se pregunta al servidor una vez al montar.** El snapshot del kill puede
            // tener hasta 6 h y sin botón no hay toque que fuerce el refresco: sin esto, un canal ya reencendido
            // seguiría diciendo «en pausa» hasta el siguiente refresco del arranque. Bajo `-uitest` no se toca
            // red, igual que en el tab.
            .task(id: signInEntry == .channelPaused) {
                guard signInEntry == .channelPaused, !SwiftDataConfiguration.isUITesting else { return }
                await RemoteConfigClient.shared.refreshIfDue(force: true)
                guard !Task.isCancelled else { return }
                refreshTick.toggle()
            }
            .onDisappear { channelCheck?.cancel() }
        }
    }

    /// El aviso se cierra bajando SOLO su `@State`. **No llama a `acknowledgeBlocked()`, y es a propósito**: el
    /// desasociar ya no deja la fase en `.blocked` (`CloudSessionSignOut.releaseDetachBlock`), así que la fase que
    /// encontrara aquí sería la de un cierre de sesión ajeno, y reconocerla le borraría además el `blockedExit` —lo que
    /// recuerda dónde retomarlo—, con sus botones de «Esperar» / «Cerrar igualmente» saliendo sin hacer nada. Es lo que ya
    /// pasaba con `.detachBusy` y lo que la review del 2026-09-15 cazó en el doble cierre del binding.
    private func dismissBlocked() {
        blockedNotice = nil
    }

    /// El texto lo decide `SignOutBlockedCopy.detachBlockedMessage(for:)`, la misma tabla que Ajustes y el Welcome, para
    /// que un test pueda recorrerlo (ticket `blocked-copy-mapping-lives-in-three-views-untestable`).
    private var blockedMessage: String {
        SignOutBlockedCopy.detachBlockedMessage(for: blockedNotice)
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

    // MARK: - La fila de la cuenta (G1)

    /// Con una cuenta que se puede soltar, y nada a medias, la sección es la fila de la cuenta. Con un soltar a medias
    /// sigue diciendo que quedó a medias: ahí la persona no está eligiendo cuenta.
    private var showsAccountRow: Bool {
        GroupsAssociationLogic.offersDetach(state) && !hasPendingPurge
    }

    /// «Tu cuenta de Yala» · «Apple · correo» · «La usan tus grupos». El id de la sección va en el rótulo, como iba en el
    /// título: en el contenedor pisaría el de los botones.
    private var accountRow: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Settings.yalaAccountRowTitle)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("storage_groups_section")
            if let accountLine {
                Text(accountLine)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("storage_groups_account")
            }
            Text(L10n.Storage.Groups.usedByGroups)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("storage_groups_used_by")
        }
    }

    /// Con qué se entra y el correo. Lee lo mismo que `accountDisplayName`: el registro de la asociación y, si falta, lo
    /// capturado al firmar. **Nunca se inventa un correo.**
    private var accountLine: String? {
        let record = GroupsAccountAssociation.shared.read()
        return GroupsAssociationLogic.accountLine(
            email: record?.email ?? CloudAuthService.shared.capturedEmail(),
            provider: record?.provider ?? CloudAuthService.shared.storedProvider())
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
            switch signInEntry {
            case .associate:
                if onAssociate != nil {
                    Button(action: requestSignIn) {
                        Text(L10n.Storage.Groups.associateButton)
                            .font(DS.Typography.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .disabled(channelCheck != nil)
                    .accessibilityIdentifier("storage_groups_associate_button")
                }
            case .signIn:
                if onAssociate != nil {
                    // La sesión no viajó, la asociación sí: entrar es el MISMO gesto que asociar (pasa por
                    // [I] con la cuenta que ya está registrada), así que no hay un camino nuevo que probar.
                    Button(action: requestSignIn) {
                        Text(L10n.Storage.Groups.signInButton)
                            .font(DS.Typography.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .disabled(channelCheck != nil)
                    .accessibilityIdentifier("storage_groups_signin_button")
                }
            case .channelPaused:
                // Sin botón: con el canal matado, el sign-in sería real contra un backend en pausa. Se dice
                // por qué en vez de dejar un hueco donde estaba el botón.
                Text(L10n.Storage.Groups.channelPausedNote)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("storage_groups_channel_paused_note")
            case .none:
                EmptyView()
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
                // G1: un enlace y no un botón relleno. Lo que la persona vino a hacer a esta pantalla es «Activar la nube»;
                // cambiar la cuenta de sus grupos es la excepción, y abre la hoja de consecuencias antes de soltar nada.
                Button(action: openDetachSheet) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(L10n.Storage.Groups.changeAccount)
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .font(DS.Typography.subheadline.weight(.medium))
                    .foregroundStyle(.thAccentText)
                    .padding(.vertical, DS.Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("storage_groups_change_account")
            }
        }
    }

    /// `phase` es del coordinador, que también lleva el cierre de sesión: un cierre en curso pintaría
    /// «Desasociando…» aquí. `isDetaching` acota el spinner al desasociar. **Lo lleva el coordinador y no un `@State`
    /// de esta vista** (2026-10-02): la hoja puede cerrarse y reabrirse a mitad de la espera, y la sección nueva no
    /// heredaba el `@State` de la que lanzó el gesto — sin spinner, un toque en «Desasociar» chocaba con el gesto en
    /// vuelo y decía «Estás cerrando sesión».
    private var isWorking: Bool { signOutCoordinator.isDetaching }

    /// **El veredicto viene por el RETORNO, no de leer la fase.** Un `.purgeFailed` deja el coordinador
    /// en `.idle` —es verdad: no está haciendo nada— así que mirar `phase` no lo distinguiría del éxito.
    /// Es exactamente la confusión que este ticket arregla, y leerla aquí la reintroduciría en la única
    /// pantalla que la sufre.
    /// La consecuencia de conservar con su cifra: «Los gastos que pagaste se quedan en tus cuentas como registros normales:
    /// 12 (S/ 840.00)». `nil` sin gastos que conservar o sin poder leerlos: la hoja la dice sin cifra.
    private func keepCountLine(_ preview: GroupsAssociationDetach.KeepPreview?) -> String? {
        guard let preview, preview.expenseCount > 0 else { return nil }
        let amounts = GroupDebtCopyLogic.amounts(
            preview.amountsByCurrency.map { ($0.value, $0.key) },
            money: { appPreferences.currency($0, currencyCode: $1) })
        return L10n.Storage.Groups.changeAccountKeepEffectCount(preview.expenseCount, amounts)
    }

    /// Abre la hoja de consecuencias, desde el enlace o desde el aviso de bloqueo. **Solo si la sección ofrece soltar en
    /// este instante**: entre el aviso y su cierre pudo empezar otro soltar, o quedar uno a medias, y entonces la hoja
    /// ofrecería una elección que ya no puede aplicarse.
    private func openDetachSheet() {
        guard GroupsAssociationLogic.offersDetach(state), !hasPendingPurge, !isWorking, detachSheet == nil else { return }
        detachSheet = DetachSheetRequest(
            keepCountLine: keepCountLine(GroupsAssociationDetach.keepPreview(context: modelContext)))
    }

    /// `onDismiss` de la hoja: corre la salida elegida, si hubo. Cancelar o arrastrarla abajo no suelta nada.
    private func applyChosenDetach() {
        guard let choice = chosenDetach else { return }
        chosenDetach = nil
        Task { @MainActor in
            apply(await signOutCoordinator.detachGroupsAccount(context: modelContext, choice: choice))
        }
    }

    /// ¿La pantalla puede soltar la cuenta de grupos AHORA? Lo pregunta el aviso de bloqueo de «Activar la nube» antes de
    /// ofrecer «Cambiar de cuenta» (`MigrationBlockChangeAccountLogic`). Las mismas tres condiciones que `openDetachSheet`.
    static func canReleaseGroupsAccount(hasCompletedOnboarding: Bool) -> Bool {
        let state = GroupsAssociationPresence.sectionState(hasCompletedOnboarding: hasCompletedOnboarding)
        guard GroupsAssociationLogic.offersDetach(state) else { return false }
        guard !CloudSessionSignOut.shared.isDetaching else { return false }
        let pending = GroupsDetachPendingPurge.isArmed(for: GroupsAccountAssociation.shared.associatedSub)
            && CloudAuthService.shared.currentUserID != GroupsDetachPendingPurge.armedSub()
        return !pending
    }

    /// «Asociar» / «Entrar»: **el canal se re-mide al tocar, y el refresco va ANTES de leer el flag.** El
    /// snapshot del kill puede tener hasta 6 h, así que el botón pudo pintarse con un canal que ya no existe;
    /// es la regla de `GroupsContainerView.requestCreateGroup` («la intención del usuario es evidencia»). Con el
    /// canal encendido sigue el camino de siempre (`onAssociate`, que cierra la hoja y emite el intent); apagado,
    /// no se emite nada, se dice por qué y la sección pasa a la nota de pausa.
    ///
    /// El gate vive AQUÍ y no en el drenado de `.presentGroupsSignIn` (`ContentView`): cada productor de ese
    /// intent decide con el flag antes de emitirlo, y un drenado que lo descartara en silencio dejaría sin
    /// respuesta un toque y sin salida los flujos ya abiertos que lo re-emiten.
    private func requestSignIn() {
        guard let onAssociate, channelCheck == nil else { return }
        channelCheck = Task { @MainActor in
            defer { channelCheck = nil }
            // Hermeticidad: bajo `-uitest` no se toca red; el getter devuelve su default (ON en `Yala Dev`).
            if !SwiftDataConfiguration.isUITesting {
                await RemoteConfigClient.shared.refreshIfDue(force: true)
            }
            guard !Task.isCancelled else { return }
            if CloudSyncFlags.groupsBackendEnabled {
                onAssociate()
            } else {
                DS.Haptic.error()
                showChannelOff = true
            }
            refreshTick.toggle()
        }
    }

    /// Terminar el borrado que quedó pendiente. **No repite el gesto**: ver
    /// `CloudSessionSignOut.retryDetachPurge`.
    private func retryPurge() {
        Task { @MainActor in
            apply(await signOutCoordinator.retryDetachPurge(context: modelContext))
        }
    }

    private func apply(_ outcome: CloudSessionSignOut.DetachOutcome) {
        switch outcome {
        case .blockedBeforeWriting(let notice):
            // **El motivo del RETORNO, no de la fase**: el coordinador ya la devolvió a `.idle`. Si esta sección se
            // desmontó a mitad de la espera, la escritura cae en un `@State` muerto y el aviso de ESTE intento no sale
            // —nadie lo está mirando—, pero ya no deja nada cogido: reintentar vuelve a decir el motivo.
            blockedNotice = notice
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
            blockedNotice = .reason(.detachBusy)
        case .detached:
            break
        }
        refreshTick.toggle()
    }
}

/// Lo que la hoja de consecuencias enseña, fijado al pedirla.
private struct DetachSheetRequest: Identifiable {
    let id = UUID()
    let keepCountLine: String?
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
