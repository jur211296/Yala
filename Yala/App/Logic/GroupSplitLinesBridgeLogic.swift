//
//  GroupSplitLinesBridgeLogic.swift
//  Yala
//
//  Grupos B · card 2. Qué hace el PUENTE con la receta de líneas (`GroupSplitLinesRecipe`) en cada pasada: si la
//  aplica, cuál es la línea ANCLA (la que representa la pata que el puente conserva) y qué líneas se convierten en
//  patas derivadas. El diseño está en `tickets/in-progress/grupos-tu-parte-en-lineas.md` (D1-D8) y las decisiones que
//  esta card concretó, en el Paso 0 del encargo `2026-11-01-grupos-b-puente-y-estadisticas`.
//
//  LA LÍNEA ANCLA es la primera línea de GASTO; sin ninguna de gasto, en el Caso B la primera línea (una recarga) y en
//  el Caso A ninguna. Las demás son DERIVADAS: cada una, una pata en la cuenta «Grupos» del gasto (D1), y una recarga
//  además su entrada en la cuenta destino.
//   · Caso B (pagó otro): la pata conservada vale `−ancla` y las derivadas, `−x`. Grupos suma `−tu parte`.
//   · Caso A (pagaste tú): la pata real sigue en `−total`, el préstamo engorda en lo que suman las derivadas
//     (`+(lent + Σderivadas)`) y la real netea a la línea ancla en Estadísticas sin cambiar el ajuste.
//
//  CUÁNDO NO SE APLICA, y entonces tu parte va en una sola pata como siempre y la receta se CONSERVA (D5-D7):
//  puente apagado o sesión solo-grupos (`gateOpen == false`), sin receta, receta ilegible o de una versión posterior,
//  líneas con problemas, líneas que no suman tu parte (`.mismatch`: el puente avisa en la Bandeja, D6), o una cuenta
//  destino que aquí no existe, es de sistema o lleva otra divisa (`.destinationUnavailable`: puede ser una ventana de
//  sync y se recupera sola en la pasada siguiente, así que no avisa).
//
//  Lógica pura: las cuentas destino llegan resueltas por quien llama.
//

import Foundation

enum GroupSplitLinesBridgeLogic {

    /// Lo que el puente sabe de una cuenta destino de una recarga, resuelta por su `shortcutID`.
    struct DestinationInfo: Equatable, Sendable {
        let currencyCode: String
        let isSystemAccount: Bool
    }

    /// Las patas que salen de una receta que se aplica.
    struct Plan: Equatable, Sendable {
        /// La línea que representa la pata conservada. `nil` solo en el Caso A sin líneas de gasto.
        let anchor: GroupSplitLinesRecipe.Line?
        /// Las líneas que se convierten en patas derivadas, en el orden de la receta.
        let derived: [GroupSplitLinesRecipe.Line]

        /// Lo que el préstamo del Caso A suma a `lent`: las derivadas se apuntan en «Grupos» y la pata real netea a la
        /// línea ancla.
        var extraLoan: Decimal { derived.reduce(Decimal(0)) { $0 + $1.amount } }
    }

    enum Decision: Equatable, Sendable {
        /// Tu parte en una sola pata, sin aviso. La receta, si la hay, se queda donde está.
        case singleLine
        /// La receta es buena pero no suma tu parte: una sola pata, receta conservada y borrador en la Bandeja.
        case mismatch(GroupSplitLinesRecipe.Balance)
        /// Alguna cuenta destino no está disponible aquí: una sola pata, sin aviso.
        case destinationUnavailable
        case apply(Plan)
    }

    /// La línea ancla: la primera de gasto; sin ninguna, la primera en el Caso B y ninguna en el Caso A.
    static func anchorIndex(in lines: [GroupSplitLinesRecipe.Line], isCaseA: Bool) -> Int? {
        if let firstExpense = lines.firstIndex(where: { $0.kind == .expense }) { return firstExpense }
        return isCaseA || lines.isEmpty ? nil : 0
    }

    /// Qué hace el puente con lo guardado en la pata conservada.
    /// - Parameters:
    ///   - gateOpen: puente activo y sesión privada (D5). En el Caso A, además, que exista la pata real.
    ///   - share: tu parte del gasto (`SplitShare.amount`).
    ///   - destinations: las cuentas destino conocidas, por `shortcutID`. Una que falta no está disponible.
    static func decide(
        stored: GroupSplitLinesRecipe.Stored,
        gateOpen: Bool,
        isCaseA: Bool,
        share: Double,
        currencyCode: String,
        destinations: [UUID: DestinationInfo]
    ) -> Decision {
        guard gateOpen, case let .recipe(lines) = stored else { return .singleLine }
        guard GroupSplitLinesRecipe.problems(in: lines, currencyCode: currencyCode).isEmpty else { return .singleLine }
        let balance = GroupSplitLinesRecipe.balance(of: lines, share: decimal(share), currencyCode: currencyCode)
        guard balance == .balanced else { return .mismatch(balance) }
        for line in lines where line.kind == .transfer {
            guard let id = line.destinationAccountID, let destination = destinations[id],
                  !destination.isSystemAccount, destination.currencyCode == currencyCode
            else { return .destinationUnavailable }
        }
        let anchor = anchorIndex(in: lines, isCaseA: isCaseA)
        let derived = lines.enumerated().filter { $0.offset != anchor }.map(\.element)
        return .apply(Plan(anchor: anchor.map { lines[$0] }, derived: derived))
    }

    /// Las cuentas destino que una receta necesita resolver. Vacío si no es una receta.
    static func destinationIDs(in stored: GroupSplitLinesRecipe.Stored) -> Set<UUID> {
        guard case let .recipe(lines) = stored else { return [] }
        return Set(lines.compactMap(\.destinationAccountID))
    }

    /// Un `Double` de reparto como `Decimal`, por su texto: `Decimal(Double)` arrastra la cola binaria (30 → 30.0000…04).
    static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    /// Un importe de línea como `Double`, para escribirlo en un `TransactionItem`.
    static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    /// `true` si lo guardado en una pata la marca como derivada de una línea, también con una marca de una versión
    /// posterior (D7): sin esto, la pata derivada de un aparato más nuevo competiría aquí como si llevara la receta y su
    /// entrada se quedaría sin dueño.
    static func isDerivedMarker(_ raw: String?) -> Bool {
        switch GroupSplitLinesRecipe.parse(raw) {
        case .derived: return true
        case .newerVersion: return looksLikeMarker(raw)
        case .none, .recipe, .unreadable: return false
        }
    }

    /// El id de línea de una pata derivada, o `nil`.
    static func derivedLineID(_ raw: String?) -> UUID? {
        if case let .derived(lineID) = GroupSplitLinesRecipe.parse(raw) { return lineID }
        return nil
    }

    /// `true` si lo guardado puede ser una receta (también una que este build no entiende): esa pata tiene prioridad para
    /// quedarse como la conservada, y nunca se trata como derivada.
    static func mayCarryRecipe(_ raw: String?) -> Bool {
        switch GroupSplitLinesRecipe.parse(raw) {
        case .recipe, .unreadable: return true
        case .newerVersion: return !looksLikeMarker(raw)
        case .none, .derived: return false
        }
    }

    /// El id de línea al que pertenece una ENTRADA de recarga: su marca o, si se la quitaron, su par.
    static func entryLineID(_ entry: TransactionItem) -> UUID? {
        derivedLineID(entry.splitLinesRaw) ?? entry.transferPairID.flatMap { UUID(uuidString: $0) }
    }

    /// El orden con que dos aparatos eligen el MISMO superviviente entre copias de una pata (regla «Fundir duplicados
    /// que llegan de dos dispositivos»): la más antigua y, a igualdad, la de menor identidad de sync.
    static func survivorFirst(_ a: TransactionItem, _ b: TransactionItem) -> Bool {
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return (a.syncID?.uuidString ?? "") < (b.syncID?.uuidString ?? "")
    }

    /// Una marca de una versión que este build no conoce: un objeto con `of` y sin `l`. No se lee su id.
    private static func looksLikeMarker(_ raw: String?) -> Bool {
        guard let data = raw?.data(using: .utf8) else { return false }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return object["of"] != nil && object["l"] == nil
        } catch {
            return false
        }
    }
}
