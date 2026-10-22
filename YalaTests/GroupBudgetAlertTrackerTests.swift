//
//  GroupBudgetAlertTrackerTests.swift
//  YalaTests
//
//  Cubre `GroupBudgetAlertTracker` — el dedup de los avisos del presupuesto de grupo (G14).
//  `UserDefaults` aislado por test; nunca `.standard`.
//
//  El test que de verdad importa es `cambiarElTopeReabreLosAvisos`: es la única razón por la que el
//  importe del tope está DENTRO de la clave, y si alguien "simplifica" la clave a solo el grupo, este
//  test muere.
//

import Testing
import Foundation
@testable import Yala

@MainActor
struct GroupBudgetAlertTrackerTests {

    private func makeTracker() -> GroupBudgetAlertTracker {
        GroupBudgetAlertTracker(defaults: makeIsolatedDefaults(prefix: "test.groupbudgetalerts"))
    }

    @Test func empiezaSinNadaAvisado() {
        let t = makeTracker()
        #expect(t.notifiedThresholds(groupZoneID: "z1", limitAmount: 3000).isEmpty)
    }

    @Test func marcarYLeerElMismoUmbral() {
        let t = makeTracker()
        t.markNotified(groupZoneID: "z1", limitAmount: 3000, threshold: 50)
        #expect(t.notifiedThresholds(groupZoneID: "z1", limitAmount: 3000) == [50])
    }

    @Test func marcarDosVecesNoDuplica() {
        let t = makeTracker()
        t.markNotified(groupZoneID: "z1", limitAmount: 3000, threshold: 50)
        t.markNotified(groupZoneID: "z1", limitAmount: 3000, threshold: 50)
        #expect(t.notifiedThresholds(groupZoneID: "z1", limitAmount: 3000) == [50])
    }

    /// LA razón de que el tope viva dentro de la clave: subir el límite y volver a cruzar el 50 % es un
    /// aviso legítimo, no un duplicado. Con una clave que solo llevara el grupo, no llegaría nunca.
    @Test func cambiarElTopeReabreLosAvisos() {
        let t = makeTracker()
        t.markNotified(groupZoneID: "z1", limitAmount: 3000, threshold: 50)
        #expect(t.notifiedThresholds(groupZoneID: "z1", limitAmount: 6000).isEmpty)
        // Y el tope viejo conserva lo suyo: volver atrás no re-avisa lo ya avisado.
        #expect(t.notifiedThresholds(groupZoneID: "z1", limitAmount: 3000) == [50])
    }

    @Test func cadaGrupoLlevaSuCuenta() {
        let t = makeTracker()
        t.markNotified(groupZoneID: "z1", limitAmount: 3000, threshold: 75)
        #expect(t.notifiedThresholds(groupZoneID: "z2", limitAmount: 3000).isEmpty)
    }

    /// El mismo número escrito de dos formas tiene que dar la MISMA clave: si `3000` y `3000.0`
    /// partieran la clave en dos, el aviso se repetiría al azar según de dónde viniera el `Double`.
    ///
    /// La clave se construye con la MISMA escala 4 que el wire (`Canonc1Codec.decimalFixed`), y eso
    /// hace algo más que evitar el `3000.0` vs `3000`: dos importes que el canal representa igual son
    /// el mismo tope, y tienen que compartir clave en todos los teléfonos del grupo. Por eso
    /// `3000.00001` —que al sincronizar se guarda como `3000.0000`— NO estrena avisos.
    @Test func laClaveUsaLaMismaEscalaQueElWire() {
        let t = makeTracker()
        t.markNotified(groupZoneID: "z1", limitAmount: 3000, threshold: 50)
        #expect(t.notifiedThresholds(groupZoneID: "z1", limitAmount: 3000.0) == [50])
        // Indistinguible a escala 4 ⇒ mismo tope ⇒ misma clave.
        #expect(t.notifiedThresholds(groupZoneID: "z1", limitAmount: 3000.00001) == [50])
        // Distinto a escala 4 ⇒ otro tope ⇒ clave nueva y avisos reabiertos.
        #expect(t.notifiedThresholds(groupZoneID: "z1", limitAmount: 3000.0001).isEmpty)
    }

    @Test func laLimpiezaSeLlevaLoQueYaNoEstaVivo() {
        let t = makeTracker()
        t.markNotified(groupZoneID: "vivo", limitAmount: 3000, threshold: 50)
        t.markNotified(groupZoneID: "borrado", limitAmount: 500, threshold: 100)
        t.markNotified(groupZoneID: "vivo", limitAmount: 999, threshold: 90)   // tope viejo del mismo grupo

        t.cleanupOrphanedEntries(liveKeys: [t.liveKey(groupZoneID: "vivo", limitAmount: 3000)])

        #expect(t.notifiedThresholds(groupZoneID: "vivo", limitAmount: 3000) == [50])
        #expect(t.notifiedThresholds(groupZoneID: "borrado", limitAmount: 500).isEmpty)
        #expect(t.notifiedThresholds(groupZoneID: "vivo", limitAmount: 999).isEmpty)
    }

    /// Un tope no finito no puede reventar la construcción de la clave (`String(format:)` con NaN da
    /// "nan", que es una clave válida pero distinta en cada plataforma; se normaliza a 0).
    @Test func topeNoFinitoNoRompeLaClave() {
        let t = makeTracker()
        t.markNotified(groupZoneID: "z1", limitAmount: .nan, threshold: 50)
        #expect(t.notifiedThresholds(groupZoneID: "z1", limitAmount: .nan) == [50])
    }
}
