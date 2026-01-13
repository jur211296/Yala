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
    @State private var isActive: Bool

    // Custom color picker
    @State private var customColor: Color
    @State private var isPresentingColorPicker: Bool = false

    // Delete confirmation
    @State private var isShowingDeleteConfirmation: Bool = false

    private var isEditing: Bool {
        tagToEdit != nil
    }

    init(tagToEdit: Tag? = nil) {
        self.tagToEdit = tagToEdit

        if let tag = tagToEdit {
            _name = State(initialValue: tag.name)
            _selectedColorHex = State(initialValue: tag.colorHex)
            _isActive = State(initialValue: tag.isActive)
            _customColor = State(initialValue: colorForHex(tag.colorHex))
        } else {
            _name = State(initialValue: "")
            _selectedColorHex = State(initialValue: "#1C3556")  // Default dark blue
            _isActive = State(initialValue: true)
            _customColor = State(initialValue: Color(red: 0.11, green: 0.21, blue: 0.34))
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

                ScrollView {
                    VStack(spacing: 24) {
                        generalSection
                        colorSection
                        statusSection

                        if isEditing {
                            deleteSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
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
                    VStack(spacing: 24) {
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
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        SectionBox(title: "General") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                    TextField("Nombre (máx. 20)", text: $name)
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

    private var colorSection: some View {
        SectionBox(title: "Color") {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(colorForHex(hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.white, lineWidth: selectedColorHex == hex ? 3 : 1)
                                )
                                .shadow(radius: selectedColorHex == hex ? 4 : 0)
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

                    Text("Seleccionado: \(selectedColorHex)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    private var statusSection: some View {
        SectionBox(title: "Estado") {
            Toggle(isOn: $isActive) {
                Text(L10n.Common.active)
            }
            .tint(Color.electricIndigo)
            .padding()
        }
    }

    private var deleteSection: some View {
        SectionBox(title: "Acciones") {
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

    private var colorOptions: [String] {
        ["#FF9F0A", "#30D158", "#FF375F", "#0A84FF", "#5E5CE6", "#FFD60A", "#1C3556"]
    }

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
            tag.isActive = isActive
        } else {
            let newTag = Tag(
                name: trimmedName,
                colorHex: selectedColorHex,
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
