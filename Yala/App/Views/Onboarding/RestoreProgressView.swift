//
//  RestoreProgressView.swift
//  Yala
//
//  Pantalla de progreso del restore de iCloud (rama B + alert "Cargar mis datos").
//  La espera real la hace `iCloudSyncService.waitForImportQuiescence`; un refresher
//  paralelo refresca los conteos REALES en vivo (CloudKit no expone un % del import).
//  Salir de la pantalla apaga los DOS: la espera observa cancelación desde el 2026-09-21
//  y el refresher tiene handle propio, así que ninguno sobrevive al desmontaje. La
//  titularidad de la ventana de sesión NO se suelta aquí —este desmontaje también ocurre
//  al cambiar de estado, con la persona todavía dentro de Restaurar—: la suelta
//  `WelcomeRestoreView` al desaparecer ella.
//  Y el apagado de la ventana no es «gane o pierda»: el tope agotado CON el import en
//  marcha deja la ventana viva, porque las filas siguen entrando.
//  Barra por fases (connecting → importing → completed/partial). Siempre se muestra
//  un mínimo para no parpadear. Al asentar (o timeout) llama `onSettled` con el summary.
//

import SwiftData
import SwiftUI

struct RestoreProgressView: View {
    /// El flujo de restauración al que pertenece esta espera, y lo único que autoriza a cerrar la
    /// ventana de sesión **cuando el flujo no deja descarga detrás**
    /// (`ICloudRestoreSessionSignal.noteRestoreFinished(_:)`, tras la puerta de
    /// `ICloudRestoreInProgressLogic.closesTheSessionWindow` — ver `startFlow()`).
    ///
    /// **Llega RESERVADO desde arriba y no se lee del latch aquí**, y esa es la pieza que hace
    /// correcto el arreglo de `restore-back-and-reenter-closes-the-live-session-window`. Esta pantalla
    /// se monta en el PRIMER render de `WelcomeRestoreView` —su `state` nace en `.searching`—, o sea
    /// antes de que `startSearch()` haya encendido nada: preguntarle al latch aquí devolvería el token
    /// del intento ANTERIOR, que es el bug por dentro. Con el token reservado en el `@State` de la
    /// vista de arriba, cada entrada a Restaurar trae el suyo sin depender de en qué orden corran los
    /// dos `.task`.
    let flowToken: ICloudRestoreSessionSignal.FlowToken
    let timeout: TimeInterval
    /// El resumen **y lo que sabemos de la espera que lo produjo**. El segundo argumento no es
    /// telemetría: con el resumen vacío es lo único que distingue «CloudKit dijo que no hay nada» de
    /// «CloudKit no terminó en 90 s», y hasta el 2026-09-20 no salía de aquí — el `settled` se gastaba
    /// en la fase visual y el consumidor recibía el mismo vacío en los dos casos
    /// (`restore-says-no-data-when-the-icloud-import-never-settled`).
    var onSettled: (ICloudAccountSummary, RestoreImportSettlement) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var counts: ICloudAccountSummary?
    @State private var phase: OnboardingRestorePhase = .connecting
    @State private var runTask: Task<Void, Never>?
    /// El refresco visual paralelo, con handle PROPIO y apagado por la MISMA vía que su padre.
    ///
    /// **No es un hijo estructurado de `runTask`**, así que no hereda su cancelación, y atarlo al
    /// `cancel()` que va después de la espera sería hacer que su tramo lo cumpla el vecino: hasta el
    /// 2026-09-21 la espera no se cortaba al salir de la pantalla, así que este bucle seguía haciendo un
    /// `iCloudAccountSummary` sobre 5+ entidades cada 0,6 s —unos 150 fetches en el MainActor— con la
    /// vista ya desmontada, escribiendo el `@State` de una vista muerta.
    @State private var refreshTask: Task<Void, Never>?

    init(flowToken: ICloudRestoreSessionSignal.FlowToken,
         timeout: TimeInterval = 90,
         onSettled: @escaping (ICloudAccountSummary, RestoreImportSettlement) -> Void) {
        self.flowToken = flowToken
        self.timeout = timeout
        self.onSettled = onSettled
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            processingCircle
            VStack(spacing: DS.Spacing.md) {
                Text(phaseLabel)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                progressBar
                liveCounts
            }
            .padding(.horizontal, DS.Spacing.xl)
            Spacer()
        }
        .task { startFlow() }
        // **Este desmontaje apaga los dos `Task` y NO suelta la titularidad de la ventana**, y esa
        // segunda mitad se mudó a `WelcomeRestoreView` el 2026-09-21
        // (`restore-timeout-closes-the-session-window-with-the-import-still-running`).
        //
        // El motivo es que esta pantalla se desmonta por DOS razones que no se parecen en nada: porque
        // la persona se fue de Restaurar, o porque el estado de arriba cambió a `.importIncomplete`,
        // `.found` o cualquier otro desenlace — o sea con la persona todavía dentro, mirando «seguimos
        // trayendo tus datos» y con un botón de volver a buscar delante. Soltar en el segundo caso deja
        // la ventana HUÉRFANA, y entonces el reintento la re-ancla (`currentFlow == nil` **Y**
        // `hasObservedImportActivity`, que es un latch monótono del proceso): el tope duro de 600 s
        // pasaría a renovarse cada 90 s con solo pulsar «volver a buscar», que es justo lo que el tercer
        // criterio del ticket prohíbe.
        //
        // Quien sabe distinguir las dos razones es la pantalla de arriba: su propio desmontaje SÍ
        // significa «me fui de Restaurar». Ahí vive ahora el `noteRestoreAbandoned`.
        .onDisappear {
            runTask?.cancel()
            refreshTask?.cancel()
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .connecting: return L10n.Welcome.Restore.Progress.connecting
        case .importing:  return L10n.Welcome.Restore.Progress.importing
        case .completed:  return L10n.Welcome.Restore.Progress.completed
        case .partial:    return L10n.Welcome.Restore.Progress.partial
        }
    }

    private var processingCircle: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [theme.accent.opacity(0.3), .clear],
                                     center: .center, startRadius: 50, endRadius: 90))
                .frame(width: 180, height: 180)
                .blur(radius: 10)
            Circle()
                .fill(LinearGradient(colors: [theme.accent.opacity(0.8), theme.accent.opacity(0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 120)
                .shadow(color: theme.accent.opacity(0.4), radius: 20, x: 0, y: 8)
            if OnboardingRestoreProgress.isTerminal(phase) {
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.accent.opacity(0.15)).frame(height: 8)
                Capsule()
                    .fill(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.8)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * OnboardingRestoreProgress.fraction(for: phase)),
                           height: 8)
                    .dsAnimation(.easeInOut(duration: 0.4), value: phase, reduceMotion: reduceMotion)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, DS.Spacing.xxxxl)
    }

    /// Conteos REALES que van apareciendo conforme llegan los lotes de CloudKit.
    /// Iconos + número (sin labels de texto → no requiere L10n; el ícono comunica el tipo).
    private var liveCounts: some View {
        HStack(spacing: DS.Spacing.lg) {
            countChip("creditcard.fill", counts?.accountsCount ?? 0, L10n.Welcome.Restore.foundAccounts(counts?.accountsCount ?? 0))
            countChip("tag.fill", counts?.categoriesCount ?? 0, "\(counts?.categoriesCount ?? 0)")
            countChip("list.bullet.rectangle.fill", counts?.transactionsCount ?? 0, L10n.Welcome.Restore.foundTransactions(counts?.transactionsCount ?? 0))
            countChip("chart.pie.fill", counts?.budgetsCount ?? 0, L10n.Welcome.Restore.foundBudgets(counts?.budgetsCount ?? 0))
            countChip("person.2.fill", counts?.groupsCount ?? 0, L10n.Welcome.Restore.foundGroups(counts?.groupsCount ?? 0))
        }
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: counts)
    }

    @ViewBuilder
    private func countChip(_ icon: String, _ value: Int, _ a11y: String) -> some View {
        if value > 0 {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                Text("\(value)").monospacedDigit().contentTransition(.numericText())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(a11y)
        }
    }

    private func startFlow() {
        // **Los handles previos se cancelan antes de reasignar**, y no es defensa: un `Task` que se
        // pisa sin cancelar queda vivo y sin dueño. `.task` corre una vez por identidad de vista, pero
        // el coste de que SwiftUI lo re-dispare sin pasar por `onDisappear` es un bucle de
        // `iCloudAccountSummary` sobre 5+ entidades cada 0,6 s que ya nadie puede apagar.
        refreshTask?.cancel()
        runTask?.cancel()
        // Refresco visual paralelo: conteos reales + fase, hasta que asiente o se vaya la pantalla.
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    counts = try modelContext.iCloudAccountSummary(appPreferences: appPreferences)
                } catch {
                    #if DEBUG
                    print("RestoreProgressView: iCloudAccountSummary falló: \(error)")
                    #endif
                }
                phase = OnboardingRestoreProgress.phase(
                    hasCompletedFirstImport: iCloudSyncService.shared.hasCompletedFirstImport,
                    isQuiescent: iCloudSyncService.shared.isImportQuiescent,
                    timedOut: false
                )
                try? await Task.sleep(for: .seconds(0.6))
            }
        }
        runTask = Task { @MainActor in
            // Espera real (primer import + quiescencia) con tope.
            let settled = await iCloudSyncService.shared.waitForImportQuiescence(timeout: timeout)
            // La señal se lee EN ESTE INSTANTE, pegada al `settled` que describe. Leerla al final —tras
            // el mínimo de exhibición— haría que la pareja hablara de dos momentos distintos. El flag es
            // monótono dentro de la sesión, así que retrasarlo solo puede cambiar el veredicto a mejor;
            // aun así el testigo se toma donde se toma la medida.
            // El testigo del import se lee UNA vez y alimenta a los dos, que preguntan cosas distintas
            // sobre el mismo instante: `RestoreImportSettlement` elige el COPY y
            // `ICloudRestoreInProgressLogic.closesTheSessionWindow` decide si se apaga un guard de
            // frontera de cuenta. Leerlo dos veces los dejaría hablando de dos momentos.
            let sawImport = iCloudSyncService.shared.hasObservedImportActivity
            let settlement = RestoreImportSettlement.resolve(
                settled: settled,
                hasObservedImportActivity: sawImport,
                lastImportErrorAt: iCloudSyncService.shared.lastImportErrorAt,
                lastSuccessfulImportAt: iCloudSyncService.shared.lastSuccessfulImportDate)
            // **El guard de cancelación va antes de TODO lo que sigue, y ese orden se invirtió el
            // 2026-09-21.**
            // Hasta entonces la espera no observaba cancelación, así que llegar aquí solo podía
            // significar «el flujo terminó por sus propios méritos» —asentó o se agotó el tope— y el
            // apagado iba delante para que un desmontaje en ese instante exacto no se lo llevara.
            // Desde que salir de la pantalla SÍ corta la espera, llegar aquí ya no significa eso: puede
            // ser que la persona tocara atrás. Y apagar ahí es justo lo que el diseño prohíbe —
            // `ICloudRestoreSessionSignal` lo dice entero: «no se apaga al volver atrás; salir de la
            // pantalla de restaurar no para el import: CloudKit sigue bajando filas». Le devolvería al
            // dueño legítimo el bloqueo cross-cuenta sobre su propia cuenta, que es el bug que la señal
            // existe para cerrar. Su lógica pura ya lo daba por hecho («el usuario que toca atrás a
            // mitad cancela ese `Task` y este camino no corre»): hasta hoy esa frase era falsa.
            //
            // Lo que se pierde es PRECISIÓN, y la lógica pura la acota: quien toca atrás y no vuelve
            // deja la ventana a cargo del import que asienta y de la caducidad (la gracia sin
            // actividad —60 s por PROCESO desde el 2026-09-22, no por entrada— y el tope duro de
            // 600 s). **Y el tramo de 600 s no es solo «el import va lento»**, que es lo
            // que decía la primera versión de este comentario y lo refutó la review:
            // `hasObservedImportActivity` se enciende en `iCloudSyncService` ANTES del `if let error`,
            // así que un import que FALLÓ y no va a volver también cae en esa rama. Se acepta —el tope
            // duro cierra igual— pero no se cuenta como si fuera el caso bueno.
            guard !Task.isCancelled else { return }
            // **El refresher se apaga DETRÁS del guard, y eso lo cazó una lente de la review.** Delante
            // parecía inofensivo —«apágalo siempre»— y no lo era: `refreshTask` es un `@State`, o sea
            // una caja COMPARTIDA entre generaciones de la vista. Un `runTask` cancelado que despierta
            // después de que la pantalla se haya vuelto a montar leería de esa caja el refresher de la
            // generación NUEVA y lo mataría, dejando los conteos congelados en el intento vivo. Detrás
            // del guard no puede pasar: en el camino cancelado ya lo apagó el `onDisappear` —que es el
            // único sitio del fichero que cancela `runTask`, así que uno cancelado implica el otro—, y
            // ahí ese `cancel()` solo podía acertarle al vecino.
            refreshTask?.cancel()
            // **El apagado dejó de ser «gane o pierda» el 2026-09-21**
            // (`restore-timeout-closes-the-session-window-with-the-import-still-running`).
            //
            // Perder tiene dos formas y solo una significa que no queda descarga: agotar el tope SIN
            // haber visto un import es un final —no hay nada bajando ni lo hubo— y ahí apagar es la
            // precisión que este camino aporta sobre la caducidad. Agotarlo **habiendo visto un import**
            // no lo es: las filas siguen entrando, y `restoreStartedAt = nil` le devuelve al dueño
            // legítimo el `.blockedForeignData` sobre su propia cuenta justo mientras sus datos bajan.
            //
            // **El criterio NO es el `settlement`, y esa distinción la trajo la review**: aquel elige el
            // copy, y su `.inconclusive` agrupa «no vi ningún import» con «el último import dio error»,
            // que a esta pregunta contestan distinto —la mayoría de esos errores son retriables y
            // CloudKit sigue trayendo filas detrás—. Con el `settlement` como puerta, un restore grande
            // con la red floja volvía a quedarse bloqueado en su propia cuenta.
            //
            // Con el token de ESTE flujo, no incondicional: quien tocó atrás y volvió a entrar tiene un
            // intento vivo con otro token, y el abandonado no puede apagarle la ventana. Si esta
            // pantalla se montó en un camino que nunca llegó a encender la señal (`.wiped`,
            // `.iCloudDisabled`), su token no es dueño de nada y esto es un no-op.
            //
            // Y cuando NO apaga, tampoco suelta: la titularidad se queda con este intento mientras la
            // persona siga dentro de Restaurar, que es lo único que impide que el reintento re-ancle el
            // tope duro (`noteRestoreStarted` conserva el reloj si hay dueño vigente).
            if ICloudRestoreInProgressLogic.closesTheSessionWindow(
                settled: settled, hasObservedImportActivity: sawImport) {
                ICloudRestoreSessionSignal.noteRestoreFinished(flowToken)
            }
            phase = settled ? .completed : .partial
            do {
                counts = try modelContext.iCloudAccountSummary(appPreferences: appPreferences)
            } catch {
                #if DEBUG
                print("RestoreProgressView: iCloudAccountSummary falló: \(error)")
                #endif
            }
            // Mínimo de exhibición para que se vea el estado final.
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            RestoreBreadcrumb.settled(phase: settled ? "completed" : "partial", settlement: settlement)
            onSettled(counts ?? ICloudAccountSummary(
                userName: nil, accountsCount: 0, transactionsCount: 0,
                budgetsCount: 0, groupsCount: 0, primaryCurrencyCode: nil, categoriesCount: 0),
                settlement)
        }
    }
}
