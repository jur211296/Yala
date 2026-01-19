//
//  ImportIntroSheet.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Import Result Model

/// Result of an import operation - used to present result sheet
struct ImportResult: Identifiable {
    let id = UUID()
    let isSuccess: Bool
    let message: String
    let count: Int
}

// MARK: - Import Result Overlay

/// Overlay view for showing import results - displayed on top of content in ZStack
/// This approach avoids the nested sheet presentation bug in SwiftUI
struct ImportResultOverlay: View {
    let result: ImportResult
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Full screen background
            Color.black.opacity(DS.Opacity.glass)
                .ignoresSafeArea()

            // Content card
            VStack(spacing: DS.Spacing.lg) {
                Spacer()

                // Icon
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(result.isSuccess ? Color.financeGreen : Color.red)

                // Title
                Text(result.isSuccess ? L10n.Import.completed : L10n.Import.importError)
                    .font(Typography.title2)
                    .foregroundStyle(Color.netoPrimaryText)

                // Message
                Text(result.message)
                    .font(Typography.body)
                    .foregroundStyle(Color.netoSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xxxl)

                Spacer()

                // Button
                Button {
                    onDismiss()
                } label: {
                    Text(L10n.Import.continueBtn)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(result.isSuccess ? Color.financeGreen : Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.netoCard)
        }
    }
}

// MARK: - Flujo de importación de archivo (FIN-24)

/// Hoja principal de introducción y configuración de importación
struct ImportIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // Data passed from parent view (no @Query = no view reconstruction on save)
    let accounts: [Account]
    let categories: [Category]

    @State private var allowCreatingNewCategories: Bool = false
    @State private var isShowingAccountPicker: Bool = false
    @State private var isShowingFileImporter: Bool = false
    @State private var selectedAccount: Account?
    @State private var templateFile: TemplateFile?

    // Import state - simple booleans and result
    @State private var isImporting: Bool = false

    // Template alert (separate from import flow)
    @State private var showTemplateAlert: Bool = false

    // Multi-currency import state
    @State private var selectedFileURL: URL?
    @State private var detectedCurrencies: Set<String> = []
    @State private var isShowingCurrencyMapping: Bool = false
    @State private var filteredCurrencyForAccountPicker: String?

    /// Callback to notify parent with import result. Parent handles display.
    let onImportCompleted: ((ImportResult) -> Void)?

    init(
        accounts: [Account],
        categories: [Category],
        onImportCompleted: ((ImportResult) -> Void)? = nil
    ) {
        self.accounts = accounts
        self.categories = categories
        self.onImportCompleted = onImportCompleted
    }

    private var activeAccounts: [Account] {
        accounts
            .filter { !$0.isArchived }
            .sorted(by: { $0.name < $1.name })
    }

    /// Accounts filtered by a specific currency (for single-currency import)
    private func accountsForCurrency(_ currencyCode: String) -> [Account] {
        activeAccounts.filter { normalizeCurrencyCode($0.currencyCode) == currencyCode }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: DS.Spacing.lg) {
                    ScrollView {
                        VStack(spacing: DS.Spacing.xxl) {
                            introSection
                            templateSection
                            toggleSection
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.lg)
                    }

                    // Bottom Action Button
                    VStack {
                        Button {
                            startImportFlow()
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                if isImporting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                    Text(L10n.Import.importing)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                    Text(L10n.Import.selectFile)
                                }
                            }
                            .font(Typography.bodyLarge)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .disabled(isImporting)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
            .navigationTitle("Importar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .disabled(isImporting)
        // Sheets & Alerts
        .sheet(isPresented: $isShowingAccountPicker) {
            ImportAccountPickerSheet(
                accounts: filteredCurrencyForAccountPicker != nil
                    ? accountsForCurrency(filteredCurrencyForAccountPicker!)
                    : activeAccounts,
                selectedAccount: $selectedAccount
            ) { account in
                selectedAccount = account
                isShowingAccountPicker = false
                // Import directly since file was already selected
                if let url = selectedFileURL {
                    performImport(from: url, into: account)
                }
            }
        }
        .sheet(isPresented: $isShowingCurrencyMapping) {
            ImportCurrencyMappingSheet(
                detectedCurrencies: detectedCurrencies,
                accounts: activeAccounts
            ) { currencyAccountMap in
                isShowingCurrencyMapping = false
                if let url = selectedFileURL {
                    performMultiCurrencyImport(from: url, with: currencyAccountMap)
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImportResult(result)
        }
        .sheet(
            item: $templateFile,
            onDismiss: {
                templateFile = nil
            }
        ) { file in
            ActivityView(activityItems: [file.url]) { completed in
                if completed {
                    showTemplateAlert = true
                }
            }
        }
        .alert(L10n.Import.templateGenerated, isPresented: $showTemplateAlert) {
            Button(L10n.Import.continueBtn, role: .cancel) {}
        } message: {
            Text(L10n.Import.templateGeneratedMessage)
        }
    }

    // MARK: - Secciones de contenido

    private var introSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandPrimary)
                .padding(.bottom, DS.Spacing.sm)

            Text(L10n.Import.title)
                .font(Typography.title2)
                .foregroundStyle(Color.netoPrimaryText)

            Text(L10n.Import.introDescription)
            .font(Typography.body)
            .foregroundStyle(Color.netoSecondaryText)
            .multilineTextAlignment(.center)
        }
        .padding(.top, DS.Spacing.xxxl)
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Button {
                generateTemplate()
            } label: {
                HStack {
                    Text(L10n.Import.downloadTemplate)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(Color.netoPrimaryText)

                    Spacer()

                    Image(systemName: "arrow.down.circle")
                        .font(.body)
                        .foregroundStyle(Color.brandPrimary)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.FormRow.paddingV)
                .background(Color.netoCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Text(L10n.Import.templateDescription)
            .font(Typography.label)
            .foregroundStyle(Color.netoSecondaryText)
            .padding(.horizontal, 4)
        }
    }

    private var toggleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {

            // Toggle Container
            HStack {
                Text(L10n.Import.createCategories)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Color.netoPrimaryText)

                Spacer()

                Toggle("", isOn: $allowCreatingNewCategories)
                    .labelsHidden()
                    .tint(Color.brandPrimary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(Color.netoCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )

            Text(L10n.Import.categoriesDescription)
            .font(Typography.label)
            .foregroundStyle(Color.netoSecondaryText)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Actions

    private func startImportFlow() {
        if activeAccounts.isEmpty {
            // No hay cuentas activas - dismiss and notify parent
            let result = ImportResult(
                isSuccess: false,
                message: L10n.Import.createAccountFirst,
                count: 0
            )
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.onImportCompleted?(result)
            }
        } else {
            // Open file picker first - currencies will be detected after file selection
            isShowingFileImporter = true
        }
    }

    private func generateTemplate() {
        var rows = [[String]]()
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Encabezado según documentación FIN-28
        rows.append([
            "Fecha", "Monto", "Tipo", "Categoría", "Subcategoría", "Nota",
        ])

        // Fila de ejemplo con una categoría del catálogo (si existe)
        let sampleCategoryName = categories.first?.name ?? "Alimentación"
        let sampleSubcategoryName: String = {
            if let cat = categories.first,
                let sub = cat.subcategories.first
            {
                return sub.name
            }
            return "Supermercado"
        }()

        rows.append([
            formatter.string(from: now),
            "-45.50",
            "egreso",
            sampleCategoryName,
            sampleSubcategoryName,
            "Compra semanal",
        ])

        rows.append([
            formatter.string(from: now),
            "1500.00",
            "ingreso",
            categories.first(where: { $0.name.lowercased().contains("ingreso") })?.name
                ?? "Salario",
            "",
            "Pago mensual",
        ])

        let csvText = rows.map { row in
            row.map { field in
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }.joined(separator: ",")
        }.joined(separator: "\n")

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("plantilla_neto.csv")

        do {
            try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
            templateFile = TemplateFile(url: tempURL)
        } catch {
            // Template generation error - just show alert, don't dismiss
            showTemplateAlert = false  // Error handled separately
        }
    }

    // MARK: - Import Handling

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            let errorResult = ImportResult(
                isSuccess: false,
                message: error.localizedDescription,
                count: 0
            )
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.onImportCompleted?(errorResult)
            }
        case .success(let urls):
            guard let url = urls.first else {
                let errorResult = ImportResult(
                    isSuccess: false,
                    message: L10n.Import.fileUrlError,
                    count: 0
                )
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.onImportCompleted?(errorResult)
                }
                return
            }

            // Scan currencies from CSV
            do {
                let currencies = try TransactionCSVImportService.scanCurrencies(from: url)
                selectedFileURL = url
                detectedCurrencies = currencies

                if currencies.count == 1, let singleCurrency = currencies.first {
                    // Single currency - route to account picker or direct import
                    let matchingAccounts = accountsForCurrency(singleCurrency)

                    if matchingAccounts.isEmpty {
                        // No accounts for this currency
                        let errorResult = ImportResult(
                            isSuccess: false,
                            message: L10n.Import.noAccountsForCurrency(singleCurrency),
                            count: 0
                        )
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.onImportCompleted?(errorResult)
                        }
                    } else if matchingAccounts.count == 1 {
                        // Only one account matches - import directly
                        selectedAccount = matchingAccounts.first
                        performImport(from: url, into: matchingAccounts.first!)
                    } else {
                        // Multiple accounts - show picker filtered by currency
                        filteredCurrencyForAccountPicker = singleCurrency
                        isShowingAccountPicker = true
                    }
                } else if currencies.count > 1 {
                    // Multiple currencies - show currency mapping sheet
                    isShowingCurrencyMapping = true
                } else {
                    // No currencies found (empty file or invalid)
                    let errorResult = ImportResult(
                        isSuccess: false,
                        message: L10n.Import.noCurrenciesDetected,
                        count: 0
                    )
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onImportCompleted?(errorResult)
                    }
                }
            } catch {
                let errorResult = ImportResult(
                    isSuccess: false,
                    message: error.localizedDescription,
                    count: 0
                )
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.onImportCompleted?(errorResult)
                }
            }
        }
    }
    private func performImport(from url: URL, into account: Account) {
        print("🔵 [IMPORT] Starting import, setting isImporting = true")
        isImporting = true
        print("🔵 [IMPORT] isImporting is now: \(isImporting)")

        // Small delay to allow SwiftUI to render the button change before heavy work starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task { @MainActor in
                do {
                    print("🔵 [IMPORT] Calling TransactionCSVImportService.importCSV")
                    let result = try await TransactionCSVImportService.importCSV(
                        from: url,
                        into: account,
                        in: modelContext,
                        allowCreatingNewCategories: allowCreatingNewCategories
                    )

                    let createdCount = result.createdCount
                    print("🔵 [IMPORT] Import complete, count = \(createdCount)")

                    // Save to persist transactions
                    try modelContext.save()
                    print("🔵 [IMPORT] Save complete")

                    // Calculate date range of imported transactions for exchange rate fetch
                    let importedDates = result.drafts.map { $0.date }
                    let dateRange: DateInterval? = {
                        guard let minDate = importedDates.min(),
                              let maxDate = importedDates.max() else { return nil }
                        return DateInterval(start: minDate, end: maxDate)
                    }()

                    // Fire background task to fetch exchange rates for imported date range
                    // This runs after the main import is complete to avoid @Query issues
                    if let dateRange = dateRange {
                        Task.detached { @MainActor in
                            print("🔵 [IMPORT] Fetching exchange rates for date range: \(dateRange)")
                            await ExchangeRateService.shared.ensureRates(for: dateRange, context: modelContext)
                            // Update any transactions with provisional rates
                            await TransactionUpdateService.updateProvisionalTransactions(context: modelContext)
                            // Trigger widget refresh so Panel recalculates with new data
                            SessionState.shared.needsExchangeRateWidgetRefresh = true
                            print("🔵 [IMPORT] Exchange rate fetch complete")
                        }
                    }

                    // Create result and dismiss (keep button in "Importando" state until sheet closes)
                    let importResult = ImportResult(
                        isSuccess: true,
                        message: "\(createdCount) registros importados correctamente.",
                        count: createdCount
                    )
                    print("🔵 [IMPORT] Dismissing sheet and notifying parent")

                    // Dismiss sheet first, then notify parent
                    dismiss()

                    // Notify parent with result after small delay for sheet to close
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onImportCompleted?(importResult)
                    }

                } catch {
                    print("🔴 [IMPORT] ERROR: \(error.localizedDescription)")
                    isImporting = false
                    let errorResult = ImportResult(
                        isSuccess: false,
                        message: error.localizedDescription,
                        count: 0
                    )
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onImportCompleted?(errorResult)
                    }
                }
            }
        }  // End DispatchQueue.asyncAfter
    }

    // MARK: - Multi-Currency Import

    private func performMultiCurrencyImport(from url: URL, with currencyAccountMap: [String: Account]) {
        print("🔵 [IMPORT-MULTI] Starting multi-currency import, setting isImporting = true")
        isImporting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task { @MainActor in
                do {
                    print("🔵 [IMPORT-MULTI] Calling TransactionCSVImportService.importCSVMultiCurrency")
                    let result = try await TransactionCSVImportService.importCSVMultiCurrency(
                        from: url,
                        currencyAccountMap: currencyAccountMap,
                        in: modelContext,
                        allowCreatingNewCategories: allowCreatingNewCategories
                    )

                    let createdCount = result.createdCount
                    let currencyCount = currencyAccountMap.count
                    print("🔵 [IMPORT-MULTI] Import complete, count = \(createdCount) in \(currencyCount) currencies")

                    // Save to persist transactions
                    try modelContext.save()
                    print("🔵 [IMPORT-MULTI] Save complete")

                    // Calculate date range for exchange rate fetch
                    let importedDates = result.drafts.map { $0.date }
                    let dateRange: DateInterval? = {
                        guard let minDate = importedDates.min(),
                              let maxDate = importedDates.max() else { return nil }
                        return DateInterval(start: minDate, end: maxDate)
                    }()

                    // Fire background task to fetch exchange rates
                    if let dateRange = dateRange {
                        Task.detached { @MainActor in
                            print("🔵 [IMPORT-MULTI] Fetching exchange rates for date range: \(dateRange)")
                            await ExchangeRateService.shared.ensureRates(for: dateRange, context: modelContext)
                            await TransactionUpdateService.updateProvisionalTransactions(context: modelContext)
                            SessionState.shared.needsExchangeRateWidgetRefresh = true
                            print("🔵 [IMPORT-MULTI] Exchange rate fetch complete")
                        }
                    }

                    // Create result with multi-currency message
                    let importResult = ImportResult(
                        isSuccess: true,
                        message: L10n.Import.recordsImportedMultiCurrency(createdCount, currencyCount),
                        count: createdCount
                    )
                    print("🔵 [IMPORT-MULTI] Dismissing sheet and notifying parent")

                    dismiss()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onImportCompleted?(importResult)
                    }

                } catch {
                    print("🔴 [IMPORT-MULTI] ERROR: \(error.localizedDescription)")
                    isImporting = false
                    let errorResult = ImportResult(
                        isSuccess: false,
                        message: error.localizedDescription,
                        count: 0
                    )
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onImportCompleted?(errorResult)
                    }
                }
            }
        }
    }
}

struct TemplateFile: Identifiable {
    let id = UUID()
    let url: URL
}
