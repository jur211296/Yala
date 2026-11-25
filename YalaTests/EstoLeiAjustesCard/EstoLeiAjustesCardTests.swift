//
//  EstoLeiAjustesCardTests.swift
//  YalaTests / EstoLeiAjustesCard
//
//  Los tres ajustes de Jürgen a la tarjeta de «Esto leí» (25-nov-2026):
//
//  1. La moneda se toca como en Nuevo registro: las mismas monedas y, al elegir una, la cuenta que la tiene (la línea de
//     su tarjeta o la primera cuenta en esa moneda). El selector de cuenta de la tarjeta enseña solo las de esa moneda.
//  2. La descripción con más peso: `headline` en el color del texto, también en el editor en línea centrado.
//  3. Sin hueco arriba: «Ver todo» pasa a un chevron a la derecha, centrado en vertical, y la tarjeta pierde el relleno
//     superior que le reservaba sitio.
//
//  Y dos que pidió viéndolo en el iPhone: el chip de cuenta dice «Cuenta» (no se corta), y la fila desplegada de la
//  hoja de varios es la misma tarjeta pegada a la izquierda (`EstoLeiCardStyle.row`).
//
//  La elección de moneda se prueba con cuentas de verdad en un almacén en memoria; lo visual, leyendo el código, porque
//  un XCUITest no ve pesos ni colores.
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Yala

@Suite("Esto leí · moneda editable, descripción con peso y sin hueco arriba")
@MainActor
struct EstoLeiAjustesCardTests {

    // MARK: - Almacén en memoria

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema, configurations: [config])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    @discardableResult
    private func account(
        _ name: String, _ currency: String, archived: Bool = false, system: Bool = false, in context: ModelContext
    ) -> Account {
        let account = Account(
            name: name, currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard", type: "Banco",
            isArchived: archived, isSystemAccount: system)
        context.insert(account)
        return account
    }

    // MARK: - 1 · Moneda

    @Test("Las monedas son las de las cuentas de la persona, la actual primero; archivadas y de sistema no cuentan")
    func options_soloCuentasPropias_laActualPrimero() throws {
        let context = try makeContext()
        account("BCP", "PEN", in: context)
        account("BCP Dólares", "USD", in: context)
        account("Interbank", "PEN", in: context)
        account("Vieja en euros", "EUR", archived: true, in: context)
        account("Grupo", "MXN", system: true, in: context)
        try context.save()
        let all = try context.fetch(FetchDescriptor<Account>())

        let options = EstoLeiCurrencyChoice.options(accounts: all, current: "usd")

        #expect(options.map(\.currencyCode) == ["USD", "PEN"])
        #expect(options.first { $0.currencyCode == "PEN" }?.accountCount == 2)
    }

    @Test("Elegir otra moneda pone la primera cuenta en esa moneda")
    func elegirMoneda_ponLaPrimeraCuentaDeEsaMoneda() throws {
        let context = try makeContext()
        let soles = account("BCP Crédito", "PEN", in: context)
        let dolares = account("Cuenta en dólares", "USD", in: context)
        try context.save()

        let chosen = EstoLeiCurrencyChoice.account(for: "USD", selected: soles, accounts: [soles, dolares])

        #expect(chosen === dolares)
    }

    @Test("Elegir la moneda que ya tiene la cuenta la deja como está")
    func elegirLaMismaMoneda_noCambiaLaCuenta() throws {
        let context = try makeContext()
        let primera = account("BCP", "PEN", in: context)
        let elegida = account("Interbank", "PEN", in: context)
        try context.save()

        let chosen = EstoLeiCurrencyChoice.account(for: "pen", selected: elegida, accounts: [primera, elegida])

        #expect(chosen === elegida)
    }

    @Test("Sin cuenta elegida, elegir una moneda pone la primera cuenta en ella")
    func sinCuenta_elegirMonedaPoneUna() throws {
        let context = try makeContext()
        let soles = account("BCP", "PEN", in: context)
        let dolares = account("Dólares", "USD", in: context)
        try context.save()

        #expect(EstoLeiCurrencyChoice.account(for: "USD", selected: nil, accounts: [soles, dolares]) === dolares)
    }

    @Test("Una moneda sin cuentas no cambia nada")
    func monedaSinCuentas_devuelveNil() throws {
        let context = try makeContext()
        let soles = account("BCP", "PEN", in: context)
        try context.save()

        #expect(EstoLeiCurrencyChoice.account(for: "EUR", selected: soles, accounts: [soles]) == nil)
    }

    // MARK: - Cableado (leído del código)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/EstoLeiAjustesCard/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz
    }

    /// El fichero sin las líneas de comentario: nombrar algo en un comentario no pinta el test de verde.
    private static func code(_ path: String) throws -> String {
        let source = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        return source
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Lo que va de `marker` a la siguiente declaración `private var`/`private func`/`// MARK:`.
    private static func block(_ source: String, from marker: String) throws -> String {
        let start = try #require(source.range(of: marker), "no está «\(marker)»")
        let rest = source[start.upperBound...]
        let ends = ["\n    private var ", "\n    private func ", "\n    var body", "\n    // MARK"]
            .compactMap { rest.range(of: $0)?.lowerBound }
        let end = ends.min() ?? rest.endIndex
        return String(rest[..<end])
    }

    private static let cardPath = "Yala/App/Views/Voice/VoiceDraftReviewCard.swift"

    @Test("La cápsula de la tarjeta abre las monedas y elige con la lógica de Nuevo registro")
    func capsula_abreMonedas() throws {
        let amountLine = try Self.block(try Self.code(Self.cardPath), from: "private var amountLine")
        #expect(!amountLine.contains("options: []"), "La cápsula ya no puede ir sin opciones.")
        #expect(amountLine.contains("options: currencyOptions"))
        #expect(amountLine.contains("onChoose: chooseCurrency"))
    }

    @Test("El selector de cuenta de la tarjeta se acota a la moneda del monto, como en Nuevo registro")
    func selectorDeCuenta_acotadoPorMoneda() throws {
        let card = try Self.code(Self.cardPath)
        let sheet = try Self.block(card, from: ".sheet(item: $activeField)")
        #expect(sheet.contains("currencyScope: currencyCode"))

        let fieldSheet = try Self.code("Yala/App/Views/Chat/ChatDraftFieldSheet.swift")
        #expect(fieldSheet.contains("currencyScope: currencyScope"), "ChatDraftFieldSheet tiene que pasarla al selector.")
    }

    @Test("La descripción va en headline y en el color del texto, también al editarla en línea centrada")
    func descripcion_conPeso() throws {
        let description = try Self.block(try Self.code(Self.cardPath), from: "private var descriptionLine")
        #expect(description.contains("DS.Typography.headline"))
        #expect(description.contains(".foregroundStyle(.primary)"))
        #expect(!description.contains(".foregroundStyle(.secondary)"))

        let editor = try Self.code("Yala/App/Views/Image/DraftNoteInlineEditor.swift")
        #expect(editor.contains("isProminent ? DS.Typography.headline"), "El editor de la tarjeta usa la misma letra.")
        #expect(!editor.contains("AnyShapeStyle(.secondary)"), "Ya no va en gris.")
        #expect(editor.contains(".lineLimit(2)"), "Dos líneas: con una, la descripción se cortaba en la hoja de varios.")
        #expect(description.contains("isProminent: true"))
    }

    @Test("«Ver todo» es un chevron a la derecha, centrado en vertical, y arriba no queda hueco")
    func sinHuecoArriba_chevronALaDerecha() throws {
        let card = try Self.code(Self.cardPath)
        let body = try Self.block(card, from: "private var cardLayout: some View")
        #expect(!body.contains("alignment: .topTrailing"), "«Ver todo» ya no va arriba a la derecha.")
        #expect(!body.contains("DS.Spacing.xxxxl"), "Sin el relleno superior que le reservaba sitio.")
        #expect(body.contains("alignment: .trailing"), "El chevron va a la derecha, centrado en vertical.")

        let button = try Self.block(card, from: "private var seeAllButton")
        #expect(button.contains("chevron.right"))
        #expect(button.contains("minWidth: EstoLeiCardLayout.chevronHitTarget"))
        #expect(button.contains("minHeight: EstoLeiCardLayout.chevronHitTarget"))
        #expect(button.contains("accessibilityIdentifier(\"esto_lei_ver_todo\")"))
        #expect(button.contains("accessibilityLabel(L10n.EstoLei.seeAllA11y)"))
        #expect(EstoLeiCardLayout.chevronHitTarget >= 44, "El objetivo de toque mide 44 pt como mínimo.")
    }

    @Test("El chip de cuenta dice «Cuenta», y VoiceOver sigue oyendo «Selecciona cuenta»")
    func chipDeCuenta_diceCuenta() throws {
        let card = try Self.code(Self.cardPath)
        #expect(card.contains("selectAccount: L10n.Transaction.account"))
        #expect(card.contains("draft.account == nil ? L10n.Chat.Draft.selectAccount"))
    }

    @Test("Desplegada, la fila de varios es la tarjeta centrada, con check y chevron en el centro y borde del acento")
    func varios_desplegadaEsLaTarjeta() throws {
        let multi = try Self.code("Yala/App/Views/Voice/MultiDraftReviewList.swift")
        #expect(multi.contains("style: .row"))
        #expect(!multi.contains("private var expandedSection"), "Los chips sueltos de antes ya no existen.")
        #expect(!multi.contains("arrow.up.left.and.arrow.down.right"), "«Ver todo» es el chevron de la tarjeta.")
        #expect(!multi.contains("HStack(alignment: isShowingCard ? .top"), "La marca va centrada en vertical.")
        #expect(multi.contains(".strokeBorder(theme.accent"), "El borde de la fila abierta es el del acento.")
        #expect(!multi.contains(".strokeBorder(DS.Semantic.warningForeground"), "Ya no es ámbar.")

        let card = try Self.code(Self.cardPath)
        let row = try Self.block(card, from: "private var rowLayout: some View")
        #expect(row.contains("seeAllButton"))
        #expect(!row.contains("alignment: .leading"), "Todo centrado, como la tarjeta sola.")
    }

    // MARK: - Fondo de la hoja de varios

    @Test("Con varios, si la hoja se queda a media altura lleva glass aunque solo se ofrezca grande")
    func fondo_aMediaAltura_esGlass() {
        let soloGrande: Set<PresentationDetent> = [.large]
        #expect(ImageEntrySheetHeightLogic.background(
            detents: soloGrande, selectedDetent: .large, usesLargeSheets: false, sheetTop: 370) == .transparent)
        #expect(ImageEntrySheetHeightLogic.background(
            detents: soloGrande, selectedDetent: .large, usesLargeSheets: false, sheetTop: 55) == .subtle)
        #expect(ImageEntrySheetHeightLogic.background(
            detents: soloGrande, selectedDetent: .large, usesLargeSheets: false) == .subtle,
            "Sin medir aún, la regla de siempre.")
        #expect(ImageEntrySheetHeightLogic.background(
            detents: soloGrande, selectedDetent: .large, usesLargeSheets: true, sheetTop: 370) == .subtle,
            "Donde la ventana fuerza hojas grandes (iPad), sólido.")
    }

    @Test("Foto y voz guardan lo que la lógica da por marcado, no la selección cruda (un incompleto cortaba el guardado)")
    func guardar_usaLoMarcadoDeVerdad() throws {
        for path in ["Yala/App/Views/Image/ImageSelectionView.swift", "Yala/App/Views/Voice/VoiceRecordingView.swift"] {
            let body = try Self.block(try Self.code(path), from: "private var draftsToSave: [InboxDraft]")
            #expect(body.contains("MultiDraftReviewLogic.toSave(reviewItems, selection)"), "\(path)")
            #expect(!body.contains("selection.contains($0.persistentModelID)"), "\(path)")
        }
    }
}
