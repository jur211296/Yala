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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric

    @State private var selectedIcon: AppIconOption = .original
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showUpgradeSheet = false
    /// El icono Pro que se tocó: el muro lo enseña (UX 2.2 · L16-11) y, si se compra ahí, se pone (L17-9).
    @State private var lockedIcon: AppIconOption?

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.lg),
        GridItem(.flexible(), spacing: DS.Spacing.lg),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "app.fill")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(.thAccent)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Settings.appIcon)
                            .font(.title2.bold())
                            .foregroundStyle(.thPrimaryText)

                        Text(L10n.Settings.appIconDescription)
                            .font(DS.Typography.body)
                            .foregroundStyle(.thSecondaryText)
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
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Settings.appIconTitle)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadCurrentIcon()

            // Sin Pro y con un icono Pro, vuelve al original. Pero no mientras esté pendiente la hoja de fin de Pro: es
            // ella la que avisa antes de devolverlo (UX 2.2 · L16-11), y aquí volvía sin decir nada.
            if !isProUser && selectedIcon.isPremium && !StoreKitManager.shared.justDowngraded {
                setAppIcon(.original)
            }
        }
        .proUpgradeSheet(
            isPresented: $showUpgradeSheet,
            feature: .premiumIcons,
            context: .proFeature,
            preview: lockedIcon.map { .icon($0) },
            onUnlocked: {
                if let lockedIcon { setAppIcon(lockedIcon) }
            }
        )
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
                lockedIcon = icon
                showUpgradeSheet = true
            } else {
                setAppIcon(icon)
            }
        } label: {
            VStack(spacing: DS.Spacing.md) {
                // Icon Preview - Load with fixed light trait to prevent dark mode changes
                ZStack(alignment: .topTrailing) {
                    AppIconPreviewImage(icon: icon, size: 80)
                        .opacity(isLocked ? 0.5 : 1.0)

                    // Lock badge for premium icons
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.white)
                            .padding(DS.Chip.paddingV)
                            .background(Circle().fill(DS.Semantic.disabledForeground)) // A11Y-DM: lock badge on app icon — white icon on gray
                            .offset(x: 4, y: -4)
                    }
                }

                // Label
                HStack(spacing: DS.Spacing.xs) {
                    Text(icon.displayName)
                        .font(DS.Typography.label.weight(isSelected ? .bold : .regular))
                        .foregroundStyle(isLocked ? .thSecondaryText : .thPrimaryText)

                    if icon.isPremium && !isSelected {
                        ProBadge(size: .small)
                    }

                    if isSelected {
                        InUseBadge()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .selectableCard(
                isSelected: false,
                radius: DS.Radius.lg,
                inactiveColor: Color.primary.opacity(0.05)
            )
            // La elegida, rellena con su borde y «En uso», como en Temas (UX 2.2 · L16-9).
            .selectedOptionFill(isSelected, radius: DS.Radius.lg, lineWidth: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("app_icon_\(icon.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                dsWithAnimation(reduceMotion) {
                    selectedIcon = icon
                }
            }
        }
    }
}

// MARK: - Icon Preview Image

/// El icono tal como se ve en la pantalla de inicio, con el aspecto claro fijo (no cambia con el modo oscuro). Lo usan
/// «Icono de la app» y la vista previa del muro de Pro (UX 2.2 · L16-11).
struct AppIconPreviewImage: View {
    let icon: AppIconOption
    let size: CGFloat

    var body: some View {
        if let uiImage = UIImage(named: icon.previewImageName)?
            .imageAsset?.image(with: UITraitCollection(userInterfaceStyle: .light)) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .accessibilityLabel(icon.displayName)
        } else {
            // Fallback if image not found
            RoundedRectangle(cornerRadius: size * 0.225)
                .fill(Color.gray.opacity(0.3)) // A11Y-DM: placeholder fallback for missing icon
                .frame(width: size, height: size)
        }
    }
}

#Preview {
    NavigationStack {
        AppIconSettingsView()
    }
}
