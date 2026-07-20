//
//  DestructiveScopeLogicTests.swift
//  YalaTests
//
//  Tabla de la lógica pura de la "hoja de alcance" destructiva (D4, §3.1/§3.3 del estudio
//  MODO-NUBE-GESTION-DATOS-UX). Verifica la ESTRUCTURA del sheet por operación × etiqueta ☁️ × deuda ×
//  huella: 3 filas SIEMPRE (device→cloud→groups) con sus tonos, la etiqueta ☁️ (mata C2), las líneas
//  condicionales (reusando la decisión D5 de `AccountDeletionMessageLogic`), y la acción secundaria.
//
//  Lógica pura sin estado → `@Suite` sin `.serialized` (molde de `CloudSignOutRowLayoutTests`).
//

import Testing
@testable import Yala

@Suite("Hoja de alcance destructiva — lógica de configuración (D4)")
struct DestructiveScopeLogicTests {

    typealias Op = DestructiveScopeLogic.Operation
    typealias Loc = DestructiveScopeLogic.Location
    typealias Tone = DestructiveScopeLogic.Tone
    typealias Line = DestructiveScopeLogic.ExtraLine
    typealias Kind = DestructiveScopeLogic.SecondaryKind

    // MARK: - Etiqueta ☁️ (C2)

    @Test func cloudLabel_cloudMode_isCloudAccount() {
        #expect(DestructiveScopeLogic.cloudLabel(storageMode: .cloud) == .cloudAccount)
    }

    @Test func cloudLabel_icloudMode_isICloud() {
        #expect(DestructiveScopeLogic.cloudLabel(storageMode: .icloud) == .icloud)
    }

    // MARK: - Invariante: SIEMPRE 3 filas en orden device→cloud→groups

    @Test func everyOperation_hasExactlyThreeRows_inCanonicalOrder() {
        for op in Op.allCases {
            for label in [DestructiveScopeLogic.CloudLabel.icloud, .cloudAccount] {
                let m = DestructiveScopeLogic.model(operation: op, cloudLabel: label)
                #expect(m.rows.count == 3, "\(op): debe tener 3 filas")
                #expect(m.rows.map(\.location) == [.device, .cloud, .groups],
                        "\(op): orden de filas incorrecto")
                #expect(m.cloudLabel == label, "\(op): la etiqueta ☁️ debe ser eco del parámetro")
            }
        }
    }

    // MARK: - Invariante: acciones secundarias (steer-away) por operación × deuda

    @Test func secondaryActions_perOperationAndDebt() {
        func expected(_ op: Op, debt: Bool) -> [Kind] {
            switch op {
            case .wipeDataFull:       return debt ? [.viewGroups, .exportBefore] : [.exportBefore]
            case .wipeDataGroupsOnly: return debt ? [.viewGroups] : []
            case .deleteAccountCloud, .deleteAccountGroupsOnly:
                                      return debt ? [.viewGroups] : []
            default:                  return []
            }
        }
        for op in Op.allCases {
            for debt in [false, true] {
                let m = DestructiveScopeLogic.model(operation: op, cloudLabel: .cloudAccount,
                                                    hasOutstandingDebt: debt)
                #expect(m.secondaryActions == expected(op, debt: debt),
                        "\(op) debt=\(debt): secondaryActions inesperadas")
            }
        }
    }

    @Test func exportBefore_onlyForWipeDataFull() {
        // "Exportar antes" (red §m.4) SOLO en Vaciar completo — el wizard personal no aplica al 5a.
        for op in Op.allCases {
            for debt in [false, true] {
                let m = DestructiveScopeLogic.model(operation: op, cloudLabel: .icloud,
                                                    hasOutstandingDebt: debt)
                #expect(m.secondaryActions.contains(.exportBefore) == (op == .wipeDataFull),
                        "\(op): exportBefore solo en wipeDataFull")
            }
        }
    }

    @Test func viewGroups_firstWhenBothPresent_inWipeDataFull() {
        // Con deuda, "Ver mis grupos" va PRIMERO (protege a terceros: saldar antes de destruir).
        let m = DestructiveScopeLogic.model(operation: .wipeDataFull, cloudLabel: .icloud,
                                            hasOutstandingDebt: true)
        #expect(m.secondaryActions == [.viewGroups, .exportBefore])
    }

    @Test func leaveAllGroups_firstWhenCanLeaveAndNoDebt_inWipeDataFull() {
        // D10: sin deuda + canLeaveAllGroups → "También salir de mis grupos" PRIMERO, luego "Exportar antes".
        let m = DestructiveScopeLogic.model(operation: .wipeDataFull, cloudLabel: .icloud,
                                            hasOutstandingDebt: false, canLeaveAllGroups: true)
        #expect(m.secondaryActions == [.leaveAllGroups, .exportBefore])
        // Con deuda, el batch NO se ofrece aunque canLeaveAllGroups sea true (gana "Ver mis grupos").
        let debt = DestructiveScopeLogic.model(operation: .wipeDataFull, cloudLabel: .icloud,
                                               hasOutstandingDebt: true, canLeaveAllGroups: true)
        #expect(debt.secondaryActions == [.viewGroups, .exportBefore])
        // canLeaveAllGroups solo aplica a wipeDataFull (default false en el resto → byte-idéntico).
        let go = DestructiveScopeLogic.model(operation: .wipeDataGroupsOnly, cloudLabel: .icloud,
                                             canLeaveAllGroups: true)
        #expect(!go.secondaryActions.contains(.leaveAllGroups))
    }

    // MARK: - C4: operación de Vaciar según el modo

    @Test func wipeOperation_groupInvite_isGroupsOnly_elseFull() {
        // 5a (group-invite, sin vida personal) → groupsOnly; resto (incl. 5b onboarding completed +
        // sesión backend) → full. La sesión NO es input (no baja el scope).
        #expect(DestructiveScopeLogic.wipeOperation(isGroupInviteMode: true) == .wipeDataGroupsOnly)
        #expect(DestructiveScopeLogic.wipeOperation(isGroupInviteMode: false) == .wipeDataFull)
    }

    // MARK: - Vaciar

    @Test func wipeDataFull_icloud_destroysDeviceAndCloud_preservesGroups_noResidual() {
        let m = DestructiveScopeLogic.model(operation: .wipeDataFull, cloudLabel: .icloud)
        #expect(m.rows.map(\.tone) == [.destructive, .destructive, .preserved])
        #expect(m.hasConservationNote)
        #expect(m.extraLines.isEmpty, "VIVO `.icloud` no lleva línea de residual → byte-idéntico")
        #expect(m.secondaryActions == [.exportBefore], "sin deuda: solo 'Exportar antes'")
    }

    @Test func wipeDataFull_cloud_addsMultiDeviceResidual() {
        let m = DestructiveScopeLogic.model(operation: .wipeDataFull, cloudLabel: .cloudAccount)
        #expect(m.extraLines == [.multiDeviceResidual], "D9: declarar el residual multi-device en `.cloud`")
    }

    @Test func wipeDataGroupsOnly_restoresProfile_preservesGroups_noConservationNote() {
        let m = DestructiveScopeLogic.model(operation: .wipeDataGroupsOnly, cloudLabel: .icloud)
        #expect(m.rows.map(\.tone) == [.destructive, .destructive, .preserved])
        #expect(m.extraLines.isEmpty)
        #expect(!m.hasConservationNote, "5a: sin cuenta/Pro que mencionar; la fila 👥 ya lo dice")
        #expect(m.secondaryActions.isEmpty, "5a sin deuda: sin export (no hay wizard personal)")
    }

    // MARK: - Eliminar cuenta

    @Test func deleteAccountCloud_tones_deviceAndCloudDestructive_groupsNeutral() {
        let m = DestructiveScopeLogic.model(operation: .deleteAccountCloud, cloudLabel: .cloudAccount)
        #expect(m.rows.map(\.tone) == [.destructive, .destructive, .neutral])
        #expect(!m.hasConservationNote)
    }

    @Test func deleteAccountGroupsOnly_deviceIsPreserved() {
        // 5b: el personal en `.icloud` NO se toca; muere la cuenta backend.
        let m = DestructiveScopeLogic.model(operation: .deleteAccountGroupsOnly, cloudLabel: .cloudAccount)
        #expect(m.rows.map(\.tone) == [.preserved, .destructive, .neutral])
    }

    @Test func deleteAccount_extraLines_matchAccountDeletionMessageLogic_minusBase() {
        // La decisión D5 (qué avisos aparecen) vive en `AccountDeletionMessageLogic`; la hoja la reutiliza
        // descartando `.base`. Barrido exhaustivo de la matriz.
        for isCloud in [true, false] {
            let op: Op = isCloud ? .deleteAccountCloud : .deleteAccountGroupsOnly
            for debt in [true, false] {
                for footprint in [true, false] {
                    let m = DestructiveScopeLogic.model(
                        operation: op, cloudLabel: .cloudAccount,
                        hasOutstandingDebt: debt, hasLegacyCloudKitFootprint: footprint)
                    let expected = AccountDeletionMessageLogic.lines(
                        isCloud: isCloud, hasOutstandingDebt: debt, hasLegacyCloudKitFootprint: footprint)
                        .compactMap { line -> Line? in
                            switch line {
                            case .base:            return nil
                            case .debtWarning:     return .debtWarning
                            case .crossRefer:      return .crossRefer
                            case .frozenICloud:    return .frozenICloud
                            case .legacyFootprint: return .legacyFootprint
                            }
                        }
                    #expect(m.extraLines == expected,
                            "isCloud=\(isCloud) debt=\(debt) footprint=\(footprint): extraLines != D5 lines - base")
                    // Invariantes concretos de la reutilización D5:
                    #expect(m.extraLines.contains(.crossRefer), "el desvío cruzado siempre presente")
                    #expect(m.extraLines.contains(.debtWarning) == debt)
                    #expect(m.extraLines.contains(.legacyFootprint) == footprint)
                    #expect(m.extraLines.contains(.frozenICloud) == isCloud,
                            "la copia iCloud congelada SOLO en `.cloud`")
                    #expect(m.secondaryActions == (debt ? [.viewGroups] : []),
                            "eliminar-cuenta: 'Ver mis grupos' SOLO con deuda, sin export")
                }
            }
        }
    }

    // MARK: - Cerrar sesión / Salir de Yala

    @Test func signOutPrivate_everythingPreserved() {
        let m = DestructiveScopeLogic.model(operation: .signOutPrivate, cloudLabel: .icloud)
        #expect(m.rows.map(\.tone) == [.preserved, .preserved, .preserved])
        #expect(m.hasConservationNote)
        #expect(m.extraLines.isEmpty)
    }

    @Test func signOutCloud_deviceNeutral_cloudAndGroupsPreserved() {
        let m = DestructiveScopeLogic.model(operation: .signOutCloud, cloudLabel: .cloudAccount)
        #expect(m.rows.map(\.tone) == [.neutral, .preserved, .preserved])
    }

    @Test func signOutSecondary_deviceNeutral_ownerDataPreserved() {
        let m = DestructiveScopeLogic.model(operation: .signOutSecondary, cloudLabel: .cloudAccount)
        #expect(m.rows.map(\.tone) == [.neutral, .preserved, .preserved])
        #expect(m.hasConservationNote)
    }

    @Test func signOutGroupsOnly_personalPreserved_groupsNeutral() {
        let m = DestructiveScopeLogic.model(operation: .signOutGroupsOnly, cloudLabel: .icloud)
        #expect(m.rows.map(\.tone) == [.preserved, .preserved, .neutral])
    }

    @Test func exitYalaLegacy_everythingPreserved() {
        let m = DestructiveScopeLogic.model(operation: .exitYalaLegacy, cloudLabel: .icloud)
        #expect(m.rows.map(\.tone) == [.preserved, .preserved, .preserved])
    }

    @Test func exitYalaGroups_personalPreserved_groupsNeutral() {
        let m = DestructiveScopeLogic.model(operation: .exitYalaGroups, cloudLabel: .icloud)
        #expect(m.rows.map(\.tone) == [.preserved, .preserved, .neutral])
    }

    // MARK: - Borrar copia congelada

    @Test func deleteFrozenCopy_cloudDestructive_deviceAndGroupsPreserved() {
        let m = DestructiveScopeLogic.model(operation: .deleteFrozenCopy, cloudLabel: .icloud)
        #expect(m.rows.map(\.tone) == [.preserved, .destructive, .preserved])
        #expect(m.hasConservationNote)
        #expect(m.extraLines.isEmpty)
        #expect(m.secondaryActions.isEmpty)
    }
}
