//
//  ProfileView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

/// Main profile screen with user info and app settings navigation
//
//  ProfileView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

/// Main profile screen acting as the Configuration Control Center
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("userName") private var userName: String = "Usuario"

    @Query private var allTransactions: [TransactionItem]

    // Navigation & Sheets
    @State private var navigationPath = NavigationPath()
    @State private var activeSheet: ProfileSheet?

    enum ProfileSheet: Identifiable {
        case personalDetails
        case importIntro
        case exportWizard

        var id: Int {
            hashValue
        }
    }

    // Destinations for NavigationStack
    enum ProfileDestination: Hashable {
        case accounts
        case categories
        case tags
        case themes
        case currency
        case notifications
        case favorites
        case planned
        case userDataReset
        case placeholder(String)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        profileHeader

                        // Sections
                        organizacionSection
                        preferenciasSection
                        datosSection
                        seguridadSection
                        ayudaSection
                        legalSection

                        // Version info
                        Text("Versión 1.0.0 (Build 1)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetTopButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $activeSheet) { item in
                switch item {
                case .personalDetails:
                    PersonalDetailsView()
                case .importIntro:
                    ImportIntroSheet(onImportCompleted: {
                        activeSheet = nil
                    })
                case .exportWizard:
                    ExportFiltersStepView()
                }
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .accounts:
                    AccountsSettingsListView()
                case .categories:
                    CategoriesSettingsListView()
                case .tags:
                    TagsSettingsListView()
                case .themes:
                    ThemeSettingsView()
                case .currency:
                    CurrencySettingsView()
                case .placeholder(let title):
                    SettingsPlaceholderView(title: title)
                case .notifications:
                    SettingsPlaceholderView(title: "Notificaciones")
                case .favorites:
                    SettingsPlaceholderView(title: "Pagos favoritos")
                case .planned:
                    SettingsPlaceholderView(title: "Pagos planificados")
                case .userDataReset:
                    UserDataResetView(onUserDataWiped: {
                        dismiss()
                    })
                }
            }
        }
        .preferredColorScheme(AppTheme(rawValue: userThemeRaw)?.colorScheme)
    }

    // User Theme for dynamic updates
    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.electricIndigo, Color.electricIndigo.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(Color.electricIndigo.opacity(0.1))
                    .frame(width: 90, height: 90)

                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.electricIndigo)
            }

            Text(userName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Button("Editar perfil") {
                activeSheet = .personalDetails
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.electricIndigo)
        }
        .padding(.top, 8)
    }

    // MARK: - Sections

    private var organizacionSection: some View {
        SectionBox(title: "Organización") {
            VStack(spacing: 0) {
                profileRow(icon: "creditcard.fill", title: "Cuentas", destination: .accounts)
                SubsectionDivider()
                profileRow(icon: "tag.fill", title: "Categorías", destination: .categories)
                SubsectionDivider()
                profileRow(icon: "number", title: "Etiquetas", destination: .tags)
                SubsectionDivider()
                profileRow(icon: "star.fill", title: "Pagos favoritos", destination: .favorites)
                SubsectionDivider()
                profileRow(
                    icon: "calendar.badge.clock", title: "Pagos planificados", destination: .planned
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private var preferenciasSection: some View {
        SectionBox(title: "Preferencias") {
            VStack(spacing: 0) {
                profileRow(icon: "paintpalette.fill", title: "Temas", destination: .themes)
                SubsectionDivider()
                profileRow(
                    icon: "app.fill", title: "Icono de aplicación",
                    destination: .placeholder("Icono de aplicación"))
                SubsectionDivider()
                profileRow(
                    icon: "dollarsign.circle.fill", title: "Divisa y cambio", destination: .currency
                )
                SubsectionDivider()
                profileRow(icon: "bell.fill", title: "Notificaciones", destination: .notifications)
            }
        }
        .padding(.horizontal, 16)
    }

    private var datosSection: some View {
        SectionBox(title: "Datos") {
            VStack(spacing: 0) {
                Button {
                    activeSheet = .importIntro
                } label: {
                    settingsRowContent(icon: "tray.and.arrow.down.fill", title: "Importar archivo")
                }
                .buttonStyle(.plain)

                SubsectionDivider()

                Button {
                    activeSheet = .exportWizard
                } label: {
                    settingsRowContent(icon: "square.and.arrow.up.fill", title: "Exportar datos")
                        .opacity(allTransactions.isEmpty ? 0.5 : 1.0)
                }
                .disabled(allTransactions.isEmpty)
                .buttonStyle(.plain)

                SubsectionDivider()

                NavigationLink(value: ProfileDestination.userDataReset) {
                    settingsRowContent(icon: "trash.fill", title: "Vaciar datos", color: .red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private var seguridadSection: some View {
        SectionBox(title: "Seguridad y cuenta") {
            VStack(spacing: 0) {
                profileRow(icon: "faceid", title: "Face ID", destination: .placeholder("Face ID"))
                SubsectionDivider()
                profileRow(
                    icon: "lock.shield.fill", title: "Permisos",
                    destination: .placeholder("Permisos"))
                SubsectionDivider()
                profileRow(
                    icon: "creditcard.fill", title: "Administrar suscripciones",
                    destination: .placeholder("Suscripciones"))
                SubsectionDivider()
                profileRow(
                    icon: "star.bubble.fill", title: "Calificar y recomendar",
                    destination: .placeholder("Calificar"))
            }
        }
        .padding(.horizontal, 16)
    }

    private var ayudaSection: some View {
        SectionBox(title: "¿Necesitas ayuda?") {
            VStack(spacing: 0) {
                profileRow(
                    icon: "lightbulb.fill", title: "Consejos y trucos",
                    destination: .placeholder("Consejos"))
                SubsectionDivider()
                profileRow(
                    icon: "questionmark.circle.fill", title: "Preguntas frecuentes",
                    destination: .placeholder("FAQ"))
                SubsectionDivider()
                profileRow(
                    icon: "envelope.fill", title: "Contacta con nosotros",
                    destination: .placeholder("Contacta"))
            }
        }
        .padding(.horizontal, 16)
    }

    private var legalSection: some View {
        SectionBox(title: "Legal") {
            VStack(spacing: 0) {
                profileRow(
                    icon: "hand.raised.fill", title: "Política de privacidad",
                    destination: .placeholder("Privacidad"))
                SubsectionDivider()
                profileRow(
                    icon: "doc.text.fill", title: "Términos de uso",
                    destination: .placeholder("Términos"))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Reference Builder

    @ViewBuilder
    private func profileRow(icon: String, title: String, destination: ProfileDestination)
        -> some View
    {
        NavigationLink(value: destination) {
            settingsRowContent(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowContent(icon: String, title: String, color: Color = .primary)
        -> some View
    {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .foregroundStyle(color)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    ProfileView()
}
