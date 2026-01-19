//
//  TagFormView.swift
//  Neto
//
//  Created by Neto Refactoring.
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

    // Fetch all tags to check for uniqueness
    @Query private var existingTags: [Tag]

    let tagToEdit: Tag?

    @State private var name: String
    @State private var selectedColorHex: String
    @State private var selectedIconName: String
    @State private var isActive: Bool

    // Custom color picker
    @State private var customColor: Color
    @State private var isPresentingColorPicker: Bool = false

    // Icon picker
    @State private var isPresentingIconPicker: Bool = false

    // Delete confirmation
    @State private var isShowingDeleteConfirmation: Bool = false

    // Focus state
    @FocusState private var isNameFieldFocused: Bool

    private var isEditing: Bool {
        tagToEdit != nil
    }

    init(tagToEdit: Tag? = nil, existingTags: [Tag] = []) {
        self.tagToEdit = tagToEdit

        if let tag = tagToEdit {
            _name = State(initialValue: tag.name)
            _selectedColorHex = State(initialValue: tag.colorHex)
            _selectedIconName = State(initialValue: tag.iconName)
            _isActive = State(initialValue: tag.isActive)
            _customColor = State(initialValue: colorForHex(tag.colorHex))
        } else {
            // Calcular color único basado en tags existentes
            let usedColors = existingTags.map { $0.colorHex }
            let defaultColor = Tag.nextAvailableColor(excluding: usedColors)
            _name = State(initialValue: "")
            _selectedColorHex = State(initialValue: defaultColor)
            _selectedIconName = State(initialValue: "tag.fill")
            _isActive = State(initialValue: true)
            _customColor = State(initialValue: colorForHex(defaultColor))
        }
    }

    // MARK: - Validation

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 20
    }

    private var isNameUnique: Bool {
        let lowerName = trimmedName.lowercased()
        return !existingTags.contains { tag in
            // Check if it's the same tag we are editing
            if let tagToEdit = tagToEdit, tag.id == tagToEdit.id {
                return false
            }
            return tag.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                == lowerName
        }
    }

    private var canSave: Bool {
        isNameValid && isNameUnique
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

                        if isEditing {
                            deleteSection
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEditing ? L10n.Tag.editTag : L10n.Tag.newTag)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton(action: { saveTag() }, isDisabled: !canSave)
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
                            selectedColorHex = hexString(from: customColor)
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
                    selectedIconName: $selectedIconName,
                    selectedColorHex: $selectedColorHex,
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
                // Auto-focus name field for new tags
                if !isEditing {
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
                    TextField(L10n.Tag.namePlaceholder, text: $name)
                        .focused($isNameFieldFocused)
                        .onChange(of: name) { oldValue, newValue in
                            if newValue.count > 20 {
                                name = String(newValue.prefix(20))
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
                        .fill(colorForHex(selectedColorHex))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: selectedIconName)
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
                                            lineWidth: selectedColorHex.uppercased()
                                                == hex.uppercased() ? 3 : 1)
                                )
                                .shadow(
                                    radius: selectedColorHex.uppercased() == hex.uppercased() ? 4 : 0
                                )
                                .onTapGesture {
                                    selectedColorHex = hex
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

                    Text(L10n.Tag.colorSelected(selectedColorHex))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    private var statusSection: some View {
        SectionBox(title: L10n.Common.status) {
            Toggle(isOn: $isActive) {
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
            return selectedColorHex
        }
    }

    // MARK: - Actions

    private func saveTag() {
        guard canSave else { return }

        if let tag = tagToEdit {
            tag.name = trimmedName
            tag.colorHex = selectedColorHex
            tag.iconName = selectedIconName
            tag.isActive = isActive
        } else {
            let newTag = Tag(
                name: trimmedName,
                colorHex: selectedColorHex,
                iconName: selectedIconName,
                isActive: isActive
            )
            modelContext.insert(newTag)
        }

        dismiss()
    }

    private func deleteTag() {
        guard let tag = tagToEdit else { return }
        modelContext.delete(tag)
        dismiss()
    }
}
