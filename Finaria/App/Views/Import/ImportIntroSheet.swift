//
//  ImportIntroSheet.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Flujo de importación de archivo (FIN-24)

/// Hoja principal de introducción y configuración de importación
struct ImportIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]

    @State private var allowCreatingNewCategories: Bool = false
    @State private var isShowingAccountPicker: Bool = false
    @State private var isShowingFileImporter: Bool = false
    @State private var selectedAccount: Account?
    @State private var isImporting: Bool = false
    @State private var templateFile: TemplateFile?

    @State private var alertTitle: String = ""
    @State private var alertMessage: String?
    @State private var isShowingAlert: Bool = false
    @State private var shouldDismissAfterAlert: Bool = false

    /// Callback opcional para notificar al presentador que la importación
    /// se completó correctamente. En Ajustes se usa para volver al Panel.
    let onImportCompleted: (() -> Void)?

    init(onImportCompleted: (() -> Void)? = nil) {
        self.onImportCompleted = onImportCompleted
    }

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: 24) {
                    ScrollView {
                        VStack(spacing: 24) {
                            introSection
                            templateSection
                            toggleSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    }

                    VStack(spacing: 12) {
                        if isImporting {
                            ProgressView("Importando...")
                                .progressViewStyle(.circular)
                                .padding(.vertical, 4)
                        }

                        Button {
                            startAccountSelection()
                        } label: {
                            Text("Importar archivo CSV")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isImporting)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Importar")
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
        .sheet(isPresented: $isShowingAccountPicker) {
            ImportAccountPickerSheet(
                accounts: activeAccounts,
                selectedAccount: $selectedAccount
            ) { account in
                selectedAccount = account
                isShowingAccountPicker = false
                isShowingFileImporter = true
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
                // Solo mostramos la confirmación si el usuario completó
                // alguna acción de guardado/compartido en el share sheet.
                if completed {
                    alertTitle = "Plantilla generada"
                    alertMessage =
                        "La plantilla CSV se generó correctamente. Ahora puedes editarla y volver a esta pantalla para importarla."
                    isShowingAlert = true
                }
            }
        }
        .alert(alertTitle, isPresented: $isShowingAlert) {
            Button("Aceptar", role: .cancel) {
                if shouldDismissAfterAlert {
                    // Cerramos esta hoja de importación
                    dismiss()
                    // Notificamos al presentador (Ajustes) para que también se cierre
                    onImportCompleted?()
                }
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Secciones de contenido

    private var introSection: some View {
        SectionBox(title: "Cómo funciona") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.9))
                        )

                    Text(
                        "Importa tus movimientos desde un archivo CSV siguiendo unos pasos simples."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 8) {
                    stepRow("Descarga la plantilla de ejemplo.")
                    stepRow("Ábrela en tu editor de hojas de cálculo.")
                    stepRow("Completa tus transacciones siguiendo el formato indicado.")
                    stepRow("Guarda el archivo como CSV.")
                    stepRow("Asegúrate de tener el archivo disponible en la app Archivos.")
                    stepRow("Selecciona la cuenta destino e importa el archivo desde aquí.")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private var templateSection: some View {
        SectionBox(title: "Plantilla de ejemplo") {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    generateTemplateCSV()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Descargar plantilla")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Text(
                    "Descarga una plantilla CSV oficial de Finaria con el encabezado correcto y un ejemplo de fila. Luego podrás rellenarla y volver a esta pantalla para importarla."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var toggleSection: some View {
        SectionBox(title: "Categorías") {
            VStack(spacing: 0) {
                Toggle(isOn: $allowCreatingNewCategories) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Crear nuevas categorías y subcategorías")
                            .font(.body)
                        Text(
                            "Si el archivo incluye categorías que no existen, se crearán automáticamente cuando esta opción esté activada."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Lógica de flujo

    private func generateTemplateCSV() {
        // FIN-35: Plantilla oficial de importación CSV de Finaria
        // Encabezado compatible con TransactionCSVImportService
        // Formato: date,amount,currency,category,subcategory,note
        let header = "date,amount,currency,category,subcategory,note\n"

        // Fila de ejemplo bien formada, alineada con los criterios de FIN-35
        let exampleRow =
            "2024-01-15,-120.50,PEN,Alimentación,Supermercados y bodegas,Compra semanal\n"

        let csvString = header + exampleRow

        guard let data = csvString.data(using: .utf8) else {
            alertTitle = "No se pudo generar la plantilla"
            alertMessage = "Ocurrió un problema al crear el archivo CSV. Inténtalo nuevamente."
            isShowingAlert = true
            return
        }

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent("Finaria_Plantilla_Importacion.csv")

        do {
            try data.write(to: fileURL, options: .atomic)
            templateFile = TemplateFile(url: fileURL)
        } catch {
            alertTitle = "No se pudo generar la plantilla"
            alertMessage = error.localizedDescription
            isShowingAlert = true
        }
    }

    private func startAccountSelection() {
        guard !isImporting else { return }

        guard !activeAccounts.isEmpty else {
            alertTitle = "No hay cuentas disponibles"
            alertMessage =
                "Para importar transacciones, primero crea al menos una cuenta en Finaria."
            isShowingAlert = true
            return
        }

        isShowingAccountPicker = true
    }

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertTitle = "No se pudo leer el archivo"
            alertMessage = error.localizedDescription
            isShowingAlert = true
        case .success(let urls):
            guard let url = urls.first else {
                alertTitle = "Archivo no válido"
                alertMessage = "No se pudo obtener la URL del archivo seleccionado."
                isShowingAlert = true
                return
            }

            guard let account = selectedAccount else {
                // Si por alguna razón no tenemos cuenta, simplemente salimos.
                return
            }

            performImport(from: url, into: account)
        }
    }

    private func performImport(from url: URL, into account: Account) {
        isImporting = true

        Task {
            do {
                // FIN-24: el flag allowCreatingNewCategories controla
                // si se crean nuevas categorías/subcategorías durante la importación.
                let result = try TransactionCSVImportService.importCSV(
                    from: url,
                    into: account,
                    in: modelContext,
                    allowCreatingNewCategories: allowCreatingNewCategories
                )

                do {
                    try modelContext.save()
                } catch {
                    // Si la persistencia falla, mostramos un error genérico.
                    alertTitle = "Error al guardar"
                    alertMessage = error.localizedDescription
                    shouldDismissAfterAlert = false
                    isShowingAlert = true
                    isImporting = false
                    return
                }

                alertTitle = "Importación completada"
                alertMessage = "Importación completada: \(result.createdCount) registros cargados."
                shouldDismissAfterAlert = true
                isShowingAlert = true
            } catch {
                alertTitle = "Error al importar"
                alertMessage = error.localizedDescription
                shouldDismissAfterAlert = false
                isShowingAlert = true
            }

            isImporting = false
        }
    }
}

struct TemplateFile: Identifiable {
    let id = UUID()
    let url: URL
}
