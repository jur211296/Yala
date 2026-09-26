//
//  LateICloudMirrorNoticeView.swift
//  Yala
//
//  Paso 4 del rediseño de sesiones · **el aviso del espejo que llega TARDE.**
//
//  El hueco lo encontró Jürgen el 2026-09-09, y es el bug del ticket por la puerta de atrás: quien elige
//  privado sin poder validar iCloud sigue en local —correcto, no poder preguntar nunca bloquea— pero el
//  día que su espejo puede sincronizar le baja el histórico viejo encima de lo que acaba de crear, sin
//  decirle nada. La validación no desapareció: se aplazó, y esto es su cobro.
//
//  **Es una PANTALLA y no dos alerts encadenados, y eso es una corrección de la review adversarial del
//  2026-09-10.** La primera versión eran dos `.alert` colgados del mismo anchor de `ContentView`, con el
//  botón destructivo del primero encendiendo el segundo. Tres cosas iban mal y las tres se van con la
//  pantalla:
//
//   1. **Los dos `.alert` compiten por el mismo anchor.** El molde que su propio comentario citaba
//      (`UserDataResetView`) encadena sheet → alert **por su `onDismiss`**, y un `.alert` no tiene
//      `onDismiss`. Si UIKit descartaba el segundo, `showLateICloudWipeConfirm` se quedaba en `true` para
//      siempre — y como es blocker de la matriz de readiness, el router no volvía a drenar NADA en toda la
//      sesión (avisos de bandeja, paywall, invitaciones): un brick silencioso que solo se arreglaba
//      matando la app.
//   2. **El botón anulaba el `presenting:` del alert que lo contenía**, dejando sus builders sin dato a
//      mitad del desmontaje.
//   3. **El borrado no tenía dónde enseñarse.** Entre «sí, borra» y el final pasan decenas de segundos y
//      la app no mostraba nada; si fallaba, tampoco. La puerta del Welcome sí tiene su fase `.wiping` y su
//      `.wipeFailed`: la asimetría era del mismo flujo consigo mismo.
//
//  Fases, no presentaciones anidadas — el mismo criterio que `WelcomePrivateICloudGateView`, con el que
//  comparte todo el copy: son el mismo hecho contado en dos momentos.
//
//  **Dos salidas y no tres, y no es una salida perdida.** El aviso de la puerta ofrece «restaurar» como
//  tercer camino porque allí los datos NO están todavía en el dispositivo; aquí el espejo ya los está
//  trayendo, así que «son míos» y «déjalo así» son literalmente el mismo desenlace. Pedirle a alguien que
//  distinga dos botones que hacen lo mismo es peor que darle uno. La salida por defecto es la que NO
//  destruye: decisión de Jürgen del 2026-09-10 —«déjalo así», los dos corpus conviven, ahora avisado—.
//  Lo que este ticket arregla no es que convivan: es que convivieran **en silencio**.
//

import SwiftUI

struct LateICloudMirrorNoticeView: View {

    let corpus: ICloudPersonalCorpus
    /// «Déjalo así»: los dos corpus conviven. Retira el testigo — la persona ya decidió.
    var onKeep: () -> Void
    /// Borrar el corpus viejo de iCloud y lo que el espejo bajó. `nil` si fue bien.
    var performWipe: @MainActor () async -> String?
    /// El borrado terminó bien: `ContentView` reabre el onboarding.
    var onWiped: () -> Void

    @State private var phase: Phase = .notice
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case notice, confirming, wiping, failed
        /// El borrado no corrió: quedan cambios de grupos sin subir (ticket
        /// `fresh-start-wipe-kills-unsent-group-writes-silently`). Nada se tocó.
        case groupsPending(CloudSessionSignOut.FreshStartGroupsBlock)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Spacer(minLength: DS.Spacing.lg)
                content
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .yalaScreenBackground(.subtle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // El cierre por la barra significa lo mismo que «déjalo así»: la persona vio el aviso
                    // y no pidió borrar nada. **Desaparece durante el borrado**, que no admite abandono.
                    if phase != .wiping {
                        Button(L10n.Action.close) {
                            // Desde «faltan cambios de grupos» también desarma: ver `leaveGroupsPending`.
                            if case .groupsPending = phase { StorageModePersistence.clearICloudCorpusWipeArm() }
                            onKeep(); dismiss()
                        }
                            .accessibilityIdentifier("late_icloud_close")
                    }
                }
            }
            // La fase conduce el trabajo, con cancelación real al desmontar (mismo criterio que la puerta).
            .task(id: phase) { await runPhase() }
        }
        // Sin marcha atrás por swipe mientras se borra: el gesto interactivo desmontaría la vista con la
        // operación en vuelo, que es justo lo que el arm existe para no tener que adivinar.
        .interactiveDismissDisabled(phase == .wiping)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .notice:
            noticeBody(
                icon: "exclamationmark.icloud",
                title: L10n.Welcome.PrivateICloud.lateTitle,
                body: L10n.Welcome.PrivateICloud.lateBody(
                    WelcomePrivateICloudGateView.countsLine(corpus)),
                identifier: "late_icloud_notice",
                primary: L10n.Welcome.PrivateICloud.lateKeep,
                primaryAction: { onKeep(); dismiss() },
                destructive: L10n.Welcome.PrivateICloud.wipeAction,
                destructiveAction: { phase = .confirming })
        case .confirming:
            noticeBody(
                icon: "trash",
                title: L10n.Settings.wipeDataSecondConfirmTitle,
                body: L10n.Welcome.PrivateICloud.wipeConfirmBody,
                identifier: "late_icloud_confirm",
                primary: L10n.Welcome.PrivateICloud.wipeConfirmKeep,
                primaryAction: { phase = .notice },
                destructive: L10n.Settings.deleteAllDataAction,
                destructiveAction: { phase = .wiping })
        case .wiping:
            VStack(spacing: DS.Spacing.lg) {
                ProgressView().controlSize(.large)
                Text(L10n.Welcome.PrivateICloud.wiping)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityIdentifier("late_icloud_wiping")
        case .failed:
            noticeBody(
                icon: "exclamationmark.icloud",
                title: L10n.Welcome.PrivateICloud.wipeFailedTitle,
                body: L10n.Welcome.PrivateICloud.wipeFailedBody,
                identifier: "late_icloud_failed",
                primary: L10n.Welcome.Restore.retry,
                primaryAction: { phase = .wiping },
                destructive: L10n.Welcome.PrivateICloud.wipeFailedBack,
                // Rendirse deja el testigo puesto a propósito: el corpus sigue en iCloud y la persona no
                // ha dicho que se lo quede, solo que ahora no. El aviso vuelve en el próximo arranque.
                destructiveAction: { dismiss() })
        case .groupsPending(let block):
            // Mismo molde que `.failed`, con el texto de lo que pasó: no se borró nada porque quedan cambios de grupos,
            // cuántos y qué hacer. `wipeRetry` y no `Restore.retry` («Reintentar búsqueda»): aquí no se busca nada.
            noticeBody(
                icon: "exclamationmark.triangle",
                title: L10n.Groups.FreshStartPending.title,
                body: SignOutBlockedCopy.freshStartGroupsPendingMessage(block),
                identifier: "late_icloud_groups_pending",
                primary: L10n.Welcome.PrivateICloud.wipeRetry,
                primaryAction: { phase = .wiping },
                destructive: L10n.Welcome.PrivateICloud.wipeFailedBack,
                destructiveAction: leaveGroupsPending)
        }
    }

    /// «Dejarlo por ahora» desde «faltan cambios de grupos». **Retira el arm y deja el testigo** (review adversarial del
    /// 2026-09-26, las tres lentes). A diferencia de `.failed`, aquí no se borró NADA —la subida va antes de la zona—, así
    /// que el arm no protege ningún estado a medias; y dejarlo puesto hacía que `runLateICloudMirrorCheck` reanudara el
    /// borrado a ciegas en cada arranque hasta que, semanas después, los cambios subieran y se llevara todo lo creado
    /// entretanto sin una sola pantalla. Con el testigo puesto, el aviso vuelve a preguntar en el próximo arranque.
    private func leaveGroupsPending() {
        StorageModePersistence.clearICloudCorpusWipeArm()
        dismiss()
    }

    private func noticeBody(icon: String, title: String, body: String, identifier: String,
                            primary: String, primaryAction: @escaping () -> Void,
                            destructive: String, destructiveAction: @escaping () -> Void) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 44)) // A11Y-DT: icono decorativo hero, tamaño fijo (patrón del flow)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(spacing: DS.Spacing.sm) {
                    Text(title)
                        .font(DS.Typography.title2)
                        .multilineTextAlignment(.center)
                    Text(body)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityIdentifier(identifier)

            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(primary) { primaryAction() }
                    .accessibilityIdentifier(identifier + "_primary")
                Button(role: .destructive, action: destructiveAction) {
                    Text(destructive)
                        .font(DS.Typography.label)
                        .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier(identifier + "_destructive")
            }
        }
    }

    /// Mismo orden kill-safe que la puerta: armar antes de la primera llamada, desarmar solo cuando el
    /// borrado confirma. Un kill en medio deja el arm puesto y el arranque siguiente vuelve a medir.
    private func runPhase() async {
        guard phase == .wiping else { return }
        StorageModePersistence.armICloudCorpusWipe()
        let failure = await performWipe()
        guard !Task.isCancelled else { return }
        if let failure {
            if failure == CloudSessionSignOut.freshStartGroupsPendingFailure,
               let block = CloudSessionSignOut.shared.freshStartGroupsBlock {
                phase = .groupsPending(block)
            } else {
                phase = .failed
            }
            return
        }
        StorageModePersistence.clearPrivateChoseWithoutICloud()
        StorageModePersistence.clearICloudCorpusWipeArm()
        onWiped()
        dismiss()
    }
}
