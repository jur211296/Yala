//
//  DraftGroupConversionFlow.swift
//  Yala
//
//  «Convertir a gasto compartido» desde la hoja de un borrador (`InboxDraftEditSheet`): 1 grupo elegible → el formulario
//  de gasto de grupo prellenado; más de uno → elegir el grupo antes. Al guardar el gasto, el borrador se borra.
//
//  La Bandeja tenía el flujo (`InboxView`); las pantallas de imagen y de voz abrían la misma hoja sin él, así que el botón
//  salía y no hacía nada (bug de Jürgen del 2026-11-03: «desde la edición de un registro que entró por imagen o voz no se
//  puede convertir a gasto compartido»). Este modificador es ese flujo para quien presenta la hoja fuera de la Bandeja, y
//  el contexto del formulario (`DraftGroupConversion.context`) es el mismo para los tres.
//

import SwiftData
import SwiftUI

/// Lo que la hoja pide al tocar «Convertir a gasto compartido».
struct DraftGroupConversionRequest: Identifiable {
    let id = UUID()
    let draft: InboxDraft
    let groups: [SplitGroup]
}

enum DraftGroupConversion {

    /// El formulario de grupo prellenado con el borrador.
    struct FormContext: Identifiable {
        let id = UUID()
        let draft: InboxDraft
        let group: SplitGroup
        let members: [SplitMember]
        let lookup: [String: String]
        let template: GroupExpensePrefillTemplate
    }

    /// Para elegir el grupo cuando hay más de uno.
    struct PickerData: Identifiable {
        let id = UUID()
        let draft: InboxDraft
        let groups: [SplitGroup]
        let memberCounts: [UUID: Int]
    }

    /// Miembros, nombres y plantilla para abrir el formulario de grupo desde un borrador personal. `nil` si el grupo no
    /// tiene miembros activos.
    @MainActor
    static func context(draft: InboxDraft, group: SplitGroup, modelContext: ModelContext) -> FormContext? {
        let members: [SplitMember]
        do {
            members = try GroupService.shared.fetchMembers(for: group, context: modelContext)
        } catch {
            #if DEBUG
            print("DraftGroupConversion: Error: fetching members for conversion: \(error)")
            #endif
            return nil
        }
        let activeMembers = members.filter(\.isActive)
        guard !activeMembers.isEmpty else { return nil }
        let lookup = Dictionary(
            members.map { ($0.id.uuidString, $0.resolvedDisplayName) }, uniquingKeysWith: { first, _ in first })
        let template = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: draft.amount ?? 0,
            cachedCurrencyCode: draft.cachedCurrencyCode,
            note: draft.note,
            activeMemberIDs: activeMembers.map { $0.id },
            groupCurrencyCode: group.currencyCode,
            accountPrefill: draft.account,
            // `effectiveDate`: `date` es opcional y su fallback (`createdAt`) es el que el resto del Inbox usa.
            date: draft.effectiveDate,
            subcategory: draft.subcategory
        )
        return FormContext(draft: draft, group: group, members: members, lookup: lookup, template: template)
    }

    /// UX 2.2 · L13-11: el aviso de adónde fue el borrador, con «Ver» que lleva al grupo (el mismo de la Bandeja).
    /// `dismissHost` cierra la pantalla que presentó la hoja antes de ir al grupo.
    @MainActor
    static func announce(_ group: SplitGroup, navigation: SceneNavigation, dismissHost: @escaping () -> Void) {
        let groupID = group.id.uuidString
        DraftDiscardUndoNotice.show(
            message: L10n.Inbox.movedToGroup(group.name),
            systemImage: "person.2",
            undoTitle: L10n.Inbox.movedToGroupView,
            noticeIdentifier: "inbox_moved_to_group_notice",
            undoIdentifier: "inbox_moved_to_group_view"
        ) {
            dismissHost()
            navigation.pendingGroupID = groupID
            navigation.selectMainTab(.groups)
        }
    }

    /// Los miembros activos de cada grupo, para el selector.
    @MainActor
    static func memberCounts(_ groups: [SplitGroup], modelContext: ModelContext) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for group in groups {
            do {
                counts[group.id] = try GroupService.shared.fetchMembers(for: group, context: modelContext)
                    .filter(\.isActive).count
            } catch {
                #if DEBUG
                print("DraftGroupConversion: Error: counting members for the picker: \(error)")
                #endif
                counts[group.id] = 0
            }
        }
        return counts
    }
}

/// El flujo entero, para una pantalla que presenta `InboxDraftEditSheet` fuera de la Bandeja. `request` lo pone el
/// `onConvertToGroupExpense` de la hoja; al terminar (guardado o no) llama a `onFinished` con el grupo si se guardó.
struct DraftGroupConversionFlow: ViewModifier {
    @Binding var request: DraftGroupConversionRequest?
    let onFinished: (SplitGroup?) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var picker: DraftGroupConversion.PickerData?
    @State private var form: DraftGroupConversion.FormContext?
    @State private var convertedTo: SplitGroup?

    func body(content: Content) -> some View {
        content
            .onChange(of: request?.id) { _, id in if id != nil { start() } }
            .sheet(item: $picker) { data in pickerSheet(data) }
            .sheet(item: $form, onDismiss: finish) { ctx in formSheet(ctx) }
    }

    /// Tras cerrarse la hoja del borrador (que se cierra sola al tocar el botón): sin apilar sobre su transición.
    private func start() {
        guard let pending = request else { return }
        request = nil
        Task {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            if pending.groups.count == 1 {
                form = DraftGroupConversion.context(draft: pending.draft, group: pending.groups[0], modelContext: modelContext)
            } else {
                picker = DraftGroupConversion.PickerData(
                    draft: pending.draft, groups: pending.groups,
                    memberCounts: DraftGroupConversion.memberCounts(pending.groups, modelContext: modelContext))
            }
        }
    }

    private func pickerSheet(_ data: DraftGroupConversion.PickerData) -> some View {
        GroupPickerSheet(
            groups: data.groups,
            selectedGroupID: nil,
            memberCount: { data.memberCounts[$0.id] ?? 0 },
            opensAtMediumHeight: true
        ) { picked in
            let draft = data.draft
            picker = nil
            Task {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                form = DraftGroupConversion.context(draft: draft, group: picked, modelContext: modelContext)
            }
        }
    }

    private func formSheet(_ ctx: DraftGroupConversion.FormContext) -> some View {
        GroupExpenseFormView(
            group: ctx.group,
            members: ctx.members,
            memberNameLookup: ctx.lookup,
            groupChip: .readOnly,
            initialTemplate: ctx.template,
            onSave: {},
            onExpenseCreated: { _ in
                DraftService.shared.handleDraftConvertedToGroupExpense(ctx.draft, context: modelContext)
                convertedTo = ctx.group
            },
            presentsSuccessScreen: false
        )
    }

    private func finish() {
        let group = convertedTo
        convertedTo = nil
        onFinished(group)
    }
}

extension View {
    /// «Convertir a gasto compartido» para una hoja de borrador presentada fuera de la Bandeja.
    func draftGroupConversionFlow(
        _ request: Binding<DraftGroupConversionRequest?>, onFinished: @escaping (SplitGroup?) -> Void
    ) -> some View {
        modifier(DraftGroupConversionFlow(request: request, onFinished: onFinished))
    }
}
