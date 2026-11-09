//
//  PersonalToGroupConversionFlow.swift
//  Yala
//
//  «Convertir a gasto compartido» desde Editar de un registro (2.3, pedido de Jürgen del 2026-11-07): un grupo elegible
//  → la revisión del gasto de grupo prellenada con el registro; más de uno → elegir el grupo antes. Es el molde de
//  `DraftGroupConversionFlow` (convertir un borrador de la Bandeja) con una diferencia: aquí el registro ya existe, y al
//  confirmar no se crea otro: pasa a ser la pata real del gasto (`GroupExpenseService.convertPersonalTransaction`).
//

import SwiftData
import SwiftUI

/// Lo que pide el editor al tocar «Convertir a gasto compartido».
struct PersonalToGroupConversionRequest: Identifiable {
    let id = UUID()
    let transaction: TransactionItem
    let groups: [SplitGroup]
}

enum PersonalToGroupConversion {

    /// La revisión del gasto de grupo prellenada con el registro.
    struct FormContext: Identifiable {
        let id = UUID()
        let transaction: TransactionItem
        let group: SplitGroup
        let members: [SplitMember]
        let lookup: [String: String]
        let template: GroupExpensePrefillTemplate
    }

    /// Para elegir el grupo cuando hay más de uno.
    struct PickerData: Identifiable {
        let id = UUID()
        let transaction: TransactionItem
        let groups: [SplitGroup]
        let memberCounts: [UUID: Int]
    }

    /// Miembros, nombres y plantilla para la revisión. `nil` si el grupo no tiene miembros activos o el registro ya no se
    /// puede leer. La plantilla es la de convertir un borrador (`DraftToGroupExpenseTemplateLogic`): importe, moneda,
    /// fecha, cuenta y categoría del registro, reparto en partes iguales entre los miembros activos.
    @MainActor
    static func context(transaction: TransactionItem, group: SplitGroup, modelContext: ModelContext) -> FormContext? {
        guard !transaction.isDeleted, transaction.modelContext != nil,
              !group.isDeleted, group.modelContext != nil else { return nil }
        let members: [SplitMember]
        do {
            members = try GroupService.shared.fetchMembers(for: group, context: modelContext)
        } catch {
            #if DEBUG
            print("PersonalToGroupConversion: Error: fetching members for conversion: \(error)")
            #endif
            return nil
        }
        let activeMembers = members.filter(\.isActive)
        guard !activeMembers.isEmpty else { return nil }
        let lookup = Dictionary(
            members.map { ($0.id.uuidString, $0.resolvedDisplayName) }, uniquingKeysWith: { first, _ in first })
        let template = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: transaction.amount,
            cachedCurrencyCode: transaction.currencyCode,
            note: PersonalToGroupConversionLogic.expenseDescription(
                note: transaction.note, subcategoryName: transaction.subcategory?.name),
            activeMemberIDs: activeMembers.map { $0.id },
            groupCurrencyCode: group.currencyCode,
            accountPrefill: transaction.account,
            date: transaction.date,
            subcategory: transaction.subcategory
        )
        return FormContext(
            transaction: transaction, group: group, members: members, lookup: lookup, template: template)
    }
}

/// El flujo entero, colgado del editor. `request` lo pone el botón; al terminar llama a `onFinished` con el grupo si el
/// registro se pasó, o con `nil` si se canceló (el registro queda intacto).
struct PersonalToGroupConversionFlow: ViewModifier {
    @Binding var request: PersonalToGroupConversionRequest?
    let onFinished: (SplitGroup?) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var picker: PersonalToGroupConversion.PickerData?
    @State private var form: PersonalToGroupConversion.FormContext?
    @State private var convertedTo: SplitGroup?

    func body(content: Content) -> some View {
        content
            .onChange(of: request?.id) { _, id in if id != nil { start() } }
            .sheet(item: $picker) { data in pickerSheet(data) }
            .sheet(item: $form, onDismiss: finish) { ctx in formSheet(ctx) }
    }

    private func start() {
        guard let pending = request else { return }
        request = nil
        if pending.groups.count == 1 {
            form = PersonalToGroupConversion.context(
                transaction: pending.transaction, group: pending.groups[0], modelContext: modelContext)
        } else {
            picker = PersonalToGroupConversion.PickerData(
                transaction: pending.transaction, groups: pending.groups,
                memberCounts: DraftGroupConversion.memberCounts(pending.groups, modelContext: modelContext))
        }
    }

    private func pickerSheet(_ data: PersonalToGroupConversion.PickerData) -> some View {
        GroupPickerSheet(
            groups: data.groups,
            selectedGroupID: nil,
            memberCount: { data.memberCounts[$0.id] ?? 0 },
            opensAtMediumHeight: true
        ) { picked in
            let transaction = data.transaction
            picker = nil
            // Sin apilar la revisión sobre la transición de cierre del selector.
            Task {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                form = PersonalToGroupConversion.context(
                    transaction: transaction, group: picked, modelContext: modelContext)
            }
        }
    }

    private func formSheet(_ ctx: PersonalToGroupConversion.FormContext) -> some View {
        GroupExpenseFormView(
            group: ctx.group,
            members: ctx.members,
            memberNameLookup: ctx.lookup,
            groupChip: .readOnly,
            initialTemplate: ctx.template,
            onSave: {},
            onExpenseCreated: { _ in convertedTo = ctx.group },
            presentsSuccessScreen: false,
            conversionSource: ctx.transaction
        )
    }

    private func finish() {
        let group = convertedTo
        convertedTo = nil
        onFinished(group)
    }
}

extension View {
    /// «Convertir a gasto compartido» para el editor de un registro.
    func personalToGroupConversionFlow(
        _ request: Binding<PersonalToGroupConversionRequest?>, onFinished: @escaping (SplitGroup?) -> Void
    ) -> some View {
        modifier(PersonalToGroupConversionFlow(request: request, onFinished: onFinished))
    }
}
