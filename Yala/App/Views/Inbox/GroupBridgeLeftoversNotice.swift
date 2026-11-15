//
//  GroupBridgeLeftoversNotice.swift
//  Yala
//
//  Aviso de la Bandeja: gastos de grupo que ya están en tus registros con su cuenta y a los que les sobra un borrador
//  «Elige cuenta» o un «Préstamo a grupos» repetido (bug del 2026-11-09). Lo de ANTES del arreglo; lo nuevo lo quita
//  la limpieza automática tras cada sincronización (`GroupBridgeRaceCleaner.convergeAfterSync`). Decisión de Jürgen del
//  2026-11-09: «solo lo nuevo + botón», y el botón en la Bandeja.
//
//  El aviso es dueño de su propia hoja (un solo anchor por observable): la Bandeja ya cuelga muchas presentaciones, y
//  una más en su cadena es la que el compilador del CI no tipa a tiempo (regla de `swiftui-ds.md`).
//

import SwiftUI
import SwiftData

struct GroupBridgeLeftoversNotice: View {

    @Environment(\.yalaTheme) private var theme

    /// Gastos afectados. Con 0 no se pinta nada.
    let count: Int
    /// Se quitó lo repetido: la Bandeja recarga.
    let onFixed: () -> Void

    @State private var showsSheet = false

    /// La hoja cuelga de un contenedor que existe SIEMPRE, no del `if`: al confirmar, el contador baja a 0 y el ancla
    /// desaparecería con la hoja aún presentada (`showsSheet` pegado en `true`, regla (1) de presentaciones).
    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            if count > 0 { banner }
        }
        .sheet(isPresented: $showsSheet) {
            GroupBridgeLeftoversSheet(onFixed: onFixed)
        }
    }

    private var banner: some View {
        Button { showsSheet = true } label: {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                Image(systemName: "person.2.badge.minus")
                    .font(DS.Typography.title)
                    .foregroundStyle(theme.accentText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(L10n.Inbox.GroupLeftovers.bannerTitle)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.thPrimaryText)
                        Text("\(count)")
                            .font(DS.Typography.labelSmall.monospacedDigit())
                            .foregroundStyle(.thOnAccent)
                            .padding(.horizontal, DS.Spacing.xs)
                            .background(theme.accent, in: Capsule())
                            .accessibilityIdentifier("inbox_group_leftovers_count")
                    }
                    Text(L10n.Inbox.GroupLeftovers.bannerMessage)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.Inbox.GroupLeftovers.bannerAction)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(theme.accentText)
                        .padding(.top, DS.Spacing.xxs)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("inbox_group_leftovers_banner")
    }
}

/// Qué sobra, gasto por gasto, y el botón que lo quita después de confirmar. Nada se quita sin el «sí».
struct GroupBridgeLeftoversSheet: View {

    let onFixed: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let date: Date?
        let drafts: Int
        let loans: Int
    }

    @State private var rows: [Row] = []
    @State private var confirming = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.Inbox.GroupLeftovers.intro)
                        .font(DS.Typography.body)
                        .accessibilityIdentifier("inbox_group_leftovers_intro")
                }
                Section {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(row.title)
                                .font(DS.Typography.body)
                                .lineLimit(2)
                            if let date = row.date {
                                Text(date, format: .dateTime.day().month().year())
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if row.drafts > 0 {
                                Text(L10n.Inbox.GroupLeftovers.extraDrafts(row.drafts))
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if row.loans > 0 {
                                Text(L10n.Inbox.GroupLeftovers.extraLoans(row.loans))
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("inbox_group_leftovers_row_\(row.id)")
                    }
                }
                if failed {
                    Section {
                        Text(L10n.Inbox.GroupLeftovers.failed)
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("inbox_group_leftovers_failed")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.Inbox.GroupLeftovers.remove, isDisabled: rows.isEmpty) { confirming = true }
                    .accessibilityIdentifier("inbox_group_leftovers_remove")
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.md)
            }
            .navigationTitle(L10n.Inbox.GroupLeftovers.bannerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Action.cancel) { dismiss() }
                        .accessibilityIdentifier("inbox_group_leftovers_cancel")
                }
            }
            .alert(L10n.Inbox.GroupLeftovers.confirmTitle, isPresented: $confirming) {
                Button(L10n.Inbox.GroupLeftovers.confirmAction, role: .destructive) { remove() }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Inbox.GroupLeftovers.confirmMessage)
            }
        }
        .accessibilityIdentifier("inbox_group_leftovers_sheet")
        .onAppear(perform: load)
    }

    private func load() {
        do {
            rows = Self.rows(from: try GroupBridgeRaceCleaner.leftovers(in: modelContext, since: nil))
        } catch {
            #if DEBUG
            print("GroupBridgeLeftoversSheet: Error: \(error)")
            #endif
            // Una lectura fallida no es «no sobra nada»: se dice, y el botón queda apagado sin filas.
            rows = []
            failed = true
        }
    }

    private func remove() {
        do {
            try GroupBridgeRaceCleaner.removeLeftovers(in: modelContext, since: nil)
            DS.Haptic.warning()
            onFixed()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupBridgeLeftoversSheet: Error removing: \(error)")
            #endif
            failed = true
            load()
        }
    }

    /// Una fila por gasto, con lo que se le quita. El nombre y la fecha, del borrador o del préstamo que sobra.
    static func rows(from found: GroupBridgeRaceCleaner.Leftovers) -> [Row] {
        var byExpense: [String: (title: String, date: Date?, drafts: Int, loans: Int)] = [:]
        for index in found.plan.draftIndices {
            let draft = found.drafts[index]
            guard let id = draft.splitExpenseID else { continue }
            var entry = byExpense[id] ?? (draft.note, draft.date, 0, 0)
            entry.drafts += 1
            byExpense[id] = entry
        }
        for index in found.plan.legIndices {
            let leg = found.legs[index]
            guard let id = leg.splitExpenseID else { continue }
            var entry = byExpense[id] ?? (leg.note ?? "", leg.date, 0, 0)
            if entry.title.isEmpty { entry.title = leg.note ?? "" }
            entry.loans += 1
            byExpense[id] = entry
        }
        return byExpense
            .map { Row(id: $0.key, title: $0.value.title, date: $0.value.date, drafts: $0.value.drafts, loans: $0.value.loans) }
            .sorted { ($0.date ?? .distantPast, $0.id) > ($1.date ?? .distantPast, $1.id) }
    }
}
