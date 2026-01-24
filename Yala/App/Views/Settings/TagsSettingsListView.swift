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
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]

    @State private var isPresentingCreateTag = false
    @State private var tagToEdit: Tag?
    @State private var isEditMode = false

    // Persisted order for tags
    @AppStorage("tagsSortOrderNames") private var tagsSortOrderNamesRaw: String = ""

    private var tagsSortOrderNames: [String] {
        tagsSortOrderNamesRaw.split(separator: "|").map(String.init)
    }

    private var orderedActiveTags: [Tag] {
        let active = tags.filter { $0.isActive }
        let order = tagsSortOrderNames
        let indexByName = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

        return active.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]

            switch (ia, ib) {
            case (let x?, let y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
    }

    private var inactiveTags: [Tag] {
        tags.filter { !$0.isActive }
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if tags.isEmpty {
                        emptyState
                    } else {
                        if !orderedActiveTags.isEmpty {
                            activeTagsSection
                        }

                        if !inactiveTags.isEmpty {
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
                YalaToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.md) {
                    YalaToolbarButton(systemName: isEditMode ? "checkmark" : "arrow.up.arrow.down")
                    {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditMode.toggle()
                        }
                    }

                    YalaToolbarButton(systemName: "plus") {
                        isPresentingCreateTag = true
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingCreateTag) {
            TagFormView(existingTags: tags)
        }
        .sheet(item: $tagToEdit) { tag in
            TagFormView(tagToEdit: tag, existingTags: tags)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(L10n.Empty.noTags)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L10n.Empty.tagsDescription)
                .font(.subheadline)
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
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            List {
                ForEach(Array(orderedActiveTags.enumerated()), id: \.element.id) { index, tag in
                    Button {
                        if !isEditMode {
                            tagToEdit = tag
                        }
                    } label: {
                        tagRow(tag)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.yalaCard)
                    .listRowSeparator(
                        index == 0 || index == orderedActiveTags.count - 1 ? .hidden : .visible,
                        edges: index == 0 ? .top : .bottom)
                }
                .onMove(perform: moveTag)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(orderedActiveTags.count) * 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        }
    }

    // MARK: - Inactive Tags Section (No reordering)

    private var inactiveTagsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.inactive)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            List {
                ForEach(Array(inactiveTags.enumerated()), id: \.element.id) { index, tag in
                    Button {
                        tagToEdit = tag
                    } label: {
                        tagRow(tag)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.yalaCard)
                    .listRowSeparator(
                        index == 0 || index == inactiveTags.count - 1 ? .hidden : .visible,
                        edges: index == 0 ? .top : .bottom)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(inactiveTags.count) * 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                )

            Text(tag.name)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            if !isEditMode {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Reorder Logic

    private func moveTag(from source: IndexSet, to destination: Int) {
        var currentOrder = orderedActiveTags.map { $0.name }
        currentOrder.move(fromOffsets: source, toOffset: destination)
        tagsSortOrderNamesRaw = currentOrder.joined(separator: "|")
    }
}
