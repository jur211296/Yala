//
//  ContentView.swift
//  Finaria
//
//  Panel inicial con TabBar (Panel, Planificación, Estadísticas)
//  y flujo de creación de cuenta "Configurar cuenta".
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Enums de apoyo

enum AccountType: String, CaseIterable, Identifiable {
    case general = "General"
    case cash = "Efectivo"
    case checking = "Cuenta corriente"
    case savings = "Cuenta de ahorros"
    
    var id: String { rawValue }
}

enum AdjustmentMode: String, CaseIterable, Identifiable {
    case byEntry = "Ajustar por registro"
    case changeInitialBalance = "Cambiar saldo inicial"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .byEntry:
            return "Escribe el saldo correcto y crearemos un registro de corrección. Úsalo si se te olvidó registrar algunos gastos."
        case .changeInitialBalance:
            return "Escribe el saldo correcto y cambiaremos el saldo inicial en tu cuenta. Usa esto si no has registrado durante mucho tiempo."
        }
    }
}

enum CurrencyCode: String, CaseIterable, Identifiable {
    case pen = "PEN"
    case usd = "USD"
    case eur = "EUR"
    
    var id: String { rawValue }
}

func currencyInfo(for currency: CurrencyCode) -> (name: String, code: String, flag: String) {
    switch currency {
    case .pen:
        return ("sol peruano", "PEN", "🇵🇪")
    case .usd:
        return ("dólar estadounidense", "USD", "🇺🇸")
    case .eur:
        return ("euro", "EUR", "🇪🇺")
    }
}

// Paleta de colores estándar para cuentas a partir de su hex
func colorForHex(_ hex: String) -> Color {
    switch hex {
    case "#FF9F0A":
        return Color.orange
    case "#30D158":
        return Color.green
    case "#FF375F":
        return Color.red
    case "#0A84FF":
        return Color.blue
    case "#5E5CE6":
        return Color.purple
    case "#FFD60A":
        return Color.yellow
    case "#1C3556":
        return Color(red: 0.11, green: 0.21, blue: 0.34)
    default:
        return .gray
    }
}

// Ícono estándar sugerido según el tipo de cuenta
func iconName(for accountType: AccountType) -> String {
    switch accountType {
    case .general:
        return "creditcard"
    case .cash:
        return "banknote.fill"
    case .checking:
        return "building.columns.fill"
    case .savings:
        return "banknote"
    }
}

// Ícono efectivo para mostrar según los datos actuales de la cuenta
func displayIconName(for account: Account) -> String {
    // Si ya hay un icono personalizado distinto del default antiguo, úsalo
    if !account.iconName.isEmpty && account.iconName != "building.columns.fill" {
        return account.iconName
    }

    // Si no, derivamos el icono a partir del tipo de cuenta
    if let type = AccountType(rawValue: account.type) {
        return iconName(for: type)
    }

    // Fallback seguro
    return "building.columns.fill"
}

// MARK: - ContentView

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - Tab principal con 3 secciones

struct MainTabView: View {
    var body: some View {
        TabView {
            PanelView()
                .tabItem {
                    Label("Panel", systemImage: "house.fill")
                }
            
            PlanningView()
                .tabItem {
                    Label("Planificación", systemImage: "calendar")
                }
            
            StatisticsView()
                .tabItem {
                    Label("Estadísticas", systemImage: "chart.bar.xaxis")
                }
        }
        .tint(.black)
    }
}

// MARK: - Panel (pantalla de inicio)

struct PanelView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    
    @State private var isPresentingAccountForm = false
    @State private var isPresentingSettings = false
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen.rawValue
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

    private var defaultCurrency: CurrencyCode {
        CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
    }

    private var accountsSortOrderNames: [String] {
        accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
    }
    
    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }
    
    private var orderedActiveAccounts: [Account] {
        let order = accountsSortOrderNames
        let indexByName = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        
        return activeAccounts.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]
            
            switch (ia, ib) {
            case let (x?, y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name < b.name
            }
        }
    }

    // Saldo total en la moneda predeterminada de la app
    private var totalBalanceInDefaultCurrency: Double {
        activeAccounts.reduce(0) { partial, account in
            let original = Decimal(account.initialBalance)
            let converted = convert(original, from: account.currencyCode, to: defaultCurrency.rawValue)
            let convertedDouble = (converted as NSDecimalNumber).doubleValue
            return partial + convertedDouble
        }
    }

    private var formattedTotalBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: totalBalanceInDefaultCurrency)) ?? "0.00"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        accountsSection
                        totalBalanceSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Panel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $isPresentingAccountForm) {
                AccountFormView(
                    existingNames: accounts.map { $0.name }
                )
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsRootView()
            }
        }
        // -----------------------------------------------------------------
        // FIN-18: Semilla de categorías por defecto
        //
        // Esta llamada inicializa las categorías y subcategorías SOLO si
        // todavía no existe ninguna categoría en la base de datos.
        //
        // NO eliminar ni modificar esta llamada sin revisar el impacto en
        // la experiencia de onboarding y sin aprobación explícita del PO.
        // -----------------------------------------------------------------
        .onAppear {
            seedCategoriesIfNeeded(in: modelContext)
        }
    }
    
    // Sección de tarjetas de cuentas (incluye tarjeta "Agregar cuenta")
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cuentas")
                .font(.title2.weight(.semibold))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(orderedActiveAccounts) { account in
                        AccountCardView(account: account)
                    }
                    
                    AddAccountCardView {
                        isPresentingAccountForm = true
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var totalBalanceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Saldo total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("\(currencyInfo(for: defaultCurrency).code) \(formattedTotalBalance)")
                .font(.title3.weight(.semibold))
        }
        .padding(.top, 8)
    }
}

// MARK: - Ajustes (pantalla principal)

struct SettingsRootView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen.rawValue
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo consistente con el estilo Liquid Glass de Finaria
                PanelBackgroundView()
                
                ScrollView {
                    VStack(spacing: 24) {
                        registrosSection
                        personalizacionSection
                        datosSection
                        seguridadSection
                        soporteSection
                        legalSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .tint(.black)
    }
    
    // MARK: - Moneda predeterminada de la app
    
    private var defaultCurrency: CurrencyCode {
        CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
    }
    
    private var defaultCurrencyBinding: Binding<CurrencyCode> {
        Binding<CurrencyCode>(
            get: { defaultCurrency },
            set: { newValue in
                defaultCurrencyCodeRaw = newValue.rawValue
            }
        )
    }

    // MARK: Secciones
    
    private var registrosSection: some View {
        SectionBox(title: "Registros") {
            VStack(spacing: 0) {
                NavigationLink {
                    AccountsSettingsListView()
                } label: {
                    settingsRow(title: "Cuentas", systemImage: "creditcard")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    CategoriesSettingsListView()
                } label: {
                    settingsRow(title: "Categorías", systemImage: "tag")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Etiquetas")
                } label: {
                    settingsRow(title: "Etiquetas", systemImage: "number")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Pagos favoritos")
                } label: {
                    settingsRow(title: "Pagos favoritos", systemImage: "star")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Pagos planificados")
                } label: {
                    settingsRow(title: "Pagos planificados", systemImage: "calendar.badge.clock")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Notificaciones")
                } label: {
                    settingsRow(title: "Notificaciones", systemImage: "bell")
                }
            }
        }
    }
    
    private var personalizacionSection: some View {
        SectionBox(title: "Personalización") {
            VStack(spacing: 0) {
                NavigationLink {
                    SettingsPlaceholderView(title: "Temas")
                } label: {
                    settingsRow(title: "Temas", systemImage: "paintpalette")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Ícono de la aplicación")
                } label: {
                    settingsRow(title: "Ícono de la aplicación", systemImage: "app")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    CurrencySelectorView(selectedCurrency: defaultCurrencyBinding)
                } label: {
                    preferredCurrencyRow
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Tipo de cambio")
                } label: {
                    settingsRow(title: "Tipo de cambio", systemImage: "arrow.2.squarepath")
                }
            }
        }
    }
    
    private var datosSection: some View {
        SectionBox(title: "Datos") {
            VStack(spacing: 0) {
                NavigationLink {
                    SettingsPlaceholderView(title: "Estado de sincronización iCloud")
                } label: {
                    settingsRow(title: "Estado de sincronización iCloud", systemImage: "icloud")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Importar archivo")
                } label: {
                    settingsRow(title: "Importar archivo", systemImage: "tray.and.arrow.down")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Exportar datos")
                } label: {
                    settingsRow(title: "Exportar datos", systemImage: "square.and.arrow.up")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Vaciar datos")
                } label: {
                    settingsRow(title: "Vaciar datos", systemImage: "trash")
                }
            }
        }
    }
    
    private var seguridadSection: some View {
        SectionBox(title: "Seguridad") {
            VStack(spacing: 0) {
                NavigationLink {
                    SettingsPlaceholderView(title: "Face ID")
                } label: {
                    settingsRow(title: "Face ID", systemImage: "faceid")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Permisos")
                } label: {
                    settingsRow(title: "Permisos", systemImage: "lock.shield")
                }
            }
        }
    }
    
    private var soporteSection: some View {
        SectionBox(title: "Soporte") {
            NavigationLink {
                SettingsPlaceholderView(title: "Correo de asistencia")
            } label: {
                settingsRow(title: "Correo de asistencia", systemImage: "envelope")
            }
        }
    }
    
    private var legalSection: some View {
        SectionBox(title: "Legal y negocio") {
            VStack(spacing: 0) {
                NavigationLink {
                    SettingsPlaceholderView(title: "Calificar esta aplicación")
                } label: {
                    settingsRow(title: "Calificar esta aplicación", systemImage: "hand.thumbsup")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Recomendar")
                } label: {
                    settingsRow(title: "Recomendar", systemImage: "square.and.arrow.up.on.square")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Administrar suscripciones")
                } label: {
                    settingsRow(title: "Administrar suscripciones", systemImage: "creditcard.and.123")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Política de privacidad")
                } label: {
                    settingsRow(title: "Política de privacidad", systemImage: "doc.text.magnifyingglass")
                }
                
                SubsectionDivider()
                
                NavigationLink {
                    SettingsPlaceholderView(title: "Condiciones de uso")
                } label: {
                    settingsRow(title: "Condiciones de uso", systemImage: "doc.text")
                }
            }
        }
    }

    // MARK: - Filas estándar de ajustes
    
    @ViewBuilder
    private func settingsRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.primary)
            
            Text(title)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    private var preferredCurrencyRow: some View {
        HStack(spacing: 12) {
            Text(currencyInfo(for: defaultCurrency).flag)
                .font(.title3)
            
            Text("Divisa preferida")
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(currencyInfo(for: defaultCurrency).name.capitalized)
                .foregroundStyle(.secondary)
            
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - Vista placeholder genérica para opciones futuras de Ajustes

struct SettingsPlaceholderView: View {
    let title: String
    let message: String
    
    init(title: String, message: String = "Próximamente") {
        self.title = title
        self.message = message
    }
    
    var body: some View {
        ZStack {
            PanelBackgroundView()
            
            VStack(spacing: 16) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.secondary)
                
                Text(title)
                    .font(.title3.weight(.semibold))
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Lista de cuentas desde Ajustes (FIN-42 - versión inicial sin reordenamiento persistente)

// MARK: - Lista de cuentas desde Ajustes (FIN-42 con diseño y orden)
// MARK: - Categorías en Ajustes (FIN-45)

/// Naturaleza de subcategoría para FIN-45
enum SubcategoryNature: String, CaseIterable, Identifiable {
    case essential = "esencial"
    case priority = "prioritaria"
    case optional = "opcional"
    case unclassified = "sin_clasificacion"
    
    var id: String { rawValue }
    
    /// Nombre visible en la UI
    var displayName: String {
        switch self {
        case .essential: return "Esencial"
        case .priority: return "Prioritaria"
        case .optional: return "Opcional"
        case .unclassified: return "Sin clasificación"
        }
    }
    
    /// Descripción corta para ayudar al usuario
    var description: String {
        switch self {
        case .essential:
            return "Gastos imprescindibles, difíciles de recortar."
        case .priority:
            return "Importantes pero con algo de flexibilidad."
        case .optional:
            return "Gastos discrecionales o de ocio."
        case .unclassified:
            return "Sin etiqueta de naturaleza específica."
        }
    }
}

/// Acceso cómodo a la naturaleza desde el modelo SwiftData
extension Subcategory {
    var nature: SubcategoryNature {
        get {
            SubcategoryNature(rawValue: natureRawValue ?? "") ?? .unclassified
        }
        set {
            natureRawValue = newValue.rawValue
        }
    }
}

/// Lista principal de categorías dentro de Ajustes → Registros
struct CategoriesSettingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name, order: .forward) private var categories: [Category]
    
    // Solo categorías padre (en Finaria v1 todas las Category son padre)
    private var orderedCategories: [Category] {
        categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var activeCategories: [Category] {
        orderedCategories.filter { $0.isVisible }
    }

    private var hiddenCategories: [Category] {
        orderedCategories.filter { !$0.isVisible }
    }

    @State private var isNavigatingToNewCategory: Bool = false
    @State private var newCategory: Category?

    private func createAndOpenNewCategory() {
        let nextSortOrder = (categories.map { $0.sortOrder }.max() ?? 0) + 1
        
        let category = Category(
            name: "",
            colorHex: "#1C3556",
            isIncome: false,
            isDefaultSeed: false,
            isVisible: true,
            sortOrder: nextSortOrder,
            subcategories: []
        )
        modelContext.insert(category)
        
        newCategory = category
        isNavigatingToNewCategory = true
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    if !activeCategories.isEmpty {
                        SectionBox(title: "Activas") {
                            VStack(spacing: 0) {
                                ForEach(Array(activeCategories.enumerated()), id: \.element.id) { index, category in
                                    NavigationLink {
                                        CategoryDetailView(category: category)
                                    } label: {
                                        categoryRow(category)
                                    }
                                    .buttonStyle(.plain)

                                    if index < activeCategories.count - 1 {
                                        SubsectionDivider()
                                    }
                                }
                            }
                        }
                    }

                    if !hiddenCategories.isEmpty {
                        SectionBox(title: "Ocultas") {
                            VStack(spacing: 0) {
                                ForEach(Array(hiddenCategories.enumerated()), id: \.element.id) { index, category in
                                    NavigationLink {
                                        CategoryDetailView(category: category)
                                    } label: {
                                        categoryRow(category)
                                    }
                                    .buttonStyle(.plain)

                                    if index < hiddenCategories.count - 1 {
                                        SubsectionDivider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createAndOpenNewCategory()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $isNavigatingToNewCategory) {
            if let newCategory {
                CategoryDetailView(category: newCategory, isNewCategory: true)
            } else {
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
            // Círculo con color e icono estándar de etiqueta
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
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14) // un poco más alta la fila
    }
}

/// Detalle de categoría: permite editar nombre, visibilidad y gestionar subcategorías
struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let category: Category
    let isNewCategory: Bool
    
    @State private var name: String
    @State private var isVisible: Bool
    @State private var showVisibilityInfo: Bool = false
    @State private var showDiscardDialog: Bool = false
    @State private var showMissingSubcategoriesAlert: Bool = false

    private let initialName: String
    private let initialIsVisible: Bool

    @Query(sort: \Subcategory.sortOrder, order: .forward) private var allSubcategories: [Subcategory]

    init(category: Category, isNewCategory: Bool = false) {
        self.category = category
        self.isNewCategory = isNewCategory
        self.initialName = category.name
        self.initialIsVisible = category.isVisible
        _name = State(initialValue: category.name)
        _isVisible = State(initialValue: category.isVisible)
    }
    
    /// Subcategorías filtradas solo para esta categoría, ordenadas por sortOrder y nombre.
    private var subcategories: [Subcategory] {
        allSubcategories
            .filter { $0.category == category }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var hasUnsavedChanges: Bool {
        let trimmedCurrentName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInitialName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCurrentName != trimmedInitialName || isVisible != initialIsVisible
    }

    private func handleBack() {
        if isNewCategory {
            if hasUnsavedChanges {
                showDiscardDialog = true
            } else {
                // Categoría nueva sin cambios: descartamos directamente
                modelContext.delete(category)
                do {
                    try modelContext.save()
                } catch {
                    print("FIN-45: Error al descartar categoría nueva sin cambios: \(error)")
                }
                dismiss()
            }
        } else {
            if hasUnsavedChanges {
                showDiscardDialog = true
            } else {
                dismiss()
            }
        }
    }
    
    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    detailsSection
                    subcategoriesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Editar categoría")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    handleBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Guardar") {
                    saveCategory()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Categoría oculta", isPresented: $showVisibilityInfo) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text("La categoría y sus subcategorías dejarán de aparecer en los selectores, pero no se perderán datos históricos.")
        }
        .alert("Añade al menos una subcategoría", isPresented: $showMissingSubcategoriesAlert) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text("Para crear una nueva categoría, debes añadir al menos una subcategoría.")
        }
        .alert("Hay cambios sin guardar", isPresented: $showDiscardDialog) {
            Button("Salir sin guardar", role: .destructive) {
                if isNewCategory {
                    modelContext.delete(category)
                    do {
                        try modelContext.save()
                    } catch {
                        print("FIN-45: Error al descartar categoría nueva: \(error)")
                    }
                }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {
                // El usuario decide seguir editando; no hacemos nada.
            }
        } message: {
            Text("Si sales ahora, se perderán los cambios realizados en esta categoría.")
        }
    }
    
    // Encabezado con círculo de color e icono
    private var header: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(colorForHex(category.colorHex))
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundStyle(.white)
                )
            
            Text(category.name)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // Sección de nombre y visibilidad
    private var detailsSection: some View {
        SectionBox(title: "Detalles") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    TextField("Nombre de la categoría", text: $name)
                        .textContentType(.name)
                }
                .padding()
                
                SubsectionDivider()
                
                Toggle(isOn: $isVisible) {
                    Text("Mostrar")
                }
                .padding()
                .onChange(of: isVisible) { _, newValue in
                    if newValue == false {
                        showVisibilityInfo = true
                    }
                }
            }
        }
    }
    
    // Sección de subcategorías
    private var subcategoriesSection: some View {
        let visibles = subcategories.filter { $0.isVisible }
        let ocultas = subcategories.filter { !$0.isVisible }
        
        return VStack(spacing: 16) {
            SectionBox(title: "Subcategorías activas") {
                VStack(spacing: 0) {
                    if visibles.isEmpty && ocultas.isEmpty {
                        Text("Esta categoría aún no tiene subcategorías.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(visibles.enumerated()), id: \.element.id) { index, subcategory in
                            NavigationLink {
                                SubcategoryDetailView(parentCategory: category, subcategoryToEdit: subcategory)
                            } label: {
                                subcategoryRow(subcategory)
                            }
                            .buttonStyle(.plain)

                            if index < visibles.count - 1 {
                                SubsectionDivider()
                            }
                        }
                    }

                    SubsectionDivider()

                    NavigationLink {
                        SubcategoryDetailView(parentCategory: category)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                            Text("Añadir subcategoría")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                    }
                }
            }
            
            if !ocultas.isEmpty {
                SectionBox(title: "Subcategorías ocultas") {
                    VStack(spacing: 0) {
                        ForEach(Array(ocultas.enumerated()), id: \.element.id) { index, subcategory in
                            NavigationLink {
                                SubcategoryDetailView(parentCategory: category, subcategoryToEdit: subcategory)
                            } label: {
                                subcategoryRow(subcategory)
                            }
                            .buttonStyle(.plain)

                            if index < ocultas.count - 1 {
                                SubsectionDivider()
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func subcategoryRow(_ subcategory: Subcategory) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorForHex(subcategory.colorHex ?? category.colorHex))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "tag")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(subcategory.name)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if isNewCategory && subcategories.isEmpty {
            showMissingSubcategoriesAlert = true
            return
        }
        
        category.name = trimmedName
        category.isVisible = isVisible
        
        do {
            try modelContext.save()
        } catch {
            print("FIN-45: Error al guardar categoría: \(error)")
        }
        
        dismiss()
    }
}

/// Formulario de creación/edición de subcategoría
struct SubcategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let parentCategory: Category
    let subcategoryToEdit: Subcategory?
    
    private var isEditing: Bool { subcategoryToEdit != nil }
    
    @State private var name: String
    @State private var selectedNature: SubcategoryNature
    @State private var isVisible: Bool
    @State private var selectedColorHex: String
    
    @State private var isPresentingNatureSelector: Bool = false
    
    @State private var showDiscardDialog: Bool = false

    private let initialName: String
    private let initialNature: SubcategoryNature
    private let initialIsVisible: Bool
    private let initialColorHex: String

    init(parentCategory: Category, subcategoryToEdit: Subcategory? = nil) {
        self.parentCategory = parentCategory
        self.subcategoryToEdit = subcategoryToEdit

        if let sub = subcategoryToEdit {
            self.initialName = sub.name
            self.initialNature = sub.nature
            self.initialIsVisible = sub.isVisible
            self.initialColorHex = sub.colorHex ?? parentCategory.colorHex
            _name = State(initialValue: sub.name)
            _selectedNature = State(initialValue: sub.nature)
            _isVisible = State(initialValue: sub.isVisible)
            _selectedColorHex = State(initialValue: sub.colorHex ?? parentCategory.colorHex)
        } else {
            self.initialName = ""
            self.initialNature = .unclassified
            self.initialIsVisible = true
            self.initialColorHex = parentCategory.colorHex
            _name = State(initialValue: "")
            _selectedNature = State(initialValue: .unclassified)
            _isVisible = State(initialValue: true)
            _selectedColorHex = State(initialValue: parentCategory.colorHex)
        }
    }

    private var hasUnsavedChanges: Bool {
        let trimmedCurrentName = trimmedName
        let trimmedInitialName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCurrentName != trimmedInitialName ||
            selectedNature != initialNature ||
            isVisible != initialIsVisible ||
            selectedColorHex != initialColorHex
    }

    private func handleBack() {
        if hasUnsavedChanges {
            showDiscardDialog = true
        } else {
            dismiss()
        }
    }
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canSave: Bool {
        !trimmedName.isEmpty
    }
    
    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    detailsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(isEditing ? "Editar subcategoría" : "Nueva subcategoría")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    handleBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Guardar") {
                    saveSubcategory()
                }
                .disabled(!canSave)
            }
        }
        .sheet(isPresented: $isPresentingNatureSelector) {
            NavigationStack {
                SubcategoryNatureSelectorView(selectedNature: $selectedNature)
            }
        }
        .confirmationDialog(
            "Hay cambios sin guardar",
            isPresented: $showDiscardDialog,
            titleVisibility: .visible
        ) {
            Button("Salir sin guardar", role: .destructive) {
                dismiss()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Si sales ahora, se perderán los cambios realizados en esta subcategoría.")
        }
    }
    
    // Encabezado con círculo de color e icono
    private var header: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(colorForHex(selectedColorHex))
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundStyle(.white)
                )
            
            Text(parentCategory.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // Sección de nombre, naturaleza y visibilidad
    private var detailsSection: some View {
        SectionBox(title: "Detalles de la subcategoría") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    TextField("Nombre de la subcategoría", text: $name)
                        .textContentType(.name)
                }
                .padding()
                
                SubsectionDivider()
                
                Button {
                    isPresentingNatureSelector = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Naturaleza")
                                .foregroundStyle(.primary)
                            Text(selectedNature.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)
                
                SubsectionDivider()
                
                Toggle(isOn: $isVisible) {
                    Text("Mostrar")
                }
                .padding()
            }
        }
    }
    
    private func saveSubcategory() {
        let finalName = trimmedName
        guard !finalName.isEmpty else { return }
        
        if let sub = subcategoryToEdit {
            // Edición
            sub.name = finalName
            sub.isVisible = isVisible
            sub.nature = selectedNature
            sub.colorHex = selectedColorHex
        } else {
            // Creación
            let sortOrder: Int
            do {
                let descriptor = FetchDescriptor<Subcategory>()
                let allSubcategories = try modelContext.fetch(descriptor)
                let existing = allSubcategories.filter { $0.category == parentCategory }
                let maxOrder = existing.map { $0.sortOrder }.max() ?? -1
                sortOrder = maxOrder + 1
            } catch {
                print("FIN-45: Error calculando sortOrder de subcategorías: \(error)")
                sortOrder = 0
            }
            
            let newSubcategory = Subcategory(
                name: finalName,
                colorHex: selectedColorHex,
                isDefaultSeed: false,
                isVisible: isVisible,
                sortOrder: sortOrder,
                natureRawValue: selectedNature.rawValue,
                category: parentCategory
            )
            
            modelContext.insert(newSubcategory)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("FIN-45: Error al guardar subcategoría: \(error)")
        }
        
        dismiss()
    }
}

/// Selector de naturaleza de subcategoría (Esencial, Prioritaria, Opcional, Sin clasificación)
struct SubcategoryNatureSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedNature: SubcategoryNature
    
    var body: some View {
        List {
            ForEach(SubcategoryNature.allCases) { nature in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(nature.displayName)
                        Spacer()
                        if nature == selectedNature {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    Text(nature.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedNature = nature
                    dismiss()
                }
            }
        }
        .navigationTitle("Naturaleza")
    }
}

struct AccountsSettingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""
    
    @State private var isPresentingCreateAccount = false
    @State private var accountToEdit: Account?
    
    // Solo cuentas no archivadas para esta vista
    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }
    
    // Orden persistente por nombre
    private var accountsSortOrderNames: [String] {
        accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
    }
    
    private var orderedActiveAccounts: [Account] {
        let order = accountsSortOrderNames
        let indexByName = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        
        return activeAccounts.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]
            
            switch (ia, ib) {
            case let (x?, y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name < b.name
            }
        }
    }
    
    // Cuentas archivadas (sin reordenamiento)
    private var archivedAccounts: [Account] {
        accounts.filter { $0.isArchived }
    }
    
    var body: some View {
        ZStack {
            PanelBackgroundView()
            
            ScrollView {
                VStack(spacing: 24) {
                    if !orderedActiveAccounts.isEmpty {
                        accountsSection(title: "Activas", accounts: orderedActiveAccounts)
                    }
                    
                    if !archivedAccounts.isEmpty {
                        accountsSection(title: "Archivadas", accounts: archivedAccounts)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Cuentas")
        .navigationBarTitleDisplayMode(.inline)    // título reducido y centrado
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingCreateAccount = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // Alta de nueva cuenta desde Ajustes (reutiliza el formulario existente)
        .sheet(isPresented: $isPresentingCreateAccount) {
            AccountFormView(
                existingNames: accounts.map { $0.name }
            )
        }
        // Edición de cuenta existente reutilizando el mismo formulario
        .sheet(item: $accountToEdit) { account in
            AccountFormView(
                existingNames: accounts.map { $0.name }.filter { $0 != account.name },
                accountToEdit: account
            )
        }
    }
    // Caja blanca de sección (similar a Suscripciones de Apple)
    @ViewBuilder
    private func accountsSection(title: String, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6)) // gris un poco más fuerte
                .padding(.leading, 6)
            
            VStack(spacing: 0) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    Button {
                        accountToEdit = account
                    } label: {
                        accountRow(account)
                    }
                    .buttonStyle(.plain)
                    
                    if index < accounts.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }
    
    // MARK: - Presentación de filas
    
    private func accountTypeText(for account: Account) -> String {
        account.type.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    private func formattedBalance(for account: Account) -> String {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let info = currencyInfo(for: currency)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let formattedAmount = formatter.string(from: NSNumber(value: account.initialBalance)) ?? "0.00"
        return "\(info.code) \(formattedAmount)"
    }
    
    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let currencyInfoTuple = currencyInfo(for: currency)
        
        // Línea principal: número de cuenta si existe, si no el nombre
        let primaryText = (account.accountNumber?.isEmpty == false) ? account.accountNumber! : account.name
        
        HStack(spacing: 12) {
            // Ícono de la cuenta con color de fondo según configuración
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorForHex(account.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .foregroundStyle(.white)
                )
            
            // Texto central (3 líneas)
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(accountTypeText(for: account))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(currencyInfoTuple.name.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Monto + chevron a la derecha
            HStack(spacing: 4) {
                Text(formattedBalance(for: account))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
}

// MARK: - Placeholders Planificación y Estadísticas

struct PlanningView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                Text("Planificación")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Planificación")
        }
    }
}

struct StatisticsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                Text("Estadísticas")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Estadísticas")
        }
    }
}

// MARK: - Fondo general tipo Liquid Glass claro

struct PanelBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.financeBackgroundTop,
                Color.financeBackgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Tarjeta de cuenta

struct AccountCardView: View {
    
    let account: Account
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: iconForAccount)
                .font(.title2)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.05))
                )
                .foregroundStyle(.primary)
            
            Text(account.name.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("\(normalizeCurrencyCode(account.currencyCode)) \(formattedAmount(account.initialBalance))")
                .font(.title3.weight(.bold))
        }
        .padding(16)
        .frame(width: 200, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
    }
    
    private var iconForAccount: String {
        displayIconName(for: account)
    }
    
    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

// MARK: - Tarjeta para agregar cuenta

struct AddAccountCardView: View {
    
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text("Agregar cuenta")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 200, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Formulario "Configurar cuenta"

struct AccountFormView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let existingNames: [String]
    let accountToEdit: Account?
    
    private var isEditing: Bool {
        accountToEdit != nil
    }
    
    // General
    @State private var name: String
    @State private var selectedType: AccountType
    @State private var accountNumber: String
    
    // Saldo actual
    @State private var isPositive: Bool
    @State private var balanceText: String
    
    // Moneda
    @State private var selectedCurrency: CurrencyCode
    
    // Ajuste
    @State private var selectedAdjustmentMode: AdjustmentMode
    
    // Color
    @State private var selectedColorHex: String
    @State private var customColor: Color
    @State private var isPresentingColorPicker: Bool
    
    // Acciones
    @State private var excludeFromStatistics: Bool
    @State private var isArchived: Bool
    
    // Navegación interna (reservado para futuros flows)
    @State private var showTypeSelector: Bool
    @State private var showCurrencySelector: Bool
    @State private var showAdjustmentSelector: Bool
    
    // Alertas de eliminación
    @State private var isShowingDeleteError: Bool = false
    @State private var deleteErrorMessage: String = ""
    
    init(existingNames: [String], accountToEdit: Account? = nil) {
        self.existingNames = existingNames
        self.accountToEdit = accountToEdit
        
        if let account = accountToEdit {
            _name = State(initialValue: account.name)
            _selectedType = State(initialValue: AccountType(rawValue: account.type) ?? .general)
            _accountNumber = State(initialValue: account.accountNumber ?? "")
            
            let balance = account.initialBalance
            _isPositive = State(initialValue: balance >= 0)
            _balanceText = State(initialValue: String(format: "%.2f", abs(balance)))
            
            _selectedCurrency = State(initialValue: CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode)) ?? .pen)
            _selectedAdjustmentMode = State(initialValue: AdjustmentMode(rawValue: account.adjustmentMode) ?? .byEntry)
            
            _selectedColorHex = State(initialValue: account.colorHex)
            _customColor = State(initialValue: colorForHex(account.colorHex))
            
            _excludeFromStatistics = State(initialValue: account.excludeFromStatistics)
            _isArchived = State(initialValue: account.isArchived)
        } else {
            _name = State(initialValue: "")
            _selectedType = State(initialValue: .general)
            _accountNumber = State(initialValue: "")
            
            _isPositive = State(initialValue: true)
            _balanceText = State(initialValue: "")
            
            _selectedCurrency = State(initialValue: .pen)
            _selectedAdjustmentMode = State(initialValue: .byEntry)
            
            _selectedColorHex = State(initialValue: "#1C3556")
            _customColor = State(initialValue: Color(red: 0.11, green: 0.21, blue: 0.34))
            
            _excludeFromStatistics = State(initialValue: false)
            _isArchived = State(initialValue: false)
        }
        
        _isPresentingColorPicker = State(initialValue: false)
        _showTypeSelector = State(initialValue: false)
        _showCurrencySelector = State(initialValue: false)
        _showAdjustmentSelector = State(initialValue: false)
    }
    
    // MARK: Validaciones
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isNameValid: Bool {
        !trimmedName.isEmpty
    }
    
    private var isNameUnique: Bool {
        let lower = trimmedName.lowercased()
        return !existingNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .contains(lower)
    }
    
    private var isCurrencyValid: Bool {
        CurrencyCode.allCases.contains(where: { $0.rawValue == selectedCurrency.rawValue })
    }
    
    private var parsedAmount: Double? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Campo vacío: lo interpretamos como 0, para permitir cuentas sin saldo inicial.
        if trimmed.isEmpty {
            return 0
        }
        
        guard let decimal = parseDecimal(from: trimmed) else {
            return nil
        }
        
        return (decimal as NSDecimalNumber).doubleValue
    }
    
    private var isAmountValid: Bool {
        parsedAmount != nil
    }
    
    private var canSave: Bool {
        isNameValid && isNameUnique && isCurrencyValid && isAmountValid
    }
    
    // MARK: Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                
                ScrollView {
                    VStack(spacing: 24) {
                        generalSection
                        currencySection
                        balanceSection
                        adjustmentSection
                        colorSection
                        actionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Configurar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        saveAccount()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isPresentingColorPicker) {
                NavigationStack {
                    VStack(spacing: 24) {
                        ColorPicker("Selecciona un color",
                                    selection: $customColor,
                                    supportsOpacity: false)
                            .padding()
                        
                        Button("Usar este color") {
                            selectedColorHex = hexString(from: customColor)
                            isPresentingColorPicker = false
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Nuevo color")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .alert(
            "No se puede eliminar esta cuenta",
            isPresented: $isShowingDeleteError,
            actions: {
                Button("Entendido", role: .cancel) { }
            },
            message: {
                Text(deleteErrorMessage)
            }
        )
    }
    
    // MARK: Secciones de la vista
    
    private var generalSection: some View {
        SectionBox(title: "General") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    TextField("Nombre de la cuenta", text: $name)
                        .textContentType(.name)
                }
                .padding()
                
                SubsectionDivider()
                
                NavigationLink {
                    AccountTypeSelectorView(selectedType: $selectedType)
                } label: {
                    HStack {
                        Text("Tipo")
                        Spacer()
                        Text(selectedType.rawValue)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                
                SubsectionDivider()
                
                HStack(spacing: 12) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                    TextField("Número de cuenta", text: $accountNumber)
                        .keyboardType(.numbersAndPunctuation)
                }
                .padding()
            }
        }
    }
    
    private var currencySection: some View {
        SectionBox(title: "Moneda") {
            NavigationLink {
                CurrencySelectorView(selectedCurrency: $selectedCurrency)
            } label: {
                HStack(spacing: 12) {
                    Text(currencyInfo(for: selectedCurrency).flag)
                        .font(.title3)
                    
                    Text("Moneda")
                        .font(.body)
                    
                    Spacer()
                    
                    Text(currencyInfo(for: selectedCurrency).name.capitalized)
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
        }
    }
    
    private var balanceSection: some View {
        SectionBox(title: "Saldo actual") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Signo")
                        .font(.subheadline)
                    Spacer()
                    Picker("Signo", selection: $isPositive) {
                        Text("Positivo").tag(true)
                        Text("Negativo").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                
                SubsectionDivider()
                
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(currencyInfo(for: selectedCurrency).code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 28, weight: .bold))
                    }
                }
                .padding()
            }
        }
    }
    
    private var adjustmentSection: some View {
        SectionBox(title: "Ajuste") {
            VStack(spacing: 0) {
                NavigationLink {
                    AdjustmentModeSelectorView(selectedAdjustmentMode: $selectedAdjustmentMode)
                } label: {
                    HStack {
                        Text("Ajuste")
                        Spacer()
                        Text(selectedAdjustmentMode.rawValue)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                
                SubsectionDivider()
                
                Text(selectedAdjustmentMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var colorSection: some View {
        SectionBox(title: "Color") {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(colorForHex(hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColorHex == hex ? 3 : 1)
                                )
                                .shadow(radius: selectedColorHex == hex ? 4 : 0)
                                .onTapGesture {
                                    selectedColorHex = hex
                                }
                        }
                        
                        Button {
                            isPresentingColorPicker = true
                        } label: {
                            Circle()
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("Seleccionado: \(selectedColorHex)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }
    
    private var actionsSection: some View {
        SectionBox(title: "Acciones") {
            VStack(spacing: 0) {
                Toggle(isOn: $excludeFromStatistics) {
                    Text("Excluir de las estadísticas")
                }
                .padding()
                
                SubsectionDivider()
                
                Toggle(isOn: $isArchived) {
                    Text("Archivar cuenta")
                }
                .padding()
                
                if isEditing {
                    SubsectionDivider()
                    
                    Button(role: .destructive) {
                        handleDeleteTapped()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Eliminar cuenta")
                            Spacer()
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: Utilidades de color
    
    private var colorOptions: [String] {
        ["#FF9F0A", "#30D158", "#FF375F", "#0A84FF", "#5E5CE6", "#FFD60A", "#1C3556"]
    }
    
    private func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let r = Int(red * 255)
            let g = Int(green * 255)
            let b = Int(blue * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return selectedColorHex
        }
    }
    
    // MARK: Guardado
    
    private func saveAccount() {
        guard canSave, let amount = parsedAmount else { return }
        
        let finalAmount = isPositive ? amount : -amount
        let trimmedAccountNumber = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let account = accountToEdit {
            // Edición de cuenta existente
            account.name = trimmedName
            account.currencyCode = normalizeCurrencyCode(selectedCurrency.rawValue)
            account.colorHex = selectedColorHex
            account.iconName = iconName(for: selectedType)
            account.type = selectedType.rawValue
            account.accountNumber = trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber
            account.initialBalance = finalAmount
            account.adjustmentMode = selectedAdjustmentMode.rawValue
            account.excludeFromStatistics = excludeFromStatistics
            account.isArchived = isArchived
        } else {
            // Creación de nueva cuenta
            let newAccount = Account(
                name: trimmedName,
                currencyCode: normalizeCurrencyCode(selectedCurrency.rawValue),
                colorHex: selectedColorHex,
                iconName: iconName(for: selectedType),
                type: selectedType.rawValue,
                accountNumber: trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber,
                initialBalance: finalAmount,
                adjustmentMode: selectedAdjustmentMode.rawValue,
                excludeFromStatistics: excludeFromStatistics,
                isArchived: isArchived
            )
            
            modelContext.insert(newAccount)
        }
        
        dismiss()
    }

    // MARK: - Eliminación de cuenta
    
    private func handleDeleteTapped() {
        guard let account = accountToEdit else { return }
        
        // Regla mínima: no permitir eliminar cuentas con saldo distinto de 0.
        // Más adelante, cuando exista el modelo de transacciones, se deberá
        // ampliar esta validación para comprobar también que no tenga movimientos.
        if account.initialBalance != 0 {
            deleteErrorMessage = "No puedes eliminar esta cuenta porque tiene saldo distinto de cero. Ajusta el saldo a 0 antes de eliminarla."
            isShowingDeleteError = true
            return
        }
        
        modelContext.delete(account)
        dismiss()
    }
}

// MARK: - Selectores de Tipo, Moneda y Ajuste

struct AccountTypeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: AccountType
    
    var body: some View {
        List {
            ForEach(AccountType.allCases) { type in
                HStack {
                    Text(type.rawValue)
                    Spacer()
                    if type == selectedType {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedType = type
                    dismiss()
                }
            }
        }
        .navigationTitle("Tipo de cuenta")
    }
}

struct CurrencySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrency: CurrencyCode
    
    var body: some View {
        List {
            ForEach(CurrencyCode.allCases) { currency in
                HStack(spacing: 12) {
                    let info = currencyInfo(for: currency)
                    
                    Text(info.flag)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.name)
                        Text(info.code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if currency == selectedCurrency {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCurrency = currency
                    dismiss()
                }
            }
        }
        .navigationTitle("Moneda")
    }
}

struct AdjustmentModeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAdjustmentMode: AdjustmentMode
    
    var body: some View {
        List {
            ForEach(AdjustmentMode.allCases) { mode in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                            .font(.body)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if mode == selectedAdjustmentMode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedAdjustmentMode = mode
                    dismiss()
                }
            }
        }
        .navigationTitle("Ajuste")
    }
}

// MARK: - Divider estándar entre subsecciones

struct SubsectionDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 20)
    }
}

// MARK: - Contenedor visual de secciones (Liquid Glass)

struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Paleta Finaria (Liquid Glass claro)

extension Color {
    static let financeGreen = Color(red: 0.13, green: 0.75, blue: 0.45)
    static let financeBlue  = Color(red: 0.17, green: 0.47, blue: 0.96)
    static let financeOrange = Color(red: 1.00, green: 0.58, blue: 0.30)
    
    static let financeBackgroundTop = Color(red: 0.99, green: 0.99, blue: 1.00)
    static let financeBackgroundBottom = Color(red: 0.93, green: 0.95, blue: 0.99)
}
