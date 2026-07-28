//
//  GroupFetchQuiescenceGateTests.swift
//  YalaTests / CloudSync
//
//  C-4 (PIEZA 1): tabla de decisión del gate de quiescencia del fetch de GRUPOS + las dos derivaciones
//  no triviales del ensamblador de la señal (OR de los tres búferes de la ventana export-only, e
//  intersección de zonas candidatas con zonas cuyo fetch falló). Pura: sin store, sin singletons, sin
//  reloj.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupFetchQuiescenceGate · C-4")
struct GroupFetchQuiescenceGateTests {

    /// Señal ASENTADA: canal vivo, auto-sync activo, sin búferes, sin ciclos en vuelo, un ciclo cerrado.
    private func settled(
        accountAvailable: Bool = true,
        engineMounted: Bool = true,
        autoSyncActive: Bool = true,
        cyclesInFlight: Int = 0,
        completedCycle: Bool = true,
        recordZoneBuffered: Int = 0,
        databaseBuffered: Int = 0,
        clearAllRequested: Bool = false,
        applyFailed: Bool = false,
        candidateZones: Set<String> = ["SplitGroup-mig"],
        failedZones: Set<String> = []
    ) -> GroupFetchQuiescenceGate.Signal {
        GroupFetchQuiescenceGate.signal(
            accountAvailable: accountAvailable,
            privateEngineMounted: engineMounted,
            autoSyncActive: autoSyncActive,
            privateCyclesInFlight: cyclesInFlight,
            privateCompletedCycle: completedCycle,
            deferredRecordZoneEventCount: recordZoneBuffered,
            deferredDatabaseEventCount: databaseBuffered,
            deferredClearAllRequested: clearAllRequested,
            applyFailedThisSession: applyFailed,
            candidateZoneNames: candidateZones,
            zonesWithFailedFetch: failedZones)
    }

    private func decide(
        _ signal: GroupFetchQuiescenceGate.Signal,
        waited: TimeInterval = 0,
        cap: TimeInterval = 120,
        canWait: Bool = true
    ) -> GroupFetchQuiescenceGate.Decision {
        GroupFetchQuiescenceGate.decide(
            signal: signal, waitedSeconds: waited, capSeconds: cap, canWait: canWait)
    }

    // MARK: - «Sin canal ⇒ PASA» (K9/B2): la cohorte de Modo Nube no puede quedar bloqueada

    @Test func sinCuentaICloud_procedeAunqueTodoLoDemasEsteFatal() {
        // Sin `ubiquityIdentityToken` NADIE puede entregar: esperar es esperar a nadie. Y hoy estos
        // devices migran perfectamente (el uploader no toca CloudKit en ningún paso).
        let s = settled(accountAvailable: false, autoSyncActive: false, cyclesInFlight: 9,
                        completedCycle: false, recordZoneBuffered: 7, applyFailed: true,
                        failedZones: ["SplitGroup-mig"])
        #expect(decide(s) == .proceed)
    }

    @Test func sinEnginePrivadoMontado_procede() {
        // Sesión secundaria / UI tests: `SplitSyncManager.initialize()` no corre → `privateEngine == nil`.
        let s = settled(engineMounted: false, autoSyncActive: false, completedCycle: false,
                        recordZoneBuffered: 3, applyFailed: true)
        #expect(decide(s) == .proceed)
    }

    // MARK: - Canal vivo pero NO asentado

    @Test func exportOnly_espera() {
        // K1: el engine EXISTE en la ventana export-only (`startEngines(autoSync: false)`) pero no puede
        // fetchear. `engineMounted` solo diría que sí.
        #expect(decide(settled(autoSyncActive: false)) == .wait)
    }

    @Test func cicloCompletadoPeroConBuffers_espera() {
        // K2: `.didFetchChanges` NO se difiere, pero el apply del batch SÍ → el ciclo «completa» con los
        // records en un búfer de memoria. Los tres búferes cuentan igual.
        #expect(decide(settled(recordZoneBuffered: 1)) == .wait)
        #expect(decide(settled(databaseBuffered: 1)) == .wait)
        #expect(decide(settled(clearAllRequested: true)) == .wait)
    }

    @Test func cicloEnVuelo_espera() {
        #expect(decide(settled(cyclesInFlight: 1)) == .wait)
    }

    @Test func sinNingunCicloCerrado_espera() {
        // «Quieto porque terminó» vs «quieto porque aún no ha empezado».
        #expect(decide(settled(completedCycle: false)) == .wait)
    }

    @Test func asentado_procede() {
        #expect(decide(settled()) == .proceed)
    }

    // MARK: - Testigo por ZONA (K3), en su forma que no deadlockea

    @Test func zonaDeCandidatoConFetchFallido_espera() {
        let s = settled(candidateZones: ["SplitGroup-mig"], failedZones: ["SplitGroup-mig"])
        #expect(decide(s) == .wait)
    }

    @Test func zonaAjenaConFetchFallido_noBloquea() {
        // El fallo de una zona que esta pasada NO va a congelar no puede bloquear la migración.
        let s = settled(candidateZones: ["SplitGroup-mig"], failedZones: ["SplitGroup-otro"])
        #expect(decide(s) == .proceed)
    }

    @Test func zonaSinCambios_noBloqueaJamas() {
        // La razón de que el testigo sea NEGATIVO: una zona sin cambios nunca produce
        // `didFetchRecordZoneChanges`, así que un testigo POSITIVO («fetcheada limpiamente») no se
        // satisfaría nunca y el gate diferiría en cada boot — la migración no correría JAMÁS.
        let s = settled(candidateZones: ["SplitGroup-a", "SplitGroup-b"], failedZones: [])
        #expect(decide(s) == .proceed)
    }

    @Test func zonaFallidaQueVuelveALimpio_dejaDeBloquear() {
        // Auto-sanado: el adaptador la retira del set al cerrar limpio (un `changeTokenExpired` no deja
        // el gate clavado). Aquí se modela como la señal siguiente.
        #expect(decide(settled(failedZones: ["SplitGroup-mig"])) == .wait)
        #expect(decide(settled(failedZones: [])) == .proceed)
    }

    // MARK: - Apply fallido (K4): no es auto-sanable

    @Test func applyFallido_difiereAunqueTodoLoDemasEsteAsentado() {
        // El token YA avanzó sobre un batch que no persistió y CloudKit no lo re-entrega: esperar no
        // arregla nada. Difiere INMEDIATAMENTE, sin agotar el tope.
        #expect(decide(settled(applyFailed: true)) == .deferToNextBoot)
        #expect(decide(settled(applyFailed: true), canWait: false) == .deferToNextBoot)
    }

    // MARK: - Tope y modo síncrono

    @Test func topeVencido_difiere() {
        #expect(decide(settled(cyclesInFlight: 1), waited: 120, cap: 120) == .deferToNextBoot)
        #expect(decide(settled(cyclesInFlight: 1), waited: 119, cap: 120) == .wait)
    }

    @Test func sinPoderEsperar_difiereEnVezDeBloquear() {
        // Re-chequeo síncrono de `migrateOne`: no hay await disponible.
        #expect(decide(settled(cyclesInFlight: 1), canWait: false) == .deferToNextBoot)
        // Pero si está asentado, procede igual (y si no hay canal, también).
        #expect(decide(settled(), canWait: false) == .proceed)
        #expect(decide(settled(accountAvailable: false, cyclesInFlight: 3), canWait: false) == .proceed)
    }

    // MARK: - Ensamblador: las dos derivaciones donde vive el riesgo del adaptador

    @Test func buffersDerivados_cualquieraDeLosTresCuenta() {
        #expect(settled().hasBufferedFetchEvents == false)
        #expect(settled(recordZoneBuffered: 1).hasBufferedFetchEvents)
        #expect(settled(databaseBuffered: 1).hasBufferedFetchEvents)
        #expect(settled(clearAllRequested: true).hasBufferedFetchEvents)
    }

    @Test func interseccionDeZonas_soloLosCandidatos() {
        #expect(settled(candidateZones: ["a"], failedZones: ["a"]).candidateZoneFetchFailed)
        #expect(settled(candidateZones: ["a"], failedZones: ["b"]).candidateZoneFetchFailed == false)
        #expect(settled(candidateZones: ["a", "b"], failedZones: ["b"]).candidateZoneFetchFailed)
        #expect(settled(candidateZones: [], failedZones: ["a"]).candidateZoneFetchFailed == false)
    }

    // MARK: - Slugs del canario (sin PII, precedencia determinista)

    @Test func motivosDelDiferimiento_slugsEstables() {
        #expect(GroupFetchQuiescenceGate.deferReason(signal: settled(accountAvailable: false)) == "noChannel")
        #expect(GroupFetchQuiescenceGate.deferReason(signal: settled(applyFailed: true)) == "applyFailed")
        #expect(GroupFetchQuiescenceGate.deferReason(signal: settled(autoSyncActive: false)) == "exportOnly")
        #expect(GroupFetchQuiescenceGate.deferReason(signal: settled(recordZoneBuffered: 2)) == "buffered")
        #expect(GroupFetchQuiescenceGate.deferReason(
            signal: settled(failedZones: ["SplitGroup-mig"])) == "zoneFetchFailed")
        #expect(GroupFetchQuiescenceGate.deferReason(signal: settled(cyclesInFlight: 1)) == "inFlight")
        #expect(GroupFetchQuiescenceGate.deferReason(signal: settled(completedCycle: false)) == "noCycle")
        #expect(GroupFetchQuiescenceGate.deferReason(signal: settled()) == "settled")
    }
}

