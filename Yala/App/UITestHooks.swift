//
//  UITestHooks.swift
//  Yala
//
//  Hooks de UI testing controlados por launch arguments (`-uitest*`).
//  En release `isActive` es siempre false y todo es no-op — no afecta producción.
//  El seeding y la activación Pro (APIs `#if DEBUG`) se aplican desde
//  AppBootstrapper dentro de bloques `#if DEBUG`; aquí solo viven los flags
//  (lectura de ProcessInfo) y la señal observable de readiness para los XCUITests.
//

import Foundation
import Observation

@MainActor
@Observable
final class UITestHooks {
    static let shared = UITestHooks()
    private init() {}

    // MARK: - Flags (false en release)

    /// True solo cuando la app se lanza con `-uitest` (y solo en builds DEBUG).
    nonisolated static var isActive: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        return false
        #endif
    }

    /// `-uitest-reset`: wipe de datos locales al arranque (estado limpio / vacío).
    nonisolated static var shouldReset: Bool { hasArg("-uitest-reset") }

    /// `-uitest-pro`: fuerza Pro (devForceProTier) al arranque.
    nonisolated static var forcePro: Bool { hasArg("-uitest-pro") }

    /// `-uitest-skip-onboarding`: marca onboarding/chooser completados.
    nonisolated static var skipOnboarding: Bool { hasArg("-uitest-skip-onboarding") }

    /// `-uitest-onboarding`: presenta el OnboardingView directo (salta Welcome Hero/Chooser),
    /// SIN marcar onboarding completado. Para testear el flujo de onboarding aislado.
    nonisolated static var startAtOnboarding: Bool { hasArg("-uitest-onboarding") }

    /// `-uitest-group-invite`: arranca en modo solo-grupos (`OnboardingMode.groupInvite`),
    /// con onboarding saltado y el tab Grupos seleccionado. Para testear el Perfil reducido.
    nonisolated static var forceGroupInvite: Bool { hasArg("-uitest-group-invite") }

    /// `-uitest-cloud-chooser`: destapa las cards de sign-in cloud (Apple/Google) del
    /// 2º nivel del Welcome bajo uitest — opt-in EXPLÍCITO del XCUITest del chooser
    /// (sesión 2 Google). Sin él, uitest conserva el bypass a restore (byte-idéntico).
    /// Solo NAVEGACIÓN determinista: el test jamás tapea el botón de sign-in real.
    nonisolated static var forceCloudChooser: Bool { hasArg("-uitest-cloud-chooser") }

    /// `-uitest-fake-icloud`: fuerza `iCloudSyncService.isAccountAvailable = true` en el
    /// simulador (que NO tiene cuenta iCloud). Desbloquea los flujos cuyo único obstáculo
    /// es el guard de disponibilidad de cuenta —onboarding "Solo grupos", prompts de
    /// restore de iCloud— que de otro modo bloquean ANTES de poder ejercitarlos en sim.
    /// NO habilita CloudKit real: crear grupo/CKShare/sync bidireccional siguen sin
    /// funcionar en sim (el store uitest es local, `cloudKitDatabase: .none`). El
    /// AppBootstrapper también marca el primer import como asentado para que los gates
    /// de boot no esperen un import de CloudKit que en sim nunca llega. Solo DEBUG.
    nonisolated static var fakeICloudAvailable: Bool { hasArg("-uitest-fake-icloud") }

    /// `-uitest-fake-backend-session`: fuerza el input `hasSession` de la fila «Eliminar mi cuenta»
    /// (ProfileView) a `true`, para QA/XCUITest del diálogo de D5 (aviso de deudas + «Ver mis grupos»)
    /// SIN un sign-in backend real —SIWA/Google no corren en sim—. NO crea una sesión Supabase real
    /// (`CloudAuthService.hasSession` global NO se toca): solo hace visible la fila + el diálogo; tocar
    /// «Continuar → Eliminar» no completa (no hay backend). Combinar con `-uitest-seed grupos` para que
    /// el usuario tenga saldos pendientes → aparece el aviso. Solo DEBUG (inerte en release vía `hasArg`).
    ///
    /// NO CONFUNDIR con `-uitest-fake-cloud-session` (abajo), su vecino tipográfico: aquel fuerza el
    /// predicado GLOBAL de sesión y este solo el input de DOS filas de Perfil. Fusionarlos rompería
    /// `YalaAccountUITests` y `DeleteAccountDialogUITests`, que dependen de que con este arg el path de
    /// cierre siga siendo `.privateReset` y el layout de Perfil no gane la fila solo-grupos.
    nonisolated static var fakeBackendSession: Bool { hasArg("-uitest-fake-backend-session") }

    /// `-uitest-fake-cloud-session`: fuerza el predicado GLOBAL `CloudAuthService.hasSession` a `true`
    /// (el `#if DEBUG` vive en `CloudAuthService.swift`). Existe porque con `groupsBackendEnabled` ON
    /// —lo que ocurre en TODO XCUITest bajo `Yala Dev`, donde el default-ausente de remote-config es ON—
    /// Grupos exige sesión POR DISEÑO: sin ella el tab pinta el empty state de re-entrada
    /// (`GroupsEmptyStateLogic.decide` → `.signInToView`) y «Nuevo grupo» rutea al sign-in
    /// (`GroupCreateRoutingLogic.route` → `.needsSignIn`), así que los XCUI escritos para el canal
    /// CloudKit no llegan ni al empty state estándar ni al formulario.
    ///
    /// NO crea una sesión Supabase real, y eso es deliberado: `currentUserID`, `sessionExpiry`,
    /// `canRenewSession` y `accessToken()` quedan intactos (`nil`/`false`). Es justo lo que mantiene el
    /// tráfico HTTP en CERO —cada cliente del canal tiene un SEGUNDO guard sobre el JWT y lanza antes de
    /// tocar `URLSession`— y lo que deja byte-idéntica la resolución de identidad por `sub`. Fabricar un
    /// JWT mandaría credenciales basura a un backend real. Solo DEBUG (inerte en release vía `hasArg`).
    nonisolated static var fakeCloudSession: Bool { hasArg("-uitest-fake-cloud-session") }

    /// `-uitest-groups-consent`: da por aceptado el consent de Grupos (§C5) sembrando sus dos keys de
    /// `UserDefaults` desde `AppBootstrapper`, SIN pasar por `GroupsConsentState.register()` —ese camino
    /// escribe por `PreferenceSyncService` (iKV en `.icloud`, outbox en `.cloud`) y un XCUITest no debe
    /// encolar preferencias—. Es ORTOGONAL a `-uitest-fake-cloud-session` porque el gate de crear grupo
    /// tiene dos escalones: sin sesión rutea a sign-in, y CON sesión pero sin consent rutea al consent
    /// (`GroupCreateRoutingLogic.route`). Separados, mañana se puede cubrir ese segundo escalón sin tocar
    /// el seam. Solo DEBUG (inerte en release vía `hasArg`).
    nonisolated static var groupsConsentAccepted: Bool { hasArg("-uitest-groups-consent") }

    /// `-uitest-groups-batch-demo`: QA/XCUITest del batch "salir de todos mis grupos" (D10) SIN backend ni
    /// iCloud (imposibles en sim — la ejecución real de leave/transfer es device/TestFlight). Fuerza que la
    /// hoja de Vaciar OFREZCA «También salir de mis grupos» (input `canLeaveAllGroups` de `UserDataResetView`)
    /// y hace que la vista del batch (`GroupBatchLeaveView`) muestre un RESULTADO determinista fabricado
    /// (2 salidos + 1 transferido + 1 «necesita tu decisión») en vez de ejecutar el orquestador real. Solo
    /// verifica el CABLEADO/UI; la lógica del orquestador va por unit tests (kill-sim). Inerte en release
    /// vía `hasArg`; el seed demo del store está bajo `#if DEBUG`.
    nonisolated static var groupsBatchDemo: Bool { hasArg("-uitest-groups-batch-demo") }

    /// `-uitest-groups-batch-running`: variante EN CURSO del seam anterior, para el botón «Detener» (D3).
    /// Siembra el intent con entries `.pending` SIN ejecutar el orquestador real (imposible en sim), de modo
    /// que la vista muestre el progreso con «Detener». El tap SÍ recorre la mecánica real
    /// (`requestStop` → `stopPending` → marcador + resultado honesto): esto no fabrica el resultado, solo el
    /// punto de partida. Inerte en release vía `hasArg`; el seed está bajo `#if DEBUG`.
    nonisolated static var groupsBatchRunning: Bool { hasArg("-uitest-groups-batch-running") }

    /// `-uitest-retention-demo`: QA/XCUITest de la pantalla de retención D1 (§3.3.2). Arma
    /// `groupsRetentionPending` (con deuda) al arrancar para presentar el cover de retención SIN
    /// ejecutar el wipe destructivo real (ni depender del alert de 2ª confirmación localizado).
    /// Inerte en release vía `hasArg`.
    nonisolated static var retentionDemo: Bool { hasArg("-uitest-retention-demo") }

    /// `-uitest-inbox-alert`: tras el seed, encola `.showInboxAlert` con un payload de
    /// muestra para presentar el InboxAlertModal sin depender del sync de CloudKit.
    nonisolated static var showInboxAlert: Bool { hasArg("-uitest-inbox-alert") }

    /// `-uitest-trial-offer`: tras el seed, encola `.presentTrialOffer` para presentar
    /// el ProTrialOfferSheet sin depender de StoreKit ni del post-onboarding real —
    /// las emisiones AUTOMÁTICAS de monetización están suprimidas en uitest, este
    /// hook explícito es el único camino (escenario paywall + alert en cola).
    nonisolated static var showTrialOffer: Bool { hasArg("-uitest-trial-offer") }

    /// `-uitest-force-update`: fuerza el estado "hay update disponible" en AppUpdateService
    /// (sin red) para testear el UpdateAvailableBanner del Panel.
    nonisolated static var forceUpdateBanner: Bool { hasArg("-uitest-force-update") }

    /// `-uitest-force-required`: fuerza la pantalla BLOQUEANTE de forzado (min-version) sin red ni
    /// snapshot, para QA/XCUITest del cover terminal. Inerte en release (hasArg + seam DEBUG).
    nonisolated static var forceUpdateRequired: Bool { hasArg("-uitest-force-required") }

    /// `-uitest-ai-consent`: marca el consentimiento de datos IA aceptado, para poder
    /// abrir entradas IA Pro (voz/imagen) sin el alert de consentimiento. No graba ni
    /// transcribe — solo destraba la navegación a la vista.
    nonisolated static var aiConsent: Bool { hasArg("-uitest-ai-consent") }

    /// `-uitest-invite-onboarding`: presenta el cover de GroupInviteOnboarding directo
    /// (sin CKShare real — no funciona en sim). Combinar con `-uitest-join-phase` para
    /// congelar la fase del GroupJoinIntentTracker y testear cada step determinista.
    nonisolated static var startAtInviteOnboarding: Bool { hasArg("-uitest-invite-onboarding") }

    /// Valor de `-uitest-join-phase <waitingForZone|creatingMember|pendingApproval|active|failed>`:
    /// congela la fase del tracker para los XCUI del onboarding de invitación.
    nonisolated static var joinPhaseOverride: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-join-phase", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Valor de `-uitest-join-soft-timeout <segundos>`: acorta el soft-timeout del
    /// onboarding de invitación (default 20s) para no dormir en los XCUI.
    var joinSoftTimeoutOverride: TimeInterval? {
        #if DEBUG
        guard Self.isActive,
              let raw = Self.parseValue(after: "-uitest-join-soft-timeout", from: ProcessInfo.processInfo.arguments)
        else { return nil }
        return TimeInterval(raw)
        #else
        return nil
        #endif
    }

    /// `-uitest-seed-desync`: siembra un set MÍNIMO y determinista de transacciones
    /// "desincronizadas" (categoría income con monto NEGATIVO y categoría expense con
    /// monto POSITIVO) para el XCUI de clasificación income/expense por CATEGORÍA
    /// (fix `8347a776`/`13f2cbb0`). Excluyente con `-uitest-seed <perfil>`: el test lo
    /// lanza SIN perfil para no contaminar los totales. Ver `DevSeedTransactions.createDesyncFixtures`.
    nonisolated static var seedDesync: Bool { hasArg("-uitest-seed-desync") }

    /// Valor de `-uitest-seed <perfil>` (ej. "realista", "pesado"). Nil si ausente.
    nonisolated static var seedProfile: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseSeedProfile(from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Pure-logic: extrae el valor que sigue a `-uitest-seed`. Nil si ausente, si es el
    /// último token, o si el siguiente token es otro flag (`-...`). Separado para test.
    nonisolated static func parseSeedProfile(from args: [String]) -> String? {
        parseValue(after: "-uitest-seed", from: args)
    }

    /// `-uitest-deeplink <target>`: simula un deeplink externo a un tab al arranque
    /// (panel/statistics/records/planning/budgets/groups/inbox/scheduledPayments/categories).
    /// Ejercita el wiring de routing a tabs ocultos (bug review-deeplinks).
    nonisolated static var deeplinkTarget: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-deeplink", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// `-uitest-deeplink-url <url>`: a diferencia de `-uitest-deeplink <target>` (que
    /// mapea un target BARE a un tab POST-seed vía `uitestDeeplinkDestination`), esta URL
    /// COMPLETA entra PRE-init por `AppBootstrapper.handleIncomingURL(_:)` → el intent se
    /// DIFIERE al DeferredIntentBuffer y se re-emite en el drain (bootstrap paso 20),
    /// ejercitando el defer→drain REAL de un deep link en cold launch (fix `ba8513e5`).
    /// Soporta el token `seeded-first` en el path (`yala://groups/seeded-first`), que el
    /// hook sustituye por el id del primer grupo sembrado (persistido en `seededGroupIDKey`).
    nonisolated static var deeplinkURL: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-deeplink-url", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Key en `UserDefaults.standard` donde `DevSeedGroups.create` publica el
    /// `SplitGroup.id.uuidString` del primer grupo sembrado, para que el hook de
    /// `-uitest-deeplink-url` resuelva el token `seeded-first` a un id real en una
    /// corrida posterior (patrón de 2 launches del XCUI de deep link en cold launch).
    nonisolated static let seededGroupIDKey = "uitest.seededGroupID"

    /// Pure-logic: extrae el valor que sigue a `flag`. Nil si ausente, si es el último
    /// token, o si el siguiente token es otro flag (`-...`). Separado para test.
    nonisolated static func parseValue(after flag: String, from args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        let value = args[i + 1]
        return value.hasPrefix("-") ? nil : value
    }

    nonisolated private static func hasArg(_ flag: String) -> Bool {
        #if DEBUG
        return isActive && ProcessInfo.processInfo.arguments.contains(flag)
        #else
        return false
        #endif
    }

    // MARK: - Readiness (observado por ContentView)

    /// Flip a true cuando bootstrap + seed terminan. Los XCUITests esperan a que
    /// el root exponga `uitest_ready` antes de interactuar (evita sleeps frágiles).
    private(set) var isReady = false

    func markReady() { isReady = true }

    /// accessibilityIdentifier del root: "" en release / sin uitest, "uitest_loading"
    /// mientras arranca, "uitest_ready" cuando todo está listo.
    var rootIdentifier: String {
        guard Self.isActive else { return "" }
        return isReady ? "uitest_ready" : "uitest_loading"
    }
}
