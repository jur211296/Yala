//
//  GroupCardView.swift
//  Yala
//
//  Card de un grupo en la lista principal — icono, nombre y miembros arriba; debajo, una fila por persona
//  (decisión de Jürgen, 2026-10-30, propuesta 1 de `docs/disenos/grupos-rediseno-2-2/`): «Le debes a Maria P.» /
//  «Maria P. te debe» a la izquierda y el monto en color a la derecha, rosa rojizo lo que debes y verde lo que te
//  deben. Primero lo que debes; como mucho tres filas y el resto en «y N más» (`GroupsListBalanceLogic.personRows`).
//

import SwiftUI

struct GroupCardView: View {

    let group: SplitGroup
    let memberCount: Int
    let pendingCount: Int
    /// Deudas simplificadas perspectiva del current user: una fila por persona y divisa.
    let debts: [GroupsViewModel.DebtRow]
    /// Drives chip pending/rejected en lugar de las filas por persona.
    let displayMode: GroupCardDisplayMode
    let action: () -> Void
    /// Disparado cuando current user `.rejected` toca la card. El padre
    /// presenta el alert "¿Salir del grupo?" (un solo modal global).
    var onRejectedTap: (() -> Void)?
    /// Disparado cuando current user `.pendingApproval` toca la card. El padre presenta el aviso
    /// «solicitud en revisión» — mismo patrón de modal global que `onRejectedTap`.
    var onPendingTap: (() -> Void)?
    // C-10: `onMigratedTap` se ELIMINÓ. Un grupo congelado ya no dispara el CTA desde la card: abre el
    // detalle (vía `action`), que es donde el banner explica el estado y ofrece la salida que este build
    // pueda cumplir de verdad.

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        group: SplitGroup,
        memberCount: Int,
        pendingCount: Int,
        debts: [GroupsViewModel.DebtRow],
        displayMode: GroupCardDisplayMode = .active,
        action: @escaping () -> Void,
        onRejectedTap: (() -> Void)? = nil,
        onPendingTap: (() -> Void)? = nil
    ) {
        self.group = group
        self.memberCount = memberCount
        self.pendingCount = pendingCount
        self.debts = debts
        self.displayMode = displayMode
        self.action = action
        self.onRejectedTap = onRejectedTap
        self.onPendingTap = onPendingTap
    }

    var body: some View {
        Button(action: handleTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header
                if displayMode == .active, !personRows.shown.isEmpty {
                    Divider()
                    personList
                }
            }
            .listRowCard()
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .pointerHighlight(cornerRadius: DS.Radius.card)
        // El `.disabled(displayMode == .pendingApproval)` que vivía aquí se RETIRÓ (2026-09-06). No
        // protegía nada que `handleTap` no proteja ya —abajo, con su propio `case`— y sí hacía dos
        // daños: apagaba la card para VoiceOver (un botón deshabilitado no se anuncia como activable)
        // y dejaba el tap sin destino. La puerta sigue cerrada; ahora dice por qué.
        .accessibilityLabel(accessibilityText)
    }

    /// Icono, nombre y miembros; a la derecha, el chip de estado cuando el grupo no está activo.
    private var header: some View {
        // A tamaños de accesibilidad el chip baja bajo el nombre (`AdaptiveRowStack`).
        AdaptiveRowStack(spacing: DS.ListRow.spacing, stackedSpacing: DS.Spacing.sm) {
            groupIcon

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(group.name)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.Groups.Member.activeCount(memberCount))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)

                    if visiblePendingCount > 0 {
                        Text("·")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text(L10n.Groups.Member.pendingCount(visiblePendingCount))
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.warningForeground)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        } trailing: {
            statusChip
        }
    }

    /// Una fila por persona y, si no caben, «y N más».
    private var personList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(personRows.shown) { row in
                personRow(row)
            }
            if personRows.hiddenCount > 0 {
                Text(L10n.Groups.Card.andMore(personRows.hiddenCount))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func personRow(_ row: GroupsViewModel.DebtRow) -> some View {
        AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xxs) {
            Text(personLabel(row))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        } trailing: {
            Text(appPreferences.currency(row.amount, currencyCode: row.currencyCode, forceFullPrecision: true))
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(row.perspective == .iOwe ? Color.groupOweAmount : Color.groupOwedAmount)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func personLabel(_ row: GroupsViewModel.DebtRow) -> String {
        row.perspective == .iOwe
            ? L10n.Groups.Card.youOwe(row.counterpartyName)
            : L10n.Groups.Card.theyOweYou(row.counterpartyName)
    }

    private var personRows: GroupsListBalanceLogic.PersonRows {
        GroupsListBalanceLogic.personRows(debts)
    }

    @ViewBuilder
    private var statusChip: some View {
        switch displayMode {
        case .pendingApproval:
            StatusChip(
                icon: "clock.arrow.circlepath",
                text: L10n.Groups.Card.pendingApprovalChip,
                foregroundColor: DS.Semantic.warningForeground,
                backgroundColor: DS.Semantic.warningBackground
            )
        case .rejected:
            StatusChip(
                icon: "xmark.circle.fill",
                text: L10n.Groups.Card.rejectedChip,
                foregroundColor: DS.Semantic.errorForeground,
                backgroundColor: DS.Semantic.errorBackground
            )
        case .migratedFrozen:
            StatusChip(
                icon: "icloud.and.arrow.up",
                text: L10n.Groups.Card.movedChip,
                foregroundColor: DS.Semantic.warningForeground,
                backgroundColor: DS.Semantic.warningBackground
            )
        case .migratedNeedsUpdate:
            // C-10: el chip NOMBRA la acción real. "Se movió" a secas invita a tocar esperando volver a
            // entrar, y en un build incapaz eso no lleva a ninguna parte.
            StatusChip(
                icon: "arrow.down.circle",
                text: L10n.Groups.Card.movedUpdateChip,
                foregroundColor: DS.Semantic.warningForeground,
                backgroundColor: DS.Semantic.warningBackground
            )
        case .migratedPaused:
            StatusChip(
                icon: "icloud.and.arrow.up",
                text: L10n.Groups.Card.movedPausedChip,
                foregroundColor: DS.Semantic.warningForeground,
                backgroundColor: DS.Semantic.warningBackground
            )
        case .active:
            EmptyView()
        }
    }

    private func handleTap() {
        switch displayMode {
        case .pendingApproval:
            // La puerta del grupo (decisión owner 2026-09-06). NO abre el detalle: presenta el aviso
            // de «solicitud en revisión». Si el padre no cablea el closure no pasa nada —igual que
            // `.rejected`—, así que el grupo sigue sin abrirse pase lo que pase.
            onPendingTap?()
        case .rejected:
            onRejectedTap?()
        case .migratedFrozen, .migratedNeedsUpdate, .migratedPaused:
            // C-10: un grupo congelado SIEMPRE se abre, en los tres estados. Antes el tap disparaba el
            // CTA de re-join directamente y el grupo era un muro; en un build incapaz, además, un muro
            // mudo. El detalle es donde hay sitio para explicar y para ofrecer la salida que toque.
            // Sigue sin poder escribirse: eso lo gobierna `isMigratedFrozen`, que no cambió.
            action()
        case .active:
            action()
        }
    }

    /// Sin la propia solicitud de quien espera aprobación (`GroupCardDisplayLogic.visiblePendingCount`).
    private var visiblePendingCount: Int {
        GroupCardDisplayLogic.visiblePendingCount(pendingCount, displayMode: displayMode)
    }

    private var accessibilityText: String {
        var parts = [group.name, L10n.Groups.Member.activeCount(memberCount)]
        if visiblePendingCount > 0 { parts.append(L10n.Groups.Member.pendingCount(visiblePendingCount)) }
        switch displayMode {
        case .pendingApproval:
            parts.append(L10n.Groups.Card.pendingApprovalChip)
        case .rejected:
            parts.append(L10n.Groups.Card.rejectedChip)
        case .migratedFrozen:
            parts.append(L10n.Groups.Card.movedChip)
        case .migratedNeedsUpdate:
            parts.append(L10n.Groups.Card.movedUpdateChip)
        case .migratedPaused:
            parts.append(L10n.Groups.Card.movedPausedChip)
        case .active:
            let rows = personRows
            for row in rows.shown {
                parts.append("\(personLabel(row)) \(appPreferences.currency(row.amount, currencyCode: row.currencyCode, forceFullPrecision: true))")
            }
            if rows.hiddenCount > 0 { parts.append(L10n.Groups.Card.andMore(rows.hiddenCount)) }
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Components

    private var groupIcon: some View {
        GroupIconBadge(colorHex: group.colorHex, iconName: group.iconName)
    }
}
