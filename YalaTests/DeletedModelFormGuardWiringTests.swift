//
//  DeletedModelFormGuardWiringTests.swift
//  YalaTests
//
//  Card 1w89 (ticket `forms-read-their-deleted-model-while-closing`), hermano de `DeletedModelRowGuardWiringTests`: un
//  formulario que borra SU modelo sigue presentado mientras se cierra, y su `body` se vuelve a evaluar al cerrarse la
//  confirmación. En el iPhone (iOS 27.x) leer una propiedad del modelo borrado aborta la app; el simulador 27.0 no, así
//  que ningún XCUITest lo caza. Estos scans fijan que los dos formularios no leen lo que borran después de borrarlo. El
//  mecanismo del ViewModel del editor de registro se prueba en `DeletedRecordFormReleaseTests`.
//

import Foundation
import Testing

@Suite("Formularios que no leen el modelo que borran — cableado (source-scan)")
struct DeletedModelFormGuardWiringTests {

    private static func readSource(of relativePath: String, file: StaticString = #filePath) throws -> String {
        let testFile = URL(fileURLWithPath: "\(file)")
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Líneas de código (trimmeadas, sin comentarios) con el nombre del miembro del tipo que las contiene: la última
    /// declaración `func`/`var`/`init` con cuatro espacios de sangría antes de esa línea.
    private static func codeLinesWithOwner(_ source: String) -> [(owner: String, code: String)] {
        var owner = ""
        var result: [(String, String)] = []
        for raw in source.components(separatedBy: "\n") {
            if let match = raw.firstMatch(of: #/^    (?:@\w+ )*(?:private |fileprivate )?(?:static )?(?:func |var |init)(\w*)/#) {
                owner = match.1.isEmpty ? "init" : String(match.1)
            }
            let code = raw.trimmingCharacters(in: .whitespaces)
            guard !code.isEmpty, !code.hasPrefix("//"), !code.hasPrefix("///") else { continue }
            result.append((owner, code))
        }
        return result
    }

    // MARK: - Formulario de gasto de grupo

    /// El título del diálogo sale de una copia hecha al tocar la papelera, no del gasto.
    @Test func groupExpenseForm_deleteDialogTitle_readsTheCopy() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Groups/GroupExpenseFormView.swift")
        #expect(source.contains("L10n.Groups.Expense.deleteTitle(deleteDialogExpenseName)"))
        #expect(!source.contains("deleteTitle(expenseToEdit"))

        // La copia se hace en el mismo toque que abre el diálogo, y antes de abrirlo.
        let copy = try #require(source.range(of: "deleteDialogExpenseName = expenseToEdit?.expenseDescription ?? \"\""))
        let open = try #require(source.range(of: "showDeleteConfirmation = true", range: copy.upperBound..<source.endIndex))
        let between = source[copy.upperBound..<open.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(between.isEmpty, "Entre la copia y la apertura del diálogo hay código: «\(between)».")
    }

    /// Fuera de la copia, de la acción de borrar y del prefill del `onAppear`, el formulario no lee el gasto.
    @Test func groupExpenseForm_readsTheExpenseOnlyBeforeDeletingIt() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Groups/GroupExpenseFormView.swift")
        let reads = Self.codeLinesWithOwner(source).filter { $0.code.contains("expenseToEdit") }
        let allowed: Set<String> = [
            "let expenseToEdit: SplitExpense?",
            "expenseToEdit: SplitExpense? = nil,",
            "self.expenseToEdit = expenseToEdit",
            "deleteDialogExpenseName = expenseToEdit?.expenseDescription ?? \"\"",
            "if let expense = expenseToEdit {",   // acción de «Eliminar» (borra) y prefill del `onAppear`
        ]
        let unexpected = reads.filter { !allowed.contains($0.code) }.map(\.code)
        #expect(unexpected.isEmpty, "Lecturas nuevas del gasto en el formulario: \(unexpected)")
        // Las dos, y solo dos, que abren el gasto: la acción de «Eliminar» y el prefill del `onAppear`. Una tercera
        // copiaría la línea permitida a otro sitio del `body`.
        #expect(reads.filter { $0.code == "if let expense = expenseToEdit {" }.count == 2)
    }

    // MARK: - Editor de presupuesto y de favorito (mismo barrido)

    /// El título de la alerta de borrado del presupuesto sale de una copia hecha al tocar «Eliminar».
    @Test func budgetEditor_deleteAlertTitle_readsTheCopy() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Planning/BudgetEditorView.swift")
        #expect(source.contains("L10n.UXL9.deleteTitle(deleteDialogBudgetName),"))
        #expect(!source.contains("deleteTitle(budget?"))
        let copy = try #require(source.range(of: "deleteDialogBudgetName = budget?.name ?? name"))
        let open = try #require(source.range(of: "showDeleteConfirmation = true", range: copy.upperBound..<source.endIndex))
        #expect(source[copy.upperBound..<open.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        // Fuera de la copia, de la carga del `onAppear`, del guardado y del borrado, nada lee el presupuesto.
        let allowedOwners: Set<String> = ["loadBudgetData", "saveBudget", "deleteBudget"]
        let unexpected = Self.codeLinesWithOwner(source)
            .filter { $0.code.range(of: #"\bbudget[?!]?\."#, options: .regularExpression) != nil }
            .filter { !allowedOwners.contains($0.owner) }
            .filter { $0.code != "deleteDialogBudgetName = budget?.name ?? name" }
            .map { "\($0.owner): \($0.code)" }
        #expect(unexpected.isEmpty, "Lecturas del presupuesto fuera de los sitios con el presupuesto vivo: \(unexpected)")
    }

    /// «Es una transferencia» se copia al crear la vista, mirando antes de leer; el `body` no lee el favorito.
    @Test func favoriteEditor_readsTheFavoriteOnlyGuardedOrOnAppear() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Favorites/FavoriteEditorView.swift")
        #expect(source.contains("@State private var isTransfer: Bool"))
        #expect(source.contains("_isTransfer = State(initialValue: Self.isTransferFavorite(favorite))"))
        #expect(source.contains("guard let favorite, !favorite.isDeleted, favorite.modelContext != nil else { return false }"))
        #expect(!source.contains("private var isTransfer: Bool { favorite"))

        // Fuera del init, del helper guardado, de la acción de borrar y de la carga del `onAppear`, nada lee el favorito.
        let allowedOwners: Set<String> = ["init", "isTransferFavorite", "loadFavoriteData"]
        let unexpected = Self.codeLinesWithOwner(source)
            .filter { $0.code.range(of: #"\bfavorite\b(\?|!)?\."#, options: .regularExpression) != nil }
            .filter { !allowedOwners.contains($0.owner) }
            .map { "\($0.owner): \($0.code)" }
        #expect(unexpected.isEmpty, "Lecturas del favorito fuera de los sitios con el favorito vivo: \(unexpected)")
    }

    // MARK: - Editor de registro

    /// Las lecturas del registro solo viven en el accesor guardado o en acciones que corren con el registro vivo
    /// (aparecer, borrar, el botón del aviso). Lo demás compara con `nil`, que no lee el modelo.
    @Test func newTransaction_readsTheRecordThroughTheGuard() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Transactions/NewTransactionView.swift")
        let actionsWithTheRecordAlive: Set<String> = [
            "init",
            "readableTransactionToEdit",
            "resolveBridgedPointer",
            "loadPendingGroupDraftIfNeeded",
            "handleBridgedCTA",
            "prefillFromContext",
            "deleteTransaction",
        ]
        let unexpected = Self.codeLinesWithOwner(source)
            .filter { $0.code.contains("transactionToEdit") && !$0.code.contains("readableTransactionToEdit") }
            .filter { !actionsWithTheRecordAlive.contains($0.owner) }
            .filter { !$0.code.contains("transactionToEdit == nil") && !$0.code.contains("transactionToEdit != nil") }
            .filter { $0.code != "let transactionToEdit: TransactionItem?" }
            .map { "\($0.owner): \($0.code)" }
        #expect(unexpected.isEmpty, "Lecturas del registro sin pasar por `readableTransactionToEdit`: \(unexpected)")

        #expect(source.contains("guard let tx = transactionToEdit, !tx.isDeleted, tx.modelContext != nil else { return nil }"))
    }

    /// La alerta de borrado pinta una copia hecha al abrirla, no el registro.
    @Test func newTransaction_deleteAlert_readsTheCopy() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Transactions/NewTransactionView.swift")
        #expect(source.contains("deleteConfirmationText?.title ?? L10n.Alert.confirmDelete,"))
        #expect(source.contains("Text(deleteConfirmationText?.message ?? L10n.Common.cannotUndo)"))
        // «Eliminar» pasa por `askToDelete`, el único sitio que abre la alerta, y ahí la copia va antes de abrirla.
        #expect(source.range(of: #"askToDelete\(\)\s*\}\s*\.accessibilityIdentifier\("new_transaction_delete_action"\)"#,
                             options: .regularExpression) != nil)
        #expect(source.components(separatedBy: "viewModel.showDeleteConfirmation = true").count == 2,
                "Hay otro sitio que abre la alerta sin copiar su texto.")
        let start = try #require(source.range(of: "private func askToDelete() {"))
        let copy = try #require(source.range(of: "deleteConfirmationText = (", range: start.upperBound..<source.endIndex))
        let open = try #require(source.range(of: "viewModel.showDeleteConfirmation = true", range: start.upperBound..<source.endIndex))
        #expect(copy.lowerBound < open.lowerBound, "La alerta se abre antes de copiar su texto.")
    }

    /// Tras borrar y guardar, el ViewModel suelta el registro ANTES de cerrar; la divisa se lee antes de borrar.
    @Test func newTransaction_deleteReleasesTheViewModelBeforeClosing() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Transactions/NewTransactionView.swift")
        let start = try #require(source.range(of: "private func deleteTransaction() {"))
        // Hasta el cierre de la función (la llave a cuatro espacios): dentro hay un `catch` del fetch de la pareja antes
        // del del borrado.
        let end = try #require(source.range(of: "\n    }\n", range: start.upperBound..<source.endIndex))
        let body = String(source[start.upperBound..<end.lowerBound])

        let shown = try #require(body.range(of: "let shownAmountCurrency = viewModel.amountCurrencyCode"))
        let delete = try #require(body.range(of: "modelContext.delete(transaction)"))
        let save = try #require(body.range(of: "try modelContext.save()"))
        let release = try #require(body.range(of: "viewModel.releaseDeletedRecord(keepingAmountCurrency: shownAmountCurrency)"))
        let dismiss = try #require(body.range(of: "dismiss()"))
        #expect(shown.lowerBound < delete.lowerBound, "La divisa se lee con el registro ya borrado.")
        #expect(save.lowerBound < release.lowerBound, "Se suelta el registro antes de saber si el borrado se guardó.")
        #expect(release.lowerBound < dismiss.lowerBound, "Se cierra sin soltar el registro.")
    }
}
