//
//  RegistroB1PantallasWiringTests.swift
//  YalaTests
//
//  La hoja B1 en todas las pantallas de registro (encargo del 20-nov) y los tres ajustes de Jürgen sobre ella. Es un
//  escaneo del código: las vistas no se pueden montar aquí, y lo que se fija es qué pieza usa cada pantalla. Que la fila
//  quepa en una línea lo fija `OneLineChipRowLogic` (NuevoRegistroB1LogicTests) y la colocación, los XCUITest
//  `RegistroUnificadoUITests` y `RegistroB1OtrasPantallasUITests`.
//

import Foundation
import Testing

@Suite("Hoja B1 en todas las pantallas de registro")
struct RegistroB1PantallasWiringTests {

    private static func code(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        // Sin comentarios: documentar una pieza no puede contar como usarla.
        return source.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: " ")
    }

    /// Las pantallas con su fila de abajo en UNA línea (`OneLineChipRow`) y sin el contenedor de filas que bajan de
    /// antes (`RecordSelectorChips`) ni la pastilla grande de fecha arriba (`RecordPillButton`).
    @Test(arguments: [
        "Yala/App/Views/Transactions/NewTransactionView.swift",
        "Yala/App/Views/Inbox/InboxDraftEditSheet.swift",
        "Yala/App/Views/Groups/GroupExpenseFormView.swift",
        "Yala/App/Views/Inbox/GroupDraftFinalizationScaffold.swift",
        "Yala/App/Views/Groups/SettlementFormView.swift",
        "Yala/App/Views/Favorites/FavoriteEditorView.swift",
    ])
    func cadaPantalla_llevaLaFilaDeUnaLinea(path: String) throws {
        let code = try Self.code(path)
        #expect(code.contains("OneLineChipRow("), "\(path): falta la fila de abajo de una línea.")
        #expect(!code.contains("RecordSelectorChips("), "\(path): vuelven las filas que bajan.")
        #expect(!code.contains("RecordPillButton("), "\(path): vuelve la pastilla de fecha arriba.")
    }

    /// La cápsula de moneda a la izquierda del monto en todas.
    @Test(arguments: [
        "Yala/App/Views/Transactions/NewTransactionView.swift",
        "Yala/App/Views/Inbox/InboxDraftEditSheet.swift",
        "Yala/App/Views/Groups/GroupExpenseFormView.swift",
        "Yala/App/Views/Inbox/GroupDraftFinalizationScaffold.swift",
        "Yala/App/Views/Groups/SettlementFormView.swift",
        "Yala/App/Views/Favorites/FavoriteEditorView.swift",
    ])
    func cadaPantalla_llevaLaCapsulaDeMoneda(path: String) throws {
        #expect(try Self.code(path).contains("AmountCurrencyCapsule("), "\(path): falta la cápsula de moneda.")
    }

    /// La subcategoría bajo el monto con su línea «● Categoría · ● Necesidad ▾», donde se elige.
    @Test(arguments: [
        "Yala/App/Views/Transactions/NewTransactionView.swift",
        "Yala/App/Views/Inbox/InboxDraftEditSheet.swift",
        "Yala/App/Views/Groups/GroupExpenseFormView.swift",
        "Yala/App/Views/Inbox/GroupExpenseDraftFinalizationSheet.swift",
        "Yala/App/Views/Inbox/GroupExpenseAccountAndSubcategoryFinalizationSheet.swift",
        "Yala/App/Views/Favorites/FavoriteEditorView.swift",
    ])
    func laSubcategoria_llevaSuLineaDeCategoria(path: String) throws {
        let code = try Self.code(path)
        #expect(code.contains("CategoryNeedLine("), "\(path): falta «● Categoría» bajo la subcategoría.")
        #expect(code.contains("fillsWhenSelected: true"), "\(path): la subcategoría elegida va rellena.")
    }

    // MARK: - Ajustes de Jürgen del 20-nov

    @Test func sinLaLineaAhoraEn() throws {
        let code = try Self.code("Yala/App/Views/Transactions/NewTransactionView.swift")
        #expect(!code.contains("new_transaction_currency_notice"), "Vuelve la línea «Ahora en…».")
        #expect(!code.contains("Label(AmountCurrencyNoticeLogic.text"), "Vuelve la línea «Ahora en…».")
        // VoiceOver sí sigue oyendo el cambio.
        #expect(code.contains("AccessibilityNotification.Announcement(AmountCurrencyNoticeLogic.text(for: next))"))
    }

    @Test func elTipoDeCambio_vaEnCapsulaGlass() throws {
        let code = try Self.code("Yala/App/Views/Transactions/Components/ExchangeRateCapsule.swift")
        #expect(code.contains(".glassEffect(.regular.interactive(), in: .capsule)"))
        #expect(!code.contains("theme.accent.opacity(0.12)"), "Vuelve el relleno de acento.")
    }

    /// El título-menú y «···» de la barra, en primary: un `Menu` en la barra toma el tinte índigo del tema.
    @Test(arguments: [
        "Yala/App/Views/Transactions/NewTransactionView.swift",
        "Yala/App/Views/Inbox/InboxDraftEditSheet.swift",
    ])
    func losMenusDeLaBarra_vanEnPrimary(path: String) throws {
        let code = try Self.code(path)
        let tints = code.components(separatedBy: ".tint(Color.primary)").count - 1
        #expect(tints >= 2, "\(path): el título-menú y «···» llevan `.tint(Color.primary)` (\(tints)).")
    }
}
