//
//  AppIconSettingsView.swift
//  Neto
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
        case .light: return "IconLight"
        case .neon: return "IconNeon"
        }
    }

    /// Preview image name (use @3x versions for display, they're 180x180)
    var previewImageName: String {
        switch self {
        case .original: return "IconOriginal@3x"
        case .dark: return "IconDark@3x"
        case .light: return "IconLight@3x"
        case .neon: return "IconNeon@3x"
        }
    }
}

// MARK: - App Icon Settings View

struct AppIconSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue

    @State private var selectedIcon: AppIconOption = .original
    @State private var showingError = false
    @State private var errorMessage = ""

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "app.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandPrimary)
                            .padding(.bottom, 8)

                        Text(L10n.Settings.appIcon)
                            .font(.title2.bold())
                            .foregroundStyle(Color.netoPrimaryText)

                        Text(L10n.Settings.appIconDescription)
                            .font(.body)
                            .foregroundStyle(Color.netoSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    // Icon Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AppIconOption.allCases) { icon in
                            iconCell(for: icon)
                        }
                    }
                    .padding(.horizontal, 16)

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
                NetoToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadCurrentIcon()
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

        Button {
            setAppIcon(icon)
        } label: {
            VStack(spacing: 12) {
                // Icon Preview - Load from bundle using UIImage
                if let uiImage = UIImage(named: icon.previewImageName) {
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

                // Label
                HStack(spacing: 6) {
                    Text(icon.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.netoPrimaryText)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.netoCard)
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
