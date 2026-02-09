//
//  TipsAndTricksView.swift
//  Yala
//
//  Created by Yala.
//

import SwiftUI

struct TipsAndTricksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedTip: TipItem?

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(DS.Typography.amountLarge)
                            .foregroundStyle(.yellow)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Settings.tips)
                            .font(.title2.bold())
                            .foregroundStyle(Color.yalaPrimaryText)

                        Text(L10n.Tips.subtitle)
                            .font(DS.Typography.body)
                            .foregroundStyle(Color.yalaSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // Sections
                    tipSection(
                        title: L10n.Tips.sectionQuickEntry,
                        icon: "bolt.fill",
                        tips: TipItem.quickEntry
                    )

                    tipSection(
                        title: L10n.Tips.sectionOrganize,
                        icon: "folder.fill",
                        tips: TipItem.organize
                    )

                    tipSection(
                        title: L10n.Tips.sectionAdvanced,
                        icon: "star.fill",
                        tips: TipItem.advanced
                    )
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
        }
        .navigationTitle(L10n.Settings.tips)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Section

    @ViewBuilder
    private func tipSection(title: String, icon: String, tips: [TipItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.yalaSecondaryText)
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.yalaSecondaryText)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(tips.enumerated()), id: \.element) { index, tip in
                    tipRow(tip: tip)

                    if index < tips.count - 1 {
                        Divider()
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                }
            }
            .background(Color.yalaCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }

    // MARK: - Tip Row

    @ViewBuilder
    private func tipRow(tip: TipItem) -> some View {
        Button {
            dsWithAnimation(reduceMotion) {
                expandedTip = expandedTip == tip ? nil : tip
            }
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: tip.icon)
                        .font(DS.Typography.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(tip.color)
                        )

                    Text(tip.title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(Color.yalaPrimaryText)

                    Spacer()

                    Image(systemName: expandedTip == tip ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(Color.yalaSecondaryText)
                }

                if expandedTip == tip {
                    Text(tip.detail)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(Color.yalaSecondaryText)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.leading, 40)
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

// MARK: - Tip Data Model

enum TipItem: Hashable {
    case voice
    case camera
    case favorites
    case budgets
    case tags
    case filters
    case export
    case faceID

    var icon: String {
        switch self {
        case .voice: return "mic.fill"
        case .camera: return "camera.fill"
        case .favorites: return "star.fill"
        case .budgets: return "chart.pie.fill"
        case .tags: return "tag.fill"
        case .filters: return "line.3.horizontal.decrease"
        case .export: return "square.and.arrow.up"
        case .faceID: return "faceid"
        }
    }

    var color: Color {
        switch self {
        case .voice: return .hotPink
        case .camera: return .teal
        case .favorites: return .yellow
        case .budgets: return .electricIndigo
        case .tags: return .orange
        case .filters: return .purple
        case .export: return .green
        case .faceID: return .blue
        }
    }

    var title: String {
        switch self {
        case .voice: return L10n.Tips.voiceTitle
        case .camera: return L10n.Tips.cameraTitle
        case .favorites: return L10n.Tips.favoritesTitle
        case .budgets: return L10n.Tips.budgetsTitle
        case .tags: return L10n.Tips.tagsTitle
        case .filters: return L10n.Tips.filtersTitle
        case .export: return L10n.Tips.exportTitle
        case .faceID: return L10n.Tips.faceIDTitle
        }
    }

    var detail: String {
        switch self {
        case .voice: return L10n.Tips.voiceDetail
        case .camera: return L10n.Tips.cameraDetail
        case .favorites: return L10n.Tips.favoritesDetail
        case .budgets: return L10n.Tips.budgetsDetail
        case .tags: return L10n.Tips.tagsDetail
        case .filters: return L10n.Tips.filtersDetail
        case .export: return L10n.Tips.exportDetail
        case .faceID: return L10n.Tips.faceIDDetail
        }
    }

    static var quickEntry: [TipItem] { [.voice, .camera, .favorites] }
    static var organize: [TipItem] { [.budgets, .tags, .filters] }
    static var advanced: [TipItem] { [.export, .faceID] }
}
