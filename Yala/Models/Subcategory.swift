//
//  Subcategory.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

// MARK: - Subcategory

@Model
final class Subcategory {
    // CloudKit: defaults required
    var name: String = ""
    var colorHex: String?

    /// Stable identifier for App Intents (Siri/Shortcuts). Unaffected by name/category renames.
    /// CloudKit: must have default value, no `@Attribute(.unique)`. Migration: legacy entities
    /// receive a UUID at first save via AppBootstrapper.persistAppEntityShortcutIDsIfNeeded.
    /// I12: identidad de sync del Modo Nube (`sync_id_source = Subcategory.shortcutID`).
    /// `.preserveValueOnDeletion` para que el history tombstone conserve el `shortcutID` (metadata de
    /// History; NO es un campo CloudKit nuevo → sin deploy .ckdb).
    @Attribute(.preserveValueOnDeletion) var shortcutID: UUID = UUID()

    /// Indica si esta subcategoría proviene de la semilla inicial
    var isDefaultSeed: Bool = false
    /// Control de visibilidad dentro de la app
    var isVisible: Bool = true
    /// Orden de presentación dentro de su categoría
    var sortOrder: Int = 0
    /// Campo reservado para futura "naturaleza" (Necesario / Deseable / etc.)
    var natureRawValue: String?
    /// Nombre del icono SF Symbol (opcional)
    var iconName: String?

    /// True para subcategorías sistema persistentes (creadas por seed para flujos como bridge de grupos).
    /// CloudKit: must have default value. Excluidas de pickers manuales, presupuestos y "Top categorías".
    /// NOTA: coexiste con `systemRole` (transferencias y ajustes de saldo). Usar `isAnySystem` cuando se quiera filtrar
    /// AMBOS tipos de subcategoría sistema.
    var isSystem: Bool = false

    /// Papel estable de una subcategoría que Yala usa para sus propios movimientos: transferencias o ajustes de saldo
    /// (`SubcategorySystemRole`). `nil` en las del usuario y en las del puente de Grupos (esas llevan `isSystem`).
    ///
    /// Se lee con `systemRole`, nunca a pelo. CloudKit: opcional y sin default, así que la migración ligera lo deja en
    /// `nil` en las subcategorías de antes y las rellena `SubcategorySystemRoleBackfill` en cada arranque. Es un campo
    /// nuevo del contenedor personal: va en los cuatro `Cloudkit Schemas/yala*.ckdb` y se despliega a Production antes
    /// de publicar el build que lo escribe. El canal personal del Modo Nube no lo lleva: cada teléfono lo deriva con la
    /// misma regla sobre campos que sí viajan (`inferredSystemRole` y el relleno).
    var systemRoleRaw: String?

    /// Relación inversa con la categoría padre (optional for CloudKit compatibility)
    @Relationship(deleteRule: .nullify)
    var category: Category?

    /// Relación inversa con budgets (muchos-a-muchos) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var budgets: [Budget]?

    /// Inverse relationship: transactions linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var transactions: [TransactionItem]?

    /// Inverse relationship: favorite payments linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var favoritePayments: [FavoritePayment]?

    /// Inverse relationship: scheduled payments linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var scheduledPayments: [ScheduledPayment]?

    /// Inverse relationship: inbox drafts linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var inboxDrafts: [InboxDraft]?

    /// Inverse relationship: merchant memories linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var merchantMemories: [MerchantMemory]?

    /// Inverse relationship: cash flow lines linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var cashFlowLines: [CashFlowLine]?

    init(
        name: String,
        colorHex: String? = nil,
        isDefaultSeed: Bool = true,
        isVisible: Bool = true,
        sortOrder: Int = 0,
        natureRawValue: String? = nil,
        iconName: String? = nil,
        isSystem: Bool = false,
        systemRole: SubcategorySystemRole? = nil,
        category: Category?
    ) {
        self.name = name
        self.colorHex = colorHex
        self.isDefaultSeed = isDefaultSeed
        self.isVisible = isVisible
        self.sortOrder = sortOrder
        self.natureRawValue = natureRawValue
        self.iconName = iconName
        self.isSystem = isSystem
        self.systemRoleRaw = systemRole?.rawValue
        self.category = category
    }

}

// MARK: - System Subcategories

/// El papel de una subcategoría de sistema de Yala. Lo que decide si es de sistema es el papel, no el nombre (decisión de
/// Jürgen, 2026-11-13): una subcategoría que el usuario cree con el nombre de una de éstas es normal, y la que Yala
/// siembra para las transferencias es de sistema en todos los idiomas.
enum SubcategorySystemRole: String, CaseIterable, Sendable {
    /// La subcategoría de las dos patas de una transferencia entre cuentas.
    case transfer
    /// «Ajustes de saldo»: el saldo inicial de una cuenta y sus correcciones.
    case balanceAdjustment
}

extension Subcategory {
    /// Balance adjustment subcategory names (all localizations)
    static let balanceAdjustmentNames: Set<String> = [
        "Ajustes de saldo",
        "Balance adjustments", "Balance adjustment",
        "Saldoanpassungen", "Saldoanpassung",
        "Ajustements de solde", "Ajustement de solde",
        "Rettifiche del saldo", "Aggiustamento saldo",
        "Ajuste de saldo",
        "Saldo-aanpassing", "Korekta salda", "残高調整", "余额调整",
    ]

    /// Transfer subcategory names (all localizations).
    ///
    /// Los valores de `transfer.categoryName` de los 16 `.lproj`: el nombre de la subcategoría que Yala crea
    /// para sus transferencias. Lo exige `TransferNamesParityTests`. Desde el 2026-11-13 ya no decide qué es de
    /// sistema: sirve para reconocer las subcategorías de antes del papel (`inferredSystemRole`) y las filas de un
    /// archivo importado, que solo traen texto. «Transferencia entre contas» (sin tilde) es un nombre viejo.
    static let transferNames: Set<String> = [
        "Transferencia entre cuentas",
        "Transfer between accounts",
        "Überweisung zwischen Konten",
        "Virement entre comptes",
        "Trasferimento tra conti",
        "Transferência entre contas", "Transferencia entre contas",
        "Overschrijving tussen rekeningen",
        "Transfer między kontami",
        "口座間振替",
        "账户间转账",
    ]

    /// Los nombres de la subcategoría de transferencia que SIEMBRA Yala al empezar (`subcategory.accountTransfer` y
    /// `…Other` de los 16 `.lproj`). En es, fr, it, pl y pt coinciden con `transferNames`; en en, de, nl, ja y zh no,
    /// y hasta el 2026-11-13 eran subcategorías normales (decisión del 29-oct, reemplazada). Lo fija
    /// `TransferNamesParityTests`.
    static let seededTransferNames: Set<String> = [
        "Transferencia entre cuentas",
        "Account transfer",
        "Kontoüberweisung",
        "Virement entre comptes",
        "Trasferimento tra conti",
        "Transferência entre contas",
        "Rekeningoverdracht",
        "Transfer między kontami",
        "口座振替",
        "账户转账",
    ]

    /// Los nombres de antes que, en una subcategoría sembrada, eran de sistema solo por coincidir. El resto de
    /// `seededTransferNames` eran normales y se elegían a mano: son los que el relleno separa.
    static let namesThatWereSystemBeforeTheRole: Set<String> = balanceAdjustmentNames.union(transferNames)

    /// El papel que tendría por su nombre una subcategoría de antes del papel, o `nil`.
    ///
    /// Solo cuenta para las que creó Yala (`isDefaultSeed`): las altas del usuario (Categorías, el importador, «Sin
    /// asignar») pasan `isDefaultSeed: false`, así que una creada a mano con el nombre de transferencia queda normal.
    /// Es el puente entre el dato viejo y el papel: lo consultan `systemRole` mientras el relleno no ha escrito el campo
    /// y el propio relleno al escribirlo.
    static func inferredSystemRole(name: String, isDefaultSeed: Bool) -> SubcategorySystemRole? {
        guard isDefaultSeed else { return nil }
        if balanceAdjustmentNames.contains(name) { return .balanceAdjustment }
        if transferNames.contains(name) || seededTransferNames.contains(name) { return .transfer }
        return nil
    }

    /// El papel de la subcategoría: el guardado, o el que se deduce de una subcategoría de antes mientras el relleno no
    /// lo escribe. Asignar `nil` lo borra.
    var systemRole: SubcategorySystemRole? {
        get {
            if let raw = systemRoleRaw, let role = SubcategorySystemRole(rawValue: raw) { return role }
            return Self.inferredSystemRole(name: name, isDefaultSeed: isDefaultSeed)
        }
        set { systemRoleRaw = newValue?.rawValue }
    }

    /// Whether this subcategory is a system subcategory that cannot be deleted. Por papel, no por nombre.
    var isSystemSubcategory: Bool {
        systemRole != nil
    }

    /// True si tiene papel de sistema (transferencia o ajuste) O el flag persistente `isSystem` del puente de Grupos.
    /// Usar este helper en filtros UI/stats que deben ocultar TODA subcat sistema.
    var isAnySystem: Bool {
        isSystemSubcategory || isSystem
    }
}

// MARK: - CloudKit Compatibility

extension Subcategory {
    /// Safe access to category. CloudKit requires optional relationships,
    /// but semantically a Subcategory always has a Category.
    /// Use this for UI/logic where category is guaranteed to exist.
    /// Cached placeholder to avoid creating new Category objects on each access.
    private static let placeholderCategory = Category(name: "Unknown", colorHex: "#6366F1", isIncome: false)

    var safeCategory: Category {
        guard let cat = category else {
            #if DEBUG
            print("Subcategory: Warning: '\(name)' has no category — returning placeholder")
            #endif
            return Self.placeholderCategory
        }
        return cat
    }
}
