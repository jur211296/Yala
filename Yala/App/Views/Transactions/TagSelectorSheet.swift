//
//  TagSelectorSheet.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import SwiftData
import SwiftUI

// MARK: - Tag Selector Sheet

/// Sheet para seleccionar múltiples etiquetas
struct TagSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = TagSelectorViewModel()
    @FocusState private var isNewTagFieldFocused: Bool
    @Environment(\.yalaTheme) private var theme

    @Binding var selectedTags: [Tag]

    /// Cómo abre la hoja (`SelectorSheetSizing`): `.mediumFirst` desde un registro nuevo, `.large` en el resto.
    var sizing: SelectorSheetSizing = .large
    @State private var selectedDetent: PresentationDetent = .medium
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var sheetBackground: YalaBackgroundVariant {
        guard sizing == .mediumFirst else { return .subtle }
        return sizing.background(
            selectedDetent: selectedDetent,
            usesLargeSheets: usesLargeSheets,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        tagsList
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(sheetBackground)
            .navigationTitle(L10n.Settings.tags)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { dismiss() })
                }
            }
        }
        .selectorSheetSizing(sizing, selectedDetent: $selectedDetent)
        .onAppear {
            viewModel.setContext(modelContext)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            YalaEmptyState(
                icon: "tag.slash",
                title: L10n.Empty.noTags,
                message: L10n.Tag.createFirstDescription
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xxxxl)

            // Add tag button even when empty
            addTagButton
        }
    }

    private var tagsList: some View {
        VStack(spacing: DS.Spacing.lg) {
            SectionBox(title: "") {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(Array(viewModel.activeTags.enumerated()), id: \.element.persistentModelID) {
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

    /// «Nueva etiqueta» es un campo con «Crear» (UX 2.2 · L2-10, decidido por Jürgen el 14-oct): solo el nombre, con el
    /// icono y el color automáticos, y queda puesta. Antes abría el editor entero (icono, 16 colores, un código hexadecimal
    /// y «Estado»), que sigue en Ajustes › Etiquetas.
    private var addTagButton: some View {
        SectionBox(title: "") {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.thAccentText)
                    .accessibilityHidden(true)
                TextField(L10n.Tag.newTag, text: $viewModel.newTagName)
                    .font(DS.Typography.body)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($isNewTagFieldFocused)
                    .onSubmit(createTag)
                    .onChange(of: viewModel.newTagName) { _, newValue in
                        if newValue.count > TagQuickCreateLogic.maxNameLength {
                            viewModel.newTagName = String(newValue.prefix(TagQuickCreateLogic.maxNameLength))
                        }
                    }
                    .accessibilityIdentifier("tag_selector_new_name")
                Button(L10n.UXL2B.createTag, action: createTag)
                    .font(DS.Typography.label)
                    .foregroundStyle(viewModel.canCreateTag ? theme.accentText : DS.Semantic.disabledForeground)
                    .disabled(!viewModel.canCreateTag)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tag_selector_create")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
        }
    }

    private func createTag() {
        guard let tag = viewModel.createOrPickTag() else { return }
        dsWithAnimation(reduceMotion) {
            if !isSelected(tag) {
                selectedTags.append(tag)
            }
        }
        isNewTagFieldFocused = false
    }

    private func isSelected(_ tag: Tag) -> Bool {
        selectedTags.contains { $0.persistentModelID == tag.persistentModelID }
    }

    private func toggleTag(_ tag: Tag) {
        dsWithAnimation(reduceMotion) {
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
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.white)
                    )

                Text(tag.name)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thAccentText)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tag.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tag_selector_row_\(tag.name)")
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
