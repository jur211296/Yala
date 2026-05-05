//
//  GroupBridgeSystemEntities.swift
//  Yala
//
//  F3 — A0-Bridge: helpers para resolver/crear las entidades sistema usadas por
//  el bridge `SplitExpense` ↔ `TransactionItem`.
//
//  - Cuenta virtual `Grupos [moneda]` (auto-creada lazy on-demand, una por moneda).
//  - Subcategorías sistema ("Préstamo a grupos", "Cobro de préstamo", etc.).
//
//  Las funciones son @MainActor + sync para mantener el invariante de atomicidad
//  del bridge (precedente Subset 3: NSLock descartado, @MainActor garantiza
//  fetch+insert sin reentrada).
//

import Foundation
import SwiftData

@MainActor
enum GroupBridgeSystemEntities {

    // MARK: - System Subcategory Roles

    /// Roles de subcategorías sistema usadas por el bridge.
    /// Mapea al `GroupBridgeSystemRole` (string) definido en `CategorySeed.swift` (F2).
    enum SystemSubcategoryRole: String {
        /// "Préstamo a grupos" (income) — Caso A TX2: yo pagué un gasto del grupo.
        case loanToGroups
        /// "Cobro de préstamo" (expense) — Caso D TX1: mi crédito virtual se redujo.
        case loanCollection
        /// "Pago de liquidación" (income) — Caso C TX1: pagué a otro, mi deuda virtual se canceló.
        case settlementPayment
        /// "Liquidación enviada" (expense) — Caso C TX2 cuenta real.
        case settlementSent
        /// "Liquidación recibida" (income) — Caso D TX2 cuenta real.
        case settlementReceived

        /// Identificador estable independiente de localización.
        var roleString: String {
            switch self {
            case .loanToGroups: return GroupBridgeSystemRole.subcategoryLoanToGroups
            case .loanCollection: return GroupBridgeSystemRole.subcategoryLoanCollection
            case .settlementPayment: return GroupBridgeSystemRole.subcategorySettlementPayment
            case .settlementSent: return GroupBridgeSystemRole.subcategorySettlementSent
            case .settlementReceived: return GroupBridgeSystemRole.subcategorySettlementReceived
            }
        }

        /// Nombre localizado de la subcategoría (matches con seed F2).
        var localizedName: String {
            switch self {
            case .loanToGroups: return L10n.Subcategory.System.loanToGroups
            case .loanCollection: return L10n.Subcategory.System.loanCollection
            case .settlementPayment: return L10n.Subcategory.System.settlementPayment
            case .settlementSent: return L10n.Subcategory.System.settlementSent
            case .settlementReceived: return L10n.Subcategory.System.settlementReceived
            }
        }
    }

    // MARK: - Errors

    enum Error: Swift.Error, LocalizedError {
        case systemSubcategoryMissing(SystemSubcategoryRole)
        case systemAccountCreationFailed(String)

        var errorDescription: String? {
            switch self {
            case .systemSubcategoryMissing(let role):
                return "GroupBridgeSystemEntities: subcategoría sistema '\(role.rawValue)' no encontrada (seed pending?)"
            case .systemAccountCreationFailed(let reason):
                return "GroupBridgeSystemEntities: no se pudo crear cuenta sistema (\(reason))"
            }
        }
    }

    // MARK: - System Account

    /// Devuelve la cuenta sistema `Grupos [currency]` para esta moneda. Auto-crea si no existe.
    ///
    /// Comportamiento:
    /// - Si existe activa con `isSystemAccount == true`: retorna directamente.
    /// - Si existe archivada: desarchiva + retorna.
    /// - Si fetch retorna >1 (race cross-device): conserva la de menor `persistentModelID.hashValue`
    ///   (criterio determinístico cross-device), archiva las demás. TX vinculadas se mantienen
    ///   en sus cuentas originales (CloudKit ya las relaciona).
    /// - Si no existe pero hay otra Account no-sistema con el mismo nombre: usa fallback con sufijo " (Yala)".
    /// - Si no existe ni hay conflict: crea con nombre interpolado.
    static func ensureSystemAccount(
        currencyCode: String,
        colorHint: String? = nil,
        context: ModelContext
    ) throws -> Account {
        // 1. Fetch existentes con isSystemAccount=true para esta moneda.
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.isSystemAccount == true && $0.currencyCode == currencyCode }
        )
        let existing = try context.fetch(descriptor)

        // 2. Dedup defensivo cross-device si fetch retorna >1.
        if existing.count > 1 {
            // Criterio determinístico: ordenar por hash del persistentModelID.
            let sorted = existing.sorted { lhs, rhs in
                lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
            }
            let canonical = sorted[0]
            // Archivar duplicados (preservar historial de TX, no eliminar)
            for duplicate in sorted.dropFirst() where !duplicate.isArchived {
                duplicate.isArchived = true
                #if DEBUG
                print("GroupBridgeSystemEntities: dedup — archivado duplicado de Grupos \(currencyCode) (id=\(duplicate.persistentModelID))")
                #endif
            }
            // Si canonical estaba archivada, desarchivar.
            if canonical.isArchived {
                canonical.isArchived = false
            }
            return canonical
        }

        // 3. Existe exactamente uno: desarchivar si aplica + retornar.
        if let account = existing.first {
            if account.isArchived {
                account.isArchived = false
                #if DEBUG
                print("GroupBridgeSystemEntities: desarchivada cuenta sistema Grupos \(currencyCode)")
                #endif
            }
            return account
        }

        // 4. No existe. Determinar nombre con fallback si conflict con cuenta no-sistema.
        let baseName = String(format: L10n.Account.System.groups, currencyCode)
        let conflictDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.name == baseName && $0.isSystemAccount == false }
        )
        let conflicts = try context.fetch(conflictDescriptor)
        let finalName: String
        if conflicts.isEmpty {
            finalName = baseName
        } else {
            finalName = "\(baseName) (Yala)"
            #if DEBUG
            print("GroupBridgeSystemEntities: conflict con cuenta '\(baseName)' pre-existente — usando fallback '\(finalName)'")
            #endif
        }

        // 5. Crear cuenta sistema.
        let colorHex = colorHint ?? "#7C3AED"
        let account = Account(
            name: finalName,
            currencyCode: currencyCode,
            colorHex: colorHex,
            iconName: "person.2.circle.fill",
            type: "system",
            adjustmentMode: "system",
            excludeFromStatistics: false,
            isArchived: false,
            isSystemAccount: true
        )
        context.insert(account)

        #if DEBUG
        print("GroupBridgeSystemEntities: creada cuenta sistema '\(finalName)' (\(currencyCode))")
        #endif

        return account
    }

    // MARK: - System Subcategory

    /// Devuelve la subcategoría sistema correspondiente al role.
    /// Si no existe (race con seed): trigger seed + re-fetch. Si tras re-fetch sigue faltando: error.
    static func systemSubcategory(
        role: SystemSubcategoryRole,
        context: ModelContext
    ) throws -> Subcategory {
        let name = role.localizedName

        // 1. Fetch por nombre + isSystem=true.
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == name && $0.isSystem == true }
        )
        let existing = try context.fetch(descriptor)
        if let sub = existing.first {
            return sub
        }

        // 2. No encontrada — trigger seed defensivo (idempotent) y re-fetch.
        seedSystemGroupCategoriesIfNeeded(in: context)
        let retry = try context.fetch(descriptor)
        if let sub = retry.first {
            return sub
        }

        // 3. Aún no — error.
        throw Error.systemSubcategoryMissing(role)
    }
}
