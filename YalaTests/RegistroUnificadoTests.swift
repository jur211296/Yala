//
//  RegistroUnificadoTests.swift
//  YalaTests
//
//  Registro unificado, opción A de Jürgen (31-oct-2026, «Va la A»): la aprobación de un borrador de la Bandeja copia a
//  Nuevo registro y Nuevo gasto de Grupos se adapta. Fija la lógica pura (el reparto en filas de los selectores, la línea
//  «Salen … de tu cuenta y te deben …» de Grupos y el color del monto) y, por source-scan, que las tres pantallas usan las
//  mismas piezas: si una vuelve a pintar a su manera, el test lo dice.
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Yala

// MARK: - Reparto en filas de los selectores

@Suite("Registro unificado · filas de los selectores")
struct RecordSelectorRowsLogicTests {

    private let chip = CGSize(width: 100, height: 36)

    @Test func sinMarcas_fluyeYBajaCuandoNoCabe() {
        // 3 de 100 con 8 de aire caben en 330 (316); el cuarto baja.
        let rows = RecordSelectorRowsLogic.arrange(
            sizes: Array(repeating: chip, count: 4), endsRow: [], maxWidth: 330, spacing: 8)
        #expect(rows.rowIndices == [0, 0, 0, 1])
        #expect(rows.origins[3] == CGPoint(x: 0, y: 44))
        #expect(rows.height == 80)
    }

    /// La tarjeta y sus líneas cierran la fila: la categoría empieza otra aunque quepa al lado. Con el reparto de antes
    /// (FlowLayout) iría en la primera fila, junto a la línea en dólares.
    @Test func laUltimaLineaCierraLaFila_yLaCategoriaEmpiezaOtra() {
        let rows = RecordSelectorRowsLogic.arrange(
            sizes: [CGSize(width: 90, height: 36), CGSize(width: 60, height: 36), CGSize(width: 60, height: 36),
                    CGSize(width: 90, height: 36), CGSize(width: 80, height: 36)],
            endsRow: [false, false, true, false, false],
            maxWidth: 600,
            spacing: 8
        )
        #expect(rows.rowIndices == [0, 0, 0, 1, 1], "Cuenta + líneas en una fila; categoría + etiqueta en otra")
        #expect(rows.origins[3].x == 0)
    }

    @Test func unaMarcaEnElUltimo_noAnadeFilaVacia() {
        let rows = RecordSelectorRowsLogic.arrange(
            sizes: [chip, chip], endsRow: [false, true], maxWidth: 600, spacing: 8)
        #expect(rows.rowIndices == [0, 0])
        #expect(rows.height == 36)
    }

    @Test func unHijoMasAnchoQueLaFila_vaSoloYNoDejaFilaVaciaDelante() {
        let rows = RecordSelectorRowsLogic.arrange(
            sizes: [CGSize(width: 500, height: 36), chip], endsRow: [], maxWidth: 300, spacing: 8)
        #expect(rows.rowIndices == [0, 1])
        #expect(rows.origins[0] == .zero)
    }

    @Test func marcasSeguidas_cadaUnaCierraSuFila() {
        let rows = RecordSelectorRowsLogic.arrange(
            sizes: [chip, chip, chip], endsRow: [true, true, false], maxWidth: 600, spacing: 8)
        #expect(rows.rowIndices == [0, 1, 2])
    }

    /// Centrado (las hojas que completan un borrador de grupo): cada fila, en medio de su ancho.
    @Test func centrado_desplazaCadaFilaAlMedio() {
        let rows = RecordSelectorRowsLogic.arrange(
            sizes: [chip, chip, chip], endsRow: [false, true, false], maxWidth: 400, spacing: 8)
        let offsets = RecordSelectorRowsLogic.centeringOffsets(rows, maxWidth: 400)
        #expect(offsets == [96, 96, 150], "fila 1: 208 de ancho → (400−208)/2; fila 2: 100 → 150")
    }

    @Test func sinHijos_altoCero() {
        let rows = RecordSelectorRowsLogic.arrange(sizes: [], endsRow: [], maxWidth: 300, spacing: 8)
        #expect(rows.height == 0)
        #expect(rows.origins.isEmpty)
    }
}

// MARK: - La línea de Grupos

@Suite("Registro unificado · «Salen … de tu cuenta» en Grupos")
struct GroupExpenseOutflowLineLogicTests {

    private func line(
        required: Bool = true, editing: Bool = false, amount: Double, participants: Bool = true,
        balanced: Bool = true, myShare: Double?
    ) -> GroupExpenseOutflowLineLogic.Line? {
        GroupExpenseOutflowLineLogic.line(
            accountRequired: required, isEditing: editing, amount: amount, hasParticipants: participants,
            sharesBalanced: balanced, myShare: myShare)
    }

    /// S/ 240 entre tres y pagas tú: salen 240 de tu cuenta y te deben 160 (no «tu parte, 80»).
    @Test func pagasTu_entreTres_salenTodoYTeDebenLoDeLosDemas() {
        #expect(line(amount: 240, myShare: 80) == .init(paidOut: 240, owedToYou: 160))
    }

    @Test func gastoSoloTuyo_nadieTeDebe() {
        #expect(line(amount: 50, myShare: 50) == .init(paidOut: 50, owedToYou: nil))
    }

    @Test func noParticipas_teDebenTodo() {
        #expect(line(amount: 90, myShare: nil) == .init(paidOut: 90, owedToYou: 90))
        #expect(line(amount: 90, myShare: 0) == .init(paidOut: 90, owedToYou: 90))
    }

    /// Paga otro (o el puente está apagado): no se pide la cuenta y no hay nada que contar de tus registros.
    @Test func sinCuentaPedida_noHayLinea() {
        #expect(line(required: false, amount: 240, myShare: 80) == nil)
    }

    @Test func repartoSinCuadrar_sinMonto_oSinParticipantes_noHayLinea() {
        #expect(line(amount: 240, balanced: false, myShare: 80) == nil)
        #expect(line(amount: 0, myShare: 0) == nil)
        // Sin nadie marcado el reparto «cuadra» (no hay qué repartir) y Guardar está apagado: no se cuenta nada.
        #expect(line(amount: 240, participants: false, myShare: nil) == nil)
    }

    /// Al editar, el puente no mueve el registro que ya existe a otra cuenta: la frase no puede prometerlo.
    @Test func alEditar_noHayLinea() {
        #expect(line(editing: true, amount: 240, myShare: 80) == nil)
    }

    /// S/ 100 entre tres, y tú primero: lo guardado es 33.34 (el céntimo sobrante va a los primeros) y te deben 66.66,
    /// lo mismo que apunta el puente. La parte sin redondear (33.333…) diría 66.67.
    @Test func cienEntreTres_usaLaParteGuardada_yDiceLoQueApuntaElPuente() throws {
        let shares = GroupSplitCalculator.calculate(
            total: 100, splitType: .equal,
            participants: ["yo", "ana", "beto"].map { GroupSplitCalculator.Participant(memberID: $0, value: 0) })
        let mine = GroupExpenseOutflowLineLogic.myStoredShare(shares, myMemberID: "yo")
        let owed = try #require(line(amount: 100, myShare: mine)?.owedToYou)
        let expected = 100 - (try #require(shares?.first { $0.memberID == "yo" }?.amount))
        #expect(abs(owed - expected) < 0.000_1)
        #expect(abs(owed - 100.0 * 2 / 3) > 0.004, "con la parte sin redondear diría 66.67")
    }

    @Test func miParteGuardada_sinRepartoOSinParticipar_esNil() {
        #expect(GroupExpenseOutflowLineLogic.myStoredShare(nil, myMemberID: "yo") == nil)
        #expect(GroupExpenseOutflowLineLogic.myStoredShare([("ana", 50)], myMemberID: "yo") == nil)
        #expect(GroupExpenseOutflowLineLogic.myStoredShare([("yo", 50)], myMemberID: nil) == nil)
        #expect(GroupExpenseOutflowLineLogic.myStoredShare([("ana", 50), ("yo", 30)], myMemberID: "yo") == 30)
    }

    /// Una diferencia de menos de medio céntimo no se lee como «te deben S/ 0.00».
    @Test func menosDeMedioCentimo_noEsUnaDeuda() {
        #expect(line(amount: 100, myShare: 99.999)?.owedToYou == nil)
    }

    @Test func losTextos_estanEnLos16Idiomas_conSusDosHuecos() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let resources = root.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let strings = try String(
                contentsOf: resources.appendingPathComponent("\(locale)/Localizable.strings"), encoding: .utf8)
            let line = strings.split(separator: "\n").first { $0.hasPrefix("\"groups.expense.outflowLine\" = ") }
            let noDebt = strings.split(separator: "\n").first { $0.hasPrefix("\"groups.expense.outflowLineNoDebt\" = ") }
            let full = try #require(line, "falta outflowLine en \(locale)")
            let short = try #require(noDebt, "falta outflowLineNoDebt en \(locale)")
            #expect(full.contains("%1$@") && full.contains("%2$@"), "\(locale)")
            #expect(short.contains("%@"), "\(locale)")
            #expect(!full.contains("NEEDS_TRANSLATION") && !short.contains("NEEDS_TRANSLATION"), "\(locale)")
        }
    }
}

// MARK: - Color del monto

@Suite("Registro unificado · color del monto")
@MainActor
struct RecordFormAmountColorTests {

    @Test func gastoRosa_ingresoTurquesa() {
        #expect(Color.recordFormAmount(isIncome: false) == Color.hotPink)
        #expect(Color.recordFormAmount(isIncome: true) == Color.incomeAmount)
    }

    /// Nuevo registro pintaba el ingreso en índigo (`TransactionType.color`); ahora, el turquesa de las tres pantallas.
    @Test func nuevoRegistro_usaElColorDeLosTresFormularios() {
        let viewModel = NewTransactionViewModel()
        viewModel.transactionType = .expense
        #expect(viewModel.amountColor == Color.hotPink)
        viewModel.transactionType = .income
        #expect(viewModel.amountColor == Color.incomeAmount)
        #expect(viewModel.amountColor != TransactionType.income.color)
        viewModel.transactionType = .transfer
        #expect(viewModel.amountColor == TransactionType.transfer.color)
    }
}

// MARK: - Las tres pantallas usan las mismas piezas (source-scan)

@Suite("Registro unificado · cableado de las tres pantallas (source-scan)")
struct RegistroUnificadoWiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return codeOnly(try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8))
    }

    private static func codeOnly(_ code: String) -> String {
        code.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    /// El tramo de `start` hasta el siguiente `end`.
    private static func section(_ code: String, from start: String, to end: String) throws -> String {
        let lower = try #require(code.range(of: start), "no encuentro \(start)")
        let rest = code[lower.upperBound...]
        let upper = rest.range(of: end)?.lowerBound ?? rest.endIndex
        return String(rest[..<upper])
    }

    private static let newRecord = "Yala/App/Views/Transactions/NewTransactionView.swift"
    private static let approval = "Yala/App/Views/Inbox/InboxDraftEditSheet.swift"
    private static let groups = "Yala/App/Views/Groups/GroupExpenseFormView.swift"

    @Test func lasTres_usanLaPastillaDeFecha_laDescripcion_yLosSelectoresCompartidos() throws {
        for path in [Self.newRecord, Self.approval, Self.groups] {
            let code = try Self.source(path)
            #expect(code.contains("RecordPillButton(icon: \"calendar\", text: dateChipText)"), "\(path): fecha")
            #expect(code.contains(".recordDescriptionStyle()"), "\(path): descripción")
            #expect(code.contains("RecordSelectorChips(spacing: DS.Spacing.sm)"), "\(path): selectores")
            #expect(code.contains("Color.recordFormAmount(isIncome:") || path == Self.newRecord, "\(path): monto")
        }
    }

    @Test func nuevoRegistroYAprobacion_compartenLosChipsBajoElMonto_yLaEtiquetaPuesta() throws {
        for path in [Self.newRecord, Self.approval] {
            let code = try Self.source(path)
            #expect(code.contains("RecordCategoryChips("), "\(path)")
            #expect(code.contains("SelectedTagChip("), "\(path)")
        }
    }

    /// La aprobación ya no pone los selectores en una fila con desplazamiento lateral, y marca lo que falta.
    @Test func aprobacion_sinFilaConScroll_yConMarcaDeLoQueFalta() throws {
        let code = try Self.source(Self.approval)
        let chips = try Self.section(code, from: "private var bottomChips: some View {", to: "private var subcategoryChipColor")
        #expect(!chips.contains("ScrollView(.horizontal"))
        #expect(chips.contains("isMissing: amount != nil && selectedAccount == nil"))
        #expect(chips.contains("isMissing: amount != nil && selectedSubcategory == nil"))
        #expect(code.contains("DatePickerSheet(selectedDate: $transactionDate, quickPick: true)"))
    }

    /// Grupos: la cuenta es una pastilla de abajo (con el identificador de la fila que sustituye), el grupo va arriba en
    /// el sitio del segmentado y la fecha encabeza el bloque central.
    @Test func grupos_cuentaComoPastilla_grupoArriba_fechaEnElBloqueCentral() throws {
        let code = try Self.source(Self.groups)
        #expect(!code.contains("private var accountRow"))
        let chips = try Self.section(code, from: "private var bottomChips: some View {", to: "private var outflowLine")
        #expect(chips.contains(".accessibilityIdentifier(\"group_expense_account_row\")"))
        #expect(chips.contains("isMissing: markedMissingField == .account"))
        let central = try Self.section(code, from: "private var centralContent: some View {", to: "private var dateChip")
        #expect(central.contains("dateChip\n            descriptionField\n            amountDisplay"))
        #expect(!central.contains("groupContextChip"), "el grupo va arriba, no junto a la fecha")
        #expect(code.contains("groupContextChip\n                            .padding(.top, DS.Spacing.sm)"))
    }

    /// La parte de la línea de Grupos es la GUARDADA (redondeada), y los dos importes van en su sitio.
    @Test func grupos_laLineaUsaLaParteGuardada_yNoSeCruzanLosImportes() throws {
        let code = try Self.source(Self.groups)
        let outflow = try Self.section(code, from: "private var outflowLine: some View {", to: "private var subcategoryChipColor")
        #expect(outflow.contains("viewModel.calculatedShares, myMemberID: viewModel.currentUserMemberID"))
        #expect(!outflow.contains("effectiveAmountsByID"))
        #expect(outflow.contains("isEditing: viewModel.isEditMode"))
        #expect(outflow.contains("hasParticipants: viewModel.hasSelectedMembers"))
        #expect(outflow.contains("appPreferences.currency(line.paidOut,"))
        #expect(outflow.contains("L10n.Groups.Expense.outflowLine(\n                    paidOut,"))
    }

    /// Las pastillas van rellenas por defecto, también en el editor de favoritos y en las hojas de grupo de la Bandeja,
    /// que comparten el componente y el contenedor.
    @Test func pastillasRellenasPorDefecto_yFavoritosYHojasDeGrupoConElMismoContenedor() throws {
        let chip = try Self.source("Yala/App/Views/Transactions/Components/SelectionChip.swift")
        #expect(chip.contains("var fillsWhenSelected: Bool = true"))
        let favorites = try Self.source("Yala/App/Views/Favorites/FavoriteEditorView.swift")
        let scaffold = try Self.source("Yala/App/Views/Inbox/GroupDraftFinalizationScaffold.swift")
        #expect(favorites.contains("RecordSelectorChips(spacing: DS.Spacing.sm)"))
        #expect(scaffold.contains("RecordSelectorChips(spacing: DS.Spacing.sm, alignment: .center) { selector() }"))
        let appRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala")
        let files = FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        for file in files {
            let code = Self.codeOnly(try String(contentsOf: file, encoding: .utf8))
            #expect(!code.contains("fillsWhenSelected: false"), "\(file.lastPathComponent) vuelve al tinte")
        }
    }

    /// La última línea de una tarjeta cierra su fila en los dos sitios que pintan líneas.
    @Test func laUltimaLinea_cierraLaFila_enNuevoRegistroYEnLaAprobacion() throws {
        let newRecord = try Self.source(Self.newRecord)
        let cardChips = try Self.source("Yala/App/Views/Transactions/Components/AccountCardChips.swift")
        #expect(newRecord.contains(".endsSelectorRow(member.persistentModelID == cardMembers.last?.persistentModelID)"))
        #expect(cardChips.contains(".endsSelectorRow(member.persistentModelID == members.last?.persistentModelID)"))
    }
}
