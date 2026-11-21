//
//  AsistentePagoCompartidoTests.swift
//  YalaTests
//
//  El asistente de «Nuevo pago planificado» completo (encargo del 21-nov): pregunta si es compartido solo con algún
//  grupo activo, pide la división antes de seguir, «¿Algo más?» no frena el camino común, y lo que crea —por él o por
//  «Reusar»— es un pago compartido que la Bandeja convierte en el gasto de grupo con el reparto y el saldo que cuadran,
//  también con el monto real de un pago estimado.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Las preguntas

@Suite("Asistente de pago · lo compartido y «¿Algo más?»")
struct AsistentePagoCompartidoLogicTests {

    typealias Logica = AsistentePagoPlanificadoLogica

    private static let calendar = Calendar(identifier: .gregorian)
    private static let hoy = calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 12)) ?? .now

    @Test("sin grupos no se pregunta; con grupos, «¿Es compartido?»; con uno elegido, también «¿Cómo lo dividen?»")
    func pasos() {
        #expect(Logica.pasos(tieneGrupos: false, conGrupo: false)
                == [.tipo, .nombre, .monto, .frecuencia, .dia, .aviso, .algoMas, .resumen])
        #expect(Logica.pasos(tieneGrupos: true, conGrupo: false)
                == [.tipo, .nombre, .monto, .compartido, .frecuencia, .dia, .aviso, .algoMas, .resumen])
        #expect(Logica.pasos(tieneGrupos: true, conGrupo: true)
                == [.tipo, .nombre, .monto, .compartido, .reparto, .frecuencia, .dia, .aviso, .algoMas, .resumen])
        // Sin grupos, un grupo elegido de antes no hace aparecer la división.
        #expect(!Logica.pasos(tieneGrupos: false, conGrupo: true).contains(.reparto))
    }

    private func respuestas(conGrupo: Bool = false, repartoListo: Bool = false, fin: Date? = nil) -> Logica.Respuestas {
        Logica.Respuestas(tieneTipo: true, nombre: "Luz", monto: 120, frecuencia: .monthly, diaDelMes: 18,
                          fecha: Self.hoy, conGrupo: conGrupo, repartoListo: repartoListo, fin: fin)
    }

    @Test("«¿Es compartido?» siempre deja seguir; la división, solo si cuadra")
    func seguir() {
        #expect(Logica.puedeSeguir(en: .compartido, respuestas(), hoy: Self.hoy, calendar: Self.calendar))
        #expect(!Logica.puedeSeguir(en: .reparto, respuestas(conGrupo: true), hoy: Self.hoy, calendar: Self.calendar))
        #expect(Logica.puedeSeguir(en: .reparto, respuestas(conGrupo: true, repartoListo: true),
                                   hoy: Self.hoy, calendar: Self.calendar))
    }

    @Test("«¿Algo más?» sigue con todo por defecto; una fecha de fin pasada no")
    func algoMas() {
        #expect(Logica.puedeSeguir(en: .algoMas, respuestas(), hoy: Self.hoy, calendar: Self.calendar))
        let ayer = Self.calendar.date(byAdding: .day, value: -1, to: Self.hoy)
        #expect(!Logica.puedeSeguir(en: .algoMas, respuestas(fin: ayer), hoy: Self.hoy, calendar: Self.calendar))
        let enUnAno = Self.calendar.date(byAdding: .year, value: 1, to: Self.hoy)
        #expect(Logica.puedeSeguir(en: .algoMas, respuestas(fin: enUnAno), hoy: Self.hoy, calendar: Self.calendar))
    }

    @Test("el resumen no crea con un grupo sin división")
    func resumen() {
        #expect(!Logica.puedeSeguir(en: .resumen, respuestas(conGrupo: true), hoy: Self.hoy, calendar: Self.calendar))
        #expect(Logica.puedeSeguir(en: .resumen, respuestas(conGrupo: true, repartoListo: true),
                                   hoy: Self.hoy, calendar: Self.calendar))
        #expect(Logica.puedeSeguir(en: .resumen, respuestas(), hoy: Self.hoy, calendar: Self.calendar))
    }

    @Test("lo compartido que se guarda: el total, la moneda y la división; nada sin grupo o sin división")
    func compartido() throws {
        let yo = UUID(), pia = UUID()
        var reparto = AsistentePagoPlanificadoReparto(grupoZona: "zona", moneda: "PEN", tipo: .exact,
                                                      participantes: [yo, pia], valores: [yo: 40, pia: 80],
                                                      miParte: 40, listo: true)
        let guardado = try #require(Logica.compartido(reparto, monto: 120))
        #expect(guardado == ScheduledPaymentGroupPrefill(groupZoneID: "zona", currencyCode: "PEN", totalAmount: 120,
                                                         splitType: .exact, participantIDs: [yo, pia],
                                                         values: [yo: 40, pia: 80]))
        #expect(Logica.compartido(reparto, monto: nil) == nil)
        reparto.listo = false
        #expect(Logica.compartido(reparto, monto: 120) == nil)
        #expect(Logica.compartido(AsistentePagoPlanificadoReparto(), monto: 120) == nil)
    }

    @Test("«Usar formulario» lleva lo compartido y «¿Algo más?»")
    func alFormulario() {
        var draft = FirstScheduledPaymentDraft()
        draft.name = "Luz"
        let grupo = ScheduledPaymentGroupPrefill(groupZoneID: "zona", currencyCode: "PEN", totalAmount: 120,
                                                 splitType: .equal, participantIDs: [UUID()], values: [:])
        var extras = ScheduledPaymentWizardExtras()
        extras.note = "Depa"
        extras.isActive = false
        let prefill = Logica.alFormulario(draft, monto: 120, respondidos: [.tipo], compartido: grupo, extras: extras)
        #expect(prefill.group == grupo)
        #expect(prefill.extras == extras)
    }
}

// MARK: - Lo que crea y lo que la Bandeja hace con ello

@Suite("Pago compartido · se crea, se registra con el monto real y el saldo cuadra", .serialized)
@MainActor
struct AsistentePagoCompartidoCreacionTests {

    private struct Escena {
        let context: ModelContext
        let group: SplitGroup
        let me: SplitMember
        let pia: SplitMember
        let account: Account
        let subcategory: Subcategory
    }

    private func montar() throws -> Escena {
        let context = try makeTestContext()
        iCloudSyncService.shared._testReset()
        let group = SplitGroup(name: "Jurpi", currencyCode: "PEN")
        group.defaultSplitType = "equal"
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        let pia = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Pía")
        context.insert(me); context.insert(pia)
        let account = makeTestAccount(context: context, name: "BCP", currencyCode: "PEN")
        let category = makeTestCategory(context: context, name: "Hogar")
        let subcategory = makeTestSubcategory(context: context, name: "Luz y agua", category: category)
        try context.save()
        return Escena(context: context, group: group, me: me, pia: pia, account: account, subcategory: subcategory)
    }

    private func borrador(_ e: Escena, variable: Bool = false) -> FirstScheduledPaymentDraft {
        var draft = FirstScheduledPaymentDraft()
        draft.subcategoryID = e.subcategory.persistentModelID
        draft.name = "Luz QA"
        draft.isVariableAmount = variable
        draft.frequency = .monthly
        draft.dayOfMonth = 15
        draft.reminder = FirstScheduledPaymentFlowLogic.Reminder.none
        return draft
    }

    @Test("compartido: guarda tu parte, el total, el grupo, la división y la moneda del gasto; sin etiquetas")
    func creaCompartido() throws {
        let e = try montar()
        let grupo = ScheduledPaymentGroupPrefill(
            groupZoneID: e.group.cloudKitZoneID, currencyCode: "PEN", totalAmount: 120, splitType: .exact,
            participantIDs: [e.me.id, e.pia.id], values: [e.me.id: 40, e.pia.id: 80])
        var extras = ScheduledPaymentWizardExtras()
        extras.note = "Depa de Lince"
        let tag = Tag(name: "Casa")
        e.context.insert(tag)
        extras.tagIDs = [tag.persistentModelID]
        let pago = try AsistentePagoPlanificadoCreador.crear(
            borrador(e), monto: 120, compartido: grupo, miParte: 40, extras: extras, defaultCurrencyCode: "USD",
            in: e.context)
        #expect(pago.isGroupPayment)
        #expect(pago.groupZoneID == e.group.cloudKitZoneID)
        #expect(pago.amount == 40)
        #expect(pago.splitTotalAmount == 120)
        #expect(pago.currencyCode == "PEN")
        #expect(pago.splitType == "exact")
        #expect(Set(pago.resolvedParticipantIDs()) == [e.me.id, e.pia.id])
        #expect(pago.resolvedSplitValues() == [e.me.id: 40, e.pia.id: 80])
        #expect(pago.note == "Depa de Lince")
        #expect((pago.resolvedTagIDs(scheduleBackfill: false) ?? []).isEmpty, "Un pago compartido no lleva etiquetas.")
    }

    @Test("personal con «¿Algo más?»: cuenta elegida, descripción, fecha de fin y pausado")
    func creaPersonalConExtras() throws {
        let e = try montar()
        let otra = makeTestAccount(context: e.context, name: "Interbank", currencyCode: "USD")
        var extras = ScheduledPaymentWizardExtras()
        extras.accountID = otra.persistentModelID
        extras.note = "Luz del depa"
        let fin = Calendar.current.date(byAdding: .year, value: 1, to: Calendar.current.startOfDay(for: .now))
        extras.endDate = fin
        extras.isActive = false
        let pago = try AsistentePagoPlanificadoCreador.crear(
            borrador(e), monto: 85, compartido: nil, miParte: 0, extras: extras, defaultCurrencyCode: "PEN",
            in: e.context)
        #expect(!pago.isGroupPayment)
        #expect(pago.amount == 85)
        #expect(pago.account?.name == "Interbank")
        #expect(pago.currencyCode == "USD")
        #expect(pago.note == "Luz del depa")
        #expect(pago.endDate == fin)
        #expect(!pago.isActive)
    }

    @Test("compartido: la cuenta de otra moneda no se usa; toma una de la moneda del gasto")
    func cuentaDeLaMoneda() throws {
        let e = try montar()
        let usd = makeTestAccount(context: e.context, name: "Dólares", currencyCode: "USD")
        let vm = ScheduledPaymentEditorViewModel()
        vm.setContext(e.context, deletionService: EntityDeletionService.shared)
        let cuenta = AsistentePagoPlanificadoCreador.cuenta(usd.persistentModelID, moneda: "PEN", viewModel: vm,
                                                            in: e.context)
        #expect(cuenta?.currencyCode == "PEN")
    }

    // MARK: - De la Bandeja al gasto de grupo

    private func conEntornoDeGrupos(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        let sesionPrivadaPrevia = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            GroupTransactionBridge.shared._testClearContext()
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
            SessionState.shared.hasPrivateSession = sesionPrivadaPrevia
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
            iCloudSyncService.shared._testReset()
        }
        try body()
    }

    @Test("estimado: la Bandeja lo registra con el monto real, el reparto lo sigue y el saldo del grupo cuadra")
    func registrarConMontoReal() throws {
        let e = try montar()
        let grupo = ScheduledPaymentGroupPrefill(
            groupZoneID: e.group.cloudKitZoneID, currencyCode: "PEN", totalAmount: 120, splitType: .equal,
            participantIDs: [e.me.id, e.pia.id], values: [:])
        let pago = try AsistentePagoPlanificadoCreador.crear(
            borrador(e, variable: true), monto: 120, compartido: grupo, miParte: 60,
            extras: ScheduledPaymentWizardExtras(), defaultCurrencyCode: "PEN", in: e.context)
        // Vencido, para que la Bandeja lo traiga ya.
        pago.nextDueDate = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
        pago.account = e.account
        try e.context.save()

        try conEntornoDeGrupos(e.context) {
            #expect(ScheduledPaymentDraftService.processDuePayments(context: e.context) == 1)
            let draft = try #require(try e.context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.statusRaw == "pending" })).first)
            #expect(draft.sourceType == .groupScheduledExpense)

            let template = GroupScheduledExpenseTemplateLogic.buildTemplate(payment: pago, draftDate: draft.effectiveDate)
            #expect(template.totalAmount == 120)
            #expect(Set(template.participantIDs) == [e.me.id, e.pia.id])

            let members = [e.me, e.pia]
            let lookup = Dictionary(members.map { ($0.id.uuidString, $0.displayName) }, uniquingKeysWith: { a, _ in a })
            let vm = GroupExpenseViewModel(group: e.group, members: members, memberNameLookup: lookup)
            vm.setContext(e.context)
            vm.isGroupsOnlyOverride = false
            vm.applyTemplate(template)
            // El recibo real de este mes: 136.40 en vez de los 120 estimados. Quién paga: tú, por defecto.
            vm.amountString = "136.40"
            #expect(vm.paidByMemberID == e.me.id.uuidString)
            #expect(vm.canSave)

            GroupTransactionBridge.shared._testClearContext()
            #expect(vm.save())
            let expenseID = try #require(vm.lastCreatedExpenseID)
            let expenseUUID = try #require(UUID(uuidString: expenseID))
            let expense = try #require(try e.context.fetch(
                FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == expenseUUID })).first)
            #expect(expense.amount == 136.40)

            let shares = try e.context.fetch(FetchDescriptor<SplitShare>(
                predicate: #Predicate { $0.expenseID == expenseUUID }))
            #expect(abs(shares.reduce(0) { $0 + $1.amount } - 136.40) < 0.005, "El reparto no suma el total.")
            #expect(shares.count == 2)

            GroupTransactionBridge.shared.setContext(e.context)
            #expect(try GroupTransactionBridge.shared.bridgeExpense(
                expense, in: e.group, accountForCurrentUser: vm.selectedAccount, shouldSave: false))
            try e.context.save()
            ScheduledPaymentDraftService.handleGroupScheduledExpenseApproved(
                draft: draft, expenseID: expenseID, context: e.context)

            // En tus registros: pagaste el total y el grupo te debe la otra mitad.
            let legs = try e.context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID == expenseID }))
            let real = legs.filter { $0.account?.isSystemAccount == false }
            let prestamo = legs.filter { $0.account?.isSystemAccount == true }
            #expect(real.map(\.amount) == [-136.40])
            let mia = shares.first { $0.memberID == e.me.id.uuidString }?.amount ?? 0
            #expect(abs((prestamo.first?.amount ?? 0) - (136.40 - mia)) < 0.005)
            #expect(abs(real.reduce(0) { $0 + $1.amount } + prestamo.reduce(0) { $0 + $1.amount } + mia) < 0.005,
                    "Lo neto en tus registros tiene que ser tu parte.")
            #expect(pago.lastPaidDate != nil, "El pago planificado no quedó como pagado.")
        }
    }
}

// MARK: - Textos

@Suite("Pago compartido · los textos nuevos existen en los 16 idiomas")
struct AsistentePagoCompartidoTextosTests {

    private static let locales = ["es", "es-419", "es-AR", "es-ES", "en", "en-GB", "pt", "pt-BR", "pt-PT", "de", "fr",
                                  "it", "nl", "pl", "ja", "zh-Hans"]

    private static func table(_ locale: String, _ name: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: repoRoot.appending(path: "Yala/Resources/\(locale).lproj/\(name).strings"))
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }

    @Test("cada texto que lee la app tiene su clave")
    func cadaTextoTieneClave() {
        typealias A = L10n.AsistentePagoPlanificado
        let leidos = [A.compartidoPregunta, A.compartidoDetalle, A.soloMio, A.soloMioPista, A.grupoPista(2, "PEN"),
                      A.repartoPregunta, A.repartoDetalle, A.repartoMoneda, A.repartoDivision, A.repartoCambiar,
                      A.algoMasPregunta, A.algoMasDetalle, A.algoMasCuenta, A.algoMasNota, A.algoMasEtiquetas,
                      A.algoMasTermina, A.algoMasUltimoPago, A.resumenCompartido, A.resumenDivision, A.resumenCuenta,
                      A.resumenNota, A.resumenEtiquetas, A.resumenTermina, A.resumenEstado, A.pausado, A.faltaGrupo,
                      A.faltaDivision]
        for texto in leidos { #expect(!texto.hasPrefix("asistentePago."), "Clave sin texto: \(texto)") }
        for texto in [ReusarRegistroText.groupGone, ReusarRegistroText.groupArchived, ReusarRegistroText.groupLeft,
                      ReusarRegistroText.footer] {
            #expect(!texto.hasPrefix("reusarRegistro."), "Clave sin texto: \(texto)")
        }
        #expect(A.grupoPista(2, "PEN").contains("2") && A.grupoPista(2, "PEN").contains("PEN"))
    }

    @Test("los 16 idiomas tienen las mismas claves que el español", arguments: locales)
    func paridad(_ locale: String) throws {
        let referencia = try Self.table("es", "AsistentePagoPlanificado")
        #expect(Set(try Self.table(locale, "AsistentePagoPlanificado").keys) == Set(referencia.keys))
        let reusar = try Self.table("es", "ReusarRegistro")
        #expect(Set(try Self.table(locale, "ReusarRegistro").keys) == Set(reusar.keys))
    }
}
