//
//  CrossAccountEntryGuardLogicTests.swift
//  YalaTests
//
//  Matriz COMPLETA del guard (16 combos). Con el flag OFF la tabla reproduce EXACTAMENTE
//  la v1 (DARK); la salida secundaria existe SOLO en la celda (datos ajenos + exists + flag).
//

import Foundation
import Testing

@testable import Yala

@Suite("Guard cross-cuenta del sign-in en Welcome (F0-C + M1)")
struct CrossAccountEntryGuardLogicTests {

    @Test
    func cleanDevice_proceeds_always() {
        // Sin datos locales → adopt clásico, JAMÁS secundaria (aunque el flag esté ON:
        // el device limpio no necesita aislamiento).
        for claim in [true, false] {
            for exists in [true, false] {
                for flag in [true, false] {
                    #expect(CrossAccountEntryGuardLogic.decide(
                        hasLocalData: false, sameAccountClaimExists: claim,
                        accountExists: exists, secondarySessionEnabled: flag
                    ) == .proceed)
                }
            }
        }
    }

    @Test
    func localData_sameAccount_proceeds_evenWithFlagOn() {
        // Re-entrada de la MISMA cuenta: el claim-store sobrevive el sign-out a propósito.
        for exists in [true, false] {
            for flag in [true, false] {
                #expect(CrossAccountEntryGuardLogic.decide(
                    hasLocalData: true, sameAccountClaimExists: true,
                    accountExists: exists, secondarySessionEnabled: flag
                ) == .proceed)
            }
        }
    }

    @Test
    func localData_foreignAccount_flagOff_blocks_exactlyAsV1() {
        // DARK: con el flag apagado, la tabla es EXACTAMENTE la de v1 (caso Pia bloqueado).
        for exists in [true, false] {
            #expect(CrossAccountEntryGuardLogic.decide(
                hasLocalData: true, sameAccountClaimExists: false,
                accountExists: exists, secondarySessionEnabled: false
            ) == .blockedForeignData)
        }
    }

    @Test
    func localData_foreignAccount_flagOn_existsTrue_proceedsSecondary() {
        // LA celda M1: datos ajenos + cuenta existente + feature encendido → secundaria.
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: true, sameAccountClaimExists: false,
            accountExists: true, secondarySessionEnabled: true
        ) == .proceedSecondarySession)
    }

    @Test
    func localData_foreignAccount_flagOn_existsFalse_stillBlocks() {
        // Sin cuenta existente NO hay secundaria (v1 solo returningUser — born-cloud de
        // invitado diferido a v1.1, decisión 6): se bloquea como siempre.
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: true, sameAccountClaimExists: false,
            accountExists: false, secondarySessionEnabled: true
        ) == .blockedForeignData)
    }
}

@Suite("SecondaryHydrationLogic · visibilidad del banner (M1)")
struct SecondaryHydrationLogicTests {

    @Test func table() {
        // Solo (secundaria && sin primer pull) muestra el banner.
        #expect(SecondaryHydrationLogic.showBanner(secondaryActive: true, firstPullCompleted: false))
        #expect(!SecondaryHydrationLogic.showBanner(secondaryActive: true, firstPullCompleted: true))
        #expect(!SecondaryHydrationLogic.showBanner(secondaryActive: false, firstPullCompleted: false))
        #expect(!SecondaryHydrationLogic.showBanner(secondaryActive: false, firstPullCompleted: true))
    }
}

@Suite("SecondaryEntryLogic · orden de escrituras (M1)")
struct SecondaryEntryLogicTests {

    @Test
    func begin_executesStepsInOrder_claimDescriptorFlags() {
        // El ORDEN es kill-safety: claim ANTES del descriptor (un descriptor sin claim
        // bloquearía la hidratación en el guard P6; un claim huérfano es inerte) y flags
        // al final (la ventana 2→3 la sana el healing del boot).
        var events: [String] = []
        SecondaryEntryLogic.begin(
            userID: "guest-1",
            recordClaim: { events.append("claim:\($0)") },
            activateDescriptor: { events.append("descriptor:\($0)") },
            markOnboardingFlags: { events.append("flags") })
        #expect(events == ["claim:guest-1", "descriptor:guest-1", "flags"])
    }
}
