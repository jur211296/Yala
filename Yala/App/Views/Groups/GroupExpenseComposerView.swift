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
//  Compartido (lote 3, 26-nov-2026): el selector es «¿Con quién?»: grupos, personas y «Escribir un nombre». Una persona
//  nueva se da de alta en el servidor al confirmar su nombre (aquí ya hay cuenta: sin ella no habría a quién apuntar) y
//  el formulario pasa a ella con lo escrito, como al cambiar de grupo.
//

import SwiftData
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
    /// Personas creadas desde «¿Con quién?» mientras el formulario estaba abierto.
    @State private var createdPeople: [SplitGroup] = []
    @State private var pendingNewPersonName: String?
    @State private var personError: String?
    @State private var showsPersonError = false
    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences

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
        .sheet(isPresented: $showGroupPicker, onDismiss: createPendingPerson) {
            GroupPickerSheet(
                groups: groups + createdPeople,
                selectedGroupID: selectedGroup.id,
                memberCount: memberCount,
                onNewPerson: { name in
                    pendingNewPersonName = name
                    showGroupPicker = false
                },
                opensAtMediumHeight: true
            ) { picked in
                if picked.id != selectedGroup.id {
                    carriedOver = pendingCarryOver
                }
                selectedGroup = picked
                showGroupPicker = false
            }
        }
        .alert(L10n.Common.error, isPresented: $showsPersonError) {
            Button(L10n.Common.ok) { personError = nil }
        } message: {
            Text(personError ?? "")
        }
    }

    /// «Escribir un nombre» en «¿Con quién?»: la persona se crea al cerrarse el selector y el formulario pasa a ella con
    /// lo escrito. Si falla, lo escrito se queda en el grupo de antes.
    private func createPendingPerson() {
        guard let name = pendingNewPersonName else { return }
        pendingNewPersonName = nil
        Task {
            do {
                let person = try await CompartidoPersonaAlta.crear(
                    nombre: name, moneda: appPreferences.defaultCurrencyCode.rawValue, contexto: modelContext)
                createdPeople.append(person)
                carriedOver = pendingCarryOver
                selectedGroup = person
                DS.Haptic.success()
            } catch {
                #if DEBUG
                print("GroupExpenseComposerView: Error creating person: \(error)")
                #endif
                DS.Haptic.error()
                personError = GroupActionErrorLogic.message(for: error)
                showsPersonError = true
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
