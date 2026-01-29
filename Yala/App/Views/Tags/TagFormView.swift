//
//  TagFormView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct TagFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(EntityDeletionService.self) private var deletionService

    @State private var viewModel: TagFormViewModel

    // Custom color picker
    @State private var customColor: Color
    @State private var isPresentingColorPicker: Bool = false

    // Icon picker
    @State private var isPresentingIconPicker: Bool = false

    // Delete confirmation
    @State private var isShowingDeleteConfirmation: Bool = false

    // Focus state
    @FocusState private var isNameFieldFocused: Bool

    init(tagToEdit: Tag? = nil, existingTags: [Tag] = []) {
        let vm = TagFormViewModel(tagToEdit: tagToEdit, initialExistingTags: existingTags)
        _viewModel = State(initialValue: vm)
        _customColor = State(initialValue: colorForHex(vm.selectedColorHex))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                    .dismissKeyboardOnTap()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        generalSection
                        iconSection
                        colorSection
                        statusSection

                        if viewModel.isEditing {
                            deleteSection
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(viewModel.isEditing ? L10n.Tag.editTag : L10n.Tag.newTag)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { saveTag() }, isDisabled: !viewModel.canSave)
                }
            }
            .sheet(isPresented: $isPresentingColorPicker) {
                NavigationStack {
                    VStack(spacing: DS.Spacing.xxl) {
                        ColorPicker(
                            L10n.Common.selectColor,
                            selection: $customColor,
                            supportsOpacity: false
                        )
                        .padding()

                        Button(L10n.Common.useThisColor) {
                            viewModel.selectedColorHex = hexString(from: customColor)
                            isPresentingColorPicker = false
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()
                    }
                    .padding()
                    .navigationTitle(L10n.Common.newColor)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .alert(L10n.Tag.deleteConfirmation, isPresented: $isShowingDeleteConfirmation) {
                Button(L10n.Action.cancel, role: .cancel) {}
                Button(L10n.Action.delete, role: .destructive) {
                    deleteTag()
                }
            } message: {
                Text(L10n.Common.cannotUndo)
            }
            .sheet(isPresented: $isPresentingIconPicker) {
                IconColorPickerSheet(
                    selectedIconName: $viewModel.selectedIconName,
                    selectedColorHex: $viewModel.selectedColorHex,
                    supportsColorPicking: false
                )
            }
            .onChange(of: isPresentingColorPicker) { _, isPresenting in
                if isPresenting { dismissKeyboard() }
            }
            .onChange(of: isPresentingIconPicker) { _, isPresenting in
                if isPresenting { dismissKeyboard() }
            }
            .onAppear {
                viewModel.setContext(modelContext)
                // Auto-focus name field for new tags
                if !viewModel.isEditing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isNameFieldFocused = true
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        SectionBox(title: L10n.Common.general) {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                    TextField(L10n.Tag.namePlaceholder, text: $viewModel.name)
                        .focused($isNameFieldFocused)
                        .onChange(of: viewModel.name) { oldValue, newValue in
                            if newValue.count > 20 {
                                viewModel.name = String(newValue.prefix(20))
                            }
                        }
                }
                .padding()
            }
        }
    }

    private var iconSection: some View {
        SectionBox(title: L10n.Common.icon) {
            Button {
                isPresentingIconPicker = true
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Circle()
                        .fill(colorForHex(viewModel.selectedColorHex))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: viewModel.selectedIconName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                        )

                    Text(L10n.Common.changeIcon)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var colorSection: some View {
        SectionBox(title: L10n.Tag.color) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.md), count: 8),
                        spacing: DS.Spacing.md
                    ) {
                        ForEach(Tag.defaultColors, id: \.self) { hex in
                            Circle()
                                .fill(colorForHex(hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.white,
                                            lineWidth: viewModel.selectedColorHex.uppercased()
                                                == hex.uppercased() ? 3 : 1)
                                )
                                .shadow(
                                    radius: viewModel.selectedColorHex.uppercased() == hex.uppercased() ? 4 : 0
                                )
                                .onTapGesture {
                                    viewModel.selectedColorHex = hex
                                }
                        }

                        Button {
                            isPresentingColorPicker = true
                        } label: {
                            Circle()
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Text(L10n.Tag.colorSelected(viewModel.selectedColorHex))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    private var statusSection: some View {
        SectionBox(title: L10n.Common.status) {
            Toggle(isOn: $viewModel.isActive) {
                Text(L10n.Common.active)
            }
            .tint(Color.electricIndigo)
            .padding()
        }
    }

    private var deleteSection: some View {
        SectionBox(title: L10n.Common.actions) {
            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(L10n.Tag.delete)
                    Spacer()
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func hexString(from color: Color) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var success = false

        #if canImport(UIKit)
            let uiColor = UIColor(color)
            success = uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
            let nsColor = NSColor(color)
            if let rgbColor = nsColor.usingColorSpace(.sRGB) {
                rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                success = true
            }
        #endif

        if success {
            let r = Int(red * 255)
            let g = Int(green * 255)
            let b = Int(blue * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return viewModel.selectedColorHex
        }
    }

    // MARK: - Actions

    private func saveTag() {
        if viewModel.saveTag() {
            dismiss()
        }
    }

    private func deleteTag() {
        guard let tag = viewModel.tagToEdit else { return }
        deletionService.setContext(modelContext)
        do {
            try deletionService.deleteTag(tag)
            dismiss()
        } catch {
            print("TagFormView: Error deleting tag: \(error)")
        }
    }
}
