//
//  ImportarGrupoPendiente.swift
//  Yala
//
//  Dentro del grupo: el aviso «Faltan saldos de Splitwise · Por emparejar: Ana, Luis» y la hoja para decir quién es cada
//  persona del export entre los miembros que ya se unieron. Solo lo ve quien puede poner saldos iniciales (dueño o admin)
//  y en el teléfono donde se hizo el import (Paso 0 del ticket `groups-import-splitwise-tricount`).
//
//  El aviso es la única pieza que se cuelga del detalle del grupo, y es dueño de su hoja: así `GroupDetailView` solo gana
//  una línea.
//

import SwiftUI

struct ImportarGrupoPendienteBanner: View {
    let group: SplitGroup
    let activeMembers: [SplitMember]
    let canManage: Bool
    /// Tras poner saldos: quien monta el aviso recarga el grupo.
    var onApplied: () -> Void

    @State private var store = PendingGroupImportStore.shared
    @State private var showsSheet = false

    var body: some View {
        if ImportarGrupoUITestSeams.seedsPending, canManage, store.pending(for: group.cloudKitZoneID) == nil {
            // Solo XCUITest: un marcador propio para que la siembra corra aunque el aviso aún no se pinte.
            Color.clear.frame(width: 1, height: 1)
                .task { ImportarGrupoUITestSeams.seedPendingIfRequested(group: group, activeMembers: activeMembers) }
        }
        if canManage, !group.isMigratedFrozen, let pending = store.pending(for: group.cloudKitZoneID) {
            let missing = pending.pendingPeople
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                Image(systemName: "person.2.badge.gearshape.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thAccentText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.ImportarGrupo.pendingBannerTitle(L10n.ImportarGrupo.sourceName(pending.source)))
                        .font(DS.Typography.subheadlineEmphasized)
                    if !missing.isEmpty {
                        Text(L10n.ImportarGrupo.pendingBannerBody(missing.formatted(.list(type: .and).locale(AppLocale.current))))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: DS.Spacing.sm)
                Button(L10n.ImportarGrupo.pendingBannerAction) { showsSheet = true }
                    .font(DS.Typography.label.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("group_import_pending_match")
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(.thAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("group_import_pending_banner")
            .sheet(isPresented: $showsSheet, onDismiss: onApplied) {
                ImportarGrupoEmparejarView(group: group, activeMembers: activeMembers, pending: pending)
            }
        }
    }
}

struct ImportarGrupoEmparejarView: View {
    let group: SplitGroup
    let activeMembers: [SplitMember]

    @Environment(\.dismiss) private var dismiss
    @State private var mapping: [String: String]
    @State private var applied: Set<String>
    @State private var showsFailed = false
    @State private var showsDiscard = false
    private let pending: PendingGroupImport

    init(group: SplitGroup, activeMembers: [SplitMember], pending: PendingGroupImport) {
        self.group = group
        self.activeMembers = activeMembers
        self.pending = pending
        // Lo que ya estaba emparejado manda; a quien falta se le propone el miembro con su mismo nombre, si es uno solo.
        let withDebts = Set(pending.debts.flatMap { [$0.debtor, $0.creditor] })
        let suggested = ImportedDebtPlanLogic.suggestedMatches(
            people: pending.people.filter(withDebts.contains),
            members: activeMembers.map { ($0.id.uuidString, $0.displayName) },
            alreadyMapped: pending.mapping)
        _mapping = State(initialValue: pending.mapping.merging(suggested) { current, _ in current })
        _applied = State(initialValue: pending.applied)
    }

    private var activeIDs: Set<String> { Set(activeMembers.map { $0.id.uuidString }) }

    /// Personas con saldo, en el orden del export.
    private var people: [String] {
        let withDebts = Set(pending.debts.flatMap { [$0.debtor, $0.creditor] })
        return pending.people.filter(withDebts.contains)
    }

    private var readyCount: Int {
        ImportedDebtPlanLogic.applicable(
            debts: pending.debts, mapping: mapping, applied: applied, activeMemberIDs: activeIDs).count
    }

    /// Alguna de sus aristas ya se creó.
    private func hasApplied(_ person: String) -> Bool {
        pending.debts.contains { ($0.debtor == person || $0.creditor == person) && applied.contains($0.id) }
    }

    private func memberName(for person: String) -> String {
        guard let id = mapping[person], let member = activeMembers.first(where: { $0.id.uuidString == id }) else {
            return person
        }
        return member.resolvedDisplayName
    }

    /// Una persona ya tiene todo puesto: ninguna de sus aristas espera.
    private func isDone(_ person: String) -> Bool {
        pending.debts.filter { $0.debtor == person || $0.creditor == person }.allSatisfy { applied.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.ImportarGrupo.matchIntro)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.xs)

                    VStack(spacing: DS.Spacing.none) {
                        ForEach(Array(people.enumerated()), id: \.element) { index, person in
                            if index > 0 { Divider() }
                            personRow(person)
                        }
                    }
                    .solidCard()

                    Text(L10n.ImportarGrupo.matchWaitingFooter)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.xs)

                    Button(L10n.ImportarGrupo.matchDiscard, role: .destructive) { showsDiscard = true }
                        .font(DS.Typography.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .padding(.horizontal, DS.Spacing.xs)
                        .accessibilityIdentifier("group_import_discard")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .readableColumn()
            }
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.ImportarGrupo.matchTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.cancel) { dismiss() }
                        .accessibilityIdentifier("group_import_match_close")
                }
            }
            .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.ImportarGrupo.matchApply, isDisabled: readyCount == 0,
                                  keepsDisabledToneInBar: true) { apply() }
                    .accessibilityIdentifier("group_import_apply")
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.sm)
            }
            .alert(L10n.Common.error, isPresented: $showsFailed) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(L10n.ImportarGrupo.matchFailed)
            }
            // Dos botones sin rol (regla de `swiftui-ds.md`: la salida de «no hacer nada» tiene que verse).
            .alert(L10n.ImportarGrupo.matchDiscardTitle, isPresented: $showsDiscard) {
                Button(L10n.Action.cancel) {}
                Button(L10n.ImportarGrupo.matchDiscard, role: .destructive) { discard() }
            } message: {
                Text(L10n.ImportarGrupo.matchDiscardBody)
            }
        }
    }

    private func personRow(_ person: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(person)
                    .font(DS.Typography.body)
                ForEach(balances(of: person), id: \.currency) { item in
                    HStack(spacing: DS.Spacing.xs) {
                        Text(item.cents > 0 ? L10n.ImportarGrupo.previewOwed : L10n.ImportarGrupo.previewOwes)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                        AmountText(value: Double(abs(item.cents)) / 100, currencyCode: item.currency,
                                   font: DS.Typography.captionSmall, secondaryFont: DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: DS.Spacing.sm)
            if isDone(person) || hasApplied(person) {
                // Con algún saldo ya puesto, la persona queda atada a su miembro: cambiarlo repartiría su saldo entre
                // dos miembros (revisión del 2026-11-16).
                Label(isDone(person) ? L10n.ImportarGrupo.matchDone : memberName(for: person),
                      systemImage: isDone(person) ? "checkmark.circle.fill" : "lock.fill")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            } else {
                Picker(L10n.ImportarGrupo.matchPickerLabel(person), selection: $mapping[person]) {
                    Text(L10n.ImportarGrupo.matchNotYet).tag(String?.none)
                    ForEach(choices(for: person), id: \.id) { member in
                        Text(member.resolvedDisplayName).tag(String?.some(member.id.uuidString))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel(L10n.ImportarGrupo.matchPickerLabel(person))
                .accessibilityIdentifier("group_import_match_\(person)")
            }
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    /// El saldo de una persona en cada moneda distinta de cero.
    private func balances(of person: String) -> [(currency: String, cents: Int)] {
        pending.balances.keys.sorted().compactMap { currency in
            guard let cents = pending.balances[currency]?[person], cents != 0 else { return nil }
            return (currency, cents)
        }
    }

    /// Miembros que se pueden elegir para una persona: los activos que no tiene ya otra persona.
    private func choices(for person: String) -> [SplitMember] {
        let takenByOthers = Set(mapping.filter { $0.key != person }.values)
        return activeMembers.filter { !takenByOthers.contains($0.id.uuidString) }
    }

    private func apply() {
        let outcome = PendingGroupImportApplier.apply(
            zoneID: group.cloudKitZoneID,
            mapping: mapping,
            activeMemberIDs: activeIDs,
            create: PendingGroupImportApplier.liveCreate(in: group))
        applied = PendingGroupImportStore.shared.pending(for: group.cloudKitZoneID)?.applied
            ?? Set(pending.debts.map(\.id))
        if outcome.failed {
            DS.Haptic.error()
            showsFailed = true
            return
        }
        DS.Haptic.success()
        if outcome.isComplete { dismiss() }
    }

    private func discard() {
        DS.Haptic.warning()
        PendingGroupImportStore.shared.remove(zoneID: group.cloudKitZoneID)
        dismiss()
    }
}
