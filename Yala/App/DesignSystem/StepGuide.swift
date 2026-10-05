//
//  StepGuide.swift
//  Yala
//
//  Guía por pasos con la forma que Jürgen señaló el 2026-09-15
//  (`docs/design/referencias/2026-09-15-flujo-por-pasos-cancelar-suscripcion.jpg`). Seis rasgos, y cada uno tiene
//  su sitio aquí para que una guía nueva no tenga que rehacerlos:
//
//  1. Progreso doble arriba: barras y «Paso N de M», en la barra de navegación.
//  2. Cabecera con contexto: icono, qué se hace y una o dos líneas de datos.
//  3. Lista numerada con hilo. Solo el paso activo lleva botón; los demás se leen.
//  4. «Lo que vas a ver»: lo que la persona encontrará fuera de Yala (opcional).
//  5. Línea de garantía: qué NO va a pasar.
//  6. Dos salidas al pie con jerarquía: la de éxito, llena; «me atasqué», un enlace.
//
//  El estado (qué paso está activo) vive en `StepGuideProgress`, con test. En una ventana ancha el contenido se
//  queda en `DS.Adaptive.readableWidth`, centrado: decide el ancho, no el aparato.
//

import SwiftUI

/// Un paso de la guía.
struct StepGuideStep: Identifiable {
    /// Acción propia del paso, cuando hacerla ES el paso (abrir Atajos). Recibe con qué marcarlo como hecho, para
    /// que solo avance si la acción salió bien.
    struct Action {
        let title: String
        let systemImage: String
        let perform: (_ markDone: @escaping () -> Void) -> Void
    }

    let id: Int
    let title: String
    let detail: String?
    var action: Action?
}

/// La cabecera: qué se hace y con qué datos.
struct StepGuideHeader {
    let systemImage: String
    let tint: Color
    let title: String
    /// Líneas de contexto bajo el título, en gris. La primera es la descripción; las siguientes, datos vivos.
    let lines: [String]
}

struct YalaStepGuide<Preview: View>: View {
    let navigationTitle: String
    /// Identificador de la pantalla para XCUITest. Va en el título de la cabecera y no en la raíz: un id en un
    /// contenedor pisa los de sus hijos (`.claude/rules/testing.md`), y la guía tiene los suyos.
    let rootIdentifier: String
    let header: StepGuideHeader
    let steps: [StepGuideStep]
    let guarantee: String
    let successTitle: String
    let onSuccess: () -> Void
    let onStuck: () -> Void
    /// «Lo que vas a ver» para el paso activo (`nil` cuando ya no queda ninguno). Sin él, la sección no sale.
    let preview: ((Int?) -> Preview)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var markerSize: CGFloat = 28 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .title2) private var headerIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric

    @State private var progress: StepGuideProgress

    init(
        navigationTitle: String,
        rootIdentifier: String,
        header: StepGuideHeader,
        steps: [StepGuideStep],
        guarantee: String,
        successTitle: String,
        onSuccess: @escaping () -> Void,
        onStuck: @escaping () -> Void,
        preview: ((Int?) -> Preview)?
    ) {
        self.navigationTitle = navigationTitle
        self.rootIdentifier = rootIdentifier
        self.header = header
        self.steps = steps
        self.guarantee = guarantee
        self.successTitle = successTitle
        self.onSuccess = onSuccess
        self.onStuck = onStuck
        self.preview = preview
        _progress = State(initialValue: StepGuideProgress(total: steps.count))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                headerView
                stepsCard
                if let preview {
                    previewSection(preview(progress.activeIndex))
                }
                guaranteeLine
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.lg)
            .frame(maxWidth: DS.Adaptive.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) { footer }
        // Borde duro bajo el pie: con el borde suave, el vídeo de «Lo que vas a ver» se leía detrás de «Me atasqué».
        .scrollEdgeEffectStyle(.hard, for: .bottom)
        .yalaScreenBackground(.subtle)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .principal) {
                StepGuideProgressBar(progress: progress)
            }
        }
    }

    // MARK: - Cabecera

    private var headerView: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: header.systemImage)
                .font(DS.Typography.title3)
                .foregroundStyle(.white)
                .frame(width: headerIconSize, height: headerIconSize)
                .background(Circle().fill(header.tint))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(header.title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(rootIdentifier)
                ForEach(Array(header.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Pasos

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step, index: index, isLast: index == steps.count - 1)
            }
        }
        .solidCard(padding: DS.Spacing.lg)
    }

    private func stepRow(_ step: StepGuideStep, index: Int, isLast: Bool) -> some View {
        let phase = progress.phase(of: index)
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(step.title)
                .font(phase == .active ? DS.Typography.bodyBold : DS.Typography.body)
                .foregroundStyle(phase == .done ? .thSecondaryText : .thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("step_guide_step_\(index)")
                .accessibilityValue(Self.accessibilityValue(for: phase))
            // La ayuda larga solo en el paso activo: en los demás se lee el título y basta, y la tarjeta no crece
            // con párrafos que todavía no tocan.
            if phase == .active, let detail = step.detail, !detail.isEmpty {
                Text(detail)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if phase == .active {
                activeButton(for: step, index: index)
                    .padding(.top, DS.Spacing.sm)
            }
        }
        .padding(.leading, markerSize + DS.Spacing.md)
        .padding(.bottom, isLast ? DS.Spacing.none : DS.Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: markerSize, alignment: .topLeading)
        // El hilo: del pie del número al número siguiente. Va de fondo para que mida lo que mide la fila.
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle()
                    .fill(phase == .done ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.quaternary))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, markerSize)
                    .padding(.leading, markerSize / 2 - 1)
            }
        }
        .overlay(alignment: .topLeading) {
            marker(index: index, phase: phase)
        }
    }

    private func marker(index: Int, phase: StepGuidePhase) -> some View {
        ZStack {
            Circle()
                .fill(phase == .upcoming ? AnyShapeStyle(.quaternary) : AnyShapeStyle(theme.accent))
            if phase == .done {
                Image(systemName: "checkmark")
                    .font(DS.Typography.caption.weight(.bold))
                    .foregroundStyle(.white)
            } else {
                Text(index + 1, format: .number)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(phase == .active ? AnyShapeStyle(.white) : AnyShapeStyle(.thPrimaryText))
            }
        }
        .frame(width: markerSize, height: markerSize)
        .accessibilityHidden(true)
    }

    /// El único botón dentro de la lista. Si el paso trae acción propia, es esa; si no, «Hecho».
    @ViewBuilder
    private func activeButton(for step: StepGuideStep, index: Int) -> some View {
        let markDone = { advance(from: index) }
        Group {
            if let action = step.action {
                Button {
                    action.perform(markDone)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                        .font(DS.Typography.label)
                }
            } else {
                Button(action: markDone) {
                    Label(L10n.StepGuide.markDone, systemImage: "checkmark")
                        .font(DS.Typography.label)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(theme.accent)
        .accessibilityIdentifier("step_guide_action")
    }

    private func advance(from index: Int) {
        dsWithAnimation(reduceMotion, .easeOut(duration: DS.Animation.normal)) {
            progress.complete(index)
        }
    }

    // MARK: - Lo que vas a ver

    private func previewSection(_ content: Preview) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.StepGuide.whatYouWillSee)
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(.thSecondaryText)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }

    // MARK: - Garantía

    private var guaranteeLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.shield")
                .accessibilityHidden(true)
            Text(guarantee)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(DS.Typography.subheadline)
        .foregroundStyle(.thSecondaryText)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("step_guide_guarantee")
    }

    // MARK: - Pie

    private var footer: some View {
        VStack(spacing: DS.Spacing.md) {
            YalaPrimaryButton(successTitle, action: onSuccess)
            Button(action: onStuck) {
                Text(L10n.StepGuide.stuck)
                    .font(DS.Typography.subheadline)
                    .underline()
                    .foregroundStyle(.thPrimaryText)
                    .padding(.vertical, DS.Spacing.xs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("step_guide_stuck")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.sm)
        .frame(maxWidth: DS.Adaptive.readableWidth)
        .frame(maxWidth: .infinity)
    }

    static func accessibilityValue(for phase: StepGuidePhase) -> String {
        switch phase {
        case .done: return L10n.StepGuide.phaseDone
        case .active: return L10n.StepGuide.phaseActive
        case .upcoming: return L10n.StepGuide.phaseUpcoming
        }
    }
}

extension YalaStepGuide where Preview == EmptyView {
    /// Guía sin «Lo que vas a ver».
    init(
        navigationTitle: String,
        rootIdentifier: String,
        header: StepGuideHeader,
        steps: [StepGuideStep],
        guarantee: String,
        successTitle: String,
        onSuccess: @escaping () -> Void,
        onStuck: @escaping () -> Void
    ) {
        self.init(
            navigationTitle: navigationTitle, rootIdentifier: rootIdentifier, header: header, steps: steps, guarantee: guarantee,
            successTitle: successTitle, onSuccess: onSuccess, onStuck: onStuck, preview: nil)
    }
}

// MARK: - Progreso doble

/// Barras y «Paso N de M». Un solo elemento para VoiceOver, que lee el texto.
struct StepGuideProgressBar: View {
    let progress: StepGuideProgress

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<progress.total, id: \.self) { index in
                    Capsule()
                        .fill(progress.isBarFilled(index) ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.quaternary))
                        .frame(width: 24, height: 5)
                }
            }
            .accessibilityHidden(true)
            Text(L10n.StepGuide.progress(progress.displayedStep, progress.total))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("step_guide_progress")
    }
}
