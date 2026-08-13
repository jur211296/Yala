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

/// El banner de «Descargando tus datos…» cubría SOLO a la invitada, y su propio docblock nombraba el
/// daño que evita: «el store nace VACÍO […] vería una app en cero sin explicación». **Tras el
/// relanzamiento del adopt, el store personal del DUEÑO nace igual de vacío** y se puebla con el pull
/// desde el cursor 0 — mismo hecho, misma pantalla en blanco, y el primer término del gate lo excluía.
///
/// El gate nuevo lee el MUNDO y no el camino: se ve vacío + el motor está hidratando. Eso hace que el
/// banner llegue a quien vuelve sin tener que enumerar por qué ruta llegó.
@Suite("SecondaryHydrationLogic · visibilidad del banner")
struct SecondaryHydrationLogicTests {

    @Test("la invitada: su store SIEMPRE nace vacío, no hace falta mirar nada más")
    func secondarySession() {
        #expect(SecondaryHydrationLogic.showBanner(
            secondaryActive: true, firstPullCompleted: false,
            cloudEngineActive: false, storeLooksEmpty: false))
        #expect(!SecondaryHydrationLogic.showBanner(
            secondaryActive: true, firstPullCompleted: true,
            cloudEngineActive: false, storeLooksEmpty: true))
    }

    /// LA aserción del ticket de re-entrada: el dueño que acaba de adoptar y relanzar.
    @Test("el dueño que vuelve, con el store aún vacío y el motor sin cerrar su primer pull")
    func returningOwnerIsCovered() {
        #expect(SecondaryHydrationLogic.showBanner(
            secondaryActive: false, firstPullCompleted: false,
            cloudEngineActive: true, storeLooksEmpty: true), """
            Quien vuelve en un móvil nuevo sigue viendo la app vacía SIN explicación: es el mismo \
            hecho que el banner ya cubría para la invitada, por la otra puerta.
            """)
    }

    /// Los dos falsos positivos que el gate tiene que seguir evitando: el usuario con sus datos ya
    /// bajados (que no está esperando nada) y el que ni siquiera tiene motor de nube.
    @Test("no sale para quien ya tiene datos ni para quien no tiene motor")
    func noFalsePositives() {
        #expect(!SecondaryHydrationLogic.showBanner(
            secondaryActive: false, firstPullCompleted: false,
            cloudEngineActive: true, storeLooksEmpty: false),
            "con datos en pantalla, «descargando tus datos» es ruido")
        #expect(!SecondaryHydrationLogic.showBanner(
            secondaryActive: false, firstPullCompleted: false,
            cloudEngineActive: false, storeLooksEmpty: true),
            "sin motor de nube no hay ninguna descarga en curso que explicar")
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
