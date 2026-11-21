//
//  NuevoRegistroB1Logic.swift
//  Yala
//
//  Nuevo registro, hoja B1 y éxito minimalista (elegidos por Jürgen el 2026-11-20, 06:14; ficha
//  `tickets/done/2026-11-19-nuevo-registro-b-realista-maquetas.md`). Lo que decide la hoja sin pintar nada, para
//  fijarlo con tests (`YalaTests/NuevoRegistroB1/`):
//
//  - `DescriptionAutofillLogic`: al elegir una sugerencia de descripción, qué cuenta, subcategoría y etiquetas se ponen
//    solas (ajuste 4 de Jürgen).
//  - `OneLineChipRowLogic`: el ancho de cada chip de la fila de abajo, que va SIEMPRE en una línea (ajuste 1).
//  - `AmountCurrencyMenuLogic`: las monedas que ofrece la cápsula «S/ ▾» y a qué cuenta lleva cada una.
//  - `NewRecordTitleLogic`, `TagCountChipLogic` y `TransactionSuccessFieldOrder`: textos y orden.
//

import CoreGraphics
import Foundation

// MARK: - Autocompletar al elegir una sugerencia (ajuste 4)

/// Lo que tuvo un registro anterior con la misma descripción. Genérico en el identificador para probarlo sin SwiftData.
struct DescriptionAutofillSample<ID: Hashable>: Equatable {
    var account: ID?
    var subcategory: ID?
    var tags: Set<UUID>
}

/// Lo que TODOS los registros anteriores con esa descripción tienen en común, dato por dato. `nil` = no coinciden (o no
/// hay), y ese dato no se toca.
struct DescriptionAutofillConsensus<ID: Hashable>: Equatable {
    var account: ID?
    var subcategory: ID?
    /// El mismo conjunto de etiquetas en todos, y no vacío.
    var tags: Set<UUID>?

    static var none: DescriptionAutofillConsensus { DescriptionAutofillConsensus(account: nil, subcategory: nil, tags: nil) }
}

/// Lo que hay ahora en el formulario y de dónde salió, para no pisar lo elegido a mano en este registro.
struct DescriptionAutofillCurrent<ID: Hashable>: Equatable {
    var account: ID?
    /// La cuenta con la que abrió el formulario (la precargada por la regla de la cuenta, L2-1). Si la de ahora es otra,
    /// la eligió la persona.
    var baselineAccount: ID?
    var subcategory: ID?
    var tags: Set<UUID>
    /// Lo que puso el último autocompletado: un dato que sigue igual a eso no lo eligió la persona, y otra sugerencia
    /// puede cambiarlo.
    var lastAutofill: DescriptionAutofillConsensus<ID>
}

enum DescriptionAutofillLogic {

    /// Dato por dato, el valor común a todas las muestras. Un registro sin cuenta o sin subcategoría rompe el acuerdo de
    /// ese dato; las etiquetas cuentan si todas tienen exactamente las mismas, y alguna.
    static func consensus<ID: Hashable>(_ samples: [DescriptionAutofillSample<ID>]) -> DescriptionAutofillConsensus<ID> {
        guard let first = samples.first else { return .none }
        let account = first.account.flatMap { value in samples.allSatisfy { $0.account == value } ? value : nil }
        let subcategory = first.subcategory.flatMap { value in samples.allSatisfy { $0.subcategory == value } ? value : nil }
        let tags: Set<UUID>? = !first.tags.isEmpty && samples.allSatisfy { $0.tags == first.tags } ? first.tags : nil
        return DescriptionAutofillConsensus(account: account, subcategory: subcategory, tags: tags)
    }

    /// Qué se pone. Un dato sin acuerdo no se toca, y tampoco uno que la persona ya eligió en este registro:
    /// - la cuenta, si es distinta de la precargada al abrir (y de la que puso el autocompletado);
    /// - la subcategoría y las etiquetas, si ya hay alguna puesta que no venga del autocompletado.
    static func plan<ID: Hashable>(
        _ consensus: DescriptionAutofillConsensus<ID>, current: DescriptionAutofillCurrent<ID>
    ) -> DescriptionAutofillConsensus<ID> {
        let accountIsHandPicked = current.account != nil
            && current.account != current.baselineAccount
            && current.account != current.lastAutofill.account
        let subcategoryIsHandPicked = current.subcategory != nil && current.subcategory != current.lastAutofill.subcategory
        let tagsAreHandPicked = !current.tags.isEmpty && current.tags != current.lastAutofill.tags
        return DescriptionAutofillConsensus(
            account: accountIsHandPicked ? nil : consensus.account,
            subcategory: subcategoryIsHandPicked ? nil : consensus.subcategory,
            tags: tagsAreHandPicked ? nil : consensus.tags
        )
    }

    /// La clave del índice: el lado (gasto o ingreso) y el texto normalizado, como las sugerencias.
    static func key(note: String, isIncome: Bool) -> String {
        (isIncome ? "i:" : "e:") + DescriptionSuggestionLogic.normalize(note.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// El índice por descripción, con el acuerdo de cada una.
    static func index<ID: Hashable>(
        rows: [(note: String, isIncome: Bool, sample: DescriptionAutofillSample<ID>)]
    ) -> [String: DescriptionAutofillConsensus<ID>] {
        var grouped: [String: [DescriptionAutofillSample<ID>]] = [:]
        for row in rows {
            let key = key(note: row.note, isIncome: row.isIncome)
            guard key.count > 2 else { continue }
            grouped[key, default: []].append(row.sample)
        }
        return grouped.mapValues { consensus($0) }
    }
}

// MARK: - La fila de abajo en una sola línea (ajuste 1)

/// Reparto del ancho de la fila de chips de abajo. Nunca hay segunda fila: si no cabe todo, se encogen los chips
/// flexibles (el nombre de la cuenta, o el origen y el destino de una transferencia), que truncan su texto; los fijos
/// («Hoy», «#2») conservan su ancho. Solo si ni así cabe (texto enorme en un iPhone SE) encogen también los fijos.
enum OneLineChipRowLogic {
    /// El mínimo de un chip flexible: icono y un par de letras.
    static let minimumFlexibleWidth: CGFloat = 64

    static func widths(ideals: [CGFloat], flexible: [Bool], maxWidth: CGFloat, spacing: CGFloat) -> [CGFloat] {
        guard !ideals.isEmpty else { return [] }
        let gaps = spacing * CGFloat(ideals.count - 1)
        let available = max(0, maxWidth - gaps)
        if ideals.reduce(0, +) <= available { return ideals }

        let fixedTotal = zip(ideals, flexible).filter { !$0.1 }.map(\.0).reduce(0, +)
        let flexibleIndices = flexible.indices.filter { flexible[$0] }
        let flexibleRoom = available - fixedTotal
        let minimumFlexibleTotal = flexibleIndices.map { min(ideals[$0], minimumFlexibleWidth) }.reduce(0, +)

        if flexibleRoom >= minimumFlexibleTotal {
            var result = ideals
            let shares = fairShares(flexibleIndices.map { ideals[$0] }, room: flexibleRoom)
            for (offset, index) in flexibleIndices.enumerated() { result[index] = shares[offset] }
            return result
        }
        // Ni con los flexibles al mínimo: todos comparten lo que hay, sin que ninguno pase de su ideal.
        return fairShares(ideals, room: available)
    }

    /// Reparte `room` entre los que piden `ideals` como un llenado de agua: nadie recibe más de lo que pide, y lo que
    /// sobra a uno corto se lo llevan los demás a partes iguales.
    static func fairShares(_ ideals: [CGFloat], room: CGFloat) -> [CGFloat] {
        var result = Array(repeating: CGFloat(0), count: ideals.count)
        var pending = Array(ideals.indices)
        var left = max(0, room)
        while !pending.isEmpty {
            let share = left / CGFloat(pending.count)
            let satisfied = pending.filter { ideals[$0] <= share }
            if satisfied.isEmpty {
                for index in pending { result[index] = share }
                return result
            }
            for index in satisfied {
                result[index] = ideals[index]
                left -= ideals[index]
            }
            pending.removeAll { satisfied.contains($0) }
        }
        return result
    }
}

// MARK: - El estimado junto al monto (ajuste 5)

enum AmountEstimatePlacementLogic {
    /// El estimado va a la derecha del monto si caben los dos a lo ancho; si no, debajo.
    static func isInline(mainWidth: CGFloat, estimateWidth: CGFloat, spacing: CGFloat, maxWidth: CGFloat) -> Bool {
        guard maxWidth.isFinite else { return true }
        return mainWidth + spacing + estimateWidth <= maxWidth
    }
}

// MARK: - La cápsula de moneda «S/ ▾»

/// Una cuenta vista por la cápsula de moneda, sin SwiftData.
struct AmountCurrencyAccount<ID: Hashable>: Equatable {
    let id: ID
    let currencyCode: String
    /// Las cuentas de su tarjeta (la principal y sus líneas vivas), si tiene líneas; si no, vacío.
    var cardMembers: [ID] = []
}

struct AmountCurrencyOption: Equatable, Identifiable {
    let currencyCode: String
    /// Cuántas cuentas hay en esa moneda (una línea de tarjeta cuenta como una).
    let accountCount: Int
    var id: String { currencyCode }
}

enum AmountCurrencyMenuLogic {

    /// Las monedas en las que hay al menos una cuenta, la del formulario primero y el resto por cuántas cuentas tiene y
    /// por código. Con una sola, la cápsula no abre nada.
    static func options<ID: Hashable>(accounts: [AmountCurrencyAccount<ID>], current: String) -> [AmountCurrencyOption] {
        var counts: [String: Int] = [:]
        for account in accounts { counts[account.currencyCode.uppercased(), default: 0] += 1 }
        let currentCode = current.uppercased()
        return counts
            .map { AmountCurrencyOption(currencyCode: $0.key, accountCount: $0.value) }
            .sorted { lhs, rhs in
                if (lhs.currencyCode == currentCode) != (rhs.currencyCode == currentCode) { return lhs.currencyCode == currentCode }
                if lhs.accountCount != rhs.accountCount { return lhs.accountCount > rhs.accountCount }
                return lhs.currencyCode < rhs.currencyCode
            }
    }

    /// La cuenta a la que lleva elegir `code`: la misma si ya está en esa moneda; la línea de su tarjeta en esa moneda si
    /// la tiene; si no, la primera cuenta en esa moneda. `nil` si no hay ninguna.
    static func target<ID: Hashable>(
        for code: String, selected: ID?, accounts: [AmountCurrencyAccount<ID>]
    ) -> ID? {
        let wanted = code.uppercased()
        let byID = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if let selected, let account = byID[selected] {
            if account.currencyCode.uppercased() == wanted { return selected }
            if let line = account.cardMembers.first(where: { byID[$0]?.currencyCode.uppercased() == wanted }) {
                return line
            }
        }
        return accounts.first { $0.currencyCode.uppercased() == wanted }?.id
    }
}

// MARK: - Títulos y textos

enum NewRecordTitleLogic {
    enum Mode: Equatable { case new, edit, duplicate }

    /// «Nuevo gasto», «Editar ingreso», «Duplicar transferencia»…
    static func title(type: TransactionType, mode: Mode) -> String {
        switch (mode, type) {
        case (.new, .expense): return NuevoRegistroB1Text.string("title.newExpense")
        case (.new, .income): return NuevoRegistroB1Text.string("title.newIncome")
        case (.new, .transfer): return NuevoRegistroB1Text.string("title.newTransfer")
        case (.edit, .expense): return NuevoRegistroB1Text.string("title.editExpense")
        case (.edit, .income): return NuevoRegistroB1Text.string("title.editIncome")
        case (.edit, .transfer): return NuevoRegistroB1Text.string("title.editTransfer")
        case (.duplicate, .expense): return NuevoRegistroB1Text.string("title.duplicateExpense")
        case (.duplicate, .income): return NuevoRegistroB1Text.string("title.duplicateIncome")
        case (.duplicate, .transfer): return NuevoRegistroB1Text.string("title.duplicateTransfer")
        }
    }

    /// El título abre el menú de tipo solo en un registro nuevo con los tres tipos a mano: no al editar ni tras
    /// Duplicar (el tipo es el del registro), ni en «solo gastos», ni en lo que viene de un grupo.
    static func opensTypeMenu(mode: Mode, isExpensesOnly: Bool, isFromGroup: Bool) -> Bool {
        mode == .new && !isExpensesOnly && !isFromGroup
    }
}

enum TagCountChipLogic {
    /// «#2» con etiquetas; «#» sin ninguna.
    static func label(count: Int) -> String {
        count > 0 ? "#\(count)" : "#"
    }

    /// Lo que lee VoiceOver: «Etiquetas» sin ninguna; con ellas, cuántas y cuáles.
    static func accessibilityLabel(names: [String]) -> String {
        guard !names.isEmpty else { return NuevoRegistroB1Text.string("tags.a11yNone") }
        return String(format: NuevoRegistroB1Text.string("tags.a11yCount"), names.count, names.joined(separator: ", "))
    }
}

/// El orden de los datos en la pantalla de éxito minimalista (ajuste 3): la descripción va suelta sobre el monto y,
/// después, por importancia: fecha, cuenta, subcategoría, naturaleza y etiqueta (solo si tiene). En una transferencia,
/// fecha y las dos cuentas.
enum TransactionSuccessFieldOrder {
    enum Field: Equatable { case date, account, transferAccounts, subcategory, need, tags }

    static func fields(isTransfer: Bool, hasSubcategory: Bool, hasNeed: Bool, hasTags: Bool) -> [Field] {
        if isTransfer { return [.date, .transferAccounts] }
        var fields: [Field] = [.date, .account]
        if hasSubcategory { fields.append(.subcategory) }
        if hasNeed { fields.append(.need) }
        if hasTags { fields.append(.tags) }
        return fields
    }
}

// MARK: - Tabla de textos propia

/// Los textos de la hoja B1, en su propia tabla (`NuevoRegistroB1.strings`), leídos con el idioma de la app. Nunca en
/// `Localizable.strings`.
enum NuevoRegistroB1Text {
    static let table = "NuevoRegistroB1"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "nr.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// Las claves de la tabla, para el test de los 16 idiomas.
    static let allKeys: [String] = [
        "title.newExpense", "title.newIncome", "title.newTransfer",
        "title.editExpense", "title.editIncome", "title.editTransfer",
        "title.duplicateExpense", "title.duplicateIncome", "title.duplicateTransfer",
        "title.a11yChangeType", "favorites.label", "favorites.seeAll",
        "currency.accountsCount.one", "currency.accountsCount.other", "currency.a11y",
        "more.a11y", "more.splitState.all", "more.splitState.mine", "more.favorite",
        "more.recurring", "more.recurringState.once",
        "save.withAmount", "addAnother",
        "saved.toast.expense", "saved.toast.income", "saved.toast.transfer",
        "success.saved.expense", "success.saved.income", "success.saved.transfer",
        "success.favorite", "success.favorited", "success.recurring",
        "tags.a11yNone", "tags.a11yCount", "need.a11yChange",
    ]
}
