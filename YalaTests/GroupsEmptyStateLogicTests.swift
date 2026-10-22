//
//  GroupsEmptyStateLogicTests.swift
//  YalaTests
//
//  Tabla del empty state del tab Grupos (H-2026-07-18-7, ampliada a CINCO casos en C2). Pure-logic sin
//  SwiftData/CloudKit/UI.
//

import Testing

@testable import Yala

@Suite("GroupsEmptyStateLogic · empty state del tab Grupos")
struct GroupsEmptyStateLogicTests {

    typealias Kind = GroupsEmptyStateLogic.Kind

    /// Estado COMPLETO por defecto: educativo visto, cuenta anterior, sesión viva y consent. Cada test
    /// apaga solo la señal que le interesa, que es lo que hace legible la precedencia.
    private func decide(flagOn: Bool = true,
                        educational: Bool = true,
                        hadSessionEver: Bool = true,
                        hasSession: Bool = true,
                        consent: Bool = true) -> Kind {
        GroupsEmptyStateLogic.decide(
            flagOn: flagOn, hasSeenEducational: educational,
            hadSessionEver: hadSessionEver, hasSession: hasSession, isConsented: consent)
    }

    // MARK: - Flag OFF → SIEMPRE standard (byte-idéntico, pase lo que pase con el resto)

    /// Las 16 celdas de `flagOn: false`. Es la no-regresión del shipping DARK: con el canal apagado Grupos
    /// sigue en CloudKit y el render no puede cambiar.
    @Test func flagOff_alwaysStandard_regardlessOfEverythingElse() {
        for educational in [false, true] {
            for hadEver in [false, true] {
                for session in [false, true] {
                    for consent in [false, true] {
                        #expect(decide(flagOn: false, educational: educational, hadSessionEver: hadEver,
                                       hasSession: session, consent: consent) == .standard)
                    }
                }
            }
        }
    }

    // MARK: - Precedencia: educativo → identidad → consent → estándar

    @Test func flagOn_neverSawEducational_needsEducational() {
        #expect(decide(educational: false) == .needsEducational)
        // Es el PRIMER término: gana incluso sin sesión y sin consent.
        #expect(decide(educational: false, hasSession: false, consent: false) == .needsEducational)
    }

    // MARK: - Las dos mitades de «sin sesión», que antes de C2 eran una sola y mentía

    /// El caso original H-2026-07-18-7, ahora acotado a quien es verdad.
    @Test func flagOn_noSession_butHadOneBefore_signInToView() {
        #expect(decide(hasSession: false) == .signInToView)
    }

    /// **La celda del chip.** Antes de C2 esta persona leía «Tus grupos están en tu cuenta · Inicia
    /// sesión»: no tiene grupos esperando en ninguna parte, y la cuenta hay que CREARLA.
    @Test func flagOn_noSession_neverHadOne_createAccount() {
        #expect(decide(hadSessionEver: false, hasSession: false) == .createAccount)
    }

    /// La otra dirección de la misma mutación: sin ESTE test, un `decide` degenerado a `.createAccount`
    /// para todo el que no tiene sesión pasaría desapercibido.
    @Test func elLatchEsLoQueSeparaLosDosCopys() {
        #expect(decide(hadSessionEver: true, hasSession: false) != decide(hadSessionEver: false, hasSession: false),
                "el empty state dejó de distinguir «vuelve a tu cuenta» de «crea una cuenta»")
    }

    // MARK: - Sesión viva

    @Test func flagOn_sessionWithoutConsent_needsConsent() {
        #expect(decide(consent: false) == .needsConsent)
    }

    @Test func flagOn_everythingReady_standard() {
        #expect(decide() == .standard)
    }

    // MARK: - Dominio completo

    /// Las 32 celdas decididas, para que añadir un `Kind` sin decidir su celda no pase en verde por
    /// omisión. Y la aserción que carga el peso: **el empty state espeja la precedencia de
    /// `GroupsGateLogic`** — lo que ANUNCIA tiene que ser lo que el tap va a PEDIR.
    @Test("las 32 celdas están decididas y la precedencia espeja la de la puerta")
    func fullDomain_isExhaustive_andMirrorsTheGate() {
        for educational in [false, true] {
            for hadEver in [false, true] {
                for session in [false, true] {
                    for consent in [false, true] {
                        let kind = decide(educational: educational, hadSessionEver: hadEver,
                                          hasSession: session, consent: consent)
                        // El educativo primero, igual que en la puerta.
                        if !educational { #expect(kind == .needsEducational) }
                        // `.standard` solo cuando NO falta nada: si sale con alguna señal apagada, el tab
                        // ofrece «crear grupo» y el tap acaba en una pantalla que el usuario no esperaba.
                        if kind == .standard {
                            #expect(educational && session && consent,
                                    "`.standard` con algo pendiente: edu=\(educational) ses=\(session) con=\(consent)")
                        }
                    }
                }
            }
        }
    }
}
