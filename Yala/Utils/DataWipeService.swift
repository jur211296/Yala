//
//  DataWipeService.swift
//  Yala
//
//  Servicio central para eliminar todos los datos del usuario
//  y resembrar la app a un estado inicial.
//

import Foundation
import SwiftData
import TipKit
import WidgetKit

// Clase de utilidad para operaciones de borrado masivo de datos de usuario.
// Marcada como @MainActor porque ModelContext debe usarse desde el hilo principal.
@MainActor
final class DataWipeService {

    // MARK: - Punto de entrada principal
    // Llama a esta función cuando quieras vaciar los datos del usuario.
    // 1. Elimina datos de todos los modelos relevantes.
    // 2. Resetea todas las preferencias de usuario a valores por defecto.
    // 3. Opcionalmente vuelve a lanzar la semilla inicial (categorías, etc.).
    // Note: reseedInitialData defaults to false - the UI should ask the user
    static func wipeAllUserData(
        in context: ModelContext,
        reseedInitialData: Bool = false,
        broadcastSignal: Bool = true
    ) throws {
        // ============================================================
        // PASO 0: Señalizar wipe a otros dispositivos via iCloud KV
        // ============================================================
        if broadcastSignal {
            PreferenceSyncService.shared.signalWipeInitiated()
        }

        // ============================================================
        // PASO 1: Borrar todos los datos de SwiftData
        // ============================================================
        // Orden de dependencias (de más dependiente a menos):
        // TransactionItem → Budget → FavoritePayment → ScheduledPayment →
        // Tag → ExchangeRate → Account → Subcategory → Category

        // 1.1 Limpiar relaciones many-to-many de TransactionItem y Tag
        let transactionDescriptor = FetchDescriptor<TransactionItem>()
        let allTransactions = try context.fetch(transactionDescriptor)
        for transaction in allTransactions {
            transaction.setTags(from: [])
        }

        let tagDescriptor = FetchDescriptor<Tag>()
        let allTags = try context.fetch(tagDescriptor)
        for tag in allTags {
            tag.transactions = []
            tag.favoritePayments = []
            tag.budgets = []
        }
        try context.save()

        // 1.1b Limpiar relaciones de InboxDraft y eliminar
        let inboxDraftDescriptor = FetchDescriptor<InboxDraft>()
        let allDrafts = try context.fetch(inboxDraftDescriptor)
        for draft in allDrafts {
            draft.setTags(from: [])
            draft.account = nil
            draft.subcategory = nil
            draft.approvedTransaction = nil
        }
        try context.save()
        for draft in allDrafts {
            context.delete(draft)
        }
        try context.save()

        // 1.1c Eliminar MerchantMemory (limpiar relaciones y eliminar)
        let merchantMemoryDescriptor = FetchDescriptor<MerchantMemory>()
        let allMerchantMemories = try context.fetch(merchantMemoryDescriptor)
        for memory in allMerchantMemories {
            memory.subcategory = nil
        }
        try context.save()
        for memory in allMerchantMemories {
            context.delete(memory)
        }
        try context.save()

        // 1.1d Eliminar notificaciones personalizadas y resetear default
        NotificationService.shared.deleteAllNotifications(context: context)

        // 1.2 Eliminar todas las transacciones
        for transaction in allTransactions {
            context.delete(transaction)
        }
        try context.save()

        // 1.3 Limpiar relaciones de Budget y eliminar
        let budgetDescriptor = FetchDescriptor<Budget>()
        let allBudgets = try context.fetch(budgetDescriptor)
        for budget in allBudgets {
            // SSOT: usa el helper único que mantiene M2M + CSV sincronizados.
            budget.setFilters(accounts: [], subcategories: [], tags: [])
        }
        try context.save()
        for budget in allBudgets {
            context.delete(budget)
        }
        try context.save()

        // 1.4 Limpiar relaciones de FavoritePayment y eliminar
        let favoriteDescriptor = FetchDescriptor<FavoritePayment>()
        let allFavorites = try context.fetch(favoriteDescriptor)
        for favorite in allFavorites {
            favorite.setTags(from: [])
        }
        try context.save()
        for favorite in allFavorites {
            context.delete(favorite)
        }
        try context.save()

        // 1.5 Eliminar todos los pagos programados
        let scheduledDescriptor = FetchDescriptor<ScheduledPayment>()
        let allScheduled = try context.fetch(scheduledDescriptor)
        for scheduled in allScheduled {
            context.delete(scheduled)
        }
        try context.save()

        // 1.6 Eliminar todos los tags
        let remainingTags = try context.fetch(tagDescriptor)
        for tag in remainingTags {
            context.delete(tag)
        }
        try context.save()

        // 1.7 Eliminar todos los tipos de cambio
        let exchangeDescriptor = FetchDescriptor<ExchangeRate>()
        let allExchangeRates = try context.fetch(exchangeDescriptor)
        for rate in allExchangeRates {
            context.delete(rate)
        }
        try context.save()

        // 1.8 Limpiar relaciones de Account y eliminar
        let accountDescriptor = FetchDescriptor<Account>()
        let allAccounts = try context.fetch(accountDescriptor)
        for account in allAccounts {
            account.budgets = []
        }
        try context.save()
        for account in allAccounts {
            context.delete(account)
        }
        try context.save()

        // 1.9 Limpiar relaciones de Subcategory y eliminar
        let subcategoryDescriptor = FetchDescriptor<Subcategory>()
        let allSubcategories = try context.fetch(subcategoryDescriptor)
        for subcategory in allSubcategories {
            subcategory.budgets = []
        }
        try context.save()
        for subcategory in allSubcategories {
            context.delete(subcategory)
        }
        try context.save()
        context.processPendingChanges()

        // 1.10 Eliminar todas las categorías
        let categoryDescriptor = FetchDescriptor<Category>()
        let allCategories = try context.fetch(categoryDescriptor)
        for category in allCategories {
            context.delete(category)
        }
        try context.save()
        context.processPendingChanges()

        // 1.11 Eliminar todos los CashFlowPlans (cascade → Lines → Overrides)
        let cashFlowPlanDescriptor = FetchDescriptor<CashFlowPlan>()
        let allCashFlowPlans = try context.fetch(cashFlowPlanDescriptor)
        for plan in allCashFlowPlans {
            context.delete(plan)
        }
        try context.save()
        context.processPendingChanges()

        // ============================================================
        // PASO 1.12: Limpiar archivo de imagen de perfil
        // ============================================================
        ProfileImageStorage.shared.delete()

        // ============================================================
        // PASO 2: Resetear todas las preferencias de usuario (UserDefaults)
        // ============================================================
        resetAllUserPreferences()

        // ============================================================
        // PASO 3: Limpiar cache de widgets + TipKit
        // ============================================================
        WidgetDataCache.clearCache()
        do {
            try Tips.resetDatastore()
        } catch {
            #if DEBUG
            print("DataWipeService: TipKit reset failed: \(error)")
            #endif
        }

        // ============================================================
        // PASO 4: Reseed de datos iniciales si corresponde
        // ============================================================
        if reseedInitialData {
            try reseedInitialAppState(in: context)
        }
    }

    // MARK: - Purga del dominio Grupos en «empiezo de cero» (handover de dispositivo)

    /// Purga la copia LOCAL del dominio Grupos. **NO** es parte de `wipeAllUserData`: ese wipe
    /// («Vaciar datos» de Ajustes, wipe remoto) conserva Grupos POR DISEÑO y su copy lo promete
    /// («Esto no incluye tus grupos»). Esta función es del otro camino, el que declara que aquí
    /// empieza OTRO usuario: «Soy nuevo» del Welcome y «Empezar de cero» de la oferta de restore.
    ///
    /// **El problema que resuelve** (auditoría Modo Nube §4/1, hallazgos `E2-04`/`NEW-E2-01`/
    /// `NEW-E2-03`; reproducido en simulador): el usuario A cierra sesión (`.privateReset`, no borra
    /// nada) y B elige «Soy nuevo» en el MISMO dispositivo con el MISMO Apple ID. `wipeAllUserData`
    /// vacía el corpus personal, pero los grupos de A siguen ahí, `groupsBetaUnlocked` sobrevive
    /// (B entra a Grupos sin el código) y el bridge, que no comprueba identidad, vuelve a
    /// materializar los gastos de A como `TransactionItem`/`InboxDraft` en el Panel, el Inbox, los
    /// presupuestos y los reportes de B.
    ///
    /// **Es borrado LOCAL, jamás remoto.** Los grupos siguen intactos en CloudKit: el store de
    /// grupos monta `cloudKitDatabase: .none` (`SwiftDataConfiguration.groupsConfiguration`) ⇒
    /// SwiftData no puede exportar nada, y el único camino de export es el enqueue EXPLÍCITO
    /// (solo desde acciones de usuario en
    /// `GroupExpenseService`). Por eso el invariante «borrar filas con el mirror montado exporta los
    /// deletes a iCloud» NO aplica aquí — habla del store PERSONAL, que sí lleva mirror.
    /// Corolario CRÍTICO: esta función JAMÁS debe usar `GroupService.leaveGroup` /
    /// `performLocalCleanupAndDelete` como primitiva — esos llaman `leaveShare`, que sacaría al
    /// usuario del grupo de otro owner DE VERDAD.
    ///
    /// **Por qué el reset del estado del motor es obligatorio y no opcional** (`resetSyncState`):
    /// borrar las filas dejando `private.json`/`shared.json` intactos deja los change tokens
    /// diciendo «estás al día» ⇒ CloudKit no reenvía JAMÁS esos records ⇒ el mismo humano que
    /// vuelve pierde sus grupos de forma permanente con los datos vivos en la nube. El precedente
    /// correcto empareja las dos cosas. Que el
    /// corpus se re-descargue es DELIBERADO: quien lo mantiene fuera de la vida personal de B es el
    /// gate de dominio del bridge (`GroupTransactionBridge.isDomainOpenForBridge`), no la ausencia
    /// de filas.
    ///
    /// Residual documentado: los grupos viven en el iCloud del Apple ID, así que un B que teclee el
    /// código beta verá lo que ese Apple ID tenga (semántica de plataforma, como Fotos). Y lo que no
    /// vive en CloudKit no vuelve: `groupPrefs_*` (cuenta de liquidación) y los overrides del bridge.
    ///
    /// - Parameters:
    ///   - context: contexto con los stores personal + grupos montados (el `mainContext` de la app).
    ///   - defaults: dominio de preferencias. Los tests DEBEN inyectar uno aislado: el host de los
    ///     unit tests es la propia app, así que su `UserDefaults.standard` es el del simulador y el
    ///     sello escrito ahí sobrevive a la corrida — cerrando el bridge para las suites de
    ///     comportamiento del bridge (por eso `isDomainOpenForBridge` exceptúa además el runner).
    ///   - iKV: el iCloud key-value store del Apple ID, por donde viaja `onboardingMode`. Inyectable
    ///     para tests (mismo protocolo mínimo que usa `CloudBeacon`, el otro escritor del iKV del
    ///     repo). Ver `clearHandoverOnboardingMode`.
    ///   - resetSyncState: seam del estado del motor + identidad cacheada + espejo del outbox de Grupos
    ///     en el App Group. Default = producción; los tests lo inyectan para no tocar
    ///     el espejo real ni el disco. `@MainActor` en el TIPO del parámetro y no solo en la
    ///     función: los valores por defecto se evalúan en el contexto del CALLER, así que sin la
    ///     anotación el default no puede llamar al singleton.
    static func wipeLocalGroupsDomain(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        iKV: BeaconKeyValueStore = NSUbiquitousKeyValueStore.default,
        resetSyncState: @MainActor () -> Void = {
            // 2.7: sin esto, borrar las filas del outbox (abajo) es COSMÉTICO —
            // `GroupsSyncClient.rehydrateOutboxFromMirror` las re-inserta en el próximo boot desde el
            // App Group. Su filtro por `userID` NO protege en esta frontera: este camino no cierra la
            // sesión Nube, así que la identidad de las entries del humano anterior sigue casando.
            GroupsOutboxMirror()?.purgeAll()
        }
    ) throws {
        // Los 5 `Split*` se vinculan por IDs planos (`groupZoneID`/`expenseID`/`memberID`), NO por
        // `@Relationship` ⇒ sin orden de dependencias que respetar y sin cascadas que disparar.
        for group in try context.fetch(FetchDescriptor<SplitGroup>()) { context.delete(group) }
        for member in try context.fetch(FetchDescriptor<SplitMember>()) { context.delete(member) }
        for expense in try context.fetch(FetchDescriptor<SplitExpense>()) { context.delete(expense) }
        for share in try context.fetch(FetchDescriptor<SplitShare>()) { context.delete(share) }
        for settlement in try context.fetch(FetchDescriptor<SplitSettlement>()) { context.delete(settlement) }

        // `GroupBridgePreference` vive en el `personalSchema` pero `wipeAllUserData` no la nombra
        // (junto con `CloudMigrationMarker`, los 2 modelos personales que no borra). Es el override
        // por-grupo del bridge: dejarla haría que el bridge del usuario nuevo heredara las
        // decisiones «TX real sí/no» del anterior.
        for pref in try context.fetch(FetchDescriptor<GroupBridgePreference>()) { context.delete(pref) }

        // 2.7 · El outbox de GRUPOS muere aquí; el CURSOR sobrevive A PROPÓSITO. Los dos viven en
        // `syncMetaSchema` —el store que `wipeAllUserData` no toca— pero tienen signos OPUESTOS en una
        // frontera de USUARIO:
        //  · las filas del outbox son escrituras PENDIENTES del humano anterior, y el JWT de la sesión
        //    Nube vive en su propio Keychain ⇒ SOBREVIVE al relevo ⇒ se subirían firmadas como suyas.
        //  · el cursor es la BARRERA que impide que el corpus del anterior BAJE al device del nuevo con
        //    ese mismo JWT (el bug de `31dded30`) ⇒ purgarlo aquí la REABRIRÍA.
        // Por eso NO se reusa `CloudSessionSignOut.purgeGroupsSyncState`, que borra AMBOS: su docblock
        // acota su uso al camino solo-grupos «tras el teardown (generación cortada)», y este camino no
        // corta ninguna generación. La otra mitad —el espejo del App Group— va en `resetSyncState`,
        // porque es disco y los tests lo sustituyen.
        for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }

        try context.save()

        removeGroupsDomainPreferenceKeys(from: defaults)
        clearHandoverOnboardingMode(from: defaults, iKV: iKV)
        resetSyncState()

        // SELLO: el borrado de arriba es local, y el reset de los tokens hace que el motor
        // re-descargue el corpus de grupos del Apple ID (deliberado — ver arriba). Quien lo mantiene
        // fuera de la vida personal del usuario nuevo es este sello, que
        // `GroupsDomainAdoptionLogic.isBridgeAllowed` traduce en «el bridge no escribe hasta que
        // ADOPTES Grupos». Va AL FINAL:
        // el barrido de prefs de arriba no lo nombra, pero el orden lo deja explícito ante un
        // futuro añadido a esa lista.
        defaults.set(true, forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart)
    }

    /// Barrido de las preferencias del dominio Grupos. Separado de `wipeLocalGroupsDomain` para
    /// testearse con un `UserDefaults` aislado, igual que `removeUserPreferenceKeys`.
    ///
    /// `groupsBetaUnlocked` se borra AQUÍ y no en `removeUserPreferenceKeys`: allí sigue siendo una
    /// exclusión deliberada (adopción per-device que el wipe de «Vaciar datos» no debe olvidar, con
    /// test que lo pinnea) — un dispositivo recuerda que adoptó Grupos, pero un dispositivo que
    /// declara «aquí empieza un usuario nuevo» no debe heredar la adopción del anterior. Es la
    /// pieza que cierra la puerta: sin ella el sello nace neutralizado y el bridge de B queda
    /// abierto desde el primer arranque, sin que B haya pedido ver Grupos.
    ///
    /// `groups_currentUserRecordName` NO se toca aquí a propósito: la borra `clearCache()` del
    /// `resetSyncState`, que además tira el valor EN MEMORIA del singleton (borrar solo la key
    /// dejaría al proceso vivo operando con la identidad cacheada del usuario anterior).
    static func removeGroupsDomainPreferenceKeys(from defaults: UserDefaults) {
        defaults.removeObject(forKey: AppPreferences.Keys.groupsBetaUnlocked)

        // Toggles personales de visibilidad/bridge y one-shots de Grupos: `removeUserPreferenceKeys`
        // ya los barre en todo wipe, pero este camino también corre sin él en algún futuro caller —
        // repetirlos es idempotente y deja la purga completa por sí sola.
        defaults.removeObject(forKey: AppPreferences.Keys.hasShownGroupsOnboarding)
        defaults.removeObject(forKey: AppPreferences.Keys.hasSeenGroupsNotificationPrompt)

        // C2 · el latch «este device tuvo sesión de Grupos alguna vez», que gobierna si el empty state
        // dice «vuelve a tu cuenta» o «crea una cuenta». Es del humano ANTERIOR: conservarlo le diría al
        // nuevo que tiene grupos esperando en una cuenta que nunca creó. Va nombrado AQUÍ, y su key vive
        // fuera de `cloudSync.*` justamente por esto — ese prefijo está excluido del wipe a propósito
        // (ver `removeUserPreferenceKeys`), así que allí el latch habría sobrevivido al relevo en silencio.
        defaults.removeObject(forKey: GroupsSessionHistoryMarker.key)

        // La intención de puentear gastos remotos que quedó a medias. Es del humano ANTERIOR y apunta a
        // filas que este camino acaba de borrar; conservarla importa porque el reset de tokens re-descarga
        // el corpus del Apple ID con los MISMOS UUID (el `recordName` ES el modelID), así que un intent
        // superviviente podría puentear al store personal del usuario nuevo gastos que no son suyos en
        // cuanto adopte Grupos y el sello deje de cortar.
        defaults.removeObject(forKey: GroupsPendingBridgeIntent.userDefaultsKey)

        // Prefijos: preferencias por-grupo (cuenta de liquidación por moneda) y dedup de
        // notificaciones de grupo. Ambos llevan el zoneID del grupo de la sesión anterior en la
        // key, así que la lista explícita no puede nombrarlos. `GroupNotifications.lastNotified.*`
        // está excluida del wipe normal (barrerla duplicaría una notificación legítima); aquí SÍ se
        // va: no hay ninguna notificación legítima que proteger, el dominio entero se va con ella.
        let prefixes = ["groupPrefs_", "GroupNotifications.lastNotified."]
        for key in defaults.dictionaryRepresentation().keys
        where prefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
        }

        defaults.synchronize()
    }

    /// La OTRA mitad del sello, y la que faltaba: `onboardingMode` no muere con la copia local.
    ///
    /// `GroupsDomainAdoptionLogic.isDomainOpen` es `isUnlocked || isGroupInviteMode`, y ese segundo término sale
    /// de `onboardingMode == .groupInvite` (`SessionState.isGroupInviteMode`) — una preferencia
    /// SINCRONIZADA por iCloud KV per-Apple-ID cuyo merge es never-downgrade por rank
    /// (`PreferenceMergeLogic`, familia `.onboardingModeNeverDowngrade`; `.groupInvite` rank 1 >
    /// `.full` rank 0). Con solo el `removeObject` local de `removeUserPreferenceKeys`, el `.groupInvite`
    /// REMOTO vuelve a ganar en el siguiente merge y `PreferenceSyncService` lo re-impone en
    /// `SessionState` ⇒ **en un dispositivo cuyo humano anterior entró por invitación o por el alta
    /// solo-grupos, el bridge quedaba abierto para el humano NUEVO sin ningún acto deliberado suyo, con
    /// el sello puesto y el gate beta intacto** (escenario `NEW-E2-03`).
    ///
    /// **Se escribe `""` al iKV, JAMÁS `removeObject`**, y es el mecanismo que ya usa
    /// `OnboardingResetHelper` para sus dos keys: el merge abre con
    /// `guard let r = remote.stringValue, !r.isEmpty` ⇒ el vacío es `.skip` ⇒ los demás dispositivos del
    /// Apple ID **conservan su modo** y un usuario legítimo que estrena un segundo device sigue
    /// recibiendo el suyo. Por eso la lista es de UNA sola key: escribir cualquier otra desde aquí
    /// propagaría a la CUENTA (regla de `swiftdata-cloudkit.md` §«Preferencias y fronteras de cuenta»),
    /// mientras que lo único que este camino declara es el relevo de humano en ESTE dispositivo.
    ///
    /// Y la mitad que ningún barrido de `UserDefaults` cubre: el PROCESO VIVO. `SessionState.shared
    /// .onboardingMode` se leyó al arrancar, así que sin reasignarlo la app sigue en `.groupInvite` —
    /// shell reducida y bridge del humano anterior— hasta el próximo lanzamiento.
    static func clearHandoverOnboardingMode(from defaults: UserDefaults, iKV: BeaconKeyValueStore) {
        // La memoria va ANTES del borrado local: el `didSet` de `SessionState.onboardingMode` persiste
        // vía `OnboardingMode.setCurrent`, así que al revés dejaría la key materializada con "full"
        // justo después de haberla quitado. El guard de igualdad ahorra esa escritura cuando no hay
        // nada que resetear.
        if SessionState.shared.onboardingMode != .full {
            SessionState.shared.onboardingMode = .full
        }
        defaults.removeObject(forKey: OnboardingMode.userDefaultsKey)
        iKV.setString("", forKey: OnboardingMode.userDefaultsKey)
        iKV.synchronize()
    }

    // MARK: - Reset del boot-cleanup de cierre de sesión (H4)

    /// Reset a "recién instalada" SIN ModelContext — para el boot-cleanup del sign-out en `.cloud`
    /// (`SwiftDataConfiguration.performSignOutWipeIfArmed`), donde los datos mueren por borrado de
    /// ARCHIVOS del store, no por deletes de filas. Reusa el mismo reset de prefs/caches del wipe
    /// normal (onboarding, seeds, router, checklist, widgets, TipKit, imagen de perfil).
    /// Corre PRE-UI en el arranque: solo toca UserDefaults, archivos y singletons de estado.
    static func resetForSignOutWipe() {
        ProfileImageStorage.shared.delete()
        resetAllUserPreferences()
        WidgetDataCache.clearCache()
        do {
            try Tips.resetDatastore()
        } catch {
            #if DEBUG
            print("DataWipeService: TipKit reset failed: \(error)")
            #endif
        }
    }

    // MARK: - Reset de preferencias de usuario
    private static func resetAllUserPreferences() {
        // --- Routing state ---
        // Clear both the in-memory AppRouter queue AND the persistent
        // DeferredIntentBuffer. Without this, queued / deferred intents
        // survive the wipe and replay against the reseeded data.
        AppRouter.shared.resetAll()

        removeUserPreferenceKeys(from: .standard)

        ProTourManager.shared.reset()                                // Re-show pro tour

        // --- Setup Checklist ---
        SetupChecklistManager.shared.resetAll()

        // --- Espejos App Group (cross-process: widgets/intents) ---
        // Solo keys que llevan datos/preferencias de la CUENTA. `isProUser` NO se toca
        // (sigue a la suscripción del Apple ID de App Store del device; StoreKitManager
        // la re-deriva y re-escribe); `pendingControlAction` tampoco (transient, se
        // drena en cada activación y no lleva datos de cuenta).
        if let appGroup = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) {
            appGroup.removeObject(forKey: AppPreferences.Keys.expensesOnlyMode)   // espejo del didSet de SessionState (widgets)
            appGroup.removeObject(forKey: "firstWeekday")                         // espejo de PreferenceSyncService (widgets)
            appGroup.removeObject(forKey: AppPreferences.Keys.lastUsedAccountID)  // shortcutID de una Account ya borrada
        }
    }

    /// Barrido de las keys de preferencias de usuario en `defaults`. Separado de
    /// `resetAllUserPreferences` para poder testearse con un `UserDefaults` aislado
    /// (el reset completo toca singletons que escriben en `.standard`).
    ///
    /// EXCLUSIONES deliberadas (auditoría 2026-07-14 — NO añadir sin razonar):
    /// - `lastKnownWipeTimestamp` — protege de reaccionar a la señal del propio wipe.
    /// - `groupsBetaUnlocked` — gate beta per-device (documentado en AppPreferences.Keys).
    /// - `isProUser` / `pro.upsell.*` / `pro.trial.*` / `review*` — siguen a la suscripción
    ///   y al pacing de monetización/review del Apple ID de App Store del DEVICE, no a la
    ///   cuenta Yala; resetearlos re-mostraría sheets one-shot al mismo suscriptor.
    /// - `hasMigratedToLiveBalance` / `biometricKeychainCleanedV1` — sentinels de migración
    ///   de datos LEGACY: post-wipe no existen datos legacy que migrar.
    /// - keys `cloudSync.*` / storageMode / arms de wipe — infra del propio sign-out/wipe,
    ///   las gestiona StorageModePersistence en el orden kill-safe del boot. JAMÁS aquí.
    ///   (El sentinel `cloudSync.prefsCutoverDrained.*` lo purga `performSignOutWipeIfArmed`
    ///   tras este reset, #37 — no re-añadirlo aquí.)
    /// - `groupsDomainSealedForFreshStart` — SELLO del handover, no preferencia: lo escribe
    ///   `wipeLocalGroupsDomain` y borrarlo aquí REABRIRÍA el bridge en un dispositivo que declaró
    ///   el relevo, devolviendo los gastos del usuario anterior al Panel del nuevo. Su vida útil la
    ///   termina el propio predicado (`GroupsDomainAdoptionLogic.isBridgeAllowed`) cuando el usuario adopta
    ///   Grupos, no un barrido.
    /// - `groupPrefs_*` y estado de Grupos — el dominio Grupos sobrevive el wipe por diseño
    ///   (store propio, CKSyncEngine); sus prefs se limpian en leaveGroup.
    ///   Incluye `GroupNotifications.lastNotified.*`: barrerla duplicaría una notificación
    ///   de grupo legítima. Por eso el barrido de dedup de notificaciones de abajo enumera
    ///   prefijos concretos y NO usa uno genérico tipo "todo lo que huela a notificación".
    /// - override de idioma (App Group de LanguageManager) — preferencia del DEVICE
    ///   compartida con widgets/extensiones, no de la cuenta.
    static func removeUserPreferenceKeys(from defaults: UserDefaults) {
        // --- Personalización ---
        defaults.removeObject(forKey: "defaultPeriod")          // Default: DetailPeriod.allTime.rawValue
        defaults.removeObject(forKey: "userTheme")              // Default: resolved by ThemeManager (liquidGlass for new users)
        defaults.removeObject(forKey: "translucentVariant")     // Default: TranslucentVariant.indigo.rawValue (0)
        defaults.removeObject(forKey: "colorfulIcons")          // Default: true
        defaults.removeObject(forKey: "firstWeekday")           // Default: 2 (Monday)
        defaults.removeObject(forKey: "showWidgetHints")        // Default: true
        defaults.removeObject(forKey: "defaultCurrencyCode")    // Default: "PEN"
        defaults.removeObject(forKey: AppPreferences.Keys.tabConfigJSON)  // Layout custom de tabs ("tabBarConfiguration")
        defaults.removeObject(forKey: "customPeriodStart")      // Rango del período .custom (SessionState)
        defaults.removeObject(forKey: "customPeriodEnd")

        // --- Visualización ---
        defaults.removeObject(forKey: "showVariations")         // Default: true
        defaults.removeObject(forKey: "decimalPlaces")          // Default: 2
        defaults.removeObject(forKey: "currencyDisplayFormat")  // Default: "symbol"
        defaults.removeObject(forKey: "useRoundedAmounts")      // Legacy pre-decimalPlaces: YalaFormatterStatic cae a esta key si decimalPlaces falta → resucitaría el redondeo de la cuenta anterior
        defaults.removeObject(forKey: AppPreferences.Keys.averageLineMode)  // Default: 1
        defaults.removeObject(forKey: AppPreferences.Keys.sankeyLabelMode)  // Default: .amount

        // --- Perfil de usuario ---
        defaults.removeObject(forKey: "userName")               // Default: "Usuario"
        defaults.removeObject(forKey: "userAlias")              // Default: ""
        defaults.removeObject(forKey: "userProfileImageData")   // Default: nil
        defaults.removeObject(forKey: "userProfileIcon")        // Default: "" (sin emoji)

        // --- Features de entrada ---
        defaults.removeObject(forKey: "voiceInputEnabled")      // Default: false
        defaults.removeObject(forKey: "voiceLanguage")          // Default: VoiceLanguage.system.rawValue
        defaults.removeObject(forKey: "imageInputEnabled")      // Default: false
        defaults.removeObject(forKey: "aiDataConsentAccepted") // Default: false
        defaults.removeObject(forKey: "aiInsightsConsentAccepted") // Default: false
        defaults.removeObject(forKey: "aiInsightsEnabled")         // Default: false
        defaults.removeObject(forKey: "aiInsightsMigratedV1")      // Sentinel de migración one-shot
        defaults.removeObject(forKey: "aiTogglesRemovedV2")        // Sentinel remove-ai-toggles refactor
        defaults.removeObject(forKey: "aiChatConsentAccepted")  // Default: false
        defaults.removeObject(forKey: "chatAssistantEnabled")   // Default: false
        defaults.removeObject(forKey: "chatFABVisible")         // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.cashFlowAIEnabled)  // Default: false
        defaults.removeObject(forKey: AppPreferences.Keys.insightsTone)       // Default: .normal
        defaults.removeObject(forKey: AppPreferences.Keys.insightsFocus)      // Default: .balanced
        defaults.removeObject(forKey: AppPreferences.Keys.autoFocusField)     // Default: .none
        defaults.removeObject(forKey: "financialMindset")          // Default: "cashFlow"
        // PAR de financialMindset: el pre-fill de OnboardingView exige AMBAS keys presentes —
        // dejar esta viva re-activaba la selección "Solo gastos" de la cuenta anterior
        // (hallazgo device 2026-07-14, HALLAZGO 3 del guion SIGNOUT-WELCOME).
        defaults.removeObject(forKey: AppPreferences.Keys.expensesOnlyMode)    // Default: false

        // --- Rate-limit y señales del chat ---
        defaults.removeObject(forKey: "chatQuestionsToday")     // Contador diario del rate-limit
        defaults.removeObject(forKey: "chatLastQuestionDate")
        defaults.removeObject(forKey: "chat_draft_saved_signal") // Señal draft→TX de la sesión anterior

        // --- Orden de listas ---
        defaults.removeObject(forKey: "accountsSortOrderNames") // Default: ""
        defaults.removeObject(forKey: "tagsSortOrderNames")     // Default: ""

        // --- Configuración de widgets ---
        defaults.removeObject(forKey: "panel_widget_configs_v1") // Key real usada por WidgetConfigManager
        defaults.removeObject(forKey: "panelHeroAIMessage_v1")   // Cache 24h del mensaje IA del hero

        // --- Panel 2.0 (orden/ocultos por sección + hero KPIs) ---
        defaults.removeObject(forKey: AppPreferences.Keys.panelTendenciasOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelTendenciasHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelDistribucionOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelDistribucionHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelPlanificacionOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelPlanificacionHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelSectionsHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelSectionsOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.moreSectionOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelAccountsCollapsed)
        defaults.removeObject(forKey: AppPreferences.Keys.panelHeroKPIsOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelHeroKPIsHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelHeroKPIsCustomized)
        // Sentinel (como seedCategoriesExecuted): re-permite el seed fresh de
        // PanelPreferencesMigration para el próximo usuario.
        defaults.removeObject(forKey: AppPreferences.Keys.panelPrefsMigratedV2)

        // --- Estado del servicio de tipos de cambio ---
        defaults.removeObject(forKey: "exchangeRate_lastHistoricalLoad")
        defaults.removeObject(forKey: "exchangeRate_lastTodayUpdate")

        // --- Preferencias de presupuestos ---
        defaults.removeObject(forKey: "budgets.hideInactive")   // Default: false
        defaults.removeObject(forKey: "budgetAlertsEnabled")    // Default: false

        // --- Grupos (toggles personales de visibilidad/bridge) ---
        defaults.removeObject(forKey: AppPreferences.Keys.includeGroupTransactionsInFeed)   // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.includeGroupsInPanelTotal)        // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.includeGroupTransactionsInStats)  // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.bridgeGroupExpensesToPersonalAccounts)  // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.hasShownGroupsOnboarding)
        defaults.removeObject(forKey: AppPreferences.Keys.hasSeenGroupsNotificationPrompt)

        // --- Sync (toggle de usuario en iCloudSyncSettingsView) ---
        defaults.removeObject(forKey: AppPreferences.Keys.subcatDedupRemoteHookDisabled)  // Default: false (hook activo)

        // --- Visibilidad de secciones de Insights ---
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowQuickStats)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowPendingPayments)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowSubscriptions)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowBudgetsAtRisk)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowWeekday)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowNature)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowTexts)

        // --- Onboarding ---
        defaults.removeObject(forKey: "hasCompletedOnboarding") // Default: false (triggers onboarding)
        defaults.removeObject(forKey: "hasShownWelcomeChooser") // A4: tras wipe vuelve a mostrarse el chooser
        defaults.removeObject(forKey: "hasShownYalaAIOnboarding") // Tras wipe vuelve a mostrarse el onboarding del chat
        // Este `removeObject` es SOLO la copia local. La key viaja además por iCloud KV con merge
        // never-downgrade, así que en el camino de RELEVO DE HUMANO («empiezo de cero») hay que
        // emparejarlo con `clearHandoverOnboardingMode` — que es donde va, y no aquí: este barrido corre
        // también en «Vaciar datos» y en el wipe remoto, donde sigue siendo el MISMO usuario y borrarle
        // el modo del iKV se lo quitaría al device que estrene mañana.
        defaults.removeObject(forKey: "onboardingMode")         // Default: .full (normal onboarding)
        defaults.removeObject(forKey: AppPreferences.Keys.usageFocus)  // D1: reset foco de shell a .full — el reset-on-absent de AppPreferences.loadFromDefaults (vía didChangeNotification) revierte el valor EN MEMORIA a .full al remover la key, sin depender del brazo de retención
        defaults.removeObject(forKey: "sessionTimestamps")      // Default: [] (UserSegmentService sessions)
        defaults.removeObject(forKey: "secondaryCurrencies")    // Default: "" (no secondary currencies)
        defaults.removeObject(forKey: "needsPostOnboardingTrial") // One-shot del trial post-onboarding

        // --- Cross-device wipe coordination ---
        // DO NOT clear lastKnownWipeTimestamp — it protects against reacting to our own wipe signal
        defaults.removeObject(forKey: "lastKnownOnboardingTimestamp")  // Allow re-processing remote onboarding

        // --- What's New ---
        defaults.removeObject(forKey: "lastSeenAppVersion")       // Re-show What's New post-wipe

        // --- App Update ---
        defaults.removeObject(forKey: "appUpdate.latestVersion")  // Clear cached App Store version
        defaults.removeObject(forKey: "appUpdate.lastChecked")    // Force re-check after wipe
        defaults.removeObject(forKey: "appUpdate.trackId")        // Clear cached App Store trackId (rehidrata appStoreURL)

        // --- Coach mark tours ---
        defaults.removeObject(forKey: "hasSeenSettingsTour")      // Re-show settings tour
        defaults.removeObject(forKey: "hasSeenCashFlowSetupTour")  // Re-show cash flow setup tour
        defaults.removeObject(forKey: "hasSeenCashFlowTableTour")  // Re-show cash flow table tour
        defaults.removeObject(forKey: "hasSeenChatContextHint")     // Re-show chat context hint
        defaults.removeObject(forKey: AppPreferences.Keys.hasSeenTodayFXCoachMark)
        defaults.removeObject(forKey: AppPreferences.Keys.showSiriTip)
        defaults.removeObject(forKey: "hasSeenNotificationPrimer")  // Primer de notifs (NewTransactionViewModel)

        // --- Contadores/señales derivados de los datos borrados ---
        defaults.removeObject(forKey: "transactionsSavedCount")   // Alimenta primer/review/milestones
        defaults.removeObject(forKey: "pro.milestone.lastShown")  // Derivado de transactionsSavedCount — sin reset, la cuenta siguiente no ve milestones hasta superar el conteo anterior
        defaults.removeObject(forKey: "hasExportedData")          // Señal de segmento (UserSegmentService)
        defaults.removeObject(forKey: "processedInboxDraftSignatures")  // Firmas de drafts ya borrados
        defaults.removeObject(forKey: "lastSplitType")            // Memoria del split del formulario de TX
        defaults.removeObject(forKey: "lastSplitPercentage")

        // Persistencia día calendario del chat + cache diario de sugerencias LLM
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("chat_session_") || key.hasPrefix("chat_suggestions_") {
            defaults.removeObject(forKey: key)
        }

        // --- Estado de deduplicación de notificaciones (keys con UUID + fecha) ---
        // Barrido POR PREFIJO: la lista explícita de arriba no puede nombrarlas, así que
        // sin esto sobreviven al wipe Y al sign-out. La crítica es `creditCardNotif_`
        // ("ya avisé hoy del pago de esta tarjeta"): una entrada de la cuenta anterior
        // SILENCIA el recordatorio de la entrante. Las otras dos llevan UUIDs de entidades
        // ya borradas — inertes, pero se van igual (el device queda "recién instalado").
        // Los prefijos de Grupos (`GroupNotifications.lastNotified.*`, `groupPrefs_*`) NO
        // entran: ese dominio sobrevive el wipe por diseño — ver exclusiones de arriba.
        let notificationDedupPrefixes = [
            ScheduledPaymentNotificationTracker.creditCardKeyPrefix,
            ScheduledPaymentNotificationTracker.keyPrefix,
            BudgetAlertTracker.keyPrefix,
        ]
        for key in defaults.dictionaryRepresentation().keys
        where notificationDedupPrefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
        }

        // --- Contextual Guides ---
        let guideIDs = ["panel", "trends", "categories", "records", "budgets", "scheduled",
                        "accounts", "transaction", "comparative", "cashflow", "insights", "inbox",
                        "budgetEditor", "scheduledEditor"]
        for guideID in guideIDs {
            defaults.removeObject(forKey: "guide.\(guideID).dismissed")
        }

        // --- Seed guards ---
        // Las DOS keys del centinela, no una: `CategorySeedSentinel` lo namespacea por store
        // (personal vs `YalaModel-UITest`) porque `UserDefaults.standard` es el mismo almacén para
        // los dos y una key única dejaba sin categorías al arranque manual. En producción la key
        // uitest no existe nunca y borrarla es un no-op.
        CategorySeedSentinel.allKeys.forEach { defaults.removeObject(forKey: $0) }
        defaults.removeObject(forKey: "notificationsSeeded")    // Allow re-seed after wipe
        defaults.removeObject(forKey: "devSeedDataExecuted")    // DEV — simetría con seedCategoriesExecuted

        // --- AppEntity shortcutID / CSV mirror migration sentinels ---
        // Re-correr migración contra entidades recién sembradas.
        defaults.removeObject(forKey: AppPreferences.Keys.appEntityShortcutIDsMigratedV3)
        defaults.removeObject(forKey: AppPreferences.Keys.appEntityShortcutIDsRegeneratedV3)
        defaults.removeObject(forKey: AppPreferences.Keys.appEntityShortcutIDsBackfillAttemptsV3)
        AppPreferences.Keys.LegacyKeys.v2MigrationSentinels.forEach {
            defaults.removeObject(forKey: $0)
        }

        // --- Legacy (compatibilidad) ---
        defaults.removeObject(forKey: "preferredCurrency")      // Reemplazado por defaultCurrencyCode

        // Forzar sincronización inmediata
        defaults.synchronize()
    }

    // MARK: - Reseed de estado inicial
    // Encapsula aquí la lógica para volver al estado "recien instalada".
    private static func reseedInitialAppState(in context: ModelContext) throws {
        // Semilla inicial de categorías y subcategorías.
        // La función es idempotente: si ya existen categorías, no hace nada.
        // Como acabamos de borrar todo, SIEMPRE sembrará.
        seedCategoriesIfNeeded(in: context)

        // Note: Notifications are NOT seeded here.
        // They are created during onboarding (step 6) based on user selection.
        // For existing users upgrading, YalaApp.swift handles the seed.
    }
}
