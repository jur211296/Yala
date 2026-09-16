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
//  ## La vuelta al neutro (2026-09-11, mitad 2 del paso 5 del rediseño)
//
//  Hasta hoy esta pantalla tenía una tercera razón para BLOQUEAR —«Aquí ya hay datos guardados»— con un
//  único botón «Volver» y un copy que invitaba a «crear el grupo desde la app que ya usas», que es ÉSTA.
//  Jürgen la midió en su móvil el 2026-09-09 sobre su propio corpus. Ahora esa rama no bloquea: **devuelve
//  el dispositivo al neutro y sigue.**
//
//  **Quien borra es el cierre de sesión privado, y eso es el chip entero.** El paso 9 construyó el verbo
//  que esta puerta llevaba esperando —esperar a que lo último llegue a iCloud, borrar por ARCHIVOS antes
//  del mount y dejar el contenedor intacto— y lo que aquí se hace es CONSUMIRLO, no reimplementarlo: la
//  sesión previa (2026-09-10) intentó llamar a `armSignOutWipe()` por su cuenta y la review midió que el
//  boot-wipe declara tres precondiciones («el coordinador ya subió el outbox, cerró la sesión y armó») que
//  un call-site suelto no cumple. Entrando por `CloudSessionSignOut.signOut(...)` las cumple las tres, y
//  además hereda sus redes: el bloqueo si quedara outbox de grupos, la salida avisada si la espera se
//  agota, y el desarme del arm si el borrado aborta en `.icloud`.
//
//  **La celda se MIDE, no se supone.** En el Welcome lo normal es `.privateSignOut` —sin sesión en la nube
//  y CON sesión privada, con el modo en `.icloud`— y con `kind == .privateOnly` el tramo no sube grupos. Pero
//  las otras dos celdas por archivos son alcanzables (una sesión de nube que sobrevive en el Keychain, un
//  dispositivo que ya venía en solo-grupos) y las dos son correctas aquí: suben los grupos antes de borrar.
//  La que NO lo es —el cierre de la nube— hace otro borrado, así que la puerta lo mide
//  ANTES y enseña una pantalla con salida en vez de arrancar.
//
//  **Lo que se lleva el store de Grupos, dicho con precisión:** `forgetsGroups = kind.pushesGroups ||
//  hasBackendGroupRows(context:)`, así que con `.privateOnly` el marker `includesGroups` **se pone si hay
//  filas del canal backend en el store** — y `hasBackendGroupRows` devuelve `true` ante un error de fetch,
//  a propósito. O sea que «el store de Grupos sobrevive» es cierto solo cuando no hay nada del backend
//  dentro. Es la semántica del cierre privado del paso 9 y no se toca aquí: cambiarla sería una segunda
//  verdad frente a Ajustes.
//
//  **Se informa, no se pregunta** (decisión de Jürgen en el ticket padre) — con una excepción que su
//  propia premisa impone: informar dice «tus datos personales siguen a salvo en iCloud», y eso solo es
//  cierto si hay copia. Cuando `privateCopyChannel()` dice `.none` —y solo dice `.none` **con prueba**,
//  que es el hallazgo nº 7 de la review del paso 9— se pide un segundo gesto antes de borrar.
//
//  **El terminal «reabre Yala» lo pinta el cover del cierre de sesión, no este step.** `WelcomeFlowModifier`
//  y `SignOutRelaunchNetModifier` están encadenados sobre el mismo body de `ContentView`, así que UIKit
//  presenta uno solo; el del cierre ya tiene verify loop con prueba de presentación efectiva, blocker de
//  readiness y salida automática en segundo plano, todo device-validado. Por eso al llegar a
//  `.awaitingRelaunch` este step avisa (`onNeutralReturnArmed`) y `ContentView` cierra el Welcome.
//

import SwiftData
import SwiftUI

struct WelcomeGroupsGateView: View {

    /// **A QUÉ vino quien está delante**, y lo decide TODO lo que esta pantalla hace distinto en cada
    /// caso: qué puerta se consulta, si se informa o se pregunta, y a dónde se sale al abrir.
    ///
    /// Las dos comparten el motor —la celda de cierre, la espera del export, el bloqueo por grupos sin
    /// subir, el terminal «reabre Yala»— y **ésa es la razón de que sea un propósito y no una vista
    /// hermana**: son el mismo borrado, y dos implementaciones serían dos verdades sobre él.
    enum Purpose: Equatable {
        /// G3 · «Crear mi primer grupo» desde el Welcome. Puerta: `GroupsOrganizerGateLogic`. Se INFORMA y
        /// se arranca, porque la persona acaba de tapear la card y esta pantalla es la respuesta a su gesto.
        case createGroup
        /// La invitación aceptada sobre un teléfono que espeja iCloud. Puerta:
        /// `GroupInviteNeutralGateLogic`. Se PREGUNTA, porque aquí puede no haber ningún gesto detrás — el
        /// reconciler llama a `drive` también en el trigger `.boot`, y el ADR 2026-09-09 prohíbe borrar el
        /// corpus de alguien en un arranque sin que nadie mire.
        case acceptInvite(groupID: String)

        /// El `groupID` de la invitación, o `nil` en la rama del organizador.
        var invitedGroupID: String? {
            if case .acceptInvite(let groupID) = self { return groupID }
            return nil
        }
    }

    /// Ver `Purpose`. Sin valor por defecto a propósito: un default sería `.createGroup` y un call-site
    /// nuevo del invitado heredaría en silencio el «informa y borra» que esta rama NO puede hacer.
    let purpose: Purpose
    /// Fetch VIVO del corpus local, no un snapshot: es el mismo argumento (y el mismo closure) que el
    /// guard cross-cuenta del Welcome usa, porque el mirror de iCloud puede estar re-importando mientras
    /// el usuario mira estas pantallas.
    let hasLocalDataNow: @MainActor @Sendable () -> Bool
    /// La puerta abrió. En `.createGroup`, seguir a `leaveWelcome(to: .groupsOrganizer)`; en
    /// `.acceptInvite`, cerrar el Welcome y retomar el join donde estaba.
    var onProceed: () -> Void
    /// Vuelta al step de los dos caminos. También es el CTA de las dos pantallas de bloqueo — «vuelve al
    /// chooser con todas las demás vías intactas», que es la mitad de «ningún camino muerto».
    var onBack: () -> Void
    /// La vuelta al neutro llegó a su terminal: el borrado está ARMADO y solo falta reabrir la app.
    /// `ContentView` persiste el destino para retomar esta misma puerta tras el arranque y cierra el
    /// Welcome, para que el cover del cierre de sesión pueda presentarse.
    var onNeutralReturnArmed: () -> Void

    /// El `mainContext`. Lo consume `CloudSessionSignOut`, que es quien sabe qué hacer con él; aquí no se
    /// lee ni se escribe ni una fila. Se toma del environment en vez de inyectarse desde `ContentView`
    /// —como sí hace el borrado de la puerta privada— porque allí había lógica que repartir (qué se borra
    /// de iCloud y qué del store) y aquí no: son tres llamadas al mismo coordinador con el mismo contexto.
    @Environment(\.modelContext) private var modelContext

    @State private var phase: Phase = .checking

    /// El `intento` de las tres fases de trabajo **no es decorativo**: `.task(id:)` solo re-arranca cuando el
    /// id CAMBIA, y los dos botones del aviso de espera agotada se pueden tocar más de una vez —el cierre
    /// vuelve a bloquear si la espera se agota otra vez, o si aparecieron más cambios—. Sin él, el segundo
    /// tap del mismo botón asigna el mismo valor, la task no se relanza y el botón parece roto; y el primero
    /// en morir es «Esperar», que es el que NO destruye.
    private enum Phase: Equatable {
        case checking
        case blockedChannelOff
        /// Sin copia en iCloud **con prueba**: segundo gesto antes de borrar.
        case confirmingNoBackup
        /// **La pregunta del invitado** (`purpose == .acceptInvite`). Un solo gesto que cubre los dos
        /// hechos: qué va a pasar con este teléfono y si hay copia en iCloud a la que apuntar. Se decidió
        /// así —y no encadenando `confirmingNoBackup` detrás— porque dos preguntas seguidas para un solo
        /// borrado leen como un trámite, y la segunda acabaría contestándose sin leerse.
        case confirmingInviteNeutral(withoutICloudCopy: Bool)
        /// **Este arranque no puede volver al neutro por el cierre privado**: su celda no es una de las tres
        /// que borran por archivos. Pantalla con salida, y CERO escrituras — lo contrario del `return` mudo
        /// que dejaba un progreso eterno sin botón.
        case unavailable
        /// El cierre privado en marcha. El detalle de lo que se ve lo dice `CloudSessionSignOut.phase`.
        case returningToNeutral(withoutICloudCopy: Bool, intento: Int)
        /// «Continuar igualmente» tras agotarse la espera del export.
        case discardingUnconfirmed(intento: Int)
        /// «Esperar»: el cierre retoma la espera donde se paró.
        case resumingExportWait(intento: Int)
        /// «Continuar y perderlos»: el teléfono lleva más de un día sin App Attest y la persona acepta perder los cambios
        /// de grupos que no suben (2026-09-15, `CloudSessionSignOut.exitDiscardingUnsyncedGroups`).
        case discardingUnsyncedGroups(intento: Int)
    }

    /// Cuántas veces se ha vuelto a lanzar el trabajo. Vive fuera de `Phase` porque es lo que la hace
    /// distinta de sí misma, no un dato de la pantalla.
    @State private var intento = 0

    /// La fase del coordinador. Se lee en el `body` para que `@Observable` la rastree.
    private var exitPhase: CloudSessionSignOut.Phase { CloudSessionSignOut.shared.phase }

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

                content

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        // **El «volver» desaparece mientras la vuelta al neutro está en vuelo** (`nil` no pinta el botón).
        // Irse a mitad cancelaría el `.task` y dejaría al coordinador en una fase que nadie atiende, con
        // el `guard phase == .idle` de `signOut` cerrándole la puerta al siguiente intento. Antes de
        // arrancar sí hay marcha atrás, y en los dos avisos con salida también.
        .welcomeBackButton(tint: .white, action: backAction)
        // **La FASE conduce**, como en la puerta privada: `id: phase` da cancelación real al desmontar el
        // step, y los botones solo cambian de fase en vez de lanzar `Task { }` sueltos.
        .task(id: phase) { await runPhase() }
        // El arm es la última escritura del cierre y va pegada a `.awaitingRelaunch`, sin `await` en medio.
        // `initial: true` **no es cinturón**: sin él, un step que se montara con el coordinador YA en su fase
        // terminal no avisaría nunca, el Welcome no se cerraría y el cover que cuenta el relanzamiento no
        // podría presentarse — un solo cover por body. El aviso es idempotente aguas abajo (persistir el
        // mismo destino y bajar un flag que ya está bajo).
        .onChange(of: exitPhase, initial: true) { _, new in
            if new == .awaitingRelaunch { onNeutralReturnArmed() }
        }
    }

    /// El «volver», o `nil` para que no se pinte. Va en una propiedad y no en un ternario dentro del
    /// `body` porque el type-checker no resuelve `cond ? nil : método` sin anotación.
    private var backAction: (() -> Void)? {
        switch phase {
        case .checking, .blockedChannelOff, .confirmingNoBackup,
             .confirmingInviteNeutral, .unavailable:
            return onBack
        case .returningToNeutral, .discardingUnconfirmed, .resumingExportWait, .discardingUnsyncedGroups:
            // Con un aviso en pantalla la salida es su propio botón; mientras trabaja, no hay ninguna.
            if case .blocked = exitPhase { return leaveAfterBlock }
            return nil
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .checking:
            // `.proceed` no pinta nada propio: el step se desmonta en la misma vuelta en que se decide,
            // así que enseñar una pantalla de éxito sería un parpadeo.
            progressContent(text: L10n.Welcome.Groups.checking,
                            identifier: "welcome_groups_gate_checking")
        case .blockedChannelOff:
            blockedContent(
                icon: "person.2.slash",
                title: L10n.Welcome.Groups.channelOffTitle,
                body: L10n.Welcome.Groups.channelOffBody,
                identifier: "welcome_groups_gate_channel_off")
        case .unavailable:
            // Sin esta pantalla el camino era un progreso eterno sin botón: `signOut` tiene TRES `return`
            // mudos (fase no `.idle`, celda distinta de la confirmada, plan nulo) y ninguno toca la fase que
            // esta vista observa. Aquí se decide ANTES de arrancar, así que no hay nada que deshacer.
            noticeShell(icon: "exclamationmark.triangle",
                        title: L10n.Welcome.Groups.neutralUnavailableTitle,
                        body: L10n.Welcome.Groups.neutralUnavailableBody,
                        identifier: "welcome_groups_gate_neutral_unavailable") {
                YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { onBack() }
                    .accessibilityIdentifier("welcome_groups_gate_neutral_unavailable_back")
            }
        case .confirmingNoBackup:
            // El único punto de este flujo donde se PREGUNTA, y solo se llega con prueba de que no hay
            // copia. El botón que destruye va debajo y con `role: .destructive`, como en la puerta privada.
            noticeShell(icon: "icloud.slash",
                        title: L10n.Welcome.Groups.neutralNoBackupTitle,
                        body: L10n.Welcome.Groups.neutralNoBackupBody,
                        identifier: "welcome_groups_gate_neutral_no_backup") {
                VStack(spacing: DS.Spacing.sm) {
                    Button(role: .destructive) {
                        beginNeutralReturn(withoutICloudCopy: true)
                    } label: {
                        Text(L10n.Welcome.Groups.neutralNoBackupCta)
                            .font(DS.Typography.label)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("welcome_groups_gate_neutral_no_backup_confirm")
                    YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { onBack() }
                        .accessibilityIdentifier("welcome_groups_gate_neutral_no_backup_back")
                }
            }
        case .confirmingInviteNeutral(let withoutICloudCopy):
            // **La pregunta del invitado.** El cuerpo cambia con la copia porque son dos situaciones
            // distintas y decir la del otro sería mentir: con copia, lo local se va y iCloud se queda;
            // sin copia (y solo se afirma CON prueba), lo que se borra no está en ningún otro sitio.
            noticeShell(icon: withoutICloudCopy ? "icloud.slash" : "iphone.badge.exclamationmark",
                        title: L10n.Welcome.Groups.inviteNeutralTitle,
                        body: withoutICloudCopy
                            ? L10n.Welcome.Groups.inviteNeutralBodyNoBackup
                            : L10n.Welcome.Groups.inviteNeutralBody,
                        identifier: "welcome_groups_gate_invite_neutral") {
                VStack(spacing: DS.Spacing.sm) {
                    Button(role: .destructive) {
                        // **Sin copia en iCloud se pide un SEGUNDO gesto, igual que en la rama del
                        // organizador.** Colapsarlo en uno era ahorrarse justo la pantalla que protege el
                        // caso irreversible: con copia, lo local se va y iCloud se queda; sin ella, lo que
                        // se borra no está en ningún otro sitio. El primero explica por qué hay que
                        // limpiar el teléfono; el segundo confirma que no hay red debajo.
                        if withoutICloudCopy {
                            phase = .confirmingNoBackup
                        } else {
                            beginNeutralReturn(withoutICloudCopy: false)
                        }
                    } label: {
                        Text(L10n.Welcome.Groups.inviteNeutralCta)
                            .font(DS.Typography.label)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("welcome_groups_gate_invite_neutral_confirm")
                    // Primero visualmente el que NO destruye, igual que en el aviso de la espera agotada.
                    YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { onBack() }
                        .accessibilityIdentifier("welcome_groups_gate_invite_neutral_back")
                }
            }
        case .returningToNeutral, .discardingUnconfirmed, .resumingExportWait, .discardingUnsyncedGroups:
            neutralReturnContent
        }
    }

    /// Lo que se ve mientras el cierre corre, decidido por la fase del coordinador.
    @ViewBuilder
    private var neutralReturnContent: some View {
        switch exitPhase {
        case .idle, .working, .awaitingRelaunch:
            // `.awaitingRelaunch` sigue enseñando el progreso a propósito: el terminal de verdad es el
            // cover del cierre de sesión, y esta pantalla solo tiene que no parpadear mientras lo releva.
            progressContent(text: L10n.Welcome.Groups.neutralWorking,
                            identifier: "welcome_groups_gate_neutral_working")
        case .blocked(let pending, .exportUnconfirmed):
            // La espera se agotó. Las mismas dos salidas que el cierre de Ajustes, y por la misma decisión
            // de Jürgen (2026-09-09): se cuenta lo que se pierde y elige la persona. Primero la que no
            // destruye nada.
            noticeShell(icon: "exclamationmark.icloud",
                        title: L10n.Welcome.Groups.neutralStalledTitle,
                        body: pending > 0
                            ? L10n.Welcome.Groups.neutralStalledBody(pending)
                            : L10n.Welcome.Groups.neutralStalledBodyUnknown,
                        identifier: "welcome_groups_gate_neutral_stalled") {
                VStack(spacing: DS.Spacing.sm) {
                    YalaPrimaryButton(L10n.Welcome.Groups.neutralStalledWait) {
                        intento += 1
                        phase = .resumingExportWait(intento: intento)
                    }
                    .accessibilityIdentifier("welcome_groups_gate_neutral_stalled_wait")
                    // **«Continuar igualmente» NO se le ofrece al INVITADO, y es la asimetría que más pesa
                    // de toda esta pantalla.** Esa salida existe para el dueño de los datos: descarta lo
                    // que el espejo no llegó a exportar, y se decidió (Jürgen, 2026-09-09) contándole
                    // cuánto pierde y dejándole elegir. Por la rama de la invitación quien la tocaría es
                    // otra persona —la del teléfono prestado o comprado de segunda mano—, así que lo que
                    // estaría descartando no es suyo. Sin el botón, la única salida es esperar o volver, y
                    // el criterio del ticket —«lo que el dueño escribió y no llegó a subir no se pierde»—
                    // deja de depender de a quién le den el móvil.
                    if purpose.invitedGroupID == nil {
                        Button(role: .destructive) {
                            intento += 1
                            phase = .discardingUnconfirmed(intento: intento)
                        } label: {
                            Text(L10n.Welcome.Groups.neutralStalledContinue)
                                .font(DS.Typography.label)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("welcome_groups_gate_neutral_stalled_continue")
                    } else {
                        YalaSecondaryButton(L10n.Welcome.Groups.gateBack) { leaveAfterBlock() }
                            .accessibilityIdentifier("welcome_groups_gate_neutral_stalled_back")
                    }
                }
            }
        case .blocked(let pending, .attestUnavailable):
            // **El teléfono sin App Attest** (2026-09-15). Esperar ya no lo arregla, y volver a entrar tampoco. Al dueño
            // se le cuenta lo que pierde y elige, con las salidas de Ajustes adaptadas a esta pantalla («si continúas
            // ahora»): primero la que no destruye. **Al INVITADO no se le ofrece**, por lo mismo que el «Continuar
            // igualmente» del export de arriba: los cambios que perdería no son suyos. Sin la salida de un cierre
            // (`offersGroupsLossExit`) tampoco: queda el texto sin salida y volver.
            let offersLoss = purpose.invitedGroupID == nil && CloudSessionSignOut.shared.offersGroupsLossExit
            noticeShell(icon: "exclamationmark.triangle",
                        title: L10n.Groups.Errors.attestUnavailableTitle,
                        body: offersLoss
                            ? SignOutBlockedCopy.welcomeAttestLossMessage(pending: pending)
                            : L10n.Groups.Errors.attestUnavailable,
                        identifier: "welcome_groups_gate_neutral_attest_unavailable") {
                VStack(spacing: DS.Spacing.sm) {
                    YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { leaveAfterBlock() }
                        .accessibilityIdentifier("welcome_groups_gate_neutral_attest_unavailable_back")
                    if offersLoss {
                        Button(role: .destructive) {
                            intento += 1
                            phase = .discardingUnsyncedGroups(intento: intento)
                        } label: {
                            Text(L10n.Welcome.Groups.neutralAttestLossContinue)
                                .font(DS.Typography.label)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("welcome_groups_gate_neutral_attest_unavailable_continue")
                    }
                }
            }
        case .blocked(_, .channelPaused):
            // **Tercer bloqueo alcanzable aquí, y el más fácil de contar mal** (2026-09-13). Los grupos
            // están apagados a propósito en el servidor y quedan cambios sin subir. El título de abajo
            // sigue siendo verdad —faltan cambios por subir— pero su cuerpo manda «vuelve a entrar con esa
            // cuenta», y con el kill puesto **volver a entrar no sube nada**: el 403 no depende de la
            // sesión. Es el mismo aviso mentiroso que el ticket cerró en Ajustes, por la cuarta celda.
            //
            // La puerta de arriba (`GroupsOrganizerGateLogic`) no lo atrapa antes porque lee el snapshot
            // LOCAL de remote-config: mientras ese snapshot no refresque, la puerta deja pasar y el kill
            // solo se conoce cuando el servidor contesta 403.
            noticeShell(icon: "person.2.slash",
                        title: L10n.Welcome.Groups.neutralBlockedTitle,
                        body: L10n.Groups.Errors.channelPaused,
                        identifier: "welcome_groups_gate_neutral_channel_paused") {
                YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { leaveAfterBlock() }
                    .accessibilityIdentifier("welcome_groups_gate_neutral_channel_paused_back")
            }
        case .blocked(_, .uploadRetryLater):
            // **La subida que no llegó al servidor** (2026-09-16). Sin red, con un 5xx o con un cortafuegos
            // delante, el cierre no ha guardado nada: hasta hoy esto viajaba dentro de `.transient` y esta
            // pantalla decía «todavía estamos terminando de guardar unos cambios» tras 45 s de espera muda.
            // Aquí aterriza sobre todo quien está sin conexión con el token caducado, desde que el canal de
            // Grupos dejó de llamar «caducada» a una renovación sin red
            // (`groups-push-reads-an-offline-token-refresh-as-a-session-expiry`).
            //
            // **Sin esta rama caería en el catch-all de abajo**, que manda «vuelve y entra con esa cuenta»: el
            // consejo equivocado, porque volver a entrar no arregla una red que no está. Ese `case .blocked`
            // final no es exhaustivo, así que el compilador no habría avisado — el propio docblock de
            // `.uploadRetryLater` lo dejó anotado el 2026-09-14, para el día en que naciera un segundo productor.
            //
            // El mensaje es el MISMO que Ajustes y la hoja del cambio de Apple ID enseñan para este motivo, y el
            // título el de las otras ramas de esta pantalla, que nombran el mismo hecho: faltan cambios por subir.
            noticeShell(icon: "arrow.trianglehead.2.clockwise.rotate.90",
                        title: L10n.Welcome.Groups.neutralBlockedTitle,
                        body: L10n.Groups.Errors.uploadRetryLater,
                        identifier: "welcome_groups_gate_neutral_upload_retry") {
                YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { leaveAfterBlock() }
                    .accessibilityIdentifier("welcome_groups_gate_neutral_upload_retry_back")
            }
        case .blocked(_, .transient):
            // **Lo pasajero va aparte** (2026-09-15). Aquí llega, tras los 45 s de reintentos del cierre, lo que
            // se cura esperando y no volviendo a entrar. **Desde el 2026-09-16 es SOLO el outbox que aún drena**:
            // el tope de iteraciones con ciclos sanos, la quiescencia del import sin asentar, la cancelación.
            // La subida fallida se fue a la rama de arriba, que es la mitad por la que este texto mentía.
            //
            // El mensaje es el MISMO que Ajustes y la hoja del cambio de Apple ID enseñan para este motivo
            // (`SignOutBlockedCopy`), por decisión de Jürgen del 2026-09-15: un solo texto para el mismo caso. El título
            // es el de las otras ramas de esta pantalla, que nombran el mismo hecho —faltan cambios por subir—: con el
            // de Ajustes («Un momento más») la puerta tendría dos títulos para una sola cosa.
            noticeShell(icon: "arrow.trianglehead.2.clockwise.rotate.90",
                        title: L10n.Welcome.Groups.neutralBlockedTitle,
                        body: SignOutBlockedCopy.message(for: .transient),
                        identifier: "welcome_groups_gate_neutral_pending") {
                YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { leaveAfterBlock() }
                    .accessibilityIdentifier("welcome_groups_gate_neutral_pending_back")
            }
        case .blocked:
            // El otro bloqueo alcanzable en esta celda: quedaron cambios de GRUPOS sin subir de una sesión
            // que caducó (`blockIfGroupsCannotUpload`). No se descartan nunca, así que la única salida
            // honesta es volver y entrar con esa cuenta. Sin esta rama la pantalla era un spinner eterno.
            // **Con el canal en pausa NO se llega aquí**: ese motivo tiene su propia rama arriba, porque
            // aquí el consejo de volver a entrar sería falso. **Lo pasajero tampoco, y desde el 2026-09-16 son
            // DOS ramas**: el outbox que drena y la subida que no llegó, que se separaron justo para que ésta
            // no les dijera a los dos que volvieran a entrar con la cuenta.
            noticeShell(icon: "arrow.trianglehead.2.clockwise.rotate.90",
                        title: L10n.Welcome.Groups.neutralBlockedTitle,
                        body: L10n.Welcome.Groups.neutralBlockedBody,
                        identifier: "welcome_groups_gate_neutral_blocked") {
                YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { leaveAfterBlock() }
                    .accessibilityIdentifier("welcome_groups_gate_neutral_blocked_back")
            }
        }
    }

    private func progressContent(text: String, identifier: String) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
        .accessibilityIdentifier(identifier)
    }

    private func blockedContent(icon: String, title: String, body: String, identifier: String) -> some View {
        noticeShell(icon: icon, title: title, body: body, identifier: identifier) {
            YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { onBack() }
        }
    }

    private func noticeShell<Actions: View>(
        icon: String, title: String, body: String, identifier: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
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

            actions()
                .padding(.horizontal, DS.Spacing.xl)
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - La puerta

    /// El trabajo de cada fase. Lo llama `.task(id: phase)`, así que la cancelación es real.
    private func runPhase() async {
        switch phase {
        case .checking:
            await evaluate()
        case .returningToNeutral(let withoutICloudCopy, _):
            await returnToNeutral(withoutICloudCopy: withoutICloudCopy)
        case .discardingUnconfirmed:
            await CloudSessionSignOut.shared.exitDiscardingUnconfirmed(context: modelContext)
        case .resumingExportWait:
            await CloudSessionSignOut.shared.resumeWaitingForExport(context: modelContext)
        case .discardingUnsyncedGroups:
            await CloudSessionSignOut.shared.exitDiscardingUnsyncedGroups(context: modelContext)
        case .blockedChannelOff, .confirmingNoBackup,
             .confirmingInviteNeutral, .unavailable:
            return
        }
    }

    /// El orden es el del spec y **no se puede reordenar**: primero se re-mide el canal (con `force`),
    /// después se decide. Esta función no escribe nada en `UserDefaults` — ni ella ni ninguna a la que
    /// llame — y eso es la mitad del chip: el alta de solo-grupos se escribe cuando la ruta ya está
    /// confirmada, nunca mientras se decide.
    private func evaluate() async {
        // **La rama del invitado no re-mide el canal, y no es un olvido.** El `force` existe porque la
        // card «Crear mi primer grupo» es la PRIMERA evidencia de que el canal debería estar encendido;
        // una invitación ya pasó por `GroupInviteChannelRoutingLogic`, que hace ese mismo refresh forzado
        // al recibir el link y decide con él. Repetirlo aquí sería una llamada de red que no cambia nada,
        // y el veredicto del invitado no tiene término de canal.
        if case .acceptInvite = purpose {
            evaluateInvite()
            return
        }

        // Hermeticidad: bajo `-uitest` no se toca red, igual que el `.task` del container. Los getters ya
        // devuelven su default (ON bajo `Yala Dev`), así que el XCUITest recorre la rama buena.
        if !SwiftDataConfiguration.isUITesting {
            await RemoteConfigClient.shared.refreshIfDue(force: true)
        }

        // El `.task` se cancela al desmontar el step, pero la CANCELACIÓN ES COOPERATIVA: `refreshIfDue`
        // solo la mira entre el fetch ajeno que espera y el suyo —nunca dentro de un fetch en curso—, así
        // que sin este guard un usuario que tapea «volver» durante el refresh saldría del Welcome igual
        // cuando la red conteste. Es el único punto de suspensión de la rama.
        guard !Task.isCancelled else { return }

        let verdict = GroupsOrganizerGateLogic.decide(
            channelEnabled: CloudSyncFlags.groupsBackendEnabled,
            hasExistingData: hasLocalDataNow(),
            // El EJE ANCHO, y se lee AQUÍ y no antes: es el testigo del mount de este proceso, que no
            // cambia, pero leerlo junto a los otros dos términos es lo que mantiene la puerta en un sitio.
            mountAttachesMirror: Self.mountAttachesMirrorNow)

        switch verdict {
        case .proceed:
            onProceed()
        case .blockedChannelOff:
            phase = .blockedChannelOff
        case .returnsToNeutral:
            phase = neutralReturnEntryPhase()
        }
    }

    /// **La puerta del INVITADO, re-medida aquí.** No es una repetición del veredicto de `drive`: entre
    /// aquel submit y este render puede haber mediado un relanzamiento entero —que es justamente lo que
    /// esta pantalla provoca—, así que quien llega tras la vuelta al neutro encuentra `.proceed` y sigue
    /// sin tocar nada. Es el mismo «la puerta vuelve a medir» con el que el paso 5 retoma la rama
    /// organizador después de reabrir la app.
    ///
    /// Síncrona y sin suspensiones: los cuatro términos son lecturas locales.
    private func evaluateInvite() {
        // **Se llama al veredicto del handler y no se recomponen los cuatro términos aquí**, aunque los
        // dos primeros se lean igual de fácil. Dos composiciones de la misma decisión divergen: bastaría
        // con que una añadiera un término para que esta pantalla dejara pasar lo que `drive` frenó, o al
        // revés. Los providers ya los cablea `ContentView` con los MISMOS closures que alimentan al guard
        // cross-cuenta, así que lo que se mide aquí es literalmente lo que se midió allí — solo que ahora,
        // que es lo único que esta segunda lectura añade.
        switch GroupBackendInviteEntryHandler.neutralGateDecision() {
        case .proceed:
            onProceed()
        case .returnsToNeutral:
            phase = inviteNeutralEntryPhase()
        }
    }

    /// A qué pantalla entra la vuelta al neutro del invitado. Comparte con la del organizador las dos
    /// comprobaciones que impiden un progreso eterno —la fase del coordinador y la celda de cierre— y se
    /// separa en el último paso: aquí **siempre** se pregunta, con o sin copia en iCloud, y el canal de
    /// copia solo elige qué dice el cuerpo.
    private func inviteNeutralEntryPhase() -> Phase {
        guard CloudSessionSignOut.shared.phase == .idle else { return .unavailable }
        switch Self.exitCell() {
        case .privateSignOut, .privateWithGroupsSignOut, .groupsOnlySignOut:
            return .confirmingInviteNeutral(
                withoutICloudCopy: CloudSessionSignOut.privateCopyChannel() == .none)
        case .cloudSecureSignOut:
            // El cierre de la nube NO borra por archivos: haría un borrado distinto del que esta pantalla
            // promete.
            return .unavailable
        }
    }

    /// **El único sitio que arranca la vuelta al neutro desde un gesto, y el que escribe el sobre.**
    ///
    /// El sobre `{groupID, token}` va AQUÍ y no en el callback del arm, y la diferencia se mide en
    /// segundos de proceso: entre `armSignOutWipe()` y la entrega del `onChange` que avisa a `ContentView`
    /// hay una vuelta de SwiftUI, y en el camino del swap in-process `attemptSignOutSwap()` corre en la
    /// MISMA vuelta del arm y desmonta esta jerarquía —esta vista incluida—. Escribirlo allí dejaba una
    /// ventana en la que el teléfono se borraba y la invitación no cruzaba: el camino muerto que toda esta
    /// pantalla existe para cerrar, y con el corpus ya borrado.
    ///
    /// Escribirlo aquí no cuesta nada si el borrado no llega a ocurrir: el sobre es INERTE hasta que un
    /// boot-wipe lo consume, y caduca solo.
    private func beginNeutralReturn(withoutICloudCopy: Bool) {
        if let groupID = purpose.invitedGroupID,
           let token = PendingJoinStore.entry(zoneName: groupID)?.inviteToken {
            GroupInviteResumeStore.set(groupID: groupID, token: token)
        }
        intento += 1
        phase = .returningToNeutral(withoutICloudCopy: withoutICloudCopy, intento: intento)
    }

    /// **El eje ancho del mount, con el seam que el host de test necesita.**
    ///
    /// Bajo `-uitest` el testigo MIENTE, y está medido: `SwiftDataConfiguration.personalConfiguration` sale
    /// por su rama `YalaModel-UITest` —`cloudKitDatabase: .none`, o sea que NO espeja— **antes** de llamar a
    /// `capturePersonalStoreMountedDecisionOnce`, así que `personalStoreMountedDecision` se queda en el
    /// default de su declaración, que es `.iCloudMirror`. Sin este seam la puerta leería `true` en toda
    /// corrida, `.proceed` sería inalcanzable y los XCUITest de la rama buena se caerían — arrastrando además
    /// un `armSignOutWipe` real en cada corrida, cuya key sobrevive a `-uitest-reset`.
    ///
    /// El default del seam es la VERDAD de ese host (`false`), no una inversión; el hook solo lo enciende
    /// para el test que quiera recorrer la vuelta al neutro. En producción no existe.
    private static var mountAttachesMirrorNow: Bool {
        #if DEBUG
        if SwiftDataConfiguration.isUITesting { return UITestHooks.groupsGateMirrorLive }
        #endif
        return CloudSessionSignOut.personalMountAttachesMirror
    }

    /// A qué pantalla entra la vuelta al neutro. **Se decide ANTES de tocar nada**, y eso cierra los tres
    /// `return` mudos de `signOut` —fase no `.idle`, celda distinta de la confirmada, plan nulo—: ninguno
    /// toca la fase que esta vista observa, así que arrancar a ciegas dejaba un progreso eterno sin botón.
    ///
    /// La celda se resuelve con la MISMA función pura y los MISMOS cinco términos que el coordinador
    /// (`CloudSignOutFlowLogic.path`), que es el duplicado deliberado que ya tiene `ProfileView.signOutRowPath`
    /// — y por eso el `confirmedPath` que viaja después es el cinturón que comprueba que no ha cambiado
    /// entre esta línea y la ejecución.
    private func neutralReturnEntryPhase() -> Phase {
        guard CloudSessionSignOut.shared.phase == .idle else { return .unavailable }
        switch Self.exitCell() {
        case .privateSignOut, .privateWithGroupsSignOut, .groupsOnlySignOut:
            // Informar, no preguntar — salvo que no haya copia a la que apuntar, y eso solo se afirma con
            // prueba (`mirrorReportedNotAuthenticated`). Con Drive apagado y CloudKit vivo el canal sigue
            // siendo `.iCloud`, que es el hallazgo nº 7 de la review del paso 9.
            switch CloudSessionSignOut.privateCopyChannel() {
            case .iCloud:
                intento += 1
                return .returningToNeutral(withoutICloudCopy: false, intento: intento)

            case .none:
                return .confirmingNoBackup
            }
        case .cloudSecureSignOut:
            // El cierre de la nube NO borra por archivos: haría un borrado distinto del que esta pantalla
            // promete.
            return .unavailable
        }
    }

    /// La celda de cierre de ESTE dispositivo. Espejo exacto del dispatch de `CloudSessionSignOut.signOut`,
    /// con sus términos en el mismo orden: si divergieran, la puerta prometería un borrado que el
    /// coordinador no va a hacer.
    private static func exitCell() -> CloudSignOutFlowLogic.Path {
        CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode,
            hasLiveSession: CloudAuthService.shared.hasSession,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability,
            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
    }

    /// La vuelta al neutro.
    ///
    /// **El latch de restauración NO se apaga aquí, y es una decisión medida.** El criterio nº 3 del ticket
    /// pide que una restauración en curso se cancele, y la primera versión llamaba a `noteRestoreFinished()`
    /// como primera línea. Dos lentes midieron el precio: si el cierre luego se bloquea —espera agotada,
    /// grupos sin subir— y la persona sale, el import SIGUE bajando con el latch apagado y **nadie lo vuelve
    /// a encender** (su único encendedor de producción es `WelcomeRestoreView`, pinneado a un solo sitio).
    /// A partir de ahí el guard cross-cuenta del sign-in vuelve a clasificar el corpus propio de la dueña
    /// como ajeno: la enmienda D2, deshecha. El criterio se cumple igual y mejor por el camino de siempre —
    /// el latch vive en MEMORIA y muere con el proceso, que es exactamente lo que el relanzamiento hace.
    ///
    /// `confirmedPath` es el cinturón: la celda se midió al entrar (`neutralReturnEntryPhase`) y si cambió
    /// entre aquella línea y ésta, el coordinador no corre un borrado que nadie leyó. Que ese `return` mudo
    /// no deje un progreso eterno lo cierra la comprobación de arriba, no éste.
    private func returnToNeutral(withoutICloudCopy: Bool) async {
        let celda = Self.exitCell()
        await CloudSessionSignOut.shared.signOut(
            context: modelContext,
            confirmedPath: celda,
            confirmedWithoutICloudCopy: withoutICloudCopy)
        // Cinturón del cinturón: si el coordinador volvió sin tocar su fase, no arrancó nada. Sin esto la
        // pantalla se queda en un progreso que no avanza y sin botón de volver.
        if CloudSessionSignOut.shared.phase == .idle { phase = .unavailable }
    }

    /// Salir tras un bloqueo. **Devuelve el coordinador a `.idle`**, porque un `.blocked` que sobrevive a
    /// esta pantalla le cierra la puerta al siguiente intento: `signOut` empieza con `guard phase == .idle`
    /// y volvería sin hacer nada, en silencio.
    private func leaveAfterBlock() {
        CloudSessionSignOut.shared.acknowledgeBlocked()
        onBack()
    }
}
