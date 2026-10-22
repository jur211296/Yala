//
//  FXPnLWiringTests.swift
//  YalaTests
//
//  Que las decisiones que sostienen la card de ganancia/pérdida cambiaria sigan CABLEADAS.
//
//  Mismo compromiso —y la misma justificación— que `ApproximateMarkWiringTests`: hay cosas aquí que
//  se pueden revertir dejando la suite entera en verde, porque no cambian ningún resultado
//  calculable sin montar una pantalla. Este archivo fija el fuente. Es más débil que un test de
//  comportamiento y se elige a conciencia.
//
//  Cada caso corresponde a un defecto REAL que tuvo esta feature antes de llegar. No son hipótesis.
//

import Foundation
import Testing

@testable import Yala

@Suite("Cableado de la card de FX P&L (source-scan)")
struct FXPnLWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    // MARK: - La marca de aproximado

    @Test("La card pasa la marca al total")
    func cardPassesTheMark() throws {
        let src = try Self.source("Yala/App/Views/Panel/FXPnLCard.swift")
        #expect(
            src.contains("isEstimate: summary.isApproximate"),
            """
            El número de la card agrega TODAS las divisas: si alguna se convirtió con una tasa que no
            era la de hoy, el total no puede presentarse como exacto.
            """
        )
    }

    @Test("La hoja de detalle marca el total Y cada fila con SU calidad")
    func sheetMarksTotalAndEachRow() throws {
        let src = try Self.source("Yala/App/Views/Panel/Sheets/FXPnLDetailSheet.swift")
        #expect(
            src.contains("isEstimate: summary.isApproximate"),
            "el total de la hoja es el mismo número que el de la card y lleva la misma marca"
        )
        #expect(
            src.contains("isEstimate: row.isApproximate"),
            """
            Y cada fila la SUYA. Las filas suman al total: si el total lleva «≈» y las filas no, el
            usuario suma, le cuadra, y concluye que el «≈» es un adorno. Marcar todas las filas
            cuando sólo una divisa es aproximada erosiona la marca por el otro lado.
            """
        )
    }

    @Test("El cálculo recoge las DOS vías de la marca, no sólo la del converter")
    func logicCollectsBothSignals() throws {
        let src = try Self.source("Yala/App/Logic/FXPnLLogic.swift")
        #expect(
            src.contains("tx.isExchangeRateProvisional"),
            """
            La rama GUARDADA. El coste base sale de `amountInPreferredCurrency`, y lo que sabe si
            aquella tasa era la del día es el flag de la transacción. Sin esta vía, una transacción
            sellada con la tabla estática produce un P&L inventado y lo presenta como exacto —
            medido: +38 % de ganancia salida de una tabla hardcodeada.
            """
        )
        #expect(
            src.contains("outcome.quality.isExact"),
            "La rama VIVA: el TC de hoy sale del converter y su calidad viene en `RateQuality`."
        )
    }

    @Test("La card no inventa un rótulo paralelo al «≈»")
    func cardDoesNotInventASecondBadge() throws {
        let src = try Self.source("Yala/App/Views/Panel/FXPnLCard.swift")
        #expect(
            !src.contains("estimatedRate"),
            """
            `.claude/rules/currency-fx.md`: «El glifo es `≈` y no lleva copy nuevo … No inventes un
            rótulo paralelo ni una key localizada». Una cápsula «Aproximado» junto al «≈» hace que la
            misma condición se señale con dos vocabularios y el usuario deduzca que son dos avisos.
            """
        )
    }

    // MARK: - El coste base

    @Test("Los traspasos entre cuentas propias no entran en el coste")
    func transfersAreExcludedFromCostBasis() throws {
        let src = try Self.source("Yala/App/Logic/FXPnLLogic.swift")
        #expect(
            src.contains("TransactionItem.adjustmentTypeTransfer"),
            """
            Un traspaso no compra ni vende divisa: mueve la misma de sitio. Sus dos patas llevan el
            TC del día del traspaso, así que dejarlas entrar reescribe el coste de un dinero que el
            usuario no ha tocado — medido: +300 se convertía en +33 por mover de bolsillo.
            """
        )
    }

    @Test("El snapshot sellado contra otra moneda preferida se RECONVIERTE, no se descarta")
    func staleSnapshotIsReconverted() throws {
        let src = try Self.source("Yala/App/Logic/FXPnLLogic.swift")
        #expect(
            src.contains("converter.convertChecked("),
            """
            Los once calculadores del repo que leen `amountInPreferredCurrency` tienen un `else` que
            reconvierte con la tasa de aquel día (`BalanceHelper:46`, `CashFlowCalculator:90`).
            Descartar la transacción sesga la muestra hacia las más antiguas o llegadas de otro
            aparato — es decir, hacia otro momento del tipo de cambio.
            """
        )
    }

    // MARK: - Qué explica la card

    @Test("La frase habla de la divisa que movió el número, no de la más grande")
    func dominantIsChosenByPnL() throws {
        let src = try Self.source("Yala/App/Logic/FXPnLLogic.swift")
        let range = try #require(src.range(of: "var dominant:"))
        let scope = String(src[range.lowerBound...].prefix(200))
        #expect(
            scope.contains("abs($0.pnl)"),
            """
            Elegirla por exposición produce una tarjeta que se contradice: con 10.000 USD planos y
            1.000.000 ARS caídos, el titular dice «Pérdida» y la frase de debajo «tus dólares valen
            hoy un 0 % más».
            """
        )
    }

    @Test("El umbral se mide contra la exposición, no contra el balance")
    func thresholdUsesExposedBase() throws {
        let src = try Self.source("Yala/App/Logic/FXPnLLogic.swift")
        let range = try #require(src.range(of: "static func shouldPresent"))
        let scope = String(src[range.lowerBound...].prefix(400))
        #expect(
            scope.contains("summary.exposedBase"),
            """
            Con el balance de denominador la regla degenera justo donde debía filtrar: un saldo
            cercano a cero, o posiciones que se cancelan, hacen que el 0,5 % sea ~0 y entonces
            cualquier céntimo pasa y la card no se va nunca.
            """
        )
    }

    // MARK: - Dónde vive la condición

    @Test("La condición de visibilidad vive DENTRO de la card")
    func visibilityGateLivesInsideTheCard() throws {
        let panel = try Self.source("Yala/App/Views/Panel/PanelView.swift")
        let card = try Self.source("Yala/App/Views/Panel/FXPnLCard.swift")

        #expect(
            panel.contains("FXPnLCard(viewModel: viewModel)"),
            "la card recibe el ViewModel y decide por dentro"
        )
        #expect(
            !panel.contains("FXPnLLogic.shouldPresent"),
            """
            Con el gate en el callsite, cruzar el umbral mientras el usuario lee el detalle destruye
            la card, su `@State` y su `.sheet`: la hoja se cierra sola en su cara. Y leer aquí una
            propiedad `@Observable` invalida `PanelView` entero — el body pesado que `PanelShell`
            existe para no re-evaluar.
            """
        )
        #expect(card.contains("FXPnLLogic.shouldPresent"), "la condición está en la card")
    }

    // MARK: - Color

    @Test("El monto coloreado usa el tono con contraste AA, nunca la paleta cruda")
    func amountUsesAccessibleInk() throws {
        for path in [
            "Yala/App/Views/Panel/FXPnLCard.swift",
            "Yala/App/Views/Panel/Sheets/FXPnLDetailSheet.swift"
        ] {
            let src = try Self.source(path)
            #expect(
                src.contains("Color.incomeAmount"),
                "\(path): la ganancia va en #0F7A80 (contraste 5,1)"
            )
            // Se busca el USO como tinta (`.color(theme.…)`), no la mención: la prosa que
            // explica por qué no se usa la paleta contiene el nombre a propósito.
            #expect(
                !src.contains(".color(theme."),
                """
                \(path): ningún color de la paleta vale para TEXTO sobre tarjeta blanca — el de
                ingreso es `priorityNeed`, contraste 2,19, y `AmountText` pinta símbolo y decimales
                al 60 % encima, que lo baja a ~2,5. Y la pérdida NUNCA va en el rojo del DS: perder
                por tipo de cambio no es un error del usuario, es el clima.
                """
            )
        }
    }
}
