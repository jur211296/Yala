//
//  TagSelectorSheet.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
//

import SwiftData
import SwiftUI

// MARK: - Tag Selector Sheet

/// Sheet para seleccionar múltiples etiquetas
struct TagSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]

    @Binding var selectedTags: [Tag]

    @State private var showNewTagSheet: Bool = false
    @State private var tagCountBeforeSheet: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        if activeTags.isEmpty {
                            emptyState
                        } else {
                            tagsList
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Settings.tags)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton(action: { dismiss() })
                }
            }
            .sheet(isPresented: $showNewTagSheet, onDismiss: {
                selectNewlyCreatedTag()
            }) {
                TagFormView(existingTags: tags)
            }
        }
        .tint(Color.electricIndigo)
    }

    /// Selecciona automáticamente la etiqueta recién creada
    private func selectNewlyCreatedTag() {
        let currentCount = activeTags.count
        if currentCount > tagCountBeforeSheet {
            // Hay una nueva etiqueta, seleccionar la última creada (ordenada por nombre)
            if let newTag = activeTags.last(where: { tag in
                !selectedTags.contains { $0.persistentModelID == tag.persistentModelID }
            }) {
                selectedTags.append(newTag)
            }
        }
    }

    private var activeTags: [Tag] {
        tags.filter { $0.isActive }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "tag.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text(L10n.Empty.noTags)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(L10n.Tag.createFirstDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)

            // Add tag button even when empty
            addTagButton
        }
    }

    private var tagsList: some View {
        VStack(spacing: DS.Spacing.lg) {
            SectionBox(title: "") {
                VStack(spacing: 0) {
                    ForEach(Array(activeTags.enumerated()), id: \.element.persistentModelID) {
                        index, tag in
                        if index > 0 {
                            SubsectionDivider()
                        }

                        TagSelectorRow(tag: tag, isSelected: isSelected(tag)) {
                            toggleTag(tag)
                        }
                    }
                }
            }

            addTagButton
        }
    }

    private var addTagButton: some View {
        SectionBox(title: "") {
            Button {
                tagCountBeforeSheet = activeTags.count
                showNewTagSheet = true
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.electricIndigo)
                    Text(L10n.Tag.newTag)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func isSelected(_ tag: Tag) -> Bool {
        selectedTags.contains { $0.persistentModelID == tag.persistentModelID }
    }

    private func toggleTag(_ tag: Tag) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if isSelected(tag) {
                selectedTags.removeAll { $0.persistentModelID == tag.persistentModelID }
            } else {
                selectedTags.append(tag)
            }
        }
    }
}

// MARK: - Tag Selector Row

struct TagSelectorRow: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                // Color circle
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: tag.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                Text(tag.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.electricIndigo)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

/// Layout horizontal que hace wrap de elementos
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews)
        -> (size: CGSize, positions: [CGPoint], sizes: [CGSize])
    {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        let totalWidth = maxWidth

        return (CGSize(width: totalWidth, height: totalHeight), positions, sizes)
    }
}

#Preview {
    TagSelectorSheet(selectedTags: .constant([]))
}
