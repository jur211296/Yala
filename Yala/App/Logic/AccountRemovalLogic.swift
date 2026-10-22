//
//  AccountRemovalLogic.swift
//  Yala
//
//  Qué se puede hacer con lo que cuelga de una cuenta antes de eliminarla.
//  Card `tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst`, decisión A de Jürgen (2026-10-15).
//

import Foundation

/// Las decisiones puras de «Eliminar cuenta» cuando la cuenta tiene algo dentro.
///
/// **El problema que cierra:** `Account.transactions` es `deleteRule: .nullify`, y el formulario
/// borraba la cuenta sin mirar nada: sus movimientos se quedaban en Registros sin cuenta (y fuera de
/// los totales), y nada lo decía. Lo mismo los pagos programados, los favoritos, los borradores
/// pendientes y los presupuestos que solo miraban esa cuenta.
///
/// **La política (decisión A, 2026-10-15):** si hay algo, la app pregunta. Mover a otra cuenta es la
/// opción principal; borrar es la destructiva y se confirma con la cifra. Sin nada, se elimina como
/// siempre. El resto de decisiones están en el Paso 0 del encargo y en el PR.
///
/// Genérica en el identificador de cuenta para poder fijarla con tests sin SwiftData.
enum AccountRemovalLogic {

    // MARK: - Forma de lo que cuelga

    /// Lo que importa de un movimiento de la cuenta que se elimina.
    struct Row<AccountID: Hashable>: Equatable {
        /// Divisa en la que está estampado el movimiento (no la de la cuenta: pueden diferir).
        let currencyCode: String
        /// Por qué no admite que se reexprese su importe (transferencia, gasto o liquidación de
        /// grupo), con el criterio de `AccountCurrencyChangeLogic`.
        let conversionBlock: AccountCurrencyChangeLogic.BlockReason?
        /// Lleva puntero a un gasto o liquidación de grupo: borrarlo lo resucita el siguiente sync.
        let isGroupRecord: Bool
        /// La cuenta de la otra pata, si es una transferencia de DOS patas y la otra está en otra
        /// cuenta. `nil` si no es transferencia, si la pareja no existe, si vive en esta misma cuenta
        /// o si el `transferPairID` lo comparten tres o más filas (colisión: no se toca, como hace
        /// `TransferPairReconcileService`).
        let transferPartnerAccount: AccountID?
    }

    /// Un pago programado de la cuenta.
    struct ScheduledShape: Equatable {
        let currencyCode: String
        /// De grupo (`groupZoneID != nil`): su importe lo manda el grupo y no se convierte.
        let isGroupPayment: Bool
    }

    /// Todo lo que cuelga de la cuenta.
    struct Inventory<AccountID: Hashable>: Equatable {
        let sourceCurrencyCode: String
        let rows: [Row<AccountID>]
        let scheduled: [ScheduledShape]
        let favoriteCount: Int
        /// La divisa de cada favorito CON importe (la de la cuenta si el favorito no guarda divisa).
        /// Es lo que la conversión reexpresa; los que no tienen importe solo se reetiquetan.
        let favoriteAmountCurrencies: [String]
        /// Borradores PENDIENTES de la bandeja. Los aprobados y rechazados son historia y no cuentan.
        let pendingDraftCount: Int
        /// De esos, cuántos traen un importe que no se puede convertir (lo manda un grupo).
        let pendingDraftsNotConvertible: Int
        /// Y cuántos traen un importe que sí se convierte si cambia la divisa.
        let pendingDraftsToConvert: Int
        /// Presupuestos cuyo filtro incluye esta cuenta.
        let budgetCount: Int
        /// De esos, cuántos la tienen como ÚNICA cuenta: al eliminarla sin más, su filtro queda vacío,
        /// que significa «todas las cuentas».
        let budgetsOnlyThisAccount: Int

        init(
            sourceCurrencyCode: String,
            rows: [Row<AccountID>],
            scheduled: [ScheduledShape] = [],
            favoriteCount: Int = 0,
            favoriteAmountCurrencies: [String] = [],
            pendingDraftCount: Int = 0,
            pendingDraftsNotConvertible: Int = 0,
            pendingDraftsToConvert: Int = 0,
            budgetCount: Int = 0,
            budgetsOnlyThisAccount: Int = 0
        ) {
            self.sourceCurrencyCode = sourceCurrencyCode
            self.rows = rows
            self.scheduled = scheduled
            self.favoriteCount = favoriteCount
            self.favoriteAmountCurrencies = favoriteAmountCurrencies
            self.pendingDraftCount = pendingDraftCount
            self.pendingDraftsNotConvertible = pendingDraftsNotConvertible
            self.pendingDraftsToConvert = pendingDraftsToConvert
            self.budgetCount = budgetCount
            self.budgetsOnlyThisAccount = budgetsOnlyThisAccount
        }

        /// Pagos programados, favoritos y borradores: lo que no es historial.
        var planCount: Int { scheduled.count + favoriteCount + pendingDraftCount }

        /// ¿Hay que preguntar? Con algo dentro, sí; vacía, se elimina como siempre. Un presupuesto que
        /// solo miraba esta cuenta también cuenta: sin preguntar, pasaría a mirar todas sin decirlo.
        var needsQuestion: Bool { !rows.isEmpty || planCount > 0 || budgetsOnlyThisAccount > 0 }
    }

    // MARK: - Borrar

    enum DeleteVerdict: Equatable {
        /// Se pueden borrar. `partnersKept` = transferencias cuya otra pata se queda en otra cuenta
        /// como movimiento normal.
        case allowed(rowCount: Int, partnersKept: Int)
        /// Hay movimientos de grupos: borrarlos los resucitaría el siguiente sync como borrador.
        case blockedByGroupRecords(count: Int)
    }

    static func deleteVerdict<ID: Hashable>(_ inventory: Inventory<ID>) -> DeleteVerdict {
        let groupCount = inventory.rows.filter(\.isGroupRecord).count
        guard groupCount == 0 else { return .blockedByGroupRecords(count: groupCount) }
        let partners = inventory.rows.filter { $0.transferPartnerAccount != nil }.count
        return .allowed(rowCount: inventory.rows.count, partnersKept: partners)
    }

    // MARK: - Mover

    /// Una cuenta a la que se puede mover.
    struct Destination<AccountID: Hashable>: Equatable {
        let id: AccountID
        let currencyCode: String
    }

    enum MoveVerdict: Equatable {
        /// Se puede. `convertedRows` = movimientos que cambian de divisa; `collapsedTransfers` =
        /// movimientos que se quitan porque su otra pata ya está en el destino; `convertsPlans` = algún
        /// programado, favorito o borrador cambia de divisa.
        case allowed(movedRows: Int, convertedRows: Int, collapsedTransfers: Int, convertsPlans: Bool)
        /// La divisa es otra y algo no se puede convertir: solo vale una cuenta en la divisa de la cuenta.
        case blockedByCurrency
    }

    /// Una fila se convierte si su divisa no es la del destino y nada la manda desde fuera.
    ///
    /// **Una fila que no admite conversión NUNCA se convierte**: si ya venía en otra divisa que la de su
    /// cuenta (un histórico anterior al bloqueo del cambio de divisa), se mueve tal cual — sigue igual de
    /// desemparejada que estaba, no peor. Solo bloquea si es esta mudanza la que la desemparejaría: estaba
    /// en la divisa de la cuenta y el destino es otra.
    static func rowConverts<ID: Hashable>(_ row: Row<ID>, to target: String) -> Bool {
        row.conversionBlock == nil && normalizeCurrencyCode(row.currencyCode) != target
    }

    /// Qué pasa al mover todo a `destination`.
    ///
    /// **Una transferencia cuya otra pata está YA en el destino se quita entera** (las dos patas): dentro
    /// de una cuenta no mueve dinero, y con la misma divisa su saldo neto es cero, así que el saldo de la
    /// cuenta destino no cambia y no queda una transferencia «de D a D» que el editor no sabe pintar.
    ///
    /// **Se bloquea por divisa** si alguna fila que esta mudanza desemparejaría no admite conversión, o si
    /// hay programados o borradores de grupo que acabarían en una cuenta de otra divisa: el puente de grupos
    /// pisa o borra esas conversiones (`AccountCurrencyChangeLogic`).
    static func moveVerdict<ID: Hashable>(
        _ inventory: Inventory<ID>,
        to destination: Destination<ID>
    ) -> MoveVerdict {
        let target = normalizeCurrencyCode(destination.currencyCode)
        let source = normalizeCurrencyCode(inventory.sourceCurrencyCode)
        let collapsed = inventory.rows.filter { $0.transferPartnerAccount == destination.id }
        let moved = inventory.rows.filter { $0.transferPartnerAccount != destination.id }

        let breaksBlockedRow = moved.contains {
            $0.conversionBlock != nil
                && normalizeCurrencyCode($0.currencyCode) == source
                && source != target
        }
        if breaksBlockedRow { return .blockedByCurrency }

        let sourceDiffers = source != target
        let groupPlanMismatch = inventory.scheduled.contains {
            $0.isGroupPayment && normalizeCurrencyCode($0.currencyCode) != target
        }
        if groupPlanMismatch { return .blockedByCurrency }
        if sourceDiffers && inventory.pendingDraftsNotConvertible > 0 { return .blockedByCurrency }

        let convertsPlans = inventory.scheduled.contains {
            !$0.isGroupPayment && normalizeCurrencyCode($0.currencyCode) != target
        }
            || inventory.favoriteAmountCurrencies.contains { normalizeCurrencyCode($0) != target }
            || (sourceDiffers && inventory.pendingDraftsToConvert > 0)

        return .allowed(
            movedRows: moved.count,
            convertedRows: moved.filter { rowConverts($0, to: target) }.count,
            collapsedTransfers: collapsed.count,
            convertsPlans: convertsPlans
        )
    }
}
