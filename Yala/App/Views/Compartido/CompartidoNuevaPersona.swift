//
//  CompartidoNuevaPersona.swift
//  Yala
//
//  Compartido (lote 3, 26-nov-2026): escribir el nombre de una persona nueva. Una sola pieza para los dos sitios donde
//  se da de alta a alguien: «Escribir un nombre» dentro de «¿Con quién?» (el selector de Grupos, `GroupPickerSheet`) y
//  «Añadir persona» de la barra del chip Personas. No es una pantalla de captura: Nuevo gasto, Voz, Foto e Yala IA son
//  las de Grupos (punto 6 de Jürgen).
//

import SwiftUI

/// «+ Escribir un nombre»: plegado, una fila; al tocarla, el campo, «Añadir» y la nota de que no hace falta que tenga
/// Yala. Con `alwaysOpen` arranca abierto y con el foco (la hoja de «Añadir persona»).
struct CompartidoNewPersonBox: View {
    @Binding var isWriting: Bool
    @Binding var name: String
    var focused: FocusState<Bool>.Binding
    var alwaysOpen = false
    var isBusy = false
    let onAdd: () -> Void

    @Environment(\.yalaTheme) private var theme

    private var canAdd: Bool { CompartidoPersonaAltaLogic.cleanName(name) != nil && !isBusy }

    var body: some View {
        SectionBox(title: "") {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if isWriting || alwaysOpen {
                    HStack(spacing: DS.Spacing.sm) {
                        TextField(L10n.Compartido.namePlaceholder, text: $name)
                            .font(DS.Typography.body)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused(focused)
                            .onSubmit { if canAdd { onAdd() } }
                            .accessibilityIdentifier("compartido_new_person_field")
                        Button {
                            onAdd()
                        } label: {
                            Group {
                                if isBusy {
                                    ProgressView()
                                } else {
                                    Text(L10n.Compartido.addAction)
                                        .font(DS.Typography.label)
                                }
                            }
                            .foregroundStyle(canAdd ? theme.onAccent : .secondary)
                            .padding(.horizontal, DS.Spacing.md)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(canAdd ? theme.accent : Color.secondary.opacity(0.15)))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdd)
                        .accessibilityIdentifier("compartido_new_person_add")
                    }
                    Text(L10n.Compartido.newPersonHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button {
                        DS.Haptic.selection()
                        isWriting = true
                        focused.wrappedValue = true
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "person.badge.plus")
                                .font(DS.Typography.headline)
                                .foregroundStyle(.thAccentText)
                                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                            Text(L10n.Compartido.writeName)
                                .font(DS.Typography.body)
                                .foregroundStyle(.thAccentText)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("compartido_write_name")
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
    }
}

/// «Añadir persona» (barra del chip Personas): el nombre y nada más. Quien la presenta crea la persona y, al cerrarse,
/// enseña la hoja de invitar (`GroupCreatedInviteSheet`, con su texto de persona).
struct CompartidoAddPersonSheet: View {
    let isBusy: Bool
    /// El error del alta, dentro de la hoja (una alerta de la pestaña no saldría con la hoja delante).
    var errorMessage: String?
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isWriting = true
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.Compartido.addPersonMessage)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    CompartidoNewPersonBox(
                        isWriting: $isWriting, name: $name, focused: $focused, alwaysOpen: true, isBusy: isBusy
                    ) {
                        guard let clean = CompartidoPersonaAltaLogic.cleanName(name) else { return }
                        onAdd(clean)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.errorForeground)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("compartido_add_person_error")
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .yalaScreenBackground(.partialSheet)
            .navigationTitle(L10n.Compartido.addPerson)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                        .accessibilityIdentifier("compartido_add_person_close")
                }
            }
            .onAppear { focused = true }
        }
        .dismissKeyboardOnTap()
    }
}

/// «Aún no tienes grupos» / «Apunta un gasto con alguien»: el vacío de cada chip en la entrada sin grupo (maqueta v2,
/// punto 6). El molde es el de `GroupsEmptyStepsCard` sin los pasos: la cuenta se pide al crear, no al entrar.
struct CompartidoEmptyChipCard: View {
    let systemImage: String
    let tint: Color
    let title: String
    let message: String
    let actionTitle: String
    /// El id del botón. En el chip Grupos conserva el de la tarjeta de pasos de cada estado (`groups_empty_state…`):
    /// el botón lleva al mismo sitio (cuenta, consentimiento o el formulario) y las pruebas de esos caminos siguen.
    var actionIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle().fill(tint).frame(width: 44, height: 44) // A11Y-DT: icono decorativo
                Image(systemName: systemImage)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
            Text(title)
                .font(DS.Typography.headline)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionTitle, action: action)
                .font(DS.Typography.label)
                .foregroundStyle(.thAccentText)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityIdentifier(actionIdentifier ?? "compartido_empty_action")
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity)
        .solidCard()
    }
}
