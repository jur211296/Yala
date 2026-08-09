//
//  BornCloudSignUpService.swift
//  Yala
//
//  El PRODUCTOR del claim born-cloud (Modo Nube §k.3 paso 0 + §f.1, incremento A2 de D-A7). Con la sesión
//  Yala YA firmada, reserva la cuenta en el backend y deja el device con el estado mínimo para que el alta
//  nube pueda continuar: faro escrito, acción de claim estampada y el registro contado.
//
//  ─────────────────────────────────────────────────────────────────────────────────────────────────────
//  CABLEADO (A5, 2026-08-09): el aviso DARK de A2 se cumplió y por eso ya no está aquí.
//
//  Su ÚNICO call-site de producción es `WelcomeCloudSignInView.runBornCloudFlow()` (entrada
//  `Entry.bornCloud`, la card «nube» de «Soy nuevo»): consent → sign-in → `signUp()` →
//  `activateBornCloudStorage()` → terminal de relanzamiento. Ese orden lo pinnea un source-scan en
//  `BornCloudSignUpFlowTests`, porque lo que decide es QUIÉN llama y en qué orden y ningún test de
//  comportamiento lo caza.
//  ─────────────────────────────────────────────────────────────────────────────────────────────────────
//
//  Lo que NO hace, y no por olvido:
//   · **No toca la máquina de migración** (`MigrationWorkExecutor`/`MigrationRunner`/`MigrationStateMachine`).
//     El born-cloud NO tiene migración: no hay corpus que subir, no hay líder, no hay cutover. Meterlo
//     dentro de esa máquina es justo el error que A2 existe para no cometer. De ahí también el
//     `migration: false` del claim (ver `signUp()`).
//   · **`signUp()` no escribe `storageMode` ni el par `.cloud` + `mirrorOffArmed`.** Eso lo hace la
//     primitiva SEPARADA `activateBornCloudStorage()` (A3), que el encadenado de A5 invoca DESPUÉS de un
//     `.seeded`. Separadas y no fundidas a propósito: el par es un cambio de estado del DEVICE y sus tres
//     salidas restantes (`routeReturningUser`/`waitForLeader`/mismatch) NO deben tocarlo.
//   · **No presenta UI** y no decide navegación: devuelve un `BornCloudSignUpOutcome` y el llamador (A5)
//     encamina.
//
//  App Attest: `POST /account/claim` pasa por `requireUser` (`gateway/src/sync/account.ts:68`), que NO
//  exige el header `X-Yala-Attest-Session`, y además es un flujo PRE-SESIÓN anterior al `/attest/bind` —
//  cablear attest aquí es justo lo que puede romper el alta (`.claude/rules/gateway-attest.md`). Por eso
//  `CloudAccountClient` se usa con su default; `AttestWiringTests` lo excluye de su barrido por esa misma
//  razón, documentada en su cabecera.
//

import Foundation
import os

// MARK: - Resultado

/// Resultado ESTRUCTURADO del alta born-cloud. Espeja el estilo de `ClaimOutcome`: el servicio NUNCA lanza
/// y NUNCA presenta nada — traduce red + decisión a un caso que el llamador (A5) enruta.
enum BornCloudSignUpOutcome: Equatable {
    /// `created` + rama born-cloud → este device siembra (§k.3). Es la única salida que continúa el alta:
    /// A3 escribe a partir de aquí el par `.cloud` + `mirrorOffArmed` y pide el relanzamiento.
    case seeded
    /// La cuenta ya existía y está estable (2º device del mismo usuario, o un reintento tras un `created`
    /// previo). **NO se siembra**: el llamador encamina al returning-user que ya existe (§k.4).
    case routeReturningUser
    /// Otro device lidera una migración en curso → seguidor: esperar (§g.6). No sembrar, no adoptar.
    case waitForLeader
    /// Variante B de §f.1: el faro dice que este Apple ID ya activó la nube con OTRO proveedor. Hoy
    /// INALCANZABLE desde la rama born-cloud (ver `signUp()`); se conserva porque la tabla que decide es
    /// `AccountClaimDecision` y no este servicio.
    case providerMismatch(knownProvider: String?)
    /// 401 / sin JWT → la sesión no está viva; re-firmar. Nada se creó server-side.
    case sessionExpired(detail: String)
    /// 403 → cuenta no disponible (suspendida). Terminal para este intento.
    case accountUnavailable(detail: String)
    /// Red caída / 5xx / respuesta indescifrable → reintentable. El claim es idempotente por contrato
    /// (§f.1: el re-claim del MISMO device colapsa a `created`), así que reintentar es seguro.
    case transient(detail: String)
}

// MARK: - Breadcrumbs

/// Rastro del alta born-cloud. Mismo `subsystem`/`category` que `CloudSyncBreadcrumb` (para que salga en el
/// mismo filtro de Console.app) y FUERA de `#if DEBUG` a propósito: en producción es la única superficie de
/// observación de este camino. Sin PII — jamás el `sub`, el JWT ni el email.
///
/// Vive aquí y no en `CloudSyncBreadcrumb` porque A2 tiene el alcance cerrado al servicio nuevo; al cablear
/// A5 se puede consolidar si tiene sentido.
enum BornCloudBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    /// Claim resuelto: estado del wire + acción decidida. El pulso normal del camino.
    static func claimResolved(state: String, action: String) {
        logger.notice("BornCloud claimResolved state=\(state, privacy: .public) action=\(action, privacy: .public)")
    }

    /// Claim exitoso con `currentUserID` nil (casi imposible — el claim usó ESA sesión). Sin estampado, el
    /// guard de identidad dejaría el runtime en `.idle` post-relanzamiento (`CloudSyncRuntime.swift:326`):
    /// es el M1 del review del adopt, y este rastro es para diagnosticarlo sin dSYM.
    static func claimStampSkippedNoUserID() {
        logger.notice("BornCloud claimStampSkipped reason=nil-userID — el runtime quedaría .idle post-relaunch")
    }

    /// El consent no está registrado al llegar aquí (`CloudConsentView` lo escribe ANTES). RUIDOSO y NUNCA
    /// aborta: el alta no se bloquea por un fallo de trazabilidad, pero tiene que dejar rastro. `missing`
    /// nombra qué falta (`acceptedAt` / `textVersion` / ambas).
    static func consentMissing(_ missing: String) {
        logger.notice("BornCloud consentMissing \(missing, privacy: .public) — alta continúa, traza GDPR incompleta")
    }

    /// A3: el par `.cloud` + `mirrorOffArmed` quedó escrito y el device espera el relanzamiento. Es la
    /// marca de agua del alta: lo que venga después de esto ya corre en modo nube.
    static func storageActivated() {
        logger.notice("BornCloud storageActivated — par .cloud+mirrorOffArmed escrito; esperando relanzamiento (el proceso NO se mata solo)")
    }

    /// La tabla de `AccountClaimDecision` devolvió una acción que la rama born-cloud no puede producir.
    /// Hoy imposible; si aparece, alguien cambió la tabla sin mirar a este consumidor.
    static func unexpectedAction(_ action: String) {
        logger.notice("BornCloud unexpectedAction \(action, privacy: .public) — la tabla de AccountClaimDecision cambió")
    }
}

// MARK: - Servicio

@MainActor
final class BornCloudSignUpService {

    private let accountClient: CloudAccountClient
    private let session: CloudSyncSessionProviding
    /// Provider de la sesión leído VIVO en el momento del claim, jamás congelado en el `init` (lección I4
    /// sesión 3 del executor de migración: el servicio puede nacer ANTES del sign-in, y un `"apple"`
    /// congelado estamparía `profiles.provider` y el FARO con el método equivocado).
    private let provider: @MainActor () -> String
    private let deviceID: String
    private let beacon: CloudBeacon
    private let claimStore: CloudClaimActionStore
    /// Donde `PreferenceSyncService` espeja las preferencias (producción: `.standard`). Se lee para VERIFICAR
    /// el consent; este servicio no lo escribe. Inyectable (nunca `.standard` directo en tests).
    private let consentDefaults: UserDefaults
    /// Donde vive el par `.cloud` + `mirrorOffArmed` (producción: `.standard`). Separado de
    /// `consentDefaults` porque son dos almacenes distintos conceptualmente y un test debe poder aislar
    /// cada uno; en producción coinciden.
    private let storageDefaults: UserDefaults
    private let now: () -> Date

    /// Los defaults MainActor-aislados se resuelven en el CUERPO (los default args son `nonisolated`) —
    /// mismo motivo y mismo molde que `MigrationWorkExecutor.init`.
    init(
        session: CloudSyncSessionProviding,
        accountClient: CloudAccountClient? = nil,
        provider: (@MainActor () -> String)? = nil,
        deviceID: String? = nil,
        beacon: CloudBeacon? = nil,
        claimStore: CloudClaimActionStore? = nil,
        consentDefaults: UserDefaults = .standard,
        storageDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = { .now }
    ) {
        self.session = session
        self.accountClient = accountClient ?? CloudAccountClient()
        self.provider = provider ?? { CloudAuthService.shared.storedProvider() ?? "apple" }
        // MISMA SSOT que el claim de migración y el faro (`CloudMigrationController.swift:190`): un
        // `device_id` distinto por camino rompería la idempotencia del re-claim del mismo device.
        self.deviceID = deviceID ?? MigrationWorkExecutor.vendorDeviceID
        self.beacon = beacon ?? CloudBeacon()
        self.claimStore = claimStore ?? .shared
        self.consentDefaults = consentDefaults
        self.storageDefaults = storageDefaults
        self.now = now
    }

    // MARK: - Alta

    /// Reserva la cuenta y deja el device listo para que A3 continúe. ORDEN EXACTO (§k.3 paso 0), y el orden
    /// importa: **faro → estampado → consent → métrica**. El faro va TEMPRANO —apenas se reserva la cuenta,
    /// no al final del alta— porque su trabajo es que un 2º device del mismo Apple ID que firme con otro
    /// proveedor DURANTE la ventana del alta lo detecte antes de sembrar una segunda cuenta divergente.
    /// El orden lo pinnea un source-scan (`BornCloudSignUpServiceTests`): no es observable desde el
    /// resultado, porque los tres efectos van a almacenes distintos.
    ///
    /// NUNCA lanza. NUNCA aborta por el consent (paso 5): eso es trazabilidad, no una precondición.
    func signUp() async -> BornCloudSignUpOutcome {
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            return .sessionExpired(detail: "no access token")
        }
        let sessionProvider = provider()

        // 1) `POST /account/claim` con `migration: FALSE`. No es un detalle: `true` armaría
        //    `migration_in_progress` server-side (§g.1) y clavaría una máquina de migración que en
        //    born-cloud NO EXISTE — nadie emitiría el `migration_progress('cutover')` que la cierra, así
        //    que la cuenta quedaría en migración perpetua. Explícito, aunque sea el default del client
        //    (`CloudAccountClient.swift:181`), para que sea legible y para que su mutación sea visible.
        let claimOutcome = await accountClient.claim(
            jwt: jwt, deviceID: deviceID, provider: sessionProvider, migration: false)

        let claimState: AccountClaimDecision.ClaimState
        switch claimOutcome {
        case .success(let state):        claimState = state
        case .sessionExpired(let d):     return .sessionExpired(detail: d)
        case .accountUnavailable(let d): return .accountUnavailable(detail: d)
        case .transient(let d):          return .transient(detail: d)
        }

        let userID = session.currentUserID

        // 2) Decisión §f.1 con los dos booleanos del faro leídos del faro REAL (nada hardcodeado).
        //    `providerMatchesBeacon` se DERIVA de `ProviderMismatchLogic` —la misma lógica sub-first que
        //    usa el Welcome (`WelcomeCloudSignInView.swift:404-412`)— en vez de comparar aquí a mano: dos
        //    reglas para la misma pregunta es exactamente cómo divergen (H4: GoTrue LINKEA identidades del
        //    mismo email verificado al MISMO `sub`, así que el provider a secas NO es la señal).
        let beaconLinked = beacon.isCloudAccountLinked
        let beaconProvider = beacon.linkedProvider
        let providerMatchesBeacon = ProviderMismatchLogic.decide(
            accountExists: false,
            beaconLinked: beaconLinked,
            beaconAccountHash: beacon.accountHash,
            beaconProvider: beaconProvider,
            sessionSubHash: userID.map { CloudBeacon.hash($0) } ?? "",
            sessionProvider: sessionProvider) == .proceed

        let action = AccountClaimDecision.decide(
            state: claimState,
            branch: .bornCloud,
            beaconSaysCloudActivated: beaconLinked,
            providerMatchesBeacon: providerMatchesBeacon)
        BornCloudBreadcrumb.claimResolved(
            state: Self.wireName(claimState), action: CloudClaimActionStore.encode(action))

        // 3) FARO, solo con `created` (§k.3 paso 0). Con `existing_stable` la cuenta ya existía y su faro lo
        //    escribió el device que la creó: re-escribirlo aquí pisaría `linkedAt` y, en un 2º device con
        //    otro proveedor, cambiaría el provider del faro por el de quien acaba de llegar — que es
        //    justamente la referencia que la variante B necesita intacta. Con `claiming_in_progress` no hay
        //    nada reservado por nosotros que anunciar.
        if claimState == .created {
            beacon.writeCloudAccountLinked(
                provider: sessionProvider, accountSub: userID, now: now())
        }

        // 4) Estampar el claim-store con la acción RESUELTA (no con `.seedBornCloud` fijo: en born-cloud
        //    `existing_stable` da `routeReturningUser` y `claiming_in_progress` da `waitForLeader`, y el
        //    gate de arranque del runtime distingue las tres — `CloudSyncRuntime.shouldStartSync`). Sin
        //    estampado, el guard de identidad deja el runtime en `.idle` post-relanzamiento
        //    (`CloudSyncRuntime.swift:326`): es el M1 del review del adopt, no lo repitas.
        if let userID {
            claimStore.record(action, forUserID: userID)
        } else {
            BornCloudBreadcrumb.claimStampSkippedNoUserID()
        }

        // 5) Consent: solo se VERIFICA. Lo escribe `CloudConsentView` antes de llegar aquí
        //    (`CloudConsentView.swift:103-110`, vía `PreferenceSyncService.set`, que espeja en el mismo
        //    `UserDefaults` que se lee aquí). Falta ⇒ ruido, JAMÁS abortar (molde `runAdoptFlow` paso
        //    5-bis): el registro GDPR es append-only y su ausencia es un fallo de traza, no del alta.
        verifyConsentRegistered()

        // 6) KPI de registros/día del alta nube, one-shot por `userID` dentro del servicio. SOLO con
        //    `created` = fila NUEVA server-side (paridad exacta con `MigrationWorkExecutor.performClaim`):
        //    un `existing_stable` es un 2º device, no un alta. Es el contador que alimenta el gatillo de
        //    PITR de P4 ([[MODO-NUBE-DIFERIDOS]] #2, ~500 cloud-only activos) — sin él ese diferido queda
        //    sin instrumentar.
        if claimState == .created, let userID {
            MetricsService.cloudRegistrationCompletedIfFirst(userID: userID, detail: "bornCloud")
        }

        switch action {
        case .seedBornCloud:
            return .seeded
        case .routeReturningUser:
            return .routeReturningUser
        case .waitForLeader:
            return .waitForLeader
        case .showProviderMismatch:
            // MEDIDO contra `AccountClaimDecision.decide` (2026-08-09): la variante B es
            // `returningUser`-ONLY (`AccountClaimDecision.swift:83`) ⇒ desde `.bornCloud` esta rama es HOY
            // INALCANZABLE, con cualquier combinación del faro. Se conserva —y con su canario— porque el
            // `switch` es exhaustivo por el compilador y porque la tabla que decide vive en
            // `AccountClaimDecision`, no aquí: el día que alguien la amplíe, este consumidor ya reacciona
            // bien en vez de sembrar en silencio.
            MetricsService.cloudSignInProviderMismatch()
            return .providerMismatch(knownProvider: beaconProvider)
        case .proceedMigration:
            // Igual de inalcanzable (la rama born-cloud jamás lidera una migración) y, si apareciera, la
            // respuesta segura es NO seguir: born-cloud no tiene máquina de migración que conducir.
            BornCloudBreadcrumb.unexpectedAction(CloudClaimActionStore.encode(action))
            return .transient(detail: "unexpected action: proceedMigration")
        }
    }

    // MARK: - Activación del almacenamiento nube (A3)

    /// **La primitiva del camino feliz de A3.** Escribe el par `.cloud` + `mirrorOffArmed` y devuelve la
    /// FASE TERMINAL que el llamador debe presentar: «Cierra y vuelve a abrir Yala».
    ///
    /// Se invoca SOLO tras un `.seeded` (cuenta reservada con `created`), y **ANTES de sembrar nada** — en
    /// born-cloud eso es trivialmente cierto porque no hay nada pre-relanzamiento que sembrar: el onboarding
    /// corre DESPUÉS, ya con el store montado sin mirror.
    ///
    /// Tres cosas que van escritas porque no son obvias:
    ///  1. **El relanzamiento no es una preferencia de UX, es lo que sostiene el invariante.**
    ///     `SwiftDataConfiguration.personalConfiguration` se evalúa UNA vez al construir el container, así
    ///     que escribir el par aquí NO remonta nada: el mirror de CloudKit sigue vivo en este proceso. Lo
    ///     que impide que el motor arranque encima es
    ///     `MigrationRuntimeGate.isPersonalMountMismatch` (A3, segunda mitad), no la buena voluntad del
    ///     llamador.
    ///  2. **Devuelve la fase, NO mata el proceso.** `CloudWelcomeSignInPhase.relaunch` es terminal y su
    ///     contrato es que el usuario cierra la app a mano — jamás un `exit(0)`: iOS trata la auto-muerte
    ///     como un crash y App Review la rechaza.
    ///  3. **No journalea nada.** El journal se queda en `notStarted`, que YA es fase estable para el
    ///     runtime, así que post-relanzamiento el motor arranca solo con el estampado del claim que dejó
    ///     `signUp()`. Meter esto en la máquina de migración es el error que A2/A3 existen para no cometer.
    ///
    /// Idempotente: re-invocarla reescribe las mismas dos keys.
    @discardableResult
    func activateBornCloudStorage() -> CloudWelcomeSignInPhase {
        StorageModePersistence.writeCloudArmed(defaults: storageDefaults)
        BornCloudBreadcrumb.storageActivated()
        return .relaunch
    }

    // MARK: - Consent (paso 5)

    /// Comprueba que las DOS keys del consent estén registradas y hace ruido si falta alguna. Las lee con la
    /// misma forma que `runAdoptFlow` (`object(forKey:) as? Int`) porque `PreferenceSyncService.set(int:)`
    /// es quien las escribe. No devuelve nada a propósito: ningún llamador debe poder abortar por esto.
    private func verifyConsentRegistered() {
        let acceptedAt = consentDefaults.object(
            forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue) as? Int
        let textVersion = consentDefaults.object(
            forKey: PrefSyncKey.cloudConsentTextVersion.rawValue) as? Int
        switch (acceptedAt, textVersion) {
        case (nil, nil):  BornCloudBreadcrumb.consentMissing("acceptedAt+textVersion")
        case (nil, _):    BornCloudBreadcrumb.consentMissing("acceptedAt")
        case (_, nil):    BornCloudBreadcrumb.consentMissing("textVersion")
        default:          break
        }
    }

    /// Nombre del estado tal y como viaja en el wire (§f.1) — para el breadcrumb, sin PII.
    private static func wireName(_ state: AccountClaimDecision.ClaimState) -> String {
        switch state {
        case .created:            return "created"
        case .existingStable:     return "existing_stable"
        case .claimingInProgress: return "claiming_in_progress"
        }
    }
}
