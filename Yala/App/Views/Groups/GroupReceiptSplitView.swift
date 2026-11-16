//
//  GroupReceiptSplitView.swift
//  Yala
//
//  La revisión del reparto de un recibo en un grupo (card «Grupos: repartir un recibo con IA», 2.3): lo único que Voz,
//  Foto y Yala IA de Grupos tienen distinto de personal. Desde el 2026-11-16 (encargo «Grupos: voz, foto y Yala IA
//  idénticos a personal») la captura vive en `Groups/Captura/` con las piezas de personal, y esta vista es solo «lo
//  entendido»: las líneas, quién paga cada una, propina, servicio e impuestos, y lo que toca a cada uno. «Usar este
//  reparto» abre Nuevo gasto relleno con importes exactos por persona; el gasto se guarda como cualquier otro.
//
//  Cupo (Jürgen, 2026-11-14): Grupos es el gancho. Sin candado: todo Free reparte 5 recibos al día y Pro 50, con un
//  contador propio (`receipt` en el gateway) que no gasta las fotos y notas de personal.
//
//  Propina, servicio e impuestos NO se reparten solos (Jürgen, 2026-11-05): llegan «sin incluir».
//

import SwiftUI

struct GroupReceiptSplitReview: View {
    @Bindable var model: GroupCaptureModel

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private var members: [SplitMember] { model.members }
    private var items: [ReceiptSplitLine] { model.lines.filter { !$0.kind.isExtra } }
    private var extras: [ReceiptSplitLine] { model.lines.filter(\.kind.isExtra) }
    private var shares: [(memberID: String, amount: Double)] { ReceiptSplitLogic.shares(model.lines, memberIDs: model.memberIDs) }

    /// Hay algo que repartir y nadie sale debiendo de menos (un descuento mayor que lo suyo).
    static func canUse(_ model: GroupCaptureModel) -> Bool {
        let parts = ReceiptSplitLogic.shares(model.lines, memberIDs: model.memberIDs)
        return !parts.isEmpty && !parts.contains { $0.amount < 0 }
    }

    /// Por qué «Usar este reparto» está apagado, o `nil`.
    static func blockedReason(_ model: GroupCaptureModel) -> String? {
        let parts = ReceiptSplitLogic.shares(model.lines, memberIDs: model.memberIDs)
        if parts.isEmpty { return L10n.ReceiptSplit.nothingToSplit }
        if parts.contains(where: { $0.amount < 0 }) { return L10n.ReceiptSplit.negativeShare }
        return nil
    }

    var body: some View {
        List {
            if !model.unmatchedNames.isEmpty {
                Section {
                    Label(
                        L10n.ReceiptSplit.unmatchedNames(model.unmatchedNames.formatted(.list(type: .and))),
                        systemImage: "person.fill.questionmark"
                    )
                    .font(DS.Typography.subheadline)
                    .accessibilityIdentifier("receipt_split_unmatched")
                }
            }

            Section {
                ForEach(items) { line in itemRow(line) }
                    .onDelete { offsets in delete(offsets, in: items) }
            } header: {
                Text(L10n.ReceiptSplit.linesSection)
            } footer: {
                Text(L10n.ReceiptSplit.linesFooter)
            }

            Section {
                ForEach(extras) { line in extraRow(line) }
                    .onDelete { offsets in delete(offsets, in: extras) }
                surchargeMenu
            } header: {
                Text(L10n.ReceiptSplit.extrasSection)
            } footer: {
                Text(L10n.ReceiptSplit.extrasFooter)
            }

            Section {
                ForEach(shares, id: \.memberID) { share in
                    HStack {
                        Text(memberName(share.memberID))
                        Spacer()
                        Text(money(share.amount))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("receipt_split_share_\(memberName(share.memberID))")
                }
                HStack {
                    Text(L10n.ReceiptSplit.total)
                        .font(DS.Typography.headline)
                    Spacer()
                    Text(money(ReceiptSplitLogic.total(model.lines)))
                        .font(DS.Typography.headline)
                        .monospacedDigit()
                        .accessibilityIdentifier("receipt_split_total")
                }
            } header: {
                Text(L10n.ReceiptSplit.perPersonSection)
            } footer: {
                if let mismatch = totalMismatch {
                    Text(mismatch)
                        .accessibilityIdentifier("receipt_split_total_mismatch")
                }
            }
        }
        .scrollContentBackground(.hidden)
        // Las tarjetas se alinean con el título de la hoja (margen de personal) y conservan sus esquinas: con margen
        // cero la lista las pinta rectas. La lista ocupa el ancho entero y pone ella el margen.
        .contentMargins(.horizontal, DS.Spacing.xl, for: .scrollContent)
        .padding(.horizontal, -DS.Spacing.xl)
    }

    private func itemRow(_ line: ReceiptSplitLine) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(line.description)
                    .font(DS.Typography.body)
                Spacer(minLength: DS.Spacing.sm)
                Text(money(line.amount))
                    .monospacedDigit()
            }
            Menu {
                Button {
                    model.setAssignees([], for: line.id)
                } label: {
                    if line.assignees.isEmpty {
                        Label(L10n.ReceiptSplit.everyone, systemImage: "checkmark")
                    } else {
                        Text(L10n.ReceiptSplit.everyone)
                    }
                }
                Section(L10n.ReceiptSplit.whoHadIt) {
                    ForEach(members, id: \.id) { member in
                        Button { model.toggle(member.id.uuidString, in: line.id) } label: {
                            if line.assignees.contains(member.id.uuidString) {
                                Label(member.displayName, systemImage: "checkmark")
                            } else {
                                Text(member.displayName)
                            }
                        }
                    }
                }
            } label: {
                peopleChip(
                    line.assignees.isEmpty ? L10n.ReceiptSplit.everyone : names(line.assignees),
                    flagged: line.needsReview
                )
            }
            .accessibilityIdentifier("receipt_split_people_\(line.description)")
        }
        .accessibilityIdentifier("receipt_split_line_\(line.description)")
    }

    private func extraRow(_ line: ReceiptSplitLine) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(line.description)
                        .font(DS.Typography.body)
                    Text(L10n.ReceiptSplit.kindLabel(line.kind))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Spacing.sm)
                Text((line.kind == .discount ? "−" : "") + money(line.amount))
                    .monospacedDigit()
                    .foregroundStyle(line.isIncluded ? .primary : .secondary)
            }
            Menu {
                shareButton(.excluded, title: L10n.ReceiptSplit.shareExcluded, line: line)
                shareButton(.proportional, title: L10n.ReceiptSplit.shareProportional, line: line)
                shareButton(.equal, title: L10n.ReceiptSplit.shareEqual, line: line)
                Section(L10n.ReceiptSplit.sharePeople) {
                    ForEach(members, id: \.id) { member in
                        Button { model.toggleExtraPerson(member.id.uuidString, in: line.id) } label: {
                            if line.extraShare == .people, line.assignees.contains(member.id.uuidString) {
                                Label(member.displayName, systemImage: "checkmark")
                            } else {
                                Text(member.displayName)
                            }
                        }
                    }
                }
            } label: {
                peopleChip(extraChipText(line), muted: !line.isIncluded)
            }
            .accessibilityIdentifier("receipt_split_extra_\(line.description)")
        }
    }

    private func shareButton(_ share: ReceiptExtraShare, title: String, line: ReceiptSplitLine) -> some View {
        Button {
            model.update(line.id) { $0.extraShare = share; $0.assignees = [] }
        } label: {
            if line.extraShare == share {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    /// Atajos para lo que no venía en el recibo: propina o servicio a un porcentaje del consumo, eligiendo cómo se
    /// reparte (nunca uno por defecto).
    private var surchargeMenu: some View {
        Menu {
            surchargeOption(.tip, percent: 10)
            surchargeOption(.tip, percent: 15)
            surchargeOption(.service, percent: 10)
        } label: {
            Label(L10n.ReceiptSplit.addSurcharge, systemImage: "plus.circle")
        }
        .accessibilityIdentifier("receipt_split_add_surcharge")
    }

    private func surchargeOption(_ kind: ReceiptLineKind, percent: Int) -> some View {
        Menu(L10n.ReceiptSplit.surchargeTitle(kind: kind, percent: percent)) {
            Button(L10n.ReceiptSplit.shareProportional) { model.addSurcharge(kind, percent: percent, share: .proportional) }
            Button(L10n.ReceiptSplit.shareEqual) { model.addSurcharge(kind, percent: percent, share: .equal) }
        }
    }

    private func peopleChip(_ text: String, muted: Bool = false, flagged: Bool = false) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: flagged ? "person.fill.questionmark" : "person.2")
            Text(text)
                .lineLimit(2)
            Image(systemName: "chevron.up.chevron.down")
                .font(DS.Typography.caption)
        }
        .font(DS.Typography.caption)
        .foregroundStyle(muted ? Color.secondary : theme.accentText)
        .padding(.vertical, DS.Spacing.xxs)
        .contentShape(Rectangle())
    }

    private func extraChipText(_ line: ReceiptSplitLine) -> String {
        switch line.extraShare {
        case .excluded: L10n.ReceiptSplit.shareExcluded
        case .proportional: L10n.ReceiptSplit.shareProportional
        case .equal: L10n.ReceiptSplit.shareEqual
        case .people: line.assignees.isEmpty ? L10n.ReceiptSplit.shareExcluded : names(line.assignees)
        }
    }

    private var totalMismatch: String? {
        guard let printedTotal = model.printedTotal else { return nil }
        let read = ReceiptSplitLogic.readTotal(model.lines)
        guard abs(read - printedTotal) >= 0.01 else { return nil }
        return L10n.ReceiptSplit.printedTotalMismatch(printed: money(printedTotal), lines: money(read))
    }

    private func delete(_ offsets: IndexSet, in section: [ReceiptSplitLine]) {
        model.delete(Set(offsets.map { section[$0].id }))
    }

    // MARK: - Formato

    private func money(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: model.effectiveCurrency, forceFullPrecision: true)
    }

    private func memberName(_ id: String) -> String {
        members.first { $0.id.uuidString == id }?.displayName ?? ""
    }

    private func names(_ ids: Set<String>) -> String {
        members.filter { ids.contains($0.id.uuidString) }.map(\.displayName).formatted(.list(type: .and))
    }
}

/// «Lo entendido» de Voz y Foto de Grupos con la maqueta de personal: el título y lo que se oyó arriba, el reparto en
/// medio y los dos botones abajo.
struct GroupReceiptReviewContent: View {
    @Bindable var model: GroupCaptureModel
    /// «Volver a grabar» u «Otra foto».
    let againTitle: String
    let againIdentifier: String
    let onAgain: () -> Void
    let onUse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L10n.ReceiptSplit.reviewTitle)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("receipt_split_review_title")
                if !model.heard.isEmpty {
                    Text(model.heard)
                        .font(DS.Typography.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .padding(.top, DS.Spacing.xs)

            GroupReceiptSplitReview(model: model)

            if let reason = GroupReceiptSplitReview.blockedReason(model) {
                Text(reason)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.md) { buttons }
                VStack(spacing: DS.Spacing.sm) { buttons }
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        GroupCaptureSecondaryButton(title: againTitle, identifier: againIdentifier, action: onAgain)
        GroupCapturePrimaryButton(
            title: L10n.ReceiptSplit.useSplit,
            isEnabled: GroupReceiptSplitReview.canUse(model),
            identifier: "receipt_split_use",
            action: onUse
        )
    }
}
