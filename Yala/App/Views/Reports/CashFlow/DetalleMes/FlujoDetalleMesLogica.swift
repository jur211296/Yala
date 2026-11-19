//
//  FlujoDetalleMesLogica.swift
//  Yala
//
//  El detalle del mes del flujo de caja cuenta una sola historia (S2 del replanteo, decisiones de Jürgen del 18-nov-2026,
//  ticket `2026-11-17-flujo-de-caja-replanteo`): «Empezaste con · Entró · Salió · Terminas con». Sustituye a las tres
//  cifras distintas de «cómo acabo el mes» y al «Empezaste con S/ 0» manual. La tabla agrupa por categoría y la fila base
//  es la subcategoría.
//
//  Lógica pura sobre lo que ya calculó el motor del mes (`CashFlowMonth`): la vista solo pinta.
//

import Foundation
import SwiftData

enum FlujoDetalleMesLogica {

    // MARK: - La historia del mes

    /// En qué tiempo se cuenta el mes: lo que ya pasó, en pasado; el mes en curso, con lo que falta estimado; lo que
    /// viene, en condicional.
    enum Tiempo: Equatable {
        case pasado, enCurso, futuro

        init(_ month: CashFlowMonth) {
            self = month.isPast ? .pasado : (month.isCurrent ? .enCurso : .futuro)
        }
    }

    /// Lo que entró o salió: lo real y lo que falta (estimado).
    struct Flujo: Equatable {
        let real: Double
        let estimado: Double
        var total: Double { real + estimado }
        /// Hay algo estimado que enseñar debajo de lo real.
        var tieneEstimado: Bool { !CurrencyFormattingHelper.isShownAsZero(estimado) }
    }

    struct Historia: Equatable {
        let tiempo: Tiempo
        /// Con cuánto empezó el mes. `nil` sin cuentas que sumen.
        let empezaste: Double?
        let entro: Flujo
        let salio: Flujo
        /// Lo que hace falta para que la suma cuadre con el saldo de tus cuentas (ajustes de saldo, movimientos sin
        /// cuenta, divisas a otra tasa). `nil` si se pinta como cero o no hay saldo.
        let ajuste: Double?
        /// Con cuánto termina el mes. `nil` sin cuentas que sumen.
        let terminas: Double?
        /// Lo que entra menos lo que sale en el mes entero.
        let neto: Double

        /// La cifra grande y la de la cápsula: con cuánto terminas; sin saldo, lo que queda.
        var cifra: Double { terminas ?? neto }
        /// Todo lo que no es un mes cerrado lleva algo estimado.
        var esEstimada: Bool { tiempo != .pasado }
    }

    static func historia(_ month: CashFlowMonth) -> Historia {
        let tiempo = Tiempo(month)
        let entro: Flujo
        let salio: Flujo
        switch tiempo {
        case .pasado:
            entro = Flujo(real: month.totalIncome, estimado: 0)
            salio = Flujo(real: month.totalExpense, estimado: 0)
        case .enCurso:
            entro = Flujo(real: month.realIncome, estimado: month.incomeLeft)
            salio = Flujo(real: month.realExpense, estimado: month.expenseLeft)
        case .futuro:
            entro = Flujo(real: 0, estimado: month.totalIncome)
            salio = Flujo(real: 0, estimado: month.totalExpense)
        }
        let empezaste = month.openingBalance
        let terminas = month.accumulatedBalance
        var ajuste: Double?
        if let empezaste, let terminas {
            let diferencia = terminas - (empezaste + month.totalIncome - month.totalExpense)
            ajuste = CurrencyFormattingHelper.isShownAsZero(diferencia) ? nil : diferencia
        }
        return Historia(
            tiempo: tiempo,
            empezaste: terminas == nil ? nil : empezaste,
            entro: entro, salio: salio,
            ajuste: ajuste,
            terminas: empezaste == nil ? nil : terminas,
            neto: month.netFlow
        )
    }

    /// La cifra de la cápsula: «12.4k», «≈ 9,820», «-450». Sin divisa (la cápsula es estrecha). Lo estimado lleva «≈»
    /// delante; un mes cerrado, no.
    static func textoCapsula(_ historia: Historia) -> String {
        let cifra = YalaFormatter.amountCompactTable(value: historia.cifra)
        if historia.terminas == nil {
            return CashFlowMonthSummaryLogic.capsuleNetText(historia.neto)
        }
        return historia.esEstimada ? "≈ " + cifra : cifra
    }

    // MARK: - La tabla por categoría

    /// Una categoría como agrupador de sus líneas: la subcategoría es la fila base; la categoría, su suma.
    struct Grupo: Identifiable {
        let id: PersistentIdentifier
        let nombre: String
        let lineas: [CashFlowLineResult]
        /// Lo anotado en la categoría sin subcategoría (real, fechado y pendiente). Va como fila propia para que el
        /// grupo sume lo que enseña. `nil` si se pinta como cero.
        let sinSubcategoria: Double?
        /// Lo que la categoría suma al mes: real + lo que falta de sus líneas + lo anotado sin subcategoría.
        let total: Double
    }

    struct Tabla {
        let grupos: [Grupo]
        /// Las líneas sin categoría (libres o de un pago sin categoría): van después de los grupos.
        let sueltas: [CashFlowLineResult]
    }

    static func tabla(lineas: [CashFlowLineResult], grupos: [CashFlowCategoryGroup]) -> Tabla {
        let porID = Dictionary(lineas.map { ($0.lineID, $0) }, uniquingKeysWith: { first, _ in first })
        var agrupadas: Set<UUID> = []
        let resultado: [Grupo] = grupos.compactMap { grupo in
            let suyas = grupo.lineIDs.compactMap { porID[$0] }
            guard !suyas.isEmpty else { return nil }
            agrupadas.formUnion(suyas.map(\.lineID))
            return Grupo(
                id: grupo.categoryID,
                nombre: grupo.categoryName,
                lineas: suyas,
                sinSubcategoria: CurrencyFormattingHelper.isShownAsZero(grupo.unassignedAmount)
                    ? nil : grupo.unassignedAmount,
                total: grupo.expectedAmount
            )
        }
        return Tabla(grupos: resultado, sueltas: lineas.filter { !agrupadas.contains($0.lineID) })
    }
}
