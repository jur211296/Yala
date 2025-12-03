//
//  SettingsRootView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Ajustes (pantalla principal)

struct SettingsRootView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen
        .rawValue

    @Query private var allTransactions: [TransactionItem]

    @State private var isPresentingImportIntro: Bool = false
    @State private var isPresentingExportWizard: Bool = false

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
        .sheet(isPresented: $isPresentingImportIntro) {
            ImportIntroSheet(onImportCompleted: {
                // Cerramos también la pantalla de Ajustes para volver al Panel
                dismiss()
            })
        }
        .sheet(isPresented: $isPresentingExportWizard) {
            ExportFiltersStepView()
        }
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
                    TagsSettingsListView()
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

                Button {
                    isPresentingImportIntro = true
                } label: {
                    settingsRow(title: "Importar archivo", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.plain)

                SubsectionDivider()

                Button {
                    isPresentingExportWizard = true
                } label: {
                    settingsRow(title: "Exportar datos", systemImage: "square.and.arrow.up")
                        .opacity(allTransactions.isEmpty ? 0.5 : 1.0)
                }
                .disabled(allTransactions.isEmpty)
                .buttonStyle(.plain)

                SubsectionDivider()

                NavigationLink {
                    UserDataResetView(onUserDataWiped: {
                        // Cerramos la hoja de Ajustes para volver al Panel
                        dismiss()
                    })
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
                    settingsRow(
                        title: "Administrar suscripciones", systemImage: "creditcard.and.123")
                }

                SubsectionDivider()

                NavigationLink {
                    SettingsPlaceholderView(title: "Política de privacidad")
                } label: {
                    settingsRow(
                        title: "Política de privacidad", systemImage: "doc.text.magnifyingglass")
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
