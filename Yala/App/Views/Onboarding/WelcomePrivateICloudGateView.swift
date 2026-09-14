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

    @State private var phase: Phase = .checking

    private enum Phase: Equatable {
        case checking
        case found(ICloudPersonalCorpus)
        /// 2.ª confirmación. Lleva el corpus dentro para poder volver a `.found` sin re-medir si la
        /// persona se arrepiente: re-preguntar a CloudKit por retroceder sería cobrarle una espera por
        /// dudar, y el corpus no ha cambiado en esos dos segundos.
        case confirmingWipe(ICloudPersonalCorpus)
        case wiping
        case wipeFailed
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
            progressContent(text: L10n.Welcome.PrivateICloud.checking,
                            identifier: "welcome_private_icloud_checking")
        case .wiping:
            progressContent(text: L10n.Welcome.PrivateICloud.wiping,
                            identifier: "welcome_private_icloud_wiping")
        case .found(let corpus):
            foundContent(corpus)
        case .confirmingWipe(let corpus):
            confirmContent(corpus)
        case .noICloud:
            // Estado K de la matriz. **Informa y sigue** — el ADR es explícito en que no poder preguntar
            // jamás bloquea. El CTA es el que sale del Welcome, no el «volver».
            noticeContent(
                icon: "icloud.slash",
                title: L10n.Welcome.PrivateICloud.noAccountTitle,
                body: L10n.Welcome.PrivateICloud.noAccountBody,
                cta: L10n.Welcome.PrivateICloud.noAccountCta,
                identifier: "welcome_private_icloud_no_account",
                action: continueWithoutValidating)
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
            twoWayNoticeContent(
                icon: "exclamationmark.icloud",
                title: L10n.Welcome.PrivateICloud.errorTitle,
                body: L10n.Welcome.PrivateICloud.errorBody,
                primary: L10n.Welcome.Restore.retry,
                secondary: L10n.Welcome.PrivateICloud.noAccountCta,
                identifier: "welcome_private_icloud_error",
                primaryAction: { phase = .checking },
                secondaryAction: continueWithoutValidating)
        case .wipeFailed:
            // El borrado falló y los datos SIGUEN en iCloud, intactos. Continuar sería mentirle. Dos
            // salidas: reintentar, o irse — y ese «irse» es el ÚNICO sitio donde se retira el arm, porque
            // es el único donde consta que la persona ya no quiere el borrado.
            twoWayNoticeContent(
                icon: "exclamationmark.icloud",
                title: L10n.Welcome.PrivateICloud.wipeFailedTitle,
                body: L10n.Welcome.PrivateICloud.wipeFailedBody,
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
            // AQUÍ, y continuar sería mentirle. Lo que cambia es dónde están — el copy de arriba promete
            // que siguen en iCloud, y aquí eso sería falso.
            twoWayNoticeContent(
                icon: "exclamationmark.triangle",
                title: L10n.Welcome.PrivateICloud.wipeFailedTitle,
                body: L10n.Welcome.PrivateICloud.wipeDeviceFailedBody,
                primary: L10n.Welcome.PrivateICloud.wipeRetry,
                secondary: L10n.Welcome.PrivateICloud.wipeFailedBack,
                identifier: "welcome_private_icloud_wipe_failed_device",
                primaryAction: { phase = .wipingDevice(iCloudUnverified: unverified) },
                secondaryAction: leaveGate)
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

    /// Seguir sin haber podido validar. **Escribe el testigo**, que es la mitad que impide que el bug
    /// vuelva por la puerta de atrás: cuando el espejo pueda sincronizar, el aviso se dará entonces.
    ///
    /// Lo comparten los dos desenlaces en los que no se pudo preguntar —sin cuenta y sin red— porque el
    /// hecho que recuerdan es el mismo: *esta persona siguió adelante sin que pudiéramos comprobarlo*.
    private func continueWithoutValidating() {
        StorageModePersistence.markPrivateChoseWithoutICloud()
        onProceed()
    }

    /// Salir de la puerta. **Retira el arm si el borrado FALLÓ, y solo entonces.**
    ///
    /// Un borrado que falla no borró nada, así que un arm que le sobrevive no protege ningún estado a
    /// medias: solo recuerda una petición, y quien se va de esta pantalla acaba de retirarla. Sin esto,
    /// alguien que se arrepiente tras un fallo de red y elige la nube se encuentra esta misma puerta en el
    /// arranque siguiente, pidiéndole que termine un borrado que ya no quiere.
    ///
    /// **Desde `.wiping` no se puede llegar aquí**, y esa es la otra mitad de la kill-safety: el «volver»
    /// está oculto mientras la operación está en vuelo, así que el arm solo sobrevive a un KILL —que es
    /// para lo que existe— y nunca a un abandono.
    ///
    /// **No toca el neutro durable**, y eso es una corrección de la review: `clearNeutralMountArm` tiene
    /// OTRO dueño —el wipe de cierre de sesión (`performSignOutWipeIfArmed`)— y limpiarlo aquí le quitaba
    /// al device recién vaciado la única cosa que impide que el espejo se readjunte sobre el corpus del
    /// humano que se acaba de ir.
    private func leaveGate() {
        if phase == .wipeFailed || isDeviceWipeFailed {
            StorageModePersistence.clearICloudCorpusWipeArm()
        }
        onBack()
    }

    /// `if case` envuelto en una propiedad porque el `||` de arriba no admite pattern matching, y porque
    /// el hecho —«el borrado que falló fue el del teléfono»— se lee mejor con nombre. Los dos fallos
    /// retiran el arm por la misma razón: un borrado que no borró nada no deja ningún estado a medias que
    /// proteger, solo una petición que quien se va acaba de retirar.
    private var isDeviceWipeFailed: Bool {
        if case .deviceWipeFailed = phase { return true }
        return false
    }

    /// El trabajo de cada fase. Lo llama `.task(id: phase)`, así que la cancelación es real.
    private func runPhase() async {
        switch phase {
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
            onProceed()
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
    private func wipe() async {
        StorageModePersistence.armICloudCorpusWipe()
        let failure = await performWipe()
        guard !Task.isCancelled else { return }
        guard failure == nil else {
            phase = .wipeFailed
            return
        }
        if clearsResidualPreferencesOnWipe {
            OnboardingResetHelper.clearResidualPreferencesForFreshStart()
        }
        StorageModePersistence.clearICloudCorpusWipeArm()
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
            phase = .deviceWipeFailed(iCloudUnverified: iCloudUnverified)
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
