//
//  PreferenceSyncService.swift
//  Yala
//
//  Syncs critical user preferences via NSUbiquitousKeyValueStore (iCloud Key-Value)
//  so they propagate across devices. NOT synced: hasCompletedOnboarding (per-device).
//

import Foundation
import WidgetKit

// MARK: - Cross-Device Wipe Notifications

extension Notification.Name {
    /// Fired when a remote device initiated a data wipe.
    /// `userInfo["onboardingAlreadyDone"]` (Bool) indicates whether another device already completed onboarding.
    static let remoteWipeDetected = Notification.Name("remoteWipeDetected")

    /// Fired when a remote device completed onboarding after a wipe.
    /// Used to pull a device out of mid-onboarding and show a sync banner instead.
    static let remoteOnboardingCompleted = Notification.Name("remoteOnboardingCompleted")

    /// Fired when iCloud became available after the container was created without CloudKit.
    static let iCloudMismatchDetected = Notification.Name("iCloudMismatchDetected")
}

// MARK: - Comportamiento de sync de prefs (M1 Inc 4)

/// Resolver PURO del comportamiento de las 37 keys sincronizadas. Tres modos — el tercero existe
/// porque en sesión SECUNDARIA el modo EFECTIVO es `.cloud` (getter descriptor-aware) pero la
/// decisión 7 del diseño M1 apaga el sync de prefs: sin `localOnly`, la rama `.icloud` escribiría
/// las prefs de la invitada al iCloud KV del DUEÑO (propagándolas a sus otros devices) y la rama
/// `.cloud` las encolaría a su outbox (subiendo los VALORES del dueño a la cuenta de la invitada).
nonisolated enum PrefsSyncBehavior: Equatable {
    /// `.icloud`: dual-write local+iKV, apply desde iKV (comportamiento de HOY).
    case icloudKeyValue
    /// `.cloud`: local + outbox durable — el backend es la fuente (I13).
    case cloudOutbox
    /// Sesión secundaria (M1): SOLO UserDefaults local — ni iKV ni outbox, en ninguna dirección.
    case localOnly

    /// La secundaria gana PRIMERO (el `storageMode` que llega aquí ya es el EFECTIVO).
    static func resolve(storageMode: StorageMode, secondarySessionActive: Bool) -> PrefsSyncBehavior {
        if secondarySessionActive { return .localOnly }
        switch storageMode {
        case .icloud: return .icloudKeyValue
        case .cloud: return .cloudOutbox
        }
    }
}

@MainActor
final class PreferenceSyncService {

    // MARK: - Singleton

    static let shared = PreferenceSyncService()

    // MARK: - Synced Keys
    //
    // La taxonomía de las 37 keys sincronizadas (familias de merge + señales + tipos) vive en el helper
    // pure-logic `PrefSyncKey` (SSOT único, `PreferenceMergeLogic.swift`), consumido por AMBAS ramas
    // (`.icloud` iKV y `.cloud` backend). El merge se decide en `PreferenceMergeLogic.decide` (byte-idéntico
    // a la lógica que vivía inline aquí) y el bloque POST-PASS compartido es `applyMergeOutcome`.

    /// Keys for cross-device wipe coordination (iKV = remote, local = UserDefaults)
    private enum WipeKey {
        static let remoteWipe = "lastWipeTimestamp"           // iKV
        static let remoteOnboarding = "lastOnboardingTimestamp" // iKV
        static let localWipe = "lastKnownWipeTimestamp"       // UserDefaults
        static let localOnboarding = "lastKnownOnboardingTimestamp" // UserDefaults
    }

    /// Key for notification userInfo
    static let onboardingAlreadyDoneKey = "onboardingAlreadyDone"

    private let iKV = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard
    private var isObserverRegistered = false

    // MARK: - Modo Nube (I13) — cola durable de prefs para la rama `.cloud`

    /// Cola durable App Group de las prefs salientes (`.cloud`). `nil` = App Group no disponible. Lazy:
    /// solo se resuelve al primer uso. DARK: `CloudSyncFlags.storageMode` es SIEMPRE `.icloud` hoy, así
    /// que la rama que la usa no corre en producción.
    private lazy var prefsOutbox: PrefsOutbox? = PrefsOutbox()

    /// El `sub` de la sesión Nube actual (owner-scoping M1 del outbox). Inyectable para tests; por
    /// defecto la sesión viva de `CloudAuthService`. Solo se consulta en la rama `.cloud`.
    var cloudUserIDProvider: () -> String? = { CloudAuthService.shared.currentUserID }

    /// Sesión secundaria activa (M1 Inc 4). Inyectable para tests.
    var secondarySessionActiveProvider: () -> Bool = { SecondarySessionStore.isActive() }

    /// Comportamiento resuelto de las 37 keys (ver `PrefsSyncBehavior`).
    private var behavior: PrefsSyncBehavior {
        PrefsSyncBehavior.resolve(
            storageMode: CloudSyncFlags.storageMode,
            secondarySessionActive: secondarySessionActiveProvider())
    }

    private init() {}

    // MARK: - Timestamps de coordinación (lectura para detección de returning user)

    /// Último timestamp de onboarding completado (KV-store, per-Apple-ID). `0` si
    /// nunca se completó. Sobrevive al uninstall → señal rápida de returning user.
    var lastOnboardingTimestamp: Double { iKV.double(forKey: WipeKey.remoteOnboarding) }

    /// Último timestamp de wipe (KV-store). `0` si nunca hubo wipe.
    var lastWipeTimestamp: Double { iKV.double(forKey: WipeKey.remoteWipe) }

    // MARK: - Bootstrap

    /// Call early in app launch (before services read preferences).
    /// Pulls remote values into UserDefaults and starts observing changes.
    /// Safe to call multiple times (e.g. pull-to-refresh) — observer registered only once.
    func bootstrap() {
        switch behavior {
        case .icloudKeyValue:
            iKV.synchronize()
            applyRemoteValues()
        case .cloudOutbox:
            // La fuente de las 37 keys es el BACKEND vía `CloudSyncRuntime` (pull + merge en su ciclo);
            // NO se lee iKV aquí. Las señales wipe/onboarding (WipeKeys) SÍ siguen en iKV en ambos modos
            // v1 (su reemplazo por el summary del backend es I14/§k.4 — documentado).
            //
            // CUTOVER S8 (§g.4) — DIFERIDOS #30 CERRADO (I10-wiring w8): el drenaje único iKV→outbox
            // corre vía `drainiKVToOutboxOnceIfNeeded()`, disparado desde `MigrationPhaseStore.configure`
            // (que conoce la fase journaleada — el gate LÍDER-only) y redundantemente aquí (por si el
            // configure corrió ANTES de que la sesión nube tuviera userID). Idempotente por sentinel.
            drainiKVToOutboxOnceIfNeeded()
        case .localOnly:
            // M1 secundaria: prefs device-local puras — nada que traer ni drenar.
            break
        }

        // Offline catch-up: process any wipe/onboarding signals that arrived while app was closed
        // (WipeKeys viven en iKV en AMBOS modos v1). En SECUNDARIA se saltan: el iKV es del DUEÑO —
        // una señal de wipe de SUS otros devices jamás debe operar la sesión de la invitada.
        if behavior != .localOnly {
            checkForRemoteWipeSignal()
        }

        guard !isObserverRegistered else { return }
        isObserverRegistered = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iKV
        )
    }

    // MARK: - Write (rama por storageMode: `.icloud` dual-write local+iKV · `.cloud` local + outbox)
    //
    // Los call-sites NO cambian (contrato §k.7/#18): la rama vive 100% dentro del service. `local.set`
    // corre SIEMPRE (fuente de lectura local en ambos modos). `appLanguageOverride` NO pasa por aquí
    // (lo escribe `LanguageManager.overrideLanguage` directo a iKV → su migración a `.cloud` es DIFERIDA,
    // fuera de I13; DARK, sin efecto hoy).

    func set(string value: String, forKey key: String) {
        local.set(value, forKey: key)
        switch behavior {
        case .icloudKeyValue:
            iKV.set(value, forKey: key)
            iKV.synchronize()
        case .cloudOutbox:
            enqueuePref(key: key, value: .string(value))
        case .localOnly:
            break
        }
    }

    func set(bool value: Bool, forKey key: String) {
        local.set(value, forKey: key)
        switch behavior {
        case .icloudKeyValue:
            iKV.set(value, forKey: key)
            iKV.synchronize()
        case .cloudOutbox:
            enqueuePref(key: key, value: .bool(value))
        case .localOnly:
            break
        }
    }

    func set(int value: Int, forKey key: String) {
        local.set(value, forKey: key)
        switch behavior {
        case .icloudKeyValue:
            iKV.set(value, forKey: key)
            iKV.synchronize()
        case .cloudOutbox:
            enqueuePref(key: key, value: .int(value))
        case .localOnly:
            break
        }
    }

    /// Elimina una pref (G5-B — limpieza del consent de grupos en el sign-out solo-grupos). Cubre las
    /// 3 ramas de `PrefsSyncBehavior` para que el borrado no reviva:
    ///  - `.icloudKeyValue`: `removeObject` local + iKV + `synchronize()` — CR-2: sin limpiar el iKV,
    ///    `applyRemoteValues()` del próximo boot RESUCITARÍA el consent (el iKV es la fuente en `.icloud`).
    ///  - `.cloudOutbox`: `removeObject` local + encola el valor CLEARED al outbox. El wire de prefs no
    ///    tiene tombstone; las únicas keys que se borran hoy son `intPresence` (consent), donde `0` ≡
    ///    ausencia (`isAccepted` es `> 0`) → encolar `.int(0)` limpia la fuente backend de forma honesta.
    ///  - `.localOnly` (secundaria): solo local — ni iKV ni outbox tocan la cuenta ajena.
    func remove(forKey key: String) {
        local.removeObject(forKey: key)
        switch behavior {
        case .icloudKeyValue:
            iKV.removeObject(forKey: key)
            iKV.synchronize()
        case .cloudOutbox:
            enqueuePref(key: key, value: .int(0))
        case .localOnly:
            break
        }
    }

    /// Encola una pref en el outbox durable (`.cloud`). El HLC se estampa en el outbox (verdad temporal).
    /// Latencia de subida = cadencia del `CloudSyncRuntime` (≈60s foreground) — decisión v1 (paridad con
    /// la latencia de dominio; NO se hace un push inmediato fuera de diseño).
    private func enqueuePref(key: String, value: PrefValue) {
        guard let prefsOutbox else {
            #if DEBUG
            print("PreferenceSyncService: prefs outbox unavailable — cannot enqueue \(key)")
            #endif
            return
        }
        guard let userID = cloudUserIDProvider() else {
            #if DEBUG
            print("PreferenceSyncService: no cloud userID — cannot owner-scope pref \(key)")
            #endif
            return
        }
        do {
            try prefsOutbox.enqueue(key: key, userID: userID, value: value)
        } catch {
            #if DEBUG
            print("PreferenceSyncService: enqueue pref \(key) failed: \(error)")
            #endif
        }
    }

    // MARK: - Drenaje único iKV → outbox (CUTOVER S8, DIFERIDOS #30 — I10-wiring w8)

    /// SSOT del prefijo en `PrefsCutoverDrain.sentinelPrefix` (#37: la reversa y el sign-out wipe lo
    /// retiran por prefijo — un literal duplicado aquí divergiría en silencio).
    private static let ikvDrainSentinelPrefix = PrefsCutoverDrain.sentinelPrefix

    /// Drena UNA VEZ por userID el estado iKV → outbox de prefs, SOLO en el device LÍDER de la
    /// migración en su ventana post-relaunch (gate por fase journaleada — ver `PrefsCutoverDrain`, que
    /// documenta POR QUÉ un adoptador/follower NO drena: su iKV puede ser más viejo que el backend y el
    /// HLC fresco del enqueue lo haría ganar). Belt: salta keys con entry ya pendiente en el outbox
    /// (un write local post-relaunch es más nuevo que la réplica iKV). El sentinel se estampa SOLO si
    /// el drenaje completó sin fallos de I/O — un fallo parcial reintenta al próximo boot (LWW absorbe
    /// el re-enqueue). Callers: `MigrationPhaseStore.configure` (orden garantizado post-journal) +
    /// `bootstrap()` rama `.cloud` (redundante benigno).
    func drainiKVToOutboxOnceIfNeeded(sentinelDefaults: UserDefaults = .standard) {
        // Behavior y no storageMode a secas: en SECUNDARIA el modo efectivo es `.cloud`, pero el iKV
        // presente es el del DUEÑO — drenarlo al outbox de la invitada subiría SUS valores a la
        // cuenta de ella. Solo el `.cloud` real (sin descriptor) drena.
        guard behavior == .cloudOutbox else { return }
        guard PrefsCutoverDrain.isLeaderPostRelaunchPhase(MigrationPhaseStore.shared.currentPhase) else { return }
        guard let userID = cloudUserIDProvider() else { return }
        let sentinelKey = Self.ikvDrainSentinelPrefix + userID
        guard !sentinelDefaults.bool(forKey: sentinelKey) else { return }
        guard let prefsOutbox else {
            #if DEBUG
            print("PreferenceSyncService: drain iKV — outbox no disponible (App Group)")
            #endif
            return
        }

        let present = Set(PrefSyncKey.allCases.filter { readRemoteIKV($0) != nil }.map(\.rawValue))
        let pending = Set(prefsOutbox.entries(forUserID: userID).map(\.key))
        let planned = PrefsCutoverDrain.plan(
            allKeys: PrefSyncKey.allCases.map(\.rawValue),
            presentInIKV: present, pendingInOutbox: pending)

        var failures = 0
        for raw in planned {
            guard let key = PrefSyncKey(rawValue: raw), let value = readRemoteIKV(key) else { continue }
            do {
                try prefsOutbox.enqueue(key: raw, userID: userID, value: value)
            } catch {
                failures += 1
                #if DEBUG
                print("PreferenceSyncService: drain iKV — enqueue \(raw) falló: \(error)")
                #endif
            }
        }
        if failures == 0 {
            sentinelDefaults.set(true, forKey: sentinelKey)
        }
        CloudSyncBreadcrumb.prefsCutoverDrained(count: planned.count - failures, failures: failures)
    }

    // MARK: - Apply Detected Defaults (Risk 1 — "data found" with no currency)

    /// Sets sensible defaults when iCloud data arrives but no preferences exist.
    /// Guards on nil currency — only runs once.
    func applyDetectedDefaultsIfNeeded() {
        guard local.string(forKey: PrefSyncKey.defaultCurrencyCode.rawValue) == nil else { return }

        let currency = CurrencyDefaults.detectCurrencyFromRegion()
        set(string: currency.rawValue, forKey: PrefSyncKey.defaultCurrencyCode.rawValue)
        set(string: DetailPeriod.thisMonth.rawValue, forKey: PrefSyncKey.defaultPeriod.rawValue)

        // Push to SessionState (already alive as singleton)
        SessionState.shared.selectedPeriod = .thisMonth

        #if DEBUG
        print("PreferenceSyncService: Applied detected defaults — currency=\(currency.rawValue)")
        #endif
    }

    // MARK: - Remote → Local merge (`.icloud`: iKV → local + SessionState)

    /// Merges iKV values into UserDefaults and pushes to SessionState. Byte-idéntico al comportamiento
    /// previo: la decisión per-key vive en `PreferenceMergeLogic.decide` (oráculo-primero) y el bloque
    /// POST-PASS compartido es `applyMergeOutcome`.
    private func applyRemoteValues() {
        var formattingChanged = false
        var weekdayChanged = false
        for key in PrefSyncKey.allCases {
            applyMergeDecision(
                for: key, remote: readRemoteIKV(key),
                formattingChanged: &formattingChanged, weekdayChanged: &weekdayChanged
            )
        }
        applyMergeOutcome(formattingChanged: formattingChanged, weekdayChanged: weekdayChanged)
    }

    // MARK: - Remote → Local merge (`.cloud`: backend pull → local + SessionState)

    /// Aplica las prefs bajadas del backend (`/prefs/pull`). Reusa `PreferenceMergeLogic` + el POST-PASS
    /// compartido → las semánticas NO-LWW (rank, vacío-válido) se resuelven client-side igual que en iKV.
    /// Lo invoca `CloudSyncRuntime` tras el pull. Una key desconocida se ignora (forward-compat).
    func applyPulledPrefs(_ prefs: [PulledPref]) {
        guard !prefs.isEmpty else { return }
        var formattingChanged = false
        var weekdayChanged = false
        for pref in prefs {
            guard let key = PrefSyncKey(rawValue: pref.key) else { continue }
            let remote: PrefValue? = pref.value.map { PrefValueCodec.decode($0, as: key.kind) }
            applyMergeDecision(
                for: key, remote: remote,
                formattingChanged: &formattingChanged, weekdayChanged: &weekdayChanged
            )
        }
        applyMergeOutcome(formattingChanged: formattingChanged, weekdayChanged: weekdayChanged)
    }

    // MARK: - Per-key apply (compartido por ambas ramas)

    /// Aplica la decisión de merge de UNA key a su destino local (UserDefaults standard, o el App Group
    /// suite para `appLanguageOverride`) y acumula las señales de side-effect.
    private func applyMergeDecision(
        for key: PrefSyncKey, remote: PrefValue?,
        formattingChanged: inout Bool, weekdayChanged: inout Bool
    ) {
        let k = key.rawValue
        let isLanguage = (key == .appLanguageOverride)
        let localValue: PrefValue? = isLanguage ? readLanguageSuite() : readLocal(key)

        let decision = PreferenceMergeLogic.decide(key: key, remote: remote, local: localValue)

        switch decision.write {
        case .skip:
            break
        case .set(let value):
            if isLanguage {
                // Storage es App Group suite (compartido con widgets), NO standard.
                LanguageManager.sharedDefaults.set(value.stringValue ?? "", forKey: k)
            } else {
                writeLocal(key, value)
            }
        case .remove:
            // Solo `appLanguageOverride` con remoto vacío → quitar el override.
            LanguageManager.sharedDefaults.removeObject(forKey: k)
        }

        if let signal = decision.signal {
            switch signal {
            case .formatting: formattingChanged = true
            case .weekday: weekdayChanged = true
            case .language: NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
        }
    }

    /// Lee el value remoto de iKV para `key`, normalizado por presencia (nil = key ausente).
    private func readRemoteIKV(_ key: PrefSyncKey) -> PrefValue? {
        let k = key.rawValue
        guard iKV.object(forKey: k) != nil else { return nil }
        switch key.kind {
        case .string: return .string(iKV.string(forKey: k) ?? "")
        case .bool: return .bool(iKV.bool(forKey: k))
        case .int: return .int(Int(iKV.longLong(forKey: k)))
        }
    }

    /// Lee el value local actual (UserDefaults standard) para `key`. Ints devuelven `.int(0)` cuando la
    /// key está ausente (paridad con `UserDefaults.integer` y con el diff-check previo).
    private func readLocal(_ key: PrefSyncKey) -> PrefValue? {
        let k = key.rawValue
        switch key.kind {
        case .string:
            return local.string(forKey: k).map { .string($0) }
        case .bool:
            return local.object(forKey: k) != nil ? .bool(local.bool(forKey: k)) : nil
        case .int:
            return .int(local.integer(forKey: k))
        }
    }

    /// Lee el value actual del override de idioma desde el App Group suite (destino de esa key).
    private func readLanguageSuite() -> PrefValue? {
        let k = PrefSyncKey.appLanguageOverride.rawValue
        let suite = LanguageManager.sharedDefaults
        return suite.object(forKey: k) != nil ? .string(suite.string(forKey: k) ?? "") : nil
    }

    /// Escribe un `PrefValue` en UserDefaults standard para `key`.
    private func writeLocal(_ key: PrefSyncKey, _ value: PrefValue) {
        let k = key.rawValue
        switch value {
        case .string(let s): local.set(s, forKey: k)
        case .bool(let b): local.set(b, forKey: k)
        case .int(let i): local.set(i, forKey: k)
        }
    }

    // MARK: - POST-PASS compartido (SessionState + formattingVersion + firstWeekday App Group)

    /// Empuja el estado post-merge a `SessionState` y ejecuta los side-effects agregados. Compartido por
    /// AMBAS ramas (`applyRemoteValues` y `applyPulledPrefs`) — byte-idéntico al bloque previo.
    private func applyMergeOutcome(formattingChanged: Bool, weekdayChanged: Bool) {
        // Push to SessionState (critical: init() already ran with possibly empty values)
        if let rawPeriod = local.string(forKey: PrefSyncKey.defaultPeriod.rawValue),
           let period = DetailPeriod(rawValue: rawPeriod) {
            SessionState.shared.selectedPeriod = period
        }

        // expensesOnlyMode didSet propagates to app group + WidgetCenter.
        // Guard against assigning when the key is absent: Swift's didSet fires even
        // when the value doesn't change, which would write the default `false` to
        // UserDefaults and contaminate fresh-install detection in OnboardingView.
        if local.object(forKey: PrefSyncKey.expensesOnlyMode.rawValue) != nil {
            SessionState.shared.isExpensesOnlyMode = local.bool(forKey: PrefSyncKey.expensesOnlyMode.rawValue)
        }

        // financialMindset (educational UI only)
        if let mindset = local.string(forKey: PrefSyncKey.financialMindset.rawValue), !mindset.isEmpty {
            SessionState.shared.financialMindset = mindset
        }

        // onboardingMode (never-downgrade already applied above)
        SessionState.shared.onboardingMode = OnboardingMode.current()

        // Trigger UI refresh when formatting preferences change remotely
        if formattingChanged {
            SessionState.shared.formattingVersion += 1
        }

        // Sync firstWeekday to App Group for widgets
        if weekdayChanged {
            if let defaults = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) {
                defaults.set(local.integer(forKey: PrefSyncKey.firstWeekday.rawValue), forKey: "firstWeekday")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Cross-Device Wipe Signaling

    /// Called by DataWipeService BEFORE deleting data — signals other devices that a wipe occurred.
    func signalWipeInitiated() {
        let timestamp = Date.now.timeIntervalSince1970
        iKV.set(timestamp, forKey: WipeKey.remoteWipe)
        iKV.synchronize()

        // Save locally so THIS device doesn't react to its own signal
        local.set(timestamp, forKey: WipeKey.localWipe)

        #if DEBUG
        print("PreferenceSyncService: Signaled wipe initiated (timestamp=\(timestamp))")
        #endif
    }

    /// Called after onboarding completes — signals other devices that onboarding is done.
    func signalOnboardingCompleted() {
        let timestamp = Date.now.timeIntervalSince1970
        iKV.set(timestamp, forKey: WipeKey.remoteOnboarding)
        iKV.synchronize()

        // Save locally to avoid redundant processing
        local.set(timestamp, forKey: WipeKey.localOnboarding)

        #if DEBUG
        print("PreferenceSyncService: Signaled onboarding completed (timestamp=\(timestamp))")
        #endif
    }

    /// Checks for remote wipe/onboarding signals and posts notifications.
    /// Called from iCloudDidChange and bootstrap (offline catch-up).
    private func checkForRemoteWipeSignal() {
        let remoteWipe = iKV.double(forKey: WipeKey.remoteWipe)
        let localWipe = local.double(forKey: WipeKey.localWipe)
        let remoteOnboarding = iKV.double(forKey: WipeKey.remoteOnboarding)
        let localOnboarding = local.double(forKey: WipeKey.localOnboarding)

        // Caso A: Nueva señal de wipe (remoteWipe > localWipe)
        if remoteWipe > 0 && remoteWipe > localWipe {
            // Mark as processed so we don't react again
            local.set(remoteWipe, forKey: WipeKey.localWipe)

            let onboardingAlreadyDone = remoteOnboarding > remoteWipe

            // Bug #6 P0 mitigation: evaluate the decider at SIGNAL TIME (not drain
            // time). If hasCompletedOnboarding=false right now (fresh-install with
            // contaminated KV-Store), don't submit the intent — otherwise the
            // readiness gate would park it across the onboarding session and
            // process it post-onboarding, wiping the user's fresh data.
            let hasCompletedOnboarding = local.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
            let decision = RemoteWipeSignalDecider.decide(
                hasCompletedOnboarding: hasCompletedOnboarding,
                isWipingData: SessionState.shared.isWipingData,
                hasRemoteWipeTimestamp: remoteWipe > 0
            )

            #if DEBUG
            print("PreferenceSyncService: Remote wipe detected (onboardingAlreadyDone=\(onboardingAlreadyDone), shouldProcess=\(decision.shouldProcess))")
            #endif

            // Mid-onboarding silencing: mark BOTH timestamps so neither Caso A nor B
            // re-fires post-onboarding. Mirrors ContentView.markRemoteSignalsAsProcessed.
            if decision.shouldMarkSignalsAsProcessed {
                if remoteOnboarding > 0 {
                    local.set(remoteOnboarding, forKey: WipeKey.localOnboarding)
                }
            }

            guard decision.shouldProcess else { return }

            RouterEntryGate.shared.submit(.remoteWipe(skipOnboarding: onboardingAlreadyDone))
            return
        }

        // Caso B: Wipe ya procesado, pero onboarding remoto nuevo
        // (another device completed onboarding after a wipe we already processed)
        if remoteWipe > 0 && remoteWipe == localWipe
            && remoteOnboarding > remoteWipe
            && remoteOnboarding > localOnboarding {

            local.set(remoteOnboarding, forKey: WipeKey.localOnboarding)

            #if DEBUG
            print("PreferenceSyncService: Remote onboarding completed after wipe")
            #endif

            // Dual-path: also post to NotificationCenter so the ContentView
            // observer can dismiss a visible onboarding screen INSTANTLY,
            // bypassing the readiness gate (which blocks .contentView drain
            // while showOnboarding=true — defeating the purpose of this signal).
            NotificationCenter.default.post(name: .remoteOnboardingCompleted, object: nil)
            RouterEntryGate.shared.submit(.remoteOnboardingCompleted)
        }
    }

    // MARK: - External Change Observer

    @objc private func iCloudDidChange(_ notification: Notification) {
        Task { @MainActor in
            // En `.cloud` las 37 keys NO vienen de iKV (el backend es la fuente) → solo se procesan las
            // señales wipe/onboarding, que SÍ viven en iKV en ambos modos v1. En `.icloud`, ambos.
            // En SECUNDARIA (localOnly), NADA: el iKV es del DUEÑO — ni valores ni señales de wipe
            // deben operar la sesión de la invitada.
            switch self.behavior {
            case .icloudKeyValue:
                self.applyRemoteValues()
                self.checkForRemoteWipeSignal()
            case .cloudOutbox:
                self.checkForRemoteWipeSignal()
            case .localOnly:
                return
            }

            #if DEBUG
            print("PreferenceSyncService: Applied remote iKV changes")
            #endif
        }
    }
}
