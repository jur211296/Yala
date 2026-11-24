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
    static let edge = Color(uiColor: UIColor { traits in // A11Y-DM: contorno propio por modo, sube con «Aumentar contraste»
        let high = traits.accessibilityContrast == .high
        return traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(high ? 0.4 : 0.2)
            : UIColor.black.withAlphaComponent(high ? 0.3 : 0.12)
    })
}

struct VoiceDraftReviewCard: View {
    let draft: InboxDraft
    /// La hoja de foto deja corregir la descripción tocándola (encargo del 2026-11-17); la de voz no lo pide.
    var editsNoteInPlace = false
    /// «Ver todo»: el editor completo del borrador, dentro de la misma hoja.
    let onOpenDetails: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var allAccounts: [Account]
    @Query(filter: #Predicate<Subcategory> { $0.isVisible == true }) private var allSubcategories: [Subcategory]
    @Query private var allTags: [Tag]

    @State private var activeField: ChatDraftField?
    @State private var isEditingNote = false
    /// El monto grande de la tarjeta: más pequeño que el de B1 (64), que ocupa la hoja entera.
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 40 // A11Y-DT: @ScaledMetric
    /// La cuenta elegida sola al leer la foto (`CuentaSolaAlLeer`): sin ella, el chip de siempre.
    @Environment(\.cuentaSolaAlLeerHoja) private var cuentaSolaHoja
    /// «Recordar» tras corregir la cuenta (parte 2): lo pone la hoja de la foto.
    @Environment(\.cuentaSolaAlLeerRecordar) private var cuentaSolaRecordar

    private var isSaved: Bool { draft.status == .approved }

    var body: some View {
        // La tarjeta puede volver a pintarse con su borrador ya borrado (desde «Ver todo»): no se lee nada de él.
        if draft.isDeleted || draft.modelContext == nil {
            EmptyView()
        } else {
            card
        }
    }

    private var card: some View {
        VStack(spacing: DS.Spacing.md) {
            descriptionLine
            amountLine
            categoryBlock
            if isSaved {
                savedLine
            } else {
                bottomRow
                lineUnderChips
            }
        }
        .padding(.top, isSaved ? DS.Spacing.lg : DS.Spacing.xxxxl)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if !isSaved {
                seeAllButton
                    .padding(.top, DS.Spacing.xs)
                    .padding(.trailing, DS.Spacing.sm)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(.thCard)
        )
        // Sin contorno, sobre el glass de la hoja a media altura no se veía dónde terminaba la tarjeta por arriba
        // (encargo del 2026-11-23). Va encima del relleno, dentro del borde: no cambia el tamaño de la tarjeta.
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(EstoLeiCardLayout.edge, lineWidth: EstoLeiCardLayout.edgeWidth)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice_draft_card")
        .sheet(item: $activeField) { field in
            ChatDraftFieldSheet(
                field: field,
                isExpense: isExpense,
                account: draft.account,
                subcategory: draft.subcategory,
                tags: currentTags,
                date: draft.effectiveDate,
                editing: editing
            )
            .environment(\.cuentaSolaAlLeerSelector, CuentaSolaAlLeerSelectorPista.pista(for: cuentaSolaEleccion))
        }
    }

    // MARK: - «Ver todo»

    private var seeAllButton: some View {
        Button(action: onOpenDetails) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(DS.Typography.captionSmall)
                    .accessibilityHidden(true)
                Text(L10n.EstoLei.seeAll)
                    .font(DS.Typography.labelSmall)
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, DS.Chip.paddingH)
            .padding(.vertical, DS.Chip.paddingV)
            .background(Capsule().fill(.quaternary))
            .frame(minHeight: 44)
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
            DraftNoteInlineEditor(draft: draft, title: title, isEditing: $isEditingNote, isCentered: true)
        } else {
            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .accessibilityIdentifier("esto_lei_description")
        }
    }

    private var currencyCode: String {
        draft.account?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
    }

    /// La cápsula de moneda de B1, sin menú: la moneda es la de la cuenta, y se cambia cambiando la cuenta.
    private var amountLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            AmountCurrencyCapsule(
                label: appPreferences.currencyIdentifier(for: currencyCode),
                options: [],
                current: currencyCode.uppercased(),
                identifierPrefix: "esto_lei",
                onChoose: { _ in }
            )
            Text(amountNumber)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
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
            .accessibilityLabel(presentation.accessibilityLabel ?? presentation.titulo)
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
            selectAccount: L10n.Chat.Draft.selectAccount)
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

extension View {
    /// Una pieza de una fila de «Esto leí» que no se toca: con la descripción en línea deja el toque al gesto de la fila,
    /// y VoiceOver la oye en el botón de fondo de la fila, no suelta.
    func rowPassesTouches(_ passes: Bool) -> some View {
        allowsHitTesting(!passes)
            .accessibilityHidden(passes)
    }
}
