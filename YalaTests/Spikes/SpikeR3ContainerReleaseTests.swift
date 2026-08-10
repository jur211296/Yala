//
//  SpikeR3ContainerReleaseTests.swift
//  YalaTests / Spikes
//
//  SPIKE R3 · ¿muere el container al soltarlo? — EJES LOCALES (1 · 2 · 4).
//  Chip R3 de [[MODO-NUBE-CHIPS-RELAUNCH-CERO]]; spec §1.9/§1.10/§1.11.
//
//  Instrumento: `SpikeR3Harness` (el MISMO código que corre el owner en device para el eje 3), sobre un
//  store PROPIO (`YalaSpikeR3`) con archivo real y `cloudKitDatabase: .none` EXPLÍCITO. Cero contacto
//  con el store de la app.
//
//  **Un spike no deja rojos: documenta la realidad.** Las aserciones de aquí son de DOS clases y hay que
//  saber cuál se está leyendo:
//   - **de instrumento** — que la medición signifique algo (el montaje no falló, el control negativo del
//     sentinel discrimina). Un rojo aquí dice que el spike no midió, no que SwiftData cambió.
//   - **de realidad medida** — el veredicto por eje que el chip lleva al spec y a DIFERIDOS #39. Un rojo
//     aquí SÍ es una noticia: el comportamiento de la plataforma cambió y R4 hay que reabrirlo.
//
//  El log completo de cada eje se imprime (prefijo `[R3]`) — es el entregable del spike, no las
//  aserciones.
//
//  Cada eje monta 2-3 `ModelContainer` sobre ARCHIVO ⇒ suite `.serialized` (regla de `makeTestContext`)
//  y correr con `-parallel-testing-enabled NO`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct SpikeR3ContainerReleaseTests {

    // MARK: - Eje 1 + Eje 2

    @Test("R3 eje 1+2 · ¿muere el ModelContainer al soltarlo? ¿lee completo el remount?")
    func eje1y2_releaseVerificadoYRemount() async throws {
        let harness = SpikeR3Harness()
        SpikeR3Harness.deleteSpikeStoreFiles()
        await harness.axis1AndAxis2(rowCount: 25)
        print(harness.log)
        SpikeR3Harness.deleteSpikeStoreFiles()

        // Instrumento.
        #expect(!harness.log.contains("FALLÓ el montaje"), "el spike no llegó a montar el store")
        #expect(!harness.log.contains("CONTROL ROTO"),
                "con un ModelContext retenido el container murió ⇒ el sentinel no discrimina")

        // Realidad medida (3/3 corridas idénticas, 2026-08-10, sim iPhone 17 Pro / iOS 26.5).
        #expect(harness.log.contains("EJE 1 ✅"), "el container NO murió al soltar la última referencia")
        #expect(harness.log.contains("EJE 1 · CONEXIÓN CERRADA"),
                "el objeto murió pero quedaron descriptores abiertos ⇒ el release deja de ser verificable")
        #expect(harness.log.contains("EJE 2 ✅"), "el remount tras la muerte no leyó el corpus completo")
    }

    // MARK: - Eje 1c

    @Test("R3 eje 1c · ¿qué más retiene el container? (fila @Model viva)")
    func eje1c_retenedoresNoObvios() async throws {
        let harness = SpikeR3Harness()
        SpikeR3Harness.deleteSpikeStoreFiles()
        await harness.axis1cRetainedModelObject(rowCount: 25)
        print(harness.log)
        SpikeR3Harness.deleteSpikeStoreFiles()

        #expect(!harness.log.contains("FALLÓ el montaje"))
        #expect(!harness.log.contains("CONTROL ROTO"))
        // Realidad medida: **una fila `@Model` retenida MANTIENE VIVO el container** ⇒ la lista de
        // retenedores de R4 (spec §1.11, 62 propiedades de tipo `ModelContext`/`ModelContainer`) está
        // INCOMPLETA: cualquier ViewModel que guarde `[TransactionItem]` cuenta como referencia.
        #expect(harness.log.contains("EJE 1c ⚠️ con una fila @Model retenida el container SIGUE VIVO"),
                "una fila @Model dejó de retener el container ⇒ la premisa de R4 cambió, reabrir")
    }

    // MARK: - Eje 4a

    @Test("R3 eje 4a · wipe in-process con release verificado deja el store vacío y escribible")
    func eje4a_wipeConReleaseVerificado() async throws {
        let harness = SpikeR3Harness()
        SpikeR3Harness.deleteSpikeStoreFiles()
        await harness.axis4aWipeAfterVerifiedRelease(rowCount: 25)
        print(harness.log)
        SpikeR3Harness.deleteSpikeStoreFiles()

        #expect(!harness.log.contains("FALLÓ el montaje"))
        #expect(harness.log.contains("EJE 4a ✅"))
    }

    // MARK: - Eje 4b (control NEGATIVO)

    /// Reproduce el estado del §1.10 A PROPÓSITO. No afirma un veredicto: afirma que el eje LLEGÓ AL
    /// FINAL — si SwiftData decidiera trapear (familia `_assertionFailure`/SIGTRAP, que un `do/catch` de
    /// Swift no ve), el proceso moriría aquí y eso también sería el resultado, visible como exit 65.
    @Test("R3 eje 4b · control negativo — wipe y segunda conexión con el container VIVO")
    func eje4b_wipeConContainerVivo() async throws {
        let harness = SpikeR3Harness()
        SpikeR3Harness.deleteSpikeStoreFiles()
        await harness.axis4bWipeWithLiveContainer(rowCount: 25)
        print(harness.log)
        SpikeR3Harness.deleteSpikeStoreFiles()

        #expect(!harness.log.contains("FALLÓ el montaje"))
        #expect(harness.log.contains("(v) limpieza final"), "el eje no llegó al final")

        // Realidad medida, y es el VEREDICTO que R4 hereda (3/3 corridas idénticas):
        //  1. borrar los archivos bajo un container vivo NO cierra su conexión (3 descriptores siguen ahí);
        //  2. el fetch del superviviente devuelve **0 filas y NO LANZA** — SQLite grita
        //     `vnode unlinked while in use` / `6922 disk I/O error` y Core Data lo traga ⇒ «la app en cero»
        //     es indistinguible de «el store está vacío» desde la API;
        //  3. el superviviente ESCRIBE y RESUCITA el archivo que el wipe acababa de borrar.
        #expect(harness.log.contains("(ii) el superviviente LEE 0 filas"),
                "el superviviente dejó de leer vacío ⇒ el modo de fallo del §1.10 cambió de forma")
        #expect(harness.log.contains("(iii) el superviviente ESCRIBIÓ sin lanzar"),
                "el superviviente ya no escribe tras el wipe ⇒ re-medir la resurrección del archivo")
    }

    // MARK: - Gating del harness

    /// El harness es inalcanzable desde la UI sin el launch arg — el host de tests no lo lleva.
    @Test("R3 · el harness está gateado por launch arg y no se cuela en la UI")
    func gating_porLaunchArg() {
        #expect(SpikeR3Harness.launchArgument == "-spike-r3")
        #expect(SpikeR3Harness.isEnabled == false)
        #expect(SpikeR3Harness.storeURL.lastPathComponent.hasPrefix("YalaSpikeR3"),
                "el store del spike JAMÁS puede resolver al archivo real de la app")
    }
}
