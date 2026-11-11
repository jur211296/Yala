//
//  PendingICloudWipeSheet.swift
//  Yala
//
//  Revisión 2.3, zona 41, decisión 57 (opción A, con la opción 1 de Jürgen del 11-nov sobre qué es «terminar»): **activar
//  la nube con un borrado pendiente se decide en una hoja, no en un globo**. El globo decía «Activar sin borrar» y no
//  decía qué no se borraba.
//
//  El borrado pendiente es el «empezar de cero» que la persona pidió: se lleva lo de este dispositivo y lo de su iCloud.
//  Tiene dos estados, y la hoja dice la verdad de cada uno:
//   - **Sin empezar** (armado): iCloud sigue intacto. Si activa la nube, el borrado no se hace y sus datos de iCloud se
//     quedan.
//   - **A medias**: lo de iCloud ya se borró y en el dispositivo quedó todo o parte. Si activa la nube, lo que quedó pasa a
//     su cuenta de Yala.
//
//  Tres salidas: activar y conservar, terminar el borrado y empezar de cero, o «Ahora no». Terminar NO borra desde aquí:
//  `StorageSettingsView` cierra Ajustes y pide la hoja que ya termina ese borrado (`LateICloudMirrorNoticeView`, con su
//  «¿seguro?», su progreso y su fallo), que es la del arranque.
//

import SwiftUI

/// Qué eligió la persona en la hoja del borrado pendiente. Lo consume el `onDismiss` de quien la presenta.
enum PendingICloudWipeChoice: Equatable {
    /// «Activar y conservar…»: la renuncia de este intento y la cadena de activar de siempre.
    case activateKeeping
    /// «Terminar de borrar y empezar de cero»: cierra Ajustes y abre la hoja que termina el borrado.
    case finishWipe
    /// «Ahora no»: el borrado se queda como estaba y se retira una renuncia de un intento anterior.
    case notNow
}

/// Lo que abre la hoja: el estado del borrado, leído al tocar «Activar», y la cara de la tarjeta (migrar o adopt).
struct PendingICloudWipeRequest: Identifiable {
    let id = UUID()
    let leftHalfway: Bool
    let isAdopt: Bool
    /// Terminar se lleva también los grupos de este dispositivo (alcance `.handover`): la tarjeta lo dice.
    let finishPurgesGroups: Bool
}

struct PendingICloudWipeSheet: View {

    let request: PendingICloudWipeRequest
    var onChoose: (PendingICloudWipeChoice) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var contentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    private var footerScrollsWithContent: Bool { dynamicTypeSize.isAccessibilitySize }

    private var detents: Set<PresentationDetent> {
        let footer = footerScrollsWithContent ? 0 : footerHeight
        guard contentHeight > 0, footerScrollsWithContent || footerHeight > 0 else { return [.large] }
        return [.height(contentHeight + footer + DS.Spacing.lg), .large]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text(L10n.Storage.PendingICloudWipe.title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("storage_pending_icloud_wipe_sheet")
                Text(request.leftHalfway
                     ? L10n.Storage.PendingICloudWipe.bodyHalfway
                     : L10n.Storage.PendingICloudWipe.body)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("storage_pending_icloud_wipe_body")
                StorageChoiceCard(
                    title: request.leftHalfway
                        ? L10n.Storage.PendingICloudWipe.proceedHalfway
                        : L10n.Storage.PendingICloudWipe.proceed,
                    detail: request.leftHalfway
                        ? L10n.Storage.PendingICloudWipe.proceedDetailHalfway
                        : L10n.Storage.PendingICloudWipe.proceedDetail,
                    destructive: false, identifier: "storage_pending_icloud_wipe_proceed") {
                    choose(.activateKeeping)
                }
                StorageChoiceCard(
                    title: L10n.Storage.PendingICloudWipe.finish,
                    detail: finishDetail,
                    destructive: true, identifier: "storage_pending_icloud_wipe_finish") {
                    choose(.finishWipe)
                }
                if footerScrollsWithContent {
                    notNowButton
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
                notNowButton
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.sm)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
            }
        }
        .yalaScreenBackground(.partialSheet)
        .yalaSheetDetents(detents)
        .presentationDragIndicator(.visible)
    }

    /// Lo que se lleva terminar: a medias, lo que quedó aquí; sin empezar, también iCloud. Y, con el alcance que purga el
    /// dominio de Grupos, también los grupos de este dispositivo.
    private var finishDetail: String {
        switch (request.leftHalfway, request.finishPurgesGroups) {
        case (true, false): return L10n.Storage.PendingICloudWipe.finishDetailHalfway
        case (true, true): return L10n.Storage.PendingICloudWipe.finishDetailHalfwayWithGroups
        case (false, false): return L10n.Storage.PendingICloudWipe.finishDetail
        case (false, true): return L10n.Storage.PendingICloudWipe.finishDetailWithGroups
        }
    }

    /// «Ahora no», siempre a la vista y sin rol (regla B6): es una decisión sobre datos.
    private var notNowButton: some View {
        Button { choose(.notNow) } label: {
            Text(L10n.Storage.PendingICloudWipe.wait)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("storage_pending_icloud_wipe_wait")
    }

    private func choose(_ choice: PendingICloudWipeChoice) {
        DS.Haptic.selection()
        onChoose(choice)
    }
}
