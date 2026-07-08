//
//  SyncContentAnchor.swift
//  Yala
//
//  Ancla de contenido DETERMINISTA por entidad (Modo Nube, incremento I2, spec §b.3). Dada la
//  identidad de una fila borrada+recreada con el MISMO contenido, permite recuperar (REBIND) su
//  `syncID` original en vez de acuñar uno nuevo → evita que un borrado+recreación local se
//  interprete como una entidad distinta en el sync.
//
//  Contrato de determinismo (CROSS-PROCESO y CROSS-DISPOSITIVO):
//  - Los componentes se serializan de forma canónica, se unen con "|" y se hashean con SHA-256
//    (CryptoKit) a hex lowercase.
//  - PROHIBIDO `Hasher`/`hashValue`: usan un seed aleatorio por proceso → producirían anclas
//    distintas en cada arranque y romperían el rebind. SHA-256 es estable siempre.
//
//  Reglas de serialización canónica de componentes:
//  - Fechas → ms Unix ENTEROS (floor hacia -∞, vía `CanonicalTime.physicalMillis`). Sin zona/locale.
//  - Montos (`Double`/`Double?`) → `String(describing:)` del valor almacenado TAL CUAL. Swift emite
//    la representación más corta que round-trippea el `Double` de forma determinista (p.ej. `12.5`,
//    `12.0`), idéntica en cualquier dispositivo. Residual ACEPTADO: dos montos IGUALES como `Double`
//    producen la misma string (por diseño — mismo contenido ⇒ misma ancla).
//  - `nil` → token `"∅"` (U+2205), inconfundible con cualquier string real serializada.
//  - Strings → tal cual, salvo donde la spec pide normalizar (Category: lowercase + trim).
//
//  `nonisolated`: pura y sin estado; toma PRIMITIVOS (no los `@Model`, que son `@MainActor`), de
//  modo que el llamador `@MainActor` extrae los valores de la fila y esta capa queda testeable con
//  vectores literales fuera del main actor.
//

import CryptoKit
import Foundation

/// Cálculo puro del ancla de contenido de las 6 entidades sincronizables (§b.3).
nonisolated enum SyncContentAnchor {

    /// Token para un componente ausente (`nil`). U+2205 "EMPTY SET" — no colisiona con strings reales.
    static let nilToken = "\u{2205}"

    // MARK: - Anclas por entidad (spec §b.3)

    /// `TransactionItem` = createdAt + date + amount + currencyCode + account?.shortcutID.
    static func transactionItem(
        createdAt: Date,
        date: Date,
        amount: Double,
        currencyCode: String,
        accountShortcutID: UUID?
    ) -> String {
        hash([
            canonicalDate(createdAt),
            canonicalDate(date),
            canonicalAmount(amount),
            currencyCode,
            token(accountShortcutID?.uuidString),
        ])
    }

    /// `Category` = nombre NORMALIZADO (lowercase + trim). Único componente, pero pasa por el
    /// pipeline canónico (join + SHA-256) igual que el resto para uniformidad de formato.
    static func category(name: String) -> String {
        hash([normalized(name)])
    }

    /// `MerchantMemory` = merchantCanonical (ya canonicalizado por su servicio; sin re-normalizar).
    static func merchantMemory(merchantCanonical: String) -> String {
        hash([merchantCanonical])
    }

    /// `ExchangeRate` = dateKey + base. Residual ACEPTADO (spec §b.3/A3): `ExchangeRate` permite
    /// duplicados exactos (mismo dateKey+base), así que sus anclas COLISIONAN — dos filas duplicadas
    /// obtendrían el mismo `syncID`. Es intencional: mismo contenido ⇒ misma identidad; el Merkle del
    /// sync detecta/resuelve el duplicado aguas abajo.
    static func exchangeRate(dateKey: String, base: String) -> String {
        hash([dateKey, base])
    }

    /// `FavoritePayment` = name + amount + createdAt + displayOrder.
    static func favoritePayment(
        name: String,
        amount: Double?,
        createdAt: Date,
        displayOrder: Int
    ) -> String {
        hash([
            name,
            canonicalAmount(amount),
            canonicalDate(createdAt),
            String(describing: displayOrder),
        ])
    }

    /// `InboxDraft` = createdAt + sourceTypeRaw + rawText.
    static func inboxDraft(
        createdAt: Date,
        sourceTypeRaw: String,
        rawText: String?
    ) -> String {
        hash([
            canonicalDate(createdAt),
            sourceTypeRaw,
            token(rawText),
        ])
    }

    // MARK: - Serialización canónica de componentes

    /// Fecha → ms Unix enteros (floor), como string. Determinista, sin zona/locale.
    static func canonicalDate(_ date: Date) -> String {
        String(CanonicalTime.physicalMillis(from: date))
    }

    /// Monto → `String(describing:)` del `Double` almacenado tal cual; `nil` → token.
    static func canonicalAmount(_ amount: Double?) -> String {
        guard let amount else { return nilToken }
        return String(describing: amount)
    }

    /// Componente opcional string → tal cual, o token si `nil`.
    static func token(_ value: String?) -> String {
        value ?? nilToken
    }

    /// Normalización de nombre (Category): lowercase + trim de whitespace/newlines.
    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Hash

    /// Une los componentes con "|" y devuelve el SHA-256 en hex lowercase (64 chars).
    static func hash(_ components: [String]) -> String {
        let joined = components.joined(separator: "|")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
