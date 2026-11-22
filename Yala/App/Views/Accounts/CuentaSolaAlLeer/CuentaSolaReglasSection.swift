//
//  CuentaSolaReglasSection.swift
//  Yala
//
//  «Reglas de captura» en Editar cuenta (parte 2 de la cuenta sola al leer, 2026-11-21): una fila por regla (abre el
//  editor), «Añadir regla» y el pie que dice qué hacen. El editor y la pregunta de regla repetida cuelgan de aquí, en su
//  propio modificador, para no engordar el `body` de `AccountFormView`.
//

import SwiftUI

struct CuentaSolaReglasSection: View {
    @Bindable var viewModel: AccountFormViewModel
    @State private var editing: EditorTarget?
    @State private var duplicate: Duplicate?
    @State private var showsDuplicate = false

    /// Qué abre el editor: una regla nueva o una que ya existe.
    struct EditorTarget: Identifiable {
        let id = UUID()
        let rule: AccountCaptureRule?
    }

    private struct Duplicate {
        let rule: AccountCaptureRule
        let other: Account
    }

    private var accountName: String {
        let name = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? (viewModel.accountToEdit?.name ?? "") : name
    }

    var body: some View {
        SectionBox(title: L10n.CuentaSolaAlLeer.Rules.section) {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                ForEach(viewModel.captureRules) { rule in
                    ruleRow(rule)
                    SubsectionDivider()
                }
                addRow
                Text(L10n.CuentaSolaAlLeer.Rules.footer)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .accessibilityIdentifier("account_capture_rules_footer")
            }
        }
        // Sin identificador en el contenedor: pisaría el de sus filas (`testing.md`).
        // La pregunta de regla repetida sale al cerrarse el editor: dos presentaciones a la vez se pierden.
        .sheet(item: $editing, onDismiss: { if duplicate != nil { showsDuplicate = true } }) { target in
            CuentaSolaReglaEditor(
                original: target.rule, accountName: accountName,
                onSave: save, onDelete: target.rule.map { rule in { viewModel.deleteCaptureRule(id: rule.id) } })
        }
        .alert(L10n.CuentaSolaAlLeer.Duplicate.title, isPresented: $showsDuplicate) {
            Button(L10n.CuentaSolaAlLeer.Duplicate.move) { moveDuplicate() }
            Button(L10n.Action.cancel, role: .cancel) { duplicate = nil }
        } message: {
            Text(duplicateMessage)
        }
    }

    private func ruleRow(_ rule: AccountCaptureRule) -> some View {
        Button {
            editing = EditorTarget(rule: rule)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon(for: rule.kind))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(L10n.CuentaSolaAlLeer.Rules.row(rule))
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("account_capture_rule_row")
    }

    private var addRow: some View {
        Button {
            editing = EditorTarget(rule: nil)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "plus.circle")
                    .font(DS.Typography.body)
                    .accessibilityHidden(true)
                Text(L10n.CuentaSolaAlLeer.Rules.add)
                    .font(DS.Typography.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.thAccentText)
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("account_capture_rules_add")
    }

    private func icon(for kind: AccountCaptureRule.Kind) -> String {
        switch kind {
        case .applePayCard: return "wave.3.right.circle"
        case .text: return "text.magnifyingglass"
        case .merchant: return "storefront"
        }
    }

    // MARK: - Guardar

    private func save(_ rule: AccountCaptureRule) {
        if let other = viewModel.captureRuleDuplicate(for: rule) {
            duplicate = Duplicate(rule: rule, other: other)
            return
        }
        viewModel.upsertCaptureRule(rule)
    }

    private func moveDuplicate() {
        guard let duplicate else { return }
        viewModel.moveCaptureRule(duplicate.rule, from: duplicate.other)
        self.duplicate = nil
    }

    private var duplicateMessage: String {
        guard let duplicate else { return "" }
        return L10n.CuentaSolaAlLeer.Duplicate.message(from: duplicate.other.name, to: accountName)
    }
}
