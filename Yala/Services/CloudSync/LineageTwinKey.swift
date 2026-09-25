//
//  LineageTwinKey.swift
//  Yala
//
//  La CLAVE DE LINAJE de una fila de identidad sintética (ticket
//  `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`). Responde «¿esta fila local sin identidad del
//  backend es la MISMA que aquella fila viva del backend que aquí falta?» sin identidad compartida: la usa la prueba de
//  cobertura del relevo y del adopt (`MigrationWorkExecutor.adoptSharedRowsProof`) para casar las filas del líder cuyas
//  identidades no llegaron por iCloud, y para saber que una fila que falta no tiene gemela aquí (se borró aquí, o no
//  llegó) y no se puede duplicar.
//
//  **No es el ancla de contenido** (`SyncContentAnchor`), que lleva importe y fecha: un movimiento del líder editado aquí
//  durante la espera no casaría. La clave usa lo que viaja con la fila por CloudKit y NO se edita:
//  - movimientos, borradores y favoritos → `created_at` en ms (el `physicalMillis` del codec; el wire lo trunca igual);
//  - comercios → `merchant_canonical` (su clave natural);
//  - categorías SEMILLA → la clave del deduplicador (`icon|color|isIncome`, la de
//    `CategoryDeduplicationService.identityKey`): casa la semilla de este teléfono con la del líder que el deduplicador
//    fundió, aunque cada teléfono la sembrara en su idioma. Icono y color se pueden editar, pero la clave solo CASA: una
//    edición hace que no case, y eso deja la fila sospechosa, que es el lado seguro.
//  - categorías del usuario → SIN clave. Su única clave posible es el nombre, y renombrar para fundir dos categorías
//    («borro Gym, renombro Sport a Gym») casaría la fila de Sport con la identidad de Gym (lo cazó la review).
//
//  **Casar es la única conclusión que se saca de la clave.** Que NO case no prueba nada: el `createdAt` de las filas
//  anteriores a su columna lo rellenó cada teléfono por su cuenta en la migración ligera. Y solo se casa con una clave
//  ÚNICA en los dos lados (lo decide `adoptSharedRowsProof`).
//
//  **La clave de FUSIÓN** (`fusion`) es otra cosa: la de los deduplicadores que corren en cada arranque (categorías y
//  subcategorías semilla, avisos de sistema). No re-identifica nada; dice que, si esa fila sube duplicada, el deduplicador
//  del otro lado la vuelve a fundir.
//
//  `nonisolated` y sobre primitivos: el llamador `@MainActor` extrae los valores del `@Model`, y el lado del backend
//  sale de los `fields` del delta. Las tablas van en literal porque `EntityEmissionMap` es `@MainActor`; un test fija
//  que coinciden.
//

import Foundation

nonisolated enum LineageTwinKey {

    /// Tablas cuya identidad de sync (`syncID`) la ACUÑA cada teléfono y viaja aparte de la fila: las seis de
    /// `SyncIdentityService`. En las demás la identidad es un UUID persistido que nace con la fila.
    static let syntheticTables: Set<String> = [
        "tx_items", "inbox_drafts", "categories", "favorite_payments", "merchant_memory", "exchange_rates",
    ]

    // MARK: - Lado local (primitivos del `@Model`)

    /// Movimientos, borradores y favoritos: el instante de creación en ms.
    static func created(_ createdAt: Date) -> String {
        "t:\(CanonicalTime.physicalMillis(from: createdAt))"
    }

    /// Categorías: la clave del deduplicador si es semilla; sin clave si no (ver la cabecera).
    static func category(isDefaultSeed: Bool, iconName: String?, colorHex: String, isIncome: Bool) -> String? {
        isDefaultSeed ? "seed:\(iconName ?? "nil")|\(colorHex)|\(isIncome)" : nil
    }

    /// Comercios: su clave canónica.
    static func merchant(_ merchantCanonical: String) -> String {
        "m:\(merchantCanonical)"
    }

    // MARK: - Lado del backend (los `fields` de un upsert enumerado)

    /// La clave de una fila viva del backend, o `nil` si su tabla no la tiene o los campos no se dejan leer. `nil` NO es
    /// «sin gemela»: el llamador lo trata como «puede ser cualquiera» y espera.
    static func backend(table: String, fields: [String: WireValue]) -> String? {
        switch table {
        case "tx_items", "inbox_drafts", "favorite_payments":
            guard case .string(let iso)? = fields["created_at"], let ms = WireValueDecoder.millisFromISO(iso) else {
                return nil
            }
            return "t:\(ms)"
        case "merchant_memory":
            guard case .string(let canonical)? = fields["merchant_canonical"] else { return nil }
            return merchant(canonical)
        case "categories":
            guard case .bool(let isSeed)? = fields["is_default_seed"] else { return nil }
            if isSeed {
                guard case .string(let color)? = fields["color_hex"], case .bool(let isIncome)? = fields["is_income"],
                      let iconValue = fields["icon_name"] else { return nil }
                let icon: String?
                switch iconValue {
                case .null: icon = nil
                case .string(let s): icon = s
                default: return nil
                }
                return category(isDefaultSeed: true, iconName: icon, colorHex: color, isIncome: isIncome)
            }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Clave de fusión (los deduplicadores del arranque)

    /// Subcategoría semilla: su icono, el criterio con el que `CategoryDeduplicationService` funde las subcategorías de dos
    /// categorías semilla fundidas.
    static func subcategorySeedFusion(iconName: String?) -> String {
        "subseed:\(iconName ?? "nil")"
    }

    /// Aviso de sistema: su tipo (`NotificationService.deduplicateNotifications` agrupa por `typeRaw`). Los `custom` no:
    /// son recordatorios de la persona, no copias de una semilla.
    static func notificationFusion(typeRaw: String) -> String? {
        typeRaw == "custom" ? nil : "notif:\(typeRaw)"
    }

    /// La clave de fusión de una fila viva del backend, o `nil` si no la tiene (no es semilla, o no se lee).
    static func fusion(table: String, fields: [String: WireValue]) -> String? {
        switch table {
        case "categories":
            return backend(table: table, fields: fields)
        case "subcategories":
            guard case .bool(true)? = fields["is_default_seed"], let iconValue = fields["icon_name"] else { return nil }
            switch iconValue {
            case .null: return subcategorySeedFusion(iconName: nil)
            case .string(let s): return subcategorySeedFusion(iconName: s)
            default: return nil
            }
        case "notification_items":
            guard case .string(let type)? = fields["type_raw"] else { return nil }
            return notificationFusion(typeRaw: type)
        default:
            return nil
        }
    }
}
