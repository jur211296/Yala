//
//  FlujoPagosDeLineaCard.swift
//  Yala
//
//  «Pagos de esta línea» en «Cálculo del monto» (encargo del 2026-11-20, maqueta «Límites con pagos y monedas»): una fila
//  por pago con su logo, nombre, frecuencia y próxima fecha, e importe en su moneda (y, si es otra, cuánto vale ese mes);
//  «Agregar pago» abre «Elige los pagos»; y debajo «Sumar un monto extra».
//

import SwiftUI

struct FlujoPagosDeLineaCard: View {
    /// Los pagos elegidos con lo que suman en el mes que se ve.
    let pagos: [FlujoLimiteEnMoneda.PagoDelMes]
    let pagosPorID: [UUID: ScheduledPayment]
    let monedaPlan: String
    let mes: Date
    @Binding var conExtra: Bool
    @Binding var extraTexto: String
    var onAgregar: () -> Void
    var onQuitar: (UUID) -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.FlujoDetalleLinea.pagosTitulo)
                    .font(DS.Typography.subheadlineEmphasized)
                    .accessibilityAddTraits(.isHeader)
                    // En el título y no en la tarjeta: un id en el contenedor pisaría el de cada fila.
                    .accessibilityIdentifier("cashflow_line_payments_card")
                VStack(spacing: DS.Spacing.none) {
                    ForEach(pagos) { pago in
                        fila(pago)
                        Divider().padding(.leading, DS.Spacing.lg + DS.Icon.badgeSmall + DS.Spacing.md)
                    }
                    agregarFila
                }
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))
            }
            extraCard
        }
    }

    // MARK: - Un pago

    private func fila(_ pago: FlujoLimiteEnMoneda.PagoDelMes) -> some View {
        let vivo = pagosPorID[pago.id]
        return HStack(alignment: .center, spacing: DS.Spacing.md) {
            icono(vivo)
            AdaptiveRowStack(spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(vivo?.name ?? L10n.FlujoDetalleLinea.pagoNoEsta)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detalle(pago, vivo: vivo))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } trailing: {
                importes(pago)
            }
            Menu {
                Button(role: .destructive) { onQuitar(pago.id) } label: {
                    Label(L10n.FlujoDetalleLinea.quitarPago, systemImage: "minus.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(DS.Typography.label.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.FlujoDetalleLinea.quitarPagoAccesible(vivo?.name ?? L10n.FlujoDetalleLinea.pagoNoEsta))
            .accessibilityIdentifier("cashflow_line_payment_remove")
        }
        .padding(.leading, DS.Spacing.lg)
        .padding(.trailing, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cashflow_line_payment_row")
    }

    @ViewBuilder
    private func icono(_ pago: ScheduledPayment?) -> some View {
        if let pago, let logo = PagoLogoComercio.logo(for: pago) {
            SubscriptionBrandBadge(logo: logo, diameter: DS.Icon.badgeSmall, isDecorative: true)
        } else {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.18))
                Image(systemName: "calendar.badge.clock")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
            .accessibilityHidden(true)
        }
    }

    /// «Mensual · próximo: 12 dic.», o por qué no suma este mes.
    private func detalle(_ pago: FlujoLimiteEnMoneda.PagoDelMes, vivo: ScheduledPayment?) -> String {
        let mesNombre = CashFlowMonthSummaryLogic.monthInSentence(mes)
        switch pago.estado {
        case .pausado: return L10n.FlujoDetalleLinea.pagoPausado
        case .terminado(let fin): return L10n.FlujoDetalleLinea.pagoTermino(CashFlowMonthSummaryLogic.monthInSentence(fin))
        case .noCae: return L10n.FlujoDetalleLinea.pagoNoCae(mesNombre)
        case .noEsta: return L10n.FlujoDetalleLinea.pagoNoEsta
        case .suma:
            guard let vivo else { return "" }
            let frecuencia = ScheduledPaymentDetailLogic.frequencyText(
                isRecurring: vivo.isRecurring, recurrenceType: vivo.recurrenceType, interval: vivo.recurrenceInterval
            )
            let texto = L10n.FlujoDetalleLinea.pagoProximo(
                frecuencia, vivo.nextDueDate.formatted(Date.FormatStyle().day().month(.abbreviated).locale(AppLocale.current))
            )
            return pago.esVariable ? "\(texto) · \(L10n.FlujoDetalleLinea.pagoVariable)" : texto
        }
    }

    /// El importe en su moneda y, si es otra, lo que vale ese mes en la del flujo.
    @ViewBuilder
    private func importes(_ pago: FlujoLimiteEnMoneda.PagoDelMes) -> some View {
        let suma = pago.estado == .suma
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: DS.Spacing.xxs) {
            Group {
                if pago.moneda == monedaPlan {
                    Text(appPreferences.currency(pago.importe, currencyCode: monedaPlan))
                } else {
                    Text(FlujoMonedaTexto.original(pago.importe, moneda: pago.moneda))
                }
            }
            .font(DS.Typography.amountSmall.monospacedDigit())
            .foregroundStyle(suma ? .primary : .secondary)
            if suma, pago.moneda != monedaPlan {
                Text(appPreferences.currency(pago.convertido, currencyCode: monedaPlan,
                                             isEstimate: pago.tasa.esAproximada))
                    .font(DS.Typography.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var agregarFila: some View {
        Button(action: onAgregar) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "plus.circle.fill")
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.accentText)
                    .frame(width: DS.Icon.badgeSmall)
                    .accessibilityHidden(true)
                Text(L10n.FlujoDetalleLinea.agregarPago)
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(theme.accentText)
                Spacer(minLength: DS.Spacing.none)
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cashflow_line_payments_add")
    }

    // MARK: - El extra

    private var extraCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            Toggle(isOn: $conExtra) {
                Text(L10n.FlujoDetalleLinea.extraInterruptor)
                    .font(DS.Typography.body)
            }
            .tint(theme.accent)
            .padding(DS.Spacing.lg)
            .accessibilityIdentifier("cashflow_line_extra_toggle")
            if conExtra {
                Divider().padding(.leading, DS.Spacing.lg)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DS.Spacing.sm) {
                        extraRotulo
                        Spacer(minLength: DS.Spacing.sm)
                        extraCampo
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        extraRotulo
                        extraCampo
                    }
                }
                .padding(DS.Spacing.lg)
            }
        }
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))
    }

    private var extraRotulo: some View {
        Text(L10n.FlujoDetalleLinea.extraCampo)
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
    }

    private var extraCampo: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(appPreferences.currencyIdentifier(for: monedaPlan))
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(L10n.FlujoDetalleLinea.extraCampo, text: $extraTexto,
                      prompt: Text(verbatim: "0").foregroundStyle(.tertiary))
                .amountKeyboard()
                .font(DS.Typography.body.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 80)
                .onChange(of: extraTexto) { _, nuevo in
                    let filtrado = AmountInputHelper.filterAmountInput(nuevo)
                    if filtrado != nuevo { extraTexto = filtrado }
                }
                .accessibilityIdentifier("cashflow_line_extra_amount")
        }
    }
}
