//
//  GroupCreatedInviteSheet.swift
//  Yala
//
//  Auditoría UX 2.2 · L12-10 (decisión de Jürgen del 15-oct: variante 1, con el botón morado: el
//  color de acento, morado en el tema de siempre). Al guardar un grupo
//  nuevo, una hoja dice que está listo y propone una sola cosa: invitar. Antes el formulario se cerraba en la lista y
//  para invitar había que abrir el grupo, Miembros y bajar hasta la última fila.
//
//  El enlace se acuña al tocar, no al abrir la hoja: «Más tarde» no deja invitaciones que nadie mandó.
//

import SwiftUI

struct GroupCreatedInviteSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var iconCircleSize: CGFloat = 72 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 30 // A11Y-DT: @ScaledMetric

    let group: SplitGroup
    /// Quien invita en un grupo recién creado: solo su creador.
    let members: [SplitMember]

    @State private var isCreatingLink = false
    @State private var shareItem: ShareItem?
    @State private var didShare = false
    @State private var showError = false
    @State private var errorMessage = ""

    /// `.sheet(item:)` y no `isPresented` + otro `@State`: la hoja de compartir saldría vacía (regla de `swiftui-ds.md`).
    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: group.colorHex).opacity(0.22))
                            .frame(width: iconCircleSize, height: iconCircleSize)
                        Image(systemName: group.iconName)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(Color(hex: group.colorHex))
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.UXL12.createdTitle(group.name))
                            .font(DS.Typography.title2)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("group_created_title")
                        Text(L10n.UXL12.createdMessage)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    YalaPrimaryButton(
                        isCreatingLink ? L10n.Groups.Settings.generatingInvite : L10n.UXL12.createdInvite,
                        icon: "square.and.arrow.up",
                        isLoading: isCreatingLink
                    ) {
                        DS.Haptic.light()
                        Task { await invite() }
                    }
                    .accessibilityIdentifier("group_created_invite")

                    Button(L10n.UXL12.createdLater) { dismiss() }
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("group_created_later")
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xl)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .yalaScreenBackground(.partialSheet)
        .sheet(item: $shareItem, onDismiss: {
            // Mandó el enlace: lo que esta hoja proponía ya está hecho. Si cerró sin mandarlo, la hoja sigue para
            // reintentar o dejarlo para más tarde.
            if didShare { dismiss() }
        }) { item in
            ActivityView(activityItems: [item.url]) { completed in
                if completed { didShare = true }
            }
        }
        .alert(L10n.Common.error, isPresented: $showError) {
            Button(L10n.Common.ok) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func invite() async {
        guard !isCreatingLink else { return }
        isCreatingLink = true
        let outcome = await GroupInviteLinkMaker.make(for: group, members: members)
        isCreatingLink = false
        switch outcome {
        case .link(let url):
            shareItem = ShareItem(url: url)
        case .failed(let message):
            errorMessage = message
            showError = true
        }
    }
}
