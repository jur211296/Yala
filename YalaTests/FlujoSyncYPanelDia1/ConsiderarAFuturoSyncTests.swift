//
//  ConsiderarAFuturoSyncTests.swift
//  YalaTests
//
//  «Considerar a futuro» del flujo de caja viaja entre teléfonos (decisión de Jürgen del 19-nov-2026, 14:04): es la
//  preferencia sincronizada `cashFlowFutureExcludedFixed`. Aquí se fija que un teléfono escribe lo que el otro lee por el
//  mismo camino que el canal (el texto del Modo Nube con `PrefValueCodec`, el merge de `PreferenceMergeLogic`), que
//  volver a encenderlo todo también viaja, y que lo apagado cuando se guardaba solo en este teléfono no se pierde.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · «Considerar a futuro» sincronizado entre teléfonos")
struct ConsiderarAFuturoSyncTests {

    private typealias F = FlujoFijosAFuturo
    private let key = PrefSyncKey.cashFlowFutureExcludedFixed

    /// Lo que hace el canal con el valor de un teléfono al llegar a otro: lo lleva como texto (Modo Nube) o como string
    /// (iCloud clave-valor, el mismo valor), lo decide el merge y lo escribe en el almacén local del receptor.
    private func viaja(de origen: UserDefaults, a destino: UserDefaults) {
        let enviado = origen.string(forKey: key.rawValue)
        let remoto = enviado.map { PrefValueCodec.decode(PrefValueCodec.encode(.string($0)), as: key.kind) }
        let local = destino.string(forKey: key.rawValue).map(PrefValue.string)
        let decision = PreferenceMergeLogic.decide(key: key, remote: remoto, local: local)
        if case let .set(value) = decision.write, let texto = value.stringValue {
            destino.set(texto, forKey: key.rawValue)
        }
    }

    @Test func laClave_esDeLaFamiliaVacioValido_yAvisaAlPanel() {
        #expect(key.rawValue == "cashFlowFutureExcludedFixed")
        #expect(F.defaultsKey == key.rawValue)
        #expect(key.family == .panelPresenceEmptyValid, "volver a encenderlo todo («») tiene que viajar")
        #expect(key.kind == .string)
        #expect(key.signal == .cashFlowPlan)
        #expect(PrefSyncKey.allCases.contains(key))
    }

    @Test func apagarEnUnTelefono_loApagaEnElOtro_yEncenderTambienViaja() {
        let telefonoA = makeIsolatedDefaults(prefix: "futuro.a")
        let telefonoB = makeIsolatedDefaults(prefix: "futuro.b")
        F.considerar("out|c:Vivienda", false, defaults: telefonoA)
        F.considerar("in|n|Cliente, S.A.", false, defaults: telefonoA)

        viaja(de: telefonoA, a: telefonoB)
        #expect(F.excluidos(defaults: telefonoB) == ["out|c:Vivienda", "in|n|Cliente, S.A."],
                "una clave con coma no se parte al viajar")

        F.considerar("out|c:Vivienda", true, defaults: telefonoB)
        F.considerar("in|n|Cliente, S.A.", true, defaults: telefonoB)
        #expect(telefonoB.string(forKey: key.rawValue) == "", "todo encendido se guarda como vacío, no se borra")
        viaja(de: telefonoB, a: telefonoA)
        #expect(F.excluidos(defaults: telefonoA).isEmpty, "encenderlo todo en B lo enciende en A")
    }

    @Test func loApagadoAntesDeSincronizar_seLee_yLaMigracionLoSube() {
        let telefono = makeIsolatedDefaults(prefix: "futuro.legado")
        telefono.set(["out|c:Vivienda", "out|s:Gym"], forKey: F.legacyDefaultsKey)

        #expect(F.excluidos(defaults: telefono) == ["out|c:Vivienda", "out|s:Gym"], "antes de migrar ya no se proyecta")
        #expect(F.migrarLoLocalSiHaceFalta(defaults: telefono))
        #expect(telefono.object(forKey: F.legacyDefaultsKey) == nil, "la lista vieja se retira")
        #expect(F.decodificar(telefono.string(forKey: key.rawValue)) == ["out|c:Vivienda", "out|s:Gym"])
        #expect(!F.migrarLoLocalSiHaceFalta(defaults: telefono), "una sola vez")

        let otro = makeIsolatedDefaults(prefix: "futuro.legado.otro")
        viaja(de: telefono, a: otro)
        #expect(F.excluidos(defaults: otro) == ["out|c:Vivienda", "out|s:Gym"], "lo migrado llega al otro teléfono")
    }

    @Test func laMigracion_uneLoQueYaLlegoDeOtroTelefono() {
        let telefono = makeIsolatedDefaults(prefix: "futuro.union")
        telefono.set(F.codificar(["in|n"]), forKey: key.rawValue)          // llegó del otro teléfono
        telefono.set(["out|c:Vivienda"], forKey: F.legacyDefaultsKey)       // apagado aquí antes de sincronizar

        F.migrarLoLocalSiHaceFalta(defaults: telefono)
        #expect(F.excluidos(defaults: telefono) == ["in|n", "out|c:Vivienda"])
        #expect(F.decodificar(telefono.string(forKey: key.rawValue)) == ["in|n", "out|c:Vivienda"])
    }

    @Test func olvidarTodo_viajaComoVacio_yRetiraLaListaVieja() {
        let telefono = makeIsolatedDefaults(prefix: "futuro.olvidar")
        telefono.set(["out|c:Vivienda"], forKey: F.legacyDefaultsKey)
        F.considerar("in|n", false, defaults: telefono)
        F.olvidarTodo(defaults: telefono)
        #expect(F.excluidos(defaults: telefono).isEmpty)
        #expect(telefono.string(forKey: key.rawValue) == "")
        #expect(telefono.object(forKey: F.legacyDefaultsKey) == nil)
    }

    @Test func unValorQueNoSeEntiende_esNadaApagado() {
        #expect(F.decodificar(nil).isEmpty)
        #expect(F.decodificar("").isEmpty)
        #expect(F.decodificar("no es json").isEmpty)
        #expect(F.codificar([]) == "")
        #expect(F.decodificar(F.codificar(["b", "a"])) == ["a", "b"])
    }

    // MARK: - Cableado

    private func codigo(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        return text.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// En la app, escribir pasa por el canal; al arrancar se migra una vez; y lo que llega de otro teléfono recalcula.
    @Test func elCanal_escribe_migraAlArrancar_yAvisaAlLlegar() throws {
        let almacen = try codigo("Yala/App/Logic/FlujoProyeccionInteligente/FlujoFijosAFuturo.swift")
        #expect(almacen.contains("PreferenceSyncService.shared.set(string: valor, forKey: defaultsKey)"))
        let arranque = try codigo("Yala/App/AppBootstrapper.swift")
        #expect(arranque.contains("FlujoFijosAFuturo.migrarLoLocalSiHaceFalta()"))
        let servicio = try codigo("Yala/App/Services/PreferenceSyncService.swift")
        #expect(servicio.contains("case .cashFlowPlan: SessionState.shared.incrementDataVersion()"))
        let borrado = try codigo("Yala/Utils/DataWipeService.swift")
        #expect(borrado.contains("defaults.removeObject(forKey: FlujoFijosAFuturo.defaultsKey)"))
        #expect(borrado.contains("defaults.removeObject(forKey: FlujoFijosAFuturo.legacyDefaultsKey)"))
    }
}
