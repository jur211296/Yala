//
//  OwnerKeyValueWiringTests.swift
//  YalaTests / CloudSync
//
//  **Nadie rodea la puerta del iCloud-KV del Apple ID** (source-scan). La tabla y la fachada viven en
//  `OwnerKeyValueGateTests.swift`; esto es la mitad que ellas no ven. Con la puerta abierta —el caso de todo
//  test— una fachada perfecta sale en verde aunque haya un segundo camino al store crudo, o aunque producción
//  no le pregunte a nadie.
//
//  Una sola `@Suite`, con el nombre del fichero, porque `-only-testing` filtra por TIPO. El nombre no es nuevo:
//  lo citan `L10n.overrideLanguage` e `ICloudRestoreSignalTests` desde la primera versión (2026-08-12), que se
//  borró con la sesión de visita el 2026-09-13 y volvió con el guard el 2026-09-14.
//
//  Los escáneres filtran las líneas de comentario: estos ficheros nombran la puerta y el store crudo para
//  explicarlos, y contar esa prosa haría que documentar el invariante lo rompiera.
//
//  MUTACIONES verificadas el 2026-09-14, una por corrida, todas a exit 65: `shared` siempre abierta · la
//  migración del Panel de vuelta al store crudo · el `guard` de presencia metido en una sola rama de
//  `readRemoteIKV` · un escritor crudo nuevo en `CloudBeacon` · una escritura cruda dentro del lector declarado
//  de `ContentView` · el observer de `AppPreferences` apuntando a la puerta · una tercera señal legible.
//

import Foundation
import Testing

@testable import Yala

@Suite("iCloud-KV del Apple ID · nadie rodea la puerta (source-scan)")
struct OwnerKeyValueWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // YalaTests/CloudSync/
        .deletingLastPathComponent()  // YalaTests/
        .deletingLastPathComponent()  // raíz

    private static let targets = ["Yala", "YalaWidgets", "YalaShare"]

    /// El fichero de la puerta: el único autorizado a nombrar el store crudo para algo más que leer lo fijado.
    private static let gateFile = "OwnerKeyValueStore.swift"

    /// Un fichero que nombra el store crudo para LEER, con lo que lee FIJADO.
    struct RawReader: Sendable {
        let path: String
        /// Cuántas veces nombra `NSUbiquitousKeyValueStore` en código.
        let mentions: Int
        /// Las sentencias exactas, normalizadas, que tienen que seguir ahí.
        let statements: [String]
        var name: String { URL(fileURLWithPath: path).lastPathComponent }
    }

    /// **No se exime el FICHERO, se fija lo que lee.** La primera versión de este escáner declaraba lectores por
    /// nombre de fichero, y la review adversarial midió que así pasaba en verde una escritura cruda nueva en el
    /// fichero más editado de la app. Los dos leen solo lo que la puerta también deja pasar —las dos señales del
    /// Apple ID— o se suscriben al emisor crudo, así que moverlos detrás de la puerta no cambiaría nada; tocarlos
    /// sí cuesta: `ContentView` casa con 29 áreas del índice de cobertura.
    static let declaredRawReaders: [RawReader] = [
        RawReader(path: "Yala/App/ContentView.swift", mentions: 2, statements: [
            "let remoteWipe = NSUbiquitousKeyValueStore.default.double(forKey: \"lastWipeTimestamp\")",
            "private func markRemoteSignalsAsProcessed() { let iKV = NSUbiquitousKeyValueStore.default "
                + "let local = UserDefaults.standard "
                + "let remoteWipe = iKV.double(forKey: \"lastWipeTimestamp\") "
                + "let remoteOnboarding = iKV.double(forKey: \"lastOnboardingTimestamp\") "
                + "if remoteWipe > 0 { local.set(remoteWipe, forKey: \"lastKnownWipeTimestamp\") } "
                + "if remoteOnboarding > 0 { local.set(remoteOnboarding, forKey: \"lastKnownOnboardingTimestamp\") } }",
        ]),
        RawReader(path: "Yala/App/Services/AppPreferences.swift", mentions: 2, statements: [
            "iKVChangeToken = NotificationCenter.default.addObserver( "
                + "forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, "
                + "object: NSUbiquitousKeyValueStore.default, queue: nil )",
        ]),
    ]

    /// Los ficheros que usan la puerta. Eran ocho con el guard de la visita; `DataWipeService` salió con el flag
    /// de onboarding que escribía, y el 2026-09-14 entró `PanelPreferencesMigration`, que leía el store crudo: con
    /// la puerta cerrada habría visto el Panel del dueño, se habría saltado la siembra y nadie aplicaría nada.
    private static let gateUsers: Set<String> = [
        "PreferenceSyncService.swift",                // las 36 keys + las señales de vaciado y onboarding
        "OnboardingResetHelper.swift",                // userName / defaultCurrencyCode al empezar de cero
        "L10n.swift",                                 // el override de idioma (7ª vía, no estaba en el ticket)
        "CloudBeacon.swift",                          // el faro del Modo Nube
        "ScheduledPaymentNotificationService.swift",  // el espejo del interruptor maestro (8ª vía)
        "GroupsAccountAssociation.swift",             // la cuenta de grupos asociada, con el correo en claro
        "AppBootstrapper.swift",                      // el bloque de `-uitest-reset` (las claves del Panel)
        "PanelPreferencesMigration.swift",            // «¿hay Panel remoto?»
    ]

    /// Las líneas de código de un fichero, sin las de comentario.
    private static func code(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El código de un fichero en una sola línea, trimmeado y sin comentarios, para fijar sentencias y cuerpos
    /// enteros sin depender de la indentación.
    private static func normalized(_ path: String) throws -> String {
        try code(repoRoot.appendingPathComponent(path))
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// `(nombre, código)` de cada `.swift` de los tres targets, y cuántos vio en cada uno.
    private static func scan() throws -> (files: [(name: String, code: String)], perTarget: [String: Int]) {
        var files: [(name: String, code: String)] = []
        var perTarget: [String: Int] = [:]
        for target in targets {
            let dir = repoRoot.appendingPathComponent(target)
            guard let walker = FileManager.default.enumerator(atPath: dir.path) else { continue }
            for case let relative as String in walker where relative.hasSuffix(".swift") {
                let url = dir.appendingPathComponent(relative)
                files.append((url.lastPathComponent, try code(url)))
                perTarget[target, default: 0] += 1
            }
        }
        return (files, perTarget)
    }

    @Test("`NSUbiquitousKeyValueStore` solo se nombra en la puerta y en los dos lectores declarados")
    func rawStoreIsNotReachable() throws {
        let (files, perTarget) = try Self.scan()
        for target in Self.targets {
            #expect(perTarget[target, default: 0] > 0, "el escáner no vio ningún fichero de \(target)")
        }
        let gate = try #require(files.first { $0.name == Self.gateFile }, "el escáner no encontró la puerta")
        #expect(gate.code.contains("NSUbiquitousKeyValueStore.default"), "control: el escáner ve el store donde sí está")

        let readerNames = Set(Self.declaredRawReaders.map(\.name))
        let naming = files.filter { $0.name != Self.gateFile && $0.code.contains("NSUbiquitousKeyValueStore") }
        let offenders = naming.map(\.name).filter { !readerNames.contains($0) }
        #expect(offenders.isEmpty, """
            Estos ficheros nombran el iCloud-KV crudo por fuera de la puerta: \(offenders.sorted()). Con una sesión \
            solo-grupos ese store es el del DUEÑO del teléfono: va por `OwnerKeyValueStore`, que decide si esta \
            sesión puede leerlo o escribirlo.
            """)
        #expect(Set(naming.map(\.name)) == readerNames, """
            Los lectores declarados ya no coinciden con el árbol (vistos: \(naming.map(\.name).sorted())). Uno que \
            desaparece deja la lista mintiendo; uno que aparece no se ha revisado.
            """)
    }

    /// **Lo que hace honesta la exención**: cada lector declarado nombra el store exactamente las veces medidas y
    /// con las sentencias medidas. Una escritura cruda nueva en `ContentView` —en otra función, o dentro de
    /// `markRemoteSignalsAsProcessed` por el `iKV` que ya tiene— rompe una de las dos cosas.
    @Test("los lectores declarados leen lo fijado, y nada más")
    func declaredReadersReadOnlyWhatIsPinned() throws {
        for reader in Self.declaredRawReaders {
            let file = try Self.normalized(reader.path)
            #expect(Self.count("NSUbiquitousKeyValueStore", in: file) == reader.mentions, """
                \(reader.name) nombra el iCloud-KV crudo \(Self.count("NSUbiquitousKeyValueStore", in: file)) veces y \
                se midieron \(reader.mentions). Si lo nuevo escribe, va por `OwnerKeyValueStore`.
                """)
            for statement in reader.statements {
                #expect(file.contains(statement), """
                    \(reader.name) cambió lo que lee del iCloud-KV crudo. Se esperaba: \(statement)
                    """)
            }
        }
    }

    @Test("los usuarios de la puerta son los conocidos")
    func gateUsersAreKnown() throws {
        let (files, _) = try Self.scan()
        let users = Set(files.filter { $0.name != Self.gateFile && $0.code.contains("OwnerKeyValueStore") }.map(\.name))

        #expect(users == Self.gateUsers, """
            Cambió el conjunto de ficheros que usan el iCloud-KV del Apple ID (hoy: \(users.sorted())). Cada uno \
            necesita una decisión explícita: con la puerta cerrada, lo que escribe no llega y lo que lee viene vacío.
            """)
    }

    /// Una fachada con la tabla perfecta y un `shared` que no le pregunta a nadie no protege nada.
    @Test("producción pregunta a las marcas VIVAS, en cada llamada")
    func sharedAsksTheLiveMarks() throws {
        let gate = try Self.normalized("Yala/Services/CloudSync/OwnerKeyValueStore.swift")
        #expect(gate.contains(
            "static let shared = OwnerKeyValueStore( backing: NSUbiquitousKeyValueStore.default, decision: { OwnerKeyValueGate.current() })"
        ), """
            `OwnerKeyValueStore.shared` dejó de resolver la puerta con las marcas del teléfono en cada llamada. Una \
            decisión fija, o tomada en el `init`, deja la puerta como estaba al construir el singleton.
            """)
    }

    /// **El eslabón que no está en la fachada.** La puerta enmascara contestando «no hay nada», y eso solo impide
    /// APLICAR si quien aplica corta por presencia ANTES de cualquier otra lectura, para todos los tipos. Se fija
    /// el cuerpo ENTERO: un `guard` metido dentro de una rama por tipo mantendría la sentencia y dejaría pasar un
    /// `.bool(false)` o un `.int(0)` enmascarados encima de lo que tiene quien usa el móvil prestado.
    @Test("la lectura remota de las 36 corta por PRESENCIA, y se fija su cuerpo entero")
    func remoteReadCutsByPresence() throws {
        let service = try Self.normalized("Yala/App/Services/PreferenceSyncService.swift")
        #expect(service.contains("private let iKV: OwnerKeyValueWriting = OwnerKeyValueStore.shared"))

        let start = try #require(service.range(of: "private func readRemoteIKV("))
        let end = try #require(service.range(of: "private func readLocal(", range: start.upperBound..<service.endIndex))
        let body = service[start.lowerBound..<end.lowerBound].trimmingCharacters(in: .whitespaces)
        #expect(body == Self.readRemoteIKVBody, """
            `readRemoteIKV` cambió. Con la puerta cerrada las lecturas vienen VACÍAS, no ausentes para el tipo: si el \
            corte por presencia deja de ser lo primero para todos los tipos, esos vacíos se aplican encima de las \
            preferencias locales. Cuerpo actual: \(body)
            """)
    }

    private static let readRemoteIKVBody =
        "private func readRemoteIKV(_ key: PrefSyncKey) -> PrefValue? { let k = key.rawValue "
        + "guard iKV.object(forKey: k) != nil else { return nil } switch key.kind { "
        + "case .string: return .string(iKV.string(forKey: k) ?? \"\") "
        + "case .bool: return .bool(iKV.bool(forKey: k)) "
        + "case .int: return .int(Int(iKV.longLong(forKey: k))) } }"

    /// Las señales que la puerta deja LEER cerrada son exactamente las dos del canal de vaciado, con los nombres
    /// con los que las escribe el servicio. Una tercera clave ahí le enseña algo del dueño a quien tiene el móvil
    /// prestado; un nombre que diverja deja la señal oculta y el vaciado pendiente hasta que la puerta se abra.
    @Test("las señales legibles con la puerta cerrada son las dos del servicio, y ninguna más")
    func readableSignalsAreTheServiceSignals() throws {
        #expect(OwnerKeyValueGate.signalKeysReadableWhenClosed == ["lastWipeTimestamp", "lastOnboardingTimestamp"])

        let service = try Self.normalized("Yala/App/Services/PreferenceSyncService.swift")
        #expect(service.contains("static let remoteWipe = \"lastWipeTimestamp\""))
        #expect(service.contains("static let remoteOnboarding = \"lastOnboardingTimestamp\""))
    }

    /// `addObserver(object:)` filtra por identidad del emisor: con la PUERTA ahí, el observer no dispara nunca y las
    /// preferencias de otro dispositivo dejan de aplicarse en silencio. El suscriptor de `AppPreferences` va crudo y
    /// lo fija `declaredReadersReadOnlyWhatIsPinned`.
    @Test("el emisor que sirve la puerta es el crudo, y el servicio se suscribe a él")
    func serviceObservesTheRawEmitter() throws {
        let gate = try Self.normalized("Yala/Services/CloudSync/OwnerKeyValueStore.swift")
        #expect(gate.contains("static var notificationSource: AnyObject { NSUbiquitousKeyValueStore.default }"), """
            `notificationSource` dejó de devolver el emisor crudo: los observers que lo usan no dispararían nunca.
            """)

        let service = try Self.normalized("Yala/App/Services/PreferenceSyncService.swift")
        #expect(Self.count("object: OwnerKeyValueStore.notificationSource", in: service) == 1)
        #expect(Self.count("name: OwnerKeyValueStore.didChangeExternallyNotification", in: service) == 1)
    }

    /// **El borrado del Panel en `-uitest-reset` va por la puerta, así que necesita la puerta ABIERTA.** Tras un
    /// XCUITest de un alta solo-grupos el simulador arranca con las dos marcas puestas; el bloque las purga, y solo
    /// después el borrado llega al iCloud-KV. Subirlo por encima de la purga lo apaga en silencio, y el seam de
    /// `-uitest-group-invite`, que apaga el eje, tiene que seguir detrás.
    @Test("el bloque de `-uitest-reset` abre la puerta antes de borrar las claves del Panel")
    func uitestResetOpensTheGateFirst() throws {
        let boot = try Self.normalized("Yala/App/AppBootstrapper.swift")
        let removalNeedle = "OwnerKeyValueStore.shared.removeObject(forKey: key)"
        #expect(Self.count(removalNeedle, in: boot) == 1)

        let axis = try #require(boot.range(of: "PrivateSessionMark.clear()"))
        let neutral = try #require(boot.range(of: "StorageModePersistence.clearGroupsOnlyNeutralMount()"))
        let removal = try #require(boot.range(of: removalNeedle))
        let seam = try #require(boot.range(of: "SessionState.shared.hasPrivateSession = false"))

        #expect(axis.upperBound <= removal.lowerBound && neutral.upperBound <= removal.lowerBound, """
            el borrado de las claves del Panel quedó por encima de la purga de las marcas: tras una corrida que deje \
            la puerta cerrada, no llegaría al iCloud-KV y el test de predeterminados mediría la corrida anterior
            """)
        #expect(removal.upperBound <= seam.lowerBound, """
            el seam que apaga el eje quedó por encima del borrado: la puerta ya estaría cerrada cuando borra
            """)
    }
}
