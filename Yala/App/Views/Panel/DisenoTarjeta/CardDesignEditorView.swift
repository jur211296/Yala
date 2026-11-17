//
//  CardDesignEditorView.swift
//  Yala
//
//  El editor de diseño de la tarjeta de una cuenta (2026-11-16, ticket `2026-11-15-tarjetas-personalizables`). Se abre
//  desde el botón de paleta de la tarjeta o desde su menú contextual en el carrusel «Tus finanzas». Arriba, la tarjeta de
//  verdad con el diseño que se está eligiendo (misma vista que el Panel, con su saldo); debajo, la galería de plantillas y
//  los controles de color, patrón, ícono, chip y últimos 4 dígitos.
//
//  Lo que la persona va eligiendo vive en el ítem de la presentación (`CardDesignDraft`), no en un `@State` del contenido:
//  iOS puede rehacer el contenido de una hoja sin cerrarla (regla de `swiftui-ds.md`) y no debe perderse lo elegido.
//

import SwiftData
import SwiftUI
import UIKit

// MARK: - Borrador y presentación

/// Lo que la persona va eligiendo, hasta que guarda.
@MainActor
@Observable
final class CardDesignDraft {
    var design: CardDesign
    /// Lo que hay escrito en el campo de los dígitos (puede estar a medias). Al guardar solo cuentan 4 números exactos.
    var lastFourText: String
    let accountType: AccountType

    init(design: CardDesign, accountType: AccountType) {
        self.design = design
        self.lastFourText = design.lastFour ?? ""
        self.accountType = accountType
    }

    /// El diseño que se pinta y se guarda: el elegido con los dígitos del campo, si son 4 números.
    var resolvedDesign: CardDesign {
        var result = design
        result.lastFour = CardDesignLogic.sanitizedLastFour(lastFourText)
        return result
    }

    func choose(template: CardTemplate) {
        design.templateID = template.id
        // Una plantilla trae sus colores y su patrón: lo que la persona había cambiado de la anterior no se arrastra.
        design.colorHex = nil
        design.pattern = nil
    }

    func resetToDefault() {
        design = CardDesignLogic.defaultDesign(type: accountType)
        lastFourText = ""
    }
}

/// El editor abierto para una cuenta, con lo que necesita su vista previa.
struct CardDesignEditorPresentation: Identifiable {
    let id = UUID()
    let account: Account
    /// El saldo (o lo gastado) que enseña la tarjeta del carrusel, para que la vista previa sea la misma tarjeta.
    let balance: Double
    let lines: [AccountCardLogic.LineAmount]
    let isExpensesOnlyMode: Bool
    let periodName: String
    let draft: CardDesignDraft
}

// MARK: - Presentación desde el Panel

/// La hoja del editor, colgada de `PanelShell` como las demás hojas del Panel (`PanelSheetState.cardDesignEditor`).
struct CardDesignEditorSheetModifier: ViewModifier {
    @Binding var item: CardDesignEditorPresentation?

    func body(content: Content) -> some View {
        content.sheet(item: $item) { presentation in
            CardDesignEditorView(presentation: presentation)
        }
    }
}

// MARK: - Editor

struct CardDesignEditorView: View {
    let presentation: CardDesignEditorPresentation

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// El color del selector «Otro color». Solo es el estado del control del sistema: lo elegido se copia al borrador.
    @State private var customColor: Color = .indigo

    private var draft: CardDesignDraft { presentation.draft }
    private var account: Account { presentation.account }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // La vista previa se queda arriba mientras se baja a los controles: se ve el cambio de cada toque. Con texto
                // de accesibilidad la tarjeta crece mucho y va dentro del scroll, para dejarle sitio a los controles.
                if !dynamicTypeSize.isAccessibilitySize {
                    preview
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.md)
                }
                editorScroll
            }
            .navigationTitle(L10n.DisenoTarjeta.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.DisenoTarjeta.cancel) { dismiss() }
                        .accessibilityIdentifier("card_design_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    YalaSaveButton(action: save, accessibilityID: "card_design_save")
                }
            }
            .yalaScreenBackground(.subtle)
        }
        .onChange(of: customColor) { _, newValue in applyCustomColor(newValue) }
        .onChange(of: draft.lastFourText) { _, newValue in filterLastFour(newValue) }
    }

    private var editorScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                if dynamicTypeSize.isAccessibilitySize {
                    preview
                }
                templatesSection
                colorSection
                patternSection
                iconSection
                detailsSection
                resetButton
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.lg)
            .readableColumn()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Vista previa

    private var preview: some View {
        AccountCardView(
            account: account,
            currentBalance: presentation.balance,
            isExpensesOnlyMode: presentation.isExpensesOnlyMode,
            periodName: presentation.periodName,
            lines: presentation.lines,
            designOverride: draft.resolvedDesign
        )
        // La tarjeta se estira hasta el alto que le ofrecen (en el carrusel iguala a la más alta); aquí va a su alto natural,
        // o fija arriba del editor se comía media pantalla.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .dsAnimation(DS.Animation.selection, value: draft.resolvedDesign, reduceMotion: reduceMotion)
        .accessibilityIdentifier("card_design_preview")
    }

    // MARK: Plantillas

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionTitle(L10n.DisenoTarjeta.Section.templates)
            ForEach(CardTemplateCategory.allCases, id: \.self) { category in
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.DisenoTarjeta.category(category))
                        .font(DS.Typography.caption)
                        .foregroundStyle(theme.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.md) {
                            ForEach(CardTemplateCatalog.templates(in: category)) { template in
                                templateThumbnail(template)
                            }
                        }
                        .padding(.vertical, DS.Spacing.xxs)
                    }
                    .scrollClipDisabled()
                }
            }
        }
    }

    private func templateThumbnail(_ template: CardTemplate) -> some View {
        let isSelected = draft.design.templateID == template.id
        var design = draft.design
        design.templateID = template.id
        design.colorHex = nil
        design.pattern = nil
        let look = CardLookLogic.look(
            for: design, type: draft.accountType, accountColorHex: account.colorHex, accountIconName: account.iconName)
        return Button {
            DS.Haptic.selection()
            draft.choose(template: template)
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ZStack(alignment: .topLeading) {
                    CardBackgroundView(look: look, cornerRadius: DS.Radius.md, patternScale: 0.6)
                    if look.showsChip {
                        CardChipView(silver: look.silverChip, width: 16)
                            .padding(DS.Spacing.sm)
                            .padding(.top, DS.Spacing.sm)
                    }
                }
                .frame(width: Self.thumbnailWidth, height: Self.thumbnailWidth * 0.63)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md + 3, style: .continuous)
                        .strokeBorder(isSelected ? theme.accentText : .clear, lineWidth: 2.5)
                        .padding(-3)
                )
                Text(L10n.DisenoTarjeta.template(template.id))
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText)
                    .lineLimit(1)
                    .frame(width: Self.thumbnailWidth, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.DisenoTarjeta.template(template.id))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("card_design_template_\(template.id)")
    }

    static let thumbnailWidth: CGFloat = 112

    // MARK: Color

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionTitle(L10n.DisenoTarjeta.Section.color)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    templateColorSwatch
                    colorSwatch(
                        hex: CardDesignLogic.sanitizedHex(account.colorHex) ?? "#6366F1",
                        label: L10n.DisenoTarjeta.Swatch.account,
                        identifier: "card_design_color_account"
                    )
                    ForEach(Array(CardTemplateCatalog.swatches.enumerated()), id: \.offset) { index, hex in
                        colorSwatch(
                            hex: hex,
                            label: L10n.DisenoTarjeta.Swatch.numbered(index + 1),
                            identifier: "card_design_color_\(index)"
                        )
                    }
                    ColorPicker(L10n.DisenoTarjeta.Swatch.custom, selection: $customColor, supportsOpacity: false)
                        .labelsHidden()
                        .accessibilityLabel(L10n.DisenoTarjeta.Swatch.custom)
                        .accessibilityIdentifier("card_design_color_custom")
                        .frame(width: Self.swatchSize, height: Self.swatchSize)
                }
                .padding(.vertical, DS.Spacing.xxs)
            }
            .scrollClipDisabled()
        }
    }

    /// «El de la plantilla»: vuelve a los colores de la plantilla elegida.
    private var templateColorSwatch: some View {
        let isSelected = draft.design.colorHex == nil
        var design = draft.design
        design.colorHex = nil
        let look = CardLookLogic.look(
            for: design, type: draft.accountType, accountColorHex: account.colorHex, accountIconName: account.iconName)
        return Button {
            DS.Haptic.selection()
            draft.design.colorHex = nil
        } label: {
            Circle()
                .fill(LinearGradient(
                    colors: look.stops.map { Color(card: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: Self.swatchSize, height: Self.swatchSize)
                .overlay(swatchRing(isSelected: isSelected))
                .overlay { if isSelected { swatchCheck(foreground: look.foreground) } }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.DisenoTarjeta.Swatch.template)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("card_design_color_template")
    }

    private func colorSwatch(hex: String, label: String, identifier: String) -> some View {
        let isSelected = draft.design.colorHex == hex
        let rgb = CardRGB(hex: hex) ?? .ink
        return Button {
            DS.Haptic.selection()
            draft.design.colorHex = hex
        } label: {
            Circle()
                .fill(Color(card: rgb))
                .frame(width: Self.swatchSize, height: Self.swatchSize)
                .overlay(swatchRing(isSelected: isSelected))
                .overlay {
                    if isSelected {
                        swatchCheck(foreground: rgb.contrast(with: .white) >= rgb.contrast(with: .ink) ? .white : .ink)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(identifier)
    }

    private func swatchRing(isSelected: Bool) -> some View {
        Circle()
            .strokeBorder(isSelected ? theme.accentText : theme.primaryText.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
            .padding(isSelected ? -4 : 0)
    }

    private func swatchCheck(foreground: CardRGB) -> some View {
        Image(systemName: "checkmark")
            .font(DS.Typography.caption.weight(.bold))
            .foregroundStyle(Color(card: foreground))
            .accessibilityHidden(true)
    }

    static let swatchSize: CGFloat = 36

    // MARK: Patrón

    private var patternSection: some View {
        let current = CardLookLogic.look(
            for: draft.design, type: draft.accountType, accountColorHex: account.colorHex,
            accountIconName: account.iconName)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionTitle(L10n.DisenoTarjeta.Section.pattern)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(CardPattern.allCases, id: \.self) { pattern in
                        patternChip(pattern, base: current)
                    }
                }
                .padding(.vertical, DS.Spacing.xxs)
            }
            .scrollClipDisabled()
        }
    }

    private func patternChip(_ pattern: CardPattern, base: CardLook) -> some View {
        let isSelected = base.pattern == pattern
        let look = CardLook(
            stops: base.stops, foreground: base.foreground, pattern: pattern, finish: base.finish,
            iconName: base.iconName, showsChip: false, silverChip: base.silverChip, lastFour: nil)
        return Button {
            DS.Haptic.selection()
            draft.design.pattern = pattern
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                CardBackgroundView(look: look, cornerRadius: DS.Radius.sm, patternScale: 0.75)
                    .frame(width: 64, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm + 3, style: .continuous)
                            .strokeBorder(isSelected ? theme.accentText : .clear, lineWidth: 2.5)
                            .padding(-3)
                    )
                Text(L10n.DisenoTarjeta.pattern(pattern))
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.DisenoTarjeta.pattern(pattern))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("card_design_pattern_\(pattern.rawValue)")
    }

    // MARK: Ícono

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionTitle(L10n.DisenoTarjeta.Section.icon)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    iconChoice(nil, symbol: account.iconName, label: L10n.DisenoTarjeta.Icon.account,
                               identifier: "card_design_icon_account")
                    ForEach(Array(CardTemplateCatalog.icons.enumerated()), id: \.offset) { index, symbol in
                        iconChoice(symbol, symbol: symbol, label: L10n.DisenoTarjeta.Icon.numbered(index + 1),
                                   identifier: "card_design_icon_\(symbol)")
                    }
                }
                .padding(.vertical, DS.Spacing.xxs)
            }
            .scrollClipDisabled()
        }
    }

    private func iconChoice(_ value: String?, symbol: String, label: String, identifier: String) -> some View {
        let isSelected = draft.design.iconName == value
        return Button {
            DS.Haptic.selection()
            draft.design.iconName = value
        } label: {
            Image(systemName: symbol)
                .font(DS.Typography.body)
                .foregroundStyle(isSelected ? theme.onAccent : theme.primaryText)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(isSelected ? theme.accent : theme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(DS.Colors.borderDark, lineWidth: isSelected ? 0 : 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(identifier)
    }

    // MARK: Chip y dígitos

    @ViewBuilder
    private var detailsSection: some View {
        @Bindable var editing = draft
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionTitle(L10n.DisenoTarjeta.Section.details)
            VStack(alignment: .leading, spacing: 0) {
                Toggle(L10n.DisenoTarjeta.chip, isOn: $editing.design.showsChip)
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.primaryText)
                    .padding(.vertical, DS.Spacing.md)
                    .accessibilityIdentifier("card_design_chip_toggle")
                Divider()
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.DisenoTarjeta.LastFour.title)
                        .font(DS.Typography.body)
                        .foregroundStyle(theme.primaryText)
                    TextField(
                        L10n.DisenoTarjeta.LastFour.title,
                        text: $editing.lastFourText,
                        prompt: Text(L10n.DisenoTarjeta.LastFour.prompt)
                    )
                    .keyboardType(.numberPad)
                    .textContentType(.none)
                    .font(DS.Typography.title3.monospacedDigit())
                    .foregroundStyle(theme.primaryText)
                    .accessibilityLabel(L10n.DisenoTarjeta.LastFour.title)
                    .accessibilityIdentifier("card_design_last_four")
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))
            Text(L10n.DisenoTarjeta.LastFour.footer)
                .font(DS.Typography.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resetButton: some View {
        Button {
            DS.Haptic.selection()
            draft.resetToDefault()
        } label: {
            Text(L10n.DisenoTarjeta.reset)
                .font(DS.Typography.body)
                .foregroundStyle(theme.accentText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("card_design_reset")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.subheadlineEmphasized)
            .foregroundStyle(theme.primaryText)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Acciones

    private func applyCustomColor(_ color: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }
        draft.design.colorHex = CardRGB(red: Double(red), green: Double(green), blue: Double(blue)).hex
    }

    /// Solo números y como mucho 4, mientras se escribe.
    private func filterLastFour(_ value: String) {
        let filtered = CardDesignLogic.typedLastFour(value)
        if filtered != value { draft.lastFourText = filtered }
    }

    private func save() {
        appPreferences.accountCardDesigns = CardDesignLogic.setting(
            draft.resolvedDesign, for: account.shortcutID, type: draft.accountType,
            in: appPreferences.accountCardDesigns)
        DS.Haptic.success()
        dismiss()
    }
}
