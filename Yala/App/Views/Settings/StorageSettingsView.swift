//
//  StorageSettingsView.swift
//  Yala
//
//  UI real de migración/reversa del Modo Nube (I14 P3). Pantalla de Ajustes (stack de Profile →
//  `.subtle`) que expone, según el estado derivado del journal (`CloudMigrationController.uiState`):
//   - `.icloud` estable → "Migrar a la nube" (UNA hoja con lo que cambia y «Continuar con Apple/Google» → auth →
//     progreso → relaunch; UX 2.2 · L20-11) o, si el mirror trae el marcador de un líder
//     (`secondaryDeviceCloudLogin`), el copy de ADOPT (la misma hoja → auth).
//   - `.cloud` estable → "Volver a iCloud" (gate `ReverseEligibility` + una confirmación, L20-17) + estado de sync.
//   - Fase transicional → progreso (molde `OnboardingRestoreProgress`) + "Retomar"/"Reintentar".
//   - `needsRelaunch` → card BLOQUEANTE "cierra Yala y vuelve a abrirla" (relaunch asistido — NUNCA `exit()`).
//
//  Solo alcanzable si `CloudBackendConfig.isConfigured` (la fila de Profile la oculta si no).
//

import SwiftUI
import SwiftData

struct StorageSettingsView: View {

    /// Paso 10 · qué hace el CTA de «Asociar una cuenta para grupos». Lo cablea `ProfileView`, que es
    /// quien puede cerrar su propio sheet: el sheet del sign-in de Grupos tiene dueño único en
    /// `ContentView` y presentarlo desde aquí sería un segundo anchor del mismo sheet. Opcional para que
    /// los demás call-sites y las previews no cambien.
    var onAssociateGroupsAccount: (() -> Void)?
    /// El controller de producción (SSOT del runner). `nil` solo si el backend no está configurado — en
    /// ese caso la fila de Profile ni aparece, pero se degrada elegante por si se navega directo.
    private var controller: CloudMigrationController? { CloudMigrationController.shared }

    /// La hoja única de activar la nube (UX 2.2 · L20-11/12): consentimiento, confirmación y método en un solo paso. Va
    /// por `.sheet(item:)` con lo que enseña DENTRO (la ruta y la cifra): con `isPresented` y la cifra en otro `@State`, la
    /// hoja podía abrirse la primera vez sin la cifra (`swiftui-ds.md`, medido en Buscar; review del 2026-10-19).
    @State private var activationRequest: CloudActivationRequest?
    @State private var consentPath: CloudMigrationController.ConsentPath = .migration
    /// One-shot de la hoja: lo quema el botón de entrar y lo CONSUME el `onDismiss` (regla 4 de presentaciones: la
    /// migración —y la auth de Google, que busca el VC de arriba— jamás arranca con la hoja aún bajando).
    /// «Cancelar» y el swipe no lo queman → no-op.
    @State private var activationPlan: CloudMigrationController.SignInPlan?
    /// Chooser de método (Apple | Google). Desde L20-11 solo lo abre «Usar otra cuenta» del aviso de bloqueo: la entrada
    /// normal elige el método en la hoja única.
    @State private var showSignInChooser = false
    /// Provider elegido en el chooser; lo consume el `onDismiss` del sheet del chooser (con el
    /// anchor YA estable — Google resuelve su presenter por topmost VC). Cancel = queda `nil` → no-op.
    @State private var chosenProvider: CloudSignInProvider?
    /// One-shot del belt del chooser (C-7): el sheet se presentó con sesión viva y se cerró solo;
    /// el `onDismiss` arranca con `.reuseLiveSession`. Cancel/drag-dismiss no lo quema → no-op.
    @State private var reuseLiveSession = false
    /// **El diálogo del borrado de iCloud pendiente** (ticket
    /// `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`). Sale al tocar «Activar la nube» o
    /// «Activar en este dispositivo» si la persona pidió borrar su iCloud y el borrado no terminó: en la nube ya no se
    /// puede terminar, así que se le pregunta en vez de retirarlo en silencio en el arranque.
    @State private var confirmPendingICloudWipe = false
    /// «Activar la nube sin borrar» de ESTE intento. Lo convierte en la renuncia durable `startActivation`, cuando la
    /// migración arranca —echarse atrás antes, en el consentimiento o las confirmaciones, no deja nada—, y la renuncia no
    /// retira el borrado: lo retira el arranque en la nube si el dispositivo llega (`retireWaivedInCloud`). Cada toque del
    /// botón lo baja antes de volver a mirar.
    @State private var pendingICloudWipeWaived = false
    /// La única confirmación de «Volver a iCloud» (L20-17): antes eran dos que decían lo mismo.
    @State private var confirmRevert = false
    /// Lo que el iCloud del teléfono sumaría a la vuelta, si la pregunta encontró algo
    /// (`CloudMigrationController.checkICloudBeforeReverse`). Copiado para presentarlo: el aviso no se queda sin cifras si
    /// la tarjeta se repinta.
    @State private var revertPriorData: ICloudForeignCorpus?
    @State private var showRevertPriorData = false
    /// «Empezar sin ellos» pide su propio «¿seguro?»: borra de iCloud y no tiene vuelta.
    @State private var confirmDiscardPriorData = false
    /// La pregunta a iCloud no contestó, o no hay iCloud al que preguntar: la vuelta no empieza y se ofrece reintentar.
    /// `revertNeedsICloud` elige el texto.
    @State private var showRevertCheckFailed = false
    @State private var revertNeedsICloud = false
    /// La persona eligió «Sumarlos a mis datos» y la confirmación de siempre es la de esa vuelta. Lo baja cada toque del botón.
    @State private var revertMergesPriorData = false
    /// Confirmación de «Cancelar y seguir en la nube» en la espera de la vuelta a iCloud. Un solo diálogo, colgado
    /// del propio botón: no encadena con los de `StorageConfirmations`.
    @State private var confirmCancelReverse = false
    /// Confirmación de «Cancelar la activación» durante la subida del snapshot de la ida. Mismo molde que la de arriba.
    @State private var confirmCancelMigration = false
    /// La de «Dejar de esperar», en la espera del seguidor. Aparte de la de arriba: su diálogo dice otra cosa, y con un solo
    /// flag un diálogo abierto en la espera podía reaparecer en la tarjeta de progreso con el cuerpo de otra fase.
    @State private var confirmStopWaiting = false
    @State private var showError = false
    /// El aviso de un «Migrar a la nube» que se paró (`CloudMigrationController.migrationIdentityBlock`), copiado para
    /// presentarlo: la hoja no se queda vacía si el controller lo suelta mientras está arriba. El controller lo suelta
    /// cuando la hoja monta.
    @State private var presentedMigrationBlock: MigrationIdentityBlock?
    /// One-shot de «Usar otra cuenta»: lo quema el botón y lo consume el `onDismiss` de la hoja, que abre la elección de
    /// Apple/Google con la hoja ya abajo. «Entendido» y el swipe no lo queman.
    @State private var migrationBlockUseAnotherAccount = false
    /// Tick de refresco del journal vivo (el runner no es `@Observable`).
    @State private var refreshTick = false
    /// **El veredicto de App Attest de ESTE teléfono** (ticket
    /// `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`). Lo mantiene al día
    /// `cloudAttestVerdictWatcher`; no sale de `controller` porque `refreshSyncBanner` solo mira
    /// `.stoppedUntilSignIn` y el attest terminal deja el runtime en `.stoppedUntilRelaunch`.
    @State private var attestVerdictIsTerminal = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                if let controller {
                    content(controller)
                } else {
                    Text(L10n.Storage.Errors.generic)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.lg)
                }

                #if DEV_BUILD
                cloudDebugPanel
                #endif
            }
            .padding(.vertical, DS.Spacing.xxl)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Storage.title)
        .navigationBarTitleDisplayMode(.inline)
        // Mantiene al día el veredicto del attest que lee `syncStatusSection` (los tres momentos, en el modifier).
        .cloudAttestVerdictWatcher($attestVerdictIsTerminal)
        .task {
            // DIFERIDOS #34: refresh del remote-config en la ENTRADA de migración (min-interval 6 h).
            // El kill-switch se re-verifica en la puerta.
            // Bajo uitest NO se toca red (hermeticidad — los getters ya devuelven el default).
            guard !SwiftDataConfiguration.isUITesting else { return }
            await RemoteConfigClient.shared.refreshIfDue()
        }
        .task {
            // Refresca el journal vivo cada 1s mientras la pantalla está abierta (molde del panel DEBUG).
            var tick = 0
            while !Task.isCancelled {
                controller?.refresh()
                refreshTick.toggle()
                // C-1 (watchdog): el poll de 1 s solo LEE, y la cadencia del runner es boot/foreground/tap —
                // así que el usuario que se queda mirando la barra en el paso 4 tendría que salir y volver
                // para que el tope llegue a evaluarse. Un empujón cada 30 s lo resuelve sin loop: el gate puro
                // `MigrationForegroundRekick.shouldRekick` ya descarta fases estables y trabajo en vuelo.
                tick += 1
                // Sin `await` (2026-10-19, ticket `cloud-activation-waits-for-icloud-with-no-way-out`): el re-kick puede
                // quedarse hasta 300 s en la pre-espera del import, y esperándolo este bucle dejaba de refrescar —la
                // pantalla congelada en el paso viejo—. `rekickIfParked` ya no hace nada con trabajo en vuelo.
                // La cadencia sale de la fase (`screenRekickSeconds`): 5 s donde solo falta observar algo local de iCloud
                // —la cifra de la vuelta se relee así—, 30 s en el resto (ticket `cloud-progress-shows-real-steps-and-counts`).
                if let controller, tick % controller.screenRekickSeconds == 0 { Task { await controller.rekickIfParked() } }
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
            }
        }
        .sheet(item: $activationRequest, onDismiss: onActivationSheetDismissed) { request in
            CloudActivationSheet(
                path: request.path,
                decision: signInDecision(isAdopt: request.path == .adopt),
                preview: request.preview,
                onContinue: { plan in
                    activationPlan = plan
                    activationRequest = nil
                })
        }
        .sheet(isPresented: $showSignInChooser, onDismiss: onChooserDismissed) {
            StorageSignInChooserView(
                decision: signInDecision(isAdopt: consentPath == .adopt),
                onSelect: { provider in
                    chosenProvider = provider
                    showSignInChooser = false
                },
                onReuseLiveSession: {
                    reuseLiveSession = true
                    showSignInChooser = false
                })
        }
        .sheet(item: $presentedMigrationBlock, onDismiss: onMigrationBlockDismissed) { block in
            StorageMigrationBlockedView(
                block: block,
                onUseAnotherAccount: {
                    migrationBlockUseAnotherAccount = true
                    presentedMigrationBlock = nil
                },
                onClose: { presentedMigrationBlock = nil })
            // El aviso se consume cuando la hoja MONTA, no al pedirla (regla 3 de presentaciones): si la pantalla se va
            // mientras llega, o el anchor está ocupado, sigue en el controller y sale la próxima vez.
            .onAppear {
                if controller?.migrationIdentityBlock?.id == block.id { controller?.migrationIdentityBlock = nil }
            }
        }
        // `initial: true`: un aviso publicado mientras la persona no tenía esta pantalla delante sale al volver a ella.
        .onChange(of: controller?.migrationIdentityBlock?.id, initial: true) { _, id in
            guard id != nil, let block = controller?.migrationIdentityBlock else { return }
            presentedMigrationBlock = block
        }
        .modifier(StorageConfirmations(
            confirmRevert: $confirmRevert,
            onRevert: startConfirmedReverse))
        .modifier(StorageRevertPriorDataDialogs(
            priorData: revertPriorData,
            showPriorData: $showRevertPriorData,
            confirmDiscard: $confirmDiscardPriorData,
            showCheckFailed: $showRevertCheckFailed,
            needsICloud: revertNeedsICloud,
            onMerge: chooseMergingPriorData,
            onDiscard: { Task { await controller?.startReverseDiscardingICloudPriorData() } },
            onRetryCheck: retryRevertCheck))
        .alert(L10n.Storage.Errors.title, isPresented: $showError, presenting: controller?.lastError) { _ in
            Button(L10n.Common.ok, role: .cancel) { controller?.lastError = nil }
        } message: { message in
            Text(message)
        }
        .onChange(of: controller?.lastError) { _, newValue in
            showError = (newValue != nil)
        }
        // Si la vuelta avanza con la confirmación de «Cancelar» abierta —drenó, saltó el techo, o simplemente pasó
        // a la fase siguiente—, el botón que la ancla desaparece y SwiftUI puede cerrarla sin tocar el flag. Sin
        // esto, el diálogo reaparecería solo en la siguiente fase que lo ofrezca.
        .onChange(of: controller?.canCancelReverse) { _, cancellable in
            if cancellable != true { confirmCancelReverse = false }
        }
        // Lo mismo para «Cancelar la activación»: si la activación sale de una fase que lo ofrece —avanza a una que no, o
        // vence su techo— con el diálogo abierto, no puede reaparecer en otra pantalla por un flag que nadie bajó.
        .onChange(of: controller?.canCancelMigration) { _, cancellable in
            if cancellable != true { confirmCancelMigration = false }
        }
        .onChange(of: controller?.canStopWaitingForLeader) { _, waiting in
            if waiting != true { confirmStopWaiting = false }
        }
        // Y el diálogo del borrado pendiente, que cuelga del botón de la tarjeta: si la tarjeta se va con él abierto —sale
        // de `.idle` o se cierra la entrada—, no puede reaparecer solo cuando vuelva.
        .onChange(of: showsMigrateCard) { _, shown in
            if !shown { confirmPendingICloudWipe = false }
        }
    }

    // MARK: - Contenido por estado

    @ViewBuilder
    private func content(_ controller: CloudMigrationController) -> some View {
        switch controller.uiState {
        case .idle:
            statusCard(controller)
            // Paso 10 · la asociación de grupos va DEBAJO del estado y ENCIMA de migrar: pertenece a
            // «dónde viven tus datos», pero lo que la persona viene a hacer aquí casi siempre es lo
            // personal. La propia sección se oculta cuando no aplica (`notApplicable`).
            GroupsAssociationSection(onAssociate: onAssociateGroupsAccount)
            // **El kill-switch de la nube cierra la ENTRADA, y desde 2026-09-11 tiene que decirlo aquí.**
            // Hasta hoy la card no necesitaba candado propio: la fila de Ajustes estaba oculta bajo el
            // kill y con ella toda la pantalla. Ahora la fila la abre también una cuenta de grupos que
            // soltar (`StorageRowGateLogic.isVisible`), así que quien entra a soltar esa cuenta durante
            // un incidente llegaría hasta aquí — y sin este `if` se encontraría «Migrar a la nube»
            // abierto, que es justo lo que el incidente cerró. La reversa no pasa por aquí: vive en
            // `.cloudActive` y es el escape.
            // Desde 2026-09-16 el mismo `if` esconde la card a un teléfono sin App Attest: ni migrar ni activar
            // en este dispositivo, porque nada de lo que sube o baja llegaría.
            if offersCloudMigrationEntry {
                migrateCard(controller)
            }
        case .cloudActive:
            statusCard(controller)
            // En la nube completa la sección solo informa («tus grupos usan esta misma cuenta») y no
            // ofrece desasociar: ADR §4.
            GroupsAssociationSection(onAssociate: onAssociateGroupsAccount)
            syncStatusSection(controller)
            if controller.showsReverseStepsBeforeJournal {
                reverseStartingCard(controller)
            } else {
                revertCard(controller)
            }
        case .migrating(let step):
            progressCard(controller, step: step, reverse: false)
            // El efecto del adopt que se reintenta sale del journal y puede durar hasta su techo de 72 h (ticket
            // `adopt-effect-retries-forever-with-no-ceiling`): como `.waitingForLeader` y `.failed`, conserva la sección, o
            // quien quiera soltar su cuenta de grupos se quedaría sin puerta todo ese tiempo. Los demás `.migrating` son
            // tránsitos y la siguen ocultando.
            if controller.isAdoptEffectPending {
                GroupsAssociationSection(onAssociate: onAssociateGroupsAccount)
            }
        case .reverting(let step):
            progressCard(controller, step: step, reverse: true)
        case .needsRelaunch(let direction):
            relaunchCard(controller, direction)
            // **Sin la sección de Grupos, y no por olvido** (ticket `needsrelaunch-hides-the-groups-section`, medido el
            // 2026-10-02). Este estado es durable como `.waitingForLeader` y `.failed`, pero aquí no hay ninguna puerta que
            // perder: las aristas que lo producen dejan el modo en `.cloud` —el cutover y el adopt arman el par,
            // `.rearmMirrorOff` lo re-arma y `.mountMirrorAndRelaunch` solo desarma el flag, porque `.icloud` no llega
            // hasta el cuarteto de cierre de `reverseUpload`—. Con `.cloud` la sección solo podría decir
            // `.sameAccountAsPersonal`, que no ofrece soltar nada. Lo fija
            // `MigrationWorkExecutorTests.needsRelaunch_keepsCloudMode_soTheGroupsSectionHasNoDoorToLose`.
        case .waitingForLeader:
            waitingCard(controller)
            // `.waitingForLeader` y `.failed` salen del journal PERSISTIDO: sobreviven al relanzamiento y
            // solo los cierra un reintento con éxito. No son tránsitos como `.migrating`, así que ocultar
            // aquí la sección dejaría sin poder desasociar —indefinidamente— a quien deja una migración
            // fallida para más adelante.
            GroupsAssociationSection(onAssociate: onAssociateGroupsAccount)
        case .failed(let kind):
            failedCard(controller, kind: kind)
            GroupsAssociationSection(onAssociate: onAssociateGroupsAccount)
        case .journalUnreadable:
            journalUnreadableCard()
            // La sección de Grupos se queda, como en `.failed` y `.waitingForLeader`: un journal que no se deja leer puede
            // durar, y ocultarla quitaría la única puerta para soltar esa cuenta. Soltarla no mueve los datos personales.
            GroupsAssociationSection(onAssociate: onAssociateGroupsAccount)
        }
    }

    // MARK: - Status card

    private func statusCard(_ controller: CloudMigrationController) -> some View {
        let isCloud = (CloudSyncFlags.storageMode == .cloud)
        return HStack(spacing: DS.Spacing.lg) {
            Image(systemName: isCloud ? "cloud.fill" : "lock.icloud.fill")
                .font(DS.Typography.title)
                .foregroundStyle(isCloud ? DS.Semantic.infoForeground : DS.Semantic.successForeground)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(isCloud ? L10n.Storage.Status.cloudTitle : L10n.Storage.Status.icloudTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                Text(isCloud ? L10n.Storage.Status.cloudBody : L10n.Storage.Status.icloudBody)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .storageCardStyle()
        .accessibilityIdentifier("storage_status_card")
    }

    // MARK: - Migrate / Adopt card

    private func migrateCard(_ controller: CloudMigrationController) -> some View {
        // El marcador de un líder en el mirror → copy de ADOPT (evita el falso "migrar" sobre cuenta poblada). Y desde
        // `adopt-claim-stays-parked-with-no-ceiling`, también tras un adopt que salió por su techo o por «Cancelar»: la
        // persona quería ENTRAR en esa cuenta, y «Migrar» la para la puerta de identidad. Esta tarjeta es su salida.
        let isAdopt = controller.offersAdoptReentry || controller.markerDecision() == .secondaryDeviceCloudLogin
        let decision = signInDecision(isAdopt: isAdopt)
        // La comprobación ya rechazó la cuenta de esta sesión: la tarjeta no la promete y no deja volver a pedirla
        // (ticket `migrate-card-keeps-promising-an-account-the-check-refused`). Solo en «Migrar»: el adopt no pasa por ella.
        let refusal = isAdopt ? nil : controller.liveSessionRefusal
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(isAdopt ? L10n.Storage.Adopt.title : L10n.Storage.Migrate.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Text(isAdopt ? L10n.Storage.Adopt.body : L10n.Storage.Migrate.body)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            switch decision {
            case .reuseLiveSession(let provider):
                if let refusal {
                    Text(L10n.Storage.Migrate.refusedNote(for: refusal))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Semantic.warningForeground)
                        .accessibilityIdentifier("storage_account_refused_note")
                } else {
                    // C-7: con sesión viva no se pregunta el método — decirlo ANTES, para que saltarse
                    // el chooser no sea una sorpresa. Cumple la promesa de `groups.signin.accountNote`.
                    Text(accountReuseNote(provider))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("storage_account_reuse_note")
                }
            case .blockedOtherAccount(let provider):
                // Esta copia pertenece a otra cuenta de Yala: adoptarla desde la sesión actual
                // mezclaría dos identidades. Se explica y se deshabilita el botón.
                Text(accountMismatchNote(provider))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Semantic.warningForeground)
                    .accessibilityIdentifier("storage_account_mismatch_note")
            case .askProvider:
                EmptyView()
            }

            // «Ver qué migraría» ya no está aquí (L20-11): la cifra la enseña la hoja de activar, en letra normal.

            YalaPrimaryButton(
                isAdopt ? L10n.Storage.Adopt.button : L10n.Storage.Migrate.button,
                icon: "arrow.up.to.line",
                isDisabled: controller.isWorking || isBlockedOtherAccount(decision) || isRefused(decision, refusal),
                isLoading: controller.isCheckingMigrationIdentity
            ) {
                // **Un borrado de iCloud pendiente se pregunta ANTES que todo lo demás**: es lo único de esta cadena que
                // la nube no puede deshacer después, y la persona tiene que elegir con él delante. Sin borrado pendiente,
                // la cadena de siempre.
                pendingICloudWipeWaived = false
                guard !hasPendingICloudWipe else {
                    confirmPendingICloudWipe = true
                    return
                }
                beginActivation(controller, isAdopt: isAdopt)
            }
            .accessibilityIdentifier("storage_migrate_button")
            .confirmationDialog(L10n.Storage.PendingICloudWipe.title,
                                isPresented: $confirmPendingICloudWipe, titleVisibility: .visible) {
                Button(L10n.Storage.PendingICloudWipe.proceed) {
                    // El botón de la tarjeta pudo deshabilitarse con el diálogo abierto: no se arranca encima.
                    guard !controller.isWorking else { return }
                    pendingICloudWipeWaived = true
                    beginActivation(controller, isAdopt: isAdopt)
                }
                .accessibilityIdentifier("storage_pending_icloud_wipe_proceed")
                // «Ahora no» deja el borrado como estaba y retira una renuncia de un intento anterior que no llegó a la
                // nube. **Sin `role: .cancel`, a propósito**: en iOS 26 el diálogo anclado al botón no pinta el de
                // cancelar, y la única salida visible sería tocar fuera (medido con el XCUITest de esta pantalla).
                Button(L10n.Storage.PendingICloudWipe.wait) {
                    StorageModePersistence.clearICloudCorpusWipeWaiver()
                }
                .accessibilityIdentifier("storage_pending_icloud_wipe_wait")
            } message: {
                Text(L10n.Storage.PendingICloudWipe.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
    }

    /// La tarjeta de la nube está en pantalla: la misma condición que el `if` de `case .idle`.
    private var showsMigrateCard: Bool {
        controller?.uiState == .idle && offersCloudMigrationEntry
    }

    /// ¿La persona pidió borrar su iCloud y el borrado no ha terminado? Armado o a medias, leído en vivo.
    /// `-uitest-pending-icloud-wipe` finge la ENTRADA —el estado real arrancaría el borrado en el propio arranque del
    /// XCUITest—; el diálogo, lo que hace cada botón y el retiro al arrancar la migración son los de producción.
    private var hasPendingICloudWipe: Bool {
        UITestHooks.fakePendingICloudWipe || StorageModePersistence.hasPendingICloudCorpusWipe()
    }

    /// El toque de «Activar la nube» / «Activar en este dispositivo», una vez resuelto el borrado pendiente. Con sesión
    /// viva, «Migrar» pregunta por la cuenta ANTES de abrir la hoja (Jürgen, 2026-09-16); sin sesión hay que firmar
    /// primero, y la comprobación va entre firmar y el claim. La hoja cuenta lo que pasaría al abrirse, no antes.
    /// `isAdopt` es la cara de la tarjeta del render que pintó el botón o el diálogo; la decisión de sesión se relee viva.
    private func beginActivation(_ controller: CloudMigrationController, isAdopt: Bool) {
        consentPath = isAdopt ? .adopt : .migration
        activationPlan = nil
        let decision = signInDecision(isAdopt: isAdopt)
        guard !isAdopt, case .reuseLiveSession = decision else {
            presentActivationSheet(controller, isAdopt: isAdopt)
            return
        }
        Task {
            guard await controller.preflightMigrationIdentity() else { return }
            presentActivationSheet(controller, isAdopt: isAdopt)
        }
    }

    /// Abre la hoja con lo que enseña. Re-mide la entrada (kill-switch, App Attest): con sesión viva el preflight tarda, y
    /// el kill pudo bajar entretanto; sin esto la persona leería y aceptaría para acabar en el error genérico.
    private func presentActivationSheet(_ controller: CloudMigrationController, isAdopt: Bool) {
        guard !abortIfCloudEntryClosed() else { return }
        activationRequest = CloudActivationRequest(
            path: isAdopt ? .adopt : .migration,
            preview: isAdopt ? nil : controller.dryRunCounts())
    }

    /// **El único sitio que arranca la migración o el adopt desde esta pantalla.** Si la persona eligió «Activar la nube
    /// sin borrar», aquí se apunta la renuncia durable (`waivePendingICloudCorpusWipeForTheCloud`). **No se retira el
    /// borrado**: entre aquí y el cutover la migración puede volver a iCloud por media docena de salidas, y retirarlo
    /// aquí lo perdía en silencio en todas (review adversarial del 2026-10-04). Lo retira el arranque en la nube, sin
    /// contarlo; si el intento acaba sin nube, la renuncia caduca y se vuelve a preguntar.
    private func startActivation(_ path: CloudMigrationController.ConsentPath,
                                 _ plan: CloudMigrationController.SignInPlan) {
        if pendingICloudWipeWaived {
            pendingICloudWipeWaived = false
            StorageModePersistence.waivePendingICloudCorpusWipeForTheCloud()
        }
        Task { await controller?.startMigration(consentPath: path, signIn: plan) }
    }

    // MARK: - Revert card

    @ViewBuilder
    private func revertCard(_ controller: CloudMigrationController) -> some View {
        let eligibility = controller.reverseEligibility()
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Storage.Revert.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Text(L10n.Storage.Revert.body)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            // La última vuelta no llegó a iCloud —la espera no drenó, o el servidor no la dejó empezar—: se dice por qué
            // ANTES del botón, para que volver a intentarlo sea una decisión informada. Sale del journal, así que sigue
            // aquí tras el relanzamiento.
            if let reason = ReverseUploadWaitingCopyLogic.abortNote(controller.reverseAbortReason) {
                // Naranja solo el icono: como TEXTO, `warningForeground` sobre la tarjeta blanca no llega a AA.
                Label {
                    Text(L10n.Storage.ReverseAbort.note(for: reason))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Semantic.warningForeground)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("storage_revert_last_attempt_note")
            }
            // §3.3.5: la Reversa ES el desenlace funcional del enlace privado ↔ nube.
            Text(L10n.Storage.Revert.desenlaceNote)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            if eligibility == .eligible {
                Button {
                    Task { await beginRevert() }
                } label: {
                    Group {
                        if controller.isCheckingICloudBeforeReverse {
                            HStack(spacing: DS.Spacing.sm) {
                                ProgressView()
                                Text(L10n.Storage.Revert.Prior.checking)
                            }
                        } else if let deleted = controller.priorICloudWipeDeleted {
                            // «Empezar sin ellos» borrando: con un iCloud grande tarda minutos, y sin cifra parecía
                            // colgado (QA guiado del 2026-10-19).
                            HStack(spacing: DS.Spacing.sm) {
                                ProgressView()
                                Text(L10n.Storage.Revert.Prior.wiping(deleted))
                                    .monospacedDigit()
                            }
                        } else {
                            Text(L10n.Storage.Revert.button)
                        }
                    }
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Semantic.warningForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(DS.Semantic.warningForeground)
                .disabled(controller.isWorking || controller.isCheckingICloudBeforeReverse)
                .accessibilityIdentifier("storage_revert_button")
            } else {
                // `.degradedNoMap` no se cura esperando: la cuenta llegó a la nube desde otro dispositivo. El resto
                // (mapa ilegible, sobre todo) sí puede cambiar, y conserva el «ahora mismo».
                Text(eligibility == .degradedNoMap
                     ? L10n.Storage.Revert.ineligibleOtherDevice
                     : L10n.Storage.Revert.ineligible)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier(eligibility == .degradedNoMap
                                             ? "storage_revert_ineligible_other_device"
                                             : "storage_revert_ineligible")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
    }

    // MARK: - Volver a iCloud: pregunta previa

    /// El toque de «Volver a iCloud»: antes de las confirmaciones, pregunta a iCloud qué sumaría la vuelta (ticket
    /// `reverse-to-icloud-merges-prior-icloud-data-without-asking`). Nada ajeno → las confirmaciones de siempre; algo
    /// ajeno → el aviso con la elección; sin respuesta → no empieza.
    private func beginRevert() async {
        guard let controller else { return }
        revertMergesPriorData = false
        // Un flag que se quedó en `true` porque UIKit no llegó a presentar su diálogo dejaría el botón sin respuesta: cada
        // toque lo volvería a poner en `true`, que no cambia nada. Cada toque empieza con los tres abajo.
        confirmRevert = false
        showRevertPriorData = false
        showRevertCheckFailed = false
        switch await controller.checkICloudBeforeReverse() {
        case nil:
            return
        case .proceed:
            confirmRevert = true
        case .ask(let corpus):
            revertPriorData = corpus
            showRevertPriorData = true
        case .cannotCheck:
            revertNeedsICloud = false
            showRevertCheckFailed = true
        case .needsICloud:
            revertNeedsICloud = true
            showRevertCheckFailed = true
        }
    }

    /// «Reintentar» de la alerta. **Espera a que la alerta se cierre** antes de volver a preguntar: una respuesta rápida
    /// (sin red, sin iCloud) volvería a presentar desde el mismo anchor mientras la alerta aún se desmonta, y UIKit puede
    /// descartar esa segunda presentación.
    private func retryRevertCheck() {
        Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch {
                return  // Cancelada: la pantalla se fue y no hay nada que reintentar.
            }
            await beginRevert()
        }
    }

    /// «Sumarlos a mis datos» lleva a la confirmación de siempre, que es la que empieza la vuelta. Elegir qué hacer con lo
    /// ajeno no es confirmar la vuelta: por eso sigue habiendo una (L20-17 fundió las dos de antes, no esta).
    private func chooseMergingPriorData() {
        revertMergesPriorData = true
        confirmRevert = true
    }

    /// El «Sí, volver a iCloud» de la confirmación: la vuelta de siempre, o la que suma lo ajeno si la persona lo eligió.
    private func startConfirmedReverse() {
        let merging = revertMergesPriorData
        revertMergesPriorData = false
        Task {
            if merging {
                await controller?.startReverseMergingICloudPriorData()
            } else {
                await controller?.startReverse()
            }
        }
    }

    // MARK: - Sync status (banner S11)

    @ViewBuilder
    private func syncStatusSection(_ controller: CloudMigrationController) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Storage.Sync.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            // **La rama del attest va PRIMERA, y sin ella esta sección mentía** (2026-09-15, ticket
            // `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`). `refreshSyncBanner` solo pone
            // `syncNeedsSignIn` con el runtime en `.stoppedUntilSignIn`; el veredicto terminal del attest lo deja en
            // `.stoppedUntilRelaunch` (`CloudSyncRuntime.RuntimeState`), que caía al `else` de abajo — o sea, un
            // check verde «Todo al día» con el motor parado y los movimientos sin subir. Es el `else` fallando
            // ABIERTO: da por bueno todo estado que nadie enumeró.
            //
            // Y va ANTES de `syncNeedsSignIn` porque re-firmar no arregla un attest roto: ofrecer ahí el botón de
            // sign-in mandaría a la persona a un gesto que no cambia nada.
            //
            // **Y el check verde ya no es el `else`** (ticket `cloud-sync-status-says-all-synced-with-changes-still-pending`,
            // decisión de Jürgen del 2026-10-07): sin red, con el motor en backoff o `.idle`, los cambios sin subir caían
            // ahí y la pantalla decía «Todo sincronizado». El orden de las cuatro ramas vive en `SyncStatusSectionLogic`.
            switch SyncStatusSectionLogic.decide(
                attestNoticeShowing: CloudAttestNotice.isShowing(verdictIsTerminal: attestVerdictIsTerminal),
                needsSignIn: controller.syncNeedsSignIn, signInPendingCount: controller.pendingUploadCount,
                isCloud: CloudSyncFlags.storageMode == .cloud, pendingCount: controller.pendingSyncCount,
                engineIsHealthy: controller.syncEngineIsHealthy) {
            case .attestUnavailable:
                CloudAttestNoticeBanner(accessibilityID: "storage_sync_attest_banner")
            case .needsSignIn(let pending):
                // Sin cifra si la cola no se dejó contar: el motor sigue parado y firmar sigue siendo la salida (ticket
                // `an-unreadable-migration-journal-reads-as-never-started`). Naranja solo el icono, como la nota de la
                // vuelta de esta misma pantalla: como TEXTO, `warningForeground` sobre la tarjeta blanca no llega a AA.
                Label {
                    if let pending {
                        Text(L10n.Storage.Sync.needsSignIn(pending))
                    } else {
                        Text(L10n.Storage.Sync.needsSignInUncounted)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.Semantic.warningForeground)
                }
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(pending == nil
                                         ? "storage_sync_needs_signin_uncounted" : "storage_sync_needs_signin_count")
                YalaPrimaryButton(L10n.Storage.Sync.signInButton, icon: "person.crop.circle.badge.checkmark",
                                  isDisabled: controller.isWorking) {
                    Task { await controller.signInToResumeSync() }
                }
                .accessibilityIdentifier("storage_sync_signin_button")
            case .waitingForConnection(let pending):
                // Gris y sin botón: es pasajero y no hay nada que pulsar —sube solo con el siguiente ciclo sano—, así que
                // ni el verde del check ni el naranja de la puerta de firmar.
                Label {
                    if let pending {
                        Text(L10n.Storage.Sync.waitingForConnection(pending))
                    } else {
                        Text(L10n.Storage.Sync.waitingForConnectionUncounted)
                    }
                } icon: {
                    Image(systemName: "icloud.and.arrow.up")
                }
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(pending == nil
                                         ? "storage_sync_waiting_uncounted" : "storage_sync_waiting_count")
            case .upToDate:
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Semantic.successForeground)
                    Text(L10n.Storage.Sync.upToDate)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("storage_sync_up_to_date")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
        // **El recuento se entera cuando algo guarda, sin otro sondeo**: apuntar un gasto, el drain que lo pasa al outbox y
        // la subida que lo borra guardan, y cada guardado avisa con `ModelContext.didSave`. El sondeo de 1 s de arriba solo
        // relee el estado del motor (`refresh()`), que no hace fetch. La tarea vive lo que vive la sección: solo en la nube.
        .task {
            controller.refreshPendingSyncCount()
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                controller.refreshPendingSyncCount()
            }
        }
    }

    // MARK: - Progress card (transitional)

    private func progressCard(_ controller: CloudMigrationController, step: MigrationUIStep, reverse: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Opción B del lienzo (decisión de Jürgen del 2026-10-22, ticket `cloud-progress-shows-real-steps-and-counts`):
            // pasos con su cifra en vez de una barra por fases que se quedaba quieta minutos. Lo que espera a iCloud —el
            // import o la revisión de la vuelta— lo dice el propio paso, con su explicación; lo que queda aquí debajo son
            // los avisos que la persona puede desatascar.
            CloudProgressStepsView(
                title: reverse ? L10n.Storage.Steps.reverseTitle : L10n.Storage.Steps.forwardTitle,
                steps: reverse ? controller.reverseProgressSteps : controller.forwardProgressSteps)
            // **La sesión caducada va PRIMERA, y lo decidió una medición, no el orden natural.** De las dos cosas ciertas a
            // la vez, manda la que la persona puede desatascar.
            if controller.reverseNeedsSignIn {
                // La vuelta a iCloud se paró porque la sesión de la nube ya no vale, antes de montar el espejo: la
                // barra parada al 15/30/50/62 % del ticket `reverse-before-mount-stays-stuck-with-an-expired-session`.
                // Esperar no la renueva, así que aquí no basta con decirlo: el botón de abajo lo OFRECE.
                //
                // Sin término `reverse`: la fase la decide el runner, que solo observa esto en las cuatro fases de la
                // vuelta. Repetir aquí esa condición dejaría verde a un mutante en la del runner.
                Text(L10n.Storage.Progress.reverseNeedsSignIn)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("storage_reverse_needs_signin_caption")
            } else if let notice = controller.adoptClaimNotice {
                // El claim de un adopt aparcado por un motivo que esperar no arregla (ticket
                // `adopt-claim-stays-parked-with-no-ceiling`): se dice YA, como hace el Welcome, y no a los 15 min del
                // techo.
                Text(adoptClaimNoticeText(notice))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("storage_adopt_claim_notice")
            } else if reverse && controller.isWaitingReverseUpload {
                // La vuelta espera a que el espejo suba los datos y algo lo frena (iCloud lleno, sin iCloud, avería
                // local): el porqué, que la cifra sola no dice. «Subiendo» ya lo dice el paso, así que no se repite.
                reverseUploadCaption(controller)
            }
            Text(reverse ? L10n.Storage.Steps.keepUsing : L10n.Storage.Steps.keepOpen)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("storage_steps_footer")
            if controller.reverseNeedsSignIn {
                // Lo único que desatasca, con peso de botón primario.
                YalaPrimaryButton(L10n.Storage.Sync.signInButton, icon: "person.crop.circle.badge.checkmark",
                                  isDisabled: controller.isWorking) {
                    Task { await controller.signInToResumeReverse() }
                }
                .accessibilityIdentifier("storage_reverse_signin_button")
            }
            // Sin «Retomar»: el lienzo B no lo lleva y la pantalla re-empuja sola (cada 5 s en las esperas de iCloud, cada
            // 30 s en el resto, `CloudProgressStepsLogic.screenRekickSeconds`).
            if reverse && controller.canCancelReverse {
                cancelReverseButton(controller)
                    .frame(maxWidth: .infinity)
            }
            // Sin término `reverse`: la fase la decide el controller (`ForwardCancelScope`), y sus cuatro fases solo se
            // pintan en la ida. Repetirlo aquí sería la misma condición dos veces, y un mutante en la del controller
            // saldría verde.
            if controller.canCancelMigration {
                cancelMigrationButton(controller)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
        // `.contain`: sin él, el id de la tarjeta pisa el de cada paso y el de sus botones (`testing.md`, regla del
        // identificador en un contenedor).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storage_progress_card")
    }

    /// La tarjeta de pasos de la vuelta mientras el journal aún dice «nube activa»: se borra lo de antes de iCloud
    /// («Borrar y volver a iCloud») o la vuelta recién confirmada espera su primer guardado (card 27z3: hasta este ticket la
    /// pantalla se quedaba con «Volver a iCloud» apagado y nada más durante minutos). Sin botones: aquí todavía no hay nada
    /// que cancelar, y el borrado no tiene vuelta.
    private func reverseStartingCard(_ controller: CloudMigrationController) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CloudProgressStepsView(title: L10n.Storage.Steps.reverseTitle, steps: controller.reverseProgressSteps)
            Text(L10n.Storage.Steps.keepUsing)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("storage_steps_footer")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
        // `.contain`: sin él, el id de la tarjeta pisa el de cada paso y el de sus botones (`testing.md`, regla del
        // identificador en un contenedor).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storage_progress_card")
    }

    /// El aviso del claim de un adopt aparcado (`AdoptClaimScope.notice`).
    private func adoptClaimNoticeText(_ notice: AdoptClaimNotice) -> String {
        switch notice {
        case .sessionExpired:     return L10n.Storage.Progress.adoptSessionExpired
        case .accountUnavailable: return L10n.Storage.Progress.adoptAccountUnavailable(AppConstants.supportEmail)
        }
    }

    /// El texto de la espera de la vuelta a iCloud (`ReverseUploadWaitingCopyLogic`): el mensaje y, si ya se observó,
    /// cuántas filas faltan. En `.secondary` como el resto de captions de la tarjeta: `warningForeground` como TEXTO
    /// sobre la tarjeta blanca da 2,2:1 (`.claude/rules/swiftui-ds.md`).
    @ViewBuilder
    private func reverseUploadCaption(_ controller: CloudMigrationController) -> some View {
        // Desde la opción B (ticket `cloud-progress-shows-real-steps-and-counts`) «subiendo» y la cifra los dice el paso
        // «Subir a iCloud»; aquí solo queda el porqué cuando algo frena la subida.
        let copy = ReverseUploadWaitingCopyLogic.waitingCopy(sample: controller.reverseUploadSample)
        if copy.message != .uploading {
            Text(reverseUploadMessage(copy.message))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("storage_reverse_waiting_message")
        }
    }

    private func reverseUploadMessage(_ message: ReverseUploadWaitingCopyLogic.Message) -> String {
        switch message {
        case .uploading:
            return L10n.Storage.Progress.reverseUploading
        case .icloudFull:
            return L10n.Storage.Progress.reverseICloudFull
        case .icloudUnavailable:
            return L10n.Storage.Progress.reverseICloudUnavailable
        case .icloudMaybeOff:
            return L10n.Storage.Progress.reverseICloudMaybeOff
        case .localFailure:
            return L10n.Storage.Progress.reverseLocalFailure
        }
    }

    /// «Cancelar y seguir en la nube»: la salida de la persona, disponible durante toda la espera de la subida
    /// (decisión de Jürgen, 2026-09-16) y también en las cuatro fases previas al montaje del espejo
    /// (`reverse-before-mount-has-no-way-to-abandon-the-return`). Pide confirmación porque cambia dónde viven sus
    /// datos.
    ///
    /// **El cuerpo del diálogo cambia con la fase, y no es cosmética.** El de la espera dice que Yala pedirá cerrarla
    /// y volver a abrirla, porque ahí el espejo ESTÁ montado y hay que re-armar su apagado. Antes del montaje no hay
    /// espejo que apagar, así que esa frase sería falsa: no hay relanzamiento que pedir.
    private func cancelReverseButton(_ controller: CloudMigrationController) -> some View {
        YalaSecondaryButton(L10n.Storage.Progress.cancelReverse, icon: "arrow.uturn.backward",
                            isDisabled: controller.isWorking) {
            confirmCancelReverse = true
        }
        .accessibilityIdentifier("storage_cancel_reverse_button")
        .confirmationDialog(L10n.Storage.Confirm.cancelReverseTitle,
                            isPresented: $confirmCancelReverse, titleVisibility: .visible) {
            Button(L10n.Storage.Confirm.cancelReverseConfirm) {
                Task { await controller.cancelReverse() }
            }
            Button(controller.isBeforeReverseMount
                   ? L10n.Storage.Confirm.cancelReverseKeepBeforeMount
                   : L10n.Storage.Confirm.cancelReverseKeep) {}
        } message: {
            Text(controller.isBeforeReverseMount
                 ? L10n.Storage.Confirm.cancelReverseBeforeMountBody
                 : L10n.Storage.Confirm.cancelReverseBody)
        }
    }

    /// «Cancelar la activación» durante la subida del snapshot (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`) y,
    /// desde `forward-migration-steps-have-no-ceiling-and-no-exit`, en los tres pasos parados al 22 %, 35 % y 80 %
    /// (decisiones de Jürgen del 2026-09-22). Pide confirmación porque abandona algo que la persona empezó, y el cuerpo dice
    /// lo que se queda: sus datos siguen en el teléfono, y lo que ya subió se queda en su cuenta de la nube —al 22 % y al
    /// 35 % no subió nada todavía, y la frase sigue siendo verdad—. Deshabilitado con trabajo en vuelo, así que solo se
    /// toca con la activación aparcada.
    private func cancelMigrationButton(_ controller: CloudMigrationController) -> some View {
        YalaSecondaryButton(L10n.Storage.Progress.cancelMigration, icon: "xmark.circle",
                            isDisabled: !MigrationImportWaitLogic.cancelEnabled(
                                isWorking: controller.isWorking, waitingForImport: controller.resumeWaitingForImport,
                                cancelling: controller.isCancellingMigration)) {
            confirmCancelMigration = true
        }
        .accessibilityIdentifier("storage_cancel_migration_button")
        .confirmationDialog(L10n.Storage.Confirm.cancelMigrationTitle,
                            isPresented: $confirmCancelMigration, titleVisibility: .visible) {
            Button(L10n.Storage.Confirm.cancelMigrationConfirm) {
                Task { await controller.cancelMigration() }
            }
            Button(L10n.Storage.Confirm.cancelMigrationKeep) {}
        } message: {
            // El cuerpo por fase —claim del adopt, efecto del adopt, «Migrar»— lo elige `StorageFailureCopyLogic`, que es
            // también quien lo elige en la barra del adopt de la bienvenida.
            Text(StorageFailureCopyLogic.cancelMigrationBody(
                isAdoptClaim: controller.isAdoptClaim, isAdoptEffectPending: controller.isAdoptEffectPending,
                surface: .storage))
        }
    }

    // MARK: - Needs relaunch (assisted relaunch — NEVER exit())

    private func relaunchCard(
        _ controller: CloudMigrationController, _ direction: CloudMigrationUIState.RelaunchDirection
    ) -> some View {
        // Tras una salida de la espera de la vuelta a iCloud el relanzamiento no «termina» nada: devuelve el
        // almacenamiento a la nube. «Ya casi está» sería falso, así que la tarjeta dice dónde siguen los datos y,
        // si no lo pidió la persona, por qué.
        //
        // UX 2.2 · L20-18 (variante 3): lo hecho con check y el gesto en tres pasos, la misma instrucción que el cierre de
        // sesión. Cada check es verdad en su caso (`RelaunchChecklistCopyLogic`): en la ida y el adopt los datos ya están en
        // la cuenta de la nube (el mirror-off se arma tras verificar); en la vuelta ya bajaron a este iPhone y suben a
        // iCloud al reabrir; con la vuelta cancelada, siguen en la nube.
        let reverseAbort = direction == .toCloud ? controller.reverseAbortReason : nil
        let copy = RelaunchChecklistCopyLogic.storage(direction: direction, reverseAborted: reverseAbort != nil)
        return RelaunchChecklist(
            title: copy.title,
            done: copy.done,
            afterNote: copy.afterNote,
            reason: ReverseUploadWaitingCopyLogic.abortNote(reverseAbort).map { reason in L10n.Storage.ReverseAbort.note(for: reason) })
            .padding(.horizontal, DS.Spacing.lg)
            // `.contain`: el id de la tarjeta no pisa los de sus pasos (`relaunch_step_<n>`).
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("storage_relaunch_card")
    }

    // MARK: - Waiting for leader

    /// La espera del seguidor: otro dispositivo está activando la nube para esta cuenta. Desde
    /// `adopt-follower-waits-for-the-leader-with-no-ceiling` (decisiones de Jürgen del 2026-09-23) lleva la salida del 22 %
    /// del adopt con sus propias palabras: el aviso de la sesión borrada o del 403 en cuanto se ven (`adoptClaimNotice`) y
    /// «Dejar de esperar». Hasta ese ticket no tenía botones, y con esos dos motivos esperaba para siempre.
    private func waitingCard(_ controller: CloudMigrationController) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.lg) {
                ProgressView()
                Text(L10n.Storage.waitingForLeader)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if let notice = controller.adoptClaimNotice {
                Text(followerNoticeText(notice))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("storage_adopt_claim_notice")
            }
            if controller.canStopWaitingForLeader {
                stopWaitingButton(controller)
            }
        }
        .storageCardStyle()
        .accessibilityIdentifier("storage_waiting_leader_card")
    }

    /// El aviso en la espera: el de la sesión borrada nombra el botón de esta tarjeta («Deja de esperar»), no el del 22 %.
    private func followerNoticeText(_ notice: AdoptClaimNotice) -> String {
        switch notice {
        case .sessionExpired:     return L10n.Storage.Progress.followerSessionExpired
        case .accountUnavailable: return L10n.Storage.Progress.adoptAccountUnavailable(AppConstants.supportEmail)
        }
    }

    /// «Dejar de esperar»: la salida del adopt (`controller.cancelMigration()`, marca `cancelled`) con palabras que son
    /// verdad para un teléfono que solo espera. El otro dispositivo sigue a lo suyo, y eso lo dice el cuerpo.
    private func stopWaitingButton(_ controller: CloudMigrationController) -> some View {
        YalaSecondaryButton(L10n.Storage.stopWaiting, icon: "xmark.circle", isDisabled: controller.isWorking) {
            confirmStopWaiting = true
        }
        .accessibilityIdentifier("storage_stop_waiting_button")
        .confirmationDialog(L10n.Storage.Confirm.stopWaitingTitle,
                            isPresented: $confirmStopWaiting, titleVisibility: .visible) {
            Button(L10n.Storage.Confirm.stopWaitingConfirm) {
                Task { await controller.cancelMigration() }
            }
            Button(L10n.Storage.Confirm.stopWaitingKeep) {}
        } message: {
            Text(L10n.Storage.Confirm.stopWaitingBody)
        }
    }

    // MARK: - Journal ilegible

    /// El journal de la migración no se dejó leer (ticket `an-unreadable-migration-journal-reads-as-never-started`). No
    /// ofrece ningún botón: migrar, volver, retomar o cancelar se decidirían con una fase que no se leyó. Lo reintenta el
    /// refresco de esta pantalla, cada segundo, y la tarjeta desaparece sola en cuanto la lectura funciona.
    private func journalUnreadableCard() -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            // Naranja solo el icono: como TEXTO, `warningForeground` sobre la tarjeta blanca no llega a AA.
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.Semantic.warningForeground)
            Text(L10n.Storage.journalUnreadableMessage)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("storage_journal_unreadable_card")
    }

    // MARK: - Failed (rollback)

    private func failedCard(_ controller: CloudMigrationController, kind: CloudMigrationUIState.FailureKind) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Semantic.warningForeground)
                Text(failureMessage(controller, kind: kind))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("storage_failed_message")
            }
            YalaPrimaryButton(L10n.Storage.Progress.retry, icon: "arrow.clockwise",
                              isDisabled: controller.isWorking) {
                Task { await controller.resetAfterRollback() }
            }
            .accessibilityIdentifier("storage_retry_button")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
    }

    /// El texto de la tarjeta de fallo: lo decide `StorageFailureCopyLogic`, que antes vivía aquí dentro.
    private func failureMessage(
        _ controller: CloudMigrationController, kind: CloudMigrationUIState.FailureKind
    ) -> String {
        StorageFailureCopyLogic.message(
            kind: kind, snapshotExit: controller.snapshotExitReason,
            forwardStepExit: controller.forwardStepExitReason, adoptClaimExit: controller.adoptClaimExit,
            cutoverBlocker: controller.cutoverBlocker)
    }

    // MARK: - Panel DEBUG (DEV_BUILD only)

    #if DEV_BUILD
    /// Acceso al panel DEBUG del Modo Nube desde la fila Almacenamiento — en `.cloud` la fila iCloud
    /// de Profile está oculta (R12 mínimo de I14) y sin esto el panel queda inalcanzable en device Dev.
    /// Mismo patrón que `cloudAuthPanel` de iCloudSyncSettingsView.
    private var cloudDebugPanel: some View {
        NavigationLink {
            CloudSyncDebugView()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "key.icloud")
                    .foregroundStyle(DS.Semantic.infoForeground)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Modo Nube · Auth")
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Panel DEBUG (solo Yala Dev)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .storageCardStyle()
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - Hoja de activar / chooser

    /// `onDismiss` de la hoja única (L20-11): arranca con la hoja YA abajo. El plan es one-shot: solo el botón de entrar
    /// lo quema. **La sesión se relee aquí** (C-7): pudo aparecer o morir con la hoja arriba. Con sesión viva se sigue
    /// con ella aunque se tocara un proveedor (el belt del chooser de antes); si la persona tocó «seguir con mi cuenta»
    /// y esa sesión ya no está, la hoja vuelve a abrirse para elegir Apple o Google en vez de arrancar con nada.
    ///
    /// **Ya no hay «¿Activar la nube?» ni «¿Seguro?» detrás** (decisión de Jürgen, opción C): la hoja dice lo que pasa y
    /// el botón de entrar es la confirmación. `.bornCloud` no llega aquí: el alta vive entera en el Welcome.
    private func onActivationSheetDismissed() {
        guard let plan = activationPlan else { return }
        activationPlan = nil
        guard !abortIfCloudEntryClosed() else { return }
        // Otra ventana (iPad) pudo arrancar una activación con la hoja arriba: no se arranca otra encima.
        guard let controller, controller.uiState == .idle, !controller.isWorking else { return }
        let path = consentPath
        guard path != .bornCloud else { return }
        switch signInDecision(isAdopt: path == .adopt) {
        case .reuseLiveSession:
            startActivation(path, .reuseLiveSession)
        case .askProvider:
            guard case .authenticateWith = plan else {
                // La sesión que iba a reusarse murió con la hoja arriba: que elija método.
                presentActivationSheet(controller, isAdopt: path == .adopt)
                return
            }
            startActivation(path, plan)
        case .blockedOtherAccount:
            // La tarjeta ya deshabilita el botón y explica por qué; si se llegara aquí por una carrera (la sesión
            // cambió con la hoja arriba), no arrancar nada.
            break
        }
    }

    /// **El término de la entrada —el kill-switch y App Attest—, en UN solo sitio y leído en vivo.** Lo
    /// consultan tres: el render de `migrateCard` y los dos puntos desde los que se arranca la migración.
    ///
    /// `isEngaged` es la misma expresión que pasa `ProfileView` al gate de la fila. Dentro de `case .idle`
    /// su segundo término es falso por construcción; se escribe entero igual, porque los dos guards de
    /// abajo corren FUERA de ese `case` —desde callbacks de sheets, con el estado ya movido— y allí sí
    /// puede ser cierto.
    ///
    /// `isAttestSupported` es la entrada de la puerta del alta del Welcome, con la misma expresión que
    /// `WelcomeNewOptionsGate.live` (lo fija un scan de paridad): el seam de XCUITest y la capacidad del cliente.
    /// Sin App Attest no se ofrece ninguna de las dos caras de la card.
    private var offersCloudMigrationEntry: Bool {
        StorageRowGateLogic.offersCloudMigrationEntry(
            remoteEnabled: CloudRemoteFlags.cloudModeEnabled,
            isEngaged: StorageRowGateLogic.isEngaged(
                persistedMode: StorageModePersistence.read(), uiState: controller?.uiState ?? .idle),
            isAttestSupported: UITestHooks.fakeAttestSupport || AppAttestClient.canObtainSessionToken)
    }

    /// **Gatear el render no es gatear la migración, y entre los dos hay una ventana real.** El flujo de
    /// esta card —la hoja única → `startMigration`— no vuelve a preguntar por el
    /// flag en ningún punto (`CloudMigrationController` no consulta `CloudRemoteFlags`: cero ocurrencias,
    /// medido el 2026-09-11). Así que quien tapeó «Migrar a la nube» un segundo antes de que aterrizara el
    /// snapshot nuevo —lo baja el `.task` de esta misma pantalla— migraba con el kill YA puesto, mientras
    /// la card desaparecía a su espalda. Re-medir aquí cierra esa ventana en el último punto antes de
    /// arrancar: el `onDismiss` de la hoja única y el del chooser, los dos sitios desde los que se arranca.
    ///
    /// Sale con el error genérico y no en silencio: la persona acaba de tocar «Continuar con…», y un botón
    /// que no hace nada es peor que un aviso. No estrena copy — es el mismo texto que ya usa la pantalla
    /// cuando no puede operar.
    ///
    /// El término de App Attest viaja en el mismo guard, pero aquí no abre ninguna ventana: la capacidad no cambia
    /// con la app abierta, así que sin ella la card ya no se pintó.
    private func abortIfCloudEntryClosed() -> Bool {
        guard !offersCloudMigrationEntry else { return false }
        controller?.lastError = L10n.Storage.Errors.generic
        return true
    }

    /// Copy de la nota de cuenta. Con método conocido lo NOMBRA (`ProviderMismatchLogic.displayName`
    /// es el molde: jamás interpolar el rawValue del wire); desconocido → línea genérica.
    private func accountReuseNote(_ provider: CloudSignInProvider?) -> String {
        guard let name = ProviderMismatchLogic.displayName(forProvider: provider?.rawValue) else {
            return L10n.Storage.Migrate.accountReuseNoteGeneric
        }
        return L10n.Storage.Migrate.accountReuseNote(name)
    }

    /// Copy del bloqueo por cuenta ajena (adopt en un segundo device).
    private func accountMismatchNote(_ provider: CloudSignInProvider?) -> String {
        guard let name = ProviderMismatchLogic.displayName(forProvider: provider?.rawValue) else {
            return L10n.Storage.Adopt.otherAccountNoteGeneric
        }
        return L10n.Storage.Adopt.otherAccountNote(name)
    }

    private func isBlockedOtherAccount(_ decision: StorageMigrationSignInLogic.Decision) -> Bool {
        if case .blockedOtherAccount = decision { return true }
        return false
    }

    /// ¿La tarjeta reusaría la cuenta que la comprobación ya rechazó? Solo con sesión viva: sin ella el toque abre la elección
    /// de Apple o Google, que puede llevar a otra cuenta.
    private func isRefused(_ decision: StorageMigrationSignInLogic.Decision,
                           _ refusal: StorageMigrationIdentityGateLogic.Block?) -> Bool {
        guard refusal != nil, case .reuseLiveSession = decision else { return false }
        return true
    }

    /// Decisión viva del paso de auth. Se re-evalúa en cada lectura (la sesión puede aparecer o
    /// morir mientras la pantalla está abierta) — jamás se cachea en `@State`.
    ///
    /// `storedProvider()` lee el Keychain, y esta pantalla re-renderiza ~1×/s por el tick del journal:
    /// sin sesión no se consulta (el caso de TODO device de producción hoy), con sesión es una lectura
    /// por render de una pantalla que se abre puntualmente.
    ///
    /// `isAdopt` habilita la comprobación contra el faro: en un adopt la cuenta esperada la nombra el
    /// device (migró desde otro con el mismo Apple ID), y la sesión viva puede no ser esa.
    private func signInDecision(isAdopt: Bool = false) -> StorageMigrationSignInLogic.Decision {
        let hasSession = CloudAuthService.shared.hasSession
        guard hasSession else { return .askProvider }
        return StorageMigrationSignInLogic.decide(
            hasSession: true,
            storedProvider: CloudAuthService.shared.storedProvider(),
            isAdopt: isAdopt,
            beaconAccountHash: isAdopt ? CloudBeacon().accountHash : nil,
            sessionAccountHash: isAdopt
                ? CloudAuthService.shared.currentUserID.map(CloudBeacon.hash) : nil)
    }

    /// `onDismiss` de la hoja del bloqueo: con «Usar otra cuenta», la elección de Apple/Google, con la hoja YA abajo
    /// (regla 4 de presentaciones: el siguiente paso nunca se presenta con la anterior bajando). No repite consentimiento
    /// ni confirmaciones: los dio este mismo intento (Jürgen, 2026-09-16). El controller ya cerró la sesión rechazada, así
    /// que la elección ofrece Apple y Google. «Entendido» y el swipe no hacen nada más.
    ///
    /// **Solo si sigue sin haber sesión**, y lo cazó la review: el aviso espera en el controller hasta que la persona vuelve
    /// a esta pantalla, y entretanto puede haber entrado con otra cuenta desde Grupos. Con esa sesión viva la elección se
    /// cierra sola y migraba con ella, sin enseñar «Usarás tu cuenta de Yala actual». La tarjeta ya la anuncia: que decida
    /// el siguiente toque.
    private func onMigrationBlockDismissed() {
        guard migrationBlockUseAnotherAccount else { return }
        migrationBlockUseAnotherAccount = false
        guard !abortIfCloudEntryClosed() else { return }
        guard case .askProvider = signInDecision() else { return }
        consentPath = .migration
        showSignInChooser = true
    }

    /// `onDismiss` del chooser: arranca la migración/adopt con el provider elegido, con el sheet YA
    /// abajo (Google resuelve su presenter vía topmost VC — sobre un VC a medio dismissal el sheet
    /// se perdería). Cancel del chooser = `chosenProvider` nil → no-op limpio.
    private func onChooserDismissed() {
        guard !abortIfCloudEntryClosed() else { return }
        let path = consentPath
        if reuseLiveSession {
            reuseLiveSession = false
            chosenProvider = nil          // el belt gana: jamás arrastrar una elección previa
            startActivation(path, .reuseLiveSession)
            return
        }
        guard let provider = chosenProvider else { return }
        chosenProvider = nil
        startActivation(path, .authenticateWith(provider))
    }
}

// MARK: - Confirmación de volver a iCloud (una sola, UX 2.2 · L20-17)
//
// Eran dos —«¿Volver a iCloud?» y «¿Seguro?»— que decían lo mismo. Volver es la salida segura y reversible: basta una
// pregunta que diga lo que pasa y que no se pierde nada. «Migrar» ya no tiene diálogos aquí: su confirmación es el
// botón de entrar de la hoja única (L20-11).
//
// B6 (lote 20, medido en el simulador el 2026-10-17): en iOS 26 estos diálogos salen como globo y NO pintan el botón con
// `role: .cancel`, también colgados de la raíz de la pantalla. El de no hacer nada va SIN rol, el molde del diálogo del
// borrado pendiente de esta misma pantalla. No le devuelvas el rol: la única salida visible volvería a ser tocar fuera.

private struct StorageConfirmations: ViewModifier {
    @Binding var confirmRevert: Bool
    let onRevert: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(L10n.Storage.Confirm.revertTitle,
                                isPresented: $confirmRevert, titleVisibility: .visible) {
                Button(L10n.Storage.Confirm.revert2Confirm, role: .destructive) { onRevert() }
                    .accessibilityIdentifier("storage_revert_confirm")
                Button(L10n.Common.cancel) {}
                    .accessibilityIdentifier("storage_revert_cancel")
            } message: {
                Text(L10n.Storage.Confirm.revertBody)
            }
    }
}

// MARK: - Datos previos en iCloud antes de volver

/// Los avisos de la pregunta previa a «Volver a iCloud». Cuelgan de la RAÍZ, como `StorageConfirmations`: un
/// `.confirmationDialog` colgado del botón no pinta su «Cancelar» en iOS 26, y aquí no hacer nada es una de las salidas.
/// Tres modificadores, el tope que el compilador del CI aguanta por `ViewModifier`.
private struct StorageRevertPriorDataDialogs: ViewModifier {
    let priorData: ICloudForeignCorpus?
    @Binding var showPriorData: Bool
    @Binding var confirmDiscard: Bool
    @Binding var showCheckFailed: Bool
    let needsICloud: Bool
    let onMerge: () -> Void
    let onDiscard: () -> Void
    let onRetryCheck: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(L10n.Storage.Revert.Prior.title,
                                isPresented: $showPriorData, titleVisibility: .visible) {
                Button(L10n.Storage.Revert.Prior.merge) { onMerge() }
                    .accessibilityIdentifier("storage_revert_prior_merge")
                Button(L10n.Storage.Revert.Prior.discard, role: .destructive) { confirmDiscard = true }
                    .accessibilityIdentifier("storage_revert_prior_discard")
                // «Ahora no» visible y sin rol: es una decisión sobre datos, y en este estilo iOS no pinta el `.cancel`
                // (medido en el simulador, como el diálogo del borrado pendiente).
                Button(L10n.Storage.PendingICloudWipe.wait) {}
                    .accessibilityIdentifier("storage_revert_prior_wait")
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(priorData.map { ReverseICloudPriorDataLogic.message($0) } ?? L10n.Storage.Revert.Prior.bodyNoCount)
            }
            .confirmationDialog(L10n.Storage.Revert.Prior.discardConfirmTitle,
                                isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button(L10n.Storage.Revert.Prior.discardConfirm, role: .destructive) { onDiscard() }
                    .accessibilityIdentifier("storage_revert_prior_discard_confirm")
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Storage.Revert.Prior.discardConfirmBody)
            }
            // Título y mensaje cambian con el motivo; los botones van literales (regla del `actions` de un `.alert`).
            .alert(needsICloud ? L10n.Storage.Revert.Prior.noAccountTitle : L10n.Storage.Revert.Prior.checkFailedTitle,
                   isPresented: $showCheckFailed) {
                Button(L10n.Action.retry) { onRetryCheck() }
                    .accessibilityIdentifier("storage_revert_prior_retry")
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(needsICloud ? L10n.Storage.Revert.Prior.noAccountBody : L10n.Storage.Revert.Prior.checkFailedBody)
            }
    }
}

private extension View {
    func storageCardStyle() -> some View {
        self
            .padding(DS.Spacing.lg)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .padding(.horizontal, DS.Spacing.lg)
    }
}

/// Lo que abre la hoja única de activar la nube: la ruta (para la métrica y el adopt) y la cifra de lo que pasaría.
private struct CloudActivationRequest: Identifiable {
    let id = UUID()
    let path: CloudMigrationController.ConsentPath
    let preview: MigrationDryRunPreview?
}
