//
//  VoiceDraftReviewCard.swift
//  Yala
//
//  Un registro de «Esto leí» (foto) o «Esto entendí» (voz) como una hoja B1 en pequeño (opción A, elegida por Jürgen el
//  2026-11-22; maqueta en `docs/propuestas/2026-11-22-esto-lei/`): la descripción centrada, la cápsula de moneda con el
//  monto grande, la categoría bajo el monto (o «● Elige categoría ▾» en ámbar si falta) y la fila Hoy · Cuenta · # con
//  los chips de Nuevo registro. Cada chip abre el MISMO selector que Nuevo registro (`ChatDraftFieldSheet`). «Ver todo»
//  abre el editor completo dentro de la misma hoja (lo monta quien la presenta); tocar la tarjeta no abre nada.
//
//  Cada cambio se escribe en el `InboxDraft` y se guarda al momento: si el usuario cierra la hoja sin guardar, el
//  borrador se queda en la Bandeja con lo que corrigió.
//

import SwiftData
import SwiftUI

/// La tarjeta de «Esto leí» sobre el glass de la hoja (encargo del 2026-11-23): el aire que la separa de la cabecera y
/// el contorno que marca dónde termina.
enum EstoLeiCardLayout {
    /// Entre la cabecera (X, título, miniatura de la foto) y el borde de arriba de la primera tarjeta.
    static let airAboveFirstCard = DS.Spacing.lg
    /// El contorno de la tarjeta. Sobre el glass, el `cardBorder` del tema (blanco al 8 % en oscuro) no se distinguía.
    static let edgeWidth: CGFloat = 1
    /// «Ver todo» es un chevron a la derecha, centrado en vertical (Jürgen, 25-nov-2026: arriba dejaba un hueco a la
    /// izquierda). Su objetivo de toque, 44 pt como mínimo.
    static let chevronHitTarget: CGFloat = 44
    /// El margen extra a cada lado del contenido: el del chevron a la derecha y el mismo a la izquierda, para que lo de
    /// dentro siga centrado en la tarjeta.
    static let chevronColumn = DS.Spacing.xl
    /// Con la hoja en grande, la tarjeta es la de los widgets del Panel (Jürgen, 27-nov-2026): su radio, su relleno y su
    /// borde del tema. A media altura, la de siempre sobre el glass.
    static func cornerRadius(large: Bool) -> CGFloat { large ? DS.Panel.widgetRadius : DS.Radius.card }
    static let edge = Color(uiColor: UIColor { traits in // A11Y-DM: contorno propio por modo, sube con «Aumentar contraste»
        let high = traits.accessibilityContrast == .high
        return traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(high ? 0.4 : 0.2)
            : UIColor.black.withAlphaComponent(high ? 0.3 : 0.12)
    })
}

/// Dónde va la tarjeta: sola en la hoja, con su fondo y su contorno (opción A), o como la fila desplegada de la hoja de
/// varios, sin fondo propio y con el chevron al lado (Jürgen, 25-nov-2026: «como Nuevo registro, bien ordenada»). Las
/// dos van centradas.
enum EstoLeiCardStyle {
    case card
    case row
}

struct VoiceDraftReviewCard: View {
    let draft: InboxDraft
    /// La hoja de foto deja corregir la descripción tocándola (encargo del 2026-11-17); la de voz no lo pide.
    var editsNoteInPlace = false
    var style: EstoLeiCardStyle = .card
    /// «Ver todo»: el editor completo del borrador, dentro de la misma hoja.
    let onOpenDetails: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    /// La hoja de la foto se ve grande: la tarjeta lleva el fondo de card del Panel (encargo del 27-nov-2026).
    @Environment(\.estoLeiEnGrande) private var largePresentation

    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var allAccounts: [Account]
    @Query(filter: #Predicate<Subcategory> { $0.isVisible == true }) private var allSubcategories: [Subcategory]
    @Query private var allTags: [Tag]

    @State private var activeField: ChatDraftField?
    @State private var isEditingNote = false
    /// El monto grande de la tarjeta: más pequeño que el de B1 (64), que ocupa la hoja entera.
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 40 // A11Y-DT: @ScaledMetric
    /// En la fila de la hoja de varios, un poco menos: va entre otras filas.
    @ScaledMetric(relativeTo: .largeTitle) private var rowAmountSize: CGFloat = 32 // A11Y-DT: @ScaledMetric
    /// La cuenta elegida sola al leer la foto (`CuentaSolaAlLeer`): sin ella, el chip de siempre.
    @Environment(\.cuentaSolaAlLeerHoja) private var cuentaSolaHoja
    /// «Recordar» tras corregir la cuenta (parte 2): lo pone la hoja de la foto.
    @Environment(\.cuentaSolaAlLeerRecordar) private var cuentaSolaRecordar

    private var isSaved: Bool { draft.status == .approved }
    private var isRow: Bool { style == .row }
    private var cardRadius: CGFloat { EstoLeiCardLayout.cornerRadius(large: largePresentation) }

    var body: some View {
        // La tarjeta puede volver a pintarse con su borrador ya borrado (desde «Ver todo»): no se lee nada de él.
        if draft.isDeleted || draft.modelContext == nil {
            EmptyView()
        } else {
            card
        }
    }

    private var card: some View {
        Group {
            if isRow {
                rowLayout
            } else {
                cardLayout
            }
        }
        .sheet(item: $activeField) { field in
            ChatDraftFieldSheet(
                field: field,
                isExpense: isExpense,
                account: draft.account,
                subcategory: draft.subcategory,
                tags: currentTags,
                date: draft.effectiveDate,
                // Solo las cuentas de la moneda junto al monto, como en Nuevo registro; para cambiarla, «S/ ▾».
                currencyScope: currencyCode,
                editing: editing
            )
            .environment(\.cuentaSolaAlLeerSelector, CuentaSolaAlLeerSelectorPista.pista(for: cuentaSolaEleccion))
        }
    }

    /// La fila desplegada de la hoja de varios: lo de la tarjeta, centrado, y el chevron de «Ver todo» a la derecha,
    /// centrado en vertical en la fila (Jürgen, 25-nov-2026).
    /// El chevron ocupa una columna estrecha y su toque de 44 pt sobresale hacia el margen de la fila: con la columna
    /// entera de 44, la fila de chips se quedaba corta y «Cuenta» se cortaba (medido en el iPhone 14).
    private var rowLayout: some View {
        VStack(spacing: DS.Spacing.sm) {
            descriptionLine
            amountLine
            categoryBlock
            bottomRow
            lineUnderChips
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing, EstoLeiCardLayout.chevronColumn)
        .overlay(alignment: .trailing) {
            seeAllButton
                .padding(.trailing, -(EstoLeiCardLayout.chevronHitTarget - EstoLeiCardLayout.chevronColumn) / 2)
        }
        .accessibilityElement(children: .contain)
    }

    private var cardLayout: some View {
        VStack(spacing: DS.Spacing.md) {
            // Lo de arriba deja sitio al chevron a cada lado; la fila de chips va a todo el ancho, por debajo de él, o
            // el chip de la cuenta se cortaba («Selecciona…», medido en el iPhone 14).
            VStack(spacing: DS.Spacing.md) {
                descriptionLine
                amountLine
                categoryBlock
            }
            .padding(.horizontal, EstoLeiCardLayout.chevronColumn)
            if isSaved {
                savedLine
            } else {
                bottomRow
                lineUnderChips
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        // «Ver todo» a la derecha y centrado en vertical: ya no ocupa la primera fila (Jürgen, 25-nov-2026).
        .overlay(alignment: .trailing) {
            if !isSaved {
                seeAllButton
                    .padding(.trailing, DS.Spacing.xs)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(.thCard)
        )
        // Sin contorno, sobre el glass de la hoja a media altura no se veía dónde terminaba la tarjeta por arriba
        // (encargo del 2026-11-23). Va encima del relleno, dentro del borde: no cambia el tamaño de la tarjeta. En grande,
        // el borde de los widgets del Panel (`solidCard`), sobre el fondo sólido de la hoja.
        .overlay {
            if largePresentation {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(theme.cardBorder, lineWidth: EstoLeiCardLayout.edgeWidth)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(EstoLeiCardLayout.edge, lineWidth: EstoLeiCardLayout.edgeWidth)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice_draft_card")
    }

    // MARK: - «Ver todo»

    /// Un chevron, como el de una fila que lleva a su detalle; VoiceOver lo lee como «Ver el registro completo».
    private var seeAllButton: some View {
        Button(action: onOpenDetails) {
            Image(systemName: "chevron.right")
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
                .frame(
                    minWidth: EstoLeiCardLayout.chevronHitTarget,
                    minHeight: EstoLeiCardLayout.chevronHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.EstoLei.seeAllA11y)
        .accessibilityIdentifier("esto_lei_ver_todo")
    }

    // MARK: - Descripción y monto

    @ViewBuilder
    private var descriptionLine: some View {
        if editsNoteInPlace, !isSaved {
            DraftNoteInlineEditor(
                draft: draft, title: title, isEditing: $isEditingNote, isCentered: true, isProminent: true)
        } else {
            // Con peso y en el color del texto (Jürgen, 25-nov-2026: en gris fino no se leía); el monto sigue mandando.
            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("esto_lei_description")
        }
    }

    private var currencyCode: String {
        draft.account?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
    }

    /// Las monedas de la cápsula, como en Nuevo registro (Jürgen, 25-nov-2026). Guardado, ya no se cambia nada.
    private var currencyOptions: [AmountCurrencyOption] {
        guard !isSaved else { return [] }
        return EstoLeiCurrencyChoice.options(accounts: allAccounts, current: currencyCode)
    }

    /// La moneda es la de la cuenta: elegir una es elegir la cuenta que la tiene, y se guarda al momento.
    private func chooseCurrency(_ code: String) {
        guard let account = EstoLeiCurrencyChoice.account(for: code, selected: draft.account, accounts: allAccounts),
              account.persistentModelID != draft.account?.persistentModelID else { return }
        DS.Haptic.selection()
        draft.account = account
        VoiceDraftFieldEditing.persist(draft, context: modelContext)
    }

    /// La cápsula de moneda de B1, con el menú de Nuevo registro.
    private var amountLine: some View {
        // La cápsula centrada en vertical con el monto: por la línea de base quedaba muy abajo (Jürgen, 25-nov-2026).
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            AmountCurrencyCapsule(
                label: appPreferences.currencyIdentifier(for: currencyCode),
                options: currencyOptions,
                current: currencyCode.uppercased(),
                identifierPrefix: "esto_lei",
                onChoose: chooseCurrency
            )
            Text(amountNumber)
                .font(.system(size: isRow ? rowAmountSize : amountSize, weight: .bold, design: .rounded))
                .foregroundStyle(draft.amount == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(amountColor))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel(draft.amount == nil ? L10n.Chat.Draft.missingAmount : formattedAmount)
                .accessibilityIdentifier("esto_lei_amount")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Categoría

    /// Elegida, la subcategoría rellena de su color y debajo su categoría y su necesidad, como en B1. Si falta, el chip
    /// ámbar «● Elige categoría ▾» en su sitio; si falta el monto, el suyo al lado, que abre «Ver todo» (el teclado del
    /// monto vive en el editor completo).
    @ViewBuilder
    private var categoryBlock: some View {
        if let subcategory = draft.subcategory {
            VStack(spacing: DS.Spacing.sm) {
                SelectionChip(
                    icon: "tag",
                    text: subcategory.name,
                    isSelected: true,
                    color: Color(hex: subcategory.safeCategory.colorHex),
                    fillsWhenSelected: true
                ) {
                    if !isSaved { activeField = .subcategory }
                }
                .allowsHitTesting(!isSaved)
                // Otro id que el de lo que falta: un XCUITest que elige la categoría espera que «falta» se vaya.
                .accessibilityIdentifier("esto_lei_subcategory")

                CategoryNeedLine(
                    category: subcategory.safeCategory,
                    need: isExpense ? subcategory.need : nil,
                    onNeedTap: onOpenDetails
                )
                .allowsHitTesting(!isSaved)

                // «Comercios en común»: la categoría la propuso la lista común (sin memoria de ese comercio).
                if !isSaved, let comercio = ComerciosEnComunLinea.comercio(
                    note: draft.note, subcategory: subcategory, isExpense: isExpense,
                    subcategories: allSubcategories, context: modelContext) {
                    ComerciosEnComunLinea(comercio: comercio) { activeField = .subcategory }
                }
            }
        } else if !isSaved {
            HStack(spacing: DS.Spacing.sm) {
                if draft.amount == nil {
                    EstoLeiMissingChip(title: L10n.Chat.Draft.missingAmount, action: onOpenDetails)
                        .accessibilityIdentifier("esto_lei_missing_amount")
                }
                EstoLeiMissingChip(title: L10n.EstoLei.chooseCategory) { activeField = .subcategory }
                    .accessibilityIdentifier("voice_draft_chip_subcategory")
            }
        }
        if draft.subcategory != nil, draft.amount == nil, !isSaved {
            EstoLeiMissingChip(title: L10n.Chat.Draft.missingAmount, action: onOpenDetails)
                .accessibilityIdentifier("esto_lei_missing_amount")
        }
    }

    // MARK: - Hoy · Cuenta · #

    private var bottomRow: some View {
        let presentation = accountChipPresentation
        return OneLineChipRow(spacing: DS.Spacing.sm) {
            RecordDateValueChip(text: ChatDraftFormatting.dateLabel(draft.effectiveDate)) {
                activeField = .date
            }
            .accessibilityIdentifier("voice_draft_chip_date")

            RecordValueChip(
                icon: "creditcard",
                iconColor: draft.account.map { Color(hex: $0.colorHex) },
                text: presentation.titulo,
                isSet: draft.account != nil,
                isMissing: presentation.estilo == .falta
            ) {
                activeField = .account
            }
            // En el chip dice «Cuenta», que no se corta (Jürgen, 25-nov-2026); VoiceOver sigue oyendo qué hacer.
            .accessibilityLabel(presentation.accessibilityLabel
                ?? (draft.account == nil ? L10n.Chat.Draft.selectAccount : presentation.titulo))
            .accessibilityIdentifier("voice_draft_chip_account")
            .shrinksInChipRow()

            TagCountChip(tags: currentTags) {
                activeField = .tags
            }
            .accessibilityIdentifier("voice_draft_chip_tags")
        }
        .frame(maxWidth: .infinity)
    }

    private var savedLine: some View {
        Label {
            Text(draft.account.map { L10n.EstoLei.savedIn($0.name) } ?? L10n.Chat.Draft.savedBadge)
                .lineLimit(1)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
        }
        .font(DS.Typography.label)
        .foregroundStyle(DS.Semantic.successForeground)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("voice_draft_saved")
    }

    /// La línea ✦ de la cuenta elegida, en UNA línea (ajuste de Jürgen al elegir A), o la de «Recordar».
    @ViewBuilder
    private var lineUnderChips: some View {
        if let recordada = cuentaSolaHoja.recordada(draft) {
            EstoLeiWhyLine(text: recordada)
                .accessibilityIdentifier("cuenta_sola_recordada")
        } else if let oferta = recordarOferta, let acciones = cuentaSolaRecordar {
            CuentaSolaAlLeerRecordarLine(
                palabras: AccountCaptureRule.cleaned(oferta.value),
                onRecordar: { acciones.recordar(draft, oferta) },
                onDescartar: { acciones.descartar(draft) })
        } else if let porque = accountChipPresentation.porque {
            EstoLeiWhyLine(text: porque)
                .accessibilityIdentifier("cuenta_sola_porque")
        }
    }

    /// La regla que ofrece «Recordar» si la persona cambió la cuenta del borrador.
    private var recordarOferta: AccountCaptureRule? {
        guard cuentaSolaRecordar != nil else { return nil }
        return cuentaSolaHoja.ofertaRecordar(draft, currentAccountID: draft.account?.shortcutID)
    }

    // MARK: - Cuenta sola al leer

    private var cuentaSolaEleccion: CuentaSolaAlLeer.Eleccion? { cuentaSolaHoja.eleccion(for: draft) }

    private var accountChipPresentation: CuentaSolaAlLeerChipPresentacion {
        CuentaSolaAlLeerChipPresentacion.make(
            eleccion: cuentaSolaEleccion,
            currentAccountID: draft.account?.shortcutID,
            accountName: draft.account?.name,
            muestraPorque: cuentaSolaHoja.muestraPorque(draft),
            // «Cuenta» y no «Selecciona cuenta»: en la fila de chips se cortaba (Jürgen, 25-nov-2026).
            selectAccount: L10n.Transaction.account)
    }

    // MARK: - Edición

    private var editing: ChatDraftEditing {
        VoiceDraftFieldEditing.editing(
            draft: draft, accounts: allAccounts, subcategories: allSubcategories, tags: allTags, context: modelContext
        )
    }

    // MARK: - Datos

    /// La nota es lo que el usuario dijo («Almuerzo»); sin nota, la subcategoría hace de título.
    private var title: String {
        if !draft.note.isEmpty { return draft.note }
        return draft.subcategory?.name ?? L10n.Common.uncategorized
    }

    private var currentTags: [Tag] {
        guard let ids = draft.resolvedTagIDs() else { return [] }
        return allTags.filter { ids.contains($0.id) }
    }

    /// El borrador guarda el importe con signo: negativo es gasto.
    private var isExpense: Bool { (draft.amount ?? -1) < 0 }

    /// El número sin moneda, que va en la cápsula, y sin signo, como en 2.1 (card ex73): lo que dice si es gasto o
    /// ingreso es el color. Sin monto, «0.00» en gris, como el campo vacío de B1.
    private var amountNumber: String {
        guard let amount = draft.amount else { return AmountInputHelper.formatWithGrouping(0) }
        return AmountInputHelper.formatWithGrouping(VoiceEntryFlowLogic.reviewDisplayedAmount(amount))
    }

    private var formattedAmount: String {
        guard let amount = draft.amount else { return "–" }
        return appPreferences.currency(
            VoiceEntryFlowLogic.reviewDisplayedAmount(amount), currencyCode: currencyCode, forceFullPrecision: true)
    }

    /// Se colorea la excepción, no la norma: el gasto va en el color del texto y el ingreso en el tono oscurecido que
    /// sí se lee sobre la tarjeta (`.claude/rules/swiftui-ds.md`).
    private var amountColor: Color {
        Color.amountTint(isIncome: !isExpense)
    }
}

/// Lo que falta, en ámbar y con su flecha: «● Elige categoría ▾». Lo comparten la tarjeta de un registro y la fila
/// desplegada de la hoja de varios.
struct EstoLeiMissingChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(DS.Semantic.warningForeground)
                    .frame(width: 6, height: 6) // A11Y-DT: punto decorativo
                    .accessibilityHidden(true)
                Text(title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(DS.Typography.captionSmall)
                    .accessibilityHidden(true)
            }
            .font(DS.Typography.labelSmall)
            .foregroundStyle(DS.Semantic.warningForeground)
            .padding(.horizontal, DS.Chip.paddingH)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(DS.Semantic.warningBackground))
            .overlay(Capsule().strokeBorder(DS.Semantic.warningForeground, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(L10n.UXL2.missingChipValue)
    }
}

/// «✦ Elegí BCP Crédito porque la imagen lo dice…» en UNA línea (ajuste de Jürgen al elegir A). Si la frase entera no
/// cabe, va su primera oración («Elegí BCP Crédito porque la imagen lo dice.»); si ni esa, se corta. VoiceOver lee la
/// frase entera.
struct EstoLeiWhyLine: View {
    let text: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            line(text, fitsWhole: true)
            line(EstoLeiLogic.firstSentence(text), fitsWhole: true)
            line(text, fitsWhole: false)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isStaticText)
    }

    /// Un solo `Text`: la estrella en el acento y la frase en gris. `fitsWhole`: a su ancho entero, para que
    /// `ViewThatFits` sepa si cabe; la última opción se corta con «…».
    private func line(_ sentence: String, fitsWhole: Bool) -> some View {
        let star = Text(verbatim: "✦").foregroundStyle(.thAccentText)
        let words = Text(sentence).foregroundStyle(.secondary)
        return Text("\(star) \(words)")
            .font(DS.Typography.caption)
            .lineLimit(1)
            .fixedSize(horizontal: fitsWhole, vertical: false)
    }
}

/// La cápsula de moneda de la tarjeta de «Esto leí»: las mismas monedas y la misma elección que Nuevo registro y la
/// Bandeja (`AmountCurrencyMenuLogic`). Elegir una moneda es elegir la cuenta que la tiene.
enum EstoLeiCurrencyChoice {
    /// Las cuentas que tiene en cuenta: activas y de la persona, con su tarjeta.
    @MainActor
    static func menuAccounts(_ accounts: [Account]) -> [AmountCurrencyAccount<PersistentIdentifier>] {
        let usable = accounts.filter { !$0.isArchived && !$0.isSystemAccount }
        let nodes = usable.map { AccountLineNode($0) }
        return usable.map { account in
            let members = AccountCardLogic.liveMembers(of: account.shortcutID, nodes: nodes)
            return AmountCurrencyAccount(
                id: account.persistentModelID,
                currencyCode: account.currencyCode.uppercased(),
                cardMembers: members.count > 1
                    ? members.compactMap { node in usable.first { $0.shortcutID == node.id }?.persistentModelID }
                    : []
            )
        }
    }

    @MainActor
    static func options(accounts: [Account], current: String) -> [AmountCurrencyOption] {
        AmountCurrencyMenuLogic.options(accounts: menuAccounts(accounts), current: current)
    }

    /// La cuenta a la que lleva elegir `code`: la misma si ya está en esa moneda, la línea de su tarjeta en esa moneda o
    /// la primera cuenta en ella. `nil` si no hay ninguna.
    @MainActor
    static func account(for code: String, selected: Account?, accounts: [Account]) -> Account? {
        let menu = menuAccounts(accounts)
        guard let id = AmountCurrencyMenuLogic.target(
            for: code, selected: selected?.persistentModelID, accounts: menu) else { return nil }
        return accounts.first { $0.persistentModelID == id }
    }
}

/// Lo que escriben los selectores de una fila de «Esto leí» en su borrador. Lo comparten la tarjeta de un registro y la
/// fila de la hoja de varios (`MultiDraftReviewList`).
enum VoiceDraftFieldEditing {
    /// Los selectores devuelven IDs; aquí vuelven a ser modelos contra lo cargado (nunca `model(for:)`, que fabrica
    /// un objeto aunque ya no exista). Importe y nota se corrigen en el formulario completo.
    @MainActor
    static func editing(
        draft: InboxDraft,
        accounts: [Account],
        subcategories: [Subcategory],
        tags: [Tag],
        context: ModelContext
    ) -> ChatDraftEditing {
        ChatDraftEditing(
            onAmountChange: { _ in },
            onAccountChange: { id in
                draft.account = accounts.first { $0.persistentModelID == id }
                persist(draft, context: context)
            },
            onSubcategoryChange: { id in
                draft.subcategory = subcategories.first { $0.persistentModelID == id }
                persist(draft, context: context)
            },
            onDateChange: { date in
                draft.date = date
                persist(draft, context: context)
            },
            onTagsChange: { ids in
                draft.setTags(from: tags.filter { ids.contains($0.persistentModelID) })
                persist(draft, context: context)
            },
            onNoteChange: { _ in }
        )
    }

    /// Lo que falta se recalcula con el mismo criterio que la Bandeja (`needsUserInput`), para que su fila diga lo
    /// mismo si el usuario cierra sin guardar.
    @MainActor
    static func persist(_ draft: InboxDraft, context: ModelContext) {
        var needs: [String] = []
        if draft.account == nil { needs.append(DraftInputRequirement.account) }
        if draft.subcategory == nil { needs.append(DraftInputRequirement.subcategory) }
        if draft.amount == nil { needs.append(DraftInputRequirement.amount) }
        draft.needsUserInput = needs
        draft.updatedAt = Date.now
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("VoiceDraftReviewCard: Error saving draft change: \(error)")
            #endif
        }
    }
}
