//
//  PreferenceMergeLogicTests.swift
//  YalaTests / CloudSync
//
//  Goldens ORÁCULO-PRIMERO del merge de prefs (I13). El oráculo es el comportamiento ACTUAL de
//  `PreferenceSyncService.applyRemoteValues()` (rama iKV): estos tests fijan la semántica por familia y
//  garantizan que el refactor a `PreferenceMergeLogic.decide` NO la cambia.
//

import Foundation
import Testing

@testable import Yala

@Suite("PreferenceMergeLogic · I13")
struct PreferenceMergeLogicTests {

    private typealias Decision = PrefMergeDecision

    // MARK: - Familia 1: strings guard no-vacío (12)

    @Test func stringGuard_presentNonEmpty_differs_sets() {
        let d = PreferenceMergeLogic.decide(key: .userName, remote: .string("Ana"), local: .string("Bea"))
        #expect(d == Decision(write: .set(.string("Ana")), signal: nil))
    }

    @Test func stringGuard_localAbsent_sets() {
        let d = PreferenceMergeLogic.decide(key: .userName, remote: .string("Ana"), local: nil)
        #expect(d == Decision(write: .set(.string("Ana")), signal: nil))
    }

    @Test func stringGuard_empty_skips() {
        // Guard no-vacío: remoto "" NUNCA aplica (aunque el local difiera).
        let d = PreferenceMergeLogic.decide(key: .userName, remote: .string(""), local: .string("Bea"))
        #expect(d == .skip)
    }

    @Test func stringGuard_equal_skips() {
        let d = PreferenceMergeLogic.decide(key: .userName, remote: .string("Ana"), local: .string("Ana"))
        #expect(d == .skip)
    }

    @Test func stringGuard_remoteAbsent_skips() {
        let d = PreferenceMergeLogic.decide(key: .userName, remote: nil, local: .string("Bea"))
        #expect(d == .skip)
    }

    @Test func stringGuard_currencyDisplayFormat_emitsFormattingSignal() {
        let d = PreferenceMergeLogic.decide(
            key: .currencyDisplayFormat, remote: .string("symbol"), local: .string("code"))
        #expect(d == Decision(write: .set(.string("symbol")), signal: .formatting))
    }

    @Test func stringGuard_otherKeys_noSignal() {
        // Solo currencyDisplayFormat de la familia string dispara señal.
        for key: PrefSyncKey in [.defaultCurrencyCode, .defaultPeriod, .financialMindset, .insightsTone] {
            let d = PreferenceMergeLogic.decide(key: key, remote: .string("x"), local: nil)
            #expect(d.signal == nil, "\(key) no debe emitir señal")
            #expect(d.write == .set(.string("x")))
        }
    }

    // MARK: - Familia 2: Panel (8) — vacío es válido

    @Test func panel_emptyRemote_localAbsent_setsEmpty() {
        // "" es estado válido: se escribe aunque el local esté ausente (nil != "").
        let d = PreferenceMergeLogic.decide(key: .panelTendenciasHidden, remote: .string(""), local: nil)
        #expect(d == Decision(write: .set(.string("")), signal: nil))
    }

    @Test func panel_emptyRemote_equalEmptyLocal_skips() {
        let d = PreferenceMergeLogic.decide(
            key: .panelTendenciasHidden, remote: .string(""), local: .string(""))
        #expect(d == .skip)
    }

    @Test func panel_presentDiffers_sets() {
        let d = PreferenceMergeLogic.decide(
            key: .panelSectionsOrder, remote: .string("a,b,c"), local: .string("a,b"))
        #expect(d == Decision(write: .set(.string("a,b,c")), signal: nil))
    }

    @Test func panel_remoteAbsent_skips() {
        let d = PreferenceMergeLogic.decide(key: .panelSectionsOrder, remote: nil, local: .string("a,b"))
        #expect(d == .skip)
    }

    @Test func panel_allEightKeys_emptyValid() {
        let panelKeys: [PrefSyncKey] = [
            .panelTendenciasOrder, .panelTendenciasHidden, .panelDistribucionOrder,
            .panelDistribucionHidden, .panelPlanificacionOrder, .panelPlanificacionHidden,
            .panelSectionsHidden, .panelSectionsOrder,
        ]
        for key in panelKeys {
            #expect(key.family == .panelPresenceEmptyValid, "\(key) debe ser familia Panel")
            let d = PreferenceMergeLogic.decide(key: key, remote: .string(""), local: nil)
            #expect(d.write == .set(.string("")), "\(key): '' válido")
        }
    }

    // MARK: - Familia 3: bools por presencia (9) — set INCONDICIONAL

    @Test func bool_present_setsUnconditionally_evenIfEqual() {
        // Oráculo: hoy NO hay diff-check para bools → set aunque el valor coincida.
        let d = PreferenceMergeLogic.decide(key: .colorfulIcons, remote: .bool(true), local: .bool(true))
        #expect(d == Decision(write: .set(.bool(true)), signal: nil))
    }

    @Test func bool_present_localAbsent_sets() {
        let d = PreferenceMergeLogic.decide(key: .budgetAlertsEnabled, remote: .bool(false), local: nil)
        #expect(d == Decision(write: .set(.bool(false)), signal: nil))
    }

    @Test func bool_remoteAbsent_skips() {
        let d = PreferenceMergeLogic.decide(key: .colorfulIcons, remote: nil, local: .bool(true))
        #expect(d == .skip)
    }

    // MARK: - Familia 4: ints por presencia (3)

    @Test func int_present_differs_sets() {
        let d = PreferenceMergeLogic.decide(key: .averageLineMode, remote: .int(2), local: .int(1))
        #expect(d == Decision(write: .set(.int(2)), signal: nil))
    }

    @Test func int_equal_skips() {
        let d = PreferenceMergeLogic.decide(key: .averageLineMode, remote: .int(2), local: .int(2))
        #expect(d == .skip)
    }

    @Test func int_localAbsentTreatedAsZero() {
        // El caller pasa `.int(0)` para una key ausente (paridad con UserDefaults.integer).
        let d = PreferenceMergeLogic.decide(key: .averageLineMode, remote: .int(0), local: .int(0))
        #expect(d == .skip)  // 0 == 0 → no aplica
        let d2 = PreferenceMergeLogic.decide(key: .averageLineMode, remote: .int(3), local: .int(0))
        #expect(d2.write == .set(.int(3)))
    }

    @Test func int_decimalPlaces_emitsFormattingSignal() {
        let d = PreferenceMergeLogic.decide(key: .decimalPlaces, remote: .int(0), local: .int(2))
        #expect(d == Decision(write: .set(.int(0)), signal: .formatting))
    }

    @Test func int_firstWeekday_emitsWeekdaySignal() {
        let d = PreferenceMergeLogic.decide(key: .firstWeekday, remote: .int(2), local: .int(1))
        #expect(d == Decision(write: .set(.int(2)), signal: .weekday))
    }

    @Test func int_remoteAbsent_skips() {
        let d = PreferenceMergeLogic.decide(key: .decimalPlaces, remote: nil, local: .int(2))
        #expect(d == .skip)
    }

    // MARK: - onboardingMode: never-downgrade (TODOS los pares de rank)

    @Test func onboarding_neverDowngrade_allRankPairs() {
        let modes: [OnboardingMode] = [.full, .groupInvite, .completed]  // ranks 0,1,2
        for localMode in modes {
            for remoteMode in modes {
                let d = PreferenceMergeLogic.decide(
                    key: .onboardingMode,
                    remote: .string(remoteMode.rawValue),
                    local: .string(localMode.rawValue)
                )
                if remoteMode.rank > localMode.rank {
                    #expect(d.write == .set(.string(remoteMode.rawValue)),
                            "remote \(remoteMode) (rank \(remoteMode.rank)) debe ganar sobre local \(localMode)")
                } else {
                    #expect(d.write == .skip,
                            "remote \(remoteMode) NO debe pisar local \(localMode) (rank >=)")
                }
                #expect(d.signal == nil)
            }
        }
    }

    @Test func onboarding_localAbsentTreatedAsFull() {
        // local nil → .full (rank 0). completed (2) gana; full (0) no.
        let win = PreferenceMergeLogic.decide(
            key: .onboardingMode, remote: .string(OnboardingMode.completed.rawValue), local: nil)
        #expect(win.write == .set(.string(OnboardingMode.completed.rawValue)))
        let lose = PreferenceMergeLogic.decide(
            key: .onboardingMode, remote: .string(OnboardingMode.full.rawValue), local: nil)
        #expect(lose.write == .skip)
    }

    @Test func onboarding_invalidOrEmptyRemote_skips() {
        #expect(PreferenceMergeLogic.decide(
            key: .onboardingMode, remote: .string(""), local: nil).write == .skip)
        #expect(PreferenceMergeLogic.decide(
            key: .onboardingMode, remote: .string("garbage"), local: nil).write == .skip)
        #expect(PreferenceMergeLogic.decide(
            key: .onboardingMode, remote: nil, local: .string("full")).write == .skip)
    }

    // MARK: - appLanguageOverride: suite + remove-on-empty + señal language

    @Test func appLanguage_setValue_differs_setsAndSignalsLanguage() {
        let d = PreferenceMergeLogic.decide(
            key: .appLanguageOverride, remote: .string("es-419"), local: nil)
        #expect(d == Decision(write: .set(.string("es-419")), signal: .language))
    }

    @Test func appLanguage_emptyRemote_removesAndSignals() {
        // Vacío = quitar el override. current="es" → remove.
        let d = PreferenceMergeLogic.decide(
            key: .appLanguageOverride, remote: .string(""), local: .string("es-419"))
        #expect(d == Decision(write: .remove, signal: .language))
    }

    @Test func appLanguage_equal_skips() {
        let d = PreferenceMergeLogic.decide(
            key: .appLanguageOverride, remote: .string("es-419"), local: .string("es-419"))
        #expect(d == .skip)
    }

    @Test func appLanguage_bothEmpty_skips() {
        let d = PreferenceMergeLogic.decide(
            key: .appLanguageOverride, remote: .string(""), local: .string(""))
        #expect(d == .skip)
    }

    @Test func appLanguage_remoteAbsent_skips() {
        let d = PreferenceMergeLogic.decide(
            key: .appLanguageOverride, remote: nil, local: .string("es-419"))
        #expect(d == .skip)
    }

    // MARK: - Taxonomía completa (guardas de conteo/kind)

    @Test func taxonomy_34Keys() {
        #expect(PrefSyncKey.allCases.count == 34)
    }

    @Test func taxonomy_kindMatchesFamily() {
        for key in PrefSyncKey.allCases {
            switch key.family {
            case .stringGuardNonEmpty, .panelPresenceEmptyValid,
                 .onboardingModeNeverDowngrade, .appLanguageOverride:
                #expect(key.kind == .string, "\(key) debe ser .string")
            case .boolPresence:
                #expect(key.kind == .bool, "\(key) debe ser .bool")
            case .intPresence:
                #expect(key.kind == .int, "\(key) debe ser .int")
            }
        }
    }

    @Test func taxonomy_signalsExact() {
        #expect(PrefSyncKey.currencyDisplayFormat.signal == .formatting)
        #expect(PrefSyncKey.decimalPlaces.signal == .formatting)
        #expect(PrefSyncKey.firstWeekday.signal == .weekday)
        #expect(PrefSyncKey.appLanguageOverride.signal == .language)
        #expect(PrefSyncKey.userName.signal == nil)
        #expect(PrefSyncKey.colorfulIcons.signal == nil)
    }
}
