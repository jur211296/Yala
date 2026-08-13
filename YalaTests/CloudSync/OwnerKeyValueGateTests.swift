//
//  OwnerKeyValueGateTests.swift
//  YalaTests / CloudSync
//
//  **M1 · la sesión secundaria no escribe en el iCloud KV del DUEÑO.**
//
//  El `NSUbiquitousKeyValueStore` es el KV del **Apple ID del DISPOSITIVO**, y la invitada no cambia
//  la cuenta de iCloud del móvil: todo lo que se escriba ahí durante su sesión aterriza en el iCloud
//  del dueño y viaja a SUS otros dispositivos. Hasta el 2026-08-12 no había una sola puerta — cada
//  escritor decidía por su cuenta si preguntaba, y la mayoría no preguntaba.
//
//  **Por qué la frontera va en el STORE y no un guard por escritor** (decisión del owner, 2026-08-12):
//  el ticket midió SEIS vías y advirtió que «la séptima entrará sin que nadie la vea». Al re-medir
//  contra el árbol, la séptima y la OCTAVA ya estaban dentro —el override de idioma
//  (`LanguageManager`) y el flip del interruptor maestro de notificaciones—, ninguna de las dos en el
//  ticket. Un guard por escritor es acordarse en N sitios; una puerta es un sitio que decide. Es la
//  misma forma que `.claude/rules/gateway-attest.md` llama la guard del HANDLER.
//
//  El escáner lleva **conteo esperado** por la razón de `AttestWiringTests`: sin él, un escáner roto o
//  un fichero renombrado pasarían en verde sin comprobar nada — la familia de «Executed 0 tests».
//
//  MUTACIONES verificadas a exit 65: (1) invertir la tabla de `decide`; (2) que un escritor vuelva a
//  `NSUbiquitousKeyValueStore.default`; (3) quitar el `guard` del wrapper.
//

import Foundation
import Testing

@testable import Yala

// MARK: - La tabla

@Suite("M1 · la puerta del iCloud KV del dueño (tabla)")
struct OwnerKeyValueGateDecisionTests {

    @Test("con sesión secundaria viva, NO se escribe")
    func secondaryBlocks() {
        #expect(OwnerKeyValueGate.decide(secondarySessionActive: true) == .blocked)
    }

    @Test("sin sesión secundaria, se escribe con normalidad")
    func ownerWrites() {
        #expect(OwnerKeyValueGate.decide(secondarySessionActive: false) == .write)
    }
}

// MARK: - El wrapper

/// Store espía: cuenta escrituras y borrados sin tocar iCloud.
private final class SpyStore: OwnerKeyValueWriting {
    var writes: [String: Int] = [:]
    var removals: [String] = []
    var synchronizeCount = 0

    func setBool(_ value: Bool, forKey key: String) { writes[key, default: 0] += 1 }
    func setString(_ value: String, forKey key: String) { writes[key, default: 0] += 1 }
    func setDouble(_ value: Double, forKey key: String) { writes[key, default: 0] += 1 }
    func setInt(_ value: Int, forKey key: String) { writes[key, default: 0] += 1 }
    func removeObject(forKey key: String) { removals.append(key) }
    func bool(forKey key: String) -> Bool { false }
    func string(forKey key: String) -> String? { nil }
    func double(forKey key: String) -> Double { 0 }
    func longLong(forKey key: String) -> Int64 { 0 }
    func object(forKey key: String) -> Any? { nil }
    @discardableResult func synchronize() -> Bool { synchronizeCount += 1; return true }
}

@MainActor
@Suite("M1 · el wrapper del iCloud KV bloquea de verdad", .serialized)
struct OwnerKeyValueStoreTests {

    /// Contar ESCRITURAS y no leer el estado final es load-bearing (molde
    /// `SecondaryOwnerDomainGuardsTests`): re-escribir el mismo valor deja el store idéntico y el
    /// mutante no caería.
    private func withStore(secondary: Bool, _ body: (SpyStore, OwnerKeyValueStore) -> Void) {
        let spy = SpyStore()
        let sut = OwnerKeyValueStore(backing: spy, secondarySessionActive: { secondary })
        body(spy, sut)
    }

    @Test("en sesión secundaria NINGUNA escritura llega al store del dueño")
    func secondarySessionWritesNothing() {
        withStore(secondary: true) { spy, sut in
            sut.setString("es", forKey: "appLanguageOverride")
            sut.setBool(true, forKey: "yala.cloud.accountLinked")
            sut.setDouble(123, forKey: "lastWipeTimestamp")
            sut.setInt(1, forKey: "algo")
            sut.removeObject(forKey: "appLanguageOverride")
            sut.synchronize()

            #expect(spy.writes.isEmpty, """
                Una escritura de la sesión de la invitada llegó al iCloud KV del DUEÑO: \(spy.writes). \
                Ese store es el del Apple ID del dispositivo y viaja a los otros móviles de él.
                """)
            #expect(spy.removals.isEmpty, "un `removeObject` en secundaria borra la pref del DUEÑO")
        }
    }

    @Test("sin sesión secundaria el store se comporta como siempre")
    func ownerSessionWritesThrough() {
        withStore(secondary: false) { spy, sut in
            sut.setString("es", forKey: "appLanguageOverride")
            sut.setBool(true, forKey: "yala.cloud.accountLinked")
            sut.setDouble(123, forKey: "lastWipeTimestamp")
            sut.setInt(1, forKey: "algo")
            #expect(spy.writes.count == 4)
            sut.removeObject(forKey: "appLanguageOverride")
            #expect(spy.removals == ["appLanguageOverride"])
        }
    }

    /// Las LECTURAS no se bloquean: leer el iKV del dueño no lo modifica, y varias decisiones de
    /// arranque las necesitan. Lo que sí está gateado aguas arriba es actuar sobre lo leído
    /// (`PreferenceSyncService.bootstrap` se salta `checkForRemoteWipeSignal` en `.localOnly`).
    @Test("las lecturas siguen pasando en secundaria")
    func readsAreNotBlocked() {
        withStore(secondary: true) { spy, sut in
            _ = sut.bool(forKey: "k")
            _ = sut.string(forKey: "k")
            _ = sut.double(forKey: "k")
            #expect(spy.writes.isEmpty)
        }
    }
}

// MARK: - El cableado (source-scan con conteo)

/// Ni «la puerta existe» ni «el wrapper bloquea» son lo que protege al dueño: lo que protege es que
/// NADIE tenga acceso al store crudo. Sin este escáner, un escritor nuevo que llame a
/// `NSUbiquitousKeyValueStore.default` deja los tests de arriba en verde y reabre el agujero entero.
@Suite("M1 · nadie escribe el iCloud KV por fuera de la puerta (source-scan)")
struct OwnerKeyValueWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func swiftFiles(in folder: String) -> [URL] {
        let dir = repoRoot.appendingPathComponent(folder)
        guard let walker = FileManager.default.enumerator(atPath: dir.path) else { return [] }
        var out: [URL] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            out.append(dir.appendingPathComponent(relative))
        }
        return out
    }

    private static func code(_ url: URL) -> String {
        ((try? String(contentsOf: url, encoding: .utf8)) ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// **El fichero de la puerta** — el único sitio del árbol autorizado a nombrar el store crudo.
    private static let gateFile = "OwnerKeyValueStore.swift"

    /// Ficheros que nombran `NSUbiquitousKeyValueStore` SOLO para leer o para observar su
    /// notificación de cambio. Cada uno está aquí con su porqué, y la lista es un CONTEO: si crece,
    /// alguien tiene que mirar si lo nuevo es una lectura de verdad.
    private static let readOnlyCallers: Set<String> = [
        // Lee `lastWipeTimestamp`/`lastOnboardingTimestamp` para clasificar al returning user.
        "ContentView.swift",
        // `hasRemotePanelPreferences`: `object(forKey:) != nil` + `synchronize()`. No escribe.
        "PanelPreferencesMigration.swift",
        // Se suscribe a `didChangeExternallyNotification` (y lee en el handler).
        "AppPreferences.swift",
    ]

    @Test("`NSUbiquitousKeyValueStore` solo se nombra en la puerta y en los lectores declarados")
    func rawStoreIsNotReachable() {
        var offenders: [String] = []
        var seenReaders: Set<String> = []
        var scanned = 0

        for folder in ["Yala", "YalaWidgets", "YalaShare"] {
            for file in Self.swiftFiles(in: folder) {
                scanned += 1
                let name = file.lastPathComponent
                guard name != Self.gateFile else { continue }
                guard Self.code(file).contains("NSUbiquitousKeyValueStore") else { continue }
                if Self.readOnlyCallers.contains(name) { seenReaders.insert(name); continue }
                offenders.append(name)
            }
        }

        #expect(scanned >= 500, "El escáner solo vio \(scanned) ficheros — no mide el árbol real.")
        #expect(offenders.isEmpty, """
            Estos ficheros nombran el iCloud KV crudo por fuera de la puerta: \(offenders.sorted()).
            En sesión secundaria ese store es el del DUEÑO. Si la escritura es legítima, va por
            `OwnerKeyValueStore`; si es una LECTURA, decláralo en `readOnlyCallers` con su porqué.
            """)
        #expect(seenReaders == Self.readOnlyCallers, """
            La lista de lectores declarados ya no coincide con el árbol (vistos: \(seenReaders.sorted())).
            Un lector que desaparece deja la lista mintiendo; uno que aparece no se ha revisado.
            """)
    }

    /// El conteo por escritor, molde `AttestWiringTests`. Son los OCHO medidos el 2026-08-12 — los
    /// seis del ticket más el override de idioma y el flip del interruptor de notificaciones, que
    /// habían entrado sin que nadie los viera.
    @Test("los escritores del iCloud KV pasan por la puerta, y son los ocho conocidos")
    func everyWriterGoesThroughTheGate() {
        var writers: Set<String> = []
        for folder in ["Yala", "YalaWidgets", "YalaShare"] {
            for file in Self.swiftFiles(in: folder) {
                let name = file.lastPathComponent
                guard name != Self.gateFile else { continue }
                if Self.code(file).contains("OwnerKeyValueStore") { writers.insert(name) }
            }
        }

        let esperados: Set<String> = [
            "PreferenceSyncService.swift",            // las 37 keys + los DOS señalizadores
            "OnboardingResetHelper.swift",            // userName / defaultCurrencyCode
            "L10n.swift",                             // override de idioma (7ª vía, no estaba en el ticket)
            "DataWipeService.swift",                  // handover del onboardingMode
            "CloudBeacon.swift",                      // el faro del Modo Nube
            "ScheduledPaymentNotificationService.swift",  // flip del maestro (8ª vía, tampoco estaba)
        ]
        #expect(writers == esperados, """
            Cambió el conjunto de ficheros que escriben el iCloud KV (hoy: \(writers.sorted())).
            Cada uno necesita una decisión explícita: en sesión secundaria ese store es el del DUEÑO.
            """)
    }
}
