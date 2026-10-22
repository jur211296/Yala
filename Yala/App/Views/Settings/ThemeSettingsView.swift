//
//  ThemeSettingsView.swift
//  Yala
//
//  Theme selection with 9 themes: 4 free + 5 PRO.
//  Grid layout with preview cards following AppIconSettingsView pattern.
//  En modo solo-grupos solo se muestran los temas free (sin candados de venta).
//

import SwiftUI

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    private let featureGate = FeatureGateService.shared

    private var isGroupsOnlyShell: Bool { !SessionState.shared.hasPrivateSession }

    @State private var showUpgradeSheet = false
    /// El tema Pro que se tocó: el muro lo enseña (UX 2.2 · L16-11) y, si se compra ahí, se aplica (L17-9).
    @State private var lockedTheme: AppTheme?
    @State private var showTranslucentVariantPicker = false

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.lg),
        GridItem(.flexible(), spacing: DS.Spacing.lg),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(.thAccent)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Profile.appearance)
                            .font(DS.Typography.title2.bold())
                            .foregroundStyle(.thPrimaryText)

                        Text(L10n.Settings.themeDescription)
                            .font(DS.Typography.body)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // Theme Grid
                    LazyVGrid(columns: columns, spacing: DS.Spacing.lg) {
                        ForEach(GroupsOnlyVisibilityPolicy.selectableThemes(isGroupsOnlyShell: isGroupsOnlyShell)) { appTheme in
                            themeCard(for: appTheme)
                        }
                    }
                    .confirmationDialog(
                        L10n.Settings.themeTranslucent,
                        isPresented: $showTranslucentVariantPicker,
                        titleVisibility: .visible
                    ) {
                        ForEach(TranslucentVariant.allCases) { variant in
                            Button {
                                // El tema se aplica AQUÍ, al elegir variante. Antes se aplicaba al tocar la tarjeta y
                                // cerrar el diálogo sin elegir lo dejaba puesto (auditoría UX 2.2, lote 16). Y la pantalla
                                // se queda (L16-10): se ve el cambio aquí mismo y se puede probar otro.
                                themeManager.userChoice = .translucent
                                themeManager.translucentVariant = variant
                            } label: {
                                Label(variant.label, systemImage: "circle.fill")
                            }
                        }
                        Button(L10n.Action.cancel, role: .cancel) {}
                    }

                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Settings.theme)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
        .proUpgradeSheet(
            isPresented: $showUpgradeSheet,
            feature: .proThemes,
            context: .proFeature,
            preview: lockedTheme.map { .theme($0, variant: themeManager.translucentVariant) },
            onUnlocked: {
                if let lockedTheme { choose(lockedTheme) }
            }
        )
    }

    /// Aplicar un tema que se puede usar: el mismo camino al tocarlo que al comprarlo desde su muro.
    private func choose(_ appTheme: AppTheme) {
        if appTheme == .translucent {
            // Solo abre el selector de variante: el tema no cambia hasta que se elige una.
            showTranslucentVariantPicker = true
        } else {
            // UX 2.2 · L16-10: el tema se aplica en vivo y Temas se queda abierta. Antes, a los 300 ms se cerraba Ajustes
            // entero y no se podían comparar dos temas.
            themeManager.userChoice = appTheme
        }
    }

    // MARK: - Theme Card

    @ViewBuilder
    private func themeCard(for appTheme: AppTheme) -> some View {
        let isSelected = themeManager.userChoice == appTheme
        let isLocked = appTheme.isPro && !featureGate.isProUser

        Button {
            if isLocked {
                lockedTheme = appTheme
                showUpgradeSheet = true
            } else {
                choose(appTheme)
            }
        } label: {
            VStack(spacing: DS.Spacing.md) {
                // Preview area
                ZStack(alignment: .topTrailing) {
                    ThemePreviewTile(appTheme: appTheme, translucentVariant: themeManager.translucentVariant)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .opacity(isLocked ? 0.5 : 1.0)

                    // Lock badge
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.white)
                            .padding(DS.Chip.paddingV)
                            .background(Circle().fill(DS.Semantic.disabledForeground)) // A11Y-DM: lock badge on theme preview — white icon on gray
                            .offset(x: 4, y: -4)
                    }
                }

                // Label row
                VStack(spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(appTheme.label)
                            .font(DS.Typography.label.weight(isSelected ? .bold : .regular))
                            .foregroundStyle(isLocked ? .thSecondaryText : .thPrimaryText)

                        if appTheme.isPro && !isSelected {
                            ProBadge(size: .small)
                        }

                        if isSelected {
                            InUseBadge()
                        }
                    }

                    // Variant indicator for translucent theme
                    if appTheme == .translucent && isSelected {
                        HStack(spacing: DS.Spacing.xxs) {
                            Circle()
                                .fill(themeManager.translucentVariant.iconColor)
                                .frame(width: 6, height: 6)
                            Text(themeManager.translucentVariant.label)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.thSecondaryText)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.sm)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            // La elegida, rellena del color de acento con su borde y «En uso» (UX 2.2 · L16-9). Antes, un borde índigo
            // en la miniatura y un ✓ pequeño junto al nombre.
            .selectedOptionFill(isSelected, radius: DS.Radius.lg, lineWidth: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("theme_card_\(appTheme.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Theme Preview Tile

/// La miniatura de un tema: la de Temas y la de la vista previa del muro de Pro (UX 2.2 · L16-11), que es la misma.
struct ThemePreviewTile: View {
    let appTheme: AppTheme
    /// La variante con la que se pinta el tema Translúcido (la elegida en Temas).
    let translucentVariant: TranslucentVariant

    var body: some View {
        if appTheme == .system {
            // Split preview: left light, right dark
            GeometryReader { geo in
                HStack(spacing: 0) {
                    themeMockup(palette: .light)
                        .frame(width: geo.size.width / 2)
                        .clipped()

                    themeMockup(palette: .dark)
                        .frame(width: geo.size.width / 2)
                        .clipped()
                }
            }
        } else if appTheme == .liquidGlass {
            translucentPreview(palette: appTheme.yalaTheme, variant: .indigo, isLiquidGlass: true)
        } else if appTheme == .translucent {
            translucentPreview(palette: appTheme.yalaTheme)
        } else {
            themeMockup(palette: appTheme.yalaTheme)
        }
    }

    // MARK: - Mock Card

    private func translucentPreview(
        palette: YalaTheme,
        variant: TranslucentVariant? = nil,
        isLiquidGlass: Bool = false
    ) -> some View {
        let effectiveVariant = variant ?? translucentVariant
        let gradientColors: [Color] = if isLiquidGlass {
            [Color(hex: "0E0A24"), Color(hex: "14102E"), Color(hex: "050510")]
        } else {
            switch effectiveVariant {
            case .indigo: [Color(hex: "1A1040"), Color(hex: "2A1A5E"), Color(hex: "0A0A1A")]
            case .rosa: [Color(hex: "401028"), Color(hex: "5E1A40"), Color(hex: "1A0A12")]
            case .teal: [Color(hex: "103830"), Color(hex: "1A5E4A"), Color(hex: "0A1A18")]
            }
        }
        return ZStack {
            // Mini gradient background
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Inner card mock with material-like effect
            VStack(spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Circle().fill(palette.accent).frame(width: 8, height: 8)
                    Circle().fill(palette.income).frame(width: 8, height: 8)
                    Circle().fill(palette.expense).frame(width: 8, height: 8)
                    Spacer()
                }

                Capsule()
                    .fill(palette.primaryText.opacity(0.6))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)

                Capsule()
                    .fill(palette.secondaryText.opacity(0.4))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, DS.Spacing.xxl)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(Color.white.opacity(0.08))
            )
            .padding(DS.Spacing.md)
        }
    }

    private func themeMockup(palette: YalaTheme) -> some View {
        ZStack {
            // Background
            Rectangle().fill(palette.background)

            // Inner card mock
            VStack(spacing: DS.Spacing.sm) {
                // Colored dots row
                HStack(spacing: DS.Spacing.sm) {
                    Circle().fill(palette.accent).frame(width: 8, height: 8)
                    Circle().fill(palette.income).frame(width: 8, height: 8)
                    Circle().fill(palette.expense).frame(width: 8, height: 8)
                    Spacer()
                }

                // Simulated text lines
                Capsule()
                    .fill(palette.primaryText.opacity(0.6))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)

                Capsule()
                    .fill(palette.secondaryText.opacity(0.4))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, DS.Spacing.xxl)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(palette.card)
            )
            .padding(DS.Spacing.md)
        }
    }
}
