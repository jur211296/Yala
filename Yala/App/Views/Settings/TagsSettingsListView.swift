//
//  TagsSettingsListView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

struct TagsSettingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var viewModel = TagsSettingsListViewModel()

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        if !viewModel.orderedActiveTags.isEmpty {
                            ContextualGuideBanner.tagsSettings()
                            activeTagsSection
                        }

                        if !viewModel.inactiveTags.isEmpty {
                            inactiveTagsSection
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxxl)
            }
        }
        .navigationTitle(L10n.Settings.tags)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.md) {
                    YalaToolbarButton(systemName: viewModel.isEditMode ? "checkmark" : "arrow.up.arrow.down", label: viewModel.isEditMode ? L10n.Action.done : L10n.Action.reorder)
                    {
                        dsWithAnimation(reduceMotion) {
                            viewModel.isEditMode.toggle()
                        }
                    }

                    YalaToolbarButton(systemName: "plus", label: L10n.Action.add) {
                        viewModel.isPresentingCreateTag = true
                    }
                    .accessibilityIdentifier("tags_add_button")
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingCreateTag, onDismiss: {
            viewModel.loadTags()
        }) {
            TagFormView(existingTags: viewModel.tags)
        }
        .sheet(item: $viewModel.tagToEdit, onDismiss: {
            viewModel.loadTags()
        }) { tag in
            TagFormView(tagToEdit: tag, existingTags: viewModel.tags)
        }
        .onAppear {
            viewModel.setContext(modelContext)
            viewModel.tagsSortOrderNames = appPreferences.tagsSortOrderNames
        }
        .onChange(of: appPreferences.tagsSortOrderNames) { _, newValue in
            viewModel.tagsSortOrderNames = newValue
        }
    }

    private var emptyState: some View {
        YalaEmptyState.noTags()
    }

    // MARK: - Active Tags Section (List with Drag and Drop)

    private var activeTagsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.active)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            List {
                ForEach(Array(viewModel.orderedActiveTags.enumerated()), id: \.element.id) { index, tag in
                    Button {
                        if !viewModel.isEditMode {
                            viewModel.tagToEdit = tag
                        }
                    } label: {
                        tagRow(tag)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tags_row_\(tag.name)")
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(
                        index == 0 || index == viewModel.orderedActiveTags.count - 1 ? .hidden : .visible,
                        edges: index == 0 ? .top : .bottom)
                }
                .onMove(perform: moveTag)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(viewModel.orderedActiveTags.count) * DS.FormRow.minHeight)
            .solidCard()
            .environment(\.editMode, .constant(viewModel.isEditMode ? .active : .inactive))
        }
    }

    // MARK: - Inactive Tags Section (No reordering)

    private var inactiveTagsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.inactive)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            List {
                ForEach(Array(viewModel.inactiveTags.enumerated()), id: \.element.id) { index, tag in
                    Button {
                        viewModel.tagToEdit = tag
                    } label: {
                        tagRow(tag)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(
                        index == 0 || index == viewModel.inactiveTags.count - 1 ? .hidden : .visible,
                        edges: index == 0 ? .top : .bottom)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(viewModel.inactiveTags.count) * DS.FormRow.minHeight)
            .solidCard()
        }
    }

    // MARK: - Tag Row

    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(colorForHex(tag.colorHex))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: tag.iconName)
                        .font(DS.Typography.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                )

            Text(tag.name)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()

            if !viewModel.isEditMode {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Reorder Logic

    private func moveTag(from source: IndexSet, to destination: Int) {
        let newOrder = viewModel.moveTag(from: source, to: destination)
        appPreferences.tagsSortOrderNames = newOrder
    }
}
