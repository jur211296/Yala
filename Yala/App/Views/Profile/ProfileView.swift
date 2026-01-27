//
//  ProfileView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import StoreKit
import SwiftData
import SwiftUI

//  Created by Yala Refactoring.
//

/// Main profile screen acting as the Configuration Control Center
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("colorfulIcons") private var colorfulIcons: Bool = true
    @AppStorage("userProfileImageData") private var userProfileImageData: Data?

    @Query private var allTransactions: [TransactionItem]
    @Query private var accounts: [Account]
    @Query private var categories: [Category]

    // Navigation & Sheets
    @State private var navigationPath = NavigationPath()
    @State private var activeSheet: ProfileSheet?

    // Import result - shown as alert after ImportIntroSheet dismisses
    @State private var importResult: ImportResult?
    @State private var showImportResult: Bool = false

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
        case personalization
        case currency
        case appIcon
        case notifications
        case favorites
        case budgetsFavorites
        case planned
        case userDataReset
        case biometricSecurity
        case placeholder(String)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
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
                        Text(L10n.Settings.versionInfo)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Profile.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $activeSheet) { item in
                switch item {
                case .personalDetails:
                    PersonalDetailsView()
                case .importIntro:
                    ImportIntroSheet(
                        accounts: accounts,
                        categories: categories,
                        onImportCompleted: { result in
                            // Store result and show alert after sheet animation completes
                            activeSheet = nil
                            importResult = result
                            // Small delay to ensure sheet is fully dismissed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showImportResult = true
                            }
                        }
                    )
                case .exportWizard:
                    ExportFiltersStepView()
                }
            }
            .alert(
                importResult?.isSuccess == true
                    ? L10n.Profile.importSuccess : L10n.Profile.importError,
                isPresented: $showImportResult,
                presenting: importResult
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { result in
                Text(result.message)
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
                case .personalization:
                    PersonalizationSettingsView()
                case .currency:
                    CurrencySettingsView()
                case .appIcon:
                    AppIconSettingsView()
                case .biometricSecurity:
                    BiometricSecurityView()
                case .placeholder(let title):
                    SettingsPlaceholderView(title: title)
                case .notifications:
                    SettingsPlaceholderView(title: L10n.Settings.notifications)
                case .favorites:
                    FavoritesListView(mode: .manage)
                case .budgetsFavorites:
                    BudgetsFavoritesSettingsView()
                case .planned:
                    ScheduledPaymentsSettingsView()
                case .userDataReset:
                    UserDataResetView(onUserDataWiped: {
                        dismiss()
                    })
                }
            }
        }
    }

    // User Theme for dynamic updates
    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue

    // Default Period Preference
    @AppStorage("defaultPeriod") private var defaultPeriodRaw: String = DetailPeriod.allTime
        .rawValue

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: DS.Spacing.md) {
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

                if let imageData = userProfileImageData,
                    let uiImage = UIImage(data: imageData)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.electricIndigo.opacity(0.1))
                        .frame(width: 90, height: 90)

                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.electricIndigo)
                }
            }

            Text(userName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Button(L10n.Profile.edit) {
                activeSheet = .personalDetails
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.electricIndigo)
        }
        .padding(.top, 8)
    }

    // MARK: - Sections

    private var organizacionSection: some View {
        SectionBox(title: L10n.Settings.organization) {
            VStack(spacing: 0) {
                profileRow(
                    icon: "creditcard.fill", title: L10n.Settings.accounts, iconColor: .green,
                    destination: .accounts)
                SubsectionDivider()
                profileRow(
                    icon: "tag.fill", title: L10n.Settings.categories, iconColor: .orange,
                    destination: .categories)
                SubsectionDivider()
                profileRow(
                    icon: "number", title: L10n.Settings.tags, iconColor: .purple,
                    destination: .tags)
                SubsectionDivider()
                profileRow(
                    icon: "chart.pie.fill", title: L10n.Settings.budgetsFavorites,
                    iconColor: .mint,
                    destination: .budgetsFavorites)
                SubsectionDivider()
                profileRow(
                    icon: "calendar.badge.clock", title: L10n.Settings.plannedPayments,
                    iconColor: .cyan,
                    destination: .planned
                )
                SubsectionDivider()
                profileRow(
                    icon: "star.fill", title: L10n.Settings.favorites, iconColor: .yellow,
                    destination: .favorites)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var preferenciasSection: some View {
        SectionBox(title: L10n.Settings.preferences) {
            VStack(spacing: 0) {
                profileRow(
                    icon: "slider.horizontal.3", title: L10n.Settings.personalization,
                    iconColor: .indigo, destination: .personalization)
                SubsectionDivider()
                profileRow(
                    icon: "paintpalette.fill", title: L10n.Settings.theme, iconColor: .pink,
                    destination: .themes)
                SubsectionDivider()
                profileRow(
                    icon: "app.fill", title: L10n.Settings.appIcon,
                    iconColor: .blue, destination: .appIcon)
                SubsectionDivider()
                profileRow(
                    icon: "dollarsign.circle.fill", title: L10n.Settings.currencyAndExchange,
                    iconColor: .green, destination: .currency
                )
                SubsectionDivider()
                profileRow(
                    icon: "bell.fill", title: L10n.Settings.notifications, iconColor: .red,
                    destination: .notifications)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var datosSection: some View {
        SectionBox(title: L10n.Settings.data) {
            VStack(spacing: 0) {
                Button {
                    activeSheet = .importIntro
                } label: {
                    settingsRowContent(
                        icon: "tray.and.arrow.down.fill", title: L10n.Settings.importData,
                        iconColor: .blue)
                }
                .buttonStyle(.plain)

                SubsectionDivider()

                Button {
                    activeSheet = .exportWizard
                } label: {
                    settingsRowContent(
                        icon: "square.and.arrow.up.fill", title: L10n.Settings.exportData,
                        iconColor: .mint
                    )
                    .opacity(allTransactions.isEmpty ? 0.5 : 1.0)
                }
                .disabled(allTransactions.isEmpty)
                .buttonStyle(.plain)

                SubsectionDivider()

                NavigationLink(value: ProfileDestination.userDataReset) {
                    settingsRowContent(
                        icon: "trash.fill", title: L10n.Settings.wipeData, iconColor: .red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var seguridadSection: some View {
        SectionBox(title: L10n.Settings.security) {
            VStack(spacing: 0) {
                profileRow(
                    icon: BiometricAuthService.shared.biometricType.icon,
                    title: BiometricAuthService.shared.biometricType.displayName,
                    iconColor: .green,
                    destination: .biometricSecurity)
                SubsectionDivider()
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    settingsRowContent(
                        icon: "lock.shield.fill", title: L10n.Settings.permissions,
                        iconColor: .blue)
                }
                .buttonStyle(.plain)
                SubsectionDivider()
                profileRow(
                    icon: "creditcard.fill", title: L10n.Settings.subscriptions,
                    iconColor: .purple, destination: .placeholder("Suscripciones"))
                SubsectionDivider()
                Button {
                    requestReview()
                } label: {
                    settingsRowContent(
                        icon: "star.bubble.fill", title: L10n.Settings.rateApp,
                        iconColor: .yellow)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var ayudaSection: some View {
        SectionBox(title: L10n.Settings.help) {
            VStack(spacing: 0) {
                profileRow(
                    icon: "lightbulb.fill", title: L10n.Settings.tips,
                    iconColor: .yellow, destination: .placeholder("Consejos"))
                SubsectionDivider()
                profileRow(
                    icon: "questionmark.circle.fill", title: L10n.Settings.faq,
                    iconColor: .orange, destination: .placeholder("FAQ"))
                SubsectionDivider()
                Button {
                    if let url = URL(string: "mailto:admin@yala-app.pe") {
                        openURL(url)
                    }
                } label: {
                    settingsRowContent(
                        icon: "envelope.fill", title: L10n.Settings.contact,
                        iconColor: .teal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var legalSection: some View {
        SectionBox(title: L10n.Settings.legal) {
            VStack(spacing: 0) {
                Button {
                    if let url = URL(string: "https://yala-app.pe/privacy") {
                        openURL(url)
                    }
                } label: {
                    settingsRowContent(
                        icon: "hand.raised.fill", title: L10n.Settings.privacy,
                        iconColor: .gray)
                }
                .buttonStyle(.plain)
                SubsectionDivider()
                Button {
                    if let url = URL(string: "https://yala-app.pe/terms") {
                        openURL(url)
                    }
                } label: {
                    settingsRowContent(
                        icon: "doc.text.fill", title: L10n.Settings.terms,
                        iconColor: .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Reference Builder

    @ViewBuilder
    private func profileRow(
        icon: String,
        title: String,
        iconColor: Color = .gray,
        destination: ProfileDestination
    ) -> some View {
        NavigationLink(value: destination) {
            settingsRowContent(icon: icon, title: title, iconColor: iconColor)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowContent(
        icon: String,
        title: String,
        iconColor: Color = .gray,
        textColor: Color = .primary
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Conditionally show colored or plain icons based on setting
            if colorfulIcons {
                // iOS-style colored icon with rounded square background
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(iconColor)
                    )
            } else {
                // Plain icon without background
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 28)
            }

            Text(title)
                .font(.body)
                .foregroundStyle(textColor)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
}
