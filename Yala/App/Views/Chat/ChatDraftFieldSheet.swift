//
//  ChatDraftFieldSheet.swift
//  Yala
//
//  Los selectores de un registro propuesto por Yala IA son LOS MISMOS de Nuevo registro —subcategoría con su
//  rejilla de iconos, cuenta, calendario y etiquetas—, para que corregir un borrador se sienta igual que crear un
//  registro a mano (decisión de Jürgen, 2026-10-04). Esta vista los presenta desde la card y desde su hoja de
//  detalles con un solo `.sheet(item:)` por anfitrión.
//
//  El borrador guarda IDs y los selectores trabajan con modelos: aquí se traduce en los dos sentidos. La selección
//  arranca con los modelos ya resueltos por quien presenta (sus `@Query`), y cada cambio vuelve al ViewModel como ID
//  por los mismos callbacks que usaba la card. La divisa la sincroniza el ViewModel al cambiar de cuenta.
//

import SwiftUI
import SwiftData

/// Qué dato del borrador se está eligiendo.
enum ChatDraftField: String, Identifiable {
    case subcategory, account, date, tags

    var id: String { rawValue }
}

/// Los callbacks con los que la card y su hoja cambian el borrador. Son los de `ChatTransactionDraftCard`,
/// agrupados para no repetirlos en cada vista que los necesita.
struct ChatDraftEditing {
    var onAmountChange: (Decimal?) -> Void
    var onAccountChange: (PersistentIdentifier?) -> Void
    var onSubcategoryChange: (PersistentIdentifier?) -> Void
    var onDateChange: (Date) -> Void
    var onTagsChange: ([PersistentIdentifier]) -> Void
    var onNoteChange: (String) -> Void
}

struct ChatDraftFieldSheet: View {
    let field: ChatDraftField
    let isExpense: Bool
    let editing: ChatDraftEditing

    @State private var account: Account?
    @State private var subcategory: Subcategory?
    @State private var tags: [Tag]
    @State private var date: Date

    init(
        field: ChatDraftField,
        isExpense: Bool,
        account: Account?,
        subcategory: Subcategory?,
        tags: [Tag],
        date: Date,
        editing: ChatDraftEditing
    ) {
        self.field = field
        self.isExpense = isExpense
        self.editing = editing
        _account = State(initialValue: account)
        _subcategory = State(initialValue: subcategory)
        _tags = State(initialValue: tags)
        _date = State(initialValue: date)
    }

    // Un `onChange` por rama, no cuatro encadenados: el compilador del CI (Xcode 26.6) no tipa bien cadenas largas
    // de modificadores (`.claude/rules/swiftui-ds.md`).
    var body: some View {
        switch field {
        case .subcategory:
            SubcategorySelectorSheet(
                selectedSubcategory: $subcategory,
                transactionType: isExpense ? .expense : .income,
                sizing: .mediumFirst
            )
            .onChange(of: subcategory) { _, new in editing.onSubcategoryChange(new?.persistentModelID) }
        case .account:
            AccountSelectorSheet(selectedAccount: $account, title: L10n.Transaction.account, sizing: .mediumFirst)
                .onChange(of: account) { _, new in editing.onAccountChange(new?.persistentModelID) }
        case .date:
            DatePickerSheet(selectedDate: $date)
                .onChange(of: date) { _, new in editing.onDateChange(new) }
        case .tags:
            TagSelectorSheet(selectedTags: $tags, sizing: .mediumFirst)
                .onChange(of: tags) { _, new in editing.onTagsChange(new.map(\.persistentModelID)) }
        }
    }
}
