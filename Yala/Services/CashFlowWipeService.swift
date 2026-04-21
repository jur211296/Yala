//
//  CashFlowWipeService.swift
//  Yala
//
//  One-shot wipe de datos locales de Cash Flow al actualizar a 1.2.7.
//  Necesario por bug de sync en 1.2.6: CashFlowOverride.line se serializaba
//  como STRING en CKRecord en vez de REFERENCE, atascando el outbox
//  entero de CloudKit. El wipe local genera tombstones que colapsan con
//  los INSERTs fallidos y liberan el batch.
//
//  No hay pérdida de datos en server: Cash Flow NUNCA sincronizó en 1.2.6
//  por los bugs de entitlements (capas 1-2 del bug). La pérdida es solo
//  configuración local manual (feature Pro nueva, subset pequeño).
//
//  Flag es local a cada device: en multi-device ambos devices ejecutan
//  el wipe una vez al actualizar a 1.2.7. Los tombstones via CloudKit
//  también destraban independientemente del orden de actualización.
//

import Foundation
import SwiftData

@MainActor
enum CashFlowWipeService {
    private static let didWipeKey = "didWipeCashFlow_1_2_7"

    static func wipeCashFlowDataIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: didWipeKey) else { return }

        do {
            // Delete all CashFlowPlan (cascade borra Lines y Overrides por deleteRule)
            let plans = try context.fetch(FetchDescriptor<CashFlowPlan>())
            for plan in plans {
                context.delete(plan)
            }

            // Safety: borrar Lines y Overrides huérfanos si quedaron sin plan
            let lines = try context.fetch(FetchDescriptor<CashFlowLine>())
            for line in lines {
                context.delete(line)
            }

            let overrides = try context.fetch(FetchDescriptor<CashFlowOverride>())
            for override in overrides {
                context.delete(override)
            }

            try context.save()

            UserDefaults.standard.set(true, forKey: didWipeKey)

            #if DEBUG
            print("CashFlowWipeService: Wiped \(plans.count) plans, \(lines.count) lines, \(overrides.count) overrides")
            #endif
        } catch {
            #if DEBUG
            print("CashFlowWipeService: Error wiping — \(error)")
            #endif
            // NO marcar flag si falla, para reintentar en próximo launch
        }
    }
}
