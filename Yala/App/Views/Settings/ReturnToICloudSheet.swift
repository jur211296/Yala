//
//  ReturnToICloudSheet.swift
//  Yala
//
//  Revisión 2.3, zona 41, decisión 53 (V2) de Jürgen, 2026-11-09: **«Volver a tu iCloud» es una hoja con fases**.
//  Sustituye a los tres globos de antes («Tu iCloud ya tiene datos de Yala», «¿Borrarlos de tu iCloud?» y «¿Volver a
//  iCloud?»), que se decidían con letra de 9-10 pt anclados al botón.
//
//  1. **Qué pasa** con cada cosa, incluido «Volver a la nube con ella · Hoy no se puede»: la tarjeta prometía «queda en
//     pausa por si vuelves», y esa cuenta hoy no puede volver a la nube.
//  2. **Qué hacer con lo que ya hay** en tu iCloud, solo si la pregunta previa encontró algo: dos tarjetas con su
//     consecuencia y «Ahora no» aparte. La que borra se lee distinta.
//  3. **Confirmar**: repite lo elegido con su cifra. Es el único botón que empieza algo.
//
//  Pura respecto a la vuelta: no la arranca. `onConfirm` devuelve la elección y `StorageSettingsView` la empieza en el
//  `onDismiss` de la hoja (regla 4 de presentaciones). Las fases y los textos de cada elección: `ReturnToICloudSheetLogic`.
//

import SwiftUI

/// Lo que abre la hoja: la respuesta de iCloud a la pregunta previa. `nil` = nada ajeno que decidir.
struct ReturnToICloudRequest: Identifiable {
    let id = UUID()
    let priorData: ICloudForeignCorpus?
}

struct ReturnToICloudSheet: View {

    let request: ReturnToICloudRequest
    /// La persona confirmó: la hoja baja y quien la presenta empieza la vuelta elegida.
    var onConfirm: (ReturnToICloudChoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: ReturnToICloudPhase = .whatHappens
    @State private var contentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    private static let iconSize: CGFloat = 36

    /// Con texto de accesibilidad los botones van al final de lo que se desplaza: fijos ocupaban media pantalla en la hoja
    /// de activar (revisión 2.3, zona 41, problema 8). A tamaño normal, fijos al pie.
    private var footerScrollsWithContent: Bool { dynamicTypeSize.isAccessibilitySize }

    /// La hoja mide lo que su fase: `.large` hasta medir; después, el alto del contenido (y `.large` para quien la estire).
    private var detents: Set<PresentationDetent> {
        let footer = footerScrollsWithContent ? 0 : footerHeight
        guard contentHeight > 0, footerScrollsWithContent || footerHeight > 0 else { return [.large] }
        return [.height(contentHeight + footer + DS.Spacing.lg), .large]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                phaseContent
                if footerScrollsWithContent {
                    footerButtons
                        .padding(.top, DS.Spacing.md)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.lg)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            if !footerScrollsWithContent {
                footerButtons
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.sm)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
            }
        }
        .yalaScreenBackground(.partialSheet)
        .yalaSheetDetents(detents)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Fases

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .whatHappens:
            whatHappens
        case .choosePrior:
            choosePrior
        case .confirm(let choice):
            confirm(choice)
        }
    }

    /// Fase 1: qué pasa con cada cosa. Las cuatro filas están medidas en el código: la vuelta no cierra la sesión de Yala,
    /// el servidor congela lo que hay en la cuenta sin borrarlo, y un claim de esa cuenta vuelve como «volvió a iCloud».
    private var whatHappens: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            title(L10n.Storage.Revert.Sheet.title, identifier: "storage_revert_sheet")
            fact(icon: "arrow.down.to.line", tint: .thAccentText,
                 title: L10n.Storage.Revert.Sheet.dataTitle, detail: L10n.Storage.Revert.Sheet.dataDetail,
                 identifier: "storage_revert_fact_data")
            fact(icon: "person.crop.circle", tint: .secondary,
                 title: L10n.Storage.Revert.Sheet.accountTitle, detail: L10n.Storage.Revert.Sheet.accountDetail,
                 identifier: "storage_revert_fact_account")
            fact(icon: "archivebox", tint: .secondary,
                 title: L10n.Storage.Revert.Sheet.storedTitle, detail: L10n.Storage.Revert.Sheet.storedDetail,
                 identifier: "storage_revert_fact_stored")
            fact(icon: "nosign", tint: DS.Semantic.warningForeground,
                 title: L10n.Storage.Revert.Sheet.cloudAgainTitle, detail: L10n.Storage.Revert.Sheet.cloudAgainDetail,
                 identifier: "storage_revert_fact_cloud_again")
        }
    }

    /// Fase 2: qué hacer con lo que ya hay en tu iCloud. Solo existe con `priorData`.
    @ViewBuilder
    private var choosePrior: some View {
        if let corpus = request.priorData {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                title(L10n.Storage.Revert.Prior.title, identifier: "storage_revert_prior_title")
                Text(ReturnToICloudSheetLogic.priorBody(corpus))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("storage_revert_prior_body")
                StorageChoiceCard(title: L10n.Storage.Revert.Prior.merge,
                                  detail: ReturnToICloudSheetLogic.mergeDetail(corpus),
                                  destructive: false, identifier: "storage_revert_prior_merge") {
                    go(to: .confirm(.mergePrior))
                }
                StorageChoiceCard(title: L10n.Storage.Revert.Prior.discard,
                                  detail: L10n.Storage.Revert.Sheet.discardDetail,
                                  destructive: true, identifier: "storage_revert_prior_discard") {
                    go(to: .confirm(.discardPrior))
                }
            }
        }
    }

    /// Fase 3: confirmar. Repite lo elegido y lo que pasa con tus datos.
    private func confirm(_ choice: ReturnToICloudChoice) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            title(L10n.Storage.Revert.Sheet.confirmTitle, identifier: "storage_revert_confirm_title")
            if let line = ReturnToICloudSheetLogic.confirmLine(choice, priorData: request.priorData) {
                Text(line)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(choice == .discardPrior ? DS.Semantic.errorForeground : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("storage_revert_confirm_line")
            }
            fact(icon: "arrow.down.to.line", tint: .thAccentText,
                 title: L10n.Storage.Revert.Sheet.dataTitle, detail: L10n.Storage.Revert.Sheet.dataDetail,
                 identifier: "storage_revert_confirm_data")
        }
    }

    // MARK: - El pie

    /// Los botones de cada fase. **La salida de no hacer nada siempre a la vista y sin rol** (regla B6): es una decisión
    /// sobre datos.
    @ViewBuilder
    private var footerButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            switch phase {
            case .whatHappens:
                YalaPrimaryButton(L10n.Storage.Revert.Sheet.continueButton) {
                    go(to: ReturnToICloudSheetLogic.phaseAfterWhatHappens(priorData: request.priorData))
                }
                .accessibilityIdentifier("storage_revert_continue")
                exitButton(L10n.Storage.PendingICloudWipe.wait, identifier: "storage_revert_not_now")
            case .choosePrior:
                exitButton(L10n.Storage.PendingICloudWipe.wait, identifier: "storage_revert_prior_wait")
            case .confirm(let choice):
                if choice == .discardPrior {
                    Button(role: .destructive) { confirmChoice(choice) } label: {
                        Text(ReturnToICloudSheetLogic.confirmButton(choice))
                            .font(DS.Typography.label)
                            .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("storage_revert_prior_discard_confirm")
                } else {
                    YalaPrimaryButton(ReturnToICloudSheetLogic.confirmButton(choice)) { confirmChoice(choice) }
                        .accessibilityIdentifier("storage_revert_confirm")
                }
                exitButton(L10n.Common.cancel, identifier: "storage_revert_cancel")
            }
        }
    }

    private func exitButton(_ text: String, identifier: String) -> some View {
        Button { dismiss() } label: {
            Text(text)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Piezas

    private func title(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(DS.Typography.title2)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(identifier)
    }

    private func fact(icon: String, tint: some ShapeStyle, title: String, detail: String,
                      identifier: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.headline)
                .foregroundStyle(tint)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .background(Color(uiColor: .secondarySystemFill), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Acciones

    private func go(to next: ReturnToICloudPhase) {
        DS.Haptic.selection()
        dsWithAnimation(reduceMotion, .easeInOut(duration: 0.2)) { phase = next }
    }

    /// Confirmar: la hoja baja y quien la presenta empieza la vuelta en su `onDismiss`.
    private func confirmChoice(_ choice: ReturnToICloudChoice) {
        onConfirm(choice)
    }
}

/// Una salida de una hoja de datos de «Dónde viven tus datos», con su consecuencia debajo (molde de la decisión 53). La
/// que borra lleva el título en rojo. La usan la hoja de volver a tu iCloud y la del borrado pendiente.
struct StorageChoiceCard: View {
    let title: String
    let detail: String
    let destructive: Bool
    let identifier: String
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(destructive ? DS.Semantic.errorForeground : Color.primary)
                    Text(detail)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.lg)
            .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
