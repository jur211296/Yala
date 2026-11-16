//
//  RecordsQuickFilterBar.swift
//  Yala
//
//  Revisión 2.3, decisión 15 (F2, 9-nov). Filtrar Registros por cuenta y categoría pedía 7 toques dentro de «···» y
//  «Aplicar». Encima de la lista, una fila fija con los chips y la hoja completa en «Más filtros» para lo demás. Los
//  filtros siguen siendo de la sesión: escriben en `SessionState` como la hoja, y por eso los ven también el Panel y
//  Estadísticas.
//
//  16-nov (Jürgen, con captura): sin el chip de período (el de arriba del hero ya lo hace), chips con icono y más aire,
//  varias cuentas y categorías a la vez con las piezas de Nuevo registro y del primer presupuesto
//  (`Records/QuickFilters/`), y en la MISMA línea que los botones Lista/Calendario (`trailing`), sin el hueco de antes.
//  Si no cabe: primero «Más filtros» queda solo con su icono, y si aun así no cabe, los chips se parten en dos líneas y
//  los botones de vista se quedan arriba a la derecha.
//

import SwiftData
import SwiftUI

struct RecordsQuickFilterBar<Trailing: View>: View {
    @Bindable var viewModel: RecordsViewModel
    let accounts: [Account]
    let categories: [Category]
    let subcategories: [Subcategory]
    let onFilterChange: () -> Void
    /// Lo que va al final de la fila: los botones Lista/Calendario.
    @ViewBuilder var trailing: Trailing

    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @State private var showsAccountPicker = false
    @State private var showsCategoryPicker = false
    /// Lo marcado en cada hoja mientras está abierta. Vive aquí y no en la hoja: si iOS rehace su contenido, no se
    /// pierde. Se aplica al cerrarla.
    @State private var accountDraft: Set<PersistentIdentifier> = []
    @State private var categoryDraft: Set<PersistentIdentifier> = []

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.sm) {
                accountChip
                categoryChip
                moreChip(showsTitle: true)
                Spacer(minLength: DS.Spacing.sm)
                trailingButtons
            }
            HStack(spacing: DS.Spacing.sm) {
                accountChip
                categoryChip
                moreChip(showsTitle: false)
                Spacer(minLength: DS.Spacing.sm)
                trailingButtons
            }
            // iPhone SE: el mismo dibujo con menos relleno dentro de cada chip.
            HStack(spacing: DS.Spacing.xs) {
                accountChip(padding: DS.Spacing.sm)
                categoryChip(padding: DS.Spacing.sm)
                moreChip(showsTitle: false)
                Spacer(minLength: DS.Spacing.xs)
                trailingButtons
            }
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                FilterBandLayout(spacing: DS.Spacing.sm) {
                    accountChip
                    categoryChip
                    moreChip(showsTitle: true)
                }
                trailingButtons
            }
        }
        .sheet(isPresented: $showsAccountPicker, onDismiss: applyAccounts) {
            RecordsQuickAccountSheet(accounts: offeredAccounts, selection: $accountDraft)
        }
        .sheet(isPresented: $showsCategoryPicker, onDismiss: applyCategories) {
            RecordsQuickCategorySheet(categories: categories, subcategories: subcategories, expanded: $categoryDraft)
        }
    }

    /// Los botones de vista, centrados en el alto de un chip aunque los chips bajen a una segunda línea.
    private var trailingButtons: some View {
        trailing
            .frame(minHeight: FilterChipView.closeHitSize)
            .fixedSize()
    }

    // MARK: - Cuenta

    /// Las cuentas que se ofrecen: las de la hoja (sin archivadas, cada tarjeta una vez, sin sus líneas).
    private var offeredAccounts: [Account] {
        let roles = AccountLineLogic.resolve(accounts.map { AccountLineNode($0) })
        return accounts.filter { !$0.isArchived && !(roles[$0.shortcutID]?.isLine ?? false) }
    }

    private var shownAccountSelection: Set<PersistentIdentifier> {
        sessionState.shownAccountSelection(viewModel.selectedAccounts)
    }

    private var accountLabel: RecordsQuickChipLabel {
        let shown = shownAccountSelection
        return .accounts(selectedNames: accounts.filter { shown.contains($0.persistentModelID) }.map(\.name))
    }

    private var accountChip: some View { accountChip(padding: DS.Spacing.md) }

    private func accountChip(padding: CGFloat) -> some View {
        Button {
            accountDraft = shownAccountSelection
            showsAccountPicker = true
        } label: {
            chipLabel(
                icon: "creditcard",
                padding: padding,
                placeholder: L10n.RecordsQuickFilters23.account,
                label: accountLabel,
                many: { L10n.RecordsQuickFilters23.accountsCount($0) }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.RecordsQuickFilters23.account)
        .accessibilityValue(accessibilityValue(accountLabel, many: { L10n.RecordsQuickFilters23.accountsCount($0) }))
        .accessibilityIdentifier("records_quick_account")
    }

    /// Al cerrar la hoja: lo marcado pasa a la sesión, si cambió.
    private func applyAccounts() {
        guard accountDraft != shownAccountSelection else { return }
        viewModel.selectedAccounts = accountDraft
        onFilterChange()
    }

    // MARK: - Categoría

    /// Las categorías de la hoja con sus subcategorías visibles.
    private var categoryEntries: [RecordsQuickCategorySelectionLogic.Entry<PersistentIdentifier, PersistentIdentifier>] {
        categories.compactMap { category in
            let subs = subcategories.filter { $0.category == category && $0.isVisible }.map(\.persistentModelID)
            return subs.isEmpty ? nil : .init(id: category.persistentModelID, subcategories: subs)
        }
    }

    /// Al cerrar la hoja: lo marcado pasa a la sesión de una vez, en la forma que filtra igual que «Más filtros», si
    /// cambió.
    private func applyCategories() {
        let result = RecordsQuickCategorySelectionLogic.committed(categoryDraft, entries: categoryEntries)
        guard result.categories != viewModel.selectedCategories
            || result.subcategories != viewModel.selectedSubcategories else { return }
        SessionState.shared.performBatchFilterUpdate {
            viewModel.selectedCategories = result.categories
            viewModel.selectedSubcategories = result.subcategories
        }
        onFilterChange()
    }

    private var categoryLabel: RecordsQuickChipLabel {
        let wholeCategories = categories
            .filter { viewModel.selectedCategories.contains($0.persistentModelID) }
            .map(\.name)
        let entries = categories.map { category in
            CategoryFilterSummaryLogic.CategoryEntry(
                name: category.name,
                subcategories: subcategories
                    .filter { $0.category == category && $0.isVisible }
                    .map { (id: $0.persistentModelID, name: $0.name) }
            )
        }
        let fromSubcategories = CategoryFilterSummaryLogic.names(
            selected: viewModel.selectedSubcategories, categories: entries
        )
        return .categories(names: wholeCategories + fromSubcategories)
    }

    private var categoryChip: some View { categoryChip(padding: DS.Spacing.md) }

    private func categoryChip(padding: CGFloat) -> some View {
        Button {
            categoryDraft = RecordsQuickCategorySelectionLogic.expanded(
                selectedCategories: viewModel.selectedCategories,
                selectedSubcategories: viewModel.selectedSubcategories,
                entries: categoryEntries
            )
            showsCategoryPicker = true
        } label: {
            chipLabel(icon: "tag", padding: padding, placeholder: L10n.RecordsQuickFilters23.category, label: categoryLabel, many: { _ in "" })
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.RecordsQuickFilters23.category)
        .accessibilityValue(accessibilityValue(categoryLabel, many: { _ in "" }))
        .accessibilityIdentifier("records_quick_category")
    }

    // MARK: - Más filtros

    private func moreChip(showsTitle: Bool) -> some View {
        Button {
            viewModel.showFiltersSheet = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accentText)
                    .accessibilityHidden(true)
                if showsTitle {
                    Text(L10n.RecordsQuickFilters23.more)
                        .font(DS.Typography.subheadline)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, showsTitle ? DS.Spacing.md : DS.Spacing.none)
            .frame(minWidth: FilterChipView.closeHitSize, minHeight: FilterChipView.closeHitSize)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.RecordsQuickFilters23.more)
        .accessibilityIdentifier("records_quick_more")
    }

    // MARK: - Piezas

    /// El chip: su icono y su nombre sin nada elegido; lo elegido, relleno con el acento, cuando lo hay. 44 pt de alto.
    private func chipLabel(
        icon: String,
        padding: CGFloat,
        placeholder: String,
        label: RecordsQuickChipLabel,
        many: @MainActor (Int) -> String
    ) -> some View {
        let text: String
        switch label {
        case .placeholder: text = placeholder
        case .one(let name): text = name
        case .many(let count): text = many(count)
        }
        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: label.isActive ? "\(icon).fill" : icon)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(label.isActive ? theme.onAccent : theme.accentText)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.subheadline)
                .lineLimit(1)
        }
        .foregroundStyle(label.isActive ? theme.onAccent : Color.primary)
        .padding(.horizontal, padding)
        .frame(minHeight: FilterChipView.closeHitSize)
        .background {
            if label.isActive {
                Capsule().fill(theme.accent)
            }
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(Capsule())
    }

    private func accessibilityValue(_ label: RecordsQuickChipLabel, many: @MainActor (Int) -> String) -> String {
        switch label {
        case .placeholder: return ""
        case .one(let name): return name
        case .many(let count): return many(count)
        }
    }
}
