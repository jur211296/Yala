//
//  OnboardingPurposeSelectionLogicTests.swift
//  YalaTests
//
//  Tabla del selector de propósito del onboarding (molde OnboardingGroupsPurposeGateLogicTests,
//  que es el resultado de `9c66c528`).
//
//  Dos mitades y ninguna cubre a la otra:
//    1. La DECISIÓN — qué card se marca en cada uno de los CUATRO modos, y qué hace tocar
//       «Llevar el control» desde cada uno.
//    2. El CABLEADO — source-scan de que `OnboardingView` deriva las tres marcas y el closure
//       de esta lógica. Sin él, devolver el call-site a `isSelected: !expensesOnlyMode` /
//       `if expensesOnlyMode` reintroduce el bug ENTERO con toda la tabla en VERDE: el predicado
//       vive dentro del `body`, donde ningún unitario llega (la lección de `965a4d86`).
//
//  Y por qué tampoco basta el XCUITest del área (`OnboardingGroupsOnlyGuardUITests`): `binaryCard`
//  solo expone `accessibilityIdentifier` — el estado de selección es un `stroke`, no un trait de
//  accesibilidad — así que desde XCUITest la MARCA no es afirmable hoy. Ese test cubre la otra
//  mitad del defecto, el tap de vuelta, que sí es observable por el paso al que lleva.
//

import Foundation
import Testing

@testable import Yala

@Suite("OnboardingPurposeSelectionLogic · el selector de propósito del onboarding")
struct OnboardingPurposeSelectionLogicTests {

    struct Caso: Sendable {
        let modo: OnboardingUsageMode
        let cardMarcada: OnboardingPurposeCard
        /// Si tocar «Llevar el control de mi dinero» debe cambiar el modo.
        let tocarControlCambia: Bool
        let porque: String
    }

    /// Los CUATRO modos, no tres. `.dayToDay` no es teórico: `OnboardingView` lo escribe en el
    /// paso `.accounts` («Una sola cuenta»), ese paso no se salta con ese modo y el flujo tiene
    /// botón atrás hasta `.purpose` — más la migración legacy del `.task`.
    static let tabla: [Caso] = [
        Caso(modo: .fullControl, cardMarcada: .control, tocarControlCambia: false,
             porque: "el default del flujo: solo «Llevar el control» marcada"),
        Caso(modo: .dayToDay, cardMarcada: .control, tocarControlCambia: false,
             porque: "«una sola cuenta» es llevar el control con una cuenta, no otro propósito"),
        Caso(modo: .expensesOnly, cardMarcada: .expenses, tocarControlCambia: true,
             porque: "solo anotar gastos es un propósito distinto; volver al control tiene que cambiar el modo"),
        Caso(modo: .groupsOnly, cardMarcada: .groups, tocarControlCambia: true,
             porque: "LA CELDA DEL BUG: con solo-grupos se marcaba ADEMÁS «Llevar el control», y tocarla no hacía nada"),
    ]

    @Test(arguments: tabla)
    func tablaCompleta(_ caso: Caso) {
        #expect(
            OnboardingPurposeSelectionLogic.selectedCard(for: caso.modo) == caso.cardMarcada,
            "modo=\(caso.modo) → se esperaba \(caso.cardMarcada) marcada: \(caso.porque)"
        )
        #expect(
            OnboardingPurposeSelectionLogic.shouldSelectFullControl(from: caso.modo) == caso.tocarControlCambia,
            """
            modo=\(caso.modo) → tocar «Llevar el control» debía \
            \(caso.tocarControlCambia ? "CAMBIAR" : "no cambiar") el modo: \(caso.porque)
            """
        )
    }

    /// La invariante que el bug rompía por los dos lados a la vez: EXACTAMENTE una card marcada.
    /// Con `.groupsOnly` había dos; con el arreglo ingenuo (`== .fullControl`) `.dayToDay` habría
    /// quedado con cero. Recorre `allCases` para que añadir una card cuarta sin decidir su celda
    /// caiga aquí.
    @Test(arguments: tabla)
    func exactamenteUnaCardMarcadaPorModo(_ caso: Caso) {
        let marcadas = OnboardingPurposeCard.allCases.filter {
            OnboardingPurposeSelectionLogic.isSelected($0, mode: caso.modo)
        }
        #expect(marcadas == [caso.cardMarcada],
                "modo=\(caso.modo) → cards marcadas \(marcadas), se esperaba solo [\(caso.cardMarcada)]")
    }

    /// MITAD 1, nombrada aparte: con «Dividir gastos con amigos» elegido, «Llevar el control» NO
    /// puede pintarse marcada. Era el síntoma visible — dos propósitos marcados en el primer
    /// contacto con la app de toda la población born-cloud, que desde `9c66c528` sí alcanza este
    /// estado (antes el muro iCloud se lo cerraba).
    @Test func conSoloGrupos_noSeMarcaLlevarElControl() {
        #expect(
            OnboardingPurposeSelectionLogic.isSelected(.control, mode: .groupsOnly) == false,
            "Volvieron las dos cards marcadas a la vez en el paso Propósito."
        )
        #expect(OnboardingPurposeSelectionLogic.isSelected(.groups, mode: .groupsOnly))
    }

    /// MITAD 2, la que no es cosmética: el tap de vuelta. Con `.groupsOnly` activo, tocar «Llevar
    /// el control» tiene que cambiar el modo. Con el predicado viejo (`expensesOnlyMode`) el tap
    /// se perdía y el usuario solo podía volver pasando por «Solo anotar gastos» — sin motivo
    /// para sospecharlo, porque la card ya se pintaba marcada.
    @Test func conSoloGrupos_tocarLlevarElControl_surteEfecto() {
        #expect(
            OnboardingPurposeSelectionLogic.shouldSelectFullControl(from: .groupsOnly),
            "El tap de «Llevar el control» volvió a morir con solo-grupos elegido."
        )
    }

    /// El caso que el arreglo ingenuo habría roto, y que no estaba en el reporte del chip:
    /// `.dayToDay` marca la card de control (no cero cards) y tocarla NO reasigna `.fullControl`
    /// — reasignar le cambiaría en silencio al usuario la respuesta de «Una sola cuenta» a
    /// «Varias cuentas» en el paso siguiente.
    @Test func conUnaSolaCuenta_seMarcaControl_yElTapNoReasigna() {
        #expect(OnboardingPurposeSelectionLogic.isSelected(.control, mode: .dayToDay),
                "Con «una sola cuenta» elegida el paso Propósito se quedaría sin ninguna card marcada.")
        #expect(
            OnboardingPurposeSelectionLogic.shouldSelectFullControl(from: .dayToDay) == false,
            "Tocar «Llevar el control» desde «una sola cuenta» le cambiaría la elección de cuentas sin decírselo."
        )
    }

    /// La causa RAÍZ, pinneada como invariante y no como celda: marca y tap tienen que salir del
    /// mismo predicado. Que fueran dos distintos es todo el defecto.
    @Test(arguments: tabla)
    func laMarcaYElTapNuncaSeContradicen(_ caso: Caso) {
        #expect(
            OnboardingPurposeSelectionLogic.isSelected(.control, mode: caso.modo)
                != OnboardingPurposeSelectionLogic.shouldSelectFullControl(from: caso.modo),
            "modo=\(caso.modo): la card de control se pinta y se comporta con predicados distintos otra vez."
        )
    }

    /// El pin del CALL SITE. Los conteos no son decoración: sin ellos, un método renombrado o un
    /// fichero movido dejarían al escáner sin encontrar nada y la suite pasaría en verde sin
    /// comprobar nada — la familia de "Executed 0 tests".
    @Test func onboardingViewDerivaLasTresMarcasYElTapDeLaLogica() throws {
        let onboardingView = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appending(path: "Yala/App/Views/Onboarding/OnboardingView.swift")

        // Sin las líneas de comentario: el porqué del cableado se explica AHÍ nombrando la lógica
        // y las formas viejas, y contar prosa haría que documentar el invariante lo rompiera.
        let source = try String(contentsOf: onboardingView, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        func veces(_ needle: String) -> Int {
            source.components(separatedBy: needle).count - 1
        }

        #expect(veces("OnboardingPurposeSelectionLogic.isSelected(") == 3,
                "Se esperaban las 3 cards del selector derivando su marca de la lógica pura.")

        for card in ["control", "expenses", "groups"] {
            #expect(
                veces("OnboardingPurposeSelectionLogic.isSelected(.\(card), mode: selectedUsageMode)") == 1,
                """
                La card `onboarding_purpose_\(card)` ya no deriva su marca de la lógica pura, o no le pasa \
                el modo VIVO. Un predicado propio ahí devuelve el selector de tres cards expresado con \
                booleanos, y las celdas de la tabla siguen en VERDE.
                """
            )
        }

        #expect(
            veces("OnboardingPurposeSelectionLogic.shouldSelectFullControl(from: selectedUsageMode)") == 1,
            """
            El closure de «Llevar el control» ya no consulta la lógica pura. Ésta es la mitad que NO es \
            cosmética: con `if expensesOnlyMode` el tap se pierde entero cuando el modo es `.groupsOnly`.
            """
        )

        // Las tres formas EXACTAS del bug, prohibidas por separado. `wantsSeparateAccounts` (el
        // otro selector binario del flujo, el paso `.accounts`) no colisiona con ninguna.
        for forma in ["isSelected: !expensesOnlyMode",
                      "isSelected: expensesOnlyMode",
                      "isSelected: groupsOnlyMode"] {
            #expect(veces(forma) == 0,
                    "`\(forma)` volvió al selector de propósito: es una de las tres formas del bug de C5.")
        }
    }
}
