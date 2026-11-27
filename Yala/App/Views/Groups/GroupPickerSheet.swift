//
//  GroupPickerSheet.swift
//  Yala
//
//  Selector de grupo — al crear un gasto desde el FAB del tab Grupos hay que
//  elegir a qué grupo va. Espeja la estructura de `AccountSelectorSheet`.
//  Recibe los grupos ya cargados (no necesita ModelContext).
//
//  Compartido (lote 3, 26-nov-2026): con `onNewPerson` es «¿Con quién?». Las personas (`SplitGroup.isPerson`, un grupo de
//  dos por dentro) salen con su inicial y «Persona», y arriba «Escribir un nombre» da de alta a alguien nuevo. Es la
//  MISMA hoja para Nuevo gasto, Voz, Foto e Yala IA: Jürgen pidió que Personas use las pantallas de Grupos, sin otras.
//

import SwiftUI

struct GroupPickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.usesLargeSheets) private var usesLargeSheets

    let groups: [SplitGroup]
    /// El grupo ya elegido, con su marca. `nil` = ninguno marcado: al convertir un borrador de la Bandeja nadie ha elegido
    /// todavía, y marcar el primero parecía una decisión ya tomada (UX 2.2 · L13-11).
    let selectedGroupID: UUID?
    let memberCount: (SplitGroup) -> Int
    /// `true` = abre a media altura (`[.medium, .large]`) con el fondo de «Configurar panel»: glass del sistema a media
    /// altura, `.subtle` al estirarla. `false` = sin detents propios y `.subtle`, como la presenta Pagos planificados.
    /// Compartido: «Escribir un nombre». Con él la hoja se titula «¿Con quién?» y ofrece dar de alta a una persona; quien
    /// presenta la hoja la cierra y la crea (pide la cuenta si hace falta). `nil` = el selector de grupo de siempre.
    var onNewPerson: ((String) -> Void)? = nil
    var opensAtMediumHeight = false
    let onSelect: (SplitGroup) -> Void

    @State private var selectedDetent: PresentationDetent = .medium
    @State private var isWritingName = false
    @State private var newName = ""
    @FocusState private var nameFocused: Bool

    private var background: YalaBackgroundVariant {
        guard opensAtMediumHeight else { return .subtle }
        return selectedDetent == .large || usesLargeSheets ? .subtle : .transparent
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if onNewPerson != nil {
                        CompartidoNewPersonBox(
                            isWriting: $isWritingName, name: $newName, focused: $nameFocused, onAdd: addPerson)
                    }
                    if !groups.isEmpty {
                        SectionBox(title: "") {
                            VStack(spacing: DS.Spacing.none) {
                                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                    if index > 0 {
                                        SubsectionDivider()
                                    }
                                    GroupPickerRow(
                                        group: group,
                                        subtitle: group.isPerson
                                            ? L10n.Compartido.personSubtitle
                                            : L10n.Groups.Member.activeCount(memberCount(group)),
                                        isSelected: group.id == selectedGroupID
                                    ) {
                                        onSelect(group)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(background)
            .navigationTitle(onNewPerson == nil ? L10n.Groups.selectGroup : L10n.Compartido.whoTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .modifier(GroupPickerDetents(isPartial: opensAtMediumHeight, selection: $selectedDetent))
        .dismissKeyboardOnTap()
    }

    /// «Añadir»: el nombre limpio a quien presenta la hoja. Si ya tienes a alguien con ese nombre, se elige esa persona.
    private func addPerson() {
        guard let name = CompartidoPersonaAltaLogic.cleanName(newName), let onNewPerson else { return }
        let known = groups.map { (id: $0.id, name: $0.name, isPerson: $0.isPerson) }
        if let existing = CompartidoPersonaAltaLogic.existingPerson(named: name, among: known),
           let person = groups.first(where: { $0.id == existing }) {
            onSelect(person)
            return
        }
        DS.Haptic.selection()
        onNewPerson(name)
    }
}

/// Los detents de la hoja cuando abre a media altura; sin ellos, decide quien la presenta.
private struct GroupPickerDetents: ViewModifier {
    let isPartial: Bool
    @Binding var selection: PresentationDetent

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPartial {
            content.yalaSheetDetents([.medium, .large], selection: $selection)
        } else {
            content
        }
    }
}

// MARK: - Group Picker Row

private struct GroupPickerRow: View {
    let group: SplitGroup
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                if group.isPerson {
                    CompartidoPersonAvatar(name: group.name, seed: group.cloudKitZoneID)
                } else {
                    GroupIconBadge(colorHex: group.colorHex, iconName: group.iconName)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(group.name)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thAccentText)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("group_picker_row_\(group.id.uuidString)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
