//
//  DestructiveScopeSheet.swift
//  Yala
//
//  "Hoja de alcance" destructiva (D4, §3.1/§3.3 del estudio MODO-NUBE-GESTION-DATOS-UX, ratificada
//  2026-07-19). Componente ÚNICO de confirmación para las operaciones destructivas: un sheet con 3 filas
//  escaneables SIEMPRE iguales — 📱 En este dispositivo / ☁️ En iCloud|En tu cuenta de Yala (dinámica por
//  `storageMode`) / 👥 En tus grupos — una nota de conservación, líneas condicionales, y botones
//  [secundaria opcional][destructiva][Cancelar]. Regla de copy: qué se borra / qué se conserva / vuelta atrás.
//
//  Es SOLO capa de presentación (los servicios NO se tocan). La ESTRUCTURA la decide `DestructiveScopeLogic`
//  (testeada por tabla); este componente es TONTO — renderiza un `Config`, que arma la factory
//  `Config.make(...)` mapeando el modelo + `L10n`. Los callsites solo pasan callbacks.
//
//  Anti-carrera (regla toolbar-muerta): el botón confirmar/secundario invoca su callback (que fija un flag
//  `pending<X>` en el callsite) y ACTO SEGUIDO hace `dismiss()` de la hoja; el `.sheet(onDismiss:)` del
//  callsite dispara la acción/siguiente-paso YA con la hoja fuera. Cancelar/swipe → solo `dismiss()` (el
//  callsite no fijó ningún flag → no-op). Nunca dos anchors ante el mismo observable.
//

import SwiftUI

struct DestructiveScopeSheet: View {

    let config: Config

    @Environment(\.dismiss) private var dismiss

    /// Alto del área de scroll (lo reporta `onGeometryChange`), para centrar verticalmente el contenido
    /// cuando cabe y dejarlo scrollear cuando crece (Dynamic Type XL).
    @State private var scrollViewportHeight: CGFloat = 0

    // MARK: - Config

    struct Config {
        let title: String
        /// SIEMPRE 3, en orden device→cloud→groups.
        let rows: [Row]
        /// Nota de conservación ("qué se conserva / vuelta atrás"). `nil` = no se muestra.
        let conservationNote: String?
        /// Líneas condicionales bajo las filas (aviso de deudas, desvío cruzado, etc.).
        let extraLines: [ExtraLineItem]
        /// Acciones secundarias SEGURAS EN ORDEN (p.ej. "Ver mis grupos", "Exportar antes"). Prominentes
        /// para desviar de la destrucción. Vacío = solo [destructiva][Cancelar].
        let secondaries: [SecondaryAction]
        let confirmLabel: String
        let confirmIdentifier: String
        let cancelLabel: String
        /// Se invoca ANTES del `dismiss()` de la hoja — el callsite fija su `pending` aquí.
        let onConfirm: () -> Void

        struct Row {
            let icon: String
            let label: String
            let detail: String
            let tone: DestructiveScopeLogic.Tone
        }

        struct ExtraLineItem {
            enum Style { case warning, info }
            let text: String
            let style: Style
        }

        struct SecondaryAction {
            let label: String
            let identifier: String
            /// Caption pequeño bajo el botón (p.ej. `.cloud` → "esta puede ser tu única copia"). `nil` = sin caption.
            let caption: String?
            /// Se invoca ANTES del `dismiss()` de la hoja.
            let handler: () -> Void
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                // A pantalla completa (`.large`) el bloque —título arriba, filas y nota debajo, con jerarquía
                // generosa (espaciado `xxl`)— se centra verticalmente en el área de scroll (patrón de
                // NotificationPrimerSheet). Así se lee como una PANTALLA DE DECISIÓN y no como un alert
                // estirado con un vacío enorme en el medio, tanto en las variantes densas (Vaciar, 4 botones)
                // como en las escasas (cerrar sesión, 2 botones). El `minHeight` = alto del viewport centra
                // cuando cabe y deja scrollear cuando el contenido crece (Dynamic Type XL). `onGeometryChange`
                // es el patrón seguro (evita el deadlock de `containerRelativeFrame` documentado en CLAUDE.md).
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    Text(config.title)
                        .font(DS.Typography.title)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        ForEach(config.rows.indices, id: \.self) { i in
                            rowView(config.rows[i])
                        }
                    }

                    if !config.extraLines.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            ForEach(config.extraLines.indices, id: \.self) { i in
                                extraLineView(config.extraLines[i])
                            }
                        }
                    }

                    if let note = config.conservationNote {
                        Text(note)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xl)
                .frame(maxWidth: .infinity, minHeight: scrollViewportHeight, alignment: .center)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { scrollViewportHeight = $0 }

            buttons
        }
        // Una decisión destructiva merece foco completo: siempre `.large` (una pantalla de decisión,
        // no un alert estirado). En `.large`, la regla SSOT de fondos exige `.subtle` (nunca
        // `.transparent`, que era solo para detents parciales). El wrapper `DS.Adaptive` es innecesario:
        // `[.large]` ya es `.large` en iPhone e iPad.
        .yalaScreenBackground(.subtle)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Rows

    private func toneColor(_ tone: DestructiveScopeLogic.Tone) -> Color {
        switch tone {
        case .destructive: return DS.Semantic.errorForeground
        case .preserved:   return .secondary
        case .neutral:     return .primary
        }
    }

    private func rowView(_ row: Config.Row) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: row.icon)
                .font(DS.Typography.body)
                .foregroundStyle(toneColor(row.tone))
                .frame(width: DS.Spacing.xxl)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(row.label)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)
                Text(row.detail)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(toneColor(row.tone))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func extraLineView(_ line: Config.ExtraLineItem) -> some View {
        Text(line.text)
            .font(DS.Typography.subheadline)
            .foregroundStyle(line.style == .warning ? DS.Semantic.warningForeground : .secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Buttons (pinned)

    private var buttons: some View {
        VStack(spacing: DS.Spacing.md) {
            // Desvíos SEGUROS EN ORDEN (D5/§m.4): prominentes sobre la acción destructiva (steer-away).
            ForEach(config.secondaries.indices, id: \.self) { i in
                secondaryButton(config.secondaries[i])
            }

            YalaSecondaryButton(config.confirmLabel, destructive: true) {
                config.onConfirm()
                dismiss()
            }
            .accessibilityIdentifier(config.confirmIdentifier)

            Button(config.cancelLabel) { dismiss() }
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, DS.Spacing.xxs)
                .accessibilityIdentifier("destructive_scope_cancel")
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xl)
    }

    private func secondaryButton(_ action: Config.SecondaryAction) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            YalaPrimaryButton(action.label) {
                action.handler()
                dismiss()
            }
            .accessibilityIdentifier(action.identifier)

            if let caption = action.caption {
                Text(caption)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Factory (modelo estructural → strings localizados, en UN solo sitio)

extension DestructiveScopeSheet.Config {

    /// Arma el `Config` desde `DestructiveScopeLogic.model` + `L10n`. `hasOutstandingDebt`/
    /// `hasLegacyCloudKitFootprint` solo influyen en `deleteAccount*`; `onSecondary` solo se usa si el
    /// modelo declara acción secundaria (eliminar-cuenta con deuda) y el callsite la provee.
    static func make(
        operation: DestructiveScopeLogic.Operation,
        cloudLabel: DestructiveScopeLogic.CloudLabel,
        hasOutstandingDebt: Bool = false,
        hasLegacyCloudKitFootprint: Bool = false,
        canLeaveAllGroups: Bool = false,
        onConfirm: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil,
        onExport: (() -> Void)? = nil,
        onLeaveGroups: (() -> Void)? = nil
    ) -> Self {
        let model = DestructiveScopeLogic.model(
            operation: operation,
            cloudLabel: cloudLabel,
            hasOutstandingDebt: hasOutstandingDebt,
            hasLegacyCloudKitFootprint: hasLegacyCloudKitFootprint,
            canLeaveAllGroups: canLeaveAllGroups)

        let rows = model.rows.map { spec in
            Row(icon: Self.icon(for: spec.location),
                label: Self.label(for: spec.location, cloudLabel: model.cloudLabel),
                detail: Self.detail(operation: operation, location: spec.location,
                                    cloudLabel: model.cloudLabel, hasOutstandingDebt: hasOutstandingDebt),
                tone: spec.tone)
        }

        // La lógica pura (`model.secondaryActions`) decide el conjunto + ORDEN; la factory mapea cada kind a
        // su label/id/handler/caption. Un kind cuyo closure sea nil se OMITE (defensivo).
        let secondaries: [SecondaryAction] = model.secondaryActions.compactMap { kind in
            switch kind {
            case .viewGroups:
                guard let onSecondary else { return nil }
                return SecondaryAction(
                    label: L10n.Settings.deleteAccountViewGroups,
                    identifier: Self.viewGroupsIdentifier(for: operation),
                    caption: nil,
                    handler: onSecondary)
            case .exportBefore:
                guard let onExport else { return nil }
                return SecondaryAction(
                    label: L10n.Settings.wipeExportBeforeButton,
                    identifier: "wipe_export_before",
                    // En `.cloud` esta puede ser la única copia (§3.3.1).
                    caption: cloudLabel == .cloudAccount ? L10n.Settings.wipeExportBeforeCloudCaption : nil,
                    handler: onExport)
            case .leaveAllGroups:
                guard let onLeaveGroups else { return nil }
                return SecondaryAction(
                    label: L10n.Settings.wipeLeaveGroupsButton,
                    identifier: "wipe_leave_groups",
                    caption: nil,
                    handler: onLeaveGroups)
            }
        }

        return Self(
            title: Self.title(for: operation),
            rows: rows,
            conservationNote: model.hasConservationNote ? Self.conservation(for: operation) : nil,
            extraLines: model.extraLines.map { Self.extraLine(for: $0) },
            secondaries: secondaries,
            confirmLabel: Self.confirmLabel(for: operation),
            confirmIdentifier: Self.confirmIdentifier(for: operation),
            cancelLabel: L10n.Common.cancel,
            onConfirm: onConfirm)
    }

    /// Preserva `delete_account_view_groups` (asertado por `DeleteAccountDialogUITests`) en eliminar-cuenta;
    /// Vaciar usa `wipe_view_groups` (contexto distinto).
    private static func viewGroupsIdentifier(for operation: DestructiveScopeLogic.Operation) -> String {
        switch operation {
        case .deleteAccountCloud, .deleteAccountGroupsOnly: return "delete_account_view_groups"
        default: return "wipe_view_groups"
        }
    }

    // MARK: Mapeo token → string

    private static func icon(for location: DestructiveScopeLogic.Location) -> String {
        switch location {
        case .device: return "iphone"
        case .cloud:  return "icloud"
        case .groups: return "person.2"
        }
    }

    private static func label(
        for location: DestructiveScopeLogic.Location,
        cloudLabel: DestructiveScopeLogic.CloudLabel
    ) -> String {
        switch location {
        case .device: return L10n.Settings.scopeDeviceLabel
        case .cloud:  return cloudLabel == .cloudAccount
            ? L10n.Settings.scopeCloudAccountLabel : L10n.Settings.scopeICloudLabel
        case .groups: return L10n.Settings.scopeGroupsLabel
        }
    }

    private static func detail(
        operation: DestructiveScopeLogic.Operation,
        location: DestructiveScopeLogic.Location,
        cloudLabel: DestructiveScopeLogic.CloudLabel,
        hasOutstandingDebt: Bool
    ) -> String {
        // Fila 👥 de Vaciar: con deuda invita a saldar (steer-away); sin deuda, "no se tocan".
        let wipeGroupsDetail = hasOutstandingDebt
            ? L10n.Settings.wipeScopeGroupsDebt : L10n.Settings.wipeScopeGroups
        switch operation {
        case .wipeDataFull:
            switch location {
            case .device: return L10n.Settings.wipeScopeDevice
            case .cloud:  return cloudLabel == .cloudAccount
                ? L10n.Settings.wipeScopeCloudAccount : L10n.Settings.wipeScopeCloudICloud
            case .groups: return wipeGroupsDetail
            }
        case .wipeDataGroupsOnly:
            switch location {
            case .device: return L10n.Settings.wipeScopeDeviceGroupsOnly
            case .cloud:  return L10n.Settings.wipeScopeCloudICloud
            case .groups: return wipeGroupsDetail
            }
        case .deleteAccountCloud:
            switch location {
            case .device: return L10n.Settings.deleteAccountScopeDeviceCloud
            case .cloud:  return L10n.Settings.deleteAccountScopeCloudCloud
            case .groups: return L10n.Settings.deleteAccountScopeGroups
            }
        case .deleteAccountGroupsOnly:
            switch location {
            case .device: return L10n.Settings.deleteAccountScopeDeviceGroupsOnly
            case .cloud:  return L10n.Settings.deleteAccountScopeCloudGroupsOnly
            case .groups: return L10n.Settings.deleteAccountScopeGroups
            }
        case .signOutPrivate:
            switch location {
            case .device: return L10n.Settings.signOutScopeDevicePrivate
            case .cloud:  return L10n.Settings.signOutScopeCloudPrivate
            case .groups: return L10n.Settings.scopeUntouchedShort
            }
        case .signOutCloud:
            switch location {
            case .device: return L10n.Settings.signOutScopeDeviceCloud
            case .cloud:  return L10n.Settings.signOutScopeCloudCloud
            case .groups: return L10n.Settings.scopeUntouchedShort
            }
        case .signOutSecondary:
            switch location {
            case .device: return L10n.Settings.signOutScopeDeviceSecondary
            case .cloud:  return L10n.Settings.signOutScopeCloudSecondary
            case .groups: return L10n.Settings.scopeUntouchedShort
            }
        case .signOutGroupsOnly:
            switch location {
            case .device: return L10n.Settings.signOutScopeDeviceGroupsOnly
            case .cloud:  return L10n.Settings.scopePersonalInICloud
            case .groups: return L10n.Settings.scopeForgetGroups
            }
        case .exitYalaLegacy:
            switch location {
            case .device: return L10n.Settings.exitYalaScopeDeviceLegacy
            case .cloud:  return L10n.Settings.exitYalaScopeCloudLegacy
            case .groups: return L10n.Settings.exitYalaScopeGroupsLegacy
            }
        case .exitYalaGroups:
            switch location {
            case .device: return L10n.Settings.exitYalaScopeDeviceGroups
            case .cloud:  return L10n.Settings.scopePersonalInICloud
            case .groups: return L10n.Settings.scopeForgetGroups
            }
        case .deleteFrozenCopy:
            switch location {
            case .device: return L10n.Settings.deleteFrozenScopeDevice
            case .cloud:  return L10n.Settings.deleteFrozenScopeCloud
            case .groups: return L10n.Settings.deleteFrozenScopeGroups
            }
        }
    }

    private static func title(for operation: DestructiveScopeLogic.Operation) -> String {
        switch operation {
        case .wipeDataFull, .wipeDataGroupsOnly:
            return L10n.Settings.deleteDataConfirmation
        case .deleteAccountCloud, .deleteAccountGroupsOnly:
            return L10n.Settings.deleteAccountConfirmTitle
        case .signOutPrivate, .signOutCloud, .signOutSecondary, .signOutGroupsOnly:
            return L10n.Settings.signOutConfirmTitle
        case .exitYalaLegacy, .exitYalaGroups:
            return L10n.Settings.exitYalaConfirmTitle
        case .deleteFrozenCopy:
            return L10n.Groups.Migrated.deleteCopyConfirmTitle
        }
    }

    private static func confirmLabel(for operation: DestructiveScopeLogic.Operation) -> String {
        switch operation {
        case .wipeDataFull, .wipeDataGroupsOnly:
            return L10n.Settings.deleteAllDataAction
        case .deleteAccountCloud, .deleteAccountGroupsOnly:
            return L10n.Settings.deleteAccountContinue
        case .signOutPrivate, .signOutCloud, .signOutSecondary, .signOutGroupsOnly:
            return L10n.Settings.signOutConfirmAction
        case .exitYalaLegacy, .exitYalaGroups:
            return L10n.Settings.exitYalaConfirmAction
        case .deleteFrozenCopy:
            return L10n.Groups.Migrated.deleteCopyConfirmButton
        }
    }

    /// Preserva los identifiers que `DeleteAccountDialogUITests` asserta; el resto usa el genérico.
    private static func confirmIdentifier(for operation: DestructiveScopeLogic.Operation) -> String {
        switch operation {
        case .deleteAccountCloud, .deleteAccountGroupsOnly: return "delete_account_continue"
        default: return "destructive_scope_confirm"
        }
    }

    private static func conservation(for operation: DestructiveScopeLogic.Operation) -> String {
        switch operation {
        case .wipeDataFull:       return L10n.Settings.wipeScopeConservation
        case .signOutPrivate:     return L10n.Settings.signOutScopeConservationPrivate
        case .signOutCloud:       return L10n.Settings.signOutScopeConservationCloud
        case .signOutSecondary:   return L10n.Settings.signOutScopeConservationSecondary
        case .signOutGroupsOnly, .exitYalaGroups:
            return L10n.Settings.signOutScopeConservationGroups
        case .exitYalaLegacy:     return L10n.Settings.exitYalaScopeConservationLegacy
        case .deleteFrozenCopy:   return L10n.Settings.deleteFrozenScopeConservation
        // Operaciones sin nota de conservación (`hasConservationNote == false`): nunca se llama.
        case .wipeDataGroupsOnly, .deleteAccountCloud, .deleteAccountGroupsOnly:
            return ""
        }
    }

    private static func extraLine(for role: DestructiveScopeLogic.ExtraLine) -> ExtraLineItem {
        switch role {
        case .debtWarning:
            return ExtraLineItem(text: L10n.Settings.deleteAccountDebtWarning, style: .warning)
        case .crossRefer:
            return ExtraLineItem(text: L10n.Settings.deleteAccountCrossReferHint, style: .info)
        case .frozenICloud:
            return ExtraLineItem(text: L10n.Settings.deleteAccountFrozenICloudNote, style: .info)
        case .legacyFootprint:
            return ExtraLineItem(text: L10n.Settings.deleteAccountLegacyFootprintNote, style: .info)
        case .multiDeviceResidual:
            return ExtraLineItem(text: L10n.Settings.wipeScopeMultiDeviceResidual, style: .info)
        }
    }
}

// MARK: - Preview

#Preview("Hoja de alcance — variantes") {
    struct PreviewHost: View {
        // D4: por defecto Vaciar en `.cloud` con deuda → dos steer-away (Ver mis grupos + Exportar antes),
        // caption "única copia" y línea de residual multi-device (D9). Cambia `op` para ver otras variantes.
        @State private var op: DestructiveScopeLogic.Operation = .wipeDataFull
        private var isCloud: Bool {
            op == .wipeDataFull || op == .deleteAccountCloud || op == .signOutCloud
        }
        var body: some View {
            Color.clear.sheet(isPresented: .constant(true)) {
                DestructiveScopeSheet(config: .make(
                    operation: op,
                    cloudLabel: isCloud ? .cloudAccount : .icloud,
                    hasOutstandingDebt: op == .wipeDataFull || op == .deleteAccountCloud,
                    hasLegacyCloudKitFootprint: op == .deleteAccountCloud,
                    onConfirm: {},
                    onSecondary: {},
                    onExport: {}))
            }
        }
    }
    return PreviewHost()
}
