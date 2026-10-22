//
//  OnboardingPurposeSelectionLogicTests.swift
//  YalaTests
//
//  Tabla del selector de propósito del onboarding.
//
//  Dos mitades y ninguna cubre a la otra:
//    1. La DECISIÓN — qué card se marca en cada uno de los TRES modos, y qué hace tocar
//       «Llevar el control» desde cada uno.
//    2. El CABLEADO — source-scan de que `OnboardingView` deriva las dos marcas y el closure
//       de esta lógica. Sin él, devolver el call-site a `isSelected: !expensesOnlyMode` /
//       `if expensesOnlyMode` reintroduce la forma del bug de C5 con toda la tabla en VERDE: el
//       predicado vive dentro del `body`, donde ningún unitario llega (la lección de `965a4d86`).
//
//  Y por qué tampoco basta el XCUITest del área (`OnboardingPurposeStepUITests`): `binaryCard`
//  solo expone `accessibilityIdentifier` — el estado de selección es un `stroke`, no un trait de
//  accesibilidad — así que desde XCUITest la MARCA no es afirmable hoy. Ese test cubre lo que sí
//  es observable: qué cards hay, y el tap de vuelta por el paso al que lleva.
//
//  DESDE EL 2026-09-10 son dos cards (ADR 2026-09-09 §7): «Dividir gastos con amigos» se retiró
//  junto con su modo `.groupsOnly`, que era la celda del bug de C5. La tabla conserva la forma
//  del bug que sigue siendo posible: el predicado de igualdad, que deja a `.dayToDay` sin card.
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

    /// Los TRES modos, no dos. `.dayToDay` no es teórico: `OnboardingView` lo escribe en el
    /// paso `.accounts` («Una sola cuenta»), ese paso no se salta con ese modo y el flujo tiene
    /// botón atrás hasta `.purpose` — más la migración legacy del `.task`.
    static let tabla: [Caso] = [
        Caso(modo: .fullControl, cardMarcada: .control, tocarControlCambia: false,
             porque: "el default del flujo: solo «Llevar el control» marcada"),
        Caso(modo: .dayToDay, cardMarcada: .control, tocarControlCambia: false,
             porque: "«una sola cuenta» es llevar el control con una cuenta, no otro propósito"),
        Caso(modo: .expensesOnly, cardMarcada: .expenses, tocarControlCambia: true,
             porque: "solo anotar gastos es un propósito distinto; volver al control tiene que cambiar el modo"),
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

    /// La invariante que el bug de C5 rompía por los dos lados a la vez: EXACTAMENTE una card
    /// marcada. Con el `.groupsOnly` de entonces había dos; con el arreglo ingenuo (`== .fullControl`)
    /// `.dayToDay` se quedaría con cero. Recorre `allCases` para que añadir una card sin decidir su
    /// celda caiga aquí.
    @Test(arguments: tabla)
    func exactamenteUnaCardMarcadaPorModo(_ caso: Caso) {
        let marcadas = OnboardingPurposeCard.allCases.filter {
            OnboardingPurposeSelectionLogic.isSelected($0, mode: caso.modo)
        }
        #expect(marcadas == [caso.cardMarcada],
                "modo=\(caso.modo) → cards marcadas \(marcadas), se esperaba solo [\(caso.cardMarcada)]")
    }

    /// El criterio del paso 7 del rediseño, a nivel de tipo: el paso ofrece EXACTAMENTE dos
    /// propósitos. Solo-grupos es una sesión que se abre desde el Welcome («Vengo por un grupo»), no
    /// un propósito de quien ya eligió llevar sus finanzas (ADR 2026-09-09 §7). Una card nueva cae
    /// aquí antes que en el XCUITest, y obliga a decidir su celda en la tabla de arriba.
    @Test func elPasoOfreceDosPropositos() {
        #expect(OnboardingPurposeCard.allCases == [.control, .expenses],
                "El paso Propósito volvió a ofrecer otra card: \(OnboardingPurposeCard.allCases).")
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
    @Test func onboardingViewDerivaLasDosMarcasYElTapDeLaLogica() throws {
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

        #expect(veces("OnboardingPurposeSelectionLogic.isSelected(") == 2,
                "Se esperaban las 2 cards del selector derivando su marca de la lógica pura.")

        for card in ["control", "expenses"] {
            #expect(
                veces("OnboardingPurposeSelectionLogic.isSelected(.\(card), mode: selectedUsageMode)") == 1,
                """
                La card `onboarding_purpose_\(card)` ya no deriva su marca de la lógica pura, o no le pasa \
                el modo VIVO. Un predicado propio ahí devuelve el selector expresado con booleanos, y las \
                celdas de la tabla siguen en VERDE.
                """
            )
        }

        // Las cards que PINTA la vista, contadas por su identificador: el enum de arriba puede tener
        // dos casos y la vista una tercera card cableada a mano con otro modo.
        #expect(veces("accessibilityId: \"onboarding_purpose_") == 2, """
            El paso Propósito pinta un número de cards distinto de dos. «Solo grupos» se retiró de aquí \
            (ADR 2026-09-09 §7): se entra por «Vengo por un grupo» en el Welcome.
            """)

        // Y contadas en el CUERPO del paso, no solo por prefijo de id: una card nueva con otro id también
        // tiene que caer.
        let inicio = try #require(source.range(of: "private var purposeStep: some View {"),
                                  "`purposeStep` desapareció o cambió de firma")
        let fin = try #require(source.range(of: "private var accountsStep: some View {",
                                            range: inicio.upperBound..<source.endIndex),
                               "`accountsStep` desapareció o cambió de firma")
        let cuerpo = source[inicio.upperBound..<fin.lowerBound]
        #expect(cuerpo.components(separatedBy: "binaryCard(").count - 1 == 2,
                "El cuerpo de `purposeStep` construye un número de cards distinto de dos.")

        #expect(
            veces("OnboardingPurposeSelectionLogic.shouldSelectFullControl(from: selectedUsageMode)") == 1,
            """
            El closure de «Llevar el control» ya no consulta la lógica pura. Ésta es la mitad que NO es \
            cosmética: con `if expensesOnlyMode` la marca y el tap vuelven a salir de predicados distintos.
            """
        )

        // Las dos formas EXACTAS del bug de C5 que siguen siendo escribibles, prohibidas por separado.
        // `wantsSeparateAccounts` (el otro selector binario del flujo, el paso `.accounts`) no
        // colisiona con ninguna.
        for forma in ["isSelected: !expensesOnlyMode",
                      "isSelected: expensesOnlyMode"] {
            #expect(veces(forma) == 0,
                    "`\(forma)` volvió al selector de propósito: es una de las formas del bug de C5.")
        }
    }
}
