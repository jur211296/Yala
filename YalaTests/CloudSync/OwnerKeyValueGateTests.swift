//
//  OwnerKeyValueGateTests.swift
//  YalaTests / CloudSync
//
//  **El iCloud-KV del Apple ID no cruza entre el dueño y quien usa su móvil prestado** (ticket
//  `icloud-kv-prefs-cross-sessions-on-a-lent-phone`; decisión de Jürgen del 2026-09-14: cada cuenta, sus
//  preferencias).
//
//  **Una sola `@Suite` de nivel superior, con el nombre del fichero, a propósito**: `-only-testing` filtra por
//  TIPO, y `-only-testing:YalaTests/OwnerKeyValueGateTests` corre las cuatro de dentro. El cableado vive
//  aparte, en `OwnerKeyValueWiringTests.swift`, por la misma regla.
//   · la TABLA — qué sesión es la dueña, en abstracto;
//   · las MARCAS — la misma tabla leída de un teléfono, que es donde se decide qué lectura del eje entra;
//   · la FACHADA — que cerrada no deje pasar nada, salvo leer las dos señales del Apple ID;
//   · PRODUCCIÓN — que la decisión por defecto lee las marcas de `.standard`, que es donde se escriben.
//
//  Con la puerta abierta —el caso de todo test normal y de toda sesión privada— la tabla y la fachada salen
//  en verde aunque nadie las llame. Lo que protege al dueño es que no haya un segundo camino al store crudo,
//  y eso solo lo ve el escáner.
//
//  MUTACIONES verificadas el 2026-09-14, una por corrida, todas a exit 65: quitar cada una de las tres ramas
//  de `decide` · invertir su ternaria · leer la permisiva donde va la estricta · otro dominio por defecto en
//  `current` · quitar el guard de `setDouble` y el de `synchronize` · quitar la máscara de `object` · ocultar
//  las señales · añadir una tercera señal · tomar la decisión una sola vez en el `init`.
//

import Foundation
import Testing

@testable import Yala

/// Una celda: qué marcas tiene el teléfono y qué tiene que salir.
struct OwnerKeyValuePhoneCell: CustomTestStringConvertible, Sendable {
    let groupsOnlyAltaStarted: Bool
    /// `nil` = la marca del eje no se ha escrito nunca.
    let privateMark: Bool?
    let expected: OwnerKeyValueGate.Decision
    let meaning: String

    var testDescription: String { meaning }

    /// Las dos lecturas del eje, tal como las contesta `PrivateSessionMark` con esta marca.
    var hasPrivateSession: Bool { privateMark ?? true }
    var confirmedPrivateSession: Bool { privateMark ?? false }
}

/// Store espía: GUARDA lo que se escribe y cuenta escrituras, borrados y sincronizaciones. Guardar los valores
/// es lo que hace discriminante la prueba de las lecturas: un espía que contestara siempre vacío daría verde
/// con la máscara quitada.
private final class SpyStore: OwnerKeyValueWriting {
    var values: [String: Any] = [:]
    var writes: [String: Int] = [:]
    var removals: [String] = []
    var synchronizeCount = 0

    func setBool(_ value: Bool, forKey key: String) { values[key] = value; writes[key, default: 0] += 1 }
    func setString(_ value: String, forKey key: String) { values[key] = value; writes[key, default: 0] += 1 }
    func setDouble(_ value: Double, forKey key: String) { values[key] = value; writes[key, default: 0] += 1 }
    func setInt(_ value: Int, forKey key: String) { values[key] = Int64(value); writes[key, default: 0] += 1 }
    func removeObject(forKey key: String) { values[key] = nil; removals.append(key) }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { values[key] as? String }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    func longLong(forKey key: String) -> Int64 { values[key] as? Int64 ?? 0 }
    func object(forKey key: String) -> Any? { values[key] }
    @discardableResult func synchronize() -> Bool { synchronizeCount += 1; return true }
}

@Suite("iCloud-KV del Apple ID · la puerta del dueño")
struct OwnerKeyValueGateTests {

    /// Las seis celdas posibles. **Tres de ellas eligen el predicado**, y cada una tumba una alternativa:
    ///  · la 1ª (neutro armado, eje ausente) CIERRA — con la lectura permisiva del eje como único término
    ///    abría, y es el instante en que la puerta del organizador escribe el nombre de quien tiene el móvil;
    ///  · la 5ª (sin neutro, eje en `false`) CIERRA — con el neutro como término principal abría, y es la
    ///    activación de Yala completo que relanzó y se canceló, o que se quedó pendiente en Restaurar;
    ///  · la 3ª (neutro pegado, eje en `true`) ABRE — sin el término del eje, un dueño quedaba cerrado.
    static let cells: [OwnerKeyValuePhoneCell] = [
        OwnerKeyValuePhoneCell(groupsOnlyAltaStarted: true, privateMark: nil, expected: .closed,
                               meaning: "alta del organizador a medias: neutro armado, eje todavía ausente"),
        OwnerKeyValuePhoneCell(groupsOnlyAltaStarted: true, privateMark: false, expected: .closed,
                               meaning: "sesión solo-grupos asentada: el móvil prestado"),
        OwnerKeyValuePhoneCell(groupsOnlyAltaStarted: true, privateMark: true, expected: .open,
                               meaning: "marca del neutro pegada sobre un dueño afirmado"),
        OwnerKeyValuePhoneCell(groupsOnlyAltaStarted: false, privateMark: nil, expected: .open,
                               meaning: "arranque neutro tras cerrar sesión, o instalación nueva"),
        OwnerKeyValuePhoneCell(groupsOnlyAltaStarted: false, privateMark: false, expected: .closed,
                               meaning: "activación de Yala completo relanzada y cancelada, o pendiente en Restaurar"),
        OwnerKeyValuePhoneCell(groupsOnlyAltaStarted: false, privateMark: true, expected: .open,
                               meaning: "sesión privada de siempre"),
    ]

    // MARK: - La tabla

    @Suite("la tabla")
    struct Decision {
        @Test("seis celdas, en abstracto", arguments: OwnerKeyValueGateTests.cells)
        func table(_ cell: OwnerKeyValuePhoneCell) {
            let decision = OwnerKeyValueGate.decide(
                groupsOnlySessionStarted: cell.groupsOnlyAltaStarted,
                hasPrivateSession: cell.hasPrivateSession,
                confirmedPrivateSession: cell.confirmedPrivateSession)
            #expect(decision == cell.expected, "\(cell.meaning)")
        }
    }

    // MARK: - Las marcas de un teléfono

    @Suite("las marcas de un teléfono")
    struct Marks {
        @Test("seis celdas leídas de un UserDefaults de verdad", arguments: OwnerKeyValueGateTests.cells)
        func readsBothMarks(_ cell: OwnerKeyValuePhoneCell) throws {
            let name = "test.ownerKeyValueGate.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            if cell.groupsOnlyAltaStarted { StorageModePersistence.armGroupsOnlyNeutralMount(defaults) }
            if let mark = cell.privateMark { PrivateSessionMark.set(mark, defaults) }

            #expect(OwnerKeyValueGate.current(defaults) == cell.expected, "\(cell.meaning)")
        }
    }

    // MARK: - La fachada

    @MainActor
    @Suite("la fachada", .serialized)
    struct Facade {

        /// Contar ESCRITURAS y no leer el estado final es lo que carga el peso: re-escribir el mismo valor deja
        /// el store idéntico y un mutante sin guard no caería.
        @Test("cerrada, ninguna escritura, borrado ni sincronización llega al store del dueño")
        func closedWritesNothing() {
            let spy = SpyStore()
            let sut = OwnerKeyValueStore(backing: spy, decision: { .closed })

            sut.setString("de", forKey: "appLanguageOverride")
            sut.setBool(true, forKey: "yala.groups.associated")
            sut.setDouble(123, forKey: "lastOnboardingTimestamp")
            sut.setInt(3, forKey: "decimalPlaces")
            sut.removeObject(forKey: "userName")
            let synced = sut.synchronize()

            #expect(spy.writes.isEmpty, """
                Una escritura de la sesión solo-grupos llegó al iCloud-KV del DUEÑO: \(spy.writes). Ese store es \
                el del Apple ID del teléfono y viaja a todos sus dispositivos.
                """)
            #expect(spy.removals.isEmpty, "un `removeObject` con la puerta cerrada borra la preferencia del dueño")
            #expect(spy.synchronizeCount == 0, "un `synchronize()` cerrado empuja a iCloud lo que otro dejara")
            #expect(synced == false)
        }

        @Test("cerrada, las lecturas contestan como una clave que nunca se escribió")
        func closedReadsAreEmpty() {
            let spy = SpyStore()
            spy.values = [
                "userName": "Dueño",
                "expensesOnlyMode": true,
                "yala.groups.detachedAt": 1_700_000_000.0,
                "decimalPlaces": Int64(3),
            ]
            let sut = OwnerKeyValueStore(backing: spy, decision: { .closed })

            #expect(sut.object(forKey: "userName") == nil, """
                la presencia es lo que `PreferenceSyncService.readRemoteIKV` mira para decidir si aplica: una \
                clave del dueño visible aquí se le copia a quien usa el móvil prestado
                """)
            #expect(sut.string(forKey: "userName") == nil)
            #expect(sut.bool(forKey: "expensesOnlyMode") == false)
            #expect(sut.double(forKey: "yala.groups.detachedAt") == 0)
            #expect(sut.longLong(forKey: "decimalPlaces") == 0)
        }

        /// **La excepción, y por qué no es un agujero.** Las dos señales son del canal, no del dueño: todo
        /// dispositivo del Apple ID tiene que verlas para darlas por procesadas, y obedecerlas lo decide el eje
        /// aguas arriba. Ocultas, un vaciado de otro dispositivo se quedaba pendiente mientras la puerta estaba
        /// cerrada, y la sesión privada que nace de «Activar Yala completo» lo obedecía al abrirse.
        @Test("cerrada, las dos señales del Apple ID se siguen leyendo, y siguen sin escribirse")
        func closedStillReadsTheAppleIDSignals() {
            let spy = SpyStore()
            spy.values = ["lastWipeTimestamp": 1_700_000_000.0, "lastOnboardingTimestamp": 1_700_000_500.0]
            let sut = OwnerKeyValueStore(backing: spy, decision: { .closed })

            #expect(sut.double(forKey: "lastWipeTimestamp") == 1_700_000_000.0, """
                el vaciado de otro dispositivo tiene que VERSE para darse por procesado: oculto, se queda \
                pendiente y lo obedece la sesión privada que nazca cuando la puerta se abra
                """)
            #expect(sut.double(forKey: "lastOnboardingTimestamp") == 1_700_000_500.0)
            #expect(sut.object(forKey: "lastWipeTimestamp") as? Double == 1_700_000_000.0)

            sut.setDouble(1, forKey: "lastWipeTimestamp")
            #expect(spy.writes.isEmpty, "leer una señal con la puerta cerrada no abre su escritura")
        }

        /// El control de las de arriba: con la puerta abierta, la fachada es transparente. Es lo que ve toda
        /// sesión privada, y lo que tiene que seguir viendo.
        @Test("abierta, todo pasa")
        func openPassesEverythingThrough() {
            let spy = SpyStore()
            let sut = OwnerKeyValueStore(backing: spy, decision: { .open })

            sut.setString("es", forKey: "appLanguageOverride")
            sut.setBool(true, forKey: "expensesOnlyMode")
            sut.setDouble(123, forKey: "yala.groups.detachedAt")
            sut.setInt(3, forKey: "decimalPlaces")
            #expect(spy.writes.count == 4)

            #expect(sut.object(forKey: "appLanguageOverride") as? String == "es")
            #expect(sut.string(forKey: "appLanguageOverride") == "es")
            #expect(sut.bool(forKey: "expensesOnlyMode"))
            #expect(sut.double(forKey: "yala.groups.detachedAt") == 123)
            #expect(sut.longLong(forKey: "decimalPlaces") == 3)

            sut.removeObject(forKey: "appLanguageOverride")
            #expect(spy.removals == ["appLanguageOverride"])
            #expect(sut.synchronize())
            #expect(spy.synchronizeCount == 1)
        }

        /// Las marcas de un teléfono de verdad, en el orden en que ocurren. Un `init` que tomara la decisión una
        /// sola vez pasaría las de arriba y fallaría aquí.
        @Test("la puerta se resuelve en CADA llamada, con el proceso vivo")
        func decisionIsResolvedPerCall() throws {
            let name = "test.ownerKeyValueGate.live.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            let spy = SpyStore()
            let sut = OwnerKeyValueStore(backing: spy, decision: { OwnerKeyValueGate.current(defaults) })
            let key = "appLanguageOverride"

            sut.setString("es", forKey: key)
            #expect(spy.writes[key] == 1, "control: sin marcas, la escritura llega")

            // Un alta solo-grupos: arma el neutro y apaga el eje.
            StorageModePersistence.armGroupsOnlyNeutralMount(defaults)
            PrivateSessionMark.set(false, defaults)
            sut.setString("de", forKey: key)
            #expect(spy.writes[key] == 1, "en solo-grupos la escritura ya no llega")
            #expect(sut.string(forKey: key) == nil, "y lo que había deja de leerse")

            // «Activar Yala completo» relanza: el neutro se levanta, pero el eje sigue en `false`.
            StorageModePersistence.clearGroupsOnlyNeutralMount(defaults)
            sut.setString("fr", forKey: key)
            #expect(spy.writes[key] == 1, "a mitad de la activación la sesión sigue sin ser la dueña")

            // La activación termina: el eje se enciende.
            PrivateSessionMark.set(true, defaults)
            sut.setString("pt-BR", forKey: key)
            #expect(spy.writes[key] == 2, "con la sesión privada afirmada vuelve a llegar")
        }
    }

    // MARK: - Producción

    /// **Producción lee `.standard`.** Todas las celdas de arriba inyectan `defaults`, así que un `current()` cuyo
    /// dominio por defecto fuera otro dejaba `shared` abierta para siempre con la suite entera en verde. Las dos
    /// claves se escriben directas, no con sus escritores: `armGroupsOnlyNeutralMount` retira además la
    /// reanudación de la activación, que es estado del simulador que el trait no restaura.
    @MainActor
    @Suite("producción lee las marcas de .standard", .serialized, .ownerKeyValueGateOpen)
    struct Production {
        @Test("con el neutro armado en .standard la decisión por defecto cierra, y con el eje afirmado abre")
        func defaultReadsTheStandardDomain() {
            #expect(OwnerKeyValueGate.current() == .open, "control: el trait entra con las dos marcas limpias")

            UserDefaults.standard.set(true, forKey: StorageModePersistence.groupsOnlyNeutralMountKey)
            #expect(OwnerKeyValueGate.current() == .closed)

            UserDefaults.standard.set(true, forKey: PrivateSessionMark.userDefaultsKey)
            #expect(OwnerKeyValueGate.current() == .open)
        }
    }
}
