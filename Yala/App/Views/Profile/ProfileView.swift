//
//  ProfileView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import AVFoundation
import Photos
import StoreKit
import SwiftData
import SwiftUI

//  Created by Yala Refactoring.
//

/// Main profile screen acting as the Configuration Control Center
struct ProfileView: View {
    /// Optional destination to navigate to on appear (used by setup checklist).
    var initialDestination: ProfileDestination?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.yalaTheme) private var theme

    @ScaledMetric(relativeTo: .largeTitle) private var avatarIconSize: CGFloat = 40 // A11Y-DT: @ScaledMetric

    @State private var viewModel = ProfileViewModel()

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState
    private var effectiveColorfulIcons: Bool {
        theme.forcesMonochromeIcons ? false : appPreferences.colorfulIcons
    }
    private var profileStorage: ProfileImageStorage { .shared }

    // Navigation & Sheets
    @State private var navigationPath = NavigationPath()
    @State private var activeSheet: ProfileSheet?

    // Import result - shown as alert after ImportIntroSheet dismisses
    @State private var importResult: ImportResult?
    @State private var showImportResult: Bool = false

    // Permission denied alert

    // Subscription state
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false
    @State private var showUpgradeForInsights = false
    @State private var showUpgradeForChat = false
    @State private var showSupportSheet = false

    // Coach mark: Settings tour
    @State private var showSettingsTour = false
    @State private var settingsTourIndex = 0
    @State private var settingsScrollProxy: ScrollViewProxy?

    // Coach mark: Pro tour (Phase 1)
    @State private var showProTour = false
    @State private var proTourIndex = 0

    #if DEBUG
    @State private var seedService = DevSeedService()
    @State private var showSeedConfirmation = false
    @State private var showSeedProgress = false
    #endif

    // H4: cierre de sesión universal (privada y nube). El coordinador es @Observable;
    // los alerts se materializan en @State propio vía onChange (regla toolbar-muerta:
    // jamás un binding de presentación con setter no-op). El cover terminal de relaunch
    // tiene DUEÑO ÚNICO en el root (SignOutRelaunchNetModifier, ContentView) — presentar
    // también desde este sheet creaba una carrera de anchors ante la misma fase y UIKit
    // tumbaba AMBAS cadenas (bug device 2026-07-14). Ante `.awaitingRelaunch` este sheet
    // solo se CIERRA; el root verifica presentación efectiva y reintenta.
    private var signOutCoordinator: CloudSessionSignOut { CloudSessionSignOut.shared }
    /// Paso 9 · la hoja de «Cerrar sesión» viaja COMO ITEM, con la operación ya resuelta AL TOCAR: la variante
    /// sin copia en iCloud se decide ahí y la confirmación la hereda, de modo que la hoja que se leyó y el
    /// cierre que se ejecuta hablan de lo mismo (molde `DeleteAccountScope`, abajo).
    private struct SignOutScope: Identifiable {
        let id = UUID()
        let path: CloudSignOutFlowLogic.Path
        let operation: DestructiveScopeLogic.Operation
        let cloudLabel: DestructiveScopeLogic.CloudLabel
    }
    @State private var signOutScope: SignOutScope?
    @State private var showSignOutBlockedAlert = false
    // H-2026-07-18-6: el bloqueo TRANSITORIO del sign-out solo-grupos usa un alert distinto
    // ("un momento más") — el permanente conserva el alert de conexión de siempre.
    @State private var showSignOutPendingAlert = false
    // Decisión del owner 2026-09-03: en la sesión de VISITA los dos alerts de bloqueo suman «salir
    // igualmente». Se fija junto al alert (no se recalcula al pintar) para que la salida forzada y el
    // aviso que la anuncia decidan por el MISMO `pendingCount`, el del bloqueo que se está mostrando.
    // D4: flags del patrón anti-carrera de las hojas de alcance — la acción corre en el `onDismiss` del
    // sheet (con la hoja YA fuera), no en el tap del botón (evita el race dismiss-hoja / transición-shell).
    @State private var pendingSignOutScope: SignOutScope?
    /// Paso 9 · segundo gesto del cierre privado SIN copia en iCloud (confirmación reforzada). Es un alert
    /// que encadena el `onDismiss` de la hoja: contenedores distintos, sin carrera en el mismo anchor.
    @State private var showSignOutNoCopyConfirm = false
    /// El camino que confirmó la hoja sin copia, para que el segundo gesto ejecute ESE y no otro.
    @State private var pendingNoCopyPath: CloudSignOutFlowLogic.Path?
    /// Paso 9 · el aviso de la espera del export agotada, con su salida de emergencia. Alert DEDICADO con
    /// botones literales: el `actions` de un `.alert` no admite labels que dependan del estado.
    @State private var showSignOutExportAlert = false
    /// Cuántos cambios no llegaron a iCloud en el bloqueo que se está mostrando (0 = no se pudo contar).
    @State private var signOutExportPending = 0
    /// El aviso del teléfono sin App Attest que ofrece cerrar sesión perdiendo los cambios de grupos (2026-09-15). Alert
    /// DEDICADO, como el del export y por lo mismo: sus botones son literales.
    @State private var showSignOutAttestLossAlert = false
    /// Cuántos cambios de grupos se perderían en el bloqueo que se está mostrando (`Int.max` = no se pudo contar).
    @State private var signOutAttestLossPending = 0
    /// El aviso de cerrar sesión en la nube con cambios PERSONALES sin subir y un teléfono sin App Attest (2026-09-15,
    /// decisión de Jürgen): exportar los movimientos, cerrar sesión perdiéndolos o dejarlo. Alert DEDICADO, por lo mismo
    /// que los dos de arriba: sus botones son literales.
    @State private var showSignOutPersonalAttestAlert = false
    /// Cuántos cambios personales se perderían en el bloqueo que se está mostrando (`Int.max` = no se pudo contar).
    @State private var signOutPersonalAttestPending = 0
    /// El archivo con todos los movimientos que ofrece ese aviso, mientras la hoja de compartir está en pantalla.
    @State private var signOutRescueExportFile: ExportedFile?
    /// La exportación de ese aviso falló: el texto que lo explica (no había movimientos, o no se pudo escribir el archivo).
    @State private var signOutRescueExportErrorMessage = ""
    @State private var showSignOutRescueExportError = false
    /// Mientras se genera ese archivo, un indicador: la exportación corre en el hilo principal y con un historial largo tarda.
    @State private var isExportingBeforeLosingChanges = false
    /// Qué bloqueó el cierre, para elegir el mensaje del aviso. **Es el motivo entero y no un `Bool`**
    /// desde el 2026-09-13: eran dos mensajes y son tres —sesión caducada, canal de Grupos en pausa, y el
    /// resto—, así que un `Bool` ya no los separa. Solo lo leen los mensajes; qué alert se presenta lo
    /// sigue decidiendo `presentSignOutBlock`.
    @State private var signOutBlockedReason: CloudSignOutFlowLogic.BlockReason?

    private func syncSignOutUI(from phase: CloudSessionSignOut.Phase) {
        switch phase {
        case .blocked(let pending, let reason):
            signOutBlockedReason = reason
            if reason == .exportUnconfirmed { signOutExportPending = pending }
            if reason == .attestUnavailable { signOutAttestLossPending = pending }
            if reason == .personalAttestUnavailable { signOutPersonalAttestPending = pending }
            presentSignOutBlock(reason)
        case .awaitingRelaunch: dismiss()
        case .idle, .working: break
        }
    }

    /// Presenta el aviso del bloqueo UN TURNO DESPUÉS, con todos los flags a cero antes.
    ///
    /// Paso 9 (review adversarial): el productor es asíncrono —una espera de hasta 45 s— y el anchor puede
    /// estar ocupado (otra hoja de Ajustes abierta) o desmontando el aviso anterior (el re-aviso de «Cerrar
    /// sesión igualmente» cuando entraron más cambios). Encender el flag en ese momento lo deja en `true` sin
    /// presentación, y volver a encenderlo ya no hace nada (`swiftui-ds.md`, dos avisos en el mismo anchor).
    /// El reset y el turno de espera son una red; la otra es `requestSignOut`, que con la fase bloqueada lo
    /// vuelve a pedir.
    private func presentSignOutBlock(_ reason: CloudSignOutFlowLogic.BlockReason) {
        showSignOutPendingAlert = false
        showSignOutBlockedAlert = false
        showSignOutExportAlert = false
        showSignOutAttestLossAlert = false
        showSignOutPersonalAttestAlert = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard case .blocked(_, let live) = signOutCoordinator.phase, live == reason else { return }
            switch reason {
            case .transient: showSignOutPendingAlert = true
            // **El teléfono sin App Attest** (2026-09-15). Con la salida de un CIERRE, su propio aviso: cuenta lo que se
            // pierde y ofrece «Cerrar sesión y perderlos». Sin ella no enciende nada, igual que los dos motivos del
            // desasociar de más abajo: ese mismo motivo lo pone el desasociar, que no ofrece salida, y su aviso lo pinta
            // `GroupsAssociationSection`. Encender aquí el genérico repetiría el agujero de
            // `signout-alert-fires-on-detach-blocks-it-did-not-cause` con un motivo nuevo.
            case .attestUnavailable:
                if signOutCoordinator.offersGroupsLossExit { showSignOutAttestLossAlert = true }
            // **Tus datos en la nube, con el teléfono sin App Attest** (2026-09-15, decisión de Jürgen). Con la salida que
            // anotó el cierre en la nube, su propio aviso: cuenta lo que se pierde y ofrece exportar los movimientos, cerrar
            // sesión perdiéndolos o dejarlo. Sin ella —otro gesto la retiró— el aviso de bloqueo con el texto que no ofrece
            // nada: este motivo solo lo pone el cierre en la nube, así que ninguna otra pantalla lo pinta por él.
            case .personalAttestUnavailable:
                if signOutCoordinator.offersPersonalLossExit {
                    showSignOutPersonalAttestAlert = true
                } else {
                    showSignOutBlockedAlert = true
                }
            // El canal de Grupos en pausa entra por el MISMO alert que los otros dos permanentes, con el
            // mensaje que le toca (`signOutBlockedMessage`).
            //
            // **Y hereda el agujero que estos tres ya tenían, que NO es suyo y no se cierra aquí:** el
            // desasociar de Ajustes escribe esta misma fase con estos mismos motivos, así que su bloqueo
            // también enciende este aviso —«No pudimos cerrar tu sesión» a quien solo pidió soltar una
            // cuenta de grupos—, encima del aviso propio de la sección. El corte de abajo solo cubre los
            // dos motivos EXCLUSIVOS del desasociar; los compartidos no se pueden distinguir por el
            // motivo, porque el discriminador correcto es el GESTO y el coordinador no lo publica.
            // Ticket: `signout-alert-fires-on-detach-blocks-it-did-not-cause`.
            //
            // **El fallo pasajero de la subida de grupos entra por el MISMO alert, y no por el de
            // «un momento más»** (2026-09-14). Su título —«No pudimos cerrar tu sesión»— es exacto: el
            // cierre no se completó y aquí nadie ha reintentado nada. El de `.transient` promete lo
            // contrario («un momento más», tras 45 s de reintentos del cierre solo-grupos) y ante un
            // servidor caído sería falso. Lo que cambia es el mensaje (`signOutBlockedMessage`).
            //
            // **Los tres del motor parado, también** (2026-09-25): mismo título, su propio mensaje. Solo los pone el cierre en
            // la nube, así que no los comparte ningún otro gesto. **Y la subida personal que no llegó**, por lo mismo que la de
            // grupos: el título es exacto y aquí nadie ha reintentado nada.
            case .permanent, .sessionExpired, .channelPaused, .uploadRetryLater,
                 .syncStoppedNeedsUpdate, .syncStoppedMidMigration, .syncStoppedNeedsRelaunch, .personalUploadRetryLater:
                showSignOutBlockedAlert = true
            // **Los dos motivos del DESASOCIAR no encienden nada aquí, y no es teoría: llegaban.**
            // `phase` es un singleton observable y esta pantalla escucha sus cambios; la de
            // almacenamiento se abre DESDE aquí, así que sigue montada. Sin este corte, cada bloqueo del
            // desasociar apilaba «No pudimos cerrar tu sesión» encima del aviso propio de la sección
            // —dos presentaciones del mismo anchor, con su carrera— y le hablaba a la persona de cerrar
            // la sesión entera cuando solo pidió soltar una cuenta de grupos. Es justo lo que el aviso
            // propio de `GroupsAssociationSection` existe para evitar. Quien los enseña es esa sección,
            // por el veredicto de retorno, no por la fase.
            case .bridgeUnreadable, .detachBusy: break
            case .exportUnconfirmed: showSignOutExportAlert = true
            }
        }
    }

    /// El toque de «Cerrar sesión», desde Ajustes o desde «Tu cuenta de Yala». Con un cierre parado en un aviso
    /// vuelve a enseñar ese aviso —la fila no puede quedarse muda con la fase bloqueada—; si no, abre la hoja de
    /// la celda, una sola vez aunque el toque se repita (un item nuevo por toque cambiaría la identidad del
    /// `.sheet(item:)` en plena presentación).
    private func requestSignOut() {
        if case .blocked = signOutCoordinator.phase {
            syncSignOutUI(from: signOutCoordinator.phase)
            return
        }
        guard signOutCoordinator.phase == .idle, signOutScope == nil else { return }
        signOutScope = makeSignOutScope()
    }

    /// «Exportar mis movimientos», desde el aviso de tus datos sin App Attest (decisión de Jürgen del 2026-09-15): el CSV de
    /// TODOS los movimientos (`ExportFilters.allTransactions`), sin asistente ni límite de plan, y la hoja de compartir.
    ///
    /// Va un turno después del tap, por lo mismo que `presentSignOutBlock`: el aviso se está desmontando y presentar en ese
    /// momento lo pierde (`swiftui-ds.md`, dos presentaciones en el mismo anchor). **No toca el cierre**, que sigue parado en
    /// su bloqueo: al cerrar la hoja —o el aviso de error— `returnToPersonalAttestNotice` lo vuelve a enseñar.
    ///
    /// Tres detalles de la review adversarial (2026-09-15). Corre en el hilo principal, como la del asistente, y con un
    /// historial largo tarda: `isExportingBeforeLosingChanges` pinta un indicador mientras dura. Pasa
    /// `scheduleTagBackfill: false`, porque ese relleno se guarda y crearía cambios por subir que harían volver el aviso con
    /// una cifra que la persona no escribió. Y el error sale con texto propio
    /// (`SignOutBlockedCopy.personalExportFailureMessage`): el del servicio está en español y habla de filtros.
    private func exportAllTransactionsBeforeLosingThem() {
        isExportingBeforeLosingChanges = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            defer { isExportingBeforeLosingChanges = false }
            do {
                let result = try TransactionsExportService.export(
                    format: .csv, using: .allTransactions, columns: .default, in: modelContext,
                    scheduleTagBackfill: false)
                CloudSessionSignOut.notePersonalLossExport(rows: result.exportedCount)
                signOutRescueExportFile = ExportedFile(urls: [result.fileURL])
            } catch {
                #if DEBUG
                print("ProfileView: Error exportando los movimientos antes de cerrar sesión: \(error)")
                #endif
                signOutRescueExportErrorMessage = SignOutBlockedCopy.personalExportFailureMessage(for: error)
                showSignOutRescueExportError = true
            }
        }
    }

    /// Tras la hoja de compartir o el aviso de error de la exportación: el cierre sigue parado en el aviso de tus datos, y se
    /// vuelve a enseñar, que es lo que la persona dejó a medias. Si ya no está ahí —otro gesto lo reconoció—, no enciende nada.
    private func returnToPersonalAttestNotice() {
        guard case .blocked(_, .personalAttestUnavailable) = signOutCoordinator.phase else { return }
        syncSignOutUI(from: signOutCoordinator.phase)
    }

    /// El mensaje del aviso de cierre bloqueado, por motivo. **La tabla vive en `SignOutBlockedCopy`**, que
    /// la comparte con la hoja del cambio de Apple ID desde el 2026-09-15: dos copias del mismo `switch`
    /// divergen. Allí está también por qué cada motivo dice lo que dice.
    ///
    /// `nil` no ocurre con el alert presentado (`syncSignOutUI` escribe el motivo antes de encenderlo); cae
    /// al genérico por si acaso. El `switch` de `presentSignOutBlock` decide qué alert sale, no qué dice.
    private var signOutBlockedMessage: String {
        SignOutBlockedCopy.message(for: signOutBlockedReason)
    }

    /// Botones de los DOS alerts de cierre bloqueado. Se comparten a propósito: la diferencia entre el
    /// bloqueo transitorio y el permanente ya la lleva el título y el mensaje (H-2026-07-18-6), y las
    /// salidas disponibles son las mismas en los dos casos.
    ///
    /// **La salida forzada («salir igualmente, perdiendo lo que no subió») se retiró con la sesión de
    /// visita, 2026-09-13**, y su motivo era suyo: la persona estaba en un móvil prestado que tenía que
    /// devolver, así que un cierre imposible de completar la dejaba atrapada. En el móvil propio nadie
    /// espera a que devuelvas nada, y perder un gasto por no esperar no tiene justificación.
    @ViewBuilder
    private var signOutBlockedButtons: some View {
        Button(L10n.Common.ok, role: .cancel) {
            CloudSessionSignOut.shared.acknowledgeBlocked()
        }
    }

    /// Paso 9 · la hoja de «Cerrar sesión» para el camino que el coordinador va a recorrer. En las dos celdas
    /// privadas pregunta AHORA si hay copia en iCloud (`CloudSessionSignOut.privateCopyChannel`): sin ella la
    /// hoja dice que no existe copia en ninguna parte y la confirmación pide un segundo gesto (decisión de
    /// Jürgen del 2026-09-09). La respuesta viaja en el item y no se recalcula al ejecutar.
    private func makeSignOutScope() -> SignOutScope {
        let path = signOutRowPath
        let hasICloudCopy: Bool
        switch path {
        case .privateSignOut, .privateWithGroupsSignOut:
            hasICloudCopy = CloudSessionSignOut.privateCopyChannel() == .iCloud
        case .cloudSecureSignOut, .groupsOnlySignOut:
            hasICloudCopy = true
        }
        // La privada sin sesión que guarda grupos del canal backend los olvida al cerrar, y su hoja tiene que
        // decirlo (misma pregunta que se hace el coordinador justo antes de armar).
        let forgetsBackendGroups = path == .privateSignOut
            && CloudSessionSignOut.hasBackendGroupRows(context: modelContext)
        let operation = DestructiveScopeLogic.signOutOperation(
            path: path, hasICloudCopy: hasICloudCopy, forgetsBackendGroups: forgetsBackendGroups)
        return SignOutScope(
            path: path,
            operation: operation,
            cloudLabel: DestructiveScopeLogic.cloudLabel(for: operation, storageMode: CloudSyncFlags.storageMode))
    }

    /// Camino de sign-out resuelto por la precedencia CONGELADA (secundaria → nube → equipo/solo-grupos →
    /// privado). SSOT de `makeSignOutScope`.
    ///
    /// **Lee la capacidad COMPILADA, igual que `CloudSessionSignOut.signOut` (D-R1 paso 2), y las dos
    /// lecturas tienen que moverse juntas.** Si esta se quedara compuesta y la del coordinador no, bajo
    /// un kill remoto la hoja de alcance resolvería `.signOutPrivate` —que pinta los grupos como
    /// preservados— mientras el dispatch resuelve `.groupsOnlySignOut` y arma el borrado del store de
    /// grupos: la hoja mentiría, y encima desaparecería la fila «Salir de Yala en este dispositivo».
    private var signOutRowPath: CloudSignOutFlowLogic.Path {
        CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode,
            hasLiveSession: CloudAuthService.shared.hasSession,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability,
            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
    }

    /// H-2026-07-18-6: caption honesto mientras el sign-out solo-grupos ESPERA a que se asienten writes
    /// internos (retry interno) — el bloqueo típico es transitorio y antes obligaba a tocar la fila varias
    /// veces. Compartido por las filas "Cerrar sesión" y "Cerrar sesión de grupos" (D2).
    @ViewBuilder
    private var signOutWorkingCaption: some View {
        if signOutCoordinator.phase == .working && signOutCoordinator.waitingForPending {
            Text(L10n.Settings.signOutWorking)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.FormRow.paddingV)
                .accessibilityIdentifier("profile_signout_working_caption")
        }
    }

    /// D6: gate de la fila "Exportar datos" — grupos en solo-grupos, transacciones en el resto.
    private var isExportEnabled: Bool {
        isGroupsOnlyShell ? viewModel.hasExportableGroups : viewModel.hasTransactions
    }

    /// Hint de accesibilidad cuando "Exportar datos" está deshabilitada (D6).
    private var exportDisabledHint: String {
        isGroupsOnlyShell
            ? L10n.Accessibility.noGroupsToExport
            : L10n.Accessibility.noTransactionsToExport
    }

    // G5-D1b: eliminar cuenta (DARK — fila visible solo con sesión backend viva). Doble confirmación:
    // el primer diálogo explica la matriz por modo, el segundo es el irreversible. Misma disciplina de
    // presentación que el cierre de sesión (bindings reales + onChange; el cover terminal lo dueña el root
    // vía CloudSessionSignOut.phase — el cierre local del borrado entra en esa misma fase viva).
    private var deletionService: AccountDeletionService { AccountDeletionService.shared }
    @State private var showDeleteAccountFinal = false
    @State private var showDeleteAccountError = false
    // D4: patrón anti-carrera — el paso final / desvío a Grupos corre en el `onDismiss` de la hoja.
    @State private var pendingDeleteAccountFinal = false
    @State private var pendingViewGroups = false

    /// D5 (§3.3.4): resumen READ-ONLY de grupos (nº con deuda del usuario + huella CloudKit legacy),
    /// recomputado al tocar "Eliminar mi cuenta". Alimenta el aviso condicional de saldos y el botón
    /// "Ver mis grupos" del primer diálogo. Cero saves (invariante de quiescencia intacto).
    ///
    /// Viaja COMO ITEM de la presentación, no como `@State` leído dentro del closure del `.sheet`:
    /// medido 2026-08-03, calcular el resumen y encender `isPresented` en el MISMO tap hace que SwiftUI
    /// arme el contenido con el valor ANTERIOR (`.empty`) y NO lo re-evalúe después ⇒ la rama D5 de
    /// deudas no se presentaba NUNCA (ni el aviso ni «Ver mis grupos»), con la deuda bien calculada.
    /// Con `.sheet(item:)` el dato es la identidad de la presentación y no puede llegar tarde.
    private struct DeleteAccountScope: Identifiable {
        let id = UUID()
        let summary: AccountDeletionGroupsSummary
    }
    @State private var deleteAccountScope: DeleteAccountScope?

    /// Input `hasSession` de «Tu cuenta de Yala», que desde el paso 9 es también la puerta de «Eliminar mi cuenta». En release es
    /// exactamente `CloudAuthService.shared.hasSession` (byte-idéntico); `UITestHooks.fakeBackendSession`
    /// es inerte fuera de DEBUG (`hasArg` → false) y solo lo fuerza a `true` para QA/XCUITest del diálogo
    /// D5 en el simulador, donde no hay sign-in backend real (SIWA/Google no corren). NO crea sesión real.
    private var deleteAccountRowHasSession: Bool {
        UITestHooks.fakeBackendSession || CloudAuthService.shared.hasSession
    }

    /// §3.3.5: la fila/pantalla "Tu cuenta de Yala" — con sesión backend viva, fuera de secundaria (M1,
    /// que describe la cuenta del DUEÑO, no la de la invitada). Reemplaza el letrero mudo `groupsAccountRow`.
    /// DARK hoy (`hasSession` imposible en prod); `UITestHooks.fakeBackendSession` la fuerza para QA
    /// (seam D5, inerte en release). NO excluye group-invite: un group-invite CON sesión backend (D6,
    /// [FLAG]) SÍ tiene cuenta que explicar (su desenlace de borrado lo gatea `YalaAccountLogic`).
    private var showsYalaAccountRow: Bool {
        deleteAccountRowHasSession
    }

    /// §3.2: subtítulo dinámico de la fila "Dónde viven tus datos" — refleja el modo real.
    private var dataLocationSubtitle: String {
        CloudSyncFlags.storageMode == .cloud
            ? L10n.Settings.dataLocationSubtitleCloud
            : L10n.Settings.dataLocationSubtitleICloud
    }

    /// D4: operación de la hoja de eliminar-cuenta según el modo (misma decisión que `AccountDeletionService`:
    /// `.cloud` vs solo-grupos backend). La composición de líneas condicionales (deudas D5, desvío cruzado,
    /// copia iCloud congelada, huella legacy) la sigue decidiendo `AccountDeletionMessageLogic`, reutilizada
    /// por `DestructiveScopeLogic`; aquí solo se elige la operación (la etiqueta ☁️ es siempre la cuenta de Yala).
    private var deleteAccountScopeOperation: DestructiveScopeLogic.Operation {
        DestructiveScopeLogic.deleteAccountOperation(
            storageMode: CloudSyncFlags.storageMode,
            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
    }

    private func syncDeletionUI(from phase: AccountDeletionService.Phase) {
        switch phase {
        case .failed: showDeleteAccountError = true
        case .awaitingRelaunch: dismiss()  // belt: el root ya cerró vía CloudSessionSignOut.phase
        case .idle, .working: break
        }
    }

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    /// GC-08: en modo solo-grupos el perfil se reduce a lo esencial de grupos +
    /// opciones universales; se ocultan las filas de finanzas personales.
    private var isGroupsOnlyShell: Bool {
        !SessionState.shared.hasPrivateSession
    }

    /// Shell reducida a Grupos: oculta la sección «Organización» (finanzas personales).
    /// Reactivo por el espejo observable del eje 1.
    private var isGroupsFocusedShell: Bool {
        ShellModeLogic.effective(
            hasPrivateSession: sessionState.hasPrivateSession) == .groupsFocused
    }

    /// Gatea la fila «Activar Yala completo». Es la MISMA pregunta que `isGroupsFocusedShell` y por eso
    /// la delega en vez de responderla por su cuenta — cuando eran dos fuentes distintas, quien llegaba
    /// por invitación no veía esta fila NUNCA. Mismo criterio que el CTA gemelo de `MoreView`.
    private var showsActivateFullRow: Bool {
        isGroupsFocusedShell
    }

    /// En solo-grupos no se muestra cromo Pro (no hay venta de Pro en ese modo).
    private var showsProBadge: Bool {
        isProUser && !isGroupsOnlyShell
    }

    private var isVoiceLocked: Bool {
        !FeatureGateService.shared.canAccess(.voiceInput)
    }

    private var isImageLocked: Bool {
        !FeatureGateService.shared.canAccess(.imageInput)
    }

    private var isSmartInsightsLocked: Bool {
        !FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    private var isChatLocked: Bool {
        !FeatureGateService.shared.canAccess(.chatAssistant)
    }

    enum ProfileSheet: Identifiable {
        case personalDetails
        case importIntro
        case exportWizard
        /// D6 (§3.3.6): export directo de grupos para el solo-grupos legado (sin wizard personal).
        case groupsExport

        var id: Int {
            hashValue
        }
    }

    // ProfileDestination extracted to Yala/App/Models/ProfileDestination.swift

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                        VStack(spacing: DS.Spacing.xxl) {
                            // Header
                            profileHeader

                            // D1 (retención) + G4: fila permanente «Activar Yala completo» en toda shell
                            // reducida a Grupos —la eligió («Solo mis grupos») o llegó por un grupo—:
                            // la vuelta a la app completa (flujo guiado).
                            if showsActivateFullRow {
                                activateFullYalaSection
                            }

                            // Sections
                            // Organización gestiona finanzas personales (cuentas, categorías,
                            // presupuestos…): se omite en la shell reducida a Grupos.
                            if !isGroupsFocusedShell {
                                organizacionSection
                            }
                            preferenciasSection
                            datosSection
                            seguridadSection
                            ayudaSection
                            legalSection

                            // Version info
                            Text(L10n.Settings.versionInfo)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.tertiary)
                                .padding(.top, DS.Spacing.sm)
                        }
                        .padding(.vertical, DS.Spacing.xxl)
                    }
                    .scrollDisabled(false)
                    .onAppear { settingsScrollProxy = scrollProxy }
            }
            .navigationTitle(L10n.Profile.title)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.subtle)
            // Mientras se genera el archivo que ofrece el aviso de tus datos sin App Attest
            // (`exportAllTransactionsBeforeLosingThem`): la exportación bloquea el hilo principal y, sin esto, nada se mueve.
            .overlay {
                if isExportingBeforeLosingChanges {
                    ProgressView()
                        .controlSize(.large)
                        .padding(DS.Spacing.lg)
                        .glassEffect()
                        .accessibilityIdentifier("profile_signout_export_progress")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $activeSheet) { item in
                switch item {
                case .personalDetails:
                    PersonalDetailsView()
                case .importIntro:
                    ImportIntroSheet(
                        accounts: viewModel.accounts,
                        categories: viewModel.categories,
                        onImportCompleted: { result in
                            // Store result and show alert after sheet animation completes
                            activeSheet = nil
                            importResult = result
                            // Small delay to ensure sheet is fully dismissed
                            Task {
                                try? await Task.sleep(for: .milliseconds(200))
                                showImportResult = true
                            }
                        }
                    )
                case .exportWizard:
                    ExportFiltersStepView()
                case .groupsExport:
                    GroupsExportView(onFinish: { activeSheet = nil })
                }
            }
            .alert(
                importResult?.isSuccess == true
                    ? L10n.Profile.importSuccess : L10n.Profile.importError,
                isPresented: $showImportResult,
                presenting: importResult
            ) { _ in
                Button(L10n.Common.ok, role: .cancel) {}
            } message: { result in
                Text(result.message)
            }
            // H4 + D4 + paso 9: «Cerrar sesión» — hoja de alcance (3 filas 📱/☁️/👥) de la celda que toca, con
            // la operación resuelta al tocar (`makeSignOutScope`). El botón fija `pendingSignOutScope` y cierra la
            // hoja; el `onDismiss` actúa YA con la hoja fuera (anti-carrera): o el segundo gesto del cierre sin
            // copia, o el cierre. El cover terminal lo dueña el root vía `.phase`.
            .sheet(item: $signOutScope, onDismiss: {
                guard let scope = pendingSignOutScope else { return }
                pendingSignOutScope = nil
                // La celda pudo cambiar con la hoja abierta (una sesión que caduca, un evento del espejo): se
                // enseña la hoja de la celda de AHORA en vez de ejecutar un borrado que nadie leyó.
                let live = makeSignOutScope()
                guard live.operation == scope.operation else {
                    signOutScope = live
                    return
                }
                if DestructiveScopeLogic.requiresNoCopyConfirmation(scope.operation) {
                    pendingNoCopyPath = scope.path
                    showSignOutNoCopyConfirm = true
                } else {
                    Task { await CloudSessionSignOut.shared.signOut(context: modelContext, confirmedPath: scope.path) }
                }
            }) { scope in
                DestructiveScopeSheet(config: .make(
                    operation: scope.operation,
                    cloudLabel: scope.cloudLabel,
                    onConfirm: { pendingSignOutScope = scope }))
            }
            // Paso 9 · el segundo gesto del cierre privado sin copia en iCloud: no se bloquea, se avisa.
            .alert(L10n.Settings.signOutNoCopyConfirmTitle, isPresented: $showSignOutNoCopyConfirm) {
                Button(L10n.Settings.signOutNoCopyConfirmAction, role: .destructive) {
                    let path = pendingNoCopyPath
                    pendingNoCopyPath = nil
                    // La celda pudo cambiar con el aviso abierto (una sesión que caduca): se enseña su hoja —un
                    // turno después, para no presentar mientras este aviso se desmonta— en vez de no hacer nada.
                    let live = makeSignOutScope()
                    guard live.path == path, DestructiveScopeLogic.requiresNoCopyConfirmation(live.operation) else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { signOutScope = live }
                        return
                    }
                    Task {
                        await CloudSessionSignOut.shared.signOut(
                            context: modelContext, confirmedPath: path, confirmedWithoutICloudCopy: true)
                    }
                }
                .accessibilityIdentifier("signout_no_copy_confirm")
                Button(L10n.Common.cancel, role: .cancel) { pendingNoCopyPath = nil }
                    .accessibilityIdentifier("signout_no_copy_cancel")
            } message: {
                Text(L10n.Settings.signOutNoCopyConfirmMessage)
            }
            // Paso 9 · la espera del export se agotó: el aviso cuenta lo que no llegó a iCloud y ofrece cerrar
            // igualmente o seguir esperando (decisión de Jürgen del 2026-09-09). Nunca borra sin este gesto.
            .alert(L10n.Settings.signOutExportPendingTitle, isPresented: $showSignOutExportAlert) {
                Button(L10n.Settings.signOutExportDiscardButton, role: .destructive) {
                    Task { await CloudSessionSignOut.shared.exitDiscardingUnconfirmed(context: modelContext) }
                }
                .accessibilityIdentifier("signout_export_discard")
                // «Esperar» sigue esperando y cierra solo cuando llega lo último: no cancela el cierre.
                Button(L10n.Settings.signOutWaitButton, role: .cancel) {
                    Task { await CloudSessionSignOut.shared.resumeWaitingForExport(context: modelContext) }
                }
                .accessibilityIdentifier("signout_export_wait")
            } message: {
                Text(signOutExportPending > 0
                     ? L10n.Settings.signOutExportPendingMessage(signOutExportPending)
                     : L10n.Settings.signOutExportPendingMessageUnknown)
            }
            // El teléfono sin App Attest (2026-09-15, decisión de Jürgen): el aviso cuenta los cambios de grupos que se
            // pierden y ofrece cerrar igualmente. «Ahora no» reconoce el bloqueo y no pierde nada. Botones literales y
            // sin `accessibilityIdentifier`: SwiftUI no los propaga a los botones de un `.alert`.
            .alert(L10n.Groups.Errors.attestUnavailableTitle, isPresented: $showSignOutAttestLossAlert) {
                Button(L10n.Groups.Errors.attestUnavailableSignOutLossButton, role: .destructive) {
                    Task { await CloudSessionSignOut.shared.exitDiscardingUnsyncedGroups(context: modelContext) }
                }
                Button(L10n.Action.notNow, role: .cancel) {
                    CloudSessionSignOut.shared.acknowledgeBlocked()
                }
            } message: {
                Text(SignOutBlockedCopy.attestLossMessage(pending: signOutAttestLossPending))
            }
            // Tus datos en la nube con el teléfono sin App Attest (2026-09-15, decisión de Jürgen): el aviso cuenta los cambios
            // que no llegaron y ofrece, en este orden, exportar los movimientos, cerrar sesión perdiéndolos o dejarlo. Exportar
            // no toca el cierre, que sigue parado: al cerrar la hoja de compartir vuelve este aviso. Botones literales y sin
            // `accessibilityIdentifier`, como el de grupos.
            .alert(L10n.Settings.signOutAttestTitle, isPresented: $showSignOutPersonalAttestAlert) {
                Button(L10n.Settings.signOutAttestExportButton) {
                    exportAllTransactionsBeforeLosingThem()
                }
                Button(L10n.Settings.signOutAttestLossButton, role: .destructive) {
                    Task { await CloudSessionSignOut.shared.exitDiscardingUnsyncedPersonalChanges(context: modelContext) }
                }
                Button(L10n.Action.notNow, role: .cancel) {
                    CloudSessionSignOut.shared.acknowledgeBlocked()
                }
            } message: {
                Text(SignOutBlockedCopy.personalAttestLossMessage(pending: signOutPersonalAttestPending))
            }
            .sheet(item: $signOutRescueExportFile, onDismiss: { returnToPersonalAttestNotice() }) { file in
                ShareSheet(activityItems: file.urls)
                    .presentationDetents(DS.Adaptive.sheetDetents([.medium, .large]))
            }
            .alert(L10n.Export.exportError, isPresented: $showSignOutRescueExportError) {
                Button(L10n.Common.ok, role: .cancel) { returnToPersonalAttestNotice() }
            } message: {
                Text(signOutRescueExportErrorMessage)
            }
            .alert(L10n.Settings.signOutBlockedTitle, isPresented: $showSignOutBlockedAlert) {
                signOutBlockedButtons
            } message: {
                Text(signOutBlockedMessage)
            }
            // H-2026-07-18-6: bloqueo TRANSITORIO (solo-grupos, tras agotar el retry interno) —
            // copy que invita a esperar, no a revisar la conexión. Solo un bool se pone a la vez
            // (rutas mutuamente excluyentes en `syncSignOutUI`).
            .alert(L10n.Settings.signOutPendingTitle, isPresented: $showSignOutPendingAlert) {
                signOutBlockedButtons
            } message: {
                Text(L10n.Settings.signOutPendingMessage)
            }
            .onChange(of: signOutCoordinator.phase) { _, newPhase in
                syncSignOutUI(from: newPhase)
            }
            // Recuperación de estados huérfanos: si el sheet se cerró mientras el coordinator
            // trabajaba, al reabrir Ajustes se re-presenta el alert `.blocked` (SEGURO — nada
            // armado, solo informar); con `.awaitingRelaunch` el sheet se cierra solo para
            // despejar el anchor del cover terminal del root (dueño único).
            .onAppear { syncSignOutUI(from: signOutCoordinator.phase) }
            // G5-D1b + D4: eliminar cuenta — DOBLE confirmación. Paso 1 = hoja de alcance (📱/☁️/👥 + líneas
            // D5: deudas/desvío/copia congelada/huella legacy). "Continuar" fija `pendingDeleteAccountFinal`;
            // el desvío SEGURO "Ver mis grupos" (D5, id preservado para `DeleteAccountDialogUITests`) fija
            // `pendingViewGroups`. El `onDismiss` actúa YA con la hoja fuera: presenta el alert 2 (irreversible,
            // contenedor DISTINTO → sin carrera) o salta al tab Grupos + cierra Ajustes. INFORMA, jamás bloquea.
            .sheet(item: $deleteAccountScope, onDismiss: {
                // Defense-in-depth: captura el intent y resetea AMBOS flags ANTES de actuar (aunque sean
                // mutuamente excluyentes por construcción, evita un flag stale en un dismiss posterior).
                let goFinal = pendingDeleteAccountFinal
                let goViewGroups = pendingViewGroups
                pendingDeleteAccountFinal = false
                pendingViewGroups = false
                if goFinal {
                    showDeleteAccountFinal = true
                } else if goViewGroups {
                    // Selecciona el tab ANTES del dismiss (patrón de FullModeActivationView): el estado del
                    // tab vive en el singleton SessionState y sobrevive al cierre del sheet de Ajustes.
                    SessionState.shared.selectMainTab(.groups)
                    dismiss()
                }
            }) { scope in
                DestructiveScopeSheet(config: .make(
                    operation: deleteAccountScopeOperation,
                    cloudLabel: .cloudAccount,  // eliminar-cuenta = SIEMPRE la cuenta de Yala (backend)
                    hasOutstandingDebt: scope.summary.hasOutstandingDebt,
                    hasLegacyCloudKitFootprint: scope.summary.hasLegacyCloudKitFootprint,
                    onConfirm: { pendingDeleteAccountFinal = true },
                    onSecondary: { pendingViewGroups = true }))
            }
            .alert(L10n.Settings.deleteAccountFinalTitle, isPresented: $showDeleteAccountFinal) {
                Button(L10n.Settings.deleteAccountFinalAction, role: .destructive) {
                    Task { await AccountDeletionService.shared.deleteAccount(context: modelContext) }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Settings.deleteAccountFinalMessage)
            }
            .alert(L10n.Settings.deleteAccountErrorTitle, isPresented: $showDeleteAccountError) {
                Button(L10n.Settings.deleteAccountRetry) {
                    Task { await AccountDeletionService.shared.deleteAccount(context: modelContext) }
                }
                Button(L10n.Common.cancel, role: .cancel) {
                    AccountDeletionService.shared.acknowledgeFailure()
                }
            } message: {
                Text(L10n.Settings.deleteAccountErrorMessage)
            }
            .onChange(of: deletionService.phase) { _, newPhase in
                syncDeletionUI(from: newPhase)
            }
            .onAppear { syncDeletionUI(from: deletionService.phase) }
            .onAppear {
                // Auto-navigate to destination passed by caller (e.g. sync settings sheet).
                if let dest = initialDestination {
                    navigationPath.append(dest)
                }
            }
            // .routerConsumer(.profile) removed in F7 — was dead code (drained
            // .profileNavigate intent but never produced one, and consumed without
            // acting). Profile navigation flows through ContentView.handleMainTabIntent
            // for tab routing instead.
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .accounts:
                    AccountsSettingsListView()
                case .categories:
                    CategoriesSettingsListView()
                case .tags:
                    TagsSettingsListView()
                case .themes:
                    ThemeSettingsView {
                        dismiss()
                    }
                case .personalization:
                    PersonalizationSettingsView()
                case .currency:
                    CurrencySettingsView()
                case .appIcon:
                    AppIconSettingsView()
                case .faceIDProtectionGuide:
                    FaceIDProtectionGuideView()
                case .subscription:
                    SubscriptionView(source: "profile")
                case .tips:
                    TutorialsListView()
                case .faq:
                    FAQView()
                case .notifications:
                    NotificationsSettingsView()
                case .favorites:
                    FavoritesListView(mode: .manage)
                case .budgets:
                    BudgetsFavoritesSettingsView()
                case .planned:
                    ScheduledPaymentsSettingsView()
                case .userDataReset:
                    UserDataResetView(onRequestCloseSettings: {
                        dismiss()
                    })
                case .iCloudSync:
                    iCloudSyncSettingsView()
                case .siriShortcuts:
                    SiriShortcutsView()
                case .aiPrivacy:
                    AIPrivacySettingsView()
                case .storageMode:
                    // Paso 10 · el CTA de asociar cierra ESTE sheet y emite el intent: el sheet del
                    // sign-in de Grupos tiene dueño único (`GroupsBackendInviteModifier`, anclado en
                    // `ContentView`) y dos anchors ante el mismo observable es el bug de sign-out del
                    // 2026-07-14 — UIKit no presenta dos veces y puede tumbar las dos cadenas. Misma
                    // forma que los desenlaces de `YalaAccountView`: la vista pide, `ProfileView` cierra.
                    StorageSettingsView(onAssociateGroupsAccount: {
                        dismiss()
                        // **Sin `sleep` de por medio, y es lo que hace seguro el gesto.** El intent va por
                        // el router porque el router RETIENE la cola mientras un nodo superior tape
                        // (`RouterConsumerGateLogic`, peek-first): si este sheet todavía no ha terminado
                        // de irse, el intent espera y se drena cuando el anchor quede libre. Un
                        // `Task { sleep 350 ms }` apostaba a un reloj —y el flag que enciende es BLOCKER
                        // de la matriz de readiness, así que una presentación que no monta deja el router
                        // muerto el resto de la sesión, sin `onDismiss` que rescate porque nunca se
                        // presentó. Es el modo de fallo de la regla (4) de Presentaciones.
                        RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: ""))
                    })
                case .yalaAccount:
                    // §3.3.5: mapa/explainer del enlace privado ↔ nube. Los desenlaces disparan el @State
                    // de ProfileView vía closures (dueño único de las hojas/observers/cover-root); "Volver a
                    // iCloud" navega por su cuenta a `.storageMode`. «Cerrar sesión» es el MISMO toque que la
                    // fila de Ajustes (`requestSignOut`), y el borrado recomputa el resumen D5 READ-ONLY. Desde
                    // el paso 9 es la única puerta del borrado, así que hereda el bloqueo cruzado de la fila
                    // retirada: con un cierre o un borrado en curso, el otro no arranca.
                    YalaAccountView(
                        onSignOut: { requestSignOut() },
                        onDeleteAccount: {
                            deleteAccountScope = DeleteAccountScope(
                                summary: GroupService.shared.accountDeletionGroupsSummary())
                        },
                        signOutDisabled: signOutCoordinator.phase == .working || deletionService.phase == .working,
                        deleteDisabled: signOutCoordinator.phase != .idle || deletionService.phase == .working)
                }
            }
            .onAppear {
                viewModel.setContext(modelContext)
                profileStorage.migrateFromUserDefaultsIfNeeded()
            }
        }
        .coachMarkOverlay(
            steps: SettingsTourSteps.steps,
            isPresented: $showSettingsTour,
            currentIndex: $settingsTourIndex,
            scrollProxy: settingsScrollProxy,
            onComplete: { appPreferences.hasSeenSettingsTour = true }
        )
        .coachMarkOverlay(
            steps: ProTourSteps.profileSteps,
            isPresented: $showProTour,
            currentIndex: $proTourIndex,
            scrollProxy: settingsScrollProxy,
            onComplete: {
                ProTourManager.shared.advancePhase()
            }
        )
        .task {
            // El coach mark monta un overlay-spotlight que intercepta taps; en uitest
            // bloquearía la navegación de Settings. Suprimido como el resto de overlays
            // de primer uso (F1c). También en solo-grupos: varios anclajes apuntan a
            // filas (Cuentas, Categorías…) ocultas en ese modo.
            guard !UITestHooks.isActive, !isGroupsOnlyShell else { return }
            if !appPreferences.hasSeenSettingsTour {
                do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
                if !appPreferences.hasSeenSettingsTour {
                    showSettingsTour = true
                }
            }
        }
        .task(id: appPreferences.hasSeenSettingsTour) {
            guard !UITestHooks.isActive, !isGroupsOnlyShell else { return }
            guard appPreferences.hasSeenSettingsTour else { return }
            // Re-check eligibility (covers race: subscribed before tours completed)
            ProTourManager.shared.triggerIfEligible()
            guard ProTourManager.shared.currentPhase == .profile else { return }
            do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
            guard ProTourManager.shared.currentPhase == .profile,
                  !showSettingsTour else { return }
            showProTour = true
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: DS.Spacing.md) {
            // Avatar - tappable to edit profile
            Button {
                activeSheet = .personalDetails
            } label: {
                ZStack {
                    // Pro users get golden gradient ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: showsProBadge
                                    ? DS.Gradients.proBadge
                                    : [theme.accent, theme.accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 100, height: 100)

                    if let imageData = profileStorage.imageData,
                        let uiImage = UIImage(data: imageData)
                    {
                        // User photo
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else {
                        // Custom icon or default
                        Circle()
                            .fill(theme.accent.opacity(0.1))
                            .frame(width: 90, height: 90)

                        Image(systemName: appPreferences.userProfileIcon.isEmpty ? "person.fill" : appPreferences.userProfileIcon)
                            .font(.system(size: avatarIconSize))
                            .foregroundStyle(theme.accent)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }

                    // Spark badge for Pro users
                    if showsProBadge {
                        ZStack {
                            Circle()
                                .fill(.thCard)
                            YalaSpark(size: .medium, animated: true)
                        }
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .offset(x: 38, y: -38)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Accessibility.profile)

            // Name
            Text(appPreferences.userName)
                .font(DS.Typography.title)
                .foregroundStyle(.primary)

            // Pro badge with cyan spark (only here, so it stands out)
            if showsProBadge {
                proBadgeWithCyanSpark
            }

            Button(L10n.Profile.edit) {
                activeSheet = .personalDetails
            }
            .font(DS.Typography.label)
            .foregroundStyle(.primary)

        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, showsProBadge ? DS.Spacing.lg : 0)
        .background(
            Group {
                if showsProBadge {
                    LinearGradient(
                        // A11Y-DM: tinte dorado Pro sutil decorativo (casi invisible, adapta a Dark Mode)
                        colors: [Color.yellow.opacity(0.03), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        )
        .sheet(isPresented: $showUpgradeForVoice) {
            UpgradePromptSheet(feature: .voiceInput, context: .proFeature)
        }
        .sheet(isPresented: $showUpgradeForImage) {
            UpgradePromptSheet(feature: .imageInput, context: .proFeature)
        }
        .sheet(isPresented: $showUpgradeForInsights) {
            UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)
        }
        .sheet(isPresented: $showUpgradeForChat) {
            UpgradePromptSheet(feature: .chatAssistant, context: .proFeature)
        }
    }

    // MARK: - Pro Badge with Cyan Spark

    /// Custom Pro badge with cyan spark so it stands out against the gold background
    private var proBadgeWithCyanSpark: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Cyan spark (instead of gold)
            YalaSparkShape()
                .fill(Color.cyan) // DS-OK: decorative section accent
                .frame(width: 12, height: 12)

            Text("PRO")
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            LinearGradient(
                colors: DS.Gradients.proBadge,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
    }

    // MARK: - Sections

    /// CTA «Activar Yala completo» para quien tiene la shell reducida a Grupos. Abre el flujo guiado
    /// (FullModeActivationView vía router), que enciende el eje 1 y con eso des-reduce la shell.
    /// Molde de `MoreView.activateFullYalaButton`.
    private var activateFullYalaSection: some View {
        Button {
            RouterEntryGate.shared.submit(.presentFullModeActivation)
        } label: {
            HStack(spacing: DS.FormRow.iconSpacing) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
                    .frame(width: DS.FormRow.iconWidth, height: DS.FormRow.iconWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.accent)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Groups.Activate.title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(L10n.Groups.Activate.subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .solidCard(radius: DS.Radius.xl)
        .dsSubtleShadow()
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityIdentifier("profile_activate_full_yala")
    }

    private var organizacionSection: some View {
        SectionBox(title: L10n.Settings.organization) {
            VStack(spacing: DS.Spacing.none) {
                profileRow(
                    icon: "creditcard.fill", title: L10n.Settings.accounts, iconColor: DS.Semantic.successForeground,
                    destination: .accounts)
                    .accessibilityIdentifier("profile_accounts")
                    .coachMarkAnchor("settingsAccounts")
                SubsectionDivider()
                profileRow(
                    icon: "tag.fill", title: L10n.Settings.categories, iconColor: .orange,
                    destination: .categories)
                    .accessibilityIdentifier("profile_categories")
                    .coachMarkAnchor("settingsCategories")
                SubsectionDivider()
                profileRow(
                    icon: "number", title: L10n.Settings.tags, iconColor: .purple,
                    destination: .tags)
                    .accessibilityIdentifier("profile_tags")
                    .coachMarkAnchor("settingsTags")
                SubsectionDivider()
                profileRow(
                    icon: "chart.pie.fill", title: L10n.Settings.budgets,
                    iconColor: .mint,
                    destination: .budgets)
                    .coachMarkAnchor("settingsBudgets")
                SubsectionDivider()
                profileRow(
                    icon: "calendar.badge.clock", title: L10n.Settings.plannedPayments,
                    iconColor: .cyan,
                    destination: .planned
                )
                .accessibilityIdentifier("profile_planned")
                .coachMarkAnchor("settingsPlanned")
                SubsectionDivider()
                profileRow(
                    icon: "star.fill", title: L10n.Settings.favorites, iconColor: .yellow,
                    destination: .favorites)
                    .accessibilityIdentifier("profile_favorites")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var preferenciasSection: some View {
        SectionBox(title: L10n.Settings.preferences) {
            VStack(spacing: DS.Spacing.none) {
                // Personalización (formato, calendario, modo solo-gastos…) es de
                // finanzas personales: oculta en solo-grupos.
                if !isGroupsOnlyShell {
                    profileRow(
                        icon: "slider.horizontal.3", title: L10n.Settings.personalization,
                        iconColor: .indigo, destination: .personalization)
                    .accessibilityIdentifier("profile_personalization")
                    .coachMarkAnchor("settingsPersonalization")
                    SubsectionDivider()
                }
                // Notificaciones: universal (los grupos generan avisos).
                profileRow(
                    icon: "bell.fill", title: L10n.Settings.notifications, iconColor: .red,
                    destination: .notifications)
                .accessibilityIdentifier("profile_notifications")
                // Divisa/tasas e Icono de app: ocultos en solo-grupos (formato queda en
                // defaults: 2 decimales + símbolo de la moneda del grupo).
                if !isGroupsOnlyShell {
                    SubsectionDivider()
                    profileRow(
                        icon: "dollarsign.circle.fill", title: L10n.Settings.currencyAndExchange,
                        iconColor: DS.Semantic.successForeground, destination: .currency
                    )
                    .accessibilityIdentifier("profile_currency")
                    SubsectionDivider()
                    profileRow(
                        icon: "app.fill", title: L10n.Settings.appIcon,
                        iconColor: .blue, destination: .appIcon)
                    .coachMarkAnchor("settingsAppIcon")
                }
                SubsectionDivider()
                profileRow(
                    icon: "paintpalette.fill", title: L10n.Settings.theme, iconColor: .pink,
                    destination: .themes)
                .coachMarkAnchor("settingsTheme")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }


    private var datosSection: some View {
        SectionBox(title: L10n.Settings.data) {
            VStack(spacing: DS.Spacing.none) {
                // §3.2: orden de DATOS = Exportar → Importar → "Dónde viven tus datos" → Vaciar (escalera
                // de gravedad). La fila "Tu cuenta de Yala" ya NO vive aquí (movida a la subsección "Tu
                // cuenta" de Seguridad). Exportar: personal (wizard con filtros) o SOLO-GRUPOS (D6 §3.3.6 —
                // el builder de grupos vive; el solo-grupos legado exporta directo, sin el wizard personal
                // que exigiría seleccionar una cuenta). Primera fila ⇒ sin divisor arriba.
                Button {
                    activeSheet = isGroupsOnlyShell ? .groupsExport : .exportWizard
                } label: {
                    settingsRowContent(
                        icon: "square.and.arrow.up.fill", title: L10n.Settings.exportData,
                        subtitle: L10n.Settings.exportDataSubtitle,
                        iconColor: .mint
                    )
                    .opacity(isExportEnabled ? 1.0 : 0.5)
                }
                .accessibilityHint(isExportEnabled ? "" : exportDisabledHint)
                .disabled(!isExportEnabled)
                .buttonStyle(.plain)
                .coachMarkAnchor("proExportExtended")

                // Importar opera sobre transacciones personales: oculto en solo-grupos.
                if !isGroupsOnlyShell {
                    SubsectionDivider()
                    Button {
                        activeSheet = .importIntro
                    } label: {
                        settingsRowContent(
                            icon: "tray.and.arrow.down.fill", title: L10n.Settings.importData,
                            iconColor: .blue)
                    }
                    .buttonStyle(.plain)
                }

                // La fila "iCloud" se oculta en Modo Nube (`.cloud`): `iCloudSyncSettingsView` mentiría
                // (el store personal ya no lo espeja el mirror). Cada bloque condicional lleva su divisor
                // arriba ⇒ nunca queda un divisor colgante si una fila anterior se oculta.
                if CloudSyncFlags.storageMode != .cloud {
                    SubsectionDivider()
                    profileRow(
                        icon: "icloud.fill",
                        title: L10n.iCloud.title,
                        iconColor: .blue,
                        destination: .iCloudSync
                    )
                }

                // §3.2: "Dónde viven tus datos" (antes "Almacenamiento"; key `storage.title` renombrada).
                // Modo Nube (I14): exige backend configurado, abierto en los dos schemes desde D-R1 paso 1
                // ⇒ hoy en producción lo que mantiene la fila oculta es el flag remoto (percent 0), no
                // `isConfigured`. DIFERIDOS #34: el flag remoto gatea solo la ENTRADA — un usuario
                // "engaged" conserva la fila SIEMPRE.
                // Paso 10 (2026-09-11): y una cuenta de grupos que soltar la conserva también. Detrás de
                // esta fila vive la ÚNICA superficie desde la que se suelta esa cuenta, y Grupos va por su
                // propio flag: sin este término, bajar el kill de la nube dejaba la cuenta puesta y sin
                // puerta. El criterio es el MISMO que dibuja el botón «Desasociar» y sale de la misma
                // lectura (`GroupsAssociationPresence`) — leerlo dos veces es cómo divergen, y divergían.
                // Quien decide qué se ofrece DENTRO bajo el kill es `offersCloudMigrationEntry`, en
                // `StorageSettingsView` — abrir la fila no abre la migración.
                if StorageRowGateLogic.isVisible(
                    isConfigured: CloudBackendConfig.isConfigured,
                    remoteEnabled: CloudRemoteFlags.cloudModeEnabled,
                    isEngaged: StorageRowGateLogic.isEngaged(
                        persistedMode: StorageModePersistence.read(),
                        uiState: CloudMigrationController.shared?.uiState ?? .idle),
                    hasGroupsAccountToDetach: GroupsAssociationPresence.offersDetach(
                        hasCompletedOnboarding: appPreferences.hasCompletedOnboarding)
                ) {
                    SubsectionDivider()
                    NavigationLink(value: ProfileDestination.storageMode) {
                        settingsRowContent(
                            icon: "externaldrive.badge.icloud",
                            title: L10n.Storage.title,
                            subtitle: dataLocationSubtitle,
                            iconColor: .indigo)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("storage_settings_row")
                }

                // Vaciar mis datos — SIEMPRE al final (lo más irreversible de la sección).
                SubsectionDivider()
                NavigationLink(value: ProfileDestination.userDataReset) {
                    // Fase 1 (§3.2): "arrow.counterclockwise" (volver al estado inicial);
                    // "trash" queda reservado a "Eliminar mi cuenta". `.red` es color de
                    // sistema (adapta a Dark Mode) → sin marcador A11Y-DM.
                    settingsRowContent(
                        icon: "arrow.counterclockwise", title: L10n.Settings.wipeData,
                        subtitle: L10n.Settings.wipeDataSubtitle, iconColor: .red)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile_security_reset_data")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var seguridadSection: some View {
        SectionBox(title: L10n.Settings.security) {
            VStack(spacing: DS.Spacing.none) {
                profileRow(
                    icon: "faceid",
                    title: L10n.Settings.faceIDProtection,
                    iconColor: DS.Semantic.successForeground,
                    destination: .faceIDProtectionGuide)
                    .accessibilityIdentifier("profile_security_faceid")
                // Atajos de Siri: registran gastos personales — fuera de alcance en solo-grupos.
                if !isGroupsOnlyShell {
                    SubsectionDivider()
                    profileRow(
                        icon: "mic.badge.plus", title: String(localized: "settings.siriShortcuts"),
                        iconColor: .blue, destination: .siriShortcuts)
                }
                SubsectionDivider()
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    settingsRowContent(
                        icon: "lock.shield.fill", title: L10n.Settings.permissions,
                        iconColor: .blue)
                }
                .buttonStyle(.plain)
                // Privacidad IA (chat) y Suscripción Pro: ligadas a finanzas personales.
                // En solo-grupos el upgrade fluye por "Activar Yala completo".
                if !isGroupsOnlyShell {
                    SubsectionDivider()
                    profileRow(
                        icon: "hand.raised.fill", title: L10n.Settings.aiPrivacy,
                        iconColor: .indigo, destination: .aiPrivacy)
                    SubsectionDivider()
                    profileRow(
                        icon: "creditcard.fill", title: L10n.Settings.subscriptions,
                        iconColor: .purple, destination: .subscription)
                }
                #if DEBUG
                if Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true {
                    SubsectionDivider()
                    devProToggleRow
                    SubsectionDivider()
                    devSeedDataRow
                }
                #endif
                SubsectionDivider()
                Button {
                    requestReview()
                } label: {
                    settingsRowContent(
                        icon: "star.bubble.fill", title: L10n.Settings.rateApp,
                        iconColor: .yellow)
                }
                .buttonStyle(.plain)
                // §3.2: subsección "Tu cuenta" — SOLO con sesión backend viva. Para VIVO sin sesión (TODO
                // device prod) nada se inserta. Agrupa «Tu cuenta de Yala →» (mapa/explainer, §3.3.5), que
                // desde el paso 9 es también la puerta de «Eliminar mi cuenta»; «Cerrar sesión» sigue debajo.
                if showsYalaAccountRow {
                    SubsectionDivider()
                    Text(L10n.Settings.accountSubsectionTitle)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.xs)
                        .accessibilityAddTraits(.isHeader)
                    NavigationLink(value: ProfileDestination.yalaAccount) {
                        settingsRowContent(
                            icon: "person.crop.circle.badge.checkmark",
                            title: L10n.Settings.yalaAccountRowTitle,
                            subtitle: L10n.Settings.yalaAccountRowSubtitle,
                            iconColor: .indigo)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile_yala_account")
                }
                // H4 + paso 9: «Cerrar sesión» — SIEMPRE al final, UNA fila y el mismo verbo en las cuatro celdas
                // del ADR 2026-09-09 (§6: «dos botones y nada más»), sin subtítulo: el detalle de qué se borra y
                // qué queda vive en la hoja de alcance, que nombra su celda. «Eliminar mi cuenta» ya no está
                // aquí: vive dentro de «Tu cuenta de Yala» (a dos toques), como pide la App Store 5.1.1(v).
                SubsectionDivider()
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        requestSignOut()
                    } label: {
                        settingsRowContent(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: L10n.Settings.signOut,
                            iconColor: .red,
                            showSpinner: signOutCoordinator.phase == .working)
                    }
                    .buttonStyle(.plain)
                    .disabled(signOutCoordinator.phase == .working || deletionService.phase == .working)
                    .accessibilityIdentifier("profile_security_signout")

                    signOutWorkingCaption
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    #if DEBUG
    private var devProToggleRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "sparkles")
                .font(DS.Typography.subheadline).fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange) // DS-OK: decorative section accent
                )

            Text("Simular Pro")
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { StoreKitManager.shared.devForceProTier },
                set: { _ in StoreKitManager.shared.toggleDevProTier() }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var devSeedDataRow: some View {
        Button {
            if seedService.hasSeeded {
                showSeedConfirmation = true
            } else {
                Task { await seedService.seed(in: modelContext) }
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: seedService.hasSeeded ? "arrow.clockwise" : "square.and.arrow.down.fill")
                    .font(DS.Typography.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(seedService.hasSeeded ? Color.orange : Color.teal)
                    )

                Text(seedService.hasSeeded ? "Recargar datos de prueba" : "Cargar datos de prueba")
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
        }
        .buttonStyle(.plain)
        .alert("¿Recargar datos de prueba?", isPresented: $showSeedConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Recargar", role: .destructive) {
                Task { await seedService.reset(in: modelContext) }
            }
        } message: {
            Text("Se eliminarán todos los datos existentes y se cargarán datos de prueba nuevos.")
        }
        .sheet(isPresented: $showSeedProgress) {
            devSeedProgressSheet
        }
        .onChange(of: seedService.isSeeding) { _, newValue in
            showSeedProgress = newValue
        }
    }

    private var devSeedProgressSheet: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "cylinder.split.1x2.fill")
                .font(.system(size: 48)) // A11Y-DT: debug-only seed progress view
                .foregroundStyle(DS.Semantic.imageAccent)

            Text("Generando datos de prueba")
                .font(DS.Typography.headline)

            VStack(spacing: DS.Spacing.sm) {
                ProgressView(value: seedService.progress)
                    .tint(DS.Semantic.imageAccent)

                Text(seedService.stepLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.xxxl)

            Text("\(Int(seedService.progress * 100))%")
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()
        }
        .interactiveDismissDisabled()
        .presentationDetents([.medium])
    }
    #endif

    private var ayudaSection: some View {
        SectionBox(title: L10n.Settings.help) {
            VStack(spacing: DS.Spacing.none) {
                // Tutoriales: el catálogo es de finanzas personales (no hay tutorial de
                // grupos) → oculto en solo-grupos.
                if !isGroupsOnlyShell {
                    profileRow(
                        icon: "book.fill", title: L10n.Settings.tutorials,
                        iconColor: .electricIndigo, destination: .tips)
                    .coachMarkAnchor("settingsTutorials")
                    SubsectionDivider()
                }
                profileRow(
                    icon: "questionmark.circle.fill", title: L10n.Settings.faq,
                    iconColor: .orange, destination: .faq)
                SubsectionDivider()
                Button {
                    showSupportSheet = true
                } label: {
                    settingsRowContent(
                        icon: "envelope.fill", title: L10n.Settings.contact,
                        iconColor: .teal)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showSupportSheet) {
                    SupportFormSheet()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var legalSection: some View {
        SectionBox(title: L10n.Settings.legal) {
            VStack(spacing: DS.Spacing.none) {
                Button {
                    openURL(AppConstants.privacyURL)
                } label: {
                    settingsRowContent(
                        icon: "hand.raised.fill", title: L10n.Settings.privacy,
                        iconColor: .gray)
                }
                .buttonStyle(.plain)
                SubsectionDivider()
                Button {
                    openURL(AppConstants.termsURL)
                } label: {
                    settingsRowContent(
                        icon: "doc.text.fill", title: L10n.Settings.terms,
                        iconColor: .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }


    // MARK: - Reference Builder

    private func profileRow(
        icon: String,
        title: String,
        iconColor: Color = .gray,
        destination: ProfileDestination
    ) -> some View {
        NavigationLink(value: destination) {
            settingsRowContent(icon: icon, title: title, iconColor: iconColor)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowContent(
        icon: String,
        title: String,
        subtitle: String? = nil,
        iconColor: Color = .gray,
        textColor: Color = .primary,
        showSpinner: Bool = false
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Conditionally show colored or plain icons based on setting
            if effectiveColorfulIcons {
                // iOS-style colored icon with rounded square background
                Image(systemName: icon)
                    .font(DS.Typography.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(iconColor)
                    )
                    .accessibilityHidden(true)
            } else {
                // Plain icon without background
                Image(systemName: icon)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(textColor)

                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            // H-2026-07-18-6: spinner inline en la fila mientras el cierre de sesión trabaja
            // (reemplaza el chevron — el resto de filas conservan el chevron por default false).
            if showSpinner {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
    }

}

#Preview {
    ProfileView()
        .previewAppPreferences()
}
