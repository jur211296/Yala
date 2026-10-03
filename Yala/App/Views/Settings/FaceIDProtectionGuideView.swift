//
//  FaceIDProtectionGuideView.swift
//  Yala
//
//  Guía informativa: cómo proteger la app con el bloqueo NATIVO de iOS
//  (mantener presionado el ícono → "Requerir Face ID"). Reemplaza al antiguo
//  bloqueo biométrico in-app. Sin LocalAuthentication — solo educación.
//
//  Desde el 2026-10-02 es una guía por pasos (`YalaStepGuide`, referencia del 2026-09-15). Los tres pasos se hacen
//  en la pantalla de inicio y iOS no le dice a Yala si el bloqueo quedó puesto, así que cada paso se marca con
//  «Hecho». «Lo que vas a ver» es el menú del icono con la opción que hay que tocar, con el icono que la persona
//  tiene puesto.
//

import SwiftUI

struct FaceIDProtectionGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSupport = false

    private var steps: [StepGuideStep] {
        [
            StepGuideStep(id: 0, title: L10n.FaceIDGuide.step1Title, detail: L10n.FaceIDGuide.step1Detail),
            StepGuideStep(id: 1, title: L10n.FaceIDGuide.step2Title, detail: L10n.FaceIDGuide.step2Detail),
            StepGuideStep(id: 2, title: L10n.FaceIDGuide.step3Title, detail: L10n.FaceIDGuide.step3Detail)
        ]
    }

    var body: some View {
        YalaStepGuide(
            navigationTitle: L10n.Settings.faceIDProtection,
            rootIdentifier: "faceid_guide_root",
            header: StepGuideHeader(
                systemImage: "faceid",
                tint: DS.Semantic.successForeground,
                title: L10n.FaceIDGuide.title,
                lines: [L10n.FaceIDGuide.subtitle]),
            steps: steps,
            guarantee: L10n.FaceIDGuide.guarantee,
            successTitle: L10n.Action.done,
            onSuccess: { dismiss() },
            onStuck: { showSupport = true },
            preview: { _ in HomeScreenMenuPreview() })
        .sheet(isPresented: $showSupport) {
            SupportFormSheet()
        }
    }
}

/// Réplica pequeña del menú que sale al mantener presionado el icono de Yala: el icono que la persona tiene puesto
/// y la opción «Requerir Face ID». El nombre de la opción es el que iOS usa en cada idioma
/// (`faceIDGuide.previewAction`, el mismo término que el paso 2).
private struct HomeScreenMenuPreview: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 44 // A11Y-DT: @ScaledMetric

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            HStack(spacing: DS.Spacing.md) {
                appIcon
                Text(verbatim: "Yala")
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thPrimaryText)
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)

            Divider()

            HStack {
                Text(L10n.FaceIDGuide.previewAction)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "faceid")
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
        }
        .solidCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("step_guide_preview")
    }

    @ViewBuilder
    private var appIcon: some View {
        let current = AppIconOption.allCases.first { $0.iconName == UIApplication.shared.alternateIconName }
            ?? .original
        if let image = UIImage(named: current.previewImageName)?
            .imageAsset?.image(with: UITraitCollection(userInterfaceStyle: .light)) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.225, style: .continuous))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "app.fill")
                .font(DS.Typography.title2)
                .foregroundStyle(.thAccent)
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
        }
    }
}
