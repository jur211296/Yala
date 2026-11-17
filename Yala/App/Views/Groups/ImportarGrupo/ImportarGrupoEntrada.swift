//
//  ImportarGrupoEntrada.swift
//  Yala
//
//  «Traer un grupo de Splitwise o Tricount» dentro de Crear grupo. Sin elegir nada es un botón; con un archivo leído y
//  aceptado es una tarjeta con el origen y «Quitar». Lo elegido vive en quien la monta (`GroupFormView`), que al crear
//  el grupo llama a `ImportarGrupoSeleccion.start(in:)`.
//

import SwiftData
import SwiftUI

/// Lo que la persona aceptó en la vista previa: el archivo leído y quién es ella en él (`nil`: no está en el grupo).
struct ImportarGrupoSeleccion: Equatable {
    let snapshot: ImportedGroupSnapshot
    let me: String?

    /// La moneda que se propone al grupo: la que más mueve el export, si Yala la tiene.
    var suggestedCurrency: CurrencyCode? {
        snapshot.currencies.first.flatMap { CurrencyCode(rawValue: $0) }
    }

    /// Recién creado el grupo: apunta lo que espera y empareja a «yo» con el miembro de quien lo creó.
    @MainActor
    func start(in group: SplitGroup) {
        let zoneID = group.cloudKitZoneID
        let members: [SplitMember]
        do {
            members = try GroupService.shared.fetchMembers(for: group)
        } catch {
            #if DEBUG
            print("ImportarGrupoSeleccion: Error: \(error)")
            #endif
            members = []
        }
        let owner = members.first(where: \.isCurrentUser) ?? GroupService.shared.currentUserMember(zoneID: zoneID)
        PendingGroupImportApplier.start(
            snapshot: snapshot,
            me: me,
            zoneID: zoneID,
            ownerMemberID: owner?.id.uuidString,
            activeMemberIDs: Set(members.filter(\.isActive).map { $0.id.uuidString }),
            create: PendingGroupImportApplier.liveCreate(in: group)
        )
    }
}

struct ImportarGrupoEntrada: View {
    @Binding var selection: ImportarGrupoSeleccion?
    /// Al aceptar un archivo: quien monta la entrada rellena el nombre y la moneda del grupo.
    var onChosen: (ImportarGrupoSeleccion) -> Void

    @Environment(\.yalaTheme) private var theme
    @State private var showsSheet = false

    var body: some View {
        Group {
            if let selection {
                chosenCard(selection)
            } else {
                entryButton
            }
        }
        .sheet(isPresented: $showsSheet) {
            ImportarGrupoHoja { chosen in
                selection = chosen
                onChosen(chosen)
            }
        }
    }

    private var entryButton: some View {
        Button {
            showsSheet = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "square.and.arrow.down")
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thAccentText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.ImportarGrupo.entryTitle)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                    Text(L10n.ImportarGrupo.entrySubtitle)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .solidCard()
        .accessibilityIdentifier("group_import_entry")
    }

    private func chosenCard(_ chosen: ImportarGrupoSeleccion) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.title3)
                .foregroundStyle(.thAccentText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.ImportarGrupo.entryChosenTitle(L10n.ImportarGrupo.sourceName(chosen.snapshot.source)))
                    .font(DS.Typography.subheadlineEmphasized)
                Text(L10n.ImportarGrupo.entryChosenSubtitle)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Spacing.sm)
            Button(L10n.ImportarGrupo.entryRemove) {
                selection = nil
            }
            .font(DS.Typography.label.weight(.semibold))
            .foregroundStyle(.thAccentText)
            .frame(minHeight: 44)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("group_import_remove")
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
        .solidCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_import_chosen")
    }
}
