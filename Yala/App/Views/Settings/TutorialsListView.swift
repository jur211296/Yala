//
//  TutorialsListView.swift
//  Yala
//
//  Created by Yala.
//

import SwiftUI

struct TutorialsListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "book.fill")
                            .font(DS.Typography.amountLarge)
                            .foregroundStyle(.thAccent)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Settings.tutorials)
                            .font(.title2.bold())
                            .foregroundStyle(.thPrimaryText)

                        Text(L10n.Tutorials.subtitle)
                            .font(DS.Typography.body)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // Sections
                    ForEach(TutorialCategory.allCases) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
        }
        .navigationTitle(L10n.Settings.tutorials)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
        .navigationDestination(for: Tutorial.self) { tutorial in
            TutorialDetailView(tutorial: tutorial)
        }
    }

    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(_ category: TutorialCategory) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(category.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.thSecondaryText)
                .textCase(.uppercase)
                .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(category.tutorials.enumerated()), id: \.element) { index, tutorial in
                    NavigationLink(value: tutorial) {
                        tutorialRow(tutorial)
                    }
                    .buttonStyle(.plain)

                    if index < category.tutorials.count - 1 {
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

    // MARK: - Tutorial Row

    @ViewBuilder
    private func tutorialRow(_ tutorial: Tutorial) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: tutorial.icon)
                .font(DS.Typography.subheadline).fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tutorial.color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(tutorial.title)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thPrimaryText)

                Text(String(format: L10n.Tutorials.stepsCount, tutorial.steps.count))
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.thSecondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.thSecondaryText)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }
}
