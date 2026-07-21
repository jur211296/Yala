//
//  GroupBatchLeaveView.swift
//  Yala
//
//  Flujo DEDICADO del batch "salir de todos mis grupos" (D10). Se presenta como sheet desde
//  `UserDataResetView` cuando el usuario elige "También salir de mis grupos" (sin deudas). Lee el estado del
//  orquestador vía `GroupBatchLeaveTracker` (@Observable). Corre HEADLESS: si se descarta a mitad, el
//  orquestador sigue y el resultado se refleja en el tab Grupos (residual declarado — decisión B1).
//

import SwiftData
import SwiftUI

struct GroupBatchLeaveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Cierra la hoja de Ajustes ENTERA (para "Ver mis grupos" → tab Grupos). Cableado por `UserDataResetView`.
    let onRequestCloseSettings: (() -> Void)?

    @State private var tracker = GroupBatchLeaveTracker.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if tracker.isComplete {
                        resultSection
                    } else {
                        progressSection
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Settings.batchLeaveTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            #if DEBUG
            if UITestHooks.groupsBatchRunning {
                // QA/XCUITest: batch EN CURSO (para «Detener»). El tap sí recorre la mecánica real.
                GroupBatchLeaveStore.seedDemoRunning()
                tracker.refresh()
                return
            }
            if UITestHooks.groupsBatchDemo {
                // QA/XCUITest: resultado determinista fabricado (sin backend/iCloud). Ver UITestHooks.
                GroupBatchLeaveStore.seedDemoResult()
                tracker.refresh()
                return
            }
            #endif
            // Arranca (o continúa) el batch. El orquestador clasifica, arma el intent y procesa; es kill-safe
            // e idempotente — si ya hay una corrida en curso, su guard de re-entrancy lo hace no-op.
            Task { @MainActor in
                await GroupBatchLeaveOrchestrator.start(context: modelContext)
            }
        }
    }

    // MARK: - Progreso

    private var progressSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(L10n.Settings.batchLeaveProgress)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if tracker.total > 0 {
                Text("\(tracker.processedCount) / \(tracker.total)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // «Detener» (D3): cancelación cooperativa. El grupo en curso termina (server-first: o completa o no
            // ocurre); ninguno nuevo se toma. Botón directo — sin diálogo de confirmación: añadir una
            // presentación en este anchor es la clase de trampa de la regla toolbar-muerta.
            YalaSecondaryButton(L10n.Settings.batchLeaveStop) {
                GroupBatchLeaveOrchestrator.requestStop()
            }
            .accessibilityIdentifier("batch_leave_stop")
            .padding(.top, DS.Spacing.lg)
        }
        .padding(.top, DS.Spacing.xxl)
    }

    // MARK: - Resultado

    private var resultSection: some View {
        VStack(spacing: DS.Spacing.xxl) {
            // Headline honesta: una parada NO es "saliste de tus grupos" — el usuario detuvo a mitad.
            VStack(spacing: DS.Spacing.md) {
                Text(headline)
                    .font(DS.Typography.title)
                    .multilineTextAlignment(.center)
                if tracker.wasStopped {
                    Text(L10n.Settings.batchLeaveStoppedBody)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Resumen (label + número, sin plurales).
            if tracker.leftCount > 0 || tracker.transferredCount > 0 || tracker.skippedCount > 0 {
                VStack(spacing: DS.Spacing.none) {
                    if tracker.leftCount > 0 {
                        statRow(label: L10n.Settings.batchLeaveStatLeft, count: tracker.leftCount)
                    }
                    if tracker.transferredCount > 0 {
                        if tracker.leftCount > 0 { SubsectionDivider() }
                        statRow(label: L10n.Settings.batchLeaveStatTransferred, count: tracker.transferredCount)
                    }
                    if tracker.skippedCount > 0 {
                        if tracker.leftCount > 0 || tracker.transferredCount > 0 { SubsectionDivider() }
                        statRow(label: L10n.Settings.batchLeaveStatSkipped, count: tracker.skippedCount)
                    }
                }
                .solidCard()
            }

            // "Necesitan tu decisión": grupos que no se pudieron dejar automáticamente.
            if !tracker.needsDecision.isEmpty {
                needsDecisionSection
            }

            YalaPrimaryButton(L10n.Settings.batchLeaveDone) {
                tracker.acknowledge()
                dismiss()
            }
            .accessibilityIdentifier("batch_leave_done")
        }
    }

    /// Titular del resultado. La parada del usuario manda sobre las otras dos ramas: anunciar "saliste de tus
    /// grupos" tras un «Detener» a mitad sería copy fabricado.
    private var headline: String {
        if tracker.wasStopped { return L10n.Settings.batchLeaveStopped }
        return tracker.needsDecision.isEmpty
            ? L10n.Settings.batchLeaveAllDone
            : L10n.Settings.batchLeaveSomeNeedDecision
    }

    private func statRow(label: String, count: Int) -> some View {
        HStack {
            Text(label).font(DS.Typography.body)
            Spacer()
            Text("\(count)").font(DS.Typography.bodyBold).monospacedDigit()
        }
        .padding(DS.Spacing.lg)
    }

    private var needsDecisionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Settings.batchLeaveNeedsDecisionHeader)
                .font(DS.Typography.headline)
            Text(L10n.Settings.batchLeaveNeedsDecisionBody)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(tracker.needsDecision.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { SubsectionDivider() }
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(item.groupName).font(DS.Typography.body)
                        Text(reasonText(item.reason))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.lg)
                }
            }
            .solidCard()

            // Deep-link al tab Grupos (no al grupo específico — honesto: "requiere atención manual").
            YalaSecondaryButton(L10n.Settings.deleteAccountViewGroups) {
                SessionState.shared.selectMainTab(.groups)
                onRequestCloseSettings?()
                dismiss()
            }
            .accessibilityIdentifier("batch_leave_view_groups")
        }
    }

    private func reasonText(_ reason: GroupBatchLeaveLogic.NeedsDecisionReason) -> String {
        switch reason {
        case .cloudKitOwnerWithCoMembers, .backendNoEligibleHeir:
            return L10n.Settings.batchLeaveReasonManual
        case .debtAppeared:
            return L10n.Settings.batchLeaveReasonDebt
        case .operationFailed:
            return L10n.Settings.batchLeaveReasonFailed
        }
    }
}
