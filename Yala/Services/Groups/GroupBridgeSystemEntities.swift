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

        /// Key cruda de localización (patrón regular `subcategory.system.<roleString>`).
        /// Permite barrer el nombre en TODOS los idiomas para resolver por rol, no por
        /// el idioma actual de la app.
        var localizationKey: String { "subcategory.system.\(roleString)" }

        /// Rol de la categoría padre (según `systemGroupCategoryDefinitions()`): las income
        /// cuelgan de "groupCollections", las expense de "groups".
        var parentCategoryRole: String {
            switch self {
            case .loanToGroups, .settlementPayment, .settlementReceived:
                return GroupBridgeSystemRole.categoryGroupCollections  // income
            case .loanCollection, .settlementSent:
                return GroupBridgeSystemRole.categoryGroups            // expense
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
            // Criterio determinístico cross-launch: name lexicográfico, luego shortcutID.
            // (`persistentModelID.hashValue` no es estable entre launches en SwiftData.)
            let sorted = existing.sorted { lhs, rhs in
                if lhs.name != rhs.name { return lhs.name < rhs.name }
                return lhs.shortcutID.uuidString < rhs.shortcutID.uuidString
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

    // MARK: - Auto-Archive

    /// A0-Bridge F13: archiva la cuenta sistema `Grupos [currency]` si:
    /// 1) No existe ningún grupo activo en esa moneda Y
    /// 2) No hay TX en la cuenta con `splitExpenseID/splitSettlementID != nil`.
    ///
    /// Si solo el primer condicional aplica pero hay TX históricas, la cuenta queda visible
    /// (preserva historial). Si user crea grupo nuevo en esa moneda: `ensureSystemAccount`
    /// la desarchiva automáticamente.
    ///
    /// **Trigger**: post-leave/delete de último grupo en moneda.
    /// NO se invoca por delete de un solo expense (la cuenta sigue visible con saldo 0).
    static func archiveSystemAccountIfEmpty(currencyCode: String, context: ModelContext) throws {
        // 1. Fetch cuenta sistema activa para esta moneda.
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate {
                $0.isSystemAccount == true && $0.currencyCode == currencyCode && $0.isArchived == false
            }
        )
        guard let account = try context.fetch(descriptor).first else { return }

        // 2. Chequear que no haya TX bridgeadas (con splitExpenseID o splitSettlementID).
        // SwiftData #Predicate no soporta `||` con nil-checks complejos; usamos 2 fetches.
        let accountID = account.persistentModelID
        let txWithExpense = try context.fetchCount(FetchDescriptor<TransactionItem>(
            predicate: #Predicate {
                $0.account?.persistentModelID == accountID && $0.splitExpenseID != nil
            }
        ))
        let txWithSettlement = try context.fetchCount(FetchDescriptor<TransactionItem>(
            predicate: #Predicate {
                $0.account?.persistentModelID == accountID && $0.splitSettlementID != nil
            }
        ))
        let bridgedTxs = txWithExpense + txWithSettlement
        if bridgedTxs > 0 {
            #if DEBUG
            print("GroupBridgeSystemEntities: skipping archive de Grupos \(currencyCode) — \(bridgedTxs) TX bridgeadas remanentes")
            #endif
            return
        }

        // 3. Archivar.
        account.isArchived = true
        try context.save()

        #if DEBUG
        print("GroupBridgeSystemEntities: archivada cuenta sistema Grupos \(currencyCode) (sin TX bridgeadas)")
        #endif
    }

    // MARK: - Resolución por rol (multi-idioma)

    /// Candidato para la selección determinística de una entidad de sistema.
    struct SystemEntityCandidate: Sendable {
        let name: String
        let isSystem: Bool
        let isDefaultSeed: Bool
        /// Clave de desempate estable (Subcategory: `shortcutID.uuidString`; Category: `name`).
        let tiebreak: String
    }

    /// PURE: índice del candidato que matchea por nombre multi-idioma.
    /// Adopta SOLO entidades de sistema o sembradas (`isSystem || isDefaultSeed`) — nunca una
    /// entidad PERSONAL homónima del usuario. Ante varios (UUIDs colapsados / duplicados
    /// cross-device) desempata determinísticamente por `tiebreak` y luego por orden de aparición.
    nonisolated static func selectSystemEntityIndex(
        _ candidates: [SystemEntityCandidate],
        matching names: Set<String>
    ) -> Int? {
        let matches = candidates.enumerated().filter {
            ($0.element.isSystem || $0.element.isDefaultSeed) && names.contains($0.element.name)
        }
        guard !matches.isEmpty else { return nil }
        return matches.min {
            $0.element.tiebreak != $1.element.tiebreak
                ? $0.element.tiebreak < $1.element.tiebreak
                : $0.offset < $1.offset
        }?.offset
    }

    /// Cache del barrido de nombres por key (independiente del idioma actual; los `.strings`
    /// no mutan en runtime). `@MainActor` (el enum lo es) → acceso serializado, sin data race.
    private static var localizedNamesCache: [String: Set<String>] = [:]

    private static func localizedNames(forKey key: String) -> Set<String> {
        if let cached = localizedNamesCache[key] { return cached }
        let names = L10n.allLocalizedValues(forKey: key)
        localizedNamesCache[key] = names
        return names
    }

    /// Mapea entidades a candidatos para `selectSystemEntityIndex`. Desempate: Subcategory por
    /// `shortcutID` (estable cross-device), Category por `name` (no tiene shortcutID).
    private static func candidates(from subs: [Subcategory]) -> [SystemEntityCandidate] {
        subs.map { SystemEntityCandidate(name: $0.name, isSystem: $0.isSystem,
                                         isDefaultSeed: $0.isDefaultSeed, tiebreak: $0.shortcutID.uuidString) }
    }

    private static func candidates(from cats: [Category]) -> [SystemEntityCandidate] {
        cats.map { SystemEntityCandidate(name: $0.name, isSystem: $0.isSystem,
                                         isDefaultSeed: $0.isDefaultSeed, tiebreak: $0.name) }
    }

    // MARK: - System Subcategory

    /// Devuelve la subcategoría de sistema del rol, robusta al idioma:
    /// 1. Find multi-idioma — resuelve aunque la app cambió de idioma tras sembrar (self-heal `isSystem`).
    /// 2. Seed defensivo (idempotent) + re-find — para DB sin entidades de sistema.
    /// 3. Create-if-missing — SOLO si no existe en NINGÚN idioma (cero riesgo de duplicado).
    ///    Garantiza la subcategoría: omitirla descuadraría las estadísticas income/expense.
    /// El `throw` solo sobrevive a fallo catastrófico de fetch (DB rota); ya NO se dispara por idioma.
    /// No persiste: el self-heal/inserts se guardan con el `save()` del caller (precedente del archivo).
    static func systemSubcategory(
        role: SystemSubcategoryRole,
        context: ModelContext
    ) throws -> Subcategory {
        // 1. Find multi-idioma.
        if let found = try findSystemSubcategory(role: role, context: context) {
            return found
        }

        // 2. Seed defensivo + re-find.
        seedSystemGroupCategoriesIfNeeded(in: context)
        if let afterSeed = try findSystemSubcategory(role: role, context: context) {
            return afterSeed
        }

        // 3. Create-if-missing bajo su categoría de sistema.
        let parent = try findOrCreateSystemCategory(forSubcategoryRole: role, context: context)
        // Re-find GLOBAL una última vez (más fuerte que mirar `parent.subcategories`, que puede
        // llegar lazy/nil desde CloudKit) para minimizar la ventana de duplicado durante un import.
        if let found = try findSystemSubcategory(role: role, context: context) {
            return found
        }
        let sub = Subcategory(
            name: role.localizedName,
            colorHex: nil,
            isDefaultSeed: true,
            isVisible: true,
            sortOrder: 0,
            natureRawValue: "sin_clasificacion",
            iconName: nil,
            isSystem: true,
            category: parent
        )
        context.insert(sub)
        return sub
    }

    /// Find multi-idioma de la subcategoría de sistema del rol. Self-heal `isSystem` si la
    /// encuentra con el flag en false (CloudKit no hidratado). No persiste (el caller guarda).
    private static func findSystemSubcategory(
        role: SystemSubcategoryRole,
        context: ModelContext
    ) throws -> Subcategory? {
        let names = localizedNames(forKey: role.localizationKey)
        // Acota a candidatas de sistema/sembradas (evita deserializar todo el catálogo del
        // usuario); el nombre se filtra en Swift porque #Predicate no maneja `Set.contains`.
        let all = try context.fetch(FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.isSystem || $0.isDefaultSeed }
        ))
        guard let idx = selectSystemEntityIndex(candidates(from: all), matching: names) else { return nil }
        let match = all[idx]
        if !match.isSystem { match.isSystem = true }  // self-heal
        return match
    }

    /// Find-or-create de la categoría de sistema padre del rol (multi-idioma + `isIncome`).
    /// Reutiliza `systemGroupCategoryDefinitions()` como fuente única de nombre/icono/color.
    private static func findOrCreateSystemCategory(
        forSubcategoryRole role: SystemSubcategoryRole,
        context: ModelContext
    ) throws -> Category {
        guard let def = systemGroupCategoryDefinitions().first(where: { $0.role == role.parentCategoryRole }) else {
            // Imposible salvo bug de programación (los roles son estáticos).
            throw Error.systemSubcategoryMissing(role)
        }
        let names = localizedNames(forKey: "category.system.\(role.parentCategoryRole)")
        // Acota a categorías de sistema/sembradas del tipo (income/expense) correcto.
        let isIncome = def.isIncome
        let scoped = try context.fetch(FetchDescriptor<Category>(
            predicate: #Predicate { ($0.isSystem || $0.isDefaultSeed) && $0.isIncome == isIncome }
        ))
        if let idx = selectSystemEntityIndex(candidates(from: scoped), matching: names) {
            let match = scoped[idx]
            if !match.isSystem { match.isSystem = true }  // self-heal
            return match
        }
        // Crear (idéntico al seed).
        let category = Category(
            name: def.name,
            colorHex: def.colorHex,
            isIncome: def.isIncome,
            isDefaultSeed: true,
            isVisible: true,
            sortOrder: 100,
            iconName: def.iconName,
            isSystem: true
        )
        context.insert(category)
        return category
    }
}
