//
//  GroupBudgetLogicTests.swift
//  YalaTests
//
//  Cubre `GroupBudgetLogic` — el presupuesto de grupo (UN límite por grupo, G14).
//  Lógica pura sobre `@Model` directos: sin `ModelContext`, sin `makeTestContext`, sin `.serialized`
//  (molde de `GroupShareableSummaryLogicTests`).
//
//  Cada test está escrito para MORIR si se revierte la decisión que prueba. Los cinco que más pesan:
//  la frontera del saldo de apertura, el dedup, la conversión de divisas (que aquí SÍ se hace, al revés
//  que en el resumen compartible), el estado "pasado de tope" y la clave de dedup de los avisos.
//

import Testing
import Foundation
@testable import Yala

// MARK: - Helpers (molde de GroupShareableSummaryLogicTests — no hay factory compartida de Split*)

@MainActor
private func makeExpense(
    id: UUID = UUID(),
    amount: Double,
    currencyCode: String = "PEN",
    isOpeningBalance: Bool = false,
    isSettled: Bool = false
) -> SplitExpense {
    let e = SplitExpense(
        groupZoneID: "test-zone",
        amount: amount,
        currencyCode: currencyCode,
        expenseDescription: "Test",
        paidByMemberID: "m1"
    )
    e.id = id
    e.isOpeningBalance = isOpeningBalance
    e.isSettled = isSettled
    return e
}

@MainActor
private func progress(
    limit: Double?,
    currency: String = "PEN",
    _ expenses: [SplitExpense],
    rate: Decimal = 1
) -> GroupBudgetProgress? {
    GroupBudgetLogic.progress(
        limitAmount: limit,
        currencyCode: currency,
        expenses: expenses,
        converter: MockCurrencyConverter(fixedRate: rate)
    )
}

// MARK: - Cuándo hay presupuesto y cuándo no

@MainActor
struct GroupBudgetLogicExistenceTests {

    @Test func sinLimite_noHayProgreso() {
        #expect(progress(limit: nil, [makeExpense(amount: 100)]) == nil)
    }

    /// Un tope de 0 (o negativo) NO es "un presupuesto agotado": es no tener presupuesto. Si esto
    /// devolviera un progreso, la barra saldría al infinito y la alerta del 100 % dispararía sola.
    @Test func limiteNoPositivo_noEsPresupuesto() {
        #expect(progress(limit: 0, [makeExpense(amount: 100)]) == nil)
        #expect(progress(limit: -50, [makeExpense(amount: 100)]) == nil)
    }

    @Test func limiteNoFinito_noEsPresupuesto() {
        #expect(progress(limit: .nan, [makeExpense(amount: 100)]) == nil)
        #expect(progress(limit: .infinity, [makeExpense(amount: 100)]) == nil)
    }

    @Test func sinGastos_progresoEnCero() throws {
        let p = try #require(progress(limit: 3000, []))
        #expect(p.spentAmount == 0)
        #expect(p.percentage == 0)
        #expect(p.isExceeded == false)
        #expect(p.remainingAmount == 3000)
    }
}

// MARK: - Qué se suma y qué no

@MainActor
struct GroupBudgetLogicSpendingTests {

    /// Suma el importe TOTAL del gasto compartido, no la porción de nadie: es un tope del grupo.
    @Test func sumaElTotalDelGasto() throws {
        let p = try #require(progress(limit: 1000, [
            makeExpense(amount: 300), makeExpense(amount: 150), makeExpense(amount: 50),
        ]))
        #expect(p.spentAmount == 500)
        #expect(p.percentage == 50)
    }

    /// Un saldo de apertura arrastra deuda PREVIA al grupo. Contarlo haría que un viaje empezara con la
    /// barra medio llena por dinero que no se gastó en el viaje.
    @Test func saldoDeAperturaNoEsGasto() throws {
        let p = try #require(progress(limit: 1000, [
            makeExpense(amount: 400, isOpeningBalance: true),
            makeExpense(amount: 100),
        ]))
        #expect(p.spentAmount == 100)
    }

    /// Los duplicados llegan por merges del canal de sync. Sin dedup, la barra diría 90 % con el grupo
    /// a la mitad y la alerta saltaría por dinero que nadie gastó.
    @Test func duplicadosPorIdNoInflanElTotal() throws {
        let shared = UUID()
        let p = try #require(progress(limit: 1000, [
            makeExpense(id: shared, amount: 300),
            makeExpense(id: shared, amount: 300),
            makeExpense(amount: 100),
        ]))
        #expect(p.spentAmount == 400)
    }

    /// Un gasto liquidado SIGUE siendo gasto del viaje: liquidar reparte quién debe a quién, no
    /// devuelve el dinero.
    @Test func gastoLiquidadoSigueContando() throws {
        let p = try #require(progress(limit: 1000, [makeExpense(amount: 200, isSettled: true)]))
        #expect(p.spentAmount == 200)
    }

    /// Defensa en profundidad: un importe no finito persistido no puede envenenar el total (y `Decimal`
    /// con NaN es un trap fatal, no un valor raro).
    @Test func importeNoFinitoNoContamina() throws {
        let p = try #require(progress(limit: 1000, [
            makeExpense(amount: .nan), makeExpense(amount: 250),
        ]))
        #expect(p.spentAmount == 250)
    }

    /// El de arriba entra por la rama «misma moneda», que ni siquiera construye un `Decimal`. ESTE es el
    /// que pisa el camino peligroso: un importe no finito **en otra divisa** llega hasta
    /// `Decimal(amount)`, y `Decimal(Double.nan)` es un trap fatal en runtime, no un valor raro. Sin
    /// este caso, un refactor que moviera la normalización de rama dejaría el trap vivo y la suite verde.
    @Test func importeNoFinitoEnOtraDivisaTampocoContamina() throws {
        let p = try #require(progress(limit: 1000, [
            makeExpense(amount: .nan, currencyCode: "USD"),
            makeExpense(amount: .infinity, currencyCode: "USD"),
            makeExpense(amount: 250),
        ], rate: 3))
        #expect(p.spentAmount == 250)
    }
}

// MARK: - Divisas: aquí SÍ se convierte

@MainActor
struct GroupBudgetLogicCurrencyTests {

    /// La decisión que este test protege: al revés que el resumen compartible (que no suma divisas
    /// porque su número se CONGELA en una imagen), la barra convierte. No hacerlo enseñaría un progreso
    /// falsamente bajo en un viaje con gastos en varias monedas — la mentira que deja gastar de más.
    @Test func gastosEnOtraMonedaSeConvierten() throws {
        let p = try #require(progress(limit: 1000, [
            makeExpense(amount: 100, currencyCode: "PEN"),
            makeExpense(amount: 100, currencyCode: "USD"),
        ], rate: 3))
        #expect(p.spentAmount == 400)   // 100 + (100 × 3)
    }

    @Test func siHuboConversion_elTotalVaMarcadoComoEstimado() throws {
        let mixto = try #require(progress(limit: 1000, [
            makeExpense(amount: 100, currencyCode: "USD"),
        ], rate: 3))
        #expect(mixto.isEstimate)
    }

    /// Marcar de más erosiona la marca igual que no ponerla: si todo está en la moneda del grupo, no
    /// hubo conversión y no hay `≈`.
    @Test func sinConversion_noHayMarcaDeEstimado() throws {
        let p = try #require(progress(limit: 1000, [
            makeExpense(amount: 100, currencyCode: "PEN"),
            makeExpense(amount: 200, currencyCode: "PEN"),
        ], rate: 3))
        #expect(p.isEstimate == false)
        #expect(p.spentAmount == 300)
    }

    @Test func laMonedaDelProgresoEsLaDelGrupo() throws {
        let p = try #require(progress(limit: 1000, currency: "EUR", [makeExpense(amount: 10)]))
        #expect(p.currencyCode == "EUR")
    }
}

// MARK: - Pasarse del tope

@MainActor
struct GroupBudgetLogicOverspendTests {

    /// Pasarse es un estado legítimo que la barra tiene que poder enseñar: el porcentaje NO se recorta
    /// a 100 (si se recortara, "te pasaste por X" no tendría de dónde salir).
    @Test func pasarseDelTopeNoRecortaElPorcentaje() throws {
        let p = try #require(progress(limit: 1000, [makeExpense(amount: 1500)]))
        #expect(p.percentage == 150)
        #expect(p.isExceeded)
        #expect(p.exceededAmount == 500)
    }

    /// Lo que queda nunca es negativo: cuando te pasas, el número que interesa es `exceededAmount`.
    @Test func loQueQuedaNuncaEsNegativo() throws {
        let p = try #require(progress(limit: 1000, [makeExpense(amount: 1500)]))
        #expect(p.remainingAmount == 0)
    }

    /// Gastar EXACTAMENTE el tope no es pasarse.
    @Test func gastarJustoElTopeNoEsPasarse() throws {
        let p = try #require(progress(limit: 1000, [makeExpense(amount: 1000)]))
        #expect(p.percentage == 100)
        #expect(p.isExceeded == false)
        #expect(p.exceededAmount == 0)
        #expect(p.remainingAmount == 0)
    }

    /// EL borde de verdad, y el que un solo gasto de 1000 no puede probar: la suma de VARIOS importes de
    /// dos decimales que da justo el tope. `915,69 + 53,48 + 30,83` son 1.000,00 exactos en decimal y
    /// `1000.0000000000001` en coma flotante — con un `>` pelado la tarjeta diría «te pasaste por 0,00»
    /// en rojo. En un barrido de repartos de 1.000 en 3-8 importes, el 16,5 % cae en este caso.
    @Test func sumaDeVariosGastosQueDaElTopeExactoNoEsPasarse() throws {
        let p = try #require(progress(limit: 1000, [
            makeExpense(amount: 915.69), makeExpense(amount: 53.48), makeExpense(amount: 30.83),
        ]))
        #expect(p.spentAmount == 1000)
        #expect(p.isExceeded == false)
        #expect(p.exceededAmount == 0)
    }

    /// Y la otra mitad del control: un céntimo de más SÍ es pasarse. Sin esto, la tolerancia podría
    /// crecer sin que ningún test se quejara.
    @Test func unCentimoDeMasSiEsPasarse() throws {
        let p = try #require(progress(limit: 1000, [makeExpense(amount: 1000.01)]))
        #expect(p.isExceeded)
        #expect(p.exceededAmount > 0)
    }
}

// MARK: - Umbrales de aviso

@MainActor
struct GroupBudgetLogicThresholdTests {

    @Test func devuelveSoloLosUmbralesCruzadosYNoAvisados() {
        let nuevos = GroupBudgetLogic.newlyCrossedThresholds(percentage: 80, alreadyNotified: [50])
        #expect(nuevos == [75])
    }

    /// El 100 se cruza al IGUALAR, no solo al pasarse.
    @Test func elCienSeCruzaAlIgualar() {
        let nuevos = GroupBudgetLogic.newlyCrossedThresholds(percentage: 100, alreadyNotified: [])
        #expect(nuevos == [50, 75, 90, 100])
    }

    @Test func nadaNuevoSiYaSeAvisoTodo() {
        let nuevos = GroupBudgetLogic.newlyCrossedThresholds(
            percentage: 120, alreadyNotified: [50, 75, 90, 100])
        #expect(nuevos.isEmpty)
    }

    @Test func porDebajoDelPrimerUmbralNoAvisaNada() {
        #expect(GroupBudgetLogic.newlyCrossedThresholds(percentage: 49.9, alreadyNotified: []).isEmpty)
    }

    @Test func devuelveEnOrdenAscendente() {
        let nuevos = GroupBudgetLogic.newlyCrossedThresholds(percentage: 95, alreadyNotified: [])
        #expect(nuevos == [50, 75, 90])
    }

    /// Un porcentaje no finito no puede disparar los cuatro avisos de golpe.
    @Test func porcentajeNoFinitoNoDisparaAvisos() {
        #expect(GroupBudgetLogic.newlyCrossedThresholds(percentage: .nan, alreadyNotified: []).isEmpty)
    }

    @Test func losUmbralesSonLosCuatroDelPresupuestoPersonal() {
        #expect(GroupBudgetLogic.alertThresholds == [50, 75, 90, 100])
    }
}
