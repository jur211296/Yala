//
//  GroupExpenseComposerView.swift
//  Yala
//
//  Wrapper para crear un gasto desde el FAB del tab Grupos (sin entrar a un grupo).
//  Sostiene el grupo seleccionado y muestra `GroupExpenseFormView` con `.id(grupo)`
//  para remontarlo al cambiar de grupo (el `GroupExpenseViewModel` deriva
//  moneda/miembros/split/paidBy en su `init` y no soporta cambio en caliente).
//  El chip de grupo (editable si hay >1 elegible) abre `GroupPickerSheet`. Lo escrito
//  viaja al grupo nuevo (decisión 39 de 2.3, F3): el chip lo entrega al tocarlo.
//

import SwiftUI

struct GroupExpenseComposerView: View {

    let groups: [SplitGroup]
    let activeMembers: (SplitGroup) -> [SplitMember]
    let memberNameLookup: (SplitGroup) -> [String: String]
    let memberCount: (SplitGroup) -> Int
    /// L13-8 · aviso arriba del formulario cuando el gasto sigue a la creación del grupo.
    let notice: String?
    /// El reparto de un recibo (Voz o Foto de Grupos). Va por miembros de SU grupo: con él, el grupo no se cambia.
    let receiptSplit: GroupExpensePrefillTemplate?
    let onSave: () -> Void

    @State private var selectedGroup: SplitGroup
    @State private var showGroupPicker = false
    /// Lo escrito al tocar el chip. Solo pasa al formulario si de verdad se cambia de grupo.
    @State private var pendingCarryOver: GroupExpenseCarryOver?
    /// Lo que recibe el formulario del grupo elegido (se monta de nuevo por el `.id`).
    @State private var carriedOver: GroupExpenseCarryOver?

    init(
        groups: [SplitGroup],
        initialGroup: SplitGroup,
        activeMembers: @escaping (SplitGroup) -> [SplitMember],
        memberNameLookup: @escaping (SplitGroup) -> [String: String],
        memberCount: @escaping (SplitGroup) -> Int,
        notice: String? = nil,
        receiptSplit: GroupExpensePrefillTemplate? = nil,
        onSave: @escaping () -> Void
    ) {
        self.groups = groups
        self.activeMembers = activeMembers
        self.memberNameLookup = memberNameLookup
        self.memberCount = memberCount
        self.notice = notice
        self.receiptSplit = receiptSplit
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
                notice: notice,
                onSave: onSave,
                carriedOver: carriedOver,
                receiptSplit: receiptSplit
            )
            .id(selectedGroup.id)
        }
        .sheet(isPresented: $showGroupPicker) {
            GroupPickerSheet(
                groups: groups,
                selectedGroupID: selectedGroup.id,
                memberCount: memberCount,
                opensAtMediumHeight: true
            ) { picked in
                if picked.id != selectedGroup.id {
                    carriedOver = pendingCarryOver
                }
                selectedGroup = picked
                showGroupPicker = false
            }
        }
    }

    /// Editable solo si hay más de un grupo elegible (si hay uno solo, no hay a dónde cambiar).
    private var chipMode: GroupContextChipMode {
        groups.count > 1 && receiptSplit == nil ? .editable { written in
            pendingCarryOver = written
            showGroupPicker = true
        } : .readOnly
    }
}
