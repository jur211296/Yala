//
//  WelcomePrivateICloudGateView.swift
//  Yala
//
//  Paso 4 del rediseño de sesiones · **la pantalla que faltaba entre «elijo privado» y «reabre la app».**
//
//  Es un STEP del `WelcomeFlowContainer`, con el molde de `WelcomeGroupsGateView`, y por las mismas tres
//  razones más una cuarta que aquí es la que manda:
//
//   1. El portal `leaveWelcome` es la única salida del cover, y esta puerta tiene que decidir ANTES.
//   2. Una presentación nueva del anchor de `ContentView` entraría en la matriz de readiness (regla 3 de
//      Presentaciones).
//   3. Dos source-scans prohíben `.alert(` en el container (`WelcomeHeroReentryTests`,
//      `GroupsOrganizerBranchTests.gateIsAScreenAndNeverAnAlert`).
//   4. **Y la razón medida:** un `.alert` colgado del anchor de `ContentView` **DESMONTA el cover del
//      Welcome** — traza en `ShellDataAlertsModifier.swift`, `DIAG gated.set: true -> false`. Ese es el bug
//      de la pantalla negra del 2026-09-03. Aquí sería peor que allí: «cancelar» tiene que devolver al
//      chooser privado/nube, y ese chooser ya no existiría cuando el usuario tocara el botón.
//
//  **Las dos confirmaciones del borrado son FASES de esta pantalla, no dos modales encadenados.** El ADR
//  pide doble confirmación; el ticket sugiere «el alert existente + una segunda». La forma es distinta a
//  propósito: encadenar dos presentaciones desde el mismo anchor es la carrera que `UserDataResetView`
//  evita usando dos CONTENEDORES distintos (sheet → alert) y un `onDismiss`, y aquí no hay un contenedor
//  de repuesto —el step ya vive dentro del `fullScreenCover` del Welcome—. Dos fases dan los dos gestos
//  deliberados que la doble confirmación existe para exigir, sin ninguna presentación anidada. El texto
//  de la segunda sí se REUSA (`settings.wipeDataSecondConfirmTitle`), que es lo que el ticket pedía.
//
//  **La FASE conduce el trabajo, y no al revés** (review adversarial del 2026-09-10). La primera versión
//  lanzaba `Task { await runWipe() }` desde los botones: `Task` no estructurado, sin handle y sin
//  cancelación, así que `Task.isCancelled` era SIEMPRE `false` ahí y un «volver» a media operación dejaba
//  el trabajo corriendo sobre una vista ya desmontada — que acababa llamando a `onProceed()` y arrancando
//  a la persona del chooser hacia el terminal de relanzamiento. Ahora los botones solo cambian `phase` y
//  el trabajo cuelga de `.task(id: phase)`: SwiftUI lo cancela al desmontar y al cambiar de fase, que es
//  exactamente la semántica que los `guard !Task.isCancelled` afirmaban tener y no tenían.
//
//  **Lo que esta pantalla NO hace: borrar.** El borrado vive en `ContentView` (`performICloudCorpusWipe`),
//  que es quien tiene el `modelContext` y el cover de relanzamiento. No es reparto de tareas: la puerta es
//  alcanzable con el espejo YA adjunto —el mount neutro dura UN arranque, así que quien abre la app, ve el
//  Welcome y la cierra sin elegir llega aquí en `.iCloudMirror`— y ahí borrar solo la zona de CloudKit
//  dejaría el corpus viejo entero en el dispositivo.
//

import SwiftUI

struct WelcomePrivateICloudGateView: View {

    /// Seguir al onboarding privado por el portal de siempre (que decide si hay que reabrir la app).
    var onProceed: () -> Void
    /// Tercera salida del aviso: «esto es mío» → «Restaurar desde iCloud», por el portal, con su destino.
    var onRestore: () -> Void
    /// Cancelar: vuelve a la elección privado / nube.
    var onBack: () -> Void
    /// Borrar el corpus del iCloud de este Apple ID **y** lo que el espejo hubiera bajado ya. Devuelve
    /// `nil` si fue bien, o el motivo del fallo. Lo ejecuta `ContentView`.
    var performWipe: @MainActor () async -> String?
    /// **El corpus que ya está EN EL TELÉFONO**, o `nil` para no preguntar por él. Sin default a
    /// propósito: los dos sitios que montan esta puerta contestan cosas OPUESTAS y el compilador tiene que
    /// obligarles a decirlo.
    ///
    ///  · El **Welcome** lo pasa: quien elige «Es mi primera vez» sobre un teléfono con datos —una etapa
    ///    solo-grupos, un reinstall— tiene que verlos antes de que nada se borre. Ese aviso se perdía
    ///    cuando el mount es neutro, porque el camino sale por el relanzamiento y nunca llega al
    ///    `onSelectPrivateAccount` que lo levantaba.
    ///  · La **activación de Yala completo** pasa `nil`, y no es un olvido: allí los datos del teléfono son
    ///    de la misma persona que está activando —sus grupos, sus categorías— y borrárselos sería el daño
    ///    contrario al que esta puerta existe para evitar.
    var deviceCorpus: DeviceCorpus?

    /// Las dos mitades del corpus local, juntas para que no puedan separarse: quien pregunta «¿hay datos?»
    /// es quien tiene que saber borrarlos. `hasData` se evalúa VIVO (un snapshot no vale: el espejo puede
    /// estar re-importando mientras el Welcome está en pantalla).
    struct DeviceCorpus {
        var hasData: @MainActor () -> Bool
        /// Borra las filas del teléfono, purga el dominio de Grupos y escribe el sello del handover.
        /// `nil` si fue bien, o el motivo del fallo.
        var wipe: @MainActor () async -> String?
    }
    /// Paso 8 · ¿el borrado limpia también el nombre y la divisa residuales? `true` en el Welcome, donde son
    /// restos de quien usó el dispositivo antes. **`false` en la activación de Yala completo**: allí son el
    /// prefill de la persona que está activando —su nombre y la divisa de sus grupos—, y borrarlos le quitaría
    /// justo lo que el onboarding le iba a ahorrar escribir.
    var clearsResidualPreferencesOnWipe: Bool = true
    /// **Qué se le ofrece a quien no pudo obtener respuesta de iCloud.** Sin default a propósito, por lo
    /// mismo que `deviceCorpus`: los sitios que montan esta puerta contestan cosas OPUESTAS y el
    /// compilador tiene que obligarles a decirlo. Un default heredaría el desenlace de uno de los dos, que
    /// es la forma exacta del bug que este parámetro cierra — la puerta de «Empezar desde cero» nació
    /// reusando esta vista y se trajo la salida de la otra sin que nadie lo decidiera.
    var unverifiedExit: UnverifiedExit
    /// **Qué hace este montaje con un borrado que quedó a medias**: recordarlo para el aviso tardío (Welcome),
    /// terminarlo al volver (la puerta de «Empezar desde cero») o nada, porque su borrado no toca filas (la puerta
    /// privada de la activación). Sin default: ver `WelcomePrivateICloudGateLogic.HalfwayWipe`.
    var halfwayWipe: WelcomePrivateICloudGateLogic.HalfwayWipe

    /// Los dos desenlaces de «no se pudo preguntar». Lo que los separa es **si la persona ya confirmó un
    /// borrado antes de llegar aquí**.
    enum UnverifiedExit: Equatable {
        /// **Sigue adelante, con el testigo del espejo tardío puesto.** Es el desenlace de quien acaba de
        /// elegir «privado» y todavía no ha pedido borrar nada: el ADR es explícito en que no poder
        /// preguntar JAMÁS bloquea, y sin esta salida la pantalla es un camino muerto —las otras dos ramas
        /// del chooser también necesitan red—. La validación no se pierde: se aplaza al primer arranque en
        /// que se pueda hacer.
        case proceedWatchingTheMirror
        /// **Vuelve por donde vino, sin declarar ningún borrado** (decisión de Jürgen, 2026-09-14, opción
        /// (a) del ticket). Es el desenlace de «Restaurar → Empezar desde cero», donde la persona YA
        /// confirmó el borrado dos veces: seguir la dejaría en el onboarding con sus datos viejos enteros,
        /// bajo un copy que le prometió lo contrario.
        case returnWithoutClaimingAWipe
    }

    /// **Por dónde entra la puerta.** `.measure`, el de siempre, le pregunta a iCloud y decide.
    ///
    /// `.wipeDevice` va directo al borrado del teléfono, y lo usa un solo sitio: el «Borrar todo y continuar» del shell
    /// cuando quedan cambios de grupos sin subir (ticket `fresh-start-has-no-way-out-when-group-writes-can-never-upload`).
    /// Aquel alert no puede subirlos —no queda nada montado donde enseñar una subida—, así que nunca conocía el motivo y
    /// siempre decía «inténtalo en un rato», también a quien no iba a poder subirlos nunca. Esta puerta sube, enseña el
    /// motivo y, si esperar no lo arregla, ofrece perderlos. La persona ya confirmó el borrado en ese alert: aquí no se le
    /// vuelve a preguntar.
    var entry: Entry = .measure

    enum Entry: Equatable {
        case measure
        case wipeDevice
    }

    /// **La entrada `.wipeDevice` borra con solo montarse, así que exige un permiso de UN solo uso** (review adversarial
    /// del 2026-09-26). Lo da el alert del shell en el mismo tap que confirma el borrado
    /// (`armDeviceWipeHandoff`) y lo gasta la primera vuelta de la fase. Sin él, cualquier camino futuro que reabriera
    /// el Welcome sin reescribir el paso inicial —se queda en `.freshStartDeviceWipe`— borraría sin preguntar. En memoria
    /// a propósito: un relanzamiento no hereda un «sí».
    private static var deviceWipeHandoffArmed = false

    /// El alert del shell confirmó «Borrar todo y continuar» con cambios de grupos pendientes: la puerta puede borrar una vez.
    static func armDeviceWipeHandoff() { deviceWipeHandoffArmed = true }

    /// Gasta el permiso. `false` = nadie confirmó este borrado: la puerta no borra y vuelve atrás.
    static func consumeDeviceWipeHandoff() -> Bool {
        defer { deviceWipeHandoffArmed = false }
        return deviceWipeHandoffArmed
    }

    @State private var phase: Phase = .checking

    private enum Phase: Equatable {
        case checking
        case found(ICloudPersonalCorpus)
        /// 2.ª confirmación. Lleva el corpus dentro para poder volver a `.found` sin re-medir si la
        /// persona se arrepiente: re-preguntar a CloudKit por retroceder sería cobrarle una espera por
        /// dudar, y el corpus no ha cambiado en esos dos segundos.
        case confirmingWipe(ICloudPersonalCorpus)
        case wiping
        /// El borrado de iCloud falló. **`zoneGone` dice si la zona ya se había borrado**, y cambia el hecho que la
        /// pantalla cuenta (ticket `private-gate-wipe-failure-copy-claims-icloud-is-intact`): sin tocarla, los datos
        /// siguen en iCloud; con ella ida, iCloud está vacío y lo del teléfono a medias. Viaja dentro del case por lo
        /// mismo que `iCloudUnverified` abajo: un `@State` al lado se hereda en silencio al reintentar.
        case wipeFailed(zoneGone: Bool)
        case noICloud
        case unreachable
        // MARK: Las cuatro del corpus que ya está en el TELÉFONO
        //
        // Son fases propias y no un flag al lado de las de arriba **porque el flag se hereda en silencio**:
        // es el defecto que la review le cazó al propósito de la puerta de Grupos cuando vivía en un
        // `@State` paralelo al step. Aquí el dato viaja DENTRO del case y el compilador obliga a cada
        // transición a decir con qué corpus trabaja.
        //
        // `iCloudUnverified` las recorre las cuatro porque decide el final del camino: si a iCloud no se
        // le pudo preguntar, quien sigue adelante tiene que quedar bajo el mismo testigo que el estado K
        // (`continueWithoutValidating`), o el aviso del espejo tardío se pierde.
        case foundDevice(iCloudUnverified: Bool)
        case confirmingDeviceWipe(iCloudUnverified: Bool)
        case wipingDevice(iCloudUnverified: Bool)
        case deviceWipeFailed(iCloudUnverified: Bool)
        /// **El borrado no corrió: quedan cambios de grupos sin subir** (ticket
        /// `fresh-start-wipe-kills-unsent-group-writes-silently`). No se tocó nada, ni en iCloud ni en el teléfono. Lleva
        /// dentro cuántos y por qué, y a qué borrado vuelve «Reintentar»: el dato viaja en el case, no en un `@State` al
        /// lado (misma razón que las cuatro de arriba).
        case groupsPending(CloudSessionSignOut.FreshStartGroupsBlock, retry: GroupsPendingRetry)
        /// **El «¿seguro?» de «Empezar de cero y perderlos»** (ticket
        /// `fresh-start-has-no-way-out-when-group-writes-can-never-upload`). Solo se llega desde un `.groupsPending` cuyo
        /// motivo ofrece la salida, y lleva dentro el mismo bloqueo y el mismo borrado para volver a él sin re-medir.
        case confirmingGroupsLoss(CloudSessionSignOut.FreshStartGroupsBlock, retry: GroupsPendingRetry)
    }

    /// Qué borrado se paró en los cambios de grupos, y por tanto cuál repite «Reintentar».
    private enum GroupsPendingRetry: Equatable {
        case iCloud
        case device(iCloudUnverified: Bool)
    }

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
        // **El «volver» desaparece durante el borrado, y no es cosmético** (`nil` deja la vista intacta,
        // que es para lo que ese parámetro es opcional). Salir a media operación deja el arm puesto
        // —correcto: la llamada puede haber llegado al servidor— pero devuelve a la persona al chooser,
        // donde puede elegir la nube; y el arranque siguiente la traería aquí a terminar un borrado que ya
        // no quiere, sobre datos que ya no son los mismos. Mientras hay algo destructivo en vuelo no hay
        // marcha atrás que ofrecer, así que no se ofrece.
        .welcomeBackButton(tint: .white, action: backAction)
        // **La FASE conduce.** `id: phase` es lo que da cancelación real: al desmontar el step o al cambiar
        // de fase, SwiftUI cancela el trabajo en vuelo. Con `Task { }` sueltos desde los botones no la
        // había, y los `guard !Task.isCancelled` de abajo eran decorativos.
        .task(id: phase) { await runPhase() }
    }

    /// El «volver», o `nil` para que no se pinte. Va en una propiedad y no en un ternario dentro del
    /// `body` porque el type-checker no resuelve `cond ? nil : método` sin anotación — y en este `body` un
    /// tropiezo del inferidor no da un error legible, da «failed to produce diagnostic».
    private var backAction: (() -> Void)? {
        if phase == .wiping { return nil }
        // La misma regla para el borrado del teléfono: mientras hay algo destructivo en vuelo no hay
        // marcha atrás que ofrecer. `if case` y no `==` porque la fase lleva su término dentro.
        if case .wipingDevice = phase { return nil }
        return { leaveGate() }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .checking:
            // Con `.wipeDevice` esta fase solo dura el instante de arrancar el borrado: se dice lo que va a pasar.
            if entry == .wipeDevice {
                progressContent(text: L10n.Welcome.PrivateICloud.wiping,
                                identifier: "welcome_private_icloud_wiping_device")
            } else {
                progressContent(text: L10n.Welcome.PrivateICloud.checking,
                                identifier: "welcome_private_icloud_checking")
            }
        case .wiping:
            progressContent(text: L10n.Welcome.PrivateICloud.wiping,
                            identifier: "welcome_private_icloud_wiping")
        case .found(let corpus):
            foundContent(corpus)
        case .confirmingWipe(let corpus):
            confirmContent(corpus)
        case .noICloud:
            // Estado K de la matriz. **Informa y sigue** — el ADR es explícito en que no poder preguntar
            // jamás bloquea. Su CTA es la salida del Welcome, no el «volver» de la barra… salvo en la
            // puerta que decide volver, donde ese mismo botón es el que devuelve a Restaurar. Lo dice
            // `unverifiedExit`, y por eso el label también sale de ahí.
            //
            // **Y el ticket dice que esta fase es inalcanzable desde «Empezar desde cero». Medido: no lo
            // es.** `WelcomeRestoreView` ofrece ese botón desde cinco estados (cuatro hasta el
            // 2026-09-17, cuando entró `.cloudUnverified`) y tres de ellos no afirman
            // que haya datos —`notFoundView`, `iCloudDisabledView` y `wipedView` llaman directo—, así que
            // con iCloud apagado en el teléfono se llega aquí con el borrado ya confirmado. Por eso la
            // salida bifurca igual que la de abajo, y no se deja «solo la fase que el ticket nombra».
            //
            // **Y en el desenlace que VUELVE, esta fase deja de tener un solo botón** (review adversarial,
            // 2026-09-14). Un CTA único que devuelve a Restaurar es un camino muerto de dos pantallas:
            // `iCloudDisabledView` ofrece «Abrir Ajustes» y «Empezar desde cero», así que la persona
            // rebota entre las dos sin nada que re-mida. El estado K es terminal donde el ADR dice que lo
            // es —el Welcome, donde no hay remedio— y aquí el remedio SÍ existe: encender iCloud en
            // Ajustes y volver a preguntar. Sin este botón, hacerlo obliga a salir de la puerta y repetir
            // el gesto destructivo entero.
            noICloudContent
        case .unreachable:
            // Se pudo intentar y falló. Dos salidas, y las dos hacen falta:
            //
            //  · **Reintentar** es la primera, porque aquí el remedio existe (a diferencia del estado K).
            //  · **Seguir sin comprobar** es la segunda, y sin ella esta pantalla era un CAMINO MUERTO
            //    (review adversarial, 2026-09-10): las otras dos ramas del chooser —restaurar de iCloud y
            //    cuenta en la nube— también necesitan red, así que un primer arranque sin conexión dejaba
            //    a la persona sin ninguna forma de entrar en la app. El ADR dice que no poder preguntar
            //    JAMÁS bloquea, y un botón que solo puede reintentar sí bloquea.
            //
            // Seguir deja el mismo testigo que el estado K: la validación no se pierde, se aplaza al
            // primer arranque en que se pueda hacer.
            //
            // **Salvo cuando la persona ya confirmó un borrado**, que es el caso real del ticket: ahí la
            // segunda salida no sigue, VUELVE (`unverifiedExit`). El botón de reintentar se queda en los
            // dos desenlaces — aquí el remedio existe, y es el que de verdad resuelve.
            twoWayNoticeContent(
                icon: "exclamationmark.icloud",
                title: L10n.Welcome.PrivateICloud.errorTitle,
                body: unreachableBody,
                primary: L10n.Welcome.Restore.retry,
                secondary: unverifiedExitLabel,
                identifier: "welcome_private_icloud_error",
                primaryAction: { phase = .checking },
                secondaryAction: exitWithoutValidating)
        case .wipeFailed(let zoneGone):
            // El borrado falló. Continuar sería mentirle. Dos salidas: reintentar, o irse — y ese «irse» es el
            // ÚNICO sitio donde se retira el arm, porque es el único donde consta que la persona ya no quiere el
            // borrado. **Qué se le dice depende de si la zona ya se había ido**: ver `wipeFailedBody(zoneGone:)`.
            twoWayNoticeContent(
                icon: "exclamationmark.icloud",
                title: L10n.Welcome.PrivateICloud.wipeFailedTitle,
                body: Self.wipeFailedBody(zoneGone: zoneGone),
                // **`wipeRetry` y no `Restore.retry`**: aquél dice «Reintentar búsqueda», que en una
                // pantalla de borrado fallido no significa nada. El de `.unreachable` se queda como está,
                // porque ahí sí se vuelve a BUSCAR.
                primary: L10n.Welcome.PrivateICloud.wipeRetry,
                secondary: L10n.Welcome.PrivateICloud.wipeFailedBack,
                identifier: "welcome_private_icloud_wipe_failed",
                primaryAction: { phase = .wiping },
                secondaryAction: leaveGate)
        case .wipingDevice:
            progressContent(text: L10n.Welcome.PrivateICloud.wipingDevice,
                            identifier: "welcome_private_icloud_wiping_device")
        case .foundDevice(let unverified):
            foundDeviceContent(iCloudUnverified: unverified)
        case .confirmingDeviceWipe(let unverified):
            confirmDeviceContent(iCloudUnverified: unverified)
        case .deviceWipeFailed(let unverified):
            // Mismo molde que su gemela de iCloud y por la misma razón: el borrado falló, los datos siguen
            // AQUÍ, y continuar sería mentirle. Lo que cambia es dónde están — el copy de arriba, con la zona sin
            // tocar, promete que siguen en iCloud, y aquí eso sería falso.
            twoWayNoticeContent(
                icon: "exclamationmark.triangle",
                title: L10n.Welcome.PrivateICloud.wipeFailedTitle,
                body: L10n.Welcome.PrivateICloud.wipeDeviceFailedBody,
                primary: L10n.Welcome.PrivateICloud.wipeRetry,
                secondary: L10n.Welcome.PrivateICloud.wipeFailedBack,
                identifier: "welcome_private_icloud_wipe_failed_device",
                primaryAction: { phase = .wipingDevice(iCloudUnverified: unverified) },
                secondaryAction: leaveGate)
        case .groupsPending(let block, let retry) where block.offersLossExit:
            groupsLossOfferContent(block, retry: retry)
        case .confirmingGroupsLoss(let block, let retry):
            groupsLossConfirmContent(block, retry: retry)
        case .groupsPending(let block, let retry):
            // Mismo molde que los dos fallos de arriba —reintentar o irse—, con el texto que dice lo que pasó de
            // verdad: no se borró nada porque quedan cambios de grupos, cuántos, y qué hacer según el motivo. Con un
            // motivo que se cura esperando no hay salida «perderlos» (`CloudSignOutFlowLogic.freshStartOffersGroupsLossExit`).
            twoWayNoticeContent(
                icon: "exclamationmark.triangle",
                title: L10n.Groups.FreshStartPending.title,
                body: SignOutBlockedCopy.freshStartGroupsPendingMessage(block),
                primary: L10n.Welcome.PrivateICloud.wipeRetry,
                secondary: L10n.Welcome.PrivateICloud.wipeFailedBack,
                identifier: "welcome_private_icloud_groups_pending",
                primaryAction: { phase = Self.wipePhase(for: retry) },
                secondaryAction: leaveGate)
        }
    }

    /// **Faltan cambios de grupos y esperar no los va a subir**: la salida «perderlos» (ticket
    /// `fresh-start-has-no-way-out-when-group-writes-can-never-upload`). Dos salidas, la que no destruye arriba —el orden
    /// de `foundDeviceContent`—: irse, que no borra nada, o ir al «¿seguro?». **Sin «Volver a intentarlo»**: con estos
    /// motivos un reintento no cambia nada, y el «¿seguro?» ya vuelve a subir antes de perder nada.
    private func groupsLossOfferContent(_ block: CloudSessionSignOut.FreshStartGroupsBlock,
                                        retry: GroupsPendingRetry) -> some View {
        noticeShell(icon: "exclamationmark.triangle",
                    title: L10n.Groups.FreshStartPending.title,
                    body: SignOutBlockedCopy.freshStartGroupsPendingMessage(block),
                    identifier: "welcome_private_icloud_groups_pending") {
            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.Welcome.PrivateICloud.wipeFailedBack) { leaveGate() }
                    .accessibilityIdentifier("welcome_private_icloud_groups_pending_back")
                destructiveButton(L10n.Groups.FreshStartPending.lossAction,
                                  identifier: "welcome_private_icloud_groups_pending_lose") {
                    phase = .confirmingGroupsLoss(block, retry: retry)
                }
            }
        }
    }

    /// **El «¿seguro?»**: cuántos se pierden y que no hay vuelta. «Mejor no» vuelve al aviso sin tocar nada; el botón
    /// destructivo es el ÚNICO de todo el gesto que acepta la pérdida (`CloudSessionSignOut.acceptFreshStartGroupsLoss`) y
    /// relanza el mismo borrado, que vuelve a subir antes de perder nada.
    private func groupsLossConfirmContent(_ block: CloudSessionSignOut.FreshStartGroupsBlock,
                                          retry: GroupsPendingRetry) -> some View {
        noticeShell(icon: "trash",
                    title: L10n.Groups.FreshStartPending.lossConfirmTitle,
                    body: SignOutBlockedCopy.freshStartGroupsLossConfirmMessage(block),
                    identifier: "welcome_private_icloud_groups_loss_confirm") {
            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.Welcome.PrivateICloud.wipeConfirmKeep) {
                    phase = .groupsPending(block, retry: retry)
                }
                .accessibilityIdentifier("welcome_private_icloud_groups_loss_keep")
                destructiveButton(L10n.Groups.FreshStartPending.lossConfirmAction,
                                  identifier: "welcome_private_icloud_groups_loss_confirm_lose") {
                    CloudSessionSignOut.shared.acceptFreshStartGroupsLoss()
                    phase = Self.wipePhase(for: retry)
                }
            }
        }
    }

    /// La fase que repite el borrado que se paró en los cambios de grupos.
    private static func wipePhase(for retry: GroupsPendingRetry) -> Phase {
        switch retry {
        case .iCloud: return .wiping
        case .device(let unverified): return .wipingDevice(iCloudUnverified: unverified)
        }
    }

    /// El estado K, con la forma que le toca a cada desenlace. **La diferencia no es estética: es si la
    /// pantalla tiene salida.**
    ///
    ///  · Quien SIGUE necesita un CTA y nada más: el remedio no existe (no hay cuenta de iCloud a la que
    ///    preguntar) y el ADR es explícito en que se informa y se sigue.
    ///  · Quien VUELVE necesita reintentar, porque su destino —`WelcomeRestoreView` con iCloud apagado—
    ///    ofrece «Abrir Ajustes» y «Empezar desde cero», y sin un botón que re-mida las dos pantallas se
    ///    devuelven la pelota. El remedio aquí sí existe: encender iCloud y volver a preguntar.
    @ViewBuilder
    private var noICloudContent: some View {
        switch unverifiedExit {
        case .proceedWatchingTheMirror:
            noticeContent(
                icon: "icloud.slash",
                title: L10n.Welcome.PrivateICloud.noAccountTitle,
                body: noICloudBody,
                cta: unverifiedExitLabel,
                identifier: "welcome_private_icloud_no_account",
                action: exitWithoutValidating)
        case .returnWithoutClaimingAWipe:
            twoWayNoticeContent(
                icon: "icloud.slash",
                title: L10n.Welcome.PrivateICloud.noAccountTitle,
                body: noICloudBody,
                // `Restore.retry` («Reintentar búsqueda») y no `wipeRetry`: aquí se vuelve a BUSCAR, que
                // es el mismo gesto que en `.unreachable`. `wipeRetry` reintenta un BORRADO, y en esta
                // pantalla no hay ninguno que reintentar.
                primary: L10n.Welcome.Restore.retry,
                secondary: unverifiedExitLabel,
                identifier: "welcome_private_icloud_no_account",
                primaryAction: { phase = .checking },
                secondaryAction: exitWithoutValidating)
        }
    }

    /// **El aviso que este ticket devuelve a su sitio: «aquí ya hay datos».**
    ///
    /// Sin cifras, a diferencia de su gemela de iCloud, y es deliberado: allí las cifras son el histórico
    /// que la persona escribió y sostienen la decisión de traerlo de vuelta; aquí lo que hay son las
    /// categorías que sembró la app y los grupos de la etapa anterior, y un «12 categorías» sugeriría un
    /// trabajo propio que nadie hizo. Lo que importa decir es que hay algo y que empezar de cero se lo
    /// lleva.
    ///
    /// **Reusa `noticeShell` en vez de repetir su cuerpo**, que es lo que la review pidió: las dos
    /// pantallas nuevas eran cuarenta líneas calcadas de ese helper, y fue esa copia la que dejó los
    /// identificadores escritos a mano y por tanto divergentes del molde del fichero.
    ///
    /// Dos salidas, la que no destruye arriba — el mismo orden que `foundContent` y por el mismo motivo.
    /// **No hay tercera**: «traer mis datos» no existe aquí porque no hay nada que traer.
    private func foundDeviceContent(iCloudUnverified: Bool) -> some View {
        noticeShell(icon: "iphone.gen3",
                    title: L10n.Welcome.PrivateICloud.foundDeviceTitle,
                    body: L10n.Welcome.PrivateICloud.foundDeviceBody,
                    identifier: "welcome_private_icloud_found_device") {
            VStack(spacing: DS.Spacing.sm) {
                // **«Dejarlo como está» y no «Mejor no»**: nadie le ha preguntado «¿seguro?» todavía —
                // acaba de elegir «Es mi primera vez»— y el mismo label a una pantalla de distancia lleva
                // a otro sitio (allí retrocede una fase; aquí sale de la puerta). Dos destinos con el
                // mismo texto es como se pulsa el equivocado.
                YalaPrimaryButton(L10n.Welcome.PrivateICloud.foundDeviceKeep) {
                    leaveGate()
                }
                .accessibilityIdentifier("welcome_private_icloud_keep_device")

                destructiveButton(L10n.Welcome.PrivateICloud.wipeAction,
                                  identifier: "welcome_private_icloud_wipe_device") {
                    phase = .confirmingDeviceWipe(iCloudUnverified: iCloudUnverified)
                }
            }
        }
    }

    /// 2.ª confirmación del corpus del teléfono. Mismo título que la de iCloud —el texto de «Vaciar datos»
    /// de Ajustes, que es donde ese copy ya vive— y cuerpo propio: el de arriba promete que lo borrado se
    /// va «de iCloud», y en este camino iCloud no se toca.
    private func confirmDeviceContent(iCloudUnverified: Bool) -> some View {
        noticeShell(icon: "trash",
                    title: L10n.Settings.wipeDataSecondConfirmTitle,
                    body: L10n.Welcome.PrivateICloud.wipeDeviceConfirmBody,
                    identifier: "welcome_private_icloud_confirm_device") {
            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.Welcome.PrivateICloud.wipeConfirmKeep) {
                    phase = .foundDevice(iCloudUnverified: iCloudUnverified)
                }
                .accessibilityIdentifier("welcome_private_icloud_confirm_keep_device")

                destructiveButton(L10n.Settings.deleteAllDataAction,
                                  identifier: "welcome_private_icloud_confirm_wipe_device") {
                    phase = .wipingDevice(iCloudUnverified: iCloudUnverified)
                }
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

    /// El aviso con CIFRAS y sus TRES salidas (decisión de Jürgen, 2026-09-09).
    ///
    /// El orden de los botones no es estético: **primero la salida que no destruye nada**. Quien llega
    /// aquí quería empezar de cero y se acaba de enterar de que tiene un histórico; el camino más probable
    /// —y el único irreversible al revés— es quedárselo.
    private func foundContent(_ corpus: ICloudPersonalCorpus) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 44)) // A11Y-DT: icono decorativo hero, tamaño fijo (patrón del flow)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Welcome.PrivateICloud.foundTitle)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(Self.countsLine(corpus))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    // El separador `·` lo lee VoiceOver como un carácter suelto, o lo salta. Es la cifra
                    // que sostiene una decisión irreversible, así que se le da su lectura hablada.
                    .accessibilityLabel(Self.countsLine(corpus, forVoiceOver: true))
                Text(L10n.Welcome.PrivateICloud.foundBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .accessibilityIdentifier("welcome_private_icloud_found")

            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.Welcome.PrivateICloud.restoreAction) {
                    onRestore()
                }
                .accessibilityIdentifier("welcome_private_icloud_restore")

                destructiveButton(L10n.Welcome.PrivateICloud.wipeAction,
                                  identifier: "welcome_private_icloud_wipe") {
                    phase = .confirmingWipe(corpus)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    /// 2.ª confirmación. Copy reusado del «Vaciar datos» de Ajustes, que es donde ese texto ya vive.
    private func confirmContent(_ corpus: ICloudPersonalCorpus) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "trash")
                .font(.system(size: 44)) // A11Y-DT: icono decorativo hero, tamaño fijo (patrón del flow)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Settings.wipeDataSecondConfirmTitle)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(L10n.Welcome.PrivateICloud.wipeConfirmBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .accessibilityIdentifier("welcome_private_icloud_confirm")

            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.Welcome.PrivateICloud.wipeConfirmKeep) {
                    phase = .found(corpus)
                }
                .accessibilityIdentifier("welcome_private_icloud_confirm_keep")

                destructiveButton(L10n.Settings.deleteAllDataAction,
                                  identifier: "welcome_private_icloud_confirm_wipe") {
                    phase = .wiping
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private func noticeContent(icon: String, title: String, body: String, cta: String,
                               identifier: String, action: @escaping () -> Void) -> some View {
        noticeShell(icon: icon, title: title, body: body, identifier: identifier) {
            YalaPrimaryButton(cta) { action() }
                .accessibilityIdentifier(identifier + "_cta")
        }
    }

    private func twoWayNoticeContent(icon: String, title: String, body: String,
                                     primary: String, secondary: String, identifier: String,
                                     primaryAction: @escaping () -> Void,
                                     secondaryAction: @escaping () -> Void) -> some View {
        noticeShell(icon: icon, title: title, body: body, identifier: identifier) {
            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(primary) { primaryAction() }
                    .accessibilityIdentifier(identifier + "_cta")
                Button { secondaryAction() } label: {
                    Text(secondary)
                        .font(DS.Typography.label)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier(identifier + "_secondary")
            }
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
            .accessibilityIdentifier(identifier)

            actions()
                .padding(.horizontal, DS.Spacing.xl)
        }
    }

    /// El botón que destruye. **Con `role: .destructive` y con el área táctil estándar**, que es lo que le
    /// falta al molde del flujo (`WelcomeRestoreView.startFresh` es un `Button` pelado sobre el texto):
    /// aquí abre un borrado irreversible del iCloud de la persona, y un control así no puede tener menos
    /// superficie que el que no destruye.
    private func destructiveButton(_ title: String, identifier: String,
                                   action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(DS.Typography.label)
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - La puerta

    /// **La salida de «no se pudo preguntar», y es el ÚNICO sitio que bifurca.** Las dos fases que la
    /// ofrecen llaman aquí y no a uno de los dos desenlaces: quien monta la puerta ya lo decidió en su
    /// `unverifiedExit`, y repetir ese `switch` en cada fase es como una de las dos se queda atrás.
    private func exitWithoutValidating() {
        switch unverifiedExit {
        case .proceedWatchingTheMirror: continueWithoutValidating()
        case .returnWithoutClaimingAWipe: returnWithoutClaimingAWipe()
        }
    }

    /// **Volver sin declarar ningún borrado** (decisión de Jürgen, 2026-09-14, opción (a) del ticket).
    ///
    /// Quien llega aquí por «Restaurar → Empezar desde cero» YA confirmó el borrado dos veces, y a iCloud
    /// no se le pudo preguntar. Las dos cosas que **no** hace son el ticket entero:
    ///
    ///  · **No sale al onboarding.** Para estar en esa puerta hubo relanzamiento, el store espeja y las
    ///    filas importadas ya están en el teléfono: seguir dejaría a la persona con sus datos viejos
    ///    enteros bajo un copy que le prometió lo contrario. Es el bug del ticket padre por otra rama.
    ///  · **No escribe el testigo del espejo tardío**, y ése era el daño encadenado —peor que el hueco—:
    ///    su aviso borra con `performICloudCorpusWipe(.handover)`, o sea preferencias y purga del dominio
    ///    de Grupos, que es justo el scope que quien activa CONSERVANDO sus grupos no puede recibir.
    ///
    /// **Sí retira el arm, y eso no es alcance nuevo: es no-regresión.** La salida de hoy ya lo hacía en
    /// este mismo punto. Y es correcto por su propio criterio: un borrado que ni siquiera se pudo medir no
    /// deja nada a medias que proteger, mientras que un arm superviviente lo reanuda **a ciegas** en el
    /// arranque siguiente (`ContentView.runLateICloudMirrorCheck`), con ese mismo `.handover`.
    private func returnWithoutClaimingAWipe() {
        discardPendingWipe()
        onBack()
    }

    /// El cuerpo del estado K. **Cambia con el desenlace porque cambia el hecho que describe**: el de
    /// siempre dice «Puedes seguir: por ahora tus datos se quedan aquí», y en la puerta que vuelve atrás
    /// eso sería prometer un camino que no se ofrece.
    ///
    /// Y el de la puerta que vuelve **no es el mismo que el de `.unreachable`**, aunque las dos cuenten
    /// «no pudimos mirar, así que no borramos nada»: la review adversarial midió que con un cuerpo
    /// compartido esta pantalla repetía su propio título y perdía la causa —iCloud apagado— que su botón
    /// de reintentar necesita para significar algo.
    private var noICloudBody: String {
        switch unverifiedExit {
        case .proceedWatchingTheMirror: return L10n.Welcome.PrivateICloud.noAccountBody
        case .returnWithoutClaimingAWipe:
            return L10n.Welcome.PrivateICloud.discardUnverifiedNoAccountBody
        }
    }

    /// Y el de la red caída, por lo mismo: `errorBody` dice «Inténtalo otra vez **antes de seguir**», y
    /// aquí no hay ningún «seguir». El de recambio nombra el reintento igual que él, porque ese botón
    /// sigue estando y es el único que de verdad resuelve — un cuerpo que solo ofreciera volver empujaría
    /// al camino que no arregla nada.
    private var unreachableBody: String {
        switch unverifiedExit {
        case .proceedWatchingTheMirror: return L10n.Welcome.PrivateICloud.errorBody
        case .returnWithoutClaimingAWipe: return L10n.Welcome.PrivateICloud.discardUnverifiedBody
        }
    }

    /// El label de esa salida. «Seguir así» describe lo que hace la de siempre y **miente** en la otra.
    private var unverifiedExitLabel: String {
        switch unverifiedExit {
        case .proceedWatchingTheMirror: return L10n.Welcome.PrivateICloud.noAccountCta
        case .returnWithoutClaimingAWipe: return L10n.Welcome.PrivateICloud.discardUnverifiedBack
        }
    }

    /// Seguir sin haber podido validar. **Escribe el testigo**, que es la mitad que impide que el bug
    /// vuelva por la puerta de atrás: cuando el espejo pueda sincronizar, el aviso se dará entonces.
    ///
    /// Lo comparten los dos desenlaces en los que no se pudo preguntar —sin cuenta y sin red— porque el
    /// hecho que recuerdan es el mismo: *esta persona siguió adelante sin que pudiéramos comprobarlo*.
    ///
    /// **Y con el teléfono medido, un borrado a medias deja de estarlo** (`unverifiedExitRetiresHalfway`): la marca antes
    /// que el arm, como en `measure()`.
    private func continueWithoutValidating() {
        StorageModePersistence.markPrivateChoseWithoutICloud()
        if WelcomePrivateICloudGateLogic.unverifiedExitRetiresHalfway(halfwayWipe, measuredDevice: deviceCorpus != nil) {
            StorageModePersistence.clearICloudCorpusWipeLeftHalfway()
            StorageModePersistence.clearICloudCorpusWipeArm()
        } else {
            discardPendingWipe()
        }
        onProceed()
    }

    /// **Toda salida de la puerta que no deja un borrado a medias retira el arm.**
    ///
    /// El arm existe para sobrevivir a un KILL con el borrado en vuelo, y solo a eso: mientras está
    /// puesto, `ContentView.runLateICloudMirrorCheck` lo REANUDA A CIEGAS —borra la zona de CloudKit y
    /// las filas locales, sin preguntar—. Que sobreviva a una salida deliberada es la diferencia entre
    /// una red y una trampa.
    ///
    /// Hasta el 2026-09-14 nadie lo retiraba en estas salidas, y no mordía por un accidente: con el mount
    /// neutro toda salida RELANZA y persiste un destino, y `presentNextOnboardingScreen` retira el arm
    /// junto con él. **La puerta alcanzada con el espejo ya adjunto no relanza**, así que esa red no
    /// existe ahí — y ese camino dejó de ser una esquina el día que «Restaurar → Empezar desde cero»
    /// empezó a entrar por aquí. El desenlace medido: la persona sale por «Traer mis datos», restaura su
    /// histórico, termina, y el arranque siguiente se lo borra entero sin una sola pregunta.
    ///
    /// **Desde `.wipeFailed` no se llega aquí**: ese fallo SÍ deja algo pendiente —se puede reintentar— y
    /// su arm lo retira `leaveGate`, que es donde consta que la persona se va.
    ///
    /// **Y desarma con `disarm()`, no con `clearICloudCorpusWipeArm` a secas**: la zona puede haberse ido en un intento
    /// anterior del mismo arm —un kill tras borrarla, y la puerta vuelve a medir sin red—, y retirar el arm a secas se la
    /// llevaba con él.
    private func discardPendingWipe() {
        disarm()
    }

    /// **Retirar el arm sin olvidar la zona** (ticket `private-gate-leave-after-a-halfway-wipe-forgets-the-zone`). Si el
    /// borrado ya se la llevó y este montaje recuerda los borrados a medias, queda «a medias»
    /// (`disarmFailedICloudCorpusWipe`, el mismo desarme que el aviso tardío). Si no se la llevó, es retirar el arm.
    ///
    /// La puerta privada de la activación retira a secas: su borrado es solo de zona, así que con la zona ida ya
    /// terminó, y lo que queda en el teléfono es de quien activa.
    private func disarm() {
        if halfwayWipe.reachesDeviceRows {
            StorageModePersistence.disarmFailedICloudCorpusWipe()
        } else {
            StorageModePersistence.clearICloudCorpusWipeArm()
        }
    }

    /// Salir de la puerta. **Retira el arm desde cualquier fase** (ticket `private-gate-back-from-found-keeps-a-resumed-arm`).
    ///
    /// El arm existe para sobrevivir a un KILL con el borrado en vuelo, y solo a eso. Quien toca «volver» ha retirado su
    /// petición, sea desde un fallo, desde «no se pudo preguntar» o desde «Encontramos datos tuyos». Hasta ese ticket
    /// solo desarmaban los fallos: tras un kill en `.wiping`, el arranque traía de vuelta la puerta con el arm puesto,
    /// la puerta volvía a medir y enseñaba `.found`; volver desde ahí y crear una cuenta en la nube dejaba el arm vivo, y
    /// el arranque siguiente lo reanudaba a ciegas con `.handover` — iCloud privado, lo del teléfono y los grupos.
    ///
    /// **Desde `.wiping` y `.wipingDevice` no se puede llegar aquí**, y esa es la otra mitad de la kill-safety: el
    /// «volver» está oculto mientras la operación está en vuelo (`backAction`), así que el arm solo sobrevive a un KILL
    /// —que es para lo que existe— y nunca a un abandono. Por eso no hay condición: la única fase que la necesitaría no
    /// tiene salida.
    ///
    /// **Desarma con `disarm()`**: si la zona ya se había ido —en el intento que falló delante o en el que cortó un
    /// kill—, el borrado dejó algo a medias (iCloud vacío, lo del teléfono no) y `disarm()` lo deja escrito en vez de
    /// olvidarlo (ticket `private-gate-leave-after-a-halfway-wipe-forgets-the-zone`). Qué lo termina depende del montaje
    /// (`halfwayWipe`): en el Welcome, el aviso tardío; en «Empezar desde cero», esta misma puerta al volver.
    ///
    /// **Y no se lleva el neutro durable del cierre de sesión** (`performSignOutWipeIfArmed`), que es lo que hace seguro
    /// desarmar desde todas las fases: `clearICloudCorpusWipeArm` solo retira el neutro que armó el propio borrado.
    private func leaveGate() {
        disarm()
        onBack()
    }

    /// La fase de «faltan cambios de grupos», si el fallo fue ése. `nil` para cualquier otro: entonces manda el fallo de
    /// siempre. El detalle lo puso la subida en `CloudSessionSignOut.freshStartGroupsBlock` justo antes de devolver.
    private func groupsPendingPhase(for failure: String?, retry: GroupsPendingRetry) -> Phase? {
        guard failure == CloudSessionSignOut.freshStartGroupsPendingFailure,
              let block = CloudSessionSignOut.shared.freshStartGroupsBlock else { return nil }
        return .groupsPending(block, retry: retry)
    }

    /// El trabajo de cada fase. Lo llama `.task(id: phase)`, así que la cancelación es real.
    private func runPhase() async {
        switch phase {
        case .checking where entry == .wipeDevice:
            // El alert del shell ya confirmó el borrado: se va directo a él, sin preguntarle nada a iCloud. Solo con su
            // permiso de un uso; sin él no se borra nada y se vuelve atrás.
            guard Self.consumeDeviceWipeHandoff() else {
                onBack()
                return
            }
            // **`iCloudUnverified` sale del testigo que dejó la puerta, no de un literal.** Al alert del shell se llega
            // tras la puerta por `.measure`: si iCloud no contestó, esa puerta ya escribió el testigo del espejo tardío
            // (`continueWithoutValidating`), y la salida de este borrado tiene que volver a dejarlo; si contestó, no.
            // Clavarlo a `false` perdía el aviso del espejo tardío de quien no pudo validar.
            let unverified = StorageModePersistence.privateChoseWithoutICloud()
            phase = .wipingDevice(iCloudUnverified: unverified)
        case .checking: await measure()
        case .wiping: await wipe()
        case .wipingDevice(let unverified): await wipeDevice(iCloudUnverified: unverified)
        default: return
        }
    }

    /// Medir y decidir. **No escribe nada**: quien escribe es el borrado, y solo si el usuario lo pide dos
    /// veces.
    private func measure() async {
        // **Hermeticidad ANTES de la red, no después.** Bajo XCUITest no se toca CloudKit en ningún punto
        // del Welcome; decidirlo dentro de `decide` dejaba el `await` de la sonda igualmente pagado, y que
        // hoy no muerda es un accidente del simulador (sin cuenta iCloud), no el invariante que este
        // fichero afirma. Es el mismo orden que `WelcomeFlowContainer.task` y `WelcomeGroupsGateView`.
        guard !SwiftDataConfiguration.isUITesting else {
            onProceed()
            return
        }
        // **Lo que ya está en el teléfono se cuenta DESPUÉS de la sonda, no antes, y el orden es lo que
        // hace verdad la palabra «vivo».** Medirlo primero deja un muestreo de hace varios segundos —lo
        // que tarde CloudKit— y en una sesión solo-grupos el canal sigue aplicando pulls durante ese rato:
        // store vacío en t0 + iCloud vacío ⇒ se sale de largo ⇒ onboarding de cero encima de las filas que
        // llegaron mientras se preguntaba. Es el bug de este ticket en una ventana estrecha, y cerrarla
        // cuesta cuatro `fetchCount`.
        // **Aquí NO hay pre-filtro, y esa es la segunda corrección del mismo sitio.** El primer diseño
        // preguntaba `isICloudAvailable()`, que mide iCloud Drive; la review lo cambió por «¿este mount
        // espeja?» (`mirrorWillSync`) — y ese término apaga la puerta **justo en el caso principal del
        // ticket**: en instalación fresca el mount es `.neutralNoMirror`, que no adjunta espejo AHORA
        // aunque lo vaya a adjuntar en el arranque siguiente, tras el relanzamiento. Con él, la rama
        // privada volvía a salir sin preguntar nada.
        //
        // La pregunta de esta pantalla no es «¿hay espejo ahora?» sino «¿el iCloud de este Apple ID tiene
        // datos que van a acabar en este dispositivo?», y a eso solo contesta CloudKit. Quien declara que
        // no hay cuenta es él, con su `notAuthenticated`. (`mirrorWillSync` sigue siendo el pre-filtro
        // correcto del aviso TARDÍO, donde la pregunta sí es sobre el espejo que ya está puesto.)
        let outcome = await ICloudPersonalCorpusProbe.probe()
        // La cancelación es COOPERATIVA y la sonda solo la mira entre páginas: sin este guard, quien toca
        // «volver» mientras CloudKit contesta vería la pantalla cambiar bajo el dedo, o peor, saldría del
        // Welcome solo.
        guard !Task.isCancelled else { return }
        let deviceHasData = deviceCorpus?.hasData() ?? false

        switch WelcomePrivateICloudGateLogic.decide(skipValidation: false,
                                                    outcome: outcome,
                                                    deviceHasData: deviceHasData) {
        case .proceed:
            // **Acaba de medir que no queda nada que borrar, así que el arm se va con la medida.** Este
            // es el desenlace de quien vuelve aquí tras un kill con el borrado a medias: si la zona ya
            // se vació, dejar el arm puesto hace que `runLateICloudMirrorCheck` «reanude» el borrado en
            // un arranque posterior y se lleve por delante lo que la persona haya creado desde entonces.
            // Lo que se pierde al retirarlo está acotado y tiene ticket
            // (`late-icloud-wipe-can-re-export-between-its-two-halves`): reaparición, nunca pérdida.
            //
            // **Y el borrado a medias se resuelve aquí, según el montaje** (ticket
            // `private-gate-leave-after-a-halfway-wipe-forgets-the-zone`): donde la puerta midió también el teléfono,
            // no queda mitad y la marca se va; en «Empezar desde cero», iCloud vacío con la marca puesta es el borrado
            // sin terminar, y se termina en vez de seguir encima de las filas importadas.
            switch WelcomePrivateICloudGateLogic.afterEmptyMeasure(
                halfwayWipe,
                leftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway(),
                zoneDone: StorageModePersistence.isICloudCorpusWipeZoneDone(),
                measuredDevice: deviceCorpus != nil
            ) {
            case .finishHalfwayWipe:
                phase = .wiping
            case .proceed(retiresHalfway: true):
                // La marca antes que el arm: un kill entre las dos deja el arm, y el arranque vuelve a esta puerta.
                StorageModePersistence.clearICloudCorpusWipeLeftHalfway()
                StorageModePersistence.clearICloudCorpusWipeArm()
                onProceed()
            case .proceed(retiresHalfway: false):
                discardPendingWipe()
                onProceed()
            }
        case .foundData(let corpus):
            phase = .found(corpus)
        case .foundDeviceData(let unverified):
            phase = .foundDevice(iCloudUnverified: unverified)
        case .noICloud:
            phase = .noICloud
        case .unreachable:
            phase = .unreachable
        }
    }

    /// Borrar. **El orden es el de `performSignOutWipeIfArmed` y no se puede reordenar:** armar ANTES de
    /// la primera llamada, desarmar DESPUÉS de que el borrado confirme. Un kill en medio deja el arm
    /// puesto y el arranque siguiente vuelve a esta puerta, que **vuelve a medir en vez de reanudar a
    /// ciegas**: si la zona ya se borró, la sonda la ve vacía y sale al onboarding limpio; y si no, se le
    /// vuelve a preguntar a la persona, que es lo honesto cuando no sabemos qué llegó a pasar.
    ///
    /// La limpieza de residuales va **después** del borrado y no antes, por el mismo motivo que en
    /// `ShellDataAlertsModifier`: si el borrado falla, los datos siguen ahí y quitarle el nombre y la
    /// divisa sería cobrarle por un borrado que no ocurrió.
    ///
    /// **La cancelación solo manda si el borrado no llegó a escribir** (ticket
    /// `private-gate-remote-wipe-can-strand-its-arm`). Con el scope del Welcome, el propio borrado se lleva
    /// `hasCompletedOnboarding` y eso puede cancelar esta `.task` con todo ya borrado; un `guard !Task.isCancelled`
    /// a secas dejaba el arm puesto y las preferencias residuales sin limpiar sobre un corpus ya borrado. La tabla
    /// entera está en `WelcomePrivateICloudGateLogic.gateWipeSettles`: cancelado sin tocar nada vuelve; cancelado
    /// después de borrar termina. Y el que vuelve, vuelve desarmado.
    ///
    /// **«Termina» es lo DURABLE, no la navegación** (review adversarial del 2026-09-27). Esta `.task` solo se
    /// cancela si la puerta se desmonta —durante `.wiping` no hay «volver» y solo esta función cambia la fase—, así
    /// que cancelada ya no hay puerta en pantalla. Una invitación de grupo que llega a mitad del borrado sustituye el
    /// step del Welcome y la desmonta: un `onProceed()` ahí saldría en nombre de una pantalla que ya no está —con su
    /// relanzamiento y su `exit(0)` al pasar a segundo plano— encima de la invitación que la persona acaba de abrir.
    /// Por eso la cancelación se lee UNA vez y decide las dos cosas: si se aplica el desenlace y si se navega.
    ///
    /// **La marca de la zona también se lee UNA vez, y decide dos cosas**: si el desenlace se aplica y qué cuenta la
    /// pantalla de fallo (ticket `private-gate-wipe-failure-copy-claims-icloud-is-intact`). Se lee de la marca y no del
    /// motivo: un reintento desde el estado a medias que falla EN la zona devuelve un error de CloudKit con la zona ya
    /// borrada por el intento anterior, y decidir por el motivo le diría «intactos».
    private func wipe() async {
        StorageModePersistence.armICloudCorpusWipe()
        let failure = await performWipe()
        let cancelled = Task.isCancelled
        let zoneGone = StorageModePersistence.isICloudCorpusWipeZoneDone()
        guard WelcomePrivateICloudGateLogic.gateWipeSettles(
            failed: failure != nil,
            cancelled: cancelled,
            zoneGone: zoneGone
        ) else {
            // **Cancelado sin tocar nada: vuelve DESARMADO.** Una cancelación no es un kill: el borrado volvió y
            // consta que no llegó a la zona, así que el arm no protege nada. Dejarlo puesto hace que
            // `ContentView.runLateICloudMirrorCheck` lo reanude A CIEGAS —zona, filas y purga de Grupos— si la
            // persona acaba el onboarding por otro camino, como la invitación que desmontó esta puerta.
            StorageModePersistence.clearICloudCorpusWipeArm()
            return
        }
        guard failure == nil else {
            // El copy suma el borrado a medias de antes: un reintento que falla antes de la zona no la devuelve.
            let failureZoneGone = WelcomePrivateICloudGateLogic.failureFoundZoneGone(
                zoneDone: zoneGone,
                leftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway()
            )
            phase = groupsPendingPhase(for: failure, retry: .iCloud) ?? .wipeFailed(zoneGone: failureZoneGone)
            return
        }
        if clearsResidualPreferencesOnWipe {
            OnboardingResetHelper.clearResidualPreferencesForFreshStart()
        }
        // **Un borrado que llega a las filas y termina bien resuelve el «a medias»** (ticket
        // `private-gate-leave-after-a-halfway-wipe-forgets-the-zone`). `wipeAllUserData` ya retira la marca cuando hay
        // filas; sin filas el borrado sale antes de llamarlo, y la marca se quedaba sobre un teléfono y un iCloud vacíos.
        // Antes que el arm, por lo mismo que en `measure()`.
        if halfwayWipe.reachesDeviceRows {
            StorageModePersistence.clearICloudCorpusWipeLeftHalfway()
        }
        StorageModePersistence.clearICloudCorpusWipeArm()
        guard !cancelled else { return }
        onProceed()
    }

    /// Borrar lo que hay EN EL TELÉFONO.
    ///
    /// **NO arma `armICloudCorpusWipe`, y no es un olvido: armarlo era un defecto ALTA de la review.** Ese
    /// testigo tiene DOS consumidores y solo uno hace lo que su docblock promete. `presentNextOnboardingScreen`
    /// vuelve a esta puerta y re-mide, sí; pero `ContentView.runLateICloudMirrorCheck` lo **reanuda a
    /// ciegas** con `performICloudCorpusWipe()`, que borra la ZONA de CloudKit del Apple ID. O sea: un kill
    /// a mitad de un borrado LOCAL —confirmado dos veces sobre un copy que dice que iCloud no se toca—
    /// acababa borrando el iCloud de la persona sin que nadie lo pidiera, y en un device solo-grupos ese
    /// camino es el que corre (`hasCompletedOnboarding` ya es `true`, así que el arranque ni siquiera pasa
    /// por la puerta).
    ///
    /// **Y la kill-safety no se pierde por quitarlo**, que es lo que hacía falta comprobar antes: si el
    /// borrado muere a mitad, `wipeAllUserData` ya se llevó `hasCompletedOnboarding`, así que el arranque
    /// siguiente enseña el Welcome; el mount sigue siendo neutro —lo sostiene la marca de la sesión
    /// solo-grupos, que este camino no toca— y la puerta vuelve a medir cuando la persona vuelva a elegir
    /// privado. Lo que se pierde es una pantalla, no datos.
    ///
    /// **iCloud no se toca aquí.** El aviso vino de las filas locales, así que pedirle a CloudKit que
    /// borre una zona sería, en el caso normal de este camino —sin cuenta o sin red—, un fallo seguro que
    /// dejaría a la persona en la pantalla de error sin haber nada que borrar allí.
    ///
    /// **Sin `guard !Task.isCancelled` después del borrado, y también es una corrección de la review:** el
    /// propio `wipeAllUserData` borra `hasCompletedOnboarding`, lo que dispara el `onChange` de
    /// `ContentView` y puede cancelar esta `.task` **con el borrado ya committeado**. Volver ahí dejaba el
    /// corpus borrado y ninguna de sus consecuencias aplicadas: ni las prefs residuales, ni el testigo del
    /// espejo tardío, ni la salida. Un borrado consumado tiene que terminar su trabajo.
    ///
    /// **El final se bifurca, y esa es la mitad que impide que el bug vuelva por detrás:** si a iCloud no
    /// se le pudo preguntar, salir por `continueWithoutValidating` deja escrito el testigo del espejo
    /// tardío. Sin él, el día que iCloud vuelva le bajaría el histórico del Apple ID encima del
    /// onboarding recién hecho — que es este mismo ticket, con otro disfraz.
    ///
    /// **Y esa salida NO pasa por `exitWithoutValidating`, a propósito** (2026-09-14). El desenlace que
    /// vuelve atrás existe para no declarar un borrado que no ocurrió, y aquí ocurrió: el teléfono está
    /// vacío. Con lo borrado abajo, el testigo del espejo tardío es justo lo que hace falta. La cuestión
    /// además no se plantea hoy: los dos montajes de la activación pasan `deviceCorpus: nil`, así que esta
    /// fase solo la alcanza el Welcome, que sale por `.proceedWatchingTheMirror`.
    private func wipeDevice(iCloudUnverified: Bool) async {
        // Sin corpus no hay borrado que hacer, y **el fallo seguro es NO seguir**: esta fase solo se
        // alcanza desde un aviso que este mismo paquete produjo, así que llegar aquí sin él significa que
        // algo se desconectó — y salir al onboarding diría que se borró algo que nadie borró.
        guard let deviceCorpus else {
            phase = .deviceWipeFailed(iCloudUnverified: iCloudUnverified)
            return
        }
        let failure = await deviceCorpus.wipe()
        guard failure == nil else {
            phase = groupsPendingPhase(for: failure, retry: .device(iCloudUnverified: iCloudUnverified))
                ?? .deviceWipeFailed(iCloudUnverified: iCloudUnverified)
            return
        }
        if clearsResidualPreferencesOnWipe {
            OnboardingResetHelper.clearResidualPreferencesForFreshStart()
        }
        if iCloudUnverified {
            continueWithoutValidating()
        } else {
            onProceed()
        }
    }

    // MARK: - El fallo del borrado de iCloud

    /// **Qué dice la pantalla cuando el borrado de iCloud falla** (ticket
    /// `private-gate-wipe-failure-copy-claims-icloud-is-intact`). Son dos hechos distintos:
    ///
    ///  · **Sin tocar la zona** (red, cuenta, import en vuelo): `wipeFailedBody`, «Tus datos siguen en iCloud,
    ///    intactos». Solo es verdad aquí.
    ///  · **Con la zona ya borrada** (falló el borrado de las filas del teléfono, o un reintento tras eso):
    ///    `wipeDeviceFailedBody`, «puede que parte de tus datos ya no esté y el resto siga aquí». Es el estado real:
    ///    iCloud vacío y el teléfono a medio vaciar. Hasta este ticket se le decía «intactos».
    ///
    /// Reusa la clave del fallo del teléfono, ya traducida en los 16 idiomas, en vez de una nueva: cuenta el mismo
    /// hecho. `leftHalfwayBody`, el del aviso tardío, no vale aquí: su última frase nombra «quedarte con lo que haya» y
    /// «terminar de borrarlo», y los botones de esta pantalla son «Volver a intentarlo» y «Dejarlo por ahora».
    static func wipeFailedBody(zoneGone: Bool) -> String {
        zoneGone ? L10n.Welcome.PrivateICloud.wipeDeviceFailedBody : L10n.Welcome.PrivateICloud.wipeFailedBody
    }

    // MARK: - Cifras

    /// «128 registros · 3 cuentas · 12 categorías · desde marzo de 2025». Se compone con las claves que YA
    /// existen para las cifras del restore (`welcome.restore.found*`), que son el mismo hecho contado en
    /// el mismo sitio — inventar claves gemelas para decir «3 cuentas» otra vez es exactamente cómo
    /// divergen dos pantallas que hablan de lo mismo.
    ///
    /// **Las categorías se pintan aunque parezcan un detalle**, y no es cosmético: `hasAnyData` dispara el
    /// aviso con ellas solas —alguien que dejó sus categorías y nada más— y sin esta línea esa persona
    /// veía un `Text("")` en medio de un aviso que le pide confirmar un borrado irreversible.
    ///
    /// **Y los presupuestos, por lo mismo, desde el 2026-09-21**
    /// (`restore-treats-budgets-and-groups-as-no-data`). Entraron en `hasAnyData` en ese ticket, así que
    /// heredaron exactamente el hueco que las categorías tuvieron aquí: cifra que levanta el aviso y no
    /// se enseña. **Toda cifra de `hasAnyData` tiene que tener su línea aquí** — es la invariante de esta
    /// función, y es la que un término nuevo rompe en silencio.
    ///
    /// `forVoiceOver` cambia el separador `·` —que la voz lee como un carácter suelto, o se salta— por una
    /// coma. Es el MISMO contenido: si divergiera, la pantalla y su lectura afirmarían cosas distintas.
    static func countsLine(_ corpus: ICloudPersonalCorpus, forVoiceOver: Bool = false) -> String {
        var parts: [String] = []
        if corpus.transactions > 0 {
            parts.append(corpus.truncated
                ? L10n.Welcome.PrivateICloud.foundAtLeast(corpus.transactions)
                : L10n.Welcome.Restore.foundTransactions(corpus.transactions))
        }
        if corpus.accounts > 0 {
            parts.append(L10n.Welcome.Restore.foundAccounts(corpus.accounts))
        }
        if corpus.categories > 0 {
            parts.append(L10n.Welcome.PrivateICloud.foundCategories(corpus.categories))
        }
        if corpus.budgets > 0 {
            parts.append(L10n.Welcome.Restore.foundBudgets(corpus.budgets))
        }
        if let oldest = corpus.oldestTransactionDate {
            parts.append(L10n.Welcome.PrivateICloud.foundSince(Self.monthYear.string(from: oldest)))
        }
        // **El corpus truncado sin ninguna cifra tiene que decir ALGO.** `hasAnyData` lo trata como «sí
        // hay» —el tope se agotó antes de llegar a los tipos que se cuentan— y un aviso que pide confirmar
        // un borrado irreversible no puede salir con la línea en blanco.
        if parts.isEmpty && corpus.truncated {
            parts.append(L10n.Welcome.PrivateICloud.foundUnknownAmount)
        }
        return parts.joined(separator: forVoiceOver ? ", " : " · ")
    }

    /// `DateFormatter` no es `Sendable`, así que vive en el MainActor con su única consumidora.
    private static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter
    }()
}
