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
        YalaSettingsList {
                // Header
                Section {
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
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.Spacing.lg)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }

                // Sections
                ForEach(TutorialCategory.allCases) { category in
                    categorySection(category)
                }
            }
        .yalaScreenBackground(.subtle)
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
        YalaSettingsSection(category.title) {
            // En una `List`, el `NavigationLink` pinta su propio chevron: la fila ya no lleva el suyo.
            ForEach(category.tutorials) { tutorial in
                NavigationLink(value: tutorial) {
                    tutorialRow(tutorial)
                }
            }
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

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(tutorial.title)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thPrimaryText)

                Text(String(format: L10n.Tutorials.stepsCount, tutorial.steps.count))
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.thSecondaryText)
            }

            Spacer()

            if tutorial.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.body)
                    .foregroundStyle(.thAccent)
            }
        }
        .contentShape(Rectangle())
    }
}
