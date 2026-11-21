//
//  FlujoElegirPagosSheet.swift
//  Yala
//
//  «Elige los pagos» (encargo del 2026-11-20, pregunta `seleccion`, opción B): casillas con los pagos del lado de la
//  línea, activos primero; buscador desde 8. Los que ya están en otra línea salen aparte con «En Renta»; marcar uno
//  avisa antes de guardar que se moverá aquí. «Listo» devuelve la selección; la línea no se guarda hasta «Guardar».
//

import SwiftUI

struct FlujoElegirPagosSheet: View {
    let pagos: [ScheduledPayment]
    let esIngreso: Bool
    let monedaPlan: String
    /// Por id de pago, el nombre de la otra línea que lo tiene.
    let enOtraLinea: [UUID: String]
    let elegidosAlAbrir: [UUID]
    var onListo: ([UUID]) -> Void

    @State private var elegidos: [UUID]
    @State private var busqueda = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    init(pagos: [ScheduledPayment], esIngreso: Bool, monedaPlan: String, enOtraLinea: [UUID: String],
         elegidos: [UUID], onListo: @escaping ([UUID]) -> Void) {
        self.pagos = pagos
        self.esIngreso = esIngreso
        self.monedaPlan = monedaPlan
        self.enOtraLinea = enOtraLinea
        self.elegidosAlAbrir = elegidos
        self.onListo = onListo
        _elegidos = State(initialValue: elegidos)
    }

    private var visibles: [ScheduledPayment] {
        let delLado = FlujoPagosDeLineaLogica.ordenados(pagos.filter { FlujoPagosDeLineaLogica.ofrecible($0, esIngreso: esIngreso) })
        let texto = busqueda.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else { return delLado }
        return delLado.filter { $0.name.localizedStandardContains(texto) }
    }

    private var libres: [ScheduledPayment] { visibles.filter { enOtraLinea[$0.id] == nil } }
    private var tomados: [ScheduledPayment] { visibles.filter { enOtraLinea[$0.id] != nil } }

    /// Los pagos de otra línea que se marcaron: se moverán aquí.
    private var seMueven: [ScheduledPayment] {
        pagos.filter { enOtraLinea[$0.id] != nil && elegidos.contains($0.id) && !elegidosAlAbrir.contains($0.id) }
    }

    private var muestraBuscador: Bool {
        FlujoPagosDeLineaLogica.muestraBuscador(pagos.filter { FlujoPagosDeLineaLogica.ofrecible($0, esIngreso: esIngreso) }.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    if muestraBuscador { buscador }
                    if visibles.isEmpty && busqueda.isEmpty {
                        Text(L10n.FlujoDetalleLinea.elegirVacio(esIngreso: esIngreso))
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !libres.isEmpty { seccion(L10n.FlujoDetalleLinea.elegirSinLinea, libres) }
                    if !tomados.isEmpty { seccion(L10n.FlujoDetalleLinea.elegirEnOtra, tomados) }
                    ForEach(seMueven, id: \.id) { pago in
                        aviso(L10n.FlujoDetalleLinea.elegirAvisoMover(pago.name, desde: enOtraLinea[pago.id] ?? ""))
                    }
                    Text(L10n.FlujoDetalleLinea.elegirPie)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Spacing.lg)
                .readableColumn()
            }
            .scrollDismissesKeyboard(.interactively)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.FlujoDetalleLinea.elegirTitulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "checkmark", label: L10n.FlujoDetalleLinea.elegirListo) {
                        DS.Haptic.selection()
                        onListo(elegidos)
                        dismiss()
                    }
                    .accessibilityIdentifier("cashflow_pick_payments_done")
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("cashflow_pick_payments_sheet")
    }

    private var buscador: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(L10n.FlujoDetalleLinea.elegirBuscar, text: $busqueda)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("cashflow_pick_payments_search")
        }
        .padding(DS.Spacing.md)
        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }

    private func seccion(_ titulo: String, _ lista: [ScheduledPayment]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(titulo)
                .font(DS.Typography.subheadlineEmphasized)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(lista.enumerated()), id: \.element.id) { indice, pago in
                    // Arranca donde arranca el texto: marca e icono miden `badgeSmall` cada uno.
                    if indice > 0 { Divider().padding(.leading, DS.Spacing.lg + 2 * (DS.Icon.badgeSmall + DS.Spacing.md)) }
                    fila(pago)
                }
            }
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))
        }
    }

    private func fila(_ pago: ScheduledPayment) -> some View {
        let marcado = elegidos.contains(pago.id)
        let otra = enOtraLinea[pago.id]
        return Button {
            DS.Haptic.selection()
            if marcado { elegidos.removeAll { $0 == pago.id } } else { elegidos.append(pago.id) }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: marcado ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.headline)
                    .foregroundStyle(marcado ? theme.accentText : Color(uiColor: .tertiaryLabel))
                    .frame(width: DS.Icon.badgeSmall)
                    .accessibilityHidden(true)
                FlujoPagoIconoView(pago: pago)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(pago.name)
                        .font(DS.Typography.body.weight(marcado ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Text(detalle(pago, otra: otra, marcado: marcado))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.none)
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(marcado ? .isSelected : [])
        .accessibilityIdentifier("cashflow_pick_payment_row")
    }

    /// «En Renta · 500.00 USD · mensual», «Se moverá aquí · …» o «S/ 44.90 · mensual».
    private func detalle(_ pago: ScheduledPayment, otra: String?, marcado: Bool) -> String {
        let importe = pago.currencyCode == monedaPlan
            ? appPreferences.currency(abs(pago.amount), currencyCode: monedaPlan)
            : FlujoMonedaTexto.original(abs(pago.amount), moneda: pago.currencyCode)
        let frecuencia = ScheduledPaymentDetailLogic.frequencyText(
            isRecurring: pago.isRecurring, recurrenceType: pago.recurrenceType, interval: pago.recurrenceInterval
        )
        var partes = [importe, frecuencia]
        if !pago.isActive { partes.append(L10n.FlujoDetalleLinea.pagoPausado) }
        if let otra {
            let mueve = marcado && !elegidosAlAbrir.contains(pago.id)
            partes.insert(mueve ? L10n.FlujoDetalleLinea.elegirSeMovera : L10n.FlujoDetalleLinea.elegirEnLinea(otra), at: 0)
        }
        return partes.joined(separator: " · ")
    }

    private func aviso(_ texto: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "arrow.left.arrow.right")
                .foregroundStyle(theme.accentText)
                .accessibilityHidden(true)
            Text(texto)
                .font(DS.Typography.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Color.secondary.opacity(0.1)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cashflow_pick_payments_move_notice")
    }
}
