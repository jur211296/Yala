//
//  SubcategorySystemRoleBackfill.swift
//  Yala
//
//  Rellena `Subcategory.systemRoleRaw` en las subcategorías de antes del papel. Ticket
//  `transfer-and-adjustment-subcategories-need-a-stable-role`.
//

import Foundation
import SwiftData

/// Escribe el papel de sistema (transferencia o ajuste) en las subcategorías que llegaron sin él: las de un store de 2.2
/// tras la migración ligera, las que baja iCloud desde un build viejo y las que trae el canal del Modo Nube, que no lleva
/// el campo.
///
/// **Corre en cada arranque, no una vez.** Son pocas filas, y lo que llega sin papel puede llegar en cualquier momento.
/// Solo toca las que tienen el campo vacío, así que repetirlo no cambia nada.
///
/// **La regla**, la misma en todos los teléfonos y sobre campos que viajan por los dos canales:
/// - Las que creó Yala (`isDefaultSeed`) toman el papel que dice su nombre (`Subcategory.inferredSystemRole`).
/// - Las del usuario (`isDefaultSeed == false`) quedan normales aunque se llamen igual, **salvo** que ya guarden
///   movimientos de ese papel: antes del papel el formulario y el importador mandaban las transferencias a cualquier
///   subcategoría con ese nombre, y el importador las creaba con `isDefaultSeed: false`. Ésa ya era, de hecho, la de
///   transferencias o ajustes.
///
/// **La sembrada de transferencia de en, de, nl, ja y zh se separa.** Hasta el 2026-11-13 era normal y se elegía a
/// mano; ahora es de sistema (decisión de Jürgen). Lo que el usuario apuntó en ella —movimientos que no son
/// transferencias, favoritos, pagos programados, borradores, presupuestos, lo aprendido de comercios y líneas del flujo
/// de caja— pasa a una subcategoría SUYA con el mismo nombre, icono y orden. Así no pierde nada: sus movimientos siguen
/// contando en estadísticas, la puede seguir eligiendo, y el puente de Grupos encuentra por nombre la suya y no la de
/// sistema (`GroupSubcategoryMatchLogic` descarta las de sistema).
///
/// **Residual aceptado:** si dos teléfonos separan la misma sembrada antes de verse, cada uno crea su copia: quedan dos
/// subcategorías del usuario con el mismo nombre, sin pérdida (cada movimiento acaba en una). Se funden a mano con
/// «Mover registros». Lo acota la espera de quiescencia del arranque.
@MainActor
enum SubcategorySystemRoleBackfill {

    /// Lo que hizo una pasada. Es la medida de cuántas filas toca la migración.
    struct Report: Equatable {
        /// Subcategorías a las que se escribió el papel.
        var rolesWritten = 0
        /// Copias del usuario creadas al separar una sembrada de transferencia que se elegía a mano.
        var userCopiesCreated = 0
        /// Movimientos que pasaron a esa copia.
        var transactionsMoved = 0
        /// Favoritos, pagos programados, borradores, presupuestos, comercios y líneas del flujo de caja que pasaron.
        var otherRecordsMoved = 0
    }

    /// Una pasada sobre `context`. Guarda solo si escribió algo; si el guardado falla deshace lo suyo y el reintento es
    /// el arranque siguiente. El llamador espera antes a que el store esté quieto (`AppBootstrapper`).
    @discardableResult
    static func run(context: ModelContext) -> Report {
        var report = Report()
        let pending: [Subcategory]
        do {
            pending = try context.fetch(FetchDescriptor<Subcategory>(
                predicate: #Predicate { $0.systemRoleRaw == nil }))
        } catch {
            #if DEBUG
            print("SubcategorySystemRoleBackfill: Error: \(error)")
            #endif
            return report
        }

        // Lo que hubiera pendiente de otra pantalla se guarda ANTES, para que un rollback de esta pasada no se lo lleve.
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                #if DEBUG
                print("SubcategorySystemRoleBackfill: Error: \(error)")
                #endif
                return report
            }
        }

        for subcategory in pending where !subcategory.isSystem {
            guard let role = role(for: subcategory) else { continue }
            if splitsUserRecords(subcategory, role: role) {
                moveUserRecords(from: subcategory, report: &report, context: context)
            }
            subcategory.systemRole = role
            report.rolesWritten += 1
        }

        guard report.rolesWritten > 0 else { return report }
        do {
            SaveBreadcrumb.willSave("SubcategorySystemRoleBackfill.run")
            try context.save()
            SaveBreadcrumb.didSave("SubcategorySystemRoleBackfill.run")
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("SubcategorySystemRoleBackfill: Error: \(error)")
            #endif
            context.rollback()
            return Report()
        }
        #if DEBUG
        print("SubcategorySystemRoleBackfill: \(report)")
        #endif
        return report
    }

    // MARK: - La regla

    /// El papel que le toca a una subcategoría sin el campo, o `nil` si es normal.
    static func role(for subcategory: Subcategory) -> SubcategorySystemRole? {
        if let inferred = Subcategory.inferredSystemRole(
            name: subcategory.name, isDefaultSeed: subcategory.isDefaultSeed) {
            return inferred
        }
        // Del usuario con el nombre de una de sistema: solo si ya guarda movimientos de ese papel.
        let types = Set((subcategory.transactions ?? []).compactMap(\.balanceAdjustmentType))
        if Subcategory.transferNames.contains(subcategory.name),
           types.contains(TransactionItem.adjustmentTypeTransfer) {
            return .transfer
        }
        if Subcategory.balanceAdjustmentNames.contains(subcategory.name),
           !types.subtracting([TransactionItem.adjustmentTypeTransfer]).isEmpty {
            return .balanceAdjustment
        }
        return nil
    }

    /// `true` si es la sembrada de transferencia que hasta ahora era normal: su nombre no era de sistema.
    static func splitsUserRecords(_ subcategory: Subcategory, role: SubcategorySystemRole) -> Bool {
        role == .transfer && subcategory.isDefaultSeed
            && !Subcategory.namesThatWereSystemBeforeTheRole.contains(subcategory.name)
    }

    // MARK: - La separación

    /// Pasa a una copia del usuario lo que el usuario apuntó en la sembrada. Las transferencias de verdad
    /// (`balanceAdjustmentType != nil`) y los favoritos de transferencia (con cuenta destino) se quedan.
    private static func moveUserRecords(from seeded: Subcategory, report: inout Report, context: ModelContext) {
        let transactions = (seeded.transactions ?? []).filter { $0.balanceAdjustmentType == nil }
        let favorites = (seeded.favoritePayments ?? []).filter { $0.destinationAccount == nil }
        let scheduled = seeded.scheduledPayments ?? []
        let drafts = seeded.inboxDrafts ?? []
        let budgets = seeded.budgets ?? []
        let memories = seeded.merchantMemories ?? []
        let lines = seeded.cashFlowLines ?? []
        let others = favorites.count + scheduled.count + drafts.count + budgets.count + memories.count + lines.count
        guard !transactions.isEmpty || others > 0 else { return }

        let copy = Subcategory(
            name: seeded.name,
            colorHex: seeded.colorHex,
            isDefaultSeed: false,
            isVisible: seeded.isVisible,
            sortOrder: seeded.sortOrder,
            natureRawValue: seeded.natureRawValue,
            iconName: seeded.iconName,
            category: seeded.category
        )
        context.insert(copy)

        for transaction in transactions { transaction.subcategory = copy }
        for favorite in favorites { favorite.subcategory = copy }
        for payment in scheduled { payment.subcategory = copy }
        for draft in drafts { draft.subcategory = copy }
        for memory in memories { memory.subcategory = copy }
        for line in lines { line.subcategory = copy }
        for budget in budgets {
            var subcategories = (budget.subcategories ?? []).filter {
                $0.persistentModelID != seeded.persistentModelID
            }
            subcategories.append(copy)
            budget.subcategories = subcategories
            // El espejo CSV se lee antes que la relación: si se quedara con el `shortcutID` de la sembrada, el
            // presupuesto contaría las transferencias y no los gastos del usuario.
            budget.setSubcategoryIDs(from: subcategories)
        }

        report.userCopiesCreated += 1
        report.transactionsMoved += transactions.count
        report.otherRecordsMoved += others
    }
}
