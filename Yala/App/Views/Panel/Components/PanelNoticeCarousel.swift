//
//  PanelNoticeCarousel.swift
//  Yala
//
//  Un aviso del Panel a la vez, con «1 de N» y un botón para ver el siguiente (UX 2.2 · L3-8, opción A). Qué avisos
//  hay y en qué orden lo decide `PanelNoticeQueueLogic`; aquí solo se pinta el que toca.
//

import SwiftUI

struct PanelNoticeCarousel<Content: View>: View {
    let notices: [PanelNotice]
    @Binding var selected: PanelNotice?
    @ViewBuilder let content: (PanelNotice) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let current = PanelNoticeQueueLogic.current(in: notices, selected: selected) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                content(current)
                    .id(current)
                    .transition(.opacity)

                if notices.count > 1, let position = notices.firstIndex(of: current) {
                    pager(position: position + 1, total: notices.count, current: current)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("panel_notices")
        }
    }

    private func pager(position: Int, total: Int, current: PanelNotice) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(L10n.Panel.Notices.position(position, total))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityIdentifier("panel_notices_position")
            Spacer(minLength: 0)
            Button {
                DS.Haptic.selection()
                dsWithAnimation(reduceMotion) {
                    selected = PanelNoticeQueueLogic.next(after: current, in: notices)
                }
            } label: {
                HStack(spacing: DS.Spacing.xxs) {
                    Text(L10n.Panel.Notices.next)
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.captionSmall)
                        .fontWeight(.semibold)
                        .accessibilityHidden(true)
                }
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.thAccent)
                .padding(.vertical, DS.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("panel_notices_next")
        }
        .padding(.horizontal, DS.Spacing.xs)
    }
}
