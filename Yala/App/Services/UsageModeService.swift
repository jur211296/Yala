//
//  UsageModeService.swift
//  Yala
//
//  Ida y vuelta entre Yala completo y «Solo grupos» sobre una sesión privada viva (card p0iu, decisiones de Jürgen
//  del 2026-10-26). La ida es una VISTA (`GroupsOnlyViewMark`): no apaga la sesión privada, así que el bridge, el espejo
//  y los borrados de la sesión siguen como estaban. La vuelta no pasa por `FullModeActivationFlowLogic`: no hay nada
//  que elegir ni bienvenida que repetir.
//
//  Lo que es decisión pura vive en `UsageModeLogic`; esto solo ejecuta.
//

import Foundation
import SwiftData

@MainActor
enum UsageModeService {

    // MARK: - Ida

    /// «Usar solo grupos»: la shell se reduce, los avisos personales se pausan y todas las ventanas van a Grupos.
    static func enterGroupsOnly() async {
        let sessionState = SessionState.shared
        guard sessionState.hasPrivateSession else { return }
        // Primero la marca: con ella puesta, ningún productor vuelve a agendar mientras se retira lo pendiente.
        sessionState.prefersGroupsOnlyView = true
        for navigation in SceneRegistry.shared.allNavigations {
            navigation.selectMainTab(.groups)
        }
        await NotificationService.shared.cancelPendingPersonalNotifications()
        // Los resúmenes de pagos los retira su replan, con la pausa puesta: así sus marcas del tracker quedan al día.
        await ScheduledPaymentNotificationService.shared.replanSummaries()
    }

    // MARK: - Vuelta

    /// Lo que cuenta la hoja de la vuelta. Lanza si no se puede leer: «no pude leer» no es «no hay nada», y con un
    /// recuento falso a cero la vuelta saltaría la pregunta a quien sí tiene registros.
    static func savedSummary(context: ModelContext) throws -> UsageModeLogic.SavedSummary {
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        let saved = transactions.filter {
            UsageModeLogic.countsAsSavedRecord(
                splitExpenseID: $0.splitExpenseID, splitSettlementID: $0.splitSettlementID,
                balanceAdjustmentType: $0.balanceAdjustmentType)
        }
        let accounts = try context.fetch(FetchDescriptor<Account>())
            .filter { !$0.isSystemAccount && $0.parentAccountID == nil }
        let budgets = try context.fetchCount(FetchDescriptor<Budget>())
        let dates = saved.map(\.date)
        return UsageModeLogic.SavedSummary(
            records: saved.count, accounts: accounts.count, budgets: budgets,
            firstDate: dates.min(), lastDate: dates.max())
    }

    /// «Seguir donde lo dejé» y la vuelta sin registros: la shell vuelve entera y los avisos se reprograman. Los pagos
    /// programados que vencieron durante la pausa NO se procesan: cada uno sigue en su próxima fecha (encargo S11e).
    /// Todas las ventanas van al Panel.
    static func returnToFull(context: ModelContext) async {
        let sessionState = SessionState.shared
        // Antes de levantar la pausa (encargo S11e): lo que venció durante ella no sale de golpe. Con la marca aún puesta,
        // un kill aquí no deja que el siguiente arranque lo saque todo. Sin marca no hubo pausa que contener: saltar
        // «todo lo anterior a hoy» se llevaría vencimientos que nunca estuvieron pausados.
        let pause = GroupsOnlyViewMark.isOn() ? PausedPayments(since: GroupsOnlyViewMark.since()) : nil
        if let pause {
            ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(context: context, pausedSince: pause.since)
        }
        sessionState.prefersGroupsOnlyView = false
        for navigation in SceneRegistry.shared.allNavigations {
            navigation.selectMainTab(.panel)
        }
        await resumePersonalReminders(context: context, pause: pause)
    }

    /// El inicio de la pausa que la vuelta acaba de levantar (`nil` dentro = marca de un build sin la fecha).
    private struct PausedPayments {
        let since: Date?
    }

    /// Lo que la pausa dejó AGENDADO, de vuelta: los borradores de los pagos que vencen hoy, los recordatorios repetitivos
    /// y los resúmenes de pagos. **Los avisos inmediatos (vencidos, tarjeta, presupuestos) no se disparan aquí**: los manda el
    /// siguiente primer plano por su camino de siempre (`AppBootstrapper.ensureNotificationsScheduled`), que tiene su
    /// cadencia y sus marcas. Lanzarlos aquí era una ráfaga con la persona dentro de la app y, si la vuelta coincidía con
    /// ese primer plano, banners duplicados (review adversarial de p0iu). Los informes que tocaban durante la pausa no se
    /// recuperan: pausa es pausa.
    private static func resumePersonalReminders(context: ModelContext, pause: PausedPayments?) async {
        ScheduledPaymentDraftService.processDuePayments(context: context)
        // Lo que acaba de salir es de antes de la pausa; lo de la pausa que venía detrás, se salta (encargo S11e).
        if let pause {
            ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(context: context, pausedSince: pause.since)
        }
        do {
            let items = try context.fetch(FetchDescriptor<NotificationItem>())
            await NotificationService.shared.rescheduleAllNotifications(items: items.filter(\.isActive))
        } catch {
            #if DEBUG
            print("UsageModeService: Error fetching notification items: \(error)")
            #endif
        }
        ScheduledPaymentNotificationService.shared.setContext(context)
        await ScheduledPaymentNotificationService.shared.replanSummaries()
    }

    // MARK: - «Empezar de cero»

    /// La cuenta principal que propone el paso de «Empezar de cero»: nombre y divisa de antes.
    static func primaryAccountPrefill(context: ModelContext, fallbackCurrency: String) -> UsageModeLogic.AccountPrefill {
        let accounts: [Account]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("UsageModeService: Error fetching accounts: \(error)")
            #endif
            accounts = []
        }
        let candidates = accounts.map { account in
            UsageModeLogic.AccountCandidate(
                name: account.name, currencyCode: account.currencyCode, type: account.type,
                iconName: account.iconName, isArchived: account.isArchived,
                isSystemAccount: account.isSystemAccount, isLine: account.parentAccountID != nil,
                recordCount: account.transactions?.count ?? 0)
        }
        return UsageModeLogic.primaryAccountPrefill(candidates, fallbackCurrency: fallbackCurrency)
    }

    /// **Borra la vida personal conservando grupos, preferencias y avisos, crea la cuenta principal y vuelve a Yala
    /// completo** (D6 del Paso 0). Antes de llamar aquí no se ha borrado nada; la cuenta se crea en la misma vuelta del
    /// main actor que el borrado.
    ///
    /// **No emite la señal de vaciado al resto del Apple ID** (review adversarial de p0iu, D14). Las filas borradas viajan
    /// igual, por el espejo de iCloud o por la nube, como en «Vaciar datos» con la nube. La señal haría que el iPad se
    /// vaciara por su cuenta: sin un onboarding nuevo que la siga, repetía la bienvenida, se llevaba sus preferencias y
    /// borraba los avisos —que vuelven a este teléfono por el espejo—, justo lo que esta vuelta promete conservar.
    static func startFresh(context: ModelContext, accountName: String, currencyCode: String, accountType: String,
                           iconName: String) async throws {
        let sessionState = SessionState.shared
        // Los filtros de la sesión apuntan a cuentas y categorías que se van: fuera antes de borrar.
        sessionState.resetToDefaults()
        // Como «Vaciar datos»: la capa de borrado desmonta las pestañas para que ningún `@Query` mire filas que se van
        // (Buscar y Grupos siguen montados en solo grupos), y la espera deja que se desmonten.
        sessionState.isWipingData = true
        defer { sessionState.isWipingData = false }
        do { try await Task.sleep(for: .milliseconds(500)) } catch {}
        do {
            try DataWipeService.wipePersonalDataKeepingGroups(
                in: context, broadcastSignal: false, keepsPersonSettings: true)
        } catch {
            // El borrado guarda por lotes: uno que lanza a media lista baja `hasPersonalData` igual.
            sessionState.requestDeliberateWipeSettle()
            throw error
        }
        sessionState.requestDeliberateWipeSettle()

        // En la MISMA vuelta del main actor que el borrado: un kill no deja una sesión sin cuentas.
        let account = Account(
            name: accountName, currencyCode: currencyCode, colorHex: AppConstants.defaultColorHex,
            iconName: iconName, type: accountType)
        context.insert(account)
        try context.save()

        // El borrado se llevó los tipos de cambio: se recargan por el camino de siempre.
        sessionState.needsExchangeRateReload = true
        await returnToFull(context: context)
    }
}
