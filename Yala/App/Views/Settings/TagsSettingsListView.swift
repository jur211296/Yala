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

    @State private var viewModel = TagsSettingsListViewModel()

    // Persisted order for tags (synced bidirectionally with ViewModel)
    @AppStorage("tagsSortOrderNames") private var tagsSortOrderNamesRaw: String = ""

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        if !viewModel.orderedActiveTags.isEmpty {
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
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.md) {
                    YalaToolbarButton(systemName: viewModel.isEditMode ? "checkmark" : "arrow.up.arrow.down", label: viewModel.isEditMode ? "Listo" : "Reordenar")
                    {
                        dsWithAnimation(reduceMotion) {
                            viewModel.isEditMode.toggle()
                        }
                    }

                    YalaToolbarButton(systemName: "plus", label: "Agregar") {
                        viewModel.isPresentingCreateTag = true
                    }
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
            viewModel.tagsSortOrderNamesRaw = tagsSortOrderNamesRaw
        }
        .onChange(of: tagsSortOrderNamesRaw) { _, newValue in
            viewModel.tagsSortOrderNamesRaw = newValue
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "tag")
                .font(DS.Typography.amountLarge)
                .foregroundStyle(.tertiary)

            Text(L10n.Empty.noTags)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)

            Text(L10n.Empty.tagsDescription)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 64)
    }

    // MARK: - Active Tags Section (List with Drag and Drop)

    private var activeTagsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.active)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

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
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.yalaCard)
                    .listRowSeparator(
                        index == 0 || index == viewModel.orderedActiveTags.count - 1 ? .hidden : .visible,
                        edges: index == 0 ? .top : .bottom)
                }
                .onMove(perform: moveTag)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(viewModel.orderedActiveTags.count) * 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Colors.borderDark, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            .environment(\.editMode, .constant(viewModel.isEditMode ? .active : .inactive))
        }
    }

    // MARK: - Inactive Tags Section (No reordering)

    private var inactiveTagsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.inactive)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            List {
                ForEach(Array(viewModel.inactiveTags.enumerated()), id: \.element.id) { index, tag in
                    Button {
                        viewModel.tagToEdit = tag
                    } label: {
                        tagRow(tag)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.yalaCard)
                    .listRowSeparator(
                        index == 0 || index == viewModel.inactiveTags.count - 1 ? .hidden : .visible,
                        edges: index == 0 ? .top : .bottom)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(viewModel.inactiveTags.count) * 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Colors.borderDark, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
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
        let newRaw = viewModel.moveTag(from: source, to: destination)
        tagsSortOrderNamesRaw = newRaw
    }
}
