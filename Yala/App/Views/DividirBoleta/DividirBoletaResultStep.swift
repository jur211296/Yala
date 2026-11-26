//
//  DividirBoletaResultStep.swift
//  Yala
//
//  El final de «Dividir una boleta»: quién pagó, cuánto le debe cada uno a esa persona, la imagen para compartir (solo
//  resumen o con detalle, en tres diseños) y, en Yala completo, mi parte como gasto o a la Bandeja. «Listo» vive arriba a
//  la derecha, en la barra de la hoja.
//

import SwiftUI

/// En qué quedó mi parte.
enum DividirBoletaRegistration: Equatable {
    case none
    case inInbox
    case registered
    case failed
}

struct DividirBoletaResultStep: View {
    @Bindable var model: DividirBoletaModel
    let allowsRegistering: Bool
    let registration: DividirBoletaRegistration
    let onShare: (UIImage) -> Void
    let onRegister: () -> Void
    let onSendToInbox: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.displayScale) private var displayScale
    @Environment(\.yalaTheme) private var theme

    @State private var preview: UIImage?
    @State private var renderFailed = false
    /// El nombre que se escribe aquí cuando el perfil no tiene uno: la imagen no sale sin él.
    @State private var typedName = ""
    @FocusState private var nameFocused: Bool

    private var summary: DividirBoletaLogic.Summary? { model.summary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if let summary {
                    hero(summary)
                    payerRow
                    peopleList(summary)
                    Text(footerText)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("dividir_boleta_result_footer")
                    imageSection
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xl)
        }
        .accessibilityIdentifier("dividir_boleta_result")
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) { bottomActions }
        .task(id: renderKey) { renderPreview() }
    }

    // MARK: - Cabecera

    private func hero(_ summary: DividirBoletaLogic.Summary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(heroLabel(summary))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
            Text(money(heroCents(summary)))
                .font(DS.Typography.panelHeroAmount)
                .monospacedDigit()
                .foregroundStyle(.thPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("dividir_boleta_hero_amount")
            Text(L10n.DividirBoleta.resultSubtitle(merchantName, money(summary.totalCents)))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dividir_boleta_hero")
    }

    /// Desde mí: «Te deben» si pagué yo, «Le debes a Carla» si pagó Carla.
    private func heroLabel(_ summary: DividirBoletaLogic.Summary) -> String {
        if summary.payerIsMe {
            if summary.debts.isEmpty { return L10n.DividirBoleta.resultNobodyOwes }
            if summary.debts.count == 1, let person = person(summary.debts[0].personID) {
                return L10n.DividirBoleta.resultOneOwesYou(person.name)
            }
            return L10n.DividirBoleta.resultOwedToYou
        }
        return L10n.DividirBoleta.resultYouOwe(model.payer?.name ?? "")
    }

    private func heroCents(_ summary: DividirBoletaLogic.Summary) -> Int {
        summary.payerIsMe ? summary.owedToPayerCents : summary.myShareCents
    }

    // MARK: - Quién pagó

    private var payerRow: some View {
        HStack {
            Text(L10n.DividirBoleta.resultPaidBy)
                .font(DS.Typography.body)
                .foregroundStyle(Color.primary)
            Spacer()
            Picker(L10n.DividirBoleta.resultPaidBy, selection: $model.payerID) {
                ForEach(model.people) { person in
                    Text(displayName(person)).tag(person.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(theme.accentText)
            .accessibilityLabel(L10n.DividirBoleta.resultPaidBy)
            .accessibilityIdentifier("dividir_boleta_payer")
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(minHeight: 50)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(.thCard))
    }

    // MARK: - Personas

    private func peopleList(_ summary: DividirBoletaLogic.Summary) -> some View {
        let shares = model.shareCents
        let breakdown = DividirBoletaLogic.breakdown(model.lines, people: model.people, mode: model.mode)
        return VStack(spacing: DS.Spacing.none) {
            ForEach(Array(model.people.enumerated()), id: \.element.id) { index, person in
                let cents = shares[person.id] ?? 0
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    DividirBoletaAvatar(person: person, index: index)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(person.isMe ? L10n.DividirBoleta.resultYourPart : person.name)
                                .font(DS.Typography.bodyBold)
                                .foregroundStyle(Color.primary)
                            if person.id == summary.payerID {
                                Text(L10n.DividirBoleta.resultPaidLabel)
                                    .font(DS.Typography.badgeLabel)
                                    .foregroundStyle(theme.accentText)
                                    .padding(.horizontal, DS.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(theme.accent.opacity(0.14)))
                            }
                        }
                        let items = (breakdown[person.id] ?? []).map(\.description)
                        if !items.isEmpty {
                            Text(items.joined(separator: " · "))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: DS.Spacing.sm)
                    Text(money(cents))
                        .font(DS.Typography.bodyBold)
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(person.isMe ? theme.accent.opacity(0.10) : Color.clear)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("dividir_boleta_result_\(person.isMe ? "me" : person.name)")
                if index < model.people.count - 1 {
                    Divider().padding(.leading, DS.Spacing.md)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(.thCard))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private var footerText: String {
        guard allowsRegistering else { return L10n.DividirBoleta.resultFooterGroupsOnly }
        if let payer = model.payer, !payer.isMe { return L10n.DividirBoleta.resultFooterPaidByOther(payer.name) }
        return L10n.DividirBoleta.resultFooterPaidByMe
    }

    // MARK: - Imagen

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.DividirBoleta.imageSection)
                .font(DS.Typography.title3)
                .foregroundStyle(.thPrimaryText)
                .accessibilityAddTraits(.isHeader)
            if profileName == nil {
                nameField
            }
            Picker(L10n.DividirBoleta.imageKindLabel, selection: $model.imageKind) {
                Text(L10n.DividirBoleta.imageSummary).tag(DividirBoletaImageKind.summary)
                Text(L10n.DividirBoleta.imageDetailed).tag(DividirBoletaImageKind.detailed)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(L10n.DividirBoleta.imageKindLabel)
            .accessibilityIdentifier("dividir_boleta_image_kind")

            HStack(spacing: DS.Spacing.sm) {
                ForEach(DividirBoletaImageStyle.allCases, id: \.self) { style in
                    styleChip(style)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.DividirBoleta.imageStyleLabel)

            Group {
                if meNameForImage == nil {
                    EmptyView()
                } else if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .stroke(.thCardBorder, lineWidth: 1)
                        )
                        .shadow(color: DS.Shadow.small.color, radius: DS.Shadow.small.radius, x: DS.Shadow.small.x, y: DS.Shadow.small.y)
                        .accessibilityLabel(L10n.DividirBoleta.imagePreview)
                        .accessibilityValue(previewAccessibilityValue)
                        .accessibilityIdentifier("dividir_boleta_image_preview")
                } else if renderFailed {
                    Text(L10n.DividirBoleta.imageRenderFailed)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func styleChip(_ style: DividirBoletaImageStyle) -> some View {
        let selected = model.imageStyle == style
        return Button {
            DS.Haptic.selection()
            model.imageStyle = style
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(Color(hex: Self.swatch(style)))
                    .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                    .frame(width: 14, height: 14) // A11Y-DT: muestra de color del diseño
                    .accessibilityHidden(true)
                Text(Self.title(style))
                    .font(DS.Typography.subheadline)
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? theme.onAccent : Color.primary)
            .padding(.horizontal, DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Capsule().fill(selected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thCard)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("dividir_boleta_style_\(style.rawValue)")
    }

    static func title(_ style: DividirBoletaImageStyle) -> String {
        switch style {
        case .light: L10n.DividirBoleta.imageStyleLight
        case .brand: L10n.DividirBoleta.imageStyleBrand
        case .receipt: L10n.DividirBoleta.imageStyleReceipt
        }
    }

    static func swatch(_ style: DividirBoletaImageStyle) -> String {
        switch style {
        case .light: DividirBoletaPalette.lightBackground
        case .brand: DividirBoletaPalette.indigo
        case .receipt: DividirBoletaPalette.paper
        }
    }

    /// Sin nombre en el perfil, se pide aquí una vez: la imagen va a otras personas y no puede decir «Yo»
    /// (Jürgen, 26-nov-2026). Se guarda en el perfil al confirmarlo o al compartir.
    private var nameField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.DividirBoleta.imageNameLabel)
                .font(DS.Typography.label)
                .foregroundStyle(.thPrimaryText)
            TextField(L10n.DividirBoleta.imageNamePlaceholder, text: $typedName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit(saveTypedName)
                .padding(.horizontal, DS.Spacing.md)
                .frame(minHeight: 44)
                .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .accessibilityIdentifier("dividir_boleta_my_name")
            Text(L10n.DividirBoleta.imageNameFooter)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func saveTypedName() {
        let name = typedName.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty else { return }
        appPreferences.userName = String(name.prefix(DividirBoletaLogic.maxNameLength))
    }

    // MARK: - Abajo

    private var bottomActions: some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaPrimaryButton(L10n.DividirBoleta.imageShare, icon: "square.and.arrow.up", isDisabled: preview == nil) {
                nameFocused = false
                saveTypedName()
                guard let image = renderImage(scale: min(max(displayScale, 2), 3)) else { return }
                onShare(image)
            }
            .accessibilityIdentifier("dividir_boleta_share")

            if allowsRegistering, let summary, summary.myShareCents > 0 {
                registrationActions(summary)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.sm)
    }

    @ViewBuilder
    private func registrationActions(_ summary: DividirBoletaLogic.Summary) -> some View {
        switch registration {
        case .none, .failed:
            YalaSecondaryButton(L10n.DividirBoleta.registerButton(money(summary.myShareCents)), icon: "plus.circle") {
                onRegister()
            }
            .accessibilityIdentifier("dividir_boleta_register")
            Button(L10n.DividirBoleta.registerInbox, action: onSendToInbox)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(theme.accentText)
                .frame(minHeight: 36)
                .accessibilityIdentifier("dividir_boleta_send_inbox")
            if registration == .failed {
                Text(L10n.DividirBoleta.registerFailed)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Semantic.warningForeground)
            }
        case .inInbox, .registered:
            Label(
                registration == .registered ? L10n.DividirBoleta.registerDone : L10n.DividirBoleta.registerInInbox,
                systemImage: "checkmark.circle.fill"
            )
            .font(DS.Typography.subheadlineEmphasized)
            .foregroundStyle(theme.accentText)
            .frame(minHeight: 36)
            .accessibilityIdentifier("dividir_boleta_registration_status")
        }
    }

    // MARK: - Render

    /// Lo que cambia la imagen: si cambia, se vuelve a pintar la vista previa.
    private var renderKey: String {
        [model.imageKind.rawValue, model.imageStyle.rawValue, model.payerID, model.mode.rawValue, meNameForImage ?? "",
         "\(model.shareCents.sorted { $0.key < $1.key })", model.people.map(\.name).joined(separator: "|")]
            .joined(separator: "#")
    }

    private func renderPreview() {
        preview = renderImage(scale: min(displayScale, 2))
        renderFailed = preview == nil
    }

    private func renderImage(scale: CGFloat) -> UIImage? {
        guard let content = imageContent else { return nil }
        let renderer = ImageRenderer(content: DividirBoletaShareCard(content: content, style: model.imageStyle))
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        // Como el resumen de grupo: se pierde nitidez antes que filas si la imagen sale muy alta.
        renderer.scale = height > 0 ? min(scale, max(1, 8_000 / height)) : scale
        guard let image = renderer.uiImage, image.size.width > 0, image.size.height > 0 else { return nil }
        return image
    }

    var imageContent: DividirBoletaImageContent? {
        guard let meName = meNameForImage else { return nil }
        return DividirBoletaImageBuilder.make(
            kind: model.imageKind,
            merchant: merchantName,
            dateText: Date.now.formatted(.dateTime.day().month(.abbreviated).year().locale(LanguageManager.resolved.locale)),
            lines: model.lines,
            people: model.people,
            mode: model.mode,
            payerID: model.payerID,
            texts: DividirBoletaFlowTexts.image(meName: meName),
            money: money
        )
    }

    private var previewAccessibilityValue: String {
        guard let content = imageContent else { return "" }
        let rows = content.rows.map { "\($0.name) \($0.amount)" }.joined(separator: ", ")
        return "\(content.headline) \(content.headlineAmount). \(rows)"
    }

    /// El nombre del perfil, si lo hay. «Usuario» es el valor por defecto de `AppPreferences.userName`: no es un nombre.
    private var profileName: String? {
        let name = appPreferences.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name == "Usuario" ? nil : name
    }

    /// Con qué nombre sale quien manda la imagen: el del perfil o el que se está escribiendo. `nil` sin ninguno.
    private var meNameForImage: String? {
        if let profileName { return profileName }
        let typed = typedName.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return typed.isEmpty ? nil : String(typed.prefix(DividirBoletaLogic.maxNameLength))
    }

    private var merchantName: String { model.merchant ?? L10n.DividirBoleta.resultMerchantFallback }

    // MARK: - Formato

    private func person(_ id: String) -> DividirBoletaPerson? { model.people.first { $0.id == id } }

    private func displayName(_ person: DividirBoletaPerson) -> String {
        person.isMe ? L10n.DividirBoleta.whoMe : person.name
    }

    private func money(_ cents: Int) -> String {
        appPreferences.currency(Double(cents) / 100, currencyCode: model.effectiveCurrency, forceFullPrecision: true)
    }
}

/// Los textos de la imagen, con el idioma de la app.
enum DividirBoletaFlowTexts {
    static func image(meName: String) -> DividirBoletaImageBuilder.Texts {
        let raw: (String) -> String = { L10n.DividirBoleta.string("dividirBoleta.\($0)") }
        let locale = LanguageManager.resolved.locale
        return DividirBoletaImageBuilder.Texts(
            owedToOther: raw("image.owedToOther"),
            oneOwesOther: raw("image.oneOwesOther"),
            paidByTotal: raw("image.paidByTotal"),
            meName: meName,
            payerPart: raw("image.payerPart"),
            everyone: raw("image.everyone"),
            sharedBy: raw("image.sharedBy"),
            footerTitle: raw("image.footerTitle"),
            footerSubtitle: raw("image.footerSubtitle"),
            joinNames: { $0.formatted(.list(type: .and).locale(locale)) }
        )
    }
}
