//
//  ExportFiltersStepView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

struct ExportFiltersStepView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Data Queries

    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Subcategory.sortOrder) private var allSubcategories: [Subcategory]

    // MARK: - Local State

    // Cuentas
    @State private var selectedAccounts: Set<PersistentIdentifier> = []
    @State private var hasInitializedAccounts = false

    // Categorías y Subcategorías
    // Para simplificar, si se selecciona una categoría, se asume que se quieren todas sus subcategorías
    // O podemos permitir selección granular. El requerimiento dice "selector jerárquico".
    // Por ahora, implementaremos selección de subcategorías plana agrupada visualmente o simple.
    // Dado el tiempo, haremos selección de categorías y subcategorías independientes o vinculadas.
    // Requerimiento: "Permite abrir un selector jerárquico (categoría → subcategorías) para filtrar por una o varias subcategorías."
    @State private var selectedCategoriesState: Set<Category> = []
    @State private var selectedSubcategories: Set<Subcategory> = []
    // Control de expansión/colapso por categoría en el selector de categorías
    @State private var expandedCategories: Set<Category> = []

    // Etiquetas
    @State private var selectedTags: Set<PersistentIdentifier> = []

    // Moneda
    @State private var selectedCurrencies: Set<CurrencyCode> = Set(CurrencyCode.allCases)

    // Monto
    @State private var amountCondition: AmountFilterCondition = .any

    // Periodo
    @State private var period: ExportPeriod = .last30Days
    @State private var customDateFrom: Date? = nil
    @State private var customDateTo: Date? = nil

    // Nota
    @State private var noteContains: String = ""

    // MARK: - Sheet Presentation State
    @State private var showAccountsSheet = false
    @State private var showCategoriesSheet = false
    @State private var showTagsSheet = false
    @State private var showCurrencySheet = false

    // MARK: - Computed Properties

    private var isAccountSelectionValid: Bool {
        !selectedAccounts.isEmpty
    }

    private var isValid: Bool {
        if !isAccountSelectionValid {
            return false
        }

        // Validar rango de fechas si es personalizado
        if period == .custom {
            if let from = customDateFrom, let to = customDateTo {
                return from <= to
            }
            // Si falta alguna fecha, depende de la lógica deseada.
            // El modelo permite nil, pero la UI debería quizás exigir ambas o manejarlo.
            // Asumiremos que se requiere al menos una o que si están ambas deben ser válidas.
            return true
        }

        // Validar rango de montos
        if case .between(let min, let max) = amountCondition {
            return min <= max
        }

        return true
    }

    private var exportFilters: ExportFilters {
        // Combinar categorías seleccionadas explícitamente con las de las subcategorías
        let categoriesFromSub = Set(selectedSubcategories.map { $0.category })
        let finalCategories = selectedCategoriesState.union(categoriesFromSub)
        
        let selectedTagObjects = allTags.filter { selectedTags.contains($0.persistentModelID) }

        let selectedTagNames: [String]
        if !allTags.isEmpty && selectedTagObjects.count == allTags.count {
            // Interpretar "todas seleccionadas" como "sin filtro por etiquetas"
            selectedTagNames = []
        } else {
            selectedTagNames = selectedTagObjects.map { $0.name }
        }
        
        return ExportFilters(
            selectedAccounts: allAccounts.filter {
                selectedAccounts.contains($0.persistentModelID)
            },
            selectedCategories: Array(finalCategories),
            selectedSubcategories: Array(selectedSubcategories),
            selectedTagNames: selectedTagNames,
            selectedCurrencies: Array(selectedCurrencies),
            amountCondition: amountCondition,
            period: period,
            customDateFrom: customDateFrom,
            customDateTo: customDateTo,
            noteContains: noteContains.isEmpty ? nil : noteContains
        )
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .sheet(isPresented: $showAccountsSheet) {
                accountsSheetView
            }
            .sheet(isPresented: $showCategoriesSheet) {
                categoriesSheetView
            }
            .sheet(isPresented: $showTagsSheet) {
                tagsSheetView
            }
            .sheet(isPresented: $showCurrencySheet) {
                currencySheetView
            }
    }

    // Vista principal del paso de filtros (sin hojas)
    private var mainContent: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        dateSection

                        SectionBox(title: "Opciones de filtrado") {
                            VStack(spacing: 0) {
                                accountsContent
                                Divider().padding(.leading, 16)
                                categoriesContent
                                Divider().padding(.leading, 16)
                                tagsContent
                                Divider().padding(.leading, 16)
                                currencyContent
                                Divider().padding(.leading, 16)
                                amountContent
                                Divider().padding(.leading, 16)
                                noteContent
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Exportar datos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ExportColumnsStepView(
                            exportFilters: exportFilters,
                            onFinish: { dismiss() }
                        )
                    } label: {
                        Text("Siguiente")
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Sheets

    private var accountsSheetView: some View {
        NavigationStack {
            List {
                ForEach(allAccounts) { account in
                    Button {
                        if selectedAccounts.contains(account.persistentModelID) {
                            selectedAccounts.remove(account.persistentModelID)
                        } else {
                            selectedAccounts.insert(account.persistentModelID)
                        }
                    } label: {
                        HStack {
                            Text(account.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedAccounts.contains(account.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Seleccionar cuentas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAccountsSheet = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private var categoriesSheetView: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        SectionBox(title: "Seleccionar categorías") {
                            VStack(spacing: 0) {
                                // Fila "Seleccionar todo"
                                Button {
                                    if isEverythingSelected {
                                        clearAllCategoriesAndSubcategories()
                                    } else {
                                        selectAllCategoriesAndSubcategories()
                                    }
                                } label: {
                                    HStack {
                                        Text(
                                            isEverythingSelected
                                                ? "Deseleccionar todo" : "Seleccionar todo"
                                        )
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)

                                        Spacer()

                                        Image(
                                            systemName: isEverythingSelected
                                                ? "checkmark.circle.fill"
                                                : "circle"
                                        )
                                        .foregroundStyle(
                                            isEverythingSelected
                                                ? Color.blue
                                                : Color.gray.opacity(0.4)
                                        )
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)

                                SubsectionDivider()

                                // Lista jerárquica de categorías + subcategorías
                                ForEach(Array(allCategories.enumerated()), id: \.element.id) {
                                    index, category in
                                    VStack(spacing: 0) {
                                        // Cabecera de categoría
                                        HStack(spacing: 12) {
                                            // Icono de categoría con color (similar a Ajustes → Categorías)
                                            Circle()
                                                .fill(colorForHex(category.colorHex))
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Image(systemName: "tag")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.white)
                                                )

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(category.name)
                                                    .font(.body)  // sin negrita
                                                    .foregroundStyle(.primary)

                                                Text(subcategorySelectionSummary(for: category))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            // Estado de selección de la categoría
                                            Button {
                                                toggleCategory(category)
                                            } label: {
                                                let state = selectionState(for: category)
                                                Image(systemName: selectionIconName(for: state))
                                                    .foregroundStyle(
                                                        state == .none
                                                            ? Color.gray.opacity(0.4)
                                                            : Color.blue
                                                    )
                                            }
                                            .buttonStyle(.plain)

                                            // Botón expandir / contraer
                                            Button {
                                                toggleExpanded(category)
                                            } label: {
                                                Image(systemName: "chevron.down")
                                                    .rotationEffect(
                                                        .degrees(isExpanded(category) ? 0 : -90)
                                                    )
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)  // un poco más alta, como en la vista de Categorías
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            toggleExpanded(category)
                                        }

                                        // Subcategorías
                                        if isExpanded(category) {
                                            let subs = subcategories(for: category)

                                            ForEach(Array(subs.enumerated()), id: \.element.id) {
                                                _, subcategory in
                                                SubsectionDivider()

                                                Button {
                                                    let subsForCategory = subcategories(
                                                        for: category)

                                                    if selectedSubcategories.contains(subcategory) {
                                                        // Quitar solo esta subcategoría y asegurar que la categoría pase a estado parcial
                                                        selectedSubcategories.remove(subcategory)
                                                        selectedCategoriesState.remove(category)
                                                    } else {
                                                        // Añadir la subcategoría
                                                        selectedSubcategories.insert(subcategory)

                                                        // Si ahora todas las subcategorías de la categoría están seleccionadas,
                                                        // marcamos también la categoría como completa
                                                        let allSubsSelected =
                                                            !subsForCategory.isEmpty
                                                            && subsForCategory.allSatisfy {
                                                                selectedSubcategories.contains($0)
                                                            }
                                                        if allSubsSelected {
                                                            selectedCategoriesState.insert(category)
                                                        }
                                                    }
                                                } label: {
                                                    HStack(spacing: 12) {
                                                        // Ícono de subcategoría con mismo tamaño que el de categoría,
                                                        // pero con sangría mediante padding.
                                                        let subColor = colorForHex(
                                                            subcategory.colorHex
                                                                ?? category.colorHex)
                                                        Circle()
                                                            .fill(subColor)
                                                            .frame(width: 36, height: 36)
                                                            .overlay(
                                                                Image(systemName: "tag")
                                                                    .font(.subheadline)
                                                                    .foregroundStyle(.white)
                                                            )

                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(subcategory.name)
                                                                .foregroundStyle(.primary)
                                                                .font(.body)
                                                        }

                                                        Spacer()

                                                        let isSelected =
                                                            selectedSubcategories.contains(
                                                                subcategory)
                                                        Image(
                                                            systemName: isSelected
                                                                ? "checkmark.circle.fill" : "circle"
                                                        )
                                                        .foregroundStyle(
                                                            isSelected
                                                                ? Color.blue
                                                                : Color.gray.opacity(0.4)
                                                        )
                                                    }
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .padding(.leading, 48)  // sangría para que quede jerárquico respecto a la categoría
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }

                                    // Divider entre categorías
                                    if index < allCategories.count - 1 {
                                        SubsectionDivider()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Seleccionar categorías")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCategoriesSheet = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .onAppear {
            // Solo inicializamos la selección la primera vez,
            // cuando aún no hay nada elegido explícitamente.
            if selectedCategoriesState.isEmpty && selectedSubcategories.isEmpty {
                selectAllCategoriesAndSubcategories()
            }
        }
    }

    private var tagsSheetView: some View {
        NavigationStack {
            List {
                ForEach(allTags) { tag in
                    Button {
                        if selectedTags.contains(tag.persistentModelID) {
                            selectedTags.remove(tag.persistentModelID)
                        } else {
                            selectedTags.insert(tag.persistentModelID)
                        }
                    } label: {
                        HStack {
                            Text(tag.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedTags.contains(tag.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Seleccionar etiquetas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTagsSheet = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private var currencySheetView: some View {
        NavigationStack {
            MultiSelectionList(
                title: "Seleccionar monedas",
                items: availableCurrencies,
                selection: $selectedCurrencies,
                label: { $0.rawValue }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCurrencySheet = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    // Estado visual de selección de una categoría (para el icono de la cabecera)
    private enum CategorySelectionVisualState {
        case none
        case partial
        case all
    }

    /// Indica si todas las categorías y subcategorías visibles están seleccionadas
    private var isEverythingSelected: Bool {
        let allVisibleSubs = allSubcategories.filter { $0.isVisible }
        return selectedCategoriesState.count == allCategories.count
            && selectedSubcategories.count == allVisibleSubs.count
    }

    /// Selecciona todas las categorías y todas las subcategorías visibles
    private func selectAllCategoriesAndSubcategories() {
        selectedCategoriesState = Set(allCategories)
        let visibleSubs = allSubcategories.filter { $0.isVisible }
        selectedSubcategories = Set(visibleSubs)
    }

    /// Limpia por completo el filtro de categorías y subcategorías
    private func clearAllCategoriesAndSubcategories() {
        selectedCategoriesState.removeAll()
        selectedSubcategories.removeAll()
    }

    /// Devuelve el estado visual de una categoría para decidir el icono:
    /// - .all: todo seleccionado
    /// - .partial: algunas subcategorías seleccionadas
    /// - .none: nada seleccionado
    private func selectionState(for category: Category) -> CategorySelectionVisualState {
        let subs = subcategories(for: category)
        let selectedSubs = subs.filter { selectedSubcategories.contains($0) }

        let allSubsSelected = !subs.isEmpty && selectedSubs.count == subs.count
        let anySubSelected = !selectedSubs.isEmpty

        if selectedCategoriesState.contains(category) || allSubsSelected {
            return .all
        } else if anySubSelected {
            return .partial
        } else {
            return .none
        }
    }

    private func isExpanded(_ category: Category) -> Bool {
        expandedCategories.contains(category)
    }

    private func toggleExpanded(_ category: Category) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }

    // MARK: - Sections

    private var selectedAccountsText: String {
        if selectedAccounts.isEmpty {
            return "Ninguna seleccionada"
        }
        if selectedAccounts.count == allAccounts.count {
            return "Todas las cuentas"
        }
        return "\(selectedAccounts.count) seleccionadas"
    }

    private func syncAccountsSelection() {
        if !hasInitializedAccounts && !allAccounts.isEmpty {
            selectedAccounts = Set(allAccounts.map { $0.persistentModelID })
            hasInitializedAccounts = true
        }
    }

    private var selectedCategoriesText: String {
        // Caso 1: sin filtro aplicado (estado inicial)
        if selectedCategoriesState.isEmpty && selectedSubcategories.isEmpty {
            return "Todas las categorías"
        }

        // Caso 2: todo realmente seleccionado (todas las categorías y subcategorías visibles)
        if isEverythingSelected {
            return "Todas las categorías"
        }

        // Caso 3: hay filtro parcial; solo hablamos de subcategorías
        let count = selectedSubcategories.count

        if count == 0 {
            // Hay alguna combinación rara (p. ej. categorías sin subcategorías),
            // pero mantenemos un texto consistente.
            return "Ninguna subcategoría seleccionada"
        }

        return "\(count) subcategorías seleccionadas"
    }

    private var selectedTagsText: String {
        if allTags.isEmpty {
            return "Sin etiquetas"
        }
        if selectedTags.isEmpty || selectedTags.count == allTags.count {
            return "Todas las etiquetas"
        }
        return "\(selectedTags.count) seleccionadas"
    }
    
    private func syncTagsSelection() {
        if selectedTags.isEmpty && !allTags.isEmpty {
            selectedTags = Set(allTags.map { $0.persistentModelID })
        }
    }

    private var selectedCurrenciesText: String {
        if selectedCurrencies.count == availableCurrencies.count {
            return "Todas las disponibles"
        }
        return selectedCurrencies.map { $0.rawValue }.joined(separator: ", ")
    }

    private var accountsContent: some View {
        FilterSelectionRow(
            title: "Cuentas",
            subtitle: selectedAccountsText,
            icon: "creditcard"
        )
        .onTapGesture {
            showAccountsSheet = true
        }
        .onAppear {
            // Asegurar que, por defecto, todas las cuentas estén seleccionadas
            // para que el texto "Todas las cuentas" coincida con la selección real
            syncAccountsSelection()
        }
        .onChange(of: selectedAccounts) { _, newAccountIDs in
            if newAccountIDs.isEmpty {
                selectedCurrencies = Set(CurrencyCode.allCases)
            } else {
                let selected = allAccounts.filter { newAccountIDs.contains($0.persistentModelID) }
                let available = Set(
                    selected.map { CurrencyCode(rawValue: $0.currencyCode) ?? .pen })
                selectedCurrencies = available
            }
        }
    }

    private var categoriesContent: some View {
        FilterSelectionRow(
            title: "Categorías",
            subtitle: selectedCategoriesText,
            icon: "tag"
        )
        .onTapGesture {
            showCategoriesSheet = true
        }
    }

    private func toggleCategory(_ category: Category) {
        let subs = subcategories(for: category)

        if selectedCategoriesState.contains(category) {
            // Desmarcar categoría completa y todas sus subcategorías
            selectedCategoriesState.remove(category)
            subs.forEach { selectedSubcategories.remove($0) }
        } else {
            // Marcar categoría completa y todas sus subcategorías visibles
            selectedCategoriesState.insert(category)
            subs.forEach { selectedSubcategories.insert($0) }
        }
    }

    private func isCategorySelected(_ category: Category) -> Bool {
        selectedCategoriesState.contains(category)
    }

    private func subcategories(for category: Category) -> [Subcategory] {
        allSubcategories.filter { sub in
            sub.category == category && sub.isVisible
        }
    }

    private var tagsContent: some View {
        FilterSelectionRow(
            title: "Etiquetas",
            subtitle: selectedTagsText,
            icon: "number"
        )
        .onTapGesture {
            if !allTags.isEmpty {
                showTagsSheet = true
            }
        }
        .onAppear {
            syncTagsSelection()
        }
        .opacity(allTags.isEmpty ? 0.5 : 1.0)
    }

    private var currencyContent: some View {
        FilterSelectionRow(
            title: "Moneda",
            subtitle: selectedCurrenciesText,
            icon: "arrow.triangle.2.circlepath"
        )
        .onTapGesture {
            showCurrencySheet = true
        }
    }

    private var availableCurrencies: [CurrencyCode] {
        if selectedAccounts.isEmpty {
            return CurrencyCode.allCases
        }
        let selected = allAccounts.filter { selectedAccounts.contains($0.persistentModelID) }
        let accountCurrencies = Set(
            selected.map { CurrencyCode(rawValue: $0.currencyCode) ?? .pen })
        return CurrencyCode.allCases.filter { accountCurrencies.contains($0) }
    }

    private var amountContent: some View {
        AmountFilterView(
            condition: $amountCondition,
            currencyCode: selectedCurrencies.count == 1 ? selectedCurrencies.first : nil
        )
    }

    private var dateSection: some View {
        SectionBox(title: "Seleccione el período a exportar") {
            DateFilterView(
                period: $period,
                customDateFrom: $customDateFrom,
                customDateTo: $customDateTo
            )
        }
    }

    private var noteContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 24)

            TextField("Nota contiene...", text: $noteContains)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Texto resumen para mostrar bajo el nombre de la categoría
    /// (cuántas subcategorías están seleccionadas).
    private func subcategorySelectionSummary(for category: Category) -> String {
        let subs = subcategories(for: category)
        let total = subs.count
        let selectedCount = subs.filter { selectedSubcategories.contains($0) }.count

        if total == 0 {
            return "Sin subcategorías"
        }

        // Si la categoría está marcada completa o todas sus subcategorías lo están
        if selectedCategoriesState.contains(category) || selectedCount == total {
            return "Todas las subcategorías"
        }

        if selectedCount == 0 {
            return "Ninguna subcategoría seleccionada"
        }

        return "\(selectedCount) de \(total) subcategorías seleccionadas"
    }

    // Helper para obtener el ícono según el estado de selección de la categoría
    private func selectionIconName(for state: CategorySelectionVisualState) -> String {
        switch state {
        case .all:
            return "checkmark.circle.fill"
        case .partial:
            return "minus.circle.fill"
        case .none:
            return "circle"
        }
    }
}
