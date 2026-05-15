//
//  PersonalDetailsView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import PhotosUI
import SwiftUI

/// View for editing personal user details
struct PersonalDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 44 // A11Y-DT: @ScaledMetric

    @State private var editedName: String = ""
    @State private var editedAlias: String = ""
    @State private var aliasValidationMessage: String = ""
    @State private var isAliasValid: Bool = true

    private let maxNameLength = 30

    // Photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var profileUIImage: UIImage?

    // Icon picker sheet
    @State private var showIconPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedIcon: String = ""

    /// Whether user has a custom avatar (photo or icon)
    private var hasCustomAvatar: Bool {
        profileImage != nil || !selectedIcon.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // Avatar header with photo picker
                        avatarHeader

                        // Details form
                        detailsSection

                        // Privacy disclaimer
                        privacyDisclaimer
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.xxl)
                    .padding(.bottom, DS.Spacing.xxxl)
                    .dismissKeyboardOnTap()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(L10n.Profile.personalDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        saveAndDismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentValues()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                        let uiImage = UIImage(data: data)
                    {
                        profileUIImage = uiImage
                        profileImage = Image(uiImage: uiImage)
                    }
                }
            }
            .onChange(of: editedName) { _, newValue in
                // Limit name length
                if newValue.count > maxNameLength {
                    editedName = String(newValue.prefix(maxNameLength))
                }
            }
            .onChange(of: editedAlias) { _, newValue in
                validateAlias(newValue)
            }
        }
    }

    // MARK: - Avatar Header

    private var avatarHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            Menu {
                // Choose photo option
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(L10n.Profile.choosePhoto, systemImage: "photo")
                }

                // Choose icon option
                Button {
                    showIconPicker = true
                } label: {
                    Label(L10n.Profile.chooseIcon, systemImage: "face.smiling")
                }

                // Remove option (only if has custom avatar)
                if hasCustomAvatar {
                    Divider()
                    Button(role: .destructive) {
                        removeCustomAvatar()
                    } label: {
                        Label(L10n.Profile.removeAvatar, systemImage: "trash")
                    }
                }
            } label: {
                avatarDisplay
            }

        }
        .padding(.vertical, DS.Spacing.sm)
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .sheet(isPresented: $showIconPicker) {
            IconPickerSheet(selectedIcon: $selectedIcon) {
                // When icon is selected, clear the photo
                profileImage = nil
                profileUIImage = nil
            }
            .presentationDetents(DS.Adaptive.sheetDetents([.medium]))
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Avatar Display

    private var avatarDisplay: some View {
        ZStack {
            if let profileImage {
                // User photo
                profileImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else if !selectedIcon.isEmpty {
                // Custom icon
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: selectedIcon)
                    .font(.system(size: avatarSize))
                    .foregroundStyle(theme.accent)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            } else {
                // Default
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.fill")
                    .font(.system(size: avatarSize))
                    .foregroundStyle(theme.accent)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }

            // Edit badge overlay
            Circle()
                .fill(theme.accent)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "pencil")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.white)
                }
                .offset(x: 35, y: 35)
        }
    }

    // MARK: - Remove Custom Avatar

    private func removeCustomAvatar() {
        profileImage = nil
        profileUIImage = nil
        selectedIcon = ""
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        SectionBox(title: "") {
            VStack(spacing: DS.Spacing.none) {
                // Name row
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text(L10n.Common.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(L10n.Profile.yourName, text: $editedName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                    }
                    .padding(DS.Spacing.lg)

                    // Character count
                    if !editedName.isEmpty {
                        Text("\(editedName.count)/\(maxNameLength) \(L10n.Profile.characters)")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(
                                editedName.count >= maxNameLength ? .orange : .secondary
                            )
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.md)
                    }
                }

            }
        }
    }

    // MARK: - Privacy Disclaimer

    private var privacyDisclaimer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Profile.privacyTitle)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)

            Text(L10n.Profile.privacyDesc)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    // MARK: - Helpers

    private func loadCurrentValues() {
        editedName = appPreferences.userName
        editedAlias = appPreferences.userAlias
        selectedIcon = appPreferences.userProfileIcon

        // Migrate from UserDefaults if needed, then load from file
        ProfileImageStorage.shared.migrateFromUserDefaultsIfNeeded()
        if let imageData = ProfileImageStorage.shared.imageData,
            let uiImage = UIImage(data: imageData)
        {
            profileUIImage = uiImage
            profileImage = Image(uiImage: uiImage)
        }
    }

    private func validateAlias(_ alias: String) {
        // Convert to lowercase
        let lowercased = alias.lowercased()
        if lowercased != alias {
            editedAlias = lowercased
            return
        }

        // Check length
        if alias.count < 3 {
            aliasValidationMessage = L10n.Profile.minChars
            isAliasValid = false
            return
        }

        if alias.count > 20 {
            aliasValidationMessage = L10n.Profile.maxChars
            isAliasValid = false
            return
        }

        // Check allowed characters (letters, numbers, underscores)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if alias.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            aliasValidationMessage = L10n.Profile.allowedChars
            isAliasValid = false
            return
        }

        // All validations passed
        aliasValidationMessage = L10n.Profile.aliasAvailable
        isAliasValid = true
    }

    private func saveAndDismiss() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        appPreferences.userName = trimmedName.isEmpty ? L10n.Profile.defaultName : trimmedName

        // Save alias (only if valid or empty)
        if isAliasValid || editedAlias.isEmpty {
            appPreferences.userAlias = editedAlias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        // Save profile image to file or clear it if icon is selected
        if let uiImage = profileUIImage {
            if let imageData = uiImage.jpegData(compressionQuality: 0.7) {
                ProfileImageStorage.shared.save(imageData)
                appPreferences.userProfileIcon = "" // Clear icon when photo is set
            }
        } else if !selectedIcon.isEmpty {
            // Icon selected, clear image file
            ProfileImageStorage.shared.delete()
            appPreferences.userProfileIcon = selectedIcon
        } else if !hasCustomAvatar {
            // User removed avatar, clear both
            ProfileImageStorage.shared.delete()
            appPreferences.userProfileIcon = ""
        }

        // Dismiss the sheet
        dismiss()
    }
}

// MARK: - Icon Picker Sheet

struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Binding var selectedIcon: String
    var onSelect: () -> Void

    /// Available icons for profile avatar
    private let availableIcons: [(name: String, symbol: String)] = [
        ("Persona", "person.fill"),
        ("Cara feliz", "face.smiling.fill"),
        ("Estrella", "star.fill"),
        ("Corazón", "heart.fill"),
        ("Rayo", "bolt.fill"),
        ("Corona", "crown.fill"),
        ("Hoja", "leaf.fill"),
        ("Llama", "flame.fill"),
        ("Luna", "moon.fill"),
        ("Sol", "sun.max.fill"),
        ("Nube", "cloud.fill"),
        ("Gota", "drop.fill"),
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 80), spacing: DS.Spacing.md)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DS.Spacing.lg) {
                    ForEach(availableIcons, id: \.symbol) { icon in
                        iconButton(icon)
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(L10n.Profile.chooseIcon)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func iconButton(_ icon: (name: String, symbol: String)) -> some View {
        Button {
            selectedIcon = icon.symbol
            onSelect()
            dismiss()
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(selectedIcon == icon.symbol
                              ? theme.accent
                              : theme.accent.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon.symbol)
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(selectedIcon == icon.symbol
                                         ? .white
                                         : theme.accent)
                }

                Text(icon.name)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PersonalDetailsView()
        .environment(AppPreferences())
}

#Preview("Icon Picker") {
    IconPickerSheet(selectedIcon: .constant("star.fill")) { }
}
