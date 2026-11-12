//
//  FAQView.swift
//  Yala
//
//  Created by Yala.
//

import SwiftUI

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsListIsAlongside) private var settingsListIsAlongside
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedItem: FAQItem?
    /// «¿No está tu pregunta? Escríbenos» abre el formulario de soporte (UX 2.2 · L16-17).
    @State private var showSupport = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(DS.Typography.amountLarge)
                            .foregroundStyle(DS.Semantic.warningForeground)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Settings.faq)
                            .font(.title2.bold())
                            .foregroundStyle(.thPrimaryText)

                        Text(L10n.FAQ.subtitle)
                            .font(DS.Typography.body)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // Sections
                    faqSection(
                        title: L10n.FAQ.sectionGeneral,
                        icon: "info.circle.fill",
                        items: FAQItem.general
                    )

                    // UX 2.2 · L16-17: lo nuevo de 2.x también tiene respuesta (monedas, grupos, Yala IA, nube o iCloud,
                    // Face ID, widgets), y la lista termina con una salida a soporte.
                    faqSection(
                        title: L10n.UXL15.faqSectionCurrencies,
                        icon: "dollarsign.circle.fill",
                        items: FAQItem.currencies
                    )

                    faqSection(
                        title: L10n.UXL15.faqSectionGroups,
                        icon: "person.2.fill",
                        items: FAQItem.groupItems
                    )

                    faqSection(
                        title: L10n.FAQ.sectionData,
                        icon: "externaldrive.fill",
                        items: FAQItem.data
                    )

                    faqSection(
                        title: L10n.FAQ.sectionPro,
                        icon: "crown.fill",
                        items: FAQItem.pro
                    )

                    askUsFooter
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
        .yalaScreenBackground(.subtle)
        .sheet(isPresented: $showSupport) {
            SupportFormSheet()
        }
        .navigationTitle(L10n.Settings.faq)
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

    // MARK: - ¿No está tu pregunta?

    private var askUsFooter: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(L10n.UXL15.faqNotHereTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
                .multilineTextAlignment(.center)
            Button {
                showSupport = true
            } label: {
                Label(L10n.UXL15.faqWriteToUs, systemImage: "envelope.fill")
                    .font(DS.Typography.bodyBold)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("faq_write_to_us")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.sm)
    }

    // MARK: - Section

    @ViewBuilder
    private func faqSection(title: String, icon: String, items: [FAQItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.thSecondaryText)
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thSecondaryText)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(items.enumerated()), id: \.element) { index, item in
                    faqRow(item: item)

                    if index < items.count - 1 {
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

    // MARK: - FAQ Row

    @ViewBuilder
    private func faqRow(item: FAQItem) -> some View {
        Button {
            dsWithAnimation(reduceMotion, .easeInOut(duration: 0.25)) {
                expandedItem = expandedItem == item ? nil : item
            }
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                HStack(spacing: DS.Spacing.md) {
                    Text(item.question)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: expandedItem == item ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.thSecondaryText)
                }

                if expandedItem == item {
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
        .accessibilityIdentifier("faq_row_\(String(describing: item))")
    }
}

// MARK: - FAQ Data Model

enum FAQItem: Hashable {
    case whatIsYala
    case howToRecord
    case multiCurrency
    case changeCategory
    case importData
    case exportData
    case deleteData
    case whatIsPro
    case cancelSub
    // UX 2.2 · L16-17
    case exchangeRate
    case groups
    case yalaAI
    case whereData
    case faceID
    case widgets

    var question: String {
        switch self {
        case .whatIsYala: return L10n.FAQ.whatIsYalaQ
        case .howToRecord: return L10n.FAQ.howToRecordQ
        case .multiCurrency: return L10n.FAQ.multiCurrencyQ
        case .changeCategory: return L10n.FAQ.changeCategoryQ
        case .importData: return L10n.FAQ.importDataQ
        case .exportData: return L10n.FAQ.exportDataQ
        case .deleteData: return L10n.FAQ.deleteDataQ
        case .whatIsPro: return L10n.FAQ.whatIsProQ
        case .cancelSub: return L10n.FAQ.cancelSubQ
        case .exchangeRate: return L10n.UXL15.faqExchangeRateQ
        case .groups: return L10n.UXL15.faqGroupsQ
        case .yalaAI: return L10n.UXL15.faqYalaAIQ
        case .whereData: return L10n.UXL15.faqWhereDataQ
        case .faceID: return L10n.UXL15.faqFaceIDQ
        case .widgets: return L10n.UXL15.faqWidgetsQ
        }
    }

    var answer: String {
        switch self {
        case .whatIsYala: return L10n.FAQ.whatIsYalaA
        case .howToRecord: return L10n.FAQ.howToRecordA
        case .multiCurrency: return L10n.FAQ.multiCurrencyA
        case .changeCategory: return L10n.FAQ.changeCategoryA
        case .importData: return L10n.FAQ.importDataA
        case .exportData: return L10n.FAQ.exportDataA
        case .deleteData: return L10n.FAQ.deleteDataA
        case .whatIsPro: return L10n.FAQ.whatIsProA
        case .cancelSub: return L10n.FAQ.cancelSubA
        case .exchangeRate: return L10n.UXL15.faqExchangeRateA
        case .groups: return L10n.UXL15.faqGroupsA
        case .yalaAI: return L10n.UXL15.faqYalaAIA
        case .whereData: return L10n.UXL15.faqWhereDataA
        case .faceID: return L10n.UXL15.faqFaceIDA
        case .widgets: return L10n.UXL15.faqWidgetsA
        }
    }

    static var general: [FAQItem] { [.whatIsYala, .howToRecord, .changeCategory, .widgets, .faceID] }
    static var currencies: [FAQItem] { [.multiCurrency, .exchangeRate] }
    static var groupItems: [FAQItem] { [.groups] }
    static var data: [FAQItem] { [.whereData, .importData, .exportData, .deleteData] }
    static var pro: [FAQItem] { [.whatIsPro, .yalaAI, .cancelSub] }
}
