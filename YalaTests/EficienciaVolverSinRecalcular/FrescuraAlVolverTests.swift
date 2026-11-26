//
//  FrescuraAlVolverTests.swift
//  YalaTests
//
//  Lote 1 de eficiencia (26-nov-2026): volver a Yala no recalcula lo que no cambió. La lógica de la vuelta
//  (`VueltaAPrimerPlano`, `FrescuraAlVolver`), la de Spotlight (`SpotlightAlVolver`) y el testigo del freno de Grupos
//  (`RecalculationDebouncer.hasUnfinishedWork`). Lo que sí cambió —un guardado, `dataVersion`, el día, trabajo que el freno
//  cortó— tiene que seguir recargando: cada caso de «no recarga» lleva su gemelo que sí.
//

import Foundation
import Testing

@testable import Yala

@Suite("Volver sin recalcular · lógica")
struct FrescuraAlVolverTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()
    /// 26-nov-2026 15:00 en Lima.
    private static let now = Date(timeIntervalSince1970: 1_795_723_200)

    private func firma(dataVersion: Int = 3, saves: Int = 10, now: Date = Self.now) -> FirmaAlVolver {
        FirmaAlVolver.tomar(dataVersion: dataVersion, storeSaves: saves, now: now, calendar: Self.calendar)
    }

    // MARK: - Decisión por visibilidad

    @Test func paginaVisible_compruebaAhora_oculta_esperaAAparecer() {
        #expect(VueltaAPrimerPlano.decidir(paginaVisible: true) == .comprobarAhora)
        #expect(VueltaAPrimerPlano.decidir(paginaVisible: false) == .esperarAAparecer)
    }

    // MARK: - Visible al volver

    @Test func nadaCambio_noRecarga() {
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma())
        let r1 = frescura.alVolverVisible(ahora: firma(), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(!r1)
    }

    @Test func unGuardadoMientrasEstabaFuera_recarga() {
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma(saves: 10))
        let r2 = frescura.alVolverVisible(ahora: firma(saves: 11), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(r2)
    }

    @Test func dataVersionQueSubio_recarga() {
        // Lo que bajó CloudKit con la app fuera se aplica al volver subiendo `dataVersion`.
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma(dataVersion: 3))
        let r3 = frescura.alVolverVisible(ahora: firma(dataVersion: 4), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(r3)
    }

    @Test func cambioDeDia_recarga_mismoDia_no() {
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma(now: Self.now))
        let mismoDia = Self.now.addingTimeInterval(3 * 3600)
        let r4 = frescura.alVolverVisible(ahora: firma(now: mismoDia), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(!r4)

        frescura.alIrse(firma(now: Self.now))
        let manana = Self.now.addingTimeInterval(12 * 3600)
        let r5 = frescura.alVolverVisible(ahora: firma(now: manana), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(r5)
    }

    @Test func trabajoQueElFrenoCorto_recargaAunqueLaFirmaNoCambie() {
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma())
        let r6 = frescura.alVolverVisible(ahora: firma(), trabajoSinTerminar: true, cambiosSinGuardar: false)
        #expect(r6)
    }

    @Test func cambiosSinGuardar_recargan() {
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma())
        let r7 = frescura.alVolverVisible(ahora: firma(), trabajoSinTerminar: false, cambiosSinGuardar: true)
        #expect(r7)
    }

    @Test func sinFirmaTomada_recarga() {
        // Volvió sin que esta pantalla viera irse a la app: el lado seguro es recargar.
        var frescura = FrescuraAlVolver()
        let r8 = frescura.alVolverVisible(ahora: firma(), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(r8)
    }

    @Test func soloCuentaLaPrimeraFaseAlIrse() {
        // `.inactive` → `.background`: la firma es la de `.inactive`; un guardado entre las dos fases cuenta como cambio.
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma(saves: 10))
        frescura.alIrse(firma(saves: 11))
        let r9 = frescura.alVolverVisible(ahora: firma(saves: 11), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(r9)
    }

    @Test func volverConsumeLaFirma_laSiguienteIdaApuntaOtra() {
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma(saves: 10))
        _ = frescura.alVolverVisible(ahora: firma(saves: 12), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(frescura.firmaAlIrse == nil)
        frescura.alIrse(firma(saves: 12))
        let r10 = frescura.alVolverVisible(ahora: firma(saves: 12), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(!r10)
    }

    // MARK: - Oculta al volver

    @Test func oculta_noDecideAlVolver_yAlAparecerComparaConLaFirmaDeAlIrse() {
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma(saves: 10))
        frescura.alVolverOculta()
        #expect(frescura.pendienteAlAparecer)

        let r11 = frescura.alAparecer(ahora: firma(saves: 10), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(r11 == false)
        #expect(!frescura.pendienteAlAparecer)
        // Consumido: la aparición siguiente hace lo de siempre.
        let r12 = frescura.alAparecer(ahora: firma(saves: 99), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(r12 == nil)
    }

    @Test func oculta_conUnGuardadoMientrasEstabaFuera_recargaAlAparecer() {
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma(saves: 10))
        frescura.alVolverOculta()
        let r13 = frescura.alAparecer(ahora: firma(saves: 11), trabajoSinTerminar: false, cambiosSinGuardar: false)
        #expect(r13 == true)
    }

    @Test func aparecerSinVueltaPendiente_noDecideNada() {
        var frescura = FrescuraAlVolver()
        frescura.alIrse(firma())
        let r14 = frescura.alAparecer(ahora: firma(saves: 50), trabajoSinTerminar: true, cambiosSinGuardar: true)
        #expect(r14 == nil)
    }

    // MARK: - Spotlight

    private func spotlight(dataVersion: Int = 1, saves: Int = 1, soloGrupos: Bool = false, soloGastos: Bool = false,
                           grupos: Bool = true) -> SpotlightFirma {
        SpotlightFirma(dataVersion: dataVersion, storeSaves: saves, isGroupsFocusedShell: soloGrupos,
                       isExpensesOnlyMode: soloGastos, includeGroupTransactions: grupos)
    }

    @Test func spotlight_sinCambios_noReconcilia() {
        #expect(!SpotlightAlVolver.debeReconciliar(ultima: spotlight(), ahora: spotlight()))
    }

    @Test func spotlight_cualquierCambio_reconcilia() {
        let base = spotlight()
        #expect(SpotlightAlVolver.debeReconciliar(ultima: nil, ahora: base))
        #expect(SpotlightAlVolver.debeReconciliar(ultima: base, ahora: spotlight(dataVersion: 2)))
        #expect(SpotlightAlVolver.debeReconciliar(ultima: base, ahora: spotlight(saves: 2)))
        #expect(SpotlightAlVolver.debeReconciliar(ultima: base, ahora: spotlight(soloGrupos: true)))
        #expect(SpotlightAlVolver.debeReconciliar(ultima: base, ahora: spotlight(soloGastos: true)))
        #expect(SpotlightAlVolver.debeReconciliar(ultima: base, ahora: spotlight(grupos: false)))
    }
}

@Suite("Volver sin recalcular · estado de Spotlight", .serialized)
@MainActor
struct SpotlightAlVolverEstadoTests {

    @Test func laReconciliacionApuntaLaFirma_yUnFalloLaOlvida() {
        SpotlightAlVolver._testReset()
        defer { SpotlightAlVolver._testReset() }
        let firma = SpotlightFirma(dataVersion: 7, storeSaves: 3, isGroupsFocusedShell: false,
                                   isExpensesOnlyMode: false, includeGroupTransactions: true)
        #expect(SpotlightAlVolver.debeReconciliar(ahora: firma))

        SpotlightAlVolver.anotarReconciliacion(firma)
        #expect(!SpotlightAlVolver.debeReconciliar(ahora: firma))

        SpotlightAlVolver.olvidar()
        #expect(SpotlightAlVolver.debeReconciliar(ahora: firma))
    }
}

@Suite("Volver sin recalcular · testigo del freno de Grupos")
@MainActor
struct RecalculationDebouncerTestigoTests {

    @Test func pedidoConElFrenoPuesto_quedaSinTerminar() {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer()
        #expect(!debouncer.hasUnfinishedWork)
        debouncer.setBackground(true)
        debouncer.schedule(reload: true) { _ in }
        #expect(debouncer.hasUnfinishedWork)
    }

    @Test func pedidoConLaAppSinActivar_quedaSinTerminar() {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer(isApplicationActive: false)
        debouncer.schedule(reload: false) { _ in }
        #expect(debouncer.hasUnfinishedWork)
    }

    @Test func cortadoAlPonerseElFreno_quedaSinTerminar_yAlCorrerSeLimpia() async {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer()
        var runs = 0
        debouncer.schedule(reload: true) { _ in runs += 1 }
        await yieldUntil { sleeper.waitingCount == 1 }
        debouncer.setBackground(true)
        sleeper.releaseAll()
        await drainMainActor()
        #expect(runs == 0)
        #expect(debouncer.hasUnfinishedWork)

        debouncer.setBackground(false)
        debouncer.schedule(reload: true) { _ in runs += 1 }
        await yieldUntil { sleeper.waitingCount == 1 }
        sleeper.releaseAll()
        await yieldUntil { runs == 1 }
        #expect(runs == 1)
        #expect(!debouncer.hasUnfinishedWork)
    }
}
