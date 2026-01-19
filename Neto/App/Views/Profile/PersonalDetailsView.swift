//
//  PersonalDetailsView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import PhotosUI
import SwiftUI

/// View for editing personal user details
struct PersonalDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("userAlias") private var userAlias: String = ""
    @AppStorage("userProfileImageData") private var userProfileImageData: Data?

    @State private var editedName: String = ""
    @State private var editedAlias: String = ""
    @State private var aliasValidationMessage: String = ""
    @State private var isAliasValid: Bool = true

    private let maxNameLength = 30

    // Photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var profileUIImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                    .dismissKeyboardOnTap()

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
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(L10n.Profile.personalDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "chevron.left") {
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
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    if let profileImage {
                        profileImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.electricIndigo.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "person.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.electricIndigo)
                    }

                    // Camera badge overlay
                    Circle()
                        .fill(Color.electricIndigo)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 35, y: 35)
                }
            }

            Text(profileImage != nil ? L10n.Profile.changePhoto : L10n.Profile.addPhoto)
                .font(.subheadline)
                .foregroundStyle(Color.electricIndigo)
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        SectionBox(title: "") {
            VStack(spacing: 0) {
                // Name row
                VStack(alignment: .leading, spacing: 4) {
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
                            .font(.caption2)
                            .foregroundStyle(
                                editedName.count >= maxNameLength ? .orange : .secondary
                            )
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.md)
                    }
                }

                SubsectionDivider()

                // Alias row
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.Common.alias)
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(L10n.Profile.aliasPlaceholder, text: $editedAlias)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    .padding(DS.Spacing.lg)

                    // Validation message
                    if !editedAlias.isEmpty {
                        HStack(spacing: 4) {
                            Image(
                                systemName: isAliasValid
                                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(isAliasValid ? .green : .orange)

                            Text(aliasValidationMessage)
                                .font(.caption)
                                .foregroundStyle(isAliasValid ? .green : .orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }

                    // Alias info
                    Text(L10n.Profile.aliasHelper)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    // MARK: - Privacy Disclaimer

    private var privacyDisclaimer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Profile.privacyTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Text(L10n.Profile.privacyDesc)
                .font(.caption)
                .foregroundStyle(.secondary)

            // TODO: Future feature note
            Text(L10n.Profile.aliasFutureNote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .italic()
                .padding(.top, DS.Spacing.sm)
        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    // MARK: - Helpers

    private func loadCurrentValues() {
        editedName = userName
        editedAlias = userAlias

        // Load profile image if exists
        if let imageData = userProfileImageData,
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
        // Save name (trim whitespace and ensure not empty)
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        userName = trimmedName.isEmpty ? "Usuario" : trimmedName

        // Save alias (only if valid or empty)
        if isAliasValid || editedAlias.isEmpty {
            userAlias = editedAlias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        // Save profile image (if user selected one)
        if let uiImage = profileUIImage {
            if let imageData = uiImage.jpegData(compressionQuality: 0.7) {
                userProfileImageData = imageData
            }
        }

        // Dismiss the sheet
        dismiss()
    }
}

#Preview {
    PersonalDetailsView()
}
