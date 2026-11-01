//
//  Catalog.swift
//  WidgetRender
//
//  Qué se pinta: cada widget en cada tamaño que admite, con la entrada que construye su propio proveedor a partir de
//  la foto cargada (la misma construcción que en la pantalla de inicio) y, aparte, los estados vacíos.
//
//  Cuando un widget cambia de API, este fichero cambia con él: es el único sitio del banco que nombra tipos del widget.
//

import SwiftUI
import WidgetKit

struct RenderItem {
    /// Nombre del fichero sin tamaño ni modo: `saldo`, `gastos`…
    let slug: String
    let spec: FamilySpec
    var background: RenderBackground = .card
    /// Modos en los que tiene sentido: los de la pantalla bloqueada solo se ven en uno.
    var modes: [RenderMode] = RenderMode.allCases
    let view: () -> AnyView
}

@MainActor
enum Catalog {
    static func items() -> [RenderItem] {
        var items: [RenderItem] = []
        let xlv = FamilySpec.extraLargePortrait

        // Saldo
        for spec in [FamilySpec.small, .medium] {
            items.append(RenderItem(slug: "saldo", spec: spec) {
                AnyView(BalanceWidgetView(entry: BalanceWidgetProvider().createEntry(for: BalanceWidgetIntent())))
            })
        }

        // Gastos
        for spec in [FamilySpec.small, .medium] {
            items.append(RenderItem(slug: "gastos", spec: spec) {
                AnyView(ExpenseWidgetView(entry: ExpenseWidgetProvider().createEntry(for: ExpenseWidgetIntent())))
            })
        }

        // Entradas y salidas
        for spec in [FamilySpec.small, .medium, .large] + (xlv.map { [$0] } ?? []) {
            items.append(RenderItem(slug: "entradas-y-salidas", spec: spec) {
                AnyView(CashFlowWidgetView(entry: CashFlowWidgetProvider().createEntry(for: CashFlowWidgetIntent())))
            })
        }

        // Categorías y subcategorías (también en el iPhone SE, el tamaño más justo)
        for spec in [FamilySpec.medium, .mediumSE] {
            items.append(RenderItem(slug: "top-categorias", spec: spec) {
                AnyView(TopCategoriesWidgetView(entry: TopCategoriesWidgetProvider().createEntry(for: TopCategoriesWidgetIntent())))
            })
            items.append(RenderItem(slug: "top-subcategorias", spec: spec) {
                AnyView(TopSubcategoriesWidgetView(entry: TopSubcategoriesWidgetProvider().createEntry(for: TopSubcategoriesWidgetIntent())))
            })
        }
        for spec in [FamilySpec.large, .largeSE] {
            items.append(RenderItem(slug: "tarta-categorias", spec: spec) {
                AnyView(CategoriesPieWidgetView(entry: CategoriesPieWidgetProvider().createEntry(for: CategoriesPieWidgetIntent())))
            })
            items.append(RenderItem(slug: "tarta-subcategorias", spec: spec) {
                AnyView(SubcategoriesPieWidgetView(entry: SubcategoriesPieWidgetProvider().createEntry(for: SubcategoriesPieWidgetIntent())))
            })
        }

        // Últimos registros
        for spec in [FamilySpec.medium, .large] {
            items.append(RenderItem(slug: "ultimos-registros", spec: spec) {
                AnyView(LatestRecordsWidgetView(
                    entry: LatestRecordsProvider().createEntry(for: LatestRecordsWidgetIntent(), family: spec.family)))
            })
        }

        // Pagos planificados
        for spec in [FamilySpec.medium, .large] + (xlv.map { [$0] } ?? []) {
            items.append(RenderItem(slug: "pagos", spec: spec) {
                AnyView(ScheduledPaymentsWidgetView(
                    entry: ScheduledPaymentsProvider().createEntry(for: ScheduledPaymentsWidgetIntent(), family: spec.family)))
            })
        }

        // Presupuestos
        for spec in [FamilySpec.medium, .large] {
            items.append(RenderItem(slug: "presupuestos", spec: spec) {
                AnyView(BudgetsWidgetView(
                    entry: BudgetsWidgetProvider().createEntry(for: BudgetsWidgetIntent(), family: spec.family)))
            })
        }

        // Grupos (S35f3)
        for spec in [FamilySpec.medium, .large] {
            items.append(RenderItem(slug: "grupos", spec: spec) {
                AnyView(GroupsWidgetView(entry: GroupsWidgetProvider().createEntry()))
            })
        }

        // Resumen del mes
        for spec in [FamilySpec.extraLarge] + (xlv.map { [$0] } ?? []) {
            items.append(RenderItem(slug: "resumen-del-mes", spec: spec) {
                AnyView(MonthSummaryWidgetView(entry: MonthSummaryProvider().createEntry()))
            })
        }

        // Entrada rápida
        items.append(RenderItem(slug: "nuevo-registro", spec: .small, background: .fill(QuickEntryAction.manual.fill)) {
            AnyView(QuickManualEntryWidgetView())
        })
        items.append(RenderItem(slug: "nuevo-registro", spec: .medium) { AnyView(QuickManualEntryWidgetView()) })
        items.append(RenderItem(slug: "registro-por-voz", spec: .small, background: .fill(QuickEntryAction.voice.fill)) {
            AnyView(QuickVoiceEntryWidgetView())
        })
        items.append(RenderItem(slug: "escanear-recibo", spec: .small, background: .fill(QuickEntryAction.image.fill)) {
            AnyView(QuickImageEntryWidgetView())
        })

        // Pantalla bloqueada (se ve en un solo modo: vibrante sobre el fondo de pantalla)
        let lock: [RenderMode] = [.oscuro]
        items.append(RenderItem(slug: "bloqueo-saldo", spec: .circular, modes: lock) {
            AnyView(AccessoryBalanceWidgetView(entry: AccessoryBalanceProvider().createEntry()))
        })
        items.append(RenderItem(slug: "bloqueo-gastos", spec: .circular, modes: lock) {
            AnyView(AccessoryExpenseWidgetView(entry: AccessoryExpenseProvider().createEntry()))
        })
        items.append(RenderItem(slug: "bloqueo-presupuesto", spec: .rectangular, modes: lock) {
            AnyView(AccessoryBudgetWidgetView(entry: AccessoryBudgetProvider().createEntry()))
        })
        items.append(RenderItem(slug: "bloqueo-presupuesto", spec: .circular, modes: lock) {
            AnyView(AccessoryBudgetWidgetView(entry: AccessoryBudgetProvider().createEntry()))
        })
        items.append(RenderItem(slug: "bloqueo-proximo-pago", spec: .rectangular, modes: lock) {
            AnyView(AccessoryNextPaymentWidgetView(entry: AccessoryNextPaymentProvider().createEntry()))
        })

        // Estados vacíos
        items.append(RenderItem(slug: "vacio-presupuestos", spec: .medium, modes: [.claro]) {
            AnyView(BudgetsWidgetView(entry: BudgetsEntry(
                date: RenderClock.now, budgets: [], currencyDisplayFormat: "symbol", isPlaceholder: false, hasNoBudgets: true)))
        })
        items.append(RenderItem(slug: "vacio-pagos", spec: .medium, modes: [.claro]) {
            AnyView(ScheduledPaymentsWidgetView(entry: ScheduledPaymentsEntry(
                date: RenderClock.now, payments: [], currencyDisplayFormat: "symbol", isPlaceholder: false, hasNoPayments: true)))
        })
        items.append(RenderItem(slug: "vacio-registros", spec: .medium, modes: [.claro]) {
            AnyView(LatestRecordsWidgetView(entry: LatestRecordsEntry(
                date: RenderClock.now, transactions: [], currencyDisplayFormat: "symbol", isPlaceholder: false)))
        })
        items.append(RenderItem(slug: "vacio-grupos", spec: .medium, modes: [.claro]) {
            AnyView(GroupsWidgetView(entry: GroupsWidgetEntry(
                date: RenderClock.now,
                groups: WidgetGroupsSummary(iOwe: [], owedToMe: [], activeGroupCount: 0, groups: []),
                currencyDisplayFormat: "symbol", isPlaceholder: false)))
        })
        items.append(RenderItem(slug: "grupos-sin-foto-de-grupos", spec: .medium, modes: [.claro]) {
            AnyView(GroupsWidgetView(entry: GroupsWidgetEntry(
                date: RenderClock.now, groups: nil, currencyDisplayFormat: "symbol", isPlaceholder: false)))
        })
        items.append(RenderItem(slug: "sin-datos-de-yala", spec: .small, modes: [.claro]) {
            AnyView(WidgetNoDataInviteView(message: "widget.empty.openYalaBalance"))
        })

        return items
    }
}
