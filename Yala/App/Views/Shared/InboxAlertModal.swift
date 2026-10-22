//
//  InboxAlertModal.swift
//  Yala
//
//  Modal centrado para notificar nuevos items añadidos al inbox.
//  Soporta pagos planificados, suscripciones y registros automáticos.
//

import SwiftUI

struct InboxAlertModal: View {
    let notification: PendingInboxNotification
    let onViewInbox: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        switch notification.notificationType {
        case .scheduledPayments: return L10n.Inbox.Alert.Title.scheduled
        case .subscriptions: return L10n.Inbox.Alert.Title.subscriptions
        case .automations: return L10n.Inbox.Alert.Title.automations
        case .mixed: return L10n.Inbox.Alert.Title.mixed
        }
    }

    private var message: String {
        switch notification.notificationType {
        case .scheduledPayments:
            return L10n.Inbox.Alert.Message.scheduled(notification.scheduledPayments)
        case .subscriptions:
            return L10n.Inbox.Alert.Message.subscriptions(notification.subscriptions)
        case .automations:
            return L10n.Inbox.Alert.Message.automations(notification.automations)
        case .mixed:
            return notification.mixedMessageBreakdown
        }
    }

    private var icon: String {
        switch notification.notificationType {
        case .scheduledPayments: return "bell.badge.fill"
        case .subscriptions: return "creditcard.and.123"
        case .automations: return "gear.badge.checkmark"
        case .mixed: return "tray.full.fill"
        }
    }

    var body: some View {
        ZStack {
            // Backdrop con blur
            Color.black
                .opacity(isVisible ? 0.4 : 0)
                .ignoresSafeArea()
                // opacity(0) NO desactiva hit-testing: sin este gate el backdrop
                // invisible seguiría capturando todos los taps de la app.
                .allowsHitTesting(isVisible)
                .onTapGesture {
                    dismissWithAnimation()
                }

            // Card modal
            VStack(spacing: DS.Spacing.xl) {
                // Icono
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Image(systemName: icon)
                        .font(DS.Typography.amountLarge)
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
                .padding(.top, DS.Spacing.sm)

                // Título y mensaje
                VStack(spacing: DS.Spacing.sm) {
                    Text(title)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Botones
                VStack(spacing: DS.Spacing.sm) {
                    // Botón primario
                    Button {
                        dismissWithAnimation {
                            onViewInbox()
                        }
                    } label: {
                        Text(L10n.Scheduled.viewInbox)
                            .font(DS.Typography.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("inbox_alert_view")

                    // Botón secundario
                    Button {
                        dismissWithAnimation()
                    } label: {
                        Text(L10n.Action.later)
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("inbox_alert_dismiss")
                }
            }
            .padding(DS.Spacing.xxl)
            .background {
                if theme.usesMaterial {
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(theme.card)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .shadow(
                color: Color.black.opacity(theme.baseColorScheme == .dark ? 0.5 : 0.15),
                radius: 24,
                x: 0,
                y: 12
            )
            .padding(.horizontal, DS.Spacing.xxxl)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            dsWithAnimation(reduceMotion) {
                isVisible = true
            }
        }
    }

    private func dismissWithAnimation(_ completion: (() -> Void)? = nil) {
        if reduceMotion {
            // Sin animación no hay salida que esperar — reset inmediato.
            isVisible = false
            onDismiss()
            completion?()
        } else {
            // El reset no cuelga de un `Task { sleep }` sino de la completion de la animación,
            // atada al ciclo de render (regla 1 de presentaciones en `.claude/rules/swiftui-ds.md`:
            // el reset del flag jamás debe depender de un temporizador interno de la vista
            // presentada). `isVisible = false` solo OCULTA; es `onDismiss` quien vacía
            // `activeInboxNotification` y con ello pide el desmontaje del cover.
            //
            // OJO, esto NO arregla el flaky de `test_inboxAlertModalDismisses` (Lista Negra
            // 2026-07-28) y no hay que leerlo como tal: instrumentado con os_log, el tramo
            // tap→onDismiss mide 284 ms IDÉNTICOS en corridas verdes y rojas. Lo que varía es el
            // tramo siguiente —onDismiss→desmontaje efectivo del `fullScreenCover`— que va de
            // 554 ms a más de 7 s, y ese lo decide SwiftUI/UIKit, no este código.
            withAnimation(.easeInOut(duration: DS.Animation.normal)) {
                isVisible = false
            } completion: {
                onDismiss()
                completion?()
            }
        }
    }
}


#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        InboxAlertModal(
            notification: PendingInboxNotification(scheduledPayments: 2, subscriptions: 0, automations: 0),
            onViewInbox: {},
            onDismiss: {}
        )
    }
}
