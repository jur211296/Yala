//
//  FlujoCambiarLimiteLogica.swift
//  Yala
//
//  Flujo de caja · S4 del replanteo (18-nov-2026): cambiar el límite de una línea con un alcance. Decisión P3 de Jürgen:
//  por defecto, «desde este mes en adelante». Nació para la hoja «Cambiar límite», retirada el 19-nov-2026 (quedó sin
//  entrada: todo pasa por «Cálculo del monto»). Queda lo que «Cálculo del monto» usa al guardar un monto fijo: el alcance,
//  leer el monto escrito y qué se escribe (`escritura`, que aplica `CashFlowPlanViewModel.cambiarLimite`).
//
//  Los tres alcances, con la misma precedencia que ya usa el cálculo (`CashFlowProjectionCalculator.resolvePlanned`:
//  ajuste de un mes › último cambio «desde» › método de la línea):
//   - Solo este mes: un ajuste de ese mes (`CashFlowOverride`). Los demás meses no cambian.
//   - Desde este mes: un cambio «desde» (`CashFlowAmountChangeLogic.applying`). Los meses anteriores no cambian, y los
//     meses siguientes con ajuste propio lo conservan: son excepciones que la persona puso a propósito.
//   - Todos los meses: la línea pasa a monto fijo y se retiran los cambios «desde» y los ajustes de un solo mes; si no,
//     un mes con ajuste propio seguiría con otro número y «todos» no sería verdad.
//
//  Un mes cerrado no cambia lo que pasó (en el motor un mes pasado es lo real): su límite solo dice con qué se compara
//  lo gastado. Por eso se puede cambiar, y la hoja lo explica.
//
//  Lógica pura: sin SwiftData ni SwiftUI.
//

import Foundation

nonisolated enum FlujoCambiarLimiteLogica {

    enum Alcance: String, CaseIterable, Sendable {
        case soloEsteMes
        case desdeEsteMes
        case todos

        /// P3: lo que la hoja trae elegido al abrir.
        static let porDefecto: Alcance = .desdeEsteMes
    }

    /// Lo que se puede guardar: cero incluido (no esperas nada en esa línea), nunca negativo.
    static func esMontoValido(_ monto: Double) -> Bool {
        monto.isFinite && monto >= 0
    }

    /// El monto escrito en el campo. `nil` si está vacío o no es un número de 0 o más: un campo vacío no se guarda
    /// como 0 (`AmountInputHelper.parseDecimal` devuelve 0 para lo que no entiende).
    static func montoEscrito(_ texto: String, locale: Locale = .current) -> Double? {
        let limpio = texto.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return nil }
        let agrupado = limpio.replacing(locale.groupingSeparator ?? ",", with: "")
        let normal = agrupado.replacing(locale.decimalSeparator ?? ".", with: ".")
        guard let valor = Double(normal), esMontoValido(valor) else { return nil }
        return valor
    }

    // MARK: - Lo que se escribe

    /// Qué hay que escribir en la línea. Lo aplica `CashFlowPlanViewModel.cambiarLimite`; aquí se decide.
    struct Escritura: Equatable, Sendable {
        enum RetirarAjustes: Equatable, Sendable {
            case mes(String)
            case todos
        }

        /// Mes del ajuste de un solo mes que se crea (reemplaza al que tuviera).
        let ajusteDeUnMes: String?
        /// Ajustes de un solo mes que se retiran antes de escribir.
        let retirarAjustes: RetirarAjustes
        /// Cambios «desde» que quedan guardados.
        let cambiosDesde: [CashFlowAmountChangeLogic.Change]
        /// Monto fijo de la línea (`nil` = el método no cambia).
        let montoFijo: Double?
    }

    /// - `conservaMetodo`: la línea es de un pago planificado. Pasarla a monto fijo la desligaría de sus pagos (el
    ///   motor solo da a la línea los cobros de su pago con el método `.scheduled`), así que «Todos los meses» deja el
    ///   método y escribe un cambio «desde» el primer mes del plan (`primerMes`).
    static func escritura(
        alcance: Alcance, elegido: String, monto: Double, cambiosActuales: [CashFlowAmountChangeLogic.Change],
        conservaMetodo: Bool = false, primerMes: String? = nil
    ) -> Escritura {
        switch alcance {
        case .soloEsteMes:
            return Escritura(
                ajusteDeUnMes: elegido, retirarAjustes: .mes(elegido), cambiosDesde: cambiosActuales, montoFijo: nil)
        case .desdeEsteMes:
            return Escritura(
                ajusteDeUnMes: nil, retirarAjustes: .mes(elegido),
                cambiosDesde: CashFlowAmountChangeLogic.applying(.init(monthKey: elegido, amount: monto), to: cambiosActuales),
                montoFijo: nil)
        case .todos where conservaMetodo:
            let desde = min(primerMes ?? elegido, elegido)
            return Escritura(
                ajusteDeUnMes: nil, retirarAjustes: .todos,
                cambiosDesde: [.init(monthKey: desde, amount: monto)], montoFijo: nil)
        case .todos:
            return Escritura(ajusteDeUnMes: nil, retirarAjustes: .todos, cambiosDesde: [], montoFijo: monto)
        }
    }
}
