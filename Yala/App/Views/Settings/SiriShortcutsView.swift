//
//  SiriShortcutsView.swift
//  Yala
//
//  Created by Yala.
//

import SwiftUI

/// Ajustes › Siri y Atajos. Desde la auditoría UX 2.2 (lote 15, L15-4, opción B variante 1, decisión de Jürgen del
/// 2026-10-18): cada acción se llama como en Atajos —el `shortTitle` de su `AppShortcut`, la misma clave, así que casan
/// en los 16 idiomas por construcción— y al pie hay un botón relleno que abre la página de Yala en Atajos.
struct SiriShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsListIsAlongside) private var settingsListIsAlongside
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var siriIconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric
    @State private var expandedFAQ: SiriShortcutsFAQ?

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "mic.badge.plus")
                            .font(DS.Typography.amountLarge)
                            // A11Y-DM: azul de identidad de Siri (color de sistema, adapta a Dark Mode)
                            .foregroundStyle(.blue)
                            .padding(.bottom, DS.Spacing.sm)
                            .accessibilityHidden(true)

                        Text(String(localized: "siriShortcuts.title"))
                            .font(.title2.bold())
                            .foregroundStyle(.thPrimaryText)

                        Text(String(localized: "siriShortcuts.subtitle"))
                            .font(DS.Typography.body)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // Section 1: Siri (highlighted)
                    siriSection

                    // Section 2: Other shortcuts
                    shortcutsSection

                    // Section 3: FAQ
                    faqSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
        .yalaScreenBackground(.subtle)
        .navigationTitle(String(localized: "siriShortcuts.title"))
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            // Con la lista de Ajustes al lado, la lista es la vuelta (UX 2.2 · L16-20).
            if !settingsListIsAlongside {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Siri Section

    private var siriSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "mic.fill")
                    .font(DS.Typography.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityHidden(true)
                Text(String(localized: "shortcut.siriNatural.shortTitle"))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thSecondaryText)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.md) {
                // Main phrase
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: siriIconSize))
                        // A11Y-DM: azul de identidad de Siri (color de sistema, adapta a Dark Mode)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(spacing: DS.Spacing.sm) {
                            Text(Self.quoted(String(localized: "siriShortcuts.siri.phrase")))
                                .font(DS.Typography.bodyBold)
                                .foregroundStyle(.thPrimaryText)

                            if !isProUser {
                                ProBadge(size: .small)
                            }
                        }

                        Text(String(localized: "siriShortcuts.siri.description"))
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thSecondaryText)
                    }

                    Spacer()
                }
                .padding(DS.Spacing.lg)

                // Pro note
                if !isProUser {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "lock.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.warningForeground)
                            .accessibilityHidden(true)

                        Text(String(localized: "siriShortcuts.siri.proNote"))
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.warningForeground)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.sm)
                }

                Divider()
                    .padding(.horizontal, DS.Spacing.lg)

                // Las otras dos frases, en una línea: «También: «A» · «B»».
                Text(Self.alsoSay)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.md)
            }
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "rectangle.grid.2x2.fill")
                    .font(DS.Typography.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityHidden(true)
                Text(String(localized: "siriShortcuts.all.title"))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thSecondaryText)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                shortcutRow(
                    icon: "sparkles",
                    iconColor: .purple,
                    name: String(localized: "shortcut.quickExpense.shortTitle"),
                    description: String(localized: "siriShortcuts.desc.quick"),
                    phrase: String(localized: "siriShortcuts.phrase.quick")
                )

                Divider().padding(.horizontal, DS.Spacing.lg)

                shortcutRow(
                    icon: "mic.badge.plus",
                    iconColor: .pink,
                    name: String(localized: "shortcut.voiceEntry.shortTitle"),
                    description: String(localized: "siriShortcuts.desc.voice"),
                    phrase: String(localized: "siriShortcuts.phrase.voice")
                )

                Divider().padding(.horizontal, DS.Spacing.lg)

                shortcutRow(
                    icon: "photo.badge.plus",
                    iconColor: .teal,
                    name: String(localized: "shortcut.imageEntry.shortTitle"),
                    description: String(localized: "siriShortcuts.desc.image"),
                    phrase: String(localized: "siriShortcuts.phrase.image")
                )

                Divider().padding(.horizontal, DS.Spacing.lg)

                shortcutRow(
                    icon: "apple.logo",
                    iconColor: .gray,
                    name: String(localized: "shortcut.applePay.shortTitle"),
                    description: String(localized: "siriShortcuts.desc.applePay"),
                    phrase: String(localized: "siriShortcuts.phrase.applePay")
                )

                // Las dos preguntas que Siri contesta sin abrir la app (#552), con el mismo molde (card bthx, opción A de
                // Jürgen del 2026-10-21). Gratis, como los widgets: sin insignia Pro.
                Divider().padding(.horizontal, DS.Spacing.lg)

                shortcutRow(
                    icon: "chart.bar.fill",
                    iconColor: .orange,
                    name: String(localized: "shortcut.spending.shortTitle"),
                    description: String(localized: "siriShortcuts.desc.spending"),
                    phrase: String(localized: "siriShortcuts.phrase.spending")
                )

                Divider().padding(.horizontal, DS.Spacing.lg)

                shortcutRow(
                    icon: "banknote.fill",
                    iconColor: .green,
                    name: String(localized: "shortcut.balance.shortTitle"),
                    description: String(localized: "siriShortcuts.desc.balance"),
                    phrase: String(localized: "siriShortcuts.phrase.balance")
                )
                // Hasta el lote 15 de la auditoría UX 2.2 había una fila «Automatización» con la frase «Registra desde
                // automatización en Yala»: esa acción no existe en `AppShortcutsProvider`. La automatización real es la
                // de Apple Pay, que ya tiene su fila.
            }
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )

            // El botón del pie (L15-4): abre la página de Yala en Atajos, donde están estas acciones.
            // Se ve el botón de Yala; el toque lo recibe el de Apple, encima y transparente (`ShortcutsPageOpener.swift`).
            // Para VoiceOver es un solo botón sin acción propia: al activarlo toca en su centro, donde está el de Apple.
            YalaPrimaryButton(String(localized: "siriShortcuts.openShortcuts"), icon: "square.on.square") {}
                .allowsHitTesting(false)
                .overlay { ShortcutsPageButtonOverlay() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "siriShortcuts.openShortcuts"))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("siri_shortcuts_open_shortcuts")
                .padding(.top, DS.Spacing.md)
        }
    }

    /// Una frase entre las comillas del idioma («…», “…”, „…“, 「…」).
    static func quoted(_ phrase: String) -> String {
        String(format: String(localized: "siriShortcuts.quotedPhrase"), phrase)
    }

    /// «También: «Apunta un gasto en Yala» · «Registra con Siri en Yala»».
    static var alsoSay: String {
        String(format: String(localized: "siriShortcuts.siri.alsoSay"),
               quoted(String(localized: "siriShortcuts.siri.alt1")),
               quoted(String(localized: "siriShortcuts.siri.alt2")))
    }

    @ViewBuilder
    private func shortcutRow(icon: String, iconColor: Color, name: String, description: String, phrase: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline).fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(name)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thPrimaryText)

                Text(description)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)

                Text(Self.quoted(phrase))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText.opacity(0.7))
                    .italic()
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - FAQ Section

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "questionmark.circle.fill")
                    .font(DS.Typography.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityHidden(true)
                Text(String(localized: "siriShortcuts.faq.title"))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thSecondaryText)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(SiriShortcutsFAQ.allCases, id: \.self) { item in
                    faqRow(item: item)

                    if item != SiriShortcutsFAQ.allCases.last {
                        Divider()
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                }
            }
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func faqRow(item: SiriShortcutsFAQ) -> some View {
        Button {
            dsWithAnimation(reduceMotion, .easeInOut(duration: 0.25)) {
                expandedFAQ = expandedFAQ == item ? nil : item
            }
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                HStack(spacing: DS.Spacing.md) {
                    Text(item.question)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: expandedFAQ == item ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.thSecondaryText)
                        .accessibilityHidden(true)
                }

                if expandedFAQ == item {
                    Text(item.answer)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .padding(.top, DS.Spacing.sm)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FAQ Data

enum SiriShortcutsFAQ: CaseIterable {
    case activate
    case inbox
    case offline

    var question: String {
        switch self {
        case .activate: return String(localized: "siriShortcuts.faq.activateQ")
        case .inbox: return String(localized: "siriShortcuts.faq.inboxQ")
        case .offline: return String(localized: "siriShortcuts.faq.offlineQ")
        }
    }

    var answer: String {
        switch self {
        case .activate: return String(localized: "siriShortcuts.faq.activateA")
        case .inbox: return String(localized: "siriShortcuts.faq.inboxA")
        case .offline: return String(localized: "siriShortcuts.faq.offlineA")
        }
    }
}
