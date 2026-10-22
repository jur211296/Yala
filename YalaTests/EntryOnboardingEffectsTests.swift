//
//  EntryOnboardingEffectsTests.swift
//  YalaTests
//
//  Pin de la regla que separa el ALTA de la RE-ENTRADA: los dos efectos de "primera vez" —la oferta
//  de prueba post-onboarding y el marcador que hace visible la card «Configura tu Yala»— pertenecen
//  al alta y NO a quien vuelve (cambio de móvil, reinstalación, adopt de una cuenta del Modo Nube).
//
//  Mutación que debe dejar esto en rojo: devolver `true` incondicionalmente en cualquiera de las dos
//  funciones — que es exactamente lo que hacía `completeOnboardingAsRestoreSkip` antes del fix.
//

import Foundation
import Testing

@testable import Yala

struct EntryOnboardingEffectsTests {

    // MARK: - Marcador de instalación nueva

    @Test("El alta marca instalación nueva (la card «Configura tu Yala» es suya)")
    func freshInstall_marksNewInstall() {
        #expect(EntryOnboardingEffects.marksNewInstall(.freshInstall) == true)
    }

    @Test("La re-entrada NO marca instalación nueva — quien vuelve no estrena nada")
    func reentry_doesNotMarkNewInstall() {
        #expect(EntryOnboardingEffects.marksNewInstall(.reentry) == false)
    }

    // MARK: - Oferta de prueba

    @Test("El alta de alguien que no es Pro arma la oferta de prueba")
    func freshInstall_nonPro_armsTrial() {
        #expect(EntryOnboardingEffects.armsTrialOffer(.freshInstall, isProUser: false) == true)
    }

    @Test("El alta de alguien que YA es Pro no arma la oferta (invariante previo al fix)")
    func freshInstall_proUser_doesNotArmTrial() {
        #expect(EntryOnboardingEffects.armsTrialOffer(.freshInstall, isProUser: false) == true)
        #expect(EntryOnboardingEffects.armsTrialOffer(.freshInstall, isProUser: true) == false)
    }

    @Test("La re-entrada no arma la oferta de prueba, sea Pro o no")
    func reentry_neverArmsTrial() {
        #expect(EntryOnboardingEffects.armsTrialOffer(.reentry, isProUser: false) == false)
        #expect(EntryOnboardingEffects.armsTrialOffer(.reentry, isProUser: true) == false)
    }

    // MARK: - La tabla entera

    @Test("Los dos efectos son del alta y solo del alta")
    func onlyFreshInstallGetsEitherEffect() {
        for kind in [AppEntryKind.freshInstall, .reentry] {
            let isFresh = (kind == .freshInstall)
            #expect(EntryOnboardingEffects.marksNewInstall(kind) == isFresh)
            #expect(EntryOnboardingEffects.armsTrialOffer(kind, isProUser: false) == isFresh)
        }
    }
}
