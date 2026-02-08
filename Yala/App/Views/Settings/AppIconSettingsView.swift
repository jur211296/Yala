//
//  AppIconSettingsView.swift
//  Yala
//
//  App icon selection screen with visual grid.
//

import SwiftUI

// MARK: - App Icon Model

enum AppIconOption: String, CaseIterable, Identifiable {
    case original
    case dark
    case light
    case neon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return L10n.Settings.iconOriginal
        case .dark: return L10n.Settings.iconDark
        case .light: return L10n.Settings.iconLight
        case .neon: return L10n.Settings.iconNeon
        }
    }

    /// The icon name to use with setAlternateIconName
    /// Must match the KEY in CFBundleAlternateIcons (nil for primary)
    var iconName: String? {
        switch self {
        case .original: return nil  // Uses CFBundlePrimaryIcon (IconOriginal)
        case .dark: return "IconDark"
        case .light: return "AppIconLight"  // Asset Catalog name
        case .neon: return "AppIconNeon"    // Asset Catalog name
        }
    }

    /// Preview image name (use @3x PNG files for display)
    var previewImageName: String {
        switch self {
        case .original: return "IconOriginal@3x"
        case .dark: return "IconDark@3x"
        case .light: return "IconLight@3x"
        case .neon: return "IconNeon@3x"
        }
    }

    /// Whether this icon requires Pro tier
    var isPremium: Bool {
        switch self {
        case .original: return false
        case .dark, .light, .neon: return true
        }
    }
}

// MARK: - App Icon Settings View

struct AppIconSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48

    @State private var selectedIcon: AppIconOption = .original
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showUpgradeSheet = false

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.lg),
        GridItem(.flexible(), spacing: DS.Spacing.lg),
    ]

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "app.fill")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(Color.brandPrimary)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Settings.appIcon)
                            .font(.title2.bold())
                            .foregroundStyle(Color.yalaPrimaryText)

                        Text(L10n.Settings.appIconDescription)
                            .font(.body)
                            .foregroundStyle(Color.yalaSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // Icon Grid
                    LazyVGrid(columns: columns, spacing: DS.Spacing.lg) {
                        ForEach(AppIconOption.allCases) { icon in
                            iconCell(for: icon)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle(L10n.Settings.appIconTitle)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadCurrentIcon()

            // If Free user has premium icon, reset to original
            if !isProUser && selectedIcon.isPremium {
                setAppIcon(.original)
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .premiumIcons, context: .proFeature)
        }
        .alert(L10n.Common.error, isPresented: $showingError) {
            Button(L10n.Action.done, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Icon Cell

    @ViewBuilder
    private func iconCell(for icon: AppIconOption) -> some View {
        let isSelected = selectedIcon == icon
        let isLocked = icon.isPremium && !isProUser

        Button {
            if isLocked {
                showUpgradeSheet = true
            } else {
                setAppIcon(icon)
            }
        } label: {
            VStack(spacing: DS.Spacing.md) {
                // Icon Preview - Load with fixed light trait to prevent dark mode changes
                ZStack(alignment: .topTrailing) {
                    if let uiImage = UIImage(named: icon.previewImageName)?
                        .imageAsset?.image(with: UITraitCollection(userInterfaceStyle: .light)) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .opacity(isLocked ? 0.5 : 1.0)
                    } else {
                        // Fallback if image not found
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 3)
                            )
                    }

                    // Lock badge for premium icons
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(Color.gray))
                            .offset(x: 4, y: -4)
                    }
                }

                // Label
                HStack(spacing: DS.Spacing.xs) {
                    Text(icon.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isLocked ? Color.yalaSecondaryText : Color.yalaPrimaryText)

                    if icon.isPremium && !isSelected {
                        ProBadge(size: .small)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .background(Color.yalaCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(
                        isSelected ? Color.brandPrimary.opacity(0.3) : Color.primary.opacity(0.05),
                        lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon Logic

    private func loadCurrentIcon() {
        let currentIconName = UIApplication.shared.alternateIconName

        if let iconName = currentIconName,
            let icon = AppIconOption.allCases.first(where: { $0.iconName == iconName })
        {
            selectedIcon = icon
        } else {
            selectedIcon = .original
        }
    }

    private func setAppIcon(_ icon: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = L10n.Settings.iconNotSupported
            showingError = true
            return
        }

        UIApplication.shared.setAlternateIconName(icon.iconName) { error in
            if let error = error {
                errorMessage = L10n.Settings.iconChangeFailed(error.localizedDescription)
                showingError = true
            } else {
                withAnimation {
                    selectedIcon = icon
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppIconSettingsView()
    }
}
