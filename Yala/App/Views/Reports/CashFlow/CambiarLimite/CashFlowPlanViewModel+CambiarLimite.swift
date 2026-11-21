//
//  CashFlowPlanViewModel+CambiarLimite.swift
//  Yala
//
//  Aplica lo que decide `FlujoCambiarLimiteLogica.escritura` (S4 del replanteo). Vive aquí, y no en
//  `CashFlowPlanViewModel.swift`, porque el encargo de S4 solo declara esta carpeta. Usa el contexto de la propia línea:
//  es el mismo que el del ViewModel (las líneas salen de su plan).
//

import Foundation
import SwiftData

extension CashFlowPlanViewModel {

    /// Guarda el límite nuevo con su alcance. Devuelve `false` si no se pudo (línea borrada, monto inválido o error al
    /// guardar): la hoja se queda abierta.
    @discardableResult
    func cambiarLimite(
        line: CashFlowLine, monthKey: String, amount: Double, alcance: FlujoCambiarLimiteLogica.Alcance,
        primerMes: String? = nil
    ) -> Bool {
        guard !line.isDeleted, let ctx = line.modelContext,
              FlujoCambiarLimiteLogica.esMontoValido(amount),
              CashFlowAmountChangeLogic.isMonthKey(monthKey)
        else { return false }

        let escritura = FlujoCambiarLimiteLogica.escritura(
            alcance: alcance, elegido: monthKey, monto: amount, cambiosActuales: line.amountChanges,
            conservaMetodo: line.method == .scheduled, primerMes: primerMes
        )

        // Ajustes de un solo mes: también los del legado (`overrides`) que aún no migraron, o quedarían dos del mismo mes.
        let ajustes = (line.monthOverrides ?? []) + (line.overrides ?? [])
        for ajuste in ajustes {
            switch escritura.retirarAjustes {
            case .todos:
                ctx.delete(ajuste)
            case .mes(let key) where ajuste.monthKey == key:
                ctx.delete(ajuste)
            case .mes:
                break
            }
        }

        if let key = escritura.ajusteDeUnMes {
            let ajuste = CashFlowOverride(monthKey: key, amount: amount, note: "")
            ctx.insert(ajuste)
            // `cashFlowLine`, NUNCA `line`: el campo de `line` lo rechaza iCloud en Production
            // (`CashFlowOverrideLineMigration`).
            ajuste.cashFlowLine = line
        }

        let raw = CashFlowAmountChangeLogic.encode(escritura.cambiosDesde)
        if line.amountChangesRaw != raw {
            line.amountChangesRaw = raw
        }

        if let fijo = escritura.montoFijo {
            line.estimationMethod = EstimationMethod.manual.rawValue
            line.manualAmount = fijo
        }
        // Un monto escrito en la moneda del flujo deja de ser «en otra moneda» (encargo del 2026-11-20).
        if line.limitCurrencyCode != nil { line.limitCurrencyCode = nil }
        if line.limitForeignAmount != nil { line.limitForeignAmount = nil }

        do {
            try ctx.save()
            Self.announcePlanChange(ctx)
            return true
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error cambiando el límite: \(error)")
            #endif
            return false
        }
    }
}
