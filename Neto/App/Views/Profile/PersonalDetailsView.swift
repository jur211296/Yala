//
//  PersonalDetailsView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

/// View for editing personal user details
struct PersonalDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("userSex") private var userSex: String = ""
    @AppStorage("userBirthday") private var userBirthdayRaw: String = ""

    @State private var editedName: String = ""
    @State private var editedSex: String = ""
    @State private var editedBirthday: Date = Date()
    @State private var showBirthdayPicker: Bool = false
    @State private var hasBirthday: Bool = false

    private let sexOptions = ["", "Masculino", "Femenino", "Otro", "Prefiero no decir"]

    private var birthdayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: editedBirthday)
    }

    private var ageString: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year], from: editedBirthday, to: now)
        if let years = components.year, years > 0 {
            return "\(years) años"
        }
        return ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar header
                        avatarHeader

                        // Details form
                        detailsSection

                        // Privacy disclaimer
                        privacyDisclaimer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Detalles personales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetTopButton(systemName: "chevron.left") {
                        saveAndDismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }

    // MARK: - Avatar Header

    private var avatarHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.electricIndigo.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.electricIndigo)
            }

            Button("Editar foto") {
                // Placeholder for photo picker
            }
            .font(.subheadline)
            .foregroundStyle(Color.electricIndigo)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        SectionBox(title: "") {
            VStack(spacing: 0) {
                // Name row
                HStack {
                    Text("Nombre")
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField("Tu nombre", text: $editedName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.primary)
                }
                .padding(16)

                SubsectionDivider()

                // Sex row
                HStack {
                    Text("Sexo")
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $editedSex) {
                        ForEach(sexOptions, id: \.self) { option in
                            Text(option.isEmpty ? "Sin especificar" : option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                SubsectionDivider()

                // Birthday/Age row
                Button {
                    showBirthdayPicker.toggle()
                } label: {
                    HStack {
                        Text("Edad")
                            .foregroundStyle(.primary)
                        Spacer()
                        if hasBirthday {
                            Text(ageString)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Sin especificar")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                if showBirthdayPicker {
                    VStack(spacing: 8) {
                        DatePicker(
                            "Cumpleaños",
                            selection: $editedBirthday,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .onChange(of: editedBirthday) { _, _ in
                            hasBirthday = true
                        }

                        if hasBirthday {
                            Button("Quitar fecha") {
                                hasBirthday = false
                                userBirthdayRaw = ""
                            }
                            .font(.footnote)
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Privacy Disclaimer

    private var privacyDisclaimer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tus datos nunca salen de tu dispositivo")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Text(
                "Neto almacena tus datos personales únicamente en tu dispositivo. No tenemos acceso a ellos ni los compartimos con terceros. Si eliminas la app, se borrarán todos tus datos."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Helpers

    private func loadCurrentValues() {
        editedName = userName
        editedSex = userSex

        if !userBirthdayRaw.isEmpty {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: userBirthdayRaw) {
                editedBirthday = date
                hasBirthday = true
            }
        }
    }

    private func saveAndDismiss() {
        // Save changes
        userName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if userName.isEmpty {
            userName = "Usuario"
        }
        userSex = editedSex

        if hasBirthday {
            let formatter = ISO8601DateFormatter()
            userBirthdayRaw = formatter.string(from: editedBirthday)
        }

        dismiss()
    }
}

#Preview {
    PersonalDetailsView()
}
