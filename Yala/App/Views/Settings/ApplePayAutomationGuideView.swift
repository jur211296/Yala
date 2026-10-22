//
//  ApplePayAutomationGuideView.swift
//  Yala
//
//  «Registrar con Apple Pay» como guía por pasos (`YalaStepGuide`, referencia del 2026-09-15). Hasta el 2026-10-02
//  era un carrusel de vídeo más en Tutoriales; es el único tutorial que se hace FUERA de Yala —en Atajos—, y por eso
//  el primero que pasa a la forma de la referencia (lo pidió Jürgen).
//
//  Lo que pone cada rasgo, sin copy de pasos nuevo: los cuatro pasos y sus textos son los del tutorial; el primero
//  abre Atajos y queda hecho al abrirse; «Lo que vas a ver» es el vídeo grabado de ese paso; la cabecera cuenta los
//  pagos de Apple Pay que esperan en la bandeja, que es la señal de que la automatización ya funciona.
//

import SwiftData
import SwiftUI

struct ApplePayAutomationGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Borradores de Apple Pay sin aprobar: el dato vivo de la cabecera.
    @Query(filter: ApplePayAutomationGuideView.pendingApplePayDrafts)
    private var pendingDrafts: [InboxDraft]

    @State private var isVideoPlaying = false
    @State private var showSupport = false

    private let tutorial = Tutorial.applePay

    static let pendingApplePayDrafts: Predicate<InboxDraft> = {
        let source = DraftSourceType.applePay.rawValue
        let pending = DraftStatus.pending.rawValue
        return #Predicate<InboxDraft> { $0.sourceTypeRaw == source && $0.statusRaw == pending }
    }()

    var body: some View {
        YalaStepGuide(
            navigationTitle: tutorial.title,
            rootIdentifier: "applepay_guide_root",
            header: StepGuideHeader(
                systemImage: tutorial.icon,
                tint: tutorial.color,
                title: tutorial.title,
                lines: [tutorial.introDescription, L10n.Tutorials.applePayPendingDrafts(pendingDrafts.count)]),
            steps: steps,
            guarantee: L10n.Tutorials.applePayGuarantee,
            successTitle: L10n.Action.done,
            onSuccess: finish,
            onStuck: { showSupport = true },
            preview: { activeIndex in videoPreview(for: activeIndex) })
        .sheet(isPresented: $showSupport) {
            SupportFormSheet()
        }
    }

    /// Los pasos del tutorial. El primero lleva su acción: abrir Atajos ES el paso, así que queda hecho si iOS
    /// abrió la app (sin Atajos instalada, `openURL` contesta que no y el paso sigue activo).
    private var steps: [StepGuideStep] {
        tutorial.steps.map { step in
            var guideStep = StepGuideStep(id: step.id, title: step.title, detail: step.description)
            if step.id == 0 {
                guideStep.action = StepGuideStep.Action(
                    title: L10n.Tutorials.applePayOpenShortcuts,
                    systemImage: "arrow.up.forward.app",
                    perform: { markDone in openShortcuts(then: markDone) })
            }
            return guideStep
        }
    }

    private func openShortcuts(then markDone: @escaping () -> Void) {
        guard let url = URL(string: "shortcuts://") else { return }
        openURL(url) { accepted in
            if accepted { markDone() }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: tutorial.completionKey)
        dismiss()
    }

    // MARK: - Lo que vas a ver

    /// El vídeo del paso activo; con todos hechos, el del último. Cambiar de paso lo deja en pausa en su primer
    /// fotograma, igual que el carrusel de antes.
    @ViewBuilder
    private func videoPreview(for activeIndex: Int?) -> some View {
        let allSteps = tutorial.steps
        if let step = (activeIndex.flatMap { allSteps.indices.contains($0) ? allSteps[$0] : nil }) ?? allSteps.last,
           step.videoURL != nil {
            LoopingVideoView(step: step, isPlaying: $isVideoPlaying, loopEnabled: !reduceMotion)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .frame(maxHeight: 380)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .overlay { playOverlay }
                .frame(maxWidth: .infinity)
                .onChange(of: step.id) { isVideoPlaying = false }
                .accessibilityIdentifier("step_guide_preview")
        }
    }

    @ViewBuilder
    private var playOverlay: some View {
        if !isVideoPlaying {
            Button {
                isVideoPlaying = true
            } label: {
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(.black.opacity(0.15))
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(DS.Typography.amountLarge)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                    }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(L10n.StepGuide.whatYouWillSee)
        }
    }
}
