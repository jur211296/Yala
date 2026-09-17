//
//  WelcomeRestoreView.swift
//  Yala
//
//  A4 — Rama B del Welcome Chooser. "Ya tengo cuenta" → restore desde iCloud.
//
//  State machine: searching → found / notFound / cloudPaused / cloudUnverified / wiped /
//  iCloudDisabled / error. Los tres de en medio son los desenlaces de una búsqueda VACÍA y los
//  decide `WelcomeRestoreEmptyOutcome`: afirman hechos distintos, no el mismo con otro copy.
//  Cada transición a state está gateada por `Task.isCancelled` para evitar
//  resume sobre vista no presentada (race con CKShare, dismiss user, app background).
//

import SwiftData
import SwiftUI

struct WelcomeRestoreView: View {

    enum ViewState: Equatable {
        case searching
        case found(ICloudAccountSummary)
        case notFound
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
    /// literalmente lo único que puede resolverlo.
    private var showRefreshToolbar: Bool {
        switch state {
        case .notFound, .cloudPaused, .cloudUnverified, .error: return true
        default: return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                switch state {
                case .searching:
                    RestoreProgressView { summary in
                        // Con datos se resuelve en el acto: el aviso de la nube jamás tapa un restore
                        // que sí puede ocurrir, y ese caso no necesita preguntarle nada al backend.
                        if summary.hasAnyData {
                            state = .found(summary)
                        } else {
                            Task { await resolveEmptyState() }
                        }
                    }
                case .found(let summary):
                    foundView(summary: summary)
                case .notFound:
                    notFoundView
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
            .confirmationDialog(
                L10n.Welcome.Restore.startFreshConfirmTitle,
                isPresented: $showStartFreshConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Welcome.Restore.startFreshConfirmConfirm, role: .destructive) {
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
        ICloudRestoreSessionSignal.noteRestoreStarted()
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
    private func resolveEmptyState() async {
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

    /// Layout adaptativo según número de categorías visibles:
    /// 1 → card centrado max-width 280pt; 2 → HStack 2 cols;
    /// 3 → HStack 3 cols; 4 → grid 2×2.
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

    private var notFoundView: some View {
        emptyStateView(
            icon: "icloud.slash",
            // A11Y-DM: gris neutro de estado vacío "no encontrado" (sistema, adapta a Dark Mode)
            tint: .gray,
            title: L10n.Welcome.Restore.notFoundTitle,
            body: L10n.Welcome.Restore.notFoundBody,
            primaryTitle: L10n.Welcome.Restore.startFresh,
            primaryAction: onStartFresh
        )
    }

    private var iCloudDisabledView: some View {
        emptyStateView(
            icon: "icloud.slash.fill",
            tint: .orange,
            title: L10n.Welcome.Restore.iCloudDisabledTitle,
            body: L10n.Welcome.Restore.iCloudDisabledBody,
            primaryTitle: L10n.Welcome.Restore.openSettings,
            primaryAction: onOpenSettings,
            secondaryTitle: L10n.Welcome.Restore.startFresh,
            secondaryAction: onStartFresh
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
            // Reusa el `confirmationDialog` del camino `.found` en vez de llamar directo. Lo comparte
            // con `.cloudUnverified` desde el 2026-09-17 y con ningún otro: los tres estados vacíos que
            // llaman directo NIEGAN que haya datos, éste afirma que EXISTEN y el otro no sabe. Empezar
            // de cero desde aquí arranca un dataset paralelo que, al levantarse el kill, convive con la
            // cuenta que este mismo texto acaba de prometer intacta.
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
