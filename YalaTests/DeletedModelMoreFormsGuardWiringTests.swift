//
//  DeletedModelMoreFormsGuardWiringTests.swift
//  YalaTests
//
//  Card gxa9 (ticket `more-forms-read-their-deleted-model-while-closing`), segunda mitad de `DeletedModelFormGuardWiringTests`:
//  siete formularios más borran SU modelo y siguen presentados mientras se cierran, y tres pantallas que los presentan se
//  repintan con el modelo ya borrado. En el iPhone (iOS 27.x) leer una propiedad de un modelo borrado aborta; el
//  simulador 27.0 no, así que ningún XCUITest lo caza. Estos scans fijan que cada vista lee el modelo solo donde sigue
//  vivo: en su accesor guardado, en la copia hecha antes de borrar o en acciones que corren con él vivo. Los mecanismos de
//  ViewModel los prueba `DeletedModelMoreFormsReleaseTests`.
//

import Foundation
import Testing

@Suite("Más formularios que no leen el modelo que borran — cableado (source-scan)")
struct DeletedModelMoreFormsGuardWiringTests {

    private static func readSource(of relativePath: String, file: StaticString = #filePath) throws -> String {
        let testFile = URL(fileURLWithPath: "\(file)")
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// El código sin comentarios (línea a línea): documentar un invariante no puede romper el scan que lo cuenta.
    private static func codeOnly(_ source: String) -> String {
        source.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El código sin los cuerpos de las declaraciones dadas (de la declaración hasta su llave de cierre). Lo que quede
    /// es lo que puede correr con el modelo ya borrado.
    private static func code(_ source: String, without declarations: [String]) throws -> String {
        var code = codeOnly(source)
        for declaration in declarations {
            let start = try #require(code.range(of: declaration), "No encuentro «\(declaration)».")
            let open = try #require(code.range(of: "{", range: start.lowerBound..<code.endIndex))
            var depth = 0
            var index = open.lowerBound
            while index < code.endIndex {
                if code[index] == "{" { depth += 1 }
                if code[index] == "}" {
                    depth -= 1
                    if depth == 0 { break }
                }
                index = code.index(after: index)
            }
            try #require(index < code.endIndex, "Llaves sin cerrar en «\(declaration)».")
            code.removeSubrange(start.lowerBound...index)
        }
        return code
    }

    private static func matches(_ pattern: String, in code: String) -> [String] {
        code.components(separatedBy: "\n")
            .filter { $0.range(of: pattern, options: .regularExpression) != nil }
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// El cuerpo de la declaración o el cierre que abre `anchor`: de su primera llave a la que la cierra.
    private static func body(of anchor: String, in source: String) throws -> String {
        let code = codeOnly(source)
        let start = try #require(code.range(of: anchor), "No encuentro «\(anchor)».")
        let open = try #require(code.range(of: "{", range: start.lowerBound..<code.endIndex))
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            index = code.index(after: index)
        }
        try #require(index < code.endIndex, "Llaves sin cerrar en «\(anchor)».")
        return String(code[open.upperBound..<index])
    }

    /// `first` aparece antes que `second`, los dos DENTRO del cuerpo que abre `anchor`: buscar hasta el final del fichero
    /// casaba con otra ocurrencia de más abajo y dejaba vivir al mutante (review de gxa9).
    private static func expectOrder(_ first: String, before second: String, after anchor: String, in source: String) throws {
        let body = try body(of: anchor, in: source)
        let a = try #require(body.range(of: first), "No encuentro «\(first)» dentro de «\(anchor)».")
        let b = try #require(body.range(of: second), "No encuentro «\(second)» dentro de «\(anchor)».")
        #expect(a.lowerBound < b.lowerBound, "«\(first)» tiene que ir antes que «\(second)» en «\(anchor)».")
    }

    // MARK: - Formulario de cuenta

    @Test func cuenta_alertaPintaLaCopia_yElViewModelSueltaLaCuentaAntesDeCerrar() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Accounts/AccountFormView.swift")
        #expect(source.contains("accountName: deleteDialogAccountName,"))
        #expect(!source.contains("accountName: viewModel.accountToEdit"))
        // La copia va junto a la apertura de la alerta corta.
        try Self.expectOrder(
            "deleteDialogAccountName = account.name", before: "showDeleteConfirmation = true",
            after: "private func requestDelete() {", in: source)

        // Alerta corta: borrar → soltar → cerrar.
        try Self.expectOrder(
            "try deletionService.deleteAccount(account)", before: "viewModel.releaseDeletedAccount()",
            after: "private func handleDeleteTapped() {", in: source)
        try Self.expectOrder(
            "viewModel.releaseDeletedAccount()", before: "dismiss()",
            after: "private func handleDeleteTapped() {", in: source)

        // Hoja de eliminar: solo cuando lo eliminado es la cuenta del formulario, no una de sus líneas, y después de
        // eliminar (si falla, el formulario recarga y sigue).
        let removal = try Self.code(source, without: [])
        let start = try #require(removal.range(of: "private func removeAccount(_ account: Account) throws {"))
        let tail = String(removal[start.upperBound...])
        let guardLine = try #require(tail.range(of: "let removesTheEditedAccount = lineBeingRemoved == nil"))
        let delete = try #require(tail.range(of: "try deletionService.deleteAccount(account)"))
        let release = try #require(tail.range(of: "viewModel.releaseDeletedAccount()"))
        #expect(guardLine.lowerBound < delete.lowerBound, "Se mira si es una línea con la cuenta ya eliminada.")
        #expect(delete.lowerBound < release.lowerBound, "Se suelta la cuenta antes de saber si se eliminó.")
        #expect(tail[delete.upperBound..<release.lowerBound].contains("if removesTheEditedAccount {"))
    }

    @Test func cuenta_laVistaMiraAntesDeLeer_yElViewModelNoGuardaTrasSoltar() throws {
        let view = try Self.readSource(of: "Yala/App/Views/Accounts/AccountFormView.swift")
        #expect(view.contains("let readableAccount = accountToEdit.flatMap { !$0.isDeleted && $0.modelContext != nil ? $0 : nil }"))
        #expect(view.contains("accountToEdit: readableAccount,"))
        let vm = try Self.readSource(of: "Yala/App/ViewModels/Accounts/AccountFormViewModel.swift")
        #expect(vm.contains("accountToEdit != nil || releasedDeletedAccount"))
        #expect(vm.contains("guard !releasedDeletedAccount, canSave else { return false }"))
    }

    // MARK: - Categoría y subcategoría

    @Test func categoria_elDetalleNoLeeLaCategoriaFueraDelAccesor() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Categories/CategoryDetailView.swift")
        // `viewModel.category` solo se pasa (a la hoja de mover y a los detalles de subcategoría, que miran antes de
        // leer); nunca se lee una propiedad suya.
        let reads = Self.matches(#"viewModel\.category\."#, in: Self.codeOnly(source))
        #expect(reads.isEmpty, "Lecturas de la categoría sin pasar por `readableCategory`: \(reads)")
        // Mover sus registros la elimina: se suelta lo cargado antes de cerrar.
        try Self.expectOrder(
            "viewModel.releaseDeletedCategory()", before: "dismiss()",
            after: "CategoryMoveRecordsSheet(category: viewModel.category) {", in: source)
    }

    @Test func categoria_elViewModelSueltaYMiraAntesDeLeer() throws {
        let source = try Self.readSource(of: "Yala/App/ViewModels/CategoryDetailViewModel.swift")
        #expect(source.contains("guard let category = readableCategory else { return false }"))
        #expect(source.contains(".filter { !$0.isDeleted && $0.modelContext != nil }"))
        #expect(source.contains("categoryWasReleased = true"))
        let view = try Self.readSource(of: "Yala/App/Views/Categories/CategoryDetailView.swift")
        #expect(view.contains("readsCategory: !category.isDeleted && category.modelContext != nil))"))
        try Self.expectOrder(
            "try service.deleteCategory(category, withSubcategories: subcategories)", before: "releaseDeletedCategory()",
            after: "func deleteCategory() -> Bool {", in: source)
        try Self.expectOrder(
            "context.delete(category)", before: "releaseDeletedCategory()",
            after: "func discardNewCategory() {", in: source)
    }

    @Test func subcategoria_elInitYElBodyMiranAntesDeLeer() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Categories/SubcategoryDetailView.swift")
        #expect(source.contains("if let sub = subcategoryToEdit, !sub.isDeleted, sub.modelContext != nil {"))
        #expect(source.contains("let parentIsReadable = !parentCategory.isDeleted && parentCategory.modelContext != nil"))
        #expect(source.contains("private var isSystemSubcategory: Bool { readableSubcategoryToEdit?.isAnySystem ?? false }"))
        // En el init, la categoría padre solo se lee tras mirar.
        let initStart = try #require(source.range(of: "init(parentCategory: Category, subcategoryToEdit: Subcategory? = nil) {"))
        let initEnd = try #require(source.range(of: "\n    }\n", range: initStart.upperBound..<source.endIndex))
        let initCode = Self.codeOnly(String(source[initStart.upperBound..<initEnd.lowerBound]))
        let parentReads = Self.matches(#"parentCategory\.(colorHex|iconName)"#, in: initCode)
        #expect(parentReads.allSatisfy { $0.contains("parentIsReadable ?") }, "El init lee la categoría sin mirar: \(parentReads)")
    }

    @Test func traspaso_pintaLaCopia_yLosDestinosMiranAntes() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Categories/SubcategoryTransferSheet.swift")
        #expect(source.contains("transferDescription(transactionCount, subcategoryName)"))
        #expect(source.contains("ForEach(destinations, id:"))
        // Fuera del init y del accesor de destinos, el nombre ni los destinos se leen de la subcategoría.
        let rest = try Self.code(source, without: [
            "init(subcategoryToDelete: Subcategory, onComplete: @escaping () -> Void) {",
            "private var destinations:",
        ])
        #expect(Self.matches(#"subcategoryToDelete\.\w"#, in: rest).isEmpty)
        #expect(Self.matches(#"availableDestinations\("#, in: rest).isEmpty)
    }

    // MARK: - Grupos

    @Test func saldoInicial_laHojaSoloLeeElSaldoEnSuCopia() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Groups/GroupOpeningBalanceDetailSheet.swift")
        let rest = try Self.code(source, without: ["init(reading expense: SplitExpense) {", "private var shown: Shown {"])
        let reads = Self.matches(#"\bexpense\.\w"#, in: rest)
        #expect(reads.isEmpty, "Lecturas del saldo inicial fuera de su copia: \(reads)")
        #expect(source.contains("!expense.isDeleted && expense.modelContext != nil ? Shown(reading: expense) : shownAtOpen"))
        #expect(source.contains("guard !expense.isDeleted, expense.modelContext != nil else {"))
    }

    @Test func detalleDeGrupo_laHojaDeEdicionNoLeeElGastoBorrado() throws {
        let view = try Self.readSource(of: "Yala/App/Views/Groups/GroupDetailView.swift")
        try Self.expectOrder(
            "guard !expense.isDeleted, expense.modelContext != nil else { return viewModel.activeMembers }",
            before: "expense.paidByMemberID",
            after: "private func membersForExpenseForm(_ expense: SplitExpense) -> [SplitMember] {", in: view)

        try Self.expectOrder(
            "guard !expense.isDeleted, expense.modelContext != nil else { return [] }",
            before: "viewModel.sharesForExpense(expense)",
            after: "private func sharesForExpenseSheet(_ expense: SplitExpense) -> [SplitShare] {", in: view)
        // Las dos hojas que borran su gasto (editar gasto, detalle del saldo inicial) piden los repartos por la guarda.
        let sheets = try Self.body(of: "private func sheetContent(for sheet: GroupSheet) -> some View {", in: view)
        for kase in ["case .editExpense(let expense):", "case .openingBalanceDetail(let expense):"] {
            let start = try #require(sheets.range(of: kase))
            let next = sheets.range(of: "case .", range: start.upperBound..<sheets.endIndex)?.lowerBound ?? sheets.endIndex
            let branch = String(sheets[start.upperBound..<next])
            #expect(!branch.contains("viewModel.sharesForExpense("), "«\(kase)» pide los repartos sin mirar si el gasto sigue.")
            #expect(branch.contains("sharesForExpenseSheet(expense)"))
        }

        let vm = try Self.readSource(of: "Yala/App/ViewModels/GroupDetailViewModel.swift")
        // La identidad de la hoja no lee el gasto.
        let idStart = try #require(vm.range(of: "    var id: ID {"))
        let idEnd = try #require(vm.range(of: "\n    }\n", range: idStart.upperBound..<vm.endIndex))
        let idCode = String(vm[idStart.upperBound..<idEnd.lowerBound])
        #expect(Self.matches(#"\be\.id\b"#, in: idCode).isEmpty, "`GroupSheet.id` vuelve a leer `id` del gasto.")
        #expect(idCode.components(separatedBy: "e.persistentModelID").count == 5)
    }

    @Test func ajustesDeGrupo_conElGrupoBorradoNoPintaFilas_niGuarda() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Groups/GroupSettingsView.swift")
        #expect(source.contains("!group.isDeleted && group.modelContext != nil"))
        let body = try #require(source.range(of: "    var body: some View {"))
        let list = try #require(source.range(of: "YalaSettingsList {", range: body.upperBound..<source.endIndex))
        let guardLine = try #require(source.range(of: "if isGroupReadable {", range: list.upperBound..<source.endIndex))
        let between = Self.codeOnly(String(source[list.upperBound..<guardLine.lowerBound]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(between.isEmpty, "La lista pinta algo antes de mirar si el grupo sigue: «\(between)».")
        // Lo que corre al desaparecer o al recalcular mira primero.
        try Self.expectOrder("guard isGroupReadable else { return }", before: "group.name",
                             after: "private func saveIdentity() {", in: source)
        try Self.expectOrder("guard isGroupReadable else { return }", before: "recomputeOutstandingDebt()",
                             after: "private func recomputeOwnerExit() {", in: source)
        try Self.expectOrder("guard isGroupReadable else { return }", before: "group.isMigratedFrozen",
                             after: "private func recomputeShareableSummary() {", in: source)
        // Lo que `LeavePresentations` recibe del `body` en cada pase, fuera de las filas: mira antes de leer miembros.
        try Self.expectOrder("guard isGroupReadable,", before: "myDebts",
                             after: "private var leaveWithDebtMessage: String {", in: source)
        try Self.expectOrder("guard isGroupReadable else {", before: "designatedHeirName",
                             after: "private var transferConfirmMessage: String {", in: source)
    }

    /// Salir del grupo (o un borrado por sync) lo borra con el detalle debajo, y su `body` se vuelve a evaluar antes de que
    /// el `onChange` lo cierre (ticket `group-detail-reads-the-group-after-leaving-it`). El `body` solo lee el grupo por
    /// su accesor guardado, o en `onAppear` (con él vivo) y en la decisión de cierre, que mira primero si sigue.
    @Test func detalleDeGrupo_conElGrupoBorradoNoLeeElGrupo_niLoQueLoAbre() throws {
        let view = try Self.readSource(of: "Yala/App/Views/Groups/GroupDetailView.swift")
        #expect(view.contains("!group.isDeleted && group.modelContext != nil"))
        let squash: (String) -> String = { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }

        let body = try Self.body(of: "    var body: some View {", in: view)
        // El contenido (avisos, pestañas, botón de nuevo gasto) solo con el grupo vivo.
        #expect(squash(try Self.body(of: "ZStack {", in: body)) == "if isGroupReadable { groupContent }")
        #expect(squash(body).contains("if isGroupReadable { groupToolbarItems }"))
        #expect(body.contains(".navigationTitle(groupTitle)"))
        #expect(body.contains("presentedSheet(for: sheet)"))
        // Fuera de `onAppear` y de la decisión de cierre, el `body` no lee el grupo directamente.
        let rest = try Self.code(body, without: [".onAppear {", ".onChange(of: sessionState.dataVersion) {"])
        #expect(Self.matches(#"\bgroup\."#, in: rest).isEmpty, "El `body` lee el grupo sin mirar si sigue.")

        // Al cerrarse la hoja de Ajustes tras salir, ni recarga ni pregunta por avisos.
        try Self.expectOrder("guard isGroupReadable else {", before: "viewModel.loadData()",
                             after: ".sheet(item: $viewModel.activeSheet, onDismiss: {", in: view)
        try Self.expectOrder("viewModel.releaseDeletedGroup()", before: "consumePendingEditFromDetail()",
                             after: ".sheet(item: $viewModel.activeSheet, onDismiss: {", in: view)
        // La decisión de cierre suelta el grupo antes de cerrar.
        try Self.expectOrder("if !isGroupReadable { viewModel.releaseDeletedGroup() }", before: "close()",
                             after: ".onChange(of: sessionState.dataVersion) {", in: view)
        #expect(squash(try Self.body(of: "private var groupTitle: String {", in: view))
                == "isGroupReadable ? group.name : viewModel.groupName")
        #expect(view.contains("if isGroupReadable || Self.isSettings(sheet) {"))
        // El `init` se vuelve a evaluar cada vez que quien lo abre se repinta, también con el grupo ya borrado.
        let initBody = try Self.body(of: "init(group: SplitGroup, presentation: Presentation", in: view)
        #expect(Self.matches(#"\bgroup\."#, in: initBody).isEmpty, "El `init` del detalle lee el grupo.")

        // La decisión de cierre no evalúa nada del grupo borrado: lo diferido va tras `isDeleted`.
        let decision = try Self.readSource(of: "Yala/App/Logic/GroupDetailDismissDecision.swift")
        #expect(decision.contains("isHiddenForAll: @autoclosure () -> Bool"))
        #expect(decision.contains("isArchived: @autoclosure () -> Bool"))

        // Quien lo abre solo lee su identidad, que no toca las propiedades del modelo.
        let container = try Self.readSource(of: "Yala/App/Views/Groups/GroupsContainerView.swift")
        let destination = try Self.body(of: ".navigationDestination(item: $viewModel.selectedGroup) { group in", in: container)
        #expect(Self.matches(#"\bgroup\.(?!persistentModelID\b)"#, in: destination).isEmpty,
                "Quien abre el detalle lee el grupo más allá de su identidad.")

        // El ViewModel mira antes de recargar, de calcular y de enseñar un aviso.
        let vm = try Self.readSource(of: "Yala/App/ViewModels/GroupDetailViewModel.swift")
        try Self.expectOrder("guard !isGroupGone else { return }", before: "fetchMembers(for: group)",
                             after: "private func fetchData() {", in: vm)
        try Self.expectOrder("guard !isGroupGone else { return }", before: "group.simplifyDebts",
                             after: "private func recalculate() {", in: vm)
        try Self.expectOrder("guard !isGroupGone else { return }", before: "group.cloudKitZoneID",
                             after: "func presentOpeningBalanceServerRejectionIfAny(", in: vm)
        try Self.expectOrder("if isGroupGone { return false }", before: "group.isMigratedFrozen",
                             after: "var canCurrentUserParticipate: Bool {", in: vm)
    }

    // MARK: - Flujo de caja

    @Test func lineaDelFlujo_laHojaLeeLaLineaSoloPorSuAccesor() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Reports/CashFlow/CashFlowLineConfigSheet.swift")
        #expect(source.contains(".navigationTitle(shown.name)"))
        // Lo que corre con la línea viva: el init (mira antes), la copia, el accesor, las dos funciones que la toman
        // del accesor, el guardado y el borrado.
        let rest = try Self.code(source, without: [
            "init(reading line: CashFlowLine) {",
            "init(viewModel: CashFlowPlanViewModel, line: CashFlowLine, currencyCode: String, transactions: [TransactionItem] = []) {",
            "private var readableLine: CashFlowLine? {",
            "private func previewForMethod(_ method: EstimationMethod) -> Double {",
            "private func computeHistoricalStats() -> HistoricalStats {",
            "private func applyChanges() {",
        ])
        let reads = Self.matches(#"\bline\.\w"#, in: rest)
        #expect(reads.isEmpty, "Lecturas de la línea fuera de su accesor: \(reads)")
        #expect(source.contains("guard let line = readableLine else { return 0 }"))
        #expect(source.contains("guard let line = readableLine else {"))
        #expect(source.contains("let readable = !line.isDeleted && line.modelContext != nil"))
    }

    @Test func celdaDelFlujo_noLeeLaLineaNiRegistrosBorrados() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift")
        #expect(source.contains(".filter { !$0.isDeleted && $0.modelContext != nil }"))
        try Self.expectOrder(".filter { !$0.isDeleted && $0.modelContext != nil }", before: "tx.date",
                             after: "private var activeTransactions: [TransactionItem] {", in: source)
        // La línea solo se lee en la copia del icono, en el accesor y en la acción que abre el selector de método (con
        // la línea viva); el resto va por `readableLine`.
        let rest = try Self.code(source, without: [
            "init(reading line: CashFlowLine) {",
            "private static func readable(_ line: CashFlowLine?) -> CashFlowLine? {",
            "private func openMethodPicker(lr: CashFlowLineResult) {",
        ])
        let reads = Self.matches(#"\bline(\?|!)?\.\w"#, in: rest)
        #expect(reads.isEmpty, "Lecturas de la línea sin pasar por `readableLine`: \(reads)")
    }

    // MARK: - Listas y etiquetas

    @Test func listaDeCuentas_laHojaNoLeeLaCuentaBorrada_niLosRegistrosBorrados() throws {
        let vm = try Self.readSource(of: "Yala/App/ViewModels/AccountsSettingsListViewModel.swift")
        try Self.expectOrder("guard !account.isDeleted, account.modelContext != nil else { return accounts.map(\\.name) }",
                             before: "account.name", after: "func existingNamesExcluding(_ account: Account) -> [String] {",
                             in: vm)
        #expect(vm.contains("var transactions: [TransactionItem] { loadedTransactions.filter { !$0.isDeleted && $0.modelContext != nil } }"))
    }

    @Test func presupuestos_laListaYLaFilaSaltanLosBorrados() throws {
        let row = try Self.readSource(of: "Yala/App/Views/Planning/BudgetRowView.swift")
        try Self.expectOrder("if summary.budget.isDeleted || summary.budget.modelContext == nil {",
                             before: "row", after: "    var body: some View {", in: row)
        #expect(try Self.body(of: "private var row: some View {", in: row).contains("NavigationLink(value:"))
        let list = try Self.readSource(of: "Yala/App/Views/Planning/BudgetsListView.swift")
        #expect(list.contains("ForEach(section.budgets.filter { !$0.budget.isDeleted && $0.budget.modelContext != nil }) { summary in"))
        let vm = try Self.readSource(of: "Yala/App/ViewModels/BudgetsViewModel.swift")
        #expect(vm.contains("allBudgets.count(where: { !$0.isDeleted && $0.modelContext != nil && $0.isActive })"))
    }

    @Test func etiqueta_alertaPintaLaCopia() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Tags/TagFormView.swift")
        #expect(source.contains("Text(L10n.UXL7.Tags.deleteMessage(deleteDialogRecordCount))"))
        try Self.expectOrder("deleteDialogRecordCount = viewModel.tagToEdit?.transactions?.count ?? 0",
                             before: "isShowingDeleteConfirmation = true", after: "private var deleteSection: some View {",
                             in: source)
        #expect(Self.matches(#"tagToEdit\?\.transactions"#, in: Self.codeOnly(source)).count == 1)
        // Mira antes de leer al crear el ViewModel, y lo suelta tras eliminar y antes de cerrar.
        #expect(source.contains("let readableTag = tagToEdit.flatMap { !$0.isDeleted && $0.modelContext != nil ? $0 : nil }"))
        try Self.expectOrder("try deletionService.deleteTag(tag)", before: "viewModel.releaseDeletedTag()",
                             after: "private func deleteTag() {", in: source)
        try Self.expectOrder("viewModel.releaseDeletedTag()", before: "dismiss()",
                             after: "private func deleteTag() {", in: source)
    }
}
