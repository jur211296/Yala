//
//  HomeScreenTutorialPages.swift
//  Yala
//
//  Y23-16 · Las piezas del paso 7 de Primeros pasos (prototipo oficial v35, pestaña 8): cada parte de la página corta
//  con su ilustración y cada mini tutorial con sus pasos. Lo que ya existe se reutiliza tal cual: los pasos y la
//  garantía de la guía de Apple Pay de Tutoriales, las frases de «Siri y Atajos» y el botón que abre los atajos de Yala.
//  Los importes y el recibo son de ejemplo (la ficha: los datos del prototipo son solo para mostrar).
//

import SwiftUI

// MARK: - Una parte de la página corta

struct HomeScreenIntroPart: View {
    let method: HomeScreenTutorialLogic.Method

    private typealias T = L10n.PrimerosPasos23.Home

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HomeScreenMethodTile(method: method)
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.welcomeHeadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            illustration
                .frame(maxWidth: .infinity)
        }
        .padding(.top, DS.Spacing.md)
    }

    private var title: String {
        switch method {
        case .widget: T.widgetPartTitle
        case .applePay: T.applePayPartTitle
        case .share: T.sharePartTitle
        case .siri: T.siriPartTitle
        }
    }

    private var message: String {
        switch method {
        case .widget: T.widgetPartMessage
        case .applePay: T.applePayPartMessage
        case .share: T.sharePartMessage
        case .siri: T.siriPartMessage
        }
    }

    @ViewBuilder
    private var illustration: some View {
        switch method {
        case .widget: HomeScreenWidgetIllustration()
        case .applePay: HomeScreenApplePayIllustration()
        case .share: HomeScreenShareIllustration()
        case .siri: HomeScreenSiriIllustration()
        }
    }
}

// MARK: - Ilustraciones

/// Una pantalla de inicio con iconos de apps y el widget «Nuevo registro».
private struct HomeScreenWidgetIllustration: View {
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 52, height: 52)
                }
            }
            HStack(spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Label {
                        Text(verbatim: "Yala")
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .font(DS.Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(.secondary)
                    Text(L10n.Accessibility.newRecord)
                        .font(DS.Typography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus")
                    .font(DS.Typography.title3.weight(.bold))
                    .foregroundStyle(theme.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.accent))
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: 260)
            .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(theme.card))
        }
        .padding(DS.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.primary.opacity(0.05)))
        .accessibilityHidden(true)
    }
}

/// Un pago de Apple Pay y el aviso de Yala que llega por revisar.
private struct HomeScreenApplePayIllustration: View {
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private var amount: String {
        appPreferences.currency(18.5, currencyCode: appPreferences.defaultCurrencyCode.rawValue)
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(Color.electricIndigo)
                    .frame(width: 56, height: 36)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.PrimerosPasos23.Home.applePayPartPaid(amount))
                        .font(DS.Typography.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: "Apple Pay")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
            HomeScreenExamplePush(text: L10n.PrimerosPasos23.Home.applePayPartPush(amount))
        }
        .accessibilityHidden(true)
    }
}

/// Un aviso de ejemplo de Yala, como una notificación.
private struct HomeScreenExamplePush: View {
    let text: String

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(theme.accent))
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(verbatim: "Yala").font(DS.Typography.subheadline.weight(.semibold))
                Text(text)
                    .font(DS.Typography.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
    }
}

/// La hoja de compartir de iOS con un recibo y Yala entre las apps.
struct HomeScreenShareIllustration: View {
    @Environment(\.yalaTheme) private var theme

    private static let apps: [(name: String, color: Color, isYala: Bool)] = [
        ("messages", .green, false), ("whatsapp", .green, false), ("Yala", .electricIndigo, true),
        ("mail", .blue, false), ("notes", .yellow, false),
    ]

    private var receipt: UIImage? {
        let supported: Set<String> = ["de", "en", "es", "fr", "it", "pt"]
        let lang = LanguageManager.baseLanguageCode(of: Bundle.main.preferredLocalizations.first ?? "en")
        return UIImage(named: "ExampleImages/example-receipt-\(supported.contains(lang) ? lang : "en")")
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            if let receipt {
                Image(uiImage: receipt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
            HStack(spacing: DS.Spacing.md) {
                ForEach(Self.apps, id: \.name) { app in
                    VStack(spacing: DS.Spacing.xxs) {
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(app.color.opacity(app.isYala ? 1 : 0.5))
                            .frame(width: 44, height: 44)
                            .overlay {
                                if app.isYala {
                                    Image(systemName: "sparkles").foregroundStyle(.white)
                                }
                            }
                            .overlay {
                                if app.isYala {
                                    RoundedRectangle(cornerRadius: DS.Radius.sm + 3)
                                        .stroke(theme.accentText, lineWidth: 2)
                                        .padding(-3)
                                }
                            }
                        // Solo el nombre de Yala: los de las demás apps cambian con el idioma de iOS.
                        Text(verbatim: app.isYala ? app.name : " ")
                            .font(DS.Typography.captionSmall.weight(.semibold))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(theme.card))
        .accessibilityHidden(true)
    }
}

/// «Oye Siri, anota un gasto en Yala» y la respuesta.
private struct HomeScreenSiriIllustration: View {
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(AngularGradient(colors: [.purple, .hotPink, .teal, .electricIndigo, .purple], center: .center))
                .frame(width: 56, height: 56)
            Text(L10n.PrimerosPasos23.Home.siriPartAsk)
                .font(DS.Typography.subheadline.weight(.semibold))
                .padding(DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.accent.opacity(0.25)))
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(L10n.PrimerosPasos23.Home.siriPartAnswer)
                .font(DS.Typography.subheadline)
                .padding(DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Un mini tutorial

struct HomeScreenMethodPage: View {
    let method: HomeScreenTutorialLogic.Method
    let onDone: () -> Void
    let onSkip: () -> Void

    private typealias T = L10n.PrimerosPasos23.Home

    @Environment(\.openURL) private var openURL
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    HomeScreenMethodTile(method: method)
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(title)
                            .font(DS.Typography.welcomeHeadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("home_tutorial_method_title")
                        Text(subtitle)
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            footer
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
        }
    }

    /// X para omitir, «2 de 4 · Apple Pay» y «Omitir» (el prototipo). Con texto de accesibilidad «Omitir» se va (la X hace
    /// lo mismo) y el rótulo usa ese sitio; sin él, la X no se lee aparte: serían dos «Omitir» seguidos.
    private var header: some View {
        HStack {
            YalaToolbarButton(systemName: "xmark", label: L10n.PrimerosPasos23.Record.skip, action: onSkip)
                .accessibilityIdentifier("home_tutorial_method_close")
                .accessibilityHidden(!dynamicTypeSize.isAccessibilitySize)
            Spacer()
            Text(T.methodEyebrow(HomeScreenTutorialLogic.position(of: method), HomeScreenTutorialLogic.methods.count,
                                 HomeScreenMethodText.name(method)))
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if dynamicTypeSize.isAccessibilitySize {
                Color.clear.frame(width: 44, height: 44)
            } else {
                Button(L10n.PrimerosPasos23.Record.skip, action: onSkip)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("home_tutorial_method_skip")
            }
        }
    }

    private var title: String {
        switch method {
        case .widget: T.widgetTitle
        case .applePay: L10n.Tutorials.applePayTitle
        case .share: T.shareTitle
        case .siri: T.siriTitle
        }
    }

    private var subtitle: String {
        switch method {
        case .widget: T.widgetSubtitle
        case .applePay: L10n.Tutorials.applePayIntroDesc
        case .share: T.shareSubtitle
        case .siri: T.siriSubtitle
        }
    }

    @ViewBuilder
    private var content: some View {
        switch method {
        case .widget:
            HomeScreenNumberedSteps(steps: [T.widgetStep1, T.widgetStep2, T.widgetStep3, T.widgetStep4])
        case .applePay:
            HomeScreenNumberedSteps(steps: Tutorial.applePay.steps.map { step in
                HomeScreenNumberedSteps.Step(title: step.title, detail: step.description)
            })
            guarantee(L10n.Tutorials.applePayGuarantee)
        case .share:
            HomeScreenShareIllustration()
            HomeScreenNumberedSteps(steps: [T.shareStep1, T.shareStep2, T.shareStep3])
        case .siri:
            HomeScreenSiriPhrases()
        }
    }

    private func guarantee(_ text: String) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(Color.incomeAmount)
        }
        .font(DS.Typography.subheadline)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: DS.Spacing.sm) {
            switch method {
            case .widget:
                doneButton(T.widgetDone)
            case .applePay:
                YalaSecondaryButton(L10n.Tutorials.applePayOpenShortcuts, icon: "arrow.up.forward.app") {
                    if let url = URL(string: "shortcuts://") { openURL(url) }
                }
                .accessibilityIdentifier("home_tutorial_open_shortcuts")
                .primerosPasosButtonText()
                doneButton(T.applePayDone)
            case .share:
                doneButton(L10n.Common.understood)
            case .siri:
                // El botón de Yala se ve; el toque lo recibe el de Apple, encima y transparente (como en «Siri y Atajos»).
                YalaSecondaryButton(L10n.PrimerosPasos23.appText("siriShortcuts.openShortcuts"), icon: "square.on.square") {}
                    .primerosPasosButtonText()
                    .allowsHitTesting(false)
                    .overlay { ShortcutsPageButtonOverlay() }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.PrimerosPasos23.appText("siriShortcuts.openShortcuts"))
                    .accessibilityAddTraits(.isButton)
                doneButton(L10n.Action.done)
            }
        }
    }

    private func doneButton(_ title: String) -> some View {
        YalaPrimaryButton(title, action: onDone)
            .accessibilityIdentifier("home_tutorial_method_done")
            .primerosPasosButtonText()
    }
}

/// Pasos numerados, con su título y, si lo hay, el detalle debajo.
struct HomeScreenNumberedSteps: View {
    struct Step {
        let title: String
        var detail: String?
    }

    let steps: [Step]

    init(steps: [Step]) { self.steps = steps }
    init(steps: [String]) { self.steps = steps.map { Step(title: $0) } }

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Text(verbatim: "\(index + 1)")
                        .font(DS.Typography.subheadline.weight(.bold))
                        .foregroundStyle(theme.onAccent)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(theme.accent))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(step.title)
                            .font(step.detail == nil ? DS.Typography.body : DS.Typography.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail = step.detail {
                            Text(detail)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home_tutorial_step_\(index + 1)")
            }
        }
    }
}

/// Las frases de «Siri y Atajos» que la ficha enseña, con la insignia Pro donde la llevan.
private struct HomeScreenSiriPhrases: View {
    @Environment(\.yalaTheme) private var theme

    private func app(_ key: String) -> String { L10n.PrimerosPasos23.appText(key) }

    private var phrases: [(phrase: String, detail: String, isPro: Bool)] {
        [
            (app("siriShortcuts.siri.phrase"), app("siriShortcuts.siri.description"), true),
            (L10n.PrimerosPasos23.Home.siriNewRecordPhrase, app("siriShortcuts.desc.quick"), false),
            (app("siriShortcuts.phrase.voice"), app("siriShortcuts.desc.voice"), true),
            (app("siriShortcuts.phrase.image"), app("siriShortcuts.desc.image"), true),
            (app("siriShortcuts.phrase.spending"), app("siriShortcuts.desc.spending"), false),
            (app("siriShortcuts.phrase.balance"), app("siriShortcuts.desc.balance"), false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(phrases, id: \.phrase) { item in
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(String(format: app("siriShortcuts.quotedPhrase"), item.phrase))
                            .font(DS.Typography.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if item.isPro { ProBadge(size: .small) }
                    }
                    Text(item.detail)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .accessibilityElement(children: .combine)
            }
        }
    }
}
