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
//  Bug de Jürgen del 2026-11-20: guardado el gasto de grupo, la fila seguía en lo leído sin marcarse. El borrador se
//  borra al convertirse, y la pantalla lo buscaba con `isDeleted`, que tras el guardado vuelve a `false`. Ahora el flujo
//  devuelve una copia de lo registrado (`DraftRegisteredInGroup`) y la pantalla la enseña como guardada, sin volver a
//  leer el borrador borrado (`DraftRegisteredInGroupRow`).
//

import SwiftData
import SwiftUI

/// Lo que la hoja pide al tocar «Convertir a gasto compartido».
struct DraftGroupConversionRequest: Identifiable {
    let id = UUID()
    let draft: InboxDraft
    let groups: [SplitGroup]
}

/// Un borrador de foto o voz que terminó como gasto de grupo. El borrador ya no existe, así que la pantalla de lo leído
/// lo pinta con esta copia, tomada antes de borrarlo.
struct DraftRegisteredInGroup: Identifiable, Equatable {
    let id: PersistentIdentifier
    let title: String
    let subcategory: Subcategory?
    /// En positivo: lo que se apuntó en el grupo.
    let amount: Double
    let currencyCode: String
    let groupName: String
}

/// Lo que devuelve el flujo cuando el gasto de grupo se guardó. `nil` si se canceló.
struct DraftGroupConversionOutcome {
    let group: SplitGroup
    let registered: DraftRegisteredInGroup
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

    /// La copia de lo registrado, leída ANTES de borrar el borrador. Lo que el formulario guardó manda (descripción,
    /// importe y moneda del gasto); si el gasto no se encuentra, lo del borrador.
    @MainActor
    static func registered(draft: InboxDraft, group: SplitGroup, expenseID: String) -> DraftRegisteredInGroup {
        let expense = createdExpense(expenseID, in: group)
        let description = expense?.expenseDescription ?? ""
        let title: String
        if !description.isEmpty {
            title = description
        } else if !draft.note.isEmpty {
            title = draft.note
        } else {
            title = draft.subcategory?.name ?? L10n.Common.uncategorized
        }
        return DraftRegisteredInGroup(
            id: draft.persistentModelID,
            title: title,
            subcategory: draft.subcategory,
            amount: abs(expense?.amount ?? draft.amount ?? 0),
            currencyCode: expense?.currencyCode ?? group.currencyCode,
            groupName: group.name
        )
    }

    @MainActor
    private static func createdExpense(_ expenseID: String, in group: SplitGroup) -> SplitExpense? {
        guard let id = UUID(uuidString: expenseID) else { return nil }
        do {
            return try GroupExpenseService.shared.fetchExpenses(for: group).first { $0.id == id }
        } catch {
            #if DEBUG
            print("DraftGroupConversion: Error: fetching the created expense: \(error)")
            #endif
            return nil
        }
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
/// `onConvertToGroupExpense` de la hoja; al terminar (guardado o no) llama a `onFinished` con lo registrado si se guardó.
struct DraftGroupConversionFlow: ViewModifier {
    @Binding var request: DraftGroupConversionRequest?
    let onFinished: (DraftGroupConversionOutcome?) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var picker: DraftGroupConversion.PickerData?
    @State private var form: DraftGroupConversion.FormContext?
    @State private var outcome: DraftGroupConversionOutcome?

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
            onExpenseCreated: { expenseID in
                // La copia antes del borrado: leer el borrador después aborta en el teléfono.
                let registered = DraftGroupConversion.registered(draft: ctx.draft, group: ctx.group, expenseID: expenseID)
                DraftService.shared.handleDraftConvertedToGroupExpense(ctx.draft, context: modelContext)
                outcome = DraftGroupConversionOutcome(group: ctx.group, registered: registered)
            },
            presentsSuccessScreen: false
        )
    }

    private func finish() {
        let finished = outcome
        outcome = nil
        onFinished(finished)
    }
}

extension View {
    /// «Convertir a gasto compartido» para una hoja de borrador presentada fuera de la Bandeja.
    func draftGroupConversionFlow(
        _ request: Binding<DraftGroupConversionRequest?>, onFinished: @escaping (DraftGroupConversionOutcome?) -> Void
    ) -> some View {
        modifier(DraftGroupConversionFlow(request: request, onFinished: onFinished))
    }
}

/// La fila de lo leído que pasó a un gasto de grupo: la misma fila guardada de `VoiceDraftReviewCard` (icono, título,
/// importe y «Guardado»), con el grupo donde quedó como subtítulo. No abre nada: ya no hay borrador que editar, y así no
/// se puede guardar otra vez como personal.
struct DraftRegisteredInGroupRow: View {
    let entry: DraftRegisteredInGroup

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        content
            .padding(.vertical, DS.ListRow.paddingV)
            .padding(.horizontal, DS.ListRow.paddingH)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(.thCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("draft_registered_in_group_row")
    }

    /// Con texto de accesibilidad el importe baja a su línea, como en la fila del borrador.
    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.ListRow.spacing) {
                    ChatDraftCategoryIcon(subcategory: entry.subcategory)
                    texts
                }
                amountColumn(alignment: .leading)
            }
        } else {
            HStack(spacing: DS.ListRow.spacing) {
                ChatDraftCategoryIcon(subcategory: entry.subcategory)
                texts
                Spacer(minLength: DS.Spacing.sm)
                amountColumn(alignment: .trailing)
            }
        }
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.title)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Label(entry.groupName, systemImage: "person.2")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func amountColumn(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: DS.Spacing.xs) {
            Text(appPreferences.currency(entry.amount, currencyCode: entry.currencyCode, forceFullPrecision: true))
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .monospacedDigit()
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(DS.Semantic.successForeground)
                Text(L10n.Chat.Draft.savedBadge)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("draft_registered_in_group_saved")
        }
    }
}
