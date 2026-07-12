//
//  PreferenceMergeLogic.swift
//  Yala
//
//  Lógica PURA de merge de las preferencias sincronizadas (Modo Nube, I13). Extracción ORÁCULO-PRIMERO
//  del switch de `PreferenceSyncService.applyRemoteValues()`: el comportamiento por-familia es
//  BYTE-IDÉNTICO al de hoy (la rama iKV no cambia). Lo consumen AMBAS ramas:
//    - `.icloud`: el service lee remoto de iKV + local de UserDefaults, construye `PrefValue`, llama
//      `decide`, aplica la escritura (misma que hoy) — sin cambio de comportamiento.
//    - `.cloud`: el service lee remoto del pull (TEXT decodificado por `PrefValueCodec`) + local, y
//      aplica idéntico → las semánticas NO-LWW (rank de onboarding, vacío-válido del Panel) se
//      resuelven client-side en el READ, exactamente como con iKV (decisión del plan §Decisiones).
//
//  4 semánticas del inventario (§I13-INVENTARIO):
//    1. Strings con guard NO-VACÍO (12) — remoto presente y no vacío y distinto → aplica.
//    2. Strings del Panel donde "" es estado VÁLIDO (8) — por presencia; "" se escribe.
//    3. Bools por presencia (9) — presente → set incondicional (paridad exacta: hoy NO hay diff-check).
//    4. Ints por presencia (3) — presente y distinto → set (+ señal de formato/weekday).
//    + `onboardingMode`: never-downgrade por `OnboardingMode.rank` (NO LWW).
//    + `appLanguageOverride`: destino App Group suite, vacío = removeObject, señal `.language`.
//
//  `nonisolated`: lógica pura sin relación con el main actor (se testea directa; el service la invoca
//  desde `@MainActor`). `OnboardingMode(rawValue:)` es un init sintetizado nonisolated (no se llama a
//  `OnboardingMode.current()`, que leería UserDefaults — la fuente local llega por parámetro).
//

import Foundation

// MARK: - Familia de merge

/// La familia de merge de una key sincronizada. Determina la semántica que aplica `decide`.
nonisolated enum PrefFamily {
    /// Strings con guard no-vacío (12). Aplica si remoto presente, no vacío y distinto del local.
    case stringGuardNonEmpty
    /// Strings del Panel donde "" es estado válido (8). Aplica por presencia si difiere (incl. "").
    case panelPresenceEmptyValid
    /// Bools por presencia (9). Aplica (set incondicional) si remoto presente — SIN diff-check (oráculo).
    case boolPresence
    /// Ints por presencia (3). Aplica si remoto presente y distinto.
    case intPresence
    /// `onboardingMode`: never-downgrade por rank (NO LWW).
    case onboardingModeNeverDowngrade
    /// `appLanguageOverride`: destino App Group suite; vacío = remove; señal `.language`.
    case appLanguageOverride
}

// MARK: - Señal de side-effect

/// Señal agregada que dispara el bloque POST-PASS del service (`applyMergeOutcome`) o el post inline.
/// Se emite SOLO cuando la escritura NO es `.skip`.
nonisolated enum PrefSideSignal {
    /// Cambió una preferencia de FORMATO (`currencyDisplayFormat`/`decimalPlaces`) → `formattingVersion += 1`.
    case formatting
    /// Cambió `firstWeekday` → re-espejo a App Group + `WidgetCenter.reloadAllTimelines()`.
    case weekday
    /// Cambió `appLanguageOverride` → post `.languageDidChange` (re-render de UI en caliente).
    case language
}

// MARK: - PrefSyncKey (SSOT de la taxonomía)

/// Las keys sincronizadas cross-device (SSOT único: el service itera `allCases`). `rawValue` = la key
/// EXACTA de UserDefaults / iKV / backend (no renombrar: rompería la persistencia y el matching).
///
/// El orden de los cases NO importa para el merge (cada key es independiente). El conteo actual es 36
/// (34 hasta I13; I14 P5 añadió `cloudConsentAcceptedAt` + `cloudConsentTextVersion`).
nonisolated enum PrefSyncKey: String, CaseIterable {
    // Strings guard no-vacío (12)
    case defaultCurrencyCode
    case userName
    case defaultPeriod
    case secondaryCurrencies
    case userProfileIcon
    case currencyDisplayFormat
    case voiceLanguage
    case autoFocusField
    case accountsSortOrderNames
    case insightsTone
    case insightsFocus
    case financialMindset
    // Merge especial: never-downgrade por rank
    case onboardingMode
    // Merge especial: App Group suite + remove-on-empty + languageDidChange
    case appLanguageOverride
    // Strings del Panel donde "" es válido (8)
    case panelTendenciasOrder
    case panelTendenciasHidden
    case panelDistribucionOrder
    case panelDistribucionHidden
    case panelPlanificacionOrder
    case panelPlanificacionHidden
    case panelSectionsHidden
    case panelSectionsOrder
    // Bools por presencia (9)
    case budgetAlertsEnabled
    case expensesOnlyMode
    case colorfulIcons
    case showVariations
    case panelAccountsCollapsed
    case includeGroupTransactionsInFeed
    case includeGroupsInPanelTotal
    case includeGroupTransactionsInStats
    case bridgeGroupExpensesToPersonalAccounts
    // Ints por presencia (5 — +2 en I14 P5)
    case firstWeekday
    case decimalPlaces
    case averageLineMode
    // Consent del Modo Nube (§2.8/§e.6, I14 P5): epoch de aceptación + versión del texto aceptado.
    // Sincronizadas para trazabilidad GDPR — en `.icloud` van a iKV y el drenaje del cutover las lleva
    // al backend; en `.cloud` (adopt) van directo al outbox de prefs. rawValue = key de UserDefaults.
    case cloudConsentAcceptedAt
    case cloudConsentTextVersion

    /// La familia de merge de esta key.
    var family: PrefFamily {
        switch self {
        case .defaultCurrencyCode, .userName, .defaultPeriod, .secondaryCurrencies,
             .userProfileIcon, .currencyDisplayFormat, .voiceLanguage, .autoFocusField,
             .accountsSortOrderNames, .insightsTone, .insightsFocus, .financialMindset:
            return .stringGuardNonEmpty
        case .onboardingMode:
            return .onboardingModeNeverDowngrade
        case .appLanguageOverride:
            return .appLanguageOverride
        case .panelTendenciasOrder, .panelTendenciasHidden,
             .panelDistribucionOrder, .panelDistribucionHidden,
             .panelPlanificacionOrder, .panelPlanificacionHidden,
             .panelSectionsHidden, .panelSectionsOrder:
            return .panelPresenceEmptyValid
        case .budgetAlertsEnabled, .expensesOnlyMode, .colorfulIcons, .showVariations,
             .panelAccountsCollapsed, .includeGroupTransactionsInFeed, .includeGroupsInPanelTotal,
             .includeGroupTransactionsInStats, .bridgeGroupExpensesToPersonalAccounts:
            return .boolPresence
        case .firstWeekday, .decimalPlaces, .averageLineMode,
             .cloudConsentAcceptedAt, .cloudConsentTextVersion:
            return .intPresence
        }
    }

    /// El tipo (para el codec TEXT del pull/outbox). Deriva de la familia.
    var kind: PrefKind {
        switch family {
        case .stringGuardNonEmpty, .panelPresenceEmptyValid,
             .onboardingModeNeverDowngrade, .appLanguageOverride:
            return .string
        case .boolPresence:
            return .bool
        case .intPresence:
            return .int
        }
    }

    /// La señal de side-effect que dispara esta key al aplicarse (nil si ninguna).
    var signal: PrefSideSignal? {
        switch self {
        case .currencyDisplayFormat, .decimalPlaces: return .formatting
        case .firstWeekday: return .weekday
        case .appLanguageOverride: return .language
        default: return nil
        }
    }
}

// MARK: - Decisión de merge

/// El resultado puro del merge de UNA key. `signal` != nil solo cuando `write` != `.skip`.
nonisolated struct PrefMergeDecision: Equatable {
    /// Qué escribir en el destino local (UserDefaults standard o App Group suite, lo resuelve el service).
    enum Write: Equatable {
        /// No hacer nada (remoto ausente / falla guard / igual al local).
        case skip
        /// Escribir este valor en el destino.
        case set(PrefValue)
        /// Eliminar la key del destino (solo `appLanguageOverride` con remoto vacío).
        case remove
    }

    let write: Write
    let signal: PrefSideSignal?

    static let skip = PrefMergeDecision(write: .skip, signal: nil)
}

// MARK: - PreferenceMergeLogic

nonisolated enum PreferenceMergeLogic {

    /// Decide el merge de UNA key. `remote`/`local` en `PrefValue?` (nil = ausente).
    ///   - `remote`: valor remoto YA normalizado por presencia (el caller pasa nil si la key está
    ///     ausente en la fuente; si presente, el `PrefValue` decodificado — strings del Panel/appLang
    ///     llegan como `.string("")` cuando la fuente tenía "" ). El guard no-vacío se aplica AQUÍ.
    ///   - `local`: valor local actual del destino (nil = ausente; para ints el caller pasa `.int(0)`
    ///     cuando está ausente, paridad con `UserDefaults.integer`).
    static func decide(key: PrefSyncKey, remote: PrefValue?, local: PrefValue?) -> PrefMergeDecision {
        guard let remote else { return .skip }

        switch key.family {
        case .stringGuardNonEmpty:
            guard let r = remote.stringValue, !r.isEmpty else { return .skip }
            if local?.stringValue != r {
                return PrefMergeDecision(write: .set(.string(r)), signal: key.signal)
            }
            return .skip

        case .panelPresenceEmptyValid:
            guard let r = remote.stringValue else { return .skip }
            if local?.stringValue != r {
                return PrefMergeDecision(write: .set(.string(r)), signal: key.signal)
            }
            return .skip

        case .boolPresence:
            guard let r = remote.boolValue else { return .skip }
            // Oráculo: set INCONDICIONAL cuando el remoto está presente (hoy no hay diff-check).
            return PrefMergeDecision(write: .set(.bool(r)), signal: key.signal)

        case .intPresence:
            guard let r = remote.intValue else { return .skip }
            let l = local?.intValue ?? 0
            if l != r {
                return PrefMergeDecision(write: .set(.int(r)), signal: key.signal)
            }
            return .skip

        case .onboardingModeNeverDowngrade:
            guard let r = remote.stringValue, !r.isEmpty,
                  let remoteMode = OnboardingMode(rawValue: r) else { return .skip }
            let localMode = OnboardingMode(rawValue: local?.stringValue ?? "") ?? .full
            if remoteMode.rank > localMode.rank {
                return PrefMergeDecision(write: .set(.string(r)), signal: nil)
            }
            return .skip

        case .appLanguageOverride:
            guard let r = remote.stringValue else { return .skip }
            let current = local?.stringValue ?? ""
            if current != r {
                let write: PrefMergeDecision.Write = r.isEmpty ? .remove : .set(.string(r))
                return PrefMergeDecision(write: write, signal: .language)
            }
            return .skip
        }
    }
}
