//
//  GroupExpenseComposerView.swift
//  Yala
//
//  Wrapper para crear un gasto desde el FAB del tab Grupos (sin entrar a un grupo).
//  Sostiene el grupo seleccionado y muestra `GroupExpenseFormView` con `.id(grupo)`
//  para remontarlo limpio al cambiar de grupo (el `GroupExpenseViewModel` deriva
//  moneda/miembros/split/paidBy en su `init` y no soporta cambio en caliente).
//  El chip de grupo (editable si hay >1 elegible) abre `GroupPickerSheet`.
//

import SwiftUI

struct GroupExpenseComposerView: View {

    let groups: [SplitGroup]
    let activeMembers: (SplitGroup) -> [SplitMember]
    let memberNameLookup: (SplitGroup) -> [String: String]
    let memberCount: (SplitGroup) -> Int
    let onSave: () -> Void

    @State private var selectedGroup: SplitGroup
    @State private var showGroupPicker = false

    init(
        groups: [SplitGroup],
        initialGroup: SplitGroup,
        activeMembers: @escaping (SplitGroup) -> [SplitMember],
        memberNameLookup: @escaping (SplitGroup) -> [String: String],
        memberCount: @escaping (SplitGroup) -> Int,
        onSave: @escaping () -> Void
    ) {
        self.groups = groups
        self.activeMembers = activeMembers
        self.memberNameLookup = memberNameLookup
        self.memberCount = memberCount
        self.onSave = onSave
        self._selectedGroup = State(initialValue: initialGroup)
    }

    var body: some View {
        // El `.sheet` cuelga del `Group` (estable); el form va keyed por `.id` para
        // remontar con el grupo nuevo. Así el picker no se desmonta al cambiar grupo.
        Group {
            GroupExpenseFormView(
                group: selectedGroup,
                members: activeMembers(selectedGroup),
                memberNameLookup: memberNameLookup(selectedGroup),
                groupChip: chipMode,
                onSave: onSave
            )
            .id(selectedGroup.id)
        }
        .sheet(isPresented: $showGroupPicker) {
            GroupPickerSheet(
                groups: groups,
                selectedGroupID: selectedGroup.id,
                memberCount: memberCount
            ) { picked in
                selectedGroup = picked
                showGroupPicker = false
            }
            .presentationDetents(DS.Adaptive.sheetDetents([.medium, .large]))
        }
    }

    /// Editable solo si hay más de un grupo elegible (si hay uno solo, no hay a dónde cambiar).
    private var chipMode: GroupContextChipMode {
        groups.count > 1 ? .editable { showGroupPicker = true } : .readOnly
    }
}
