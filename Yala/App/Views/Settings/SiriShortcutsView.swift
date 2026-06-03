//
//  SiriShortcutsView.swift
//  Yala
//
//  Created by Yala.
//

import SwiftUI

struct SiriShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var siriIconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric
    @State private var expandedFAQ: SiriShortcutsFAQ?

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "mic.badge.plus")
                            .font(DS.Typography.amountLarge)
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
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .navigationTitle(String(localized: "siriShortcuts.title"))
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
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
                Text(String(localized: "siriShortcuts.siri.title"))
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
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(spacing: DS.Spacing.sm) {
                            Text("\"" + String(localized: "siriShortcuts.siri.phrase") + "\"")
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

                // Alternative phrases
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(String(localized: "siriShortcuts.siri.alt1"))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                    Text(String(localized: "siriShortcuts.siri.alt2"))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                }
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
                    name: String(localized: "siriShortcuts.shortcut.quick"),
                    description: String(localized: "siriShortcuts.desc.quick"),
                    phrase: String(localized: "siriShortcuts.phrase.quick")
                )

                Divider().padding(.horizontal, DS.Spacing.lg)

                shortcutRow(
                    icon: "mic.badge.plus",
                    iconColor: .pink,
                    name: String(localized: "siriShortcuts.shortcut.voice"),
                    description: String(localized: "siriShortcuts.desc.voice"),
                    phrase: String(localized: "siriShortcuts.phrase.voice")
                )

                Divider().padding(.horizontal, DS.Spacing.lg)

                shortcutRow(
                    icon: "photo.badge.plus",
                    iconColor: .teal,
                    name: String(localized: "siriShortcuts.shortcut.image"),
                    description: String(localized: "siriShortcuts.desc.image"),
                    phrase: String(localized: "siriShortcuts.phrase.image")
                )

                Divider().padding(.horizontal, DS.Spacing.lg)

                shortcutRow(
                    icon: "apple.logo",
                    iconColor: .pink,
                    name: String(localized: "siriShortcuts.shortcut.applePay"),
                    description: String(localized: "siriShortcuts.desc.applePay"),
                    phrase: String(localized: "siriShortcuts.phrase.applePay")
                )

                Divider().padding(.horizontal, DS.Spacing.lg)

                shortcutRow(
                    icon: "gearshape.fill",
                    iconColor: .gray,
                    name: String(localized: "siriShortcuts.shortcut.automation"),
                    description: String(localized: "siriShortcuts.desc.automation"),
                    phrase: String(localized: "siriShortcuts.phrase.automation")
                )
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

                Text("\"" + phrase + "\"")
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
