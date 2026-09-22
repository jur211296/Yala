//
//  WelcomeRestoreView.swift
//  Yala
//
//  A4 — Rama B del Welcome Chooser. "Ya tengo cuenta" → restore desde iCloud.
//
//  State machine: searching → found / importIncomplete / notFound / cloudPaused / cloudUnverified /
//  wiped / iCloudDisabled / error. Una búsqueda que termina VACÍA se reparte entre cuatro de ellos y
//  hacen falta DOS decisiones puras, en este orden: `RestoreImportSettlement` mira el import de
//  CloudKit y aparta el caso en el que el vacío todavía no es cierto (`.importIncomplete`), y solo
//  entonces `WelcomeRestoreEmptyOutcome` reparte el resto. Ninguno es el mismo con otro copy: afirman
//  hechos distintos —y a veces opuestos— sobre los datos del usuario.
//  Cada transición a state está gateada por `Task.isCancelled` para evitar
//  resume sobre vista no presentada (race con CKShare, dismiss user, app background).
//

import SwiftData
import SwiftUI

struct WelcomeRestoreView: View {

    enum ViewState: Equatable {
        case searching
        case found(ICloudAccountSummary)
        /// Búsqueda vacía y **nada que impida afirmarlo**: el copy de siempre. Aquí caen el usuario
        /// realmente nuevo y el teléfono al que CloudKit no contestó, y la señal del import no los
        /// separa — por eso el texto no cambia y la red es el diálogo del gesto destructivo
        /// (`notFoundView`, con la medición de por qué pregunta siempre).
        case notFound
        /// El tope se agotó **con un import de CloudKit en marcha**: los datos EXISTEN y están bajando.
        /// Caso propio porque afirma lo contrario que `.notFound`, y hasta el 2026-09-20 se pintaba con
        /// el copy de aquél — «No hay datos asociados a tu cuenta de iCloud» a alguien cuyo histórico
        /// estaba entrando en ese mismo momento.
        case importIncomplete
        /// Búsqueda vacía **porque la nube está en pausa**, no porque no haya datos: el kill-switch
        /// remoto está puesto y el faro dice que este Apple ID ya tiene cuenta nube. Caso propio y no
        /// un `.notFound` con otro copy — los dos afirman hechos OPUESTOS sobre los datos del usuario
        /// (`WelcomeRestoreEmptyOutcome`).
        case cloudPaused
        /// Búsqueda vacía **sin que hayamos podido comprobar nada**: el servidor nunca contestó en esta
        /// instalación (reinstalar se lleva el snapshot de remote-config, y sin red el fetch tampoco
        /// llega). Ni afirma que los datos existan ni que falten — que es justo lo que sabemos.
        case cloudUnverified
        case wiped
        case iCloudDisabled
        case error
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var state: ViewState = .searching
    /// El intento de restauración vigente, acuñado por `startSearch()` al encender la señal. Es lo
    /// único que autoriza a cerrar la ventana de sesión, y **la pantalla de progreso no se monta sin
    /// él** — ver el `case .searching` del body, donde está el porqué.
    @State private var flowToken: ICloudRestoreSessionSignal.FlowToken?
    @State private var showStartFreshConfirm: Bool = false
    @State private var refreshRotation: Double = 0

    var onContinueWithSummary: (ICloudAccountSummary) -> Void
    var onStartFresh: () -> Void
    var onOpenSettings: () -> Void
    var onBack: () -> Void

    /// Computed: `if case` no es válido dentro de `ToolbarItem` content closure.
    ///
    /// `.cloudPaused` lo lleva por la MISMA razón que `.notFound`: reintentar es lo único que puede
    /// cambiar el desenlace — allí porque el import de CloudKit puede no haber terminado, aquí porque
    /// el kill se conmuta desde el backend y el re-encendido llega sin que la app haga nada.
    /// `.cloudUnverified` con más motivo todavía: lo que falta es la red, y volver a preguntar es
    /// literalmente lo único que puede resolverlo. Y `.importIncomplete` es el caso más claro de todos:
    /// lo que falta es TIEMPO, y volver a buscar es esperar un poco más con los conteos a la vista.
    ///
    /// **`.iCloudDisabled` entra el 2026-09-20 y lo cazó la review**: era el único estado de los que
    /// pueden tener datos que no ofrecía reintentar, y su botón primario manda a Ajustes. `startSearch`
    /// cuelga de un `.task` que corre una vez, así que quien enciende iCloud y vuelve se encuentra la
    /// misma pantalla sin forma de repetir la búsqueda — el remedio que la propia pantalla recomienda
    /// no tenía cómo surtir efecto.
    private var showRefreshToolbar: Bool {
        switch state {
        case .notFound, .importIncomplete, .cloudPaused, .cloudUnverified, .iCloudDisabled, .error:
            return true
        default: return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                switch state {
                case .searching:
                    // **La espera no se monta hasta que hay intento, y ese `if` es la mitad del
                    // arreglo de `restore-back-and-reenter-closes-the-live-session-window`.**
                    // `state` nace en `.searching`, así que sin la puerta esta pantalla arrancaría su
                    // espera de 90 s en el PRIMER render — antes de que `startSearch()` haya mirado
                    // iCloud ni el wipe. Desde que `.iCloudDisabled` ofrece reintentar (2026-09-20),
                    // quien enciende iCloud y recarga tenía DOS esperas vivas, y la fantasma apagaba la
                    // ventana de la buena. **El motivo cambió de mitad el 2026-09-21**: aquella espera
                    // sobrevivía al desvío a `.wiped` o `.iCloudDisabled` porque `forceFetchAndWait` no
                    // observaba cancelación, y ahora sí la observa — la puerta se queda porque lo que
                    // evita es MONTARLA, que es más barato que montarla y cancelarla, y porque el token
                    // llega por montaje.
                    //
                    // Con la puerta, el token llega por MONTAJE y no por re-disparo: nada depende de
                    // en qué orden corran el `.task` de esta vista y el de la de abajo.
                    if let flowToken {
                        RestoreProgressView(flowToken: flowToken) { summary, settlement in
                            // Con datos se resuelve en el acto: el aviso de la nube jamás tapa un restore
                            // que sí puede ocurrir, y ese caso no necesita preguntarle nada al backend.
                            if summary.hasAnyData {
                                state = .found(summary)
                            } else if !settlement.consultsRemoteConfig {
                                // El import sigue trayendo datos: ya sabemos que existen, así que no hay
                                // nada que preguntarle al backend —su kill-switch gobierna la nube de Yala,
                                // no el espejo de Apple— y quien ya esperó el tope entero no gana nada con
                                // otro fetch encima.
                                RestoreBreadcrumb.importIncomplete()
                                state = .importIncomplete
                            } else {
                                Task { await resolveEmptyState(settlement) }
                            }
                        }
                    }
                case .found(let summary):
                    foundView(summary: summary)
                case .notFound:
                    notFoundView
                case .importIncomplete:
                    importIncompleteView
                case .cloudPaused:
                    cloudPausedView
                case .cloudUnverified:
                    cloudUnverifiedView
                case .wiped:
                    wipedView
                case .iCloudDisabled:
                    iCloudDisabledView
                case .error:
                    errorView
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        onBack()
                    }
                }
                if showRefreshToolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dsWithAnimation(reduceMotion, .easeInOut(duration: 0.6)) {
                                refreshRotation += 360
                            }
                            state = .searching
                            startSearch()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(refreshRotation))
                        }
                        .accessibilityLabel(L10n.Welcome.Restore.retry)
                    }
                }
            }
            .task { startSearch() }
            // **Irse de Restaurar SUELTA la titularidad de la ventana de sesión, y no la apaga.**
            //
            // La distinción es `abandoned-restore-no-longer-clears-the-session-window-clock`: el import
            // sigue bajando cuando esta pantalla se va —CloudKit no para porque nadie mire—, así que el
            // reloj no se toca; lo que se libera es el derecho a cerrarla, para que quien vuelva a entrar
            // ESTRENE ventana en vez de heredar un instante de hace siete minutos que la haría caducar a
            // media descarga.
            //
            // **Vive aquí desde el 2026-09-21 y antes vivía en la pantalla de progreso**
            // (`restore-timeout-closes-the-session-window-with-the-import-still-running`). Aquélla se
            // desmonta también cuando solo cambia el `state` —a `.importIncomplete`, a `.found`—, o sea
            // con la persona todavía dentro de Restaurar y un botón de «volver a buscar» delante: soltar
            // ahí dejaba la ventana huérfana y el reintento la re-anclaba, porque `hasObservedImportActivity`
            // es un latch monótono del proceso. El tope duro de 600 s pasaba a renovarse cada 90 s a
            // voluntad. Este desmontaje es mucho mejor aproximación a «me fui»: las salidas de
            // `ContentView.welcomeRestoreCover` bajan todas `showWelcomeRestore`, y el `case .restore`
            // de `FullModeActivationView` cambia de pantalla.
            //
            // **Lo que NO es, y conviene no creérselo** (lo midió una lente de la review): no cubre
            // TODAS las salidas ni solo las salidas. `FullModeActivationView.finishRestoreSearch` con
            // un resumen completo pinta su `finale` ENCIMA, en el mismo `ZStack`, sin desmontar nada —
            // así que ahí la persona se fue y esto no corre—; y en sentido contrario, su `go(to:)` a la
            // puerta de descarte desmonta con la persona todavía dentro del flujo de activación. Hoy
            // ninguna de las dos hace daño —soltar no toca el reloj, y descartar apaga por su cuenta en
            // el botón de arriba—, pero cualquier cosa que se cuelgue de aquí hereda los dos huecos.
            //
            // El `if let` no es defensa: `.wiped` y `.iCloudDisabled` salen de `startSearch()` antes de
            // encender nada, y sin token no hay titularidad que soltar. En el camino normal es un no-op —
            // `noteRestoreFinished` ya rotó el dueño a `nil`— y con un intento MÁS NUEVO vivo también,
            // por el guard del token dentro de la señal.
            .onDisappear {
                if let flowToken {
                    ICloudRestoreSessionSignal.noteRestoreAbandoned(flowToken)
                }
            }
            .confirmationDialog(
                L10n.Welcome.Restore.startFreshConfirmTitle,
                isPresented: $showStartFreshConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Welcome.Restore.startFreshConfirmConfirm, role: .destructive) {
                    // **Descartar APAGA la ventana, que no es lo mismo que soltarla.** Lo cazó una
                    // lente de la review del 2026-09-21 y era una regresión de este mismo ticket:
                    // desde que el tope agotado con el import vivo ya no apaga, la única salida que
                    // quedaba aquí era el `onDisappear`, que suelta y deja el reloj —o sea, la ventana
                    // viva hasta diez minutos con el guard de frontera de cuenta entornado, y en un
                    // teléfono con el corpus de otra persona eso son ocho minutos de sobra para firmar
                    // encima. Antes lo cerraba el apagado incondicional a los 90 s.
                    //
                    // Y es el ÚNICO camino de salida en el que apagar es correcto: todo el diseño de la
                    // señal se apoya en «las filas siguen entrando», y aquí la persona acaba de decir
                    // lo contrario — lo que hay detrás de este botón es la puerta que las borra. Si se
                    // arrepiente, volver a Restaurar estrena ventana como cualquier entrada nueva.
                    if let flowToken {
                        ICloudRestoreSessionSignal.noteRestoreFinished(flowToken)
                    }
                    onStartFresh()
                }
                Button(L10n.Welcome.Restore.startFreshConfirmCancel, role: .cancel) {}
            } message: {
                Text(L10n.Welcome.Restore.startFreshConfirmBody)
            }
        }
    }

    // MARK: - Search

    /// Decide el estado inicial; la espera con quiescencia + el progreso en vivo
    /// los hace `RestoreProgressView` (estado `.searching`). Respeta el wipe: si el
    /// último acto del usuario fue un wipe, no ofrecemos restaurar (estado `.wiped`).
    private func startSearch() {
        guard iCloudSyncService.shared.isAccountAvailable else {
            state = .iCloudDisabled
            return
        }
        if RestoreOfferGate.wasWiped(
            lastOnboarding: PreferenceSyncService.shared.lastOnboardingTimestamp,
            lastWipe: PreferenceSyncService.shared.lastWipeTimestamp
        ) {
            RestoreBreadcrumb.wiped()
            state = .wiped
            return
        }
        // El ÚNICO encendido de la señal, y va aquí y no en el tap de la card por dos razones medidas:
        // (a) los dos `return` de arriba son los estados en los que NO hay import de CloudKit —sin
        // cuenta y tras un wipe— y encender ahí abriría el guard cross-cuenta sin corpus que lo
        // justifique; (b) elegir «Restaurar» con el mount neutro RELANZA la app
        // (`WelcomeMirrorRelaunchLogic.requiresMirror(.restoreICloud)`), así que una señal encendida en
        // el tap moriría con el proceso — este punto vive ya en el proceso que importa.
        //
        // **Y el token que devuelve identifica a ESTE intento, y se guarda.** El encendido ya no es
        // del todo idempotente: conserva el reloj de la ventana —el tope no es extensible a
        // voluntad— pero el dueño pasa a ser quien acaba de entrar. Así el intento anterior, esté
        // abandonado o terminado, pierde el derecho a cerrar la ventana del que sigue bajando datos
        // (`restore-back-and-reenter-closes-the-live-session-window`). Cada entrada y cada
        // reintento acuñan el suyo, así que dos esperas nunca comparten identidad.
        //
        // **Y el testigo del import viaja desde aquí, vivo.** Es lo que decide si esta entrada
        // RE-ANCLA una ventana huérfana —la que dejó un intento que la persona abandonó— o se
        // conforma con su reloj. Sin él, entrar y salir de esta pantalla renueva la ventana del guard
        // cross-cuenta indefinidamente; con él, solo la renueva quien tiene una descarga de verdad
        // detrás. No tiene default en la señal justamente para que este call-site tenga que decidir
        // de dónde sale.
        //
        // **Y lleva FECHA desde el 2026-09-21** (`leaving-and-reentering-restore-renews-the-hard-cap`).
        // Hasta ese día era `hasObservedImportActivity` a secas, un latch monótono del proceso: una
        // vez visto el primer `.importEvent` estaba encendido para siempre, así que cualquier
        // salir-de-Restaurar-y-volver estrenaba 600 s nuevos con dos toques, apoyándose en una
        // descarga que podía haber terminado veinte minutos antes. Los dos crudos van juntos porque
        // un import EN CURSO puede pasar minutos sin emitir un solo evento — el estado del espejo es
        // lo que cubre ese hueco, y sin él la vuelta legítima a los siete minutos no re-anclaría.
        flowToken = ICloudRestoreSessionSignal.noteRestoreStarted(
            hasLiveImportActivity: ICloudRestoreInProgressLogic.hasLiveImportActivity(
                isImportingNow: iCloudSyncService.shared.status.isImporting,
                lastImportActivityAt: iCloudSyncService.shared.lastImportActivityAt,
                now: .now))
        state = .searching
    }

    /// Desenlace de una búsqueda que terminó SIN datos: cuál de los tres hechos afirmar —«no hay
    /// datos», «la nube está en pausa» o «no lo hemos podido comprobar»—, y lo decide
    /// `WelcomeRestoreEmptyOutcome`.
    ///
    /// **El `force: true` no es cosmético, y aquí carga más peso que en sus hermanos.** `refreshIfDue`
    /// sin él es un no-op mientras el último fetch tenga menos de 6 h, que es el caso NORMAL: el boot
    /// acaba de refrescar. Sin forzar, el flag que se lee es el del arranque, y como el botón primario
    /// de esta pantalla es «Reintentar», el usuario podría pulsarlo indefinidamente leyendo siempre el
    /// mismo snapshot — un botón que no puede cambiar su desenlace. El kill se conmuta desde el
    /// backend, así que preguntar es la única forma de enterarse, y tapear «Restaurar» ya es evidencia
    /// de que quiere saberlo AHORA (mismo criterio que `WelcomeGroupsGateView.evaluate`).
    ///
    /// El faro y el flag se leen AQUÍ y no se heredan del `WelcomeFlowContainer` a propósito: elegir
    /// «Restaurar» con el mount neutro RELANZA la app
    /// (`WelcomeMirrorRelaunchLogic.requiresMirror(.restoreICloud)`), así que este proceso no vio esa
    /// pantalla. Los dos sobreviven al relanzamiento por su cuenta —el faro porque vive en el
    /// iCloud-KV, el flag porque es remote-config— y por eso se re-consultan en vez de pasarse.
    ///
    /// `settlement` llega desde la pantalla de progreso y aquí solo puede valer `.settledEmpty` o
    /// `.inconclusive` — el tercer caso no entra, porque ya se resolvió sin preguntar. Se recibe y no
    /// se re-lee del servicio a propósito: describe el instante en que terminó la espera, no éste.
    private func resolveEmptyState(_ settlement: RestoreImportSettlement) async {
        // Hermeticidad: bajo `-uitest` no se toca red (mismo criterio que el resto del Welcome). Los
        // getters devuelven su default, así que el recorrido determinista no cambia.
        if !SwiftDataConfiguration.isUITesting {
            await RemoteConfigClient.shared.refreshIfDue(force: true)
        }
        // La cancelación es COOPERATIVA y `refreshIfDue` solo la mira entre fetches, así que sin este
        // guard un usuario que toca «volver» durante el refresco vería la pantalla cambiar bajo el
        // dedo cuando la red conteste. Es el único punto de suspensión de la rama.
        guard !Task.isCancelled else { return }

        // `cloudConfigKnown` se lee DESPUÉS del refresco y no antes: el `force` de arriba es
        // precisamente el intento de que deje de ser `false`. Leerlo antes describiría el estado
        // anterior a preguntar, que es el de cualquier arranque.
        let outcome = WelcomeRestoreEmptyOutcome.resolve(
            beaconLinked: CloudBeacon().isCloudAccountLinked,
            cloudConfigKnown: CloudRemoteFlags.cloudConfigKnown,
            remoteCloudEnabled: CloudRemoteFlags.cloudModeEnabled)
        switch outcome {
        case .cloudPaused:
            RestoreBreadcrumb.cloudPaused()
            state = .cloudPaused
        case .cloudUnverified:
            RestoreBreadcrumb.cloudUnverified()
            state = .cloudUnverified
        case .notFound:
            state = .notFound
        }
    }

    // MARK: - State views

    private func foundView(summary: ICloudAccountSummary) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer(minLength: DS.Spacing.xxl)

            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: DS.Gradients.heroIntense,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: DS.Spacing.sm) {
                Text(summary.userName.map { L10n.Welcome.Restore.foundTitle($0) } ?? L10n.Welcome.Restore.foundTitleAnonymous)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(L10n.Welcome.Restore.foundBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.lg)

            countCards(for: summary)
                .padding(.horizontal, DS.Spacing.lg)

            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.Welcome.Restore.continueAction) {
                    DS.Haptic.success()
                    // El destino (directo / onboarding) lo decide el caller con
                    // RestoreRouter, según lo que traiga el resumen restaurado.
                    onContinueWithSummary(summary)
                }

                Button {
                    showStartFreshConfirm = true
                } label: {
                    Text(L10n.Welcome.Restore.startFresh)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    /// Items visibles del resumen `.found` (count > 0), cada uno renderizado
    /// como card individual.
    ///
    /// **Toda cifra que enciende `hasAnyData` tiene que tener su card aquí.** Es la misma invariante que
    /// gobierna `WelcomePrivateICloudGateView.countsLine`, y se escribe porque se rompió en los dos
    /// sitios por el mismo motivo: un término del predicado sin consumidor que lo pinte deja la pantalla
    /// afirmando «Encontramos tus datos en iCloud:» sobre NADA — `countCards` con cero items cae en su
    /// `default` y dibuja un grid vacío.
    private struct CountItem: Identifiable {
        let id = UUID()
        let icon: String
        let count: Int
        let label: String
    }

    private func visibleCountItems(for s: ICloudAccountSummary) -> [CountItem] {
        var items: [CountItem] = []
        if s.accountsCount > 0 {
            items.append(CountItem(icon: "creditcard.fill", count: s.accountsCount,
                                   label: L10n.Welcome.Restore.foundAccounts(s.accountsCount)))
        }
        if s.transactionsCount > 0 {
            items.append(CountItem(icon: "list.bullet.rectangle.fill", count: s.transactionsCount,
                                   label: L10n.Welcome.Restore.foundTransactions(s.transactionsCount)))
        }
        // **Las categorías, desde el 2026-09-21** (`restore-treats-budgets-and-groups-as-no-data`, D5).
        // Es un hueco ANTERIOR a ese ticket, cazado al revisar este consumidor: `hasAnyData` ya las
        // contaba y esta lista era el único de los tres sitios que enseñan cifras del restore que no las
        // pintaba (`RestoreProgressView.liveCounts` sí, `countsLine` desde el 10-sep). Quien restauraba
        // solo categorías veía la pantalla del hallazgo con el grid en blanco.
        if s.categoriesCount > 0 {
            items.append(CountItem(icon: "tag.fill", count: s.categoriesCount,
                                   label: L10n.Welcome.PrivateICloud.foundCategories(s.categoriesCount)))
        }
        if s.budgetsCount > 0 {
            items.append(CountItem(icon: "chart.pie.fill", count: s.budgetsCount,
                                   label: L10n.Welcome.Restore.foundBudgets(s.budgetsCount)))
        }
        if s.groupsCount > 0 {
            items.append(CountItem(icon: "person.2.fill", count: s.groupsCount,
                                   label: L10n.Welcome.Restore.foundGroups(s.groupsCount)))
        }
        return items
    }

    /// Layout adaptativo según número de CIFRAS visibles:
    /// 1 → card centrado max-width 280pt; 2 → HStack 2 cols;
    /// 3 → HStack 3 cols; **4 o 5 → grid de 2 columnas** (2×2, o 2×2+1 con la quinta sola en su fila).
    ///
    /// **Cinco es alcanzable desde el 2026-09-21** y hasta entonces no lo era: las categorías entraron
    /// en `visibleCountItems` ese día, así que un restore con las cinco cifras deja una card sola en la
    /// última fila. Es un grid impar, no un defecto, pero se mira con los ojos en el device-QA — el
    /// docblock decía «4 → grid 2×2» y describía un máximo que ya no existe.
    @ViewBuilder
    private func countCards(for summary: ICloudAccountSummary) -> some View {
        let items = visibleCountItems(for: summary)
        switch items.count {
        case 1:
            HStack {
                Spacer()
                countCard(items[0])
                    .frame(maxWidth: 280)
                Spacer()
            }
        case 2, 3:
            HStack(spacing: DS.Spacing.md) {
                ForEach(items) { item in
                    countCard(item)
                        .frame(maxWidth: .infinity)
                }
            }
        default:
            // 4 items o más → grid 2×2.
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DS.Spacing.md),
                          GridItem(.flexible(), spacing: DS.Spacing.md)],
                spacing: DS.Spacing.md
            ) {
                ForEach(items) { item in
                    countCard(item)
                }
            }
        }
    }

    private func countCard(_ item: CountItem) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: item.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.accent)
            Text("\(item.count)")
                .font(DS.Typography.amount)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(item.label)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
        .dsCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.label)
    }

    /// No hay datos. **El copy no cambia** —Jürgen descartó el 2026-09-17 convertir al usuario
    /// realmente nuevo en un «no pudimos comprobar» tras 90 s de espera, y la señal del import no lo
    /// separa del teléfono al que CloudKit no contestó: los dos terminan sin ver un `.importEvent`—.
    /// Lo que cambia es el GESTO: «Empezar desde cero» pregunta antes.
    ///
    /// **Pregunta SIEMPRE, y eso se midió en vez de razonarse.** El criterio que pide el ticket es
    /// «cuando la búsqueda/import no asentó», y el primer intento llevó ese término en el estado
    /// (`.notFound(conclusive:)`). Al buscar quién alcanza la rama concluyente salió que `settled`
    /// exige `hasCompletedFirstImport` (`iCloudSyncService.waitForImportQuiescence`), o sea que CloudKit
    /// trajo algo;
    /// y si trajo algo y `hasAnyData` seguía en `false`, lo que trajo eran presupuestos o grupos, que
    /// aquel predicado no contaba. ⇒ la rama que llamaba directo tenía **una sola población, y era
    /// gente con datos** — le hacía daño justo a quien pretendía no molestar.
    ///
    /// **Ese hueco se cerró A MEDIAS el 2026-09-21** (`restore-treats-budgets-and-groups-as-no-data`),
    /// y la mitad que queda abierta es la que sostiene el gesto: `hasAnyData` cuenta ya los
    /// presupuestos, así que quien los tenga no llega aquí; **los grupos siguen sin contar, medido y a
    /// propósito** —no vienen de iCloud, y contarlos haría inalcanzables `.importIncomplete`,
    /// `.cloudPaused`, `.cloudUnverified` y este mismo estado para toda la población con grupos—. A
    /// quien solo tiene grupos se le sigue avisando antes de borrar, pero **en la puerta**, no aquí:
    /// su `deviceHasData` sale de `ContentView.checkHasExistingData()`, que sí los cuenta.
    ///
    /// **Y el gesto NO se desanda**, por dos razones ahora: esa población sigue llegando, y
    /// `.inconclusive` sigue sin separar a quien de verdad no tiene nada del teléfono al que CloudKit
    /// no contestó (ver `RestoreImportSettlement.inconclusive`).
    private var notFoundView: some View {
        emptyStateView(
            icon: "icloud.slash",
            // A11Y-DM: gris neutro de estado vacío "no encontrado" (sistema, adapta a Dark Mode)
            tint: .gray,
            title: L10n.Welcome.Restore.notFoundTitle,
            body: L10n.Welcome.Restore.notFoundBody,
            primaryTitle: L10n.Welcome.Restore.startFresh,
            primaryAction: { showStartFreshConfirm = true }
        )
    }

    /// El tope se agotó con el import en marcha: los datos vienen.
    ///
    /// Ni el gris del vacío ni el naranja del fallo — aquí no falta nada ni ha fallado nada, solo falta
    /// tiempo, así que va con el acento del tema. Reintentar es el botón primario porque es literalmente
    /// lo único que resuelve el caso: volver a buscar es esperar otro tramo con los conteos subiendo a
    /// la vista. Y «Empezar desde cero» **confirma**, por el mismo motivo que en `.cloudPaused`: esta
    /// pantalla acaba de afirmar que el histórico existe, y arrancar de cero encima abre un dataset
    /// paralelo que convivirá con él cuando el import termine.
    private var importIncompleteView: some View {
        emptyStateView(
            icon: "icloud.and.arrow.down",
            tint: theme.accent,
            title: L10n.Welcome.Restore.importIncompleteTitle,
            body: L10n.Welcome.Restore.importIncompleteBody,
            primaryTitle: L10n.Welcome.Restore.retry,
            primaryAction: { state = .searching; startSearch() },
            secondaryTitle: L10n.Welcome.Restore.startFresh,
            secondaryAction: { showStartFreshConfirm = true }
        )
        .accessibilityIdentifier("welcome_restore_import_incomplete")
    }

    /// iCloud apagado: **no hubo búsqueda**, así que este estado no sabe si hay datos.
    ///
    /// Confirma desde el 2026-09-20, y no por coherencia: **su población tiene datos**. La puerta que
    /// manda aquí es `startSearch`, con `iCloudSyncService.isAccountAvailable`, que es
    /// `SwiftDataConfiguration.isICloudAvailable()` = `FileManager.ubiquityIdentityToken != nil`
    /// (`Yala/Utils/SwiftDataConfiguration.swift:36-38`). **Ese token mide iCloud DRIVE, no CloudKit**
    /// (`.claude/rules/swiftdata-cloudkit.md`, la regla del 2026-09-10): con Drive apagado y la sesión
    /// de iCloud viva el token es `nil` mientras CloudKit funciona perfectamente — y el mount que sale
    /// de ahí adjunta el espejo igual. O sea que quien cae en esta pantalla puede tener su histórico
    /// entero esperando en el servidor, y hasta hoy podía tirarlo de un solo toque. Es el mismo bug del
    /// ticket por otra puerta, y le toca la misma red.
    ///
    /// Y el criterio del bucle que lo excluía —«estados que NIEGAN que haya datos»— tampoco lo
    /// clasificaba bien: su copy no niega nada. «Necesitas tener iCloud activado para **recuperar tus
    /// datos**» los presupone (`es-419.lproj/Localizable.strings:4101`).
    private var iCloudDisabledView: some View {
        emptyStateView(
            icon: "icloud.slash.fill",
            tint: .orange,
            title: L10n.Welcome.Restore.iCloudDisabledTitle,
            body: L10n.Welcome.Restore.iCloudDisabledBody,
            primaryTitle: L10n.Welcome.Restore.openSettings,
            primaryAction: onOpenSettings,
            secondaryTitle: L10n.Welcome.Restore.startFresh,
            secondaryAction: { showStartFreshConfirm = true }
        )
    }

    private var errorView: some View {
        emptyStateView(
            icon: "exclamationmark.triangle.fill",
            tint: .orange,
            title: L10n.Welcome.Restore.errorTitle,
            body: L10n.Welcome.Restore.errorBody,
            primaryTitle: L10n.Welcome.Restore.retry,
            primaryAction: { state = .searching; startSearch() }
        )
    }

    /// Nube en pausa: los datos EXISTEN y el mensaje no debe decir lo contrario.
    ///
    /// Naranja y no el gris de `.notFound` a propósito: el gris es el estado vacío («no hay nada»),
    /// y aquí sí hay algo — es la misma familia que `.iCloudDisabled`, «falta una condición externa
    /// para poder traerlo». Por eso comparte también su forma de dos botones: reintentar primero
    /// (el kill se re-enciende desde el backend, sin actualizar la app) y empezar de cero como
    /// salida, nunca al revés.
    private var cloudPausedView: some View {
        emptyStateView(
            icon: "cloud.slash",
            tint: .orange,
            title: L10n.Welcome.Restore.cloudPausedTitle,
            body: L10n.Welcome.Restore.cloudPausedBody,
            primaryTitle: L10n.Welcome.Restore.retry,
            primaryAction: { state = .searching; startSearch() },
            secondaryTitle: L10n.Welcome.Restore.startFresh,
            // Reusa el `confirmationDialog` del camino `.found` en vez de llamar directo. Desde el
            // 2026-09-20 lo comparten todos menos uno: el ÚNICO que sigue llamando directo es `.wiped`,
            // el único desenlace concluyente por acto de la propia persona. Empezar de cero desde aquí
            // arranca un dataset paralelo que, al levantarse el kill, convive con la cuenta que este
            // mismo texto acaba de prometer intacta.
            secondaryAction: { showStartFreshConfirm = true }
        )
        .accessibilityIdentifier("welcome_restore_cloud_paused")
    }

    /// No pudimos comprobarlo: el mensaje no afirma NI que los datos existan ni que falten.
    ///
    /// Es el desenlace de quien reinstala —o estrena móvil— y abre sin red: el snapshot de
    /// remote-config se fue con la app y el faro de iCloud-KV tampoco ha sincronizado, así que las dos
    /// señales que distinguen «no hay datos» de «hay datos y la nube está en pausa» están en blanco.
    /// Hasta el 2026-09-17 ese caso caía en `.notFound` y le decía «no hay datos asociados a tu
    /// cuenta» a alguien con su histórico intacto en el servidor.
    ///
    /// Copia la forma de `.cloudPaused` —naranja, reintentar primero, empezar de cero como salida— y
    /// **también su confirmación**: los tres estados que llaman directo al callback niegan que haya
    /// datos, y éste no niega nada. Sin saber, el gesto destructivo se pregunta.
    ///
    /// **Ni el icono ni el copy culpan a la conexión del usuario**, y eso lo cazó la review: la
    /// comprobación que falló viaja por NUESTRO gateway, no por CloudKit, así que un 5xx del Worker o
    /// una red que filtre su dominio dan este mismo desenlace con el wifi de la persona perfecto. Un
    /// `wifi.exclamationmark` y un «revisa tu conexión» le mandarían a mirar un router que funciona.
    private var cloudUnverifiedView: some View {
        emptyStateView(
            icon: "exclamationmark.icloud",
            // El token, no el literal: `DS.Semantic.warningForeground` ES `.orange`, así que el color en
            // pantalla no cambia y el fichero deja de sumar un hardcode. Sus vecinos (`errorView`,
            // `cloudPausedView`) siguen con el literal — deuda incremental, se migra al tocarlos.
            tint: DS.Semantic.warningForeground,
            title: L10n.Welcome.Restore.cloudUnverifiedTitle,
            body: L10n.Welcome.Restore.cloudUnverifiedBody,
            primaryTitle: L10n.Welcome.Restore.retry,
            primaryAction: { state = .searching; startSearch() },
            secondaryTitle: L10n.Welcome.Restore.startFresh,
            secondaryAction: { showStartFreshConfirm = true }
        )
        .accessibilityIdentifier("welcome_restore_cloud_unverified")
    }

    /// Respeto al wipe: el usuario borró sus datos en este dispositivo → no
    /// ofrecemos recargar, solo empezar de nuevo.
    private var wipedView: some View {
        emptyStateView(
            // A11Y-DM: gris neutro de estado vacío (sistema, adapta a Dark Mode)
            icon: "trash.slash",
            tint: .gray,
            title: L10n.Welcome.Restore.Wiped.title,
            body: L10n.Welcome.Restore.Wiped.body,
            primaryTitle: L10n.Welcome.Restore.startFresh,
            primaryAction: onStartFresh
        )
    }

    // MARK: - Helpers

    private func emptyStateView(
        icon: String,
        tint: Color,
        title: String,
        body bodyText: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(tint)
            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(bodyText)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.lg)
            Spacer()
            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(primaryTitle, action: primaryAction)
                if let secondaryTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                            .font(DS.Typography.label)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
    }
}
