//
//  RecurringProposalsBanner.swift
//  Yala
//
//  «Pagos que se repiten» arriba de Pagos planificados. Desde el 17-nov (Jürgen, sobre TestFlight) es un banner de una
//  frase —«Encontramos 3 pagos que se repiten. Puedes agregarlos a tus pagos planificados.»— en lugar de la tarjeta con
//  la lista entera (lote S1, opción P1). Tocarlo abre la hoja con todos los casos (`RecurringProposalsListSheet`).
//  Desaparece cuando no queda nada por responder.
//

import SwiftData
import SwiftUI

/// Lo que el banner y su hoja saben del historial. Se recalcula al aparecer y cuando cambian los datos con la página a la
/// vista; con la página oculta solo se apunta y se recalcula al volver (las seis páginas siguen montadas).
@MainActor
@Observable
final class RecurringProposalsModel {
    private(set) var items: [RecurringProposalsSource.Item] = []
    private var isStale = true

    /// Con la función apagada no se lee nada: queda pendiente para cuando se encienda.
    func refreshIfNeeded(context: ModelContext, isEnabled: Bool) {
        guard isStale, isEnabled else { return }
        refresh(context: context)
    }

    func markStale() { isStale = true }

    func refresh(context: ModelContext, now: Date = .now) {
        isStale = false
        do {
            items = try RecurringProposalsSource.load(context: context, now: now)
        } catch {
            #if DEBUG
            print("RecurringProposalsModel: Error: \(error)")
            #endif
            items = []
        }
    }

    /// Lo que se enseña según lo que la persona ya contestó.
    func visibleItems(preferences: RecurringProposalPreferences) -> [RecurringProposalsSource.Item] {
        let visibleKeys = Set(preferences.visible(items.map(\.proposal)).map(\.key))
        return items.filter { visibleKeys.contains($0.proposal.key) }
    }
}

struct RecurringProposalsBanner: View {
    /// Lleva la lista al mes del primer cobro del pago recién creado («Ver» del aviso).
    let onShowMonth: (Date) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.isRootPageShown) private var isRootPageShown
    @Environment(\.yalaTheme) private var theme

    @State private var model = RecurringProposalsModel()
    @State private var showsList = false

    private var preferences: RecurringProposalPreferences { .shared }

    var body: some View {
        let count = model.visibleItems(preferences: preferences).count
        VStack(spacing: DS.Spacing.none) {
            // El margen va dentro del `if`: sin propuestas, Pagos planificados queda exactamente como antes.
            if count > 0 {
                banner(count: count)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)
            }
        }
        // Las páginas de pestaña están montadas desde el arranque: con la página oculta no se lee el historial.
        .onAppear { if isRootPageShown { refreshIfNeeded() } }
        .onChange(of: sessionState.dataVersion) { _, _ in dataChanged() }
        .onChange(of: isRootPageShown) { _, shown in pageShownChanged(shown) }
        .onChange(of: preferences.isEnabled) { _, _ in if isRootPageShown { refreshIfNeeded() } }
        .sheet(isPresented: $showsList) {
            RecurringProposalsListSheet(model: model) { month in showMonth(month) }
        }
    }

    private func banner(count: Int) -> some View {
        Button {
            showsList = true
        } label: {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                ZStack {
                    Circle().fill(theme.accent)
                    Image(systemName: PaymentCategory.recurring.iconName)
                        .font(DS.Typography.label)
                        .foregroundStyle(theme.onAccent)
                }
                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                .accessibilityHidden(true)

                Text(PagosRecurrentesText.bannerFound(count))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .panelCard(small: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("recurring_proposals_banner")
    }

    // MARK: - Refresco

    private func refreshIfNeeded() {
        model.refreshIfNeeded(context: modelContext, isEnabled: preferences.isEnabled)
    }

    private func dataChanged() {
        model.markStale()
        if isRootPageShown { refreshIfNeeded() }
    }

    private func pageShownChanged(_ shown: Bool) {
        if shown { refreshIfNeeded() }
    }

    /// «Ver» del aviso de pago creado: cierra la hoja (si sigue abierta) y lleva Pagos planificados a ese mes.
    private func showMonth(_ month: Date) {
        showsList = false
        onShowMonth(month)
    }
}
