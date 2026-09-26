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

#if DEBUG
/// Error del seam `-uitest-fail-wipe`. Vive bajo `#if DEBUG` y no tiene ningún lanzador en
/// producción: su única razón de ser es hacer observable en pantalla la rama de fallo del wipe.
enum WipeSeamError: Error {
    case forcedByUITestHook
}
#endif

// Clase de utilidad para operaciones de borrado masivo de datos de usuario.
// Marcada como @MainActor porque ModelContext debe usarse desde el hilo principal.
@MainActor
final class DataWipeService {

    // MARK: - Punto de entrada principal
    // Llama a esta función cuando quieras vaciar los datos del usuario.
    // 1. Elimina datos de todos los modelos relevantes.
    // 2. Resetea todas las preferencias de usuario a valores por defecto — SALVO con
    //    `resetsPreferences: false`, que las conserva y solo reabre las puertas del seed (ver abajo).
    // 3. Opcionalmente vuelve a lanzar la semilla inicial (categorías, etc.).
    // Note: reseedInitialData defaults to false - the UI should ask the user
    //
    // - Parameter resetsPreferences: `true` (el default, que preserva el comportamiento de los tres
    //   consumidores de siempre) borra además la identidad y las preferencias: las ~114 keys, el router,
    //   el pro tour, la checklist, los espejos del App Group y la foto de perfil. **`false` es el borrado
    //   que solo tira las FILAS**, y existe para «Activar Yala completo → Restaurar → Empezar desde
    //   cero»: ahí resetear las preferencias se llevaría `hasCompletedOnboarding` y mandaría al Welcome a
    //   quien está a mitad de activar (restricción del paso 8), y el nombre y la divisa son el prefill de
    //   esa misma persona (decisión de Jürgen, 2026-09-14).
    //
    //   **El corte, en una frase: lo que describe a la PERSONA se queda; lo que describe a las FILAS que
    //   se acaban de borrar, se va.** Por eso `false` reabre igualmente las puertas del seed
    //   (`reopenSeedGates`), barre los contadores y punteros del corpus (`removeRowDerivedKeys`) y resetea
    //   la checklist y el buffer de intents: no son preferencias, son estado que tiene que casar con la
    //   base. El criterio para clasificar una key: **¿seguiría siendo verdad si no se hubiera borrado
    //   nada?** Si no, se va en los dos borrados.
    static func wipeAllUserData(
        in context: ModelContext,
        reseedInitialData: Bool = false,
        broadcastSignal: Bool = true,
        resetsPreferences: Bool = true
    ) throws {
        #if DEBUG
        // Seam de QA (`-uitest-fail-wipe`): lanza ANTES de tocar nada, así que los datos quedan
        // intactos. Gateado por el fin del bootstrap — ver `UITestHooks.shouldFailWipeNow`.
        if UITestHooks.shouldFailWipeNow { throw WipeSeamError.forcedByUITestHook }
        #endif

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
        // **Va con las preferencias y no con las filas**, aunque viva en un archivo: la foto es IDENTIDAD
        // de quien usa la app, hermana de `userName` / `userAlias` / `userProfileIcon` —las cuatro son la
        // misma sección de `removeUserPreferenceKeys`— y no sincroniza por iCloud, así que no es corpus
        // que vaya a volver a bajar. Dejarla fuera del flag borraba la foto mientras conservaba el nombre.
        if resetsPreferences {
            ProfileImageStorage.shared.delete()
        }

        // ============================================================
        // PASO 2: Resetear todas las preferencias de usuario (UserDefaults)
        // ============================================================
        if resetsPreferences {
            resetAllUserPreferences()
        } else {
            // **Lo que no es preferencia, se limpia igual**: todo esto describe a las filas que acabamos de
            // borrar, no a la persona, y dejarlo puesto es una incoherencia. Los dos barridos son los
            // MISMOS que llama la rama de arriba, desde una sola lista cada uno.
            //
            //  · las puertas del seed, sin las cuales el onboarding siguiente NO siembra categorías
            //    (el motivo largo, en el docblock de `reopenSeedGates`);
            //  · los contadores, las huellas y los punteros del corpus (`removeRowDerivedKeys`);
            //  · la checklist de puesta en marcha, que afirma pasos —«tu primer gasto», «tu primer
            //    presupuesto»— sobre filas que ya no existen;
            //  · la última cuenta usada, un `shortcutID` que ya no resuelve a ninguna `Account` — la misma
            //    key que `resetAllUserPreferences` borra en la rama de arriba, y vive solo en el App Group.
            //
            // **Y DOS cosas que el reset de arriba sí hace y aquí NO, las dos medidas y las dos por el
            // mismo motivo: el dominio de Grupos sobrevive a este borrado.**
            //  · `AppRouter.resetAll()` se lleva además `PendingJoinStore` y los arms de invitación.
            //  · `DeferredIntentBuffer.clear()` parece la mitad inocente de eso, y no lo es: su
            //    `SerializableIntent` tiene un case `.navigateGroupDetail(groupID:)`, o sea que el buffer
            //    puede llevar dentro la navegación a un grupo que sigue vivo. De sus tres cases, el único
            //    que miente tras este borrado es `showInboxAlert` —cifras de borradores que ya no están— y
            //    ese se corrige solo en cuanto la persona abre la bandeja. Perder un deeplink a un grupo
            //    no se corrige solo, y va contra lo que este scope existe para conservar.
            reopenSeedGates(in: .standard)
            removeRowDerivedKeys(from: .standard)
            SetupChecklistManager.shared.resetAll()
            UserDefaults(suiteName: SharedContainerService.appGroupIdentifier)?
                .removeObject(forKey: AppPreferences.Keys.lastUsedAccountID)
        }

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
    /// `NEW-E2-03`; reproducido en simulador): el usuario A cierra sesión (`.privateReset`, el cierre privado anterior al paso 9, que no borraba
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
    ///   - resetSyncState: seam del estado del motor + identidad cacheada + espejo del outbox de Grupos
    ///     en el App Group. Default = producción; los tests lo inyectan para no tocar
    ///     el espejo real ni el disco. `@MainActor` en el TIPO del parámetro y no solo en la
    ///     función: los valores por defecto se evalúan en el contexto del CALLER, así que sin la
    ///     anotación el default no puede llamar al singleton.
    ///   - retireCloudSession: seam del DISPARO del retiro de la sesión en la nube. El ARM se escribe
    ///     en el cuerpo (durable, sobre el `defaults` inyectado); esto solo lo consume en este proceso,
    ///     que es asíncrono y por eso no cabe en el cuerpo. Los tests lo sustituyen para no tocar el
    ///     llavero real.
    ///   - witness: los testigos del canal que el cinturón consulta —en concreto, lo que el espejo del App Group guarda
    ///     fuera del outbox—. Default = producción; los tests lo inyectan porque el espejo real del simulador guarda lo
    ///     que otras suites dejaron.
    ///   - acceptedGroupsLoss: lo que la persona aceptó perder en «Empezar de cero y perderlos», tal como lo devolvió la
    ///     subida (`CloudSessionSignOut.FreshStartGroupsDrain.lossAccepted`). `nil` —el default, y lo de todos los demás
    ///     callers— es el cinturón de siempre: no se borra nada sin subir.
    static func wipeLocalGroupsDomain(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        retireCloudSession: @MainActor () -> Void = {
            // El retiro es asíncrono (hay que parar al SDK antes de tocar el llavero, o su auto-refresh
            // repone la sesión) y esta función no lo es. Mientras el `Task` no termine, quien cubre las
            // puertas es el SELLO que se escribe unas líneas más abajo, síncrono en este mismo gesto.
            Task { await CloudSessionRetirement.retireIfArmed() }
        },
        resetSyncState: @MainActor () -> Void = {
            // 2.7: sin esto, borrar las filas del outbox (abajo) es COSMÉTICO —
            // `GroupsSyncClient.rehydrateOutboxFromMirror` las re-inserta en el próximo boot desde el
            // App Group. **Su filtro por `userID` tampoco basta desde el 2026-09-17**, aunque este
            // camino ya cierre la sesión: el retiro es un `Task` y un kill entre medias deja la sesión
            // viva con la identidad del anterior casando. El borrado del espejo no depende de eso.
            GroupsOutboxMirror()?.purgeAll()
        },
        witness: CloudSessionSignOut.GroupsExitWitness = .live,
        acceptedGroupsLoss: CloudSignOutFlowLogic.FreshStartGroupsLoss? = nil
    ) throws {
        // El seam `-uitest-fail-wipe` NO está aquí: vive en `deleteLocalGroupsRows`, el escritor que
        // esta función llama abajo (2026-09-11). Repetirlo aquí solo adelantaba el throw por delante del
        // cinturón fail-closed, que no escribe nada, así que el estado observable tras el fallo —«todo
        // sigue ahí»— es el mismo. Lo que se gana al tenerlo en el escritor es que lo hereden los otros
        // call-sites, empezando por el desasociar del paso 10, que no pasa por aquí.

        // 2.7 · El outbox de GRUPOS muere aquí; el CURSOR sobrevive A PROPÓSITO. Los dos viven en
        // `syncMetaSchema` —el store que `wipeAllUserData` no toca— pero tienen signos OPUESTOS en una
        // frontera de USUARIO:
        //  · las filas del outbox son escrituras PENDIENTES de la sesión que las firmó. **Desde el
        //    2026-09-26 no se tiran: se SUBEN antes** (`CloudSessionSignOut.drainGroupsBeforeFreshStart`,
        //    en los tres callers). Van firmadas con su JWT a los grupos de su dueño, que es a donde iban,
        //    y quien empieza de cero puede ser esa misma persona. Lo que llega aquí ya está vacío de filas
        //    vivas —lo exige `requireNoUnsentGroupWrites`, abajo— y lo que se borra son las dead-letter.
        //    Hasta ese día se borraban con el razonamiento contrario («se subirían firmadas como suyas»),
        //    que tiraba en silencio los gastos de grupo apuntados sin cobertura.
        //  · el cursor es la BARRERA que impide que el corpus del anterior BAJE al device del nuevo con
        //    ese mismo JWT (el bug de `31dded30`) ⇒ purgarlo aquí la REABRIRÍA.
        //
        // **Y desde el 2026-09-17 este camino SÍ cierra la sesión (ver más abajo), lo que NO cambia el
        // signo del cursor** — es lo que Jürgen pidió medir: el cursor está indexado por `groupID`, así
        // que los grupos de la persona nueva son otros IDs y bajan enteros; si comparten grupo, el
        // re-join ya lo resetea (`cursorResetGroupIDs`, `GroupsSyncClient.applyPulledPage`); y si el
        // retiro falla, el cursor es la ÚNICA barrera que queda. El par coherente sigue siendo el mismo.
        // Por eso NO se reusa `CloudSessionSignOut.purgeGroupsSyncState`, que borra AMBOS: su docblock
        // acota su uso al camino solo-grupos «tras el teardown (generación cortada)», y este camino no
        // corta ninguna generación. La otra mitad —el espejo del App Group— va en `resetSyncState`,
        // porque es disco y los tests lo sustituyen.
        //
        // Va DENTRO de `deleteLocalGroupsRows` (2026-09-11) para seguir siendo UNA sola transacción ahora
        // que el `save()` vive ahí: es esa función la que la firma con el autor del canal, y un save propio
        // aquí volvería a escribir los deletes bajo el autor por defecto — traducibles a tombstones.
        //
        // **Y desde el 2026-09-26 solo borra lo que ya no puede subir** (ticket
        // `fresh-start-wipe-kills-unsent-group-writes-silently`). En la puerta privada quien empieza de cero puede ser la
        // MISMA persona, y esas filas eran sus gastos de grupo sin cobertura: se perdían sin que nada lo dijera. Los tres
        // callers suben primero (`CloudSessionSignOut.drainGroupsBeforeFreshStart`); esto es el cinturón dentro del
        // escritor, para que un cuarto caller no pueda volver a tirarlas. Las dead-letter (`rejectedReason != nil`) sí se
        // van: el servidor ya las rechazó para siempre, y el cierre tampoco las espera.
        //
        // **Y desde el 2026-09-26, con una excepción acotada** (ticket
        // `fresh-start-has-no-way-out-when-group-writes-can-never-upload`): las que la persona aceptó perder en el
        // «¿seguro?» de «Empezar de cero y perderlos», por fila. Ni una más.
        try requireNoUnsentGroupWrites(in: context, witness: witness, accepting: acceptedGroupsLoss)
        try deleteLocalGroupsRows(in: context) {
            for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        }

        // **LA SESIÓN EN LA NUBE SE RETIRA.** Decisión de Jürgen (2026-09-17, ticket
        // `previous-person-cloud-session-survives-fresh-start-and-reinstall`): «Empezar desde cero» es la
        // frontera de otro humano en este teléfono, y el JWT de la persona anterior vive en su propio
        // llavero — que sobrevive incluso a borrar la app. Sin esto, cada puerta que reusa la sesión viva
        // (el Welcome, «Activar Yala completo», la hoja de Grupos, la tarjeta de adopt) le deja a la
        // persona nueva sus finanzas o sus grupos en la cuenta de la anterior.
        //
        // **El ARM va aquí, en el cuerpo, y el DISPARO en el seam.** El arm es durable y síncrono, así
        // que un kill entre este punto y el retiro lo repite el arranque siguiente
        // (`AppBootstrapper`, paso 0.0-quater). El disparo no cabe aquí: retirar la sesión exige parar
        // antes al SDK —su auto-refresh repondría el llavero— y eso es `async`.
        //
        // **Va DESPUÉS de la transacción de borrado, no antes**, para que un wipe que lanza no se lleve
        // por delante la sesión de quien sigue con sus datos intactos: si el borrado falla, el relevo no
        // ocurrió. Y va ANTES del sello por la misma lógica que el sello va al final — el orden de estas
        // tres líneas es el que deja el estado menos dañino ante un kill en cada hueco.
        CloudSessionRetirement.arm(defaults: defaults)
        retireCloudSession()

        removeGroupsDomainPreferenceKeys(from: defaults)
        clearHandoverPrivateSessionMark(from: defaults)
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

    /// Por qué `wipeLocalGroupsDomain` no borró.
    enum GroupsDomainWipeError: Error, Equatable {
        /// Quedan filas VIVAS en el outbox de grupos, o entradas del espejo del App Group sin fila: cambios que aún no
        /// subieron. `Int.max` = no se pudieron contar.
        case unsentGroupWrites(pendingCount: Int)
    }

    /// **El outbox de grupos no tiene nada vivo.** Lanza si lo tiene, o si no se pudo contar (`liveGroupsPendingCount`
    /// devuelve `Int.max` y eso cuenta como «sí»: una fila que no se pudo mirar no se tira). No escribe nada.
    ///
    /// **Y el espejo del App Group tampoco guarda nada sin fila** (ticket `groups-drain-failure-reads-as-nothing-pending`).
    /// Un kill o un `save` fallido del drain deja el cambio solo en el espejo, y `resetSyncState`, unas líneas más abajo
    /// de `wipeLocalGroupsDomain`, lo purga ENTERO: con el recuento del outbox a 0 se iba sin que nada lo contara. Por eso
    /// aquí cuentan las de la sesión y, sin sesión, todas (`CloudSessionSignOut.freshStartGroupsPendingCount`).
    ///
    /// La llama `wipeLocalGroupsDomain` como su primera línea, y los callers de «Empezar de cero» ANTES de
    /// `wipeAllUserData`: sin eso, una fila aparecida tras la subida dejaría borrado lo personal y los grupos enteros.
    ///
    /// **`accepting`: lo que la persona aceptó perder** en «Empezar de cero y perderlos» (ticket
    /// `fresh-start-has-no-way-out-when-group-writes-can-never-upload`). Con él, pasa si lo que queda AHORA está entre lo
    /// aceptado, por fila (`FreshStartGroupsLoss.covers`): un cambio que el aviso no enseñó —apuntado entre la subida y
    /// aquí— lanza igual. Sin él, el cinturón de siempre.
    static func requireNoUnsentGroupWrites(
        in context: ModelContext, witness: CloudSessionSignOut.GroupsExitWitness = .live,
        accepting: CloudSignOutFlowLogic.FreshStartGroupsLoss? = nil
    ) throws {
        if let accepting {
            let now = CloudSessionSignOut.freshStartGroupsLoss(context: context, witness: witness)
            guard accepting.covers(now) else {
                throw GroupsDomainWipeError.unsentGroupWrites(pendingCount: now.count)
            }
            return
        }
        let pending = CloudSessionSignOut.freshStartGroupsPendingCount(context: context, witness: witness)
        guard pending == 0 else { throw GroupsDomainWipeError.unsentGroupWrites(pendingCount: pending) }
    }

    /// Borra las filas locales del dominio Grupos: los 5 `Split*` y el override por-grupo del bridge.
    /// **Solo filas** — ni preferencias, ni sello, ni estado del motor, ni nada del iKV del Apple ID.
    ///
    /// Extraída de `wipeLocalGroupsDomain` para que el desasociar del paso 10
    /// (`CloudSessionSignOut.detachGroupsAccount`) borre exactamente el mismo conjunto sin heredar lo que
    /// es propio del handover: el **sello** `groupsDomainSealedForFreshStart` cerraría el bridge para el
    /// mismo humano que vuelve a asociar, y el barrido de preferencias le quitaría la adopción de Grupos
    /// de este dispositivo. Dos listas de entidades en dos sitios es exactamente como divergen.
    ///
    /// **Los cinco `Split*` son borrado LOCAL, jamás remoto, y lo que lo garantiza es el AUTOR del save.**
    /// Ese store monta `cloudKitDatabase: .none` (no hay espejo que exporte nada), así que su único camino
    /// de salida es el drain del canal, que traduce el SwiftData History a filas de outbox. El drain
    /// descarta por autor antes de traducir (`GroupsSyncClient.performDrain`, `tx.author !=
    /// outboxSaveAuthor`), así que esta transacción va firmada con `GroupsSyncClient.outboxSaveAuthor` y
    /// deja de ser traducible **mire el drain el History desde donde lo mire**.
    ///
    /// **Cortar el canal antes de llamar NO basta, y ésa era la garantía delegada al llamador hasta el
    /// 2026-09-11.** El History sobrevive al proceso: en un arranque POSTERIOR, con el canal ya de vuelta,
    /// un drain que re-barra esa ventana traduciría estos deletes a tombstones y borraría los grupos **para
    /// todos los miembros**. Lo único que lo impedía era un efecto colateral del orden dentro de
    /// `syncCycleOnce` (el drain corre antes del pull, así que las zonas aún no están repobladas), y un
    /// reordenamiento futuro de ese método reabría el agujero sin que nadie lo notara. Ticket
    /// `detach-history-replay-can-tombstone-groups-on-next-launch`.
    ///
    /// Por eso la firma vive AQUÍ dentro y no en los dos llamadores: un tercer camino que borre estas filas
    /// nace firmado sin tener que acordarse. Y por eso la función hace SIEMPRE el `save()` — con el autor
    /// restaurado antes de un save ajeno, la firma no serviría de nada. Lo que el llamador quiera meter en
    /// la MISMA transacción va en `alsoDeleting`.
    ///
    /// **`GroupBridgePreference` NO cumple esa frase, y por eso es opcional.** Vive en el
    /// `personalSchema` (`SwiftDataConfiguration.swift:112`), que sí lleva el espejo de CloudKit: con el
    /// modo `.icloud` su borrado SE EXPORTA al Apple ID. Para el relevo de humano eso es lo que se
    /// quiere —el dispositivo cambia de dueño—; para un desasociar **no**: es una preferencia PERSONAL
    /// sobre cómo puentear, sobrevive a la cuenta de grupos, y borrarla se la quitaría también en el iPad
    /// del mismo Apple ID, donde puede haber una sesión de grupos viva.
    ///
    /// - Parameters:
    ///   - includingBridgePreferences: ver arriba. `true` solo en el relevo de humano.
    ///   - alsoDeleting: lo que el llamador quiere borrar en la MISMA transacción (su outbox, su cursor).
    ///     Corre con el autor del canal ya puesto y antes del único `save()`.
    static func deleteLocalGroupsRows(
        in context: ModelContext, includingBridgePreferences: Bool = true,
        alsoDeleting extra: () throws -> Void = {}
    ) throws {
        #if DEBUG
        // Seam de QA (`-uitest-fail-wipe`), y vive AQUÍ y no en los llamadores por lo mismo que la firma
        // del autor: este es el escritor común de los tres caminos que borran estas filas —«Empiezo de
        // cero» (`wipeLocalGroupsDomain`), el desasociar del paso 10
        // (`CloudSessionSignOut.purgeGroupsDomainForDetach`) y el que nazca mañana— y un seam repetido en
        // cada uno deja fuera justo al que se olvide. Hasta el 2026-09-11 el desasociar era ese olvidado:
        // el flag existía y su rama de fallo no tenía forma de verse en pantalla.
        //
        // Lanza ANTES del primer `delete` y antes de tocar `context.author`, así que no deja ni deletes
        // sucios ni el autor del canal puesto en un contexto que sigue vivo. El estado observable tras el
        // fallo es «todo sigue ahí», que es exactamente el caso que los dos alerts deben cubrir.
        if UITestHooks.shouldFailWipeNow { throw WipeSeamError.forcedByUITestHook }
        #endif

        // El autor se fija ANTES del primer `delete` y se restaura pase lo que pase. Es propiedad del
        // CONTEXTO en el instante del save —un autosave que se colara a mitad también quedaría firmado—,
        // así que el par fijar/restaurar tiene que envolver la transacción entera, no solo el `save()`.
        let previousAuthor = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        defer { context.author = previousAuthor }

        // El `do` abarca desde el PRIMER `delete`, no solo el `save()`: un `fetch` que lance a mitad
        // —`SplitShare` tras haber borrado ya los grupos, por ejemplo— deja los deletes anteriores SUCIOS
        // en el contexto, y el siguiente `save()` de cualquier otro camino los comitea bajo el autor POR
        // DEFECTO. Esa es exactamente la transacción traducible a tombstones que esta función existe para
        // no escribir, así que el rollback tiene que cubrir el cuerpo entero.
        do {
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
            if includingBridgePreferences {
                for pref in try context.fetch(FetchDescriptor<GroupBridgePreference>()) {
                    context.delete(pref)
                }
            }

            try extra()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
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

        // Paso 10 · el espejo local de la cuenta de grupos asociada, y el libro de lo que una
        // desasociación anterior conservó en el Panel. Los dos son del humano ANTERIOR: el primero le
        // enseñaría al nuevo el CORREO del anterior en la fila de Ajustes, y el segundo frenaría el
        // puente de gastos que para el nuevo no existen.
        //
        // **Al iCloud-KV no se escribe NADA en este camino, y no es un olvido.** Lo que se escriba o se
        // borre ahí viaja a TODOS los dispositivos del Apple ID, y este camino solo declara el relevo de
        // humano en ESTE teléfono: borrar le quitaría al dueño su asociación en el iPad. Quien cierra la
        // puerta al humano nuevo es el SELLO que se escribe abajo: `GroupsAccountAssociation` no lee el
        // iCloud-KV con el dominio sellado.
        defaults.removeObject(forKey: GroupsAccountAssociation.localKey)
        defaults.removeObject(forKey: GroupsDetachedBridgeLedger.userDefaultsKey)
        // La marca de un desasociar a medias muere con el humano anterior, y va NOMBRADA aquí porque
        // esta función es una LISTA de keys, no un barrido por prefijo — el `groups.*` del namespace es
        // convención, no mecanismo. Sin esta línea, quien recibe el teléfono ve en «¿Dónde viven tus
        // datos?» un botón para «terminar de soltar» una cuenta que nunca asoció.
        defaults.removeObject(forKey: GroupsDetachPendingPurge.userDefaultsKey)

        // Prefijos: preferencias por-grupo (cuenta de liquidación por moneda) y dedup de
        // notificaciones de grupo. Ambos llevan el zoneID del grupo de la sesión anterior en la
        // key, así que la lista explícita no puede nombrarlos. `GroupNotifications.lastNotified.*`
        // está excluida del wipe normal (barrerla duplicaría una notificación legítima); aquí SÍ se
        // va: no hay ninguna notificación legítima que proteger, el dominio entero se va con ella.
        // `SettlementReminderTracker.keyPrefix` («ya avisé de esta deuda») entra por la MISMA razón
        // que su vecina y NO en `removeUserPreferenceKeys`: es dedup de notificaciones de GRUPOS, y
        // ese dominio sobrevive el wipe personal por diseño. Aquí sí se va — con el dominio entero
        // no queda ninguna deuda de la que avisar, y una entrada superviviente silenciaría durante
        // una semana el primer recordatorio de quien entre después.
        // `GroupBudgetAlertTracker.keyPrefix` («ya avisé de este umbral de este tope») entra por la
        // misma puerta y por la misma razón: sin grupos no queda ningún presupuesto del que avisar, y
        // una entrada superviviente se llevaría por delante el primer aviso de quien entre después —
        // su clave lleva el zone id y el importe, y ambos pueden repetirse tras un wipe.
        let prefixes = [
            "groupPrefs_", "GroupNotifications.lastNotified.",
            SettlementReminderTracker.keyPrefix, GroupBudgetAlertTracker.keyPrefix,
        ]
        for key in defaults.dictionaryRepresentation().keys
        where prefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
        }

        defaults.synchronize()
    }

    /// **El eje 1 muere en el relevo de HUMANO.** «Empiezo de cero» entrega el teléfono a otra persona:
    /// «¿hay vida personal en este dispositivo?» deja de tener la respuesta del anterior, y la marca
    /// vuelve a ausente — que es como nace un teléfono recién instalado.
    ///
    /// **No hay mitad de iCloud-KV que soltar, y ésa es la mejora sobre lo que había aquí.** Hasta el
    /// 2026-09-13 este camino tenía que reparar a mano un flag de onboarding que viajaba por el KV del
    /// Apple ID con merge never-downgrade: borrarlo en local no bastaba —el valor remoto volvía a ganar
    /// en el siguiente merge y `PreferenceSyncService` lo re-imponía—, así que había que escribir `""`
    /// al KV para que el merge lo ignorase sin pisarle el modo a los demás dispositivos de esa persona.
    /// El eje nuevo es un hecho del DISPOSITIVO y nunca viaja, con lo que el relevo se cierra aquí y no
    /// en dos sitios. La lección general está en `.claude/rules/swiftdata-cloudkit.md`.
    /// **Y la mitad que ningún barrido de `UserDefaults` cubre: el PROCESO VIVO.** Este camino corre
    /// in-session —«Empiezo de cero» no relanza— y el espejo observable del eje se leyó al construir
    /// `SessionState`, con el valor de la persona ANTERIOR. Sin re-sincronizarlo, la persona nueva
    /// arranca su onboarding con la shell del anterior, y —peor— el dominio de Grupos se lee como
    /// adoptado, neutralizando el sello que este mismo camino acaba de escribir.
    ///
    /// Se refresca en vez de asignar: asignar volvería a PERSISTIR la marca que se acaba de borrar, y la
    /// ausencia es justo lo que el teléfono necesita para quedar como recién instalado.
    @MainActor
    static func clearHandoverPrivateSessionMark(from defaults: UserDefaults) {
        PrivateSessionMark.clear(defaults)
        SessionState.shared.refreshPrivateSessionMirror()
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

        // M1: el dominio de quien PULSA. `ProfileView.swift:961` es un `NavigationLink`
        // incondicional, así que la invitada llega aquí sin un solo guard: con `.standard` clavado,
        // «Vaciar mis datos» le borraba al DUEÑO sus ~114 preferencias.
        removeUserPreferenceKeys(from: UserDefaults.standard)

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

    // MARK: - Las puertas del seed

    /// **Reabre las puertas del seed tras borrar las filas.** No son preferencias: son centinelas cuyo
    /// valor tiene que CASAR con lo que hay en la base, y borrar las filas dejándolos puestos es una
    /// incoherencia, no una decisión de producto. Por eso los llaman los DOS borrados —el que resetea
    /// preferencias y el que las conserva— desde una sola lista.
    ///
    /// **Lo que pasa si esto no corre, medido:** un alta solo-grupos deja `seedCategoriesExecuted == true`
    /// en el 100 % de los casos normales (`GroupsOrganizerOnboarding.completeSetup`,
    /// `GroupInviteOnboardingView.performSilentSetup`), y `seedCategoriesIfNeeded` sale por su flag guard
    /// **antes** de mirar la base. Así que el seed del final del onboarding es un no-op silencioso: la
    /// persona termina sin ninguna categoría, y sin «Ajuste de saldo» el saldo inicial falla sin decir nada.
    ///
    /// Las DOS keys del centinela de categorías, no una: `CategorySeedSentinel` lo namespacea por store
    /// (personal vs `YalaModel-UITest`) porque `UserDefaults.standard` es el mismo almacén para los dos y
    /// una key única dejaba sin categorías al arranque manual. En producción la key uitest no existe nunca
    /// y borrarla es un no-op.
    ///
    /// El par es el mismo que `ShellDataAlertsModifier` ya reabre a mano cuando otro dispositivo del Apple
    /// ID vació los datos.
    static func reopenSeedGates(in defaults: UserDefaults) {
        CategorySeedSentinel.allKeys.forEach { defaults.removeObject(forKey: $0) }
        defaults.removeObject(forKey: "notificationsSeeded")    // Allow re-seed after wipe
    }

    /// **Lo que describe a las FILAS que se acaban de borrar, y por tanto se va en los DOS borrados.**
    ///
    /// Hermano de `reopenSeedGates`, y existe por el mismo motivo: la rama que conserva las preferencias
    /// de la persona no puede conservar además los contadores, las huellas y los punteros de un corpus que
    /// ya no está. Enumerarlos en los dos sitios es como divergen; aquí hay una sola lista.
    ///
    /// El criterio para añadir algo aquí, en una frase: **¿esta key seguiría siendo verdad si el usuario
    /// no hubiera borrado nada?** Si la respuesta es no, va aquí; si describe a la persona (su nombre, su
    /// tema, sus toggles), se queda en `removeUserPreferenceKeys` y sobrevive al borrado sin reset.
    ///
    /// La más crítica del barrido por prefijo es `creditCardNotif_` («ya avisé hoy del pago de esta
    /// tarjeta»): una entrada de la etapa anterior SILENCIA el recordatorio de la entrante. Las otras dos
    /// llevan UUIDs de entidades ya borradas — inertes, pero se van igual. Los prefijos de Grupos
    /// (`GroupNotifications.lastNotified.*`, `groupPrefs_*`) NO entran: ese dominio sobrevive el wipe por
    /// diseño — ver las exclusiones de `removeUserPreferenceKeys`.
    static func removeRowDerivedKeys(from defaults: UserDefaults) {
        defaults.removeObject(forKey: "transactionsSavedCount")   // Alimenta primer/review/milestones
        defaults.removeObject(forKey: "pro.milestone.lastShown")  // Derivado de transactionsSavedCount — sin reset, la cuenta siguiente no ve milestones hasta superar el conteo anterior
        defaults.removeObject(forKey: "hasExportedData")          // Señal de segmento (UserSegmentService)
        defaults.removeObject(forKey: "processedInboxDraftSignatures")  // Firmas de drafts ya borrados
        defaults.removeObject(forKey: "lastSplitType")            // Memoria del split del formulario de TX
        defaults.removeObject(forKey: "lastSplitPercentage")

        // El estado del servicio de tipos de cambio. Sin esto, `preloadHistoricalIfNeeded` se salta el
        // histórico hasta 30 días después —la key la acaba de escribir el arranque que importó el corpus—
        // y `updateTodayIfNeeded` frena igual sobre un store que ya no tiene ni una fila.
        defaults.removeObject(forKey: "exchangeRate_lastHistoricalLoad")
        defaults.removeObject(forKey: "exchangeRate_lastTodayUpdate")
        defaults.removeObject(forKey: "fxRepairQueue.futileSweepFingerprint.v1")

        // Re-correr la migración de shortcutIDs contra entidades recién sembradas.
        defaults.removeObject(forKey: AppPreferences.Keys.appEntityShortcutIDsMigratedV3)
        defaults.removeObject(forKey: AppPreferences.Keys.appEntityShortcutIDsRegeneratedV3)
        defaults.removeObject(forKey: AppPreferences.Keys.appEntityShortcutIDsBackfillAttemptsV3)
        AppPreferences.Keys.LegacyKeys.v2MigrationSentinels.forEach {
            defaults.removeObject(forKey: $0)
        }

        // Persistencia día calendario del chat + cache diario de sugerencias LLM.
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("chat_session_") || key.hasPrefix("chat_suggestions_") {
            defaults.removeObject(forKey: key)
        }

        // Deduplicación de notificaciones: barrido POR PREFIJO, porque las keys llevan UUID + fecha y una
        // lista explícita no puede nombrarlas.
        let notificationDedupPrefixes = [
            ScheduledPaymentNotificationTracker.creditCardKeyPrefix,
            ScheduledPaymentNotificationTracker.keyPrefix,
            BudgetAlertTracker.keyPrefix,
        ]
        for key in defaults.dictionaryRepresentation().keys
        where notificationDedupPrefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
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
        // Las dos keys de última carga y la huella del último barrido estéril del reparador viven ahora en
        // `removeRowDerivedKeys`: describen al CORPUS —una cola que el wipe acaba de vaciar, un histórico
        // que ya no existe— y no a la persona, así que los necesitan los DOS borrados.

        // --- Preferencias de presupuestos ---
        defaults.removeObject(forKey: "budgets.hideInactive")   // Default: false
        defaults.removeObject(forKey: "budgetAlertsEnabled")    // Default: false
        defaults.removeObject(forKey: "groupSettlementRemindersEnabled")    // Default: false

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

        // --- Contadores, señales y punteros derivados de los datos borrados ---
        // **Delegados, no enumerados aquí**, por lo mismo que las puertas del seed: los necesita también el
        // borrado que conserva las preferencias. Ver `removeRowDerivedKeys`.
        removeRowDerivedKeys(from: defaults)

        // --- Contextual Guides ---
        let guideIDs = ["panel", "trends", "categories", "records", "budgets", "scheduled",
                        "accounts", "transaction", "comparative", "cashflow", "insights", "inbox",
                        "budgetEditor", "scheduledEditor"]
        for guideID in guideIDs {
            defaults.removeObject(forKey: "guide.\(guideID).dismissed")
        }

        // --- Seed guards ---
        // **Delegados, no enumerados aquí**: los necesita también el borrado que NO resetea
        // preferencias (`resetsPreferences: false`), y dos listas que «siempre van juntas» divergen
        // en el commit siguiente, en silencio y hacia el lado que deja al usuario sin categorías.
        // Una sola fuente, dos llamadores. Ver `reopenSeedGates`.
        reopenSeedGates(in: defaults)
        defaults.removeObject(forKey: "devSeedDataExecuted")    // DEV — simetría con seedCategoriesExecuted

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
