//
//  GroupSplitLineSheet.swift
//  Yala
//
//  La hoja de una línea de «Tu parte» (Grupos B; maqueta `opcion-b.html`, escenario 1, paso 3): segmento Gasto |
//  Recarga, el importe y lo que pide cada tipo. Un gasto pide su categoría; una recarga, la cuenta a la que va.
//
//  EL DESTINO SOLO OFRECE CUENTAS QUE EL PUENTE ACEPTA. El puente (PR #737) crea la recarga solo si la cuenta es tuya, no
//  es de sistema y lleva la divisa del gasto; si no, deja tu parte en una sola línea sin avisar. `AccountSelectorSheet`
//  con `currencyFilter` ya quita las de sistema y las archivadas y deja solo las de esa divisa. La cuenta de la que sale
//  la recarga tampoco se ofrece.
//
//  No guarda nada: entrega la línea a la tarjeta (`onSave`), que es quien tiene la lista.
//

import SwiftData
import SwiftUI

struct GroupSplitLineSheet: View {

    // MARK: - Input

    /// La línea que se edita; `nil` para una nueva.
    let initialLine: GroupSplitLinesRecipe.Line?
    /// Importe con que abre una línea nueva (lo que falta para cuadrar).
    let suggestedAmount: Decimal?
    let currencyCode: String
    let transferSourceName: String
    var transferSourceAccount: Account? = nil
    /// «Eliminar línea» solo si la línea existe y quedan otras.
    let canDelete: Bool
    let onSave: (GroupSplitLinesRecipe.Line) -> Void
    let onDelete: () -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var accounts: [Account]
    @Query private var subcategories: [Subcategory]

    // MARK: - State

    @State private var draft: GroupSplitLinesEditorLogic.Draft
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedAccount: Account?
    @State private var showsSubcategorySelector = false
    @State private var showsAccountSelector = false
    @FocusState private var amountFocused: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 44 // A11Y-DT: @ScaledMetric

    init(
        initialLine: GroupSplitLinesRecipe.Line?,
        suggestedAmount: Decimal?,
        currencyCode: String,
        transferSourceName: String,
        transferSourceAccount: Account? = nil,
        canDelete: Bool,
        onSave: @escaping (GroupSplitLinesRecipe.Line) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.initialLine = initialLine
        self.suggestedAmount = suggestedAmount
        self.currencyCode = currencyCode
        self.transferSourceName = transferSourceName
        self.transferSourceAccount = transferSourceAccount
        self.canDelete = canDelete
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: initialLine.map {
            GroupSplitLinesEditorLogic.Draft(line: $0, currencyCode: currencyCode, locale: .current)
        } ?? GroupSplitLinesEditorLogic.Draft(suggestedAmount: suggestedAmount, currencyCode: currencyCode, locale: .current))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    kindSelector
                    amountField
                    switch draft.kind {
                    case .expense: subcategoryChip
                    case .transfer: transferBlock
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { bottomButtons }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.SplitLines.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
            .sheet(isPresented: $showsSubcategorySelector) {
                SubcategorySelectorSheet(selectedSubcategory: $selectedSubcategory, transactionType: .expense)
            }
            .sheet(isPresented: $showsAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $selectedAccount,
                    title: L10n.Transaction.destinationAccount,
                    excludeAccount: transferSourceAccount,
                    currencyFilter: currencyCode
                )
            }
            .onChange(of: selectedSubcategory) { _, new in draft.subcategoryID = new?.shortcutID }
            .onChange(of: selectedAccount) { _, new in draft.destinationAccountID = new?.shortcutID }
            .onAppear {
                selectedSubcategory = draft.subcategoryID.flatMap { id in subcategories.first { $0.shortcutID == id } }
                selectedAccount = draft.destinationAccountID.flatMap { id in accounts.first { $0.shortcutID == id } }
            }
        }
    }

    // MARK: - Gasto | Recarga

    /// Molde de `SplitTypeSegmentedSelector`: cápsula del acento con su texto encima (`thOnAccent`). Con letra de
    /// accesibilidad las dos opciones van una debajo de otra.
    private var kindSelector: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.none))
        return layout {
            kindOption(.expense, title: L10n.Transaction.TransactionType.expense)
            kindOption(.transfer, title: L10n.Groups.SplitLines.kindTransfer)
        }
        .padding(DS.Spacing.xs)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.primary.opacity(0.06)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Groups.SplitLines.kindPicker)
        .accessibilityIdentifier("split_line_kind")
    }

    private func kindOption(_ kind: GroupSplitLinesRecipe.Kind, title: String) -> some View {
        let isSelected = draft.kind == kind
        return Button {
            guard !isSelected else { return }
            DS.Haptic.selection()
            dsWithAnimation(reduceMotion) { draft.kind = kind }
        } label: {
            Text(title)
                .font(DS.Typography.label.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AnyShapeStyle(.thOnAccent) : AnyShapeStyle(.secondary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(isSelected ? AnyShapeStyle(.thAccent) : AnyShapeStyle(Color.clear)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(kind == .expense ? "split_line_kind_expense" : "split_line_kind_transfer")
    }

    // MARK: - Importe

    private var amountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(appPreferences.currencyIdentifier(for: currencyCode))
                .font(.system(size: amountSize * 0.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            TextField("0", text: $draft.amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize()
                .focused($amountFocused)
                .onChange(of: draft.amountText) { _, new in
                    let filtered = AmountInputHelper.filterAmountInput(new)
                    if filtered != new { draft.amountText = filtered }
                }
                .accessibilityLabel(L10n.Transaction.amount)
                .accessibilityIdentifier("split_line_amount")
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { amountFocused = true }
    }

    // MARK: - Gasto: categoría

    private var subcategoryChip: some View {
        SelectionChip(
            icon: selectedSubcategory?.iconName ?? "tag",
            text: selectedSubcategory?.name ?? L10n.Groups.SplitLines.chooseCategory,
            isSelected: selectedSubcategory != nil,
            color: selectedSubcategory.map { Color(hex: $0.colorHex ?? $0.safeCategory.colorHex) },
            isMissing: selectedSubcategory == nil
        ) {
            showsSubcategorySelector = true
        }
        .accessibilityIdentifier("split_line_subcategory")
    }

    // MARK: - Recarga: de dónde a dónde

    private var transferBlock: some View {
        VStack(spacing: DS.Spacing.lg) {
            RecordSelectorChips(spacing: DS.Spacing.sm, alignment: .center) {
                Text(L10n.Groups.SplitLines.from(transferSourceName))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                SelectionChip(
                    icon: "creditcard",
                    text: destinationAccount?.name ?? L10n.Groups.SplitLines.chooseAccount,
                    isSelected: destinationAccount != nil,
                    color: destinationAccount.map { Color(hex: $0.colorHex) },
                    isMissing: destinationAccount == nil
                ) {
                    showsAccountSelector = true
                }
                .accessibilityIdentifier("split_line_destination")
            }

            Text(transferExplanation)
                .font(DS.Typography.subheadline)
                .foregroundStyle(destinationIsUnavailable ? AnyShapeStyle(Color.groupOweAmount) : AnyShapeStyle(.secondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    /// La cuenta elegida, solo si el puente la acepta. Una que dejó de servir no se pinta como elegida.
    private var destinationAccount: Account? {
        guard let account = selectedAccount, !destinationIsUnavailable else { return nil }
        return account
    }

    private var destinationIsUnavailable: Bool {
        guard draft.destinationAccountID != nil else { return false }
        return !GroupSplitLinesEditorLogic.linesWithUnavailableDestination(
            [draft.line(locale: .current)],
            destinations: GroupSplitLinesCard.destinationInfo(accounts),
            currencyCode: currencyCode
        ).isEmpty
    }

    private var transferExplanation: String {
        if destinationIsUnavailable { return L10n.Groups.SplitLines.destinationUnavailable }
        guard let account = destinationAccount else { return L10n.Groups.SplitLines.transferExplanationNoAccount }
        return L10n.Groups.SplitLines.transferExplanation(account.name)
    }

    // MARK: - Botones

    private var bottomButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaPrimaryButton(L10n.Groups.SplitLines.saveLine, icon: "checkmark.circle.fill") {
                onSave(draft.line(locale: .current))
                dismiss()
            }
            .disabled(!GroupSplitLinesEditorLogic.canSave(
                draft, currencyCode: currencyCode, locale: .current,
                destinations: GroupSplitLinesCard.destinationInfo(accounts)
            ))
            .accessibilityIdentifier("split_line_save")

            if canDelete {
                YalaSecondaryButton(L10n.Groups.SplitLines.deleteLine) {
                    onDelete()
                    dismiss()
                }
                .accessibilityIdentifier("split_line_delete")
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.lg)
        .background(.thBackground)
    }
}

// MARK: - Previews

#if DEBUG

#Preview("Recarga a Sip") {
    let seeded = GroupSplitLinesPreviewFixture.make()
    GroupSplitLineSheet(
        initialLine: GroupSplitLinesPreviewFixture.piaLines(seeded)[0],
        suggestedAmount: nil,
        currencyCode: "PEN",
        transferSourceName: "Grupos",
        canDelete: true,
        onSave: { _ in },
        onDelete: {}
    )
    .modelContainer(seeded.container)
    .previewAppPreferences()
}

#Preview("Línea nueva") {
    let seeded = GroupSplitLinesPreviewFixture.make()
    GroupSplitLineSheet(
        initialLine: nil,
        suggestedAmount: 10,
        currencyCode: "PEN",
        transferSourceName: "Grupos",
        canDelete: false,
        onSave: { _ in },
        onDelete: {}
    )
    .modelContainer(seeded.container)
    .previewAppPreferences()
}
#endif
