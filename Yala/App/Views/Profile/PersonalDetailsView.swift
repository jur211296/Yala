//
//  PersonalDetailsView.swift
//  Yala
//
//  Created by Yala Refactoring.
//
//  «Detalles personales», rediseñada el 2026-11-18 (encargo «perfil con personalización de verdad», variante A): arriba la
//  tarjeta de perfil con la vista previa en vivo y, debajo, el nombre, qué lleva el avatar (símbolo, emoji, iniciales o
//  foto), su color y el fondo de la tarjeta, con las plantillas de las tarjetas de cuentas. «Dónde viven tus datos» va al
//  final, más pequeño.
//
//  Se guarda al cerrar («Listo» o deslizando), como el nombre: el símbolo en `userProfileIcon` y lo demás en
//  `userProfileStyle` (`ProfileStyleLogic`). La foto sigue en su archivo local.
//

import PhotosUI
import SwiftUI
import UIKit

/// Qué pestaña del avatar se ve. La foto no es un tipo guardado: si hay foto, manda.
enum ProfileAvatarTab: String, CaseIterable, Identifiable {
    case symbol
    case emoji
    case initials
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .symbol: return L10n.PerfilPersonalizacion.kindSymbol
        case .emoji: return L10n.PerfilPersonalizacion.kindEmoji
        case .initials: return L10n.PerfilPersonalizacion.kindInitials
        case .photo: return L10n.PerfilPersonalizacion.kindPhoto
        }
    }

    init(kind: ProfileAvatarKind) {
        switch kind {
        case .symbol: self = .symbol
        case .emoji: self = .emoji
        case .initials: self = .initials
        }
    }
}

/// View for editing personal user details
struct PersonalDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppPreferences.self) private var appPreferences

    @State private var editedName: String = ""
    @State private var editedAlias: String = ""
    @State private var isAliasValid: Bool = true
    /// Hasta que `onAppear` carga lo guardado, los campos están vacíos: guardar antes borraría el nombre.
    @State private var didLoadValues = false
    /// «Más sobre tus datos» abre la política de privacidad dentro de Yala (UX 2.2 · L16-2, con el molde de L16-19).
    @State private var webPage: InAppWebPage?

    private let maxNameLength = 30

    // Personalización (se guarda al cerrar)
    @State private var style: ProfileStyle = .standard
    @State private var symbol: String = ""
    @State private var selectedTab: ProfileAvatarTab = .symbol
    /// El color del selector «Otro color». Solo es el estado del control: lo elegido se copia al estilo.
    @State private var customColor: Color = .indigo

    // Foto
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileUIImage: UIImage?
    @State private var showPhotoPicker = false
    /// La foto cambió (elegida o quitada) en esta visita: solo entonces se reescribe el archivo.
    @State private var photoChanged = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    profileCard
                    nameSection
                    avatarSection
                    colorSection
                    cardSection
                    resetButton
                    privacyDisclaimer
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxxl)
                .readableColumn()
                // El gesto que baja el teclado va DETRÁS del contenido: colgado del contenido se quedaría los toques de
                // las rejillas.
                .background { Color.clear.dismissKeyboardOnTap() }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.Profile.personalDetails)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.subtle)
            // UX 2.2 · L16-2: «Listo» arriba a la derecha, que es como se cierra una hoja que guarda.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    YalaToolbarTextButton(L10n.Action.done) {
                        saveAndDismiss()
                    }
                    .accessibilityIdentifier("personal_details_done")
                }
            }
            .inAppSafari($webPage)
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onAppear {
                loadCurrentValues()
            }
            // Cerrar la hoja deslizando hacia abajo NO pasa por «Listo»: sin esto, lo cambiado se perdía sin aviso
            // (auditoría UX 2.2, lote 16). `persistChanges` es idempotente.
            .onDisappear {
                persistChanges()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadPickedPhoto(newItem)
            }
            .onChange(of: editedName) { _, newValue in
                if newValue.count > maxNameLength {
                    editedName = String(newValue.prefix(maxNameLength))
                }
            }
            .onChange(of: editedAlias) { _, newValue in
                validateAlias(newValue)
            }
            .onChange(of: customColor) { _, newValue in
                applyCustomColor(newValue)
            }
        }
    }

    // MARK: - Lo que se ve

    private var displayName: String {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.Profile.defaultName : trimmed
    }

    private var avatarContent: ProfileAvatarContent {
        ProfileStyleLogic.content(style: style, symbol: symbol, name: displayName, defaultName: L10n.Profile.defaultName)
    }

    private var appearance: ProfileAvatarAppearance {
        ProfileAvatarAppearance(photo: profileUIImage, content: avatarContent, colorHex: style.avatarColorHex)
    }

    private var cardLook: CardLook {
        ProfileStyleLogic.cardLook(style: style, themeAccentHex: themeAccentHex)
    }

    /// El color de acento del tema en «#RRGGBB», para teñir la tarjeta en «Tu color» sin color de avatar.
    private var themeAccentHex: String {
        ProfileCardThemeColor.accentHex(theme.accent, colorScheme: colorScheme)
    }

    private var showsPro: Bool {
        FeatureGateService.shared.isProUser && !SessionState.shared.isGroupsFocusedShell
    }

    // MARK: - Tarjeta

    private var profileCard: some View {
        ProfileCardView(look: cardLook, name: displayName, showsPro: showsPro, identifier: "profile_card") {
            Menu {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(profileUIImage == nil ? L10n.PerfilPersonalizacion.photoChoose
                          : L10n.PerfilPersonalizacion.photoChange, systemImage: "photo")
                }
                if profileUIImage != nil {
                    Button(role: .destructive) {
                        removePhoto()
                    } label: {
                        Label(L10n.PerfilPersonalizacion.photoRemove, systemImage: "trash")
                    }
                }
            } label: {
                cardAvatar
            }
            .accessibilityLabel(L10n.PerfilPersonalizacion.avatarMenu)
            .accessibilityIdentifier("profile_card_avatar")
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    private var cardAvatar: some View {
        ProfileCardAvatar(appearance: appearance, look: cardLook, showsCameraBadge: true)
    }

    // MARK: - Nombre

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // A tamaños de accesibilidad el rótulo va encima del campo: en la misma fila se partía («Nom-bre») y el nombre
            // salía cortado.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(L10n.Common.name)
                            .font(DS.Typography.caption)
                            .foregroundStyle(theme.secondaryText)
                        nameField
                    }
                } else {
                    HStack {
                        Text(L10n.Common.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        nameField
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))

            if !editedName.isEmpty {
                Text("\(editedName.count)/\(maxNameLength) \(L10n.Profile.characters)")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(editedName.count >= maxNameLength ? .orange : .secondary)
                    .padding(.horizontal, DS.Spacing.sm)
            }
        }
    }

    private var nameField: some View {
        TextField(L10n.Profile.yourName, text: $editedName)
            .accessibilityIdentifier("personal_details_name_field")
            .foregroundStyle(.primary)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionTitle(L10n.PerfilPersonalizacion.avatarSection)
            tabChips
            switch selectedTab {
            case .symbol: symbolGrid
            case .emoji: emojiGrid
            case .initials: initialsChoice
            case .photo: photoChoice
            }
        }
    }

    /// Los cuatro tipos en cápsulas que se desplazan a lo ancho: con letra grande no se cortan ni se apilan.
    private var tabChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(ProfileAvatarTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button {
                        DS.Haptic.selection()
                        selectedTab = tab
                    } label: {
                        Text(tab.title)
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(isSelected ? theme.onAccent : theme.primaryText)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(Capsule().fill(isSelected ? theme.accent : theme.card))
                            .overlay(Capsule().strokeBorder(DS.Colors.borderDark, lineWidth: isSelected ? 0 : 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    .accessibilityIdentifier("profile_tab_\(tab.rawValue)")
                }
            }
            .padding(.vertical, DS.Spacing.xxs)
        }
        .scrollClipDisabled()
        .accessibilityLabel(L10n.PerfilPersonalizacion.kindPicker)
    }

    /// Tres filas que se desplazan a lo ancho, como los colores y los fondos: las 36 opciones caben sin empujar el resto
    /// de la pantalla seis filas hacia abajo.
    private let gridRows = Array(repeating: GridItem(.fixed(Self.tileSize), spacing: DS.Spacing.sm), count: 3)

    static let tileSize: CGFloat = 54

    private func tileStrip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: gridRows, spacing: DS.Spacing.sm) {
                content()
            }
            .padding(.vertical, DS.Spacing.xxs)
        }
        .scrollClipDisabled()
    }

    private var symbolGrid: some View {
        tileStrip {
            ForEach(Array(ProfileStyleLogic.symbols.enumerated()), id: \.element) { index, name in
                let isSelected = profileUIImage == nil && style.kind == .symbol
                    && (symbol.isEmpty ? ProfileStyleLogic.defaultSymbol : symbol) == name
                choiceTile(isSelected: isSelected, label: symbolLabel(index: index, name: name),
                           identifier: "profile_symbol_\(name)") {
                    Image(systemName: name)
                        .font(DS.Typography.title3)
                        .foregroundStyle(isSelected ? theme.onAccent : theme.primaryText)
                } action: {
                    chooseSymbol(name)
                }
            }
        }
    }

    /// Los doce de antes conservan su nombre para VoiceOver; los nuevos van numerados, como los íconos del editor de
    /// tarjetas.
    private func symbolLabel(index: Int, name: String) -> String {
        switch name {
        case "person.fill": return L10n.Profile.iconPerson
        case "face.smiling.fill": return L10n.Profile.iconSmiley
        case "star.fill": return L10n.Profile.iconStar
        case "heart.fill": return L10n.Profile.iconHeart
        case "bolt.fill": return L10n.Profile.iconBolt
        case "crown.fill": return L10n.Profile.iconCrown
        case "leaf.fill": return L10n.Profile.iconLeaf
        case "flame.fill": return L10n.Profile.iconFlame
        case "moon.fill": return L10n.Profile.iconMoon
        case "sun.max.fill": return L10n.Profile.iconSun
        case "cloud.fill": return L10n.Profile.iconCloud
        case "drop.fill": return L10n.Profile.iconDrop
        default: return L10n.PerfilPersonalizacion.symbolNumbered(index + 1)
        }
    }

    private var emojiGrid: some View {
        tileStrip {
            ForEach(Array(ProfileStyleLogic.emojis.enumerated()), id: \.offset) { index, emoji in
                let isSelected = profileUIImage == nil && style.kind == .emoji && style.emoji == emoji
                choiceTile(isSelected: isSelected, label: emoji, identifier: "profile_emoji_\(index)") {
                    Text(verbatim: emoji)
                        .font(DS.Typography.title2)
                } action: {
                    chooseEmoji(emoji)
                }
            }
        }
    }

    @ViewBuilder
    private var initialsChoice: some View {
        let letters = ProfileStyleLogic.initials(from: editedName, defaultName: L10n.Profile.defaultName)
        if letters.isEmpty {
            Text(L10n.PerfilPersonalizacion.initialsNeedName)
                .font(DS.Typography.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("profile_initials_need_name")
        } else {
            let isSelected = profileUIImage == nil && style.kind == .initials
            HStack(spacing: DS.Spacing.md) {
                choiceTile(isSelected: isSelected, label: letters, identifier: "profile_initials_choice") {
                    Text(verbatim: letters)
                        .font(DS.Typography.title3.weight(.bold))
                        .foregroundStyle(isSelected ? theme.onAccent : theme.primaryText)
                } action: {
                    chooseInitials()
                }
                Text(L10n.PerfilPersonalizacion.initialsDetail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var photoChoice: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Un solo botón por fila: «Quitar» va a su lado como ícono, nunca debajo.
            HStack(spacing: DS.Spacing.sm) {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(profileUIImage == nil ? L10n.PerfilPersonalizacion.photoChoose
                          : L10n.PerfilPersonalizacion.photoChange, systemImage: "photo")
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(theme.accentText)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile_photo_choose")

                if profileUIImage != nil {
                    Button(role: .destructive) {
                        removePhoto()
                    } label: {
                        Image(systemName: "trash")
                            .font(DS.Typography.body.weight(.semibold))
                            .foregroundStyle(DS.Semantic.errorForeground)
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.PerfilPersonalizacion.photoRemove)
                    .accessibilityIdentifier("profile_photo_remove")
                }
            }
            Text(L10n.PerfilPersonalizacion.photoDetail)
                .font(DS.Typography.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func choiceTile<Glyph: View>(
        isSelected: Bool, label: String, identifier: String,
        @ViewBuilder glyph: () -> Glyph, action: @escaping () -> Void
    ) -> some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            glyph()
                // La casilla mide lo mismo con cualquier tamaño de texto (la etiqueta de VoiceOver lo dice todo): a
                // tamaños de accesibilidad el glifo la desbordaba.
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .frame(width: Self.tileSize, height: Self.tileSize)
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

    // MARK: - Color del avatar

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionTitle(L10n.PerfilPersonalizacion.colorSection)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    themeColorSwatch
                    ForEach(Array(ProfileStyleLogic.avatarColors.enumerated()), id: \.offset) { index, hex in
                        colorSwatch(hex: hex, index: index)
                    }
                    ColorPicker(L10n.PerfilPersonalizacion.colorCustom, selection: $customColor, supportsOpacity: false)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PerfilPersonalizacion.colorCustom)
                        .accessibilityIdentifier("profile_color_custom")
                        .frame(width: Self.swatchSize, height: Self.swatchSize)
                }
                .padding(.vertical, DS.Spacing.xs)
                .padding(.horizontal, DS.Spacing.xxs)
            }
            .scrollClipDisabled()
        }
    }

    /// «Del tema»: el relleno de siempre, en el color de acento.
    private var themeColorSwatch: some View {
        let isSelected = style.avatarColorHex == nil
        return Button {
            DS.Haptic.selection()
            style.avatarColorHex = nil
        } label: {
            Circle()
                .fill(theme.accent)
                .frame(width: Self.swatchSize, height: Self.swatchSize)
                .overlay {
                    Image(systemName: isSelected ? "checkmark" : "paintbrush.fill")
                        .font(DS.Typography.caption.weight(.bold))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .foregroundStyle(theme.onAccent)
                        .accessibilityHidden(true)
                }
                .overlay(swatchRing(isSelected: isSelected))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.PerfilPersonalizacion.colorTheme)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("profile_color_theme")
    }

    private func colorSwatch(hex: String, index: Int) -> some View {
        let isSelected = style.avatarColorHex == hex
        let rgb = CardRGB(hex: hex) ?? .ink
        return Button {
            DS.Haptic.selection()
            style.avatarColorHex = hex
        } label: {
            Circle()
                .fill(Color(card: rgb))
                .frame(width: Self.swatchSize, height: Self.swatchSize)
                .overlay(swatchRing(isSelected: isSelected))
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(DS.Typography.caption.weight(.bold))
                            .foregroundStyle(Color(card: ProfileStyleLogic.foreground(onFill: hex)))
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.PerfilPersonalizacion.colorNumbered(index + 1))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("profile_color_\(index)")
    }

    private func swatchRing(isSelected: Bool) -> some View {
        Circle()
            .strokeBorder(isSelected ? theme.accentText : theme.primaryText.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
            .padding(isSelected ? -4 : 0)
    }

    static let swatchSize: CGFloat = 36

    // MARK: - Fondo de la tarjeta

    private var cardSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionTitle(L10n.PerfilPersonalizacion.cardSection)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(CardTemplateCatalog.all) { template in
                        templateThumbnail(template)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
                .padding(.horizontal, DS.Spacing.xxs)
            }
            .scrollClipDisabled()
        }
    }

    private func templateThumbnail(_ template: CardTemplate) -> some View {
        let current = style.cardTemplateID ?? CardTemplateCatalog.accountColorID
        let isSelected = current == template.id
        var preview = style
        preview.cardTemplateID = template.id
        let look = ProfileStyleLogic.cardLook(style: preview, themeAccentHex: themeAccentHex)
        return Button {
            DS.Haptic.selection()
            style.cardTemplateID = template.id == CardTemplateCatalog.accountColorID ? nil : template.id
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                CardBackgroundView(look: look, cornerRadius: DS.Radius.md, patternScale: 0.6)
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
                    .minimumScaleFactor(0.8)
                    // El rótulo va debajo de una miniatura de ancho fijo: más grande se partía en sílabas («Au-rora»).
                    // VoiceOver lee el nombre entero en la etiqueta del botón.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(width: Self.thumbnailWidth, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.DisenoTarjeta.template(template.id))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("profile_card_template_\(template.id)")
    }

    static let thumbnailWidth: CGFloat = 104

    // MARK: - Volver al de siempre

    @ViewBuilder
    private var resetButton: some View {
        if style != .standard || profileUIImage != nil || !(symbol.isEmpty || symbol == ProfileStyleLogic.defaultSymbol) {
            Button {
                DS.Haptic.selection()
                resetToStandard()
            } label: {
                Text(L10n.PerfilPersonalizacion.reset)
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.accentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile_reset")
        }
    }

    // MARK: - Dónde viven tus datos

    /// UX 2.2 · L16-2: dos líneas y «Más sobre tus datos». Desde el rediseño del perfil va al final y en pequeño: es
    /// información, no lo que se viene a hacer aquí.
    private var privacyDisclaimer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Profile.privacyTitle)
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            Text(L10n.UXL15.personalDataNote)
                .font(DS.Typography.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(L10n.UXL15.moreAboutYourData) {
                webPage = InAppWebPage(url: AppConstants.privacyURL)
            }
            .font(DS.Typography.caption.weight(.semibold))
            .foregroundStyle(theme.accentText)
            .accessibilityIdentifier("personal_details_more_about_data")
        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.subheadlineEmphasized)
            .foregroundStyle(theme.primaryText)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Acciones

    private func chooseSymbol(_ name: String) {
        dsWithAnimation(reduceMotion, DS.Animation.selection) {
            symbol = name
            style.kind = .symbol
            clearPhotoIfAny()
        }
    }

    private func chooseEmoji(_ emoji: String) {
        dsWithAnimation(reduceMotion, DS.Animation.selection) {
            style.kind = .emoji
            style.emoji = emoji
            clearPhotoIfAny()
        }
    }

    private func chooseInitials() {
        dsWithAnimation(reduceMotion, DS.Animation.selection) {
            style.kind = .initials
            clearPhotoIfAny()
        }
    }

    /// Elegir otro avatar quita la foto, como antes elegir un icono.
    private func clearPhotoIfAny() {
        guard profileUIImage != nil else { return }
        profileUIImage = nil
        photoChanged = true
    }

    private func removePhoto() {
        profileUIImage = nil
        selectedPhotoItem = nil
        photoChanged = true
        if selectedTab == .photo {
            selectedTab = ProfileAvatarTab(kind: style.kind)
        }
    }

    private func resetToStandard() {
        style = .standard
        // El símbolo de serie escrito, no vacío: `userProfileIcon` no sincroniza un vacío, y así vuelve en todos los
        // dispositivos.
        symbol = symbol.isEmpty ? "" : ProfileStyleLogic.defaultSymbol
        if profileUIImage != nil {
            profileUIImage = nil
            photoChanged = true
        }
        selectedTab = .symbol
    }

    private func applyCustomColor(_ color: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }
        style.avatarColorHex = CardRGB(red: Double(red), green: Double(green), blue: Double(blue)).hex
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            // Reducida al entrar al tamaño con que se guarda: a tamaño completo, una foto de 48 MP ocupaba ~185 MB
            // mientras se veía en esta pantalla (YALA-IOS-B, 2026-11-12).
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                    let uiImage = PhotoIntake.image(from: data, maxEdge: ProfileImageStorage.maxPixelSize)
                {
                    profileUIImage = uiImage
                    photoChanged = true
                    selectedTab = .photo
                }
            } catch {
                #if DEBUG
                print("PersonalDetailsView: Error loading picked photo: \(error)")
                #endif
            }
        }
    }

    // MARK: - Cargar y guardar

    private func loadCurrentValues() {
        didLoadValues = true
        // UX 2.2 · L16-2: el nombre de serie («Usuario») no se escribe en el campo: el campo sale vacío con la pista «Tu
        // nombre» y la persona escribe sin borrar nada. Si lo deja vacío, se guarda el de serie, como antes.
        editedName = PersonalNameFieldLogic.fieldValue(stored: appPreferences.userName, defaultName: L10n.Profile.defaultName)
        editedAlias = appPreferences.userAlias
        symbol = appPreferences.userProfileIcon
        style = ProfileStyleLogic.decode(appPreferences.userProfileStyle)

        ProfileImageStorage.shared.migrateFromUserDefaultsIfNeeded()
        // La foto YA GUARDADA, que `ProfileImageStorage` reduce a 512 px al guardar (lo fija `PhotoIntakeTests`).
        if let imageData = ProfileImageStorage.shared.imageData, let uiImage = UIImage(data: imageData) {
            profileUIImage = uiImage
        } else {
            profileUIImage = nil
        }
        photoChanged = false
        selectedTab = profileUIImage != nil ? .photo : ProfileAvatarTab(kind: style.kind)
    }

    private func validateAlias(_ alias: String) {
        let lowercased = alias.lowercased()
        if lowercased != alias {
            editedAlias = lowercased
            return
        }
        guard alias.count >= 3, alias.count <= 20 else {
            isAliasValid = false
            return
        }
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        isAliasValid = alias.rangeOfCharacter(from: allowedCharacters.inverted) == nil
    }

    private func saveAndDismiss() {
        persistChanges()
        // «Listo» guarda (preferencias locales, no falla): éxito (card C4). El cierre deslizando guarda sin vibrar.
        DS.Haptic.success()
        dismiss()
    }

    /// Guarda nombre, alias, avatar y tarjeta. Lo llaman «Listo» y el cierre deslizando (`onDisappear`).
    private func persistChanges() {
        guard didLoadValues else { return }
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        appPreferences.userName = trimmedName.isEmpty ? L10n.Profile.defaultName : trimmedName

        if isAliasValid || editedAlias.isEmpty {
            appPreferences.userAlias = editedAlias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        appPreferences.userProfileIcon = symbol
        appPreferences.userProfileStyle = ProfileStyleLogic.encode(style)

        guard photoChanged else { return }
        if let uiImage = profileUIImage {
            // 0,85: la foto ya entra a 512 px y `ProfileImageStorage` la guarda tal cual.
            if let imageData = uiImage.jpegData(compressionQuality: 0.85) {
                ProfileImageStorage.shared.save(imageData)
            }
        } else {
            ProfileImageStorage.shared.delete()
        }
        photoChanged = false
    }
}

#Preview {
    PersonalDetailsView()
        .previewAppPreferences()
}
