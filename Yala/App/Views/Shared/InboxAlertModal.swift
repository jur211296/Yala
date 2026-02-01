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
    @Environment(\.colorScheme) private var colorScheme

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
        case .automations: return "gearshape.badge.checkmark"
        case .mixed: return "tray.full.fill"
        }
    }

    var body: some View {
        ZStack {
            // Backdrop con blur
            Color.black
                .opacity(isVisible ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }

            // Card modal
            VStack(spacing: DS.Spacing.xl) {
                // Icono
                ZStack {
                    Circle()
                        .fill(Color.electricIndigo.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.electricIndigo)
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
                            .background(Color.electricIndigo)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)

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
                }
            }
            .padding(DS.Spacing.xxl)
            .background(Color.yalaCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15),
                radius: 24,
                x: 0,
                y: 12
            )
            .padding(.horizontal, DS.Spacing.xxxl)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    private func dismissWithAnimation(_ completion: (() -> Void)? = nil) {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
            completion?()
        }
    }
}

// MARK: - Clear Background Helper

/// Helper to make fullScreenCover background transparent
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        InboxAlertModal(
            notification: PendingInboxNotification(scheduledPayments: 2, subscriptions: 0, automations: 0),
            onViewInbox: { print("View inbox") },
            onDismiss: { print("Dismiss") }
        )
    }
}
