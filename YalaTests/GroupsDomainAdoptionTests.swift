//
//  GroupsDomainAdoptionTests.swift
//  YalaTests
//
//  La ADOPCIÓN del dominio Grupos tras la retirada del gate beta «1050» (2.1, chip G1).
//
//  El fichero se llamaba `GroupsBetaGateLogicTests` y cubría el código beta (`isValidCode`) y la
//  decisión de pintar la pantalla de bloqueo (`shouldShowGate`). Las dos cosas se fueron con el
//  gate; lo que queda vivo —y lo que este fichero cubre ahora— es la OTRA mitad de la SSOT: el
//  predicado que decide si el bridge escribe en un dispositivo SELLADO por «empiezo de cero», y el
//  escritor nuevo que ocupa el hueco que dejó el código.
//
//  Sin SwiftUI, sin SwiftData, sin singletons, sin `makeTestContext()` — evita flake R8 conocido.
//

import Foundation
import Testing

@testable import Yala

/// `UserDefaults` que CUENTA escrituras: leer el estado final no vale para pinnear el guard de
/// `recordEntry` —re-escribir `true` sobre `true` deja el store idéntico y el mutante no caería—.
/// Molde de `UITestSeamPersistenceIsolationTests.CountingDefaults`.
private final class CountingDefaults: UserDefaults {
    var writes: [String: Int] = [:]

    override func set(_ value: Any?, forKey defaultName: String) {
        writes[defaultName, default: 0] += 1
        super.set(value, forKey: defaultName)
    }
}

@MainActor
@Suite(.serialized)
struct GroupsDomainAdoptionTests {

    private let unlockedKey = AppPreferences.Keys.groupsBetaUnlocked
    private let sealKey = AppPreferences.Keys.groupsDomainSealedForFreshStart

    // MARK: - El escritor de la adopción (el hueco que dejó el código beta)

    /// **El test del falso negativo, y el que carga el peso del chip.** De los 4 escritores de la
    /// adopción, el que desaparece al retirar el gate es el primero (teclear «1050» = el acto de
    /// adopción). En un dispositivo SELLADO cuyo dueño NUEVO abre Grupos por el tab, sin este
    /// escritor ya nadie escribe la key ⇒ el bridge queda cerrado para él EN SILENCIO, con el
    /// síntoma «mis gastos de grupo no aparecen» — literalmente el falso negativo que
    /// `isBridgeAllowed` dice haber sido diseñado para evitar.
    @Test func enteringTheGroupsTab_recordsAdoption_soASealedDeviceReopensItsBridge() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: sealKey)

        // Antes de entrar: sellado, sin adopción y sin modo solo-grupos ⇒ el bridge NO escribe.
        #expect(GroupsDomainAdoptionLogic.isBridgeAllowed(
            sealedForFreshStart: defaults.bool(forKey: sealKey),
            isUnlocked: defaults.bool(forKey: unlockedKey),
            isGroupInviteMode: false) == false)

        GroupsDomainAdoptionMarker.recordEntry(defaults)

        #expect(defaults.bool(forKey: unlockedKey) == true)
        #expect(GroupsDomainAdoptionLogic.isBridgeAllowed(
            sealedForFreshStart: defaults.bool(forKey: sealKey),
            isUnlocked: defaults.bool(forKey: unlockedKey),
            isGroupInviteMode: false) == true)
    }

    /// El guard de `recordEntry` NO es una optimización: bajo `-uitest` el seam
    /// (`UITestEphemeralDefaults.applyGroupsBetaUnlocked`) purga la key del disco y la aplica en el
    /// dominio de REGISTRO, volátil; `bool(forKey:)` la ve ⇒ el guard corta y no se persiste nada.
    /// Un `set(true, …)` incondicional convertiría ese valor volátil en permanente y dejaría Grupos
    /// adoptado para siempre en el simulador, que es justo el bug que el seam cerró.
    ///
    /// El escenario se monta con un `set` normal y NO con `register(defaults:)` a propósito: el
    /// dominio de registro es del PROCESO, no de la instancia, no se puede deshacer y se colaría en
    /// `DataWipeServiceTests` y `HandoverGroupsDomainTests`, que afirman `object(forKey:) == nil`
    /// sobre almacenes aislados.
    @Test func recordEntry_isIdempotent_soTheUITestSeamNeverGetsPersisted() throws {
        let suite = "test.\(UUID().uuidString)"
        let counting = try #require(CountingDefaults(suiteName: suite))
        defer { counting.removePersistentDomain(forName: suite) }

        counting.set(true, forKey: unlockedKey)
        counting.writes = [:]

        GroupsDomainAdoptionMarker.recordEntry(counting)

        #expect(
            counting.writes[unlockedKey, default: 0] == 0,
            """
            `recordEntry` re-escribió «\(unlockedKey)» \
            (\(counting.writes[unlockedKey, default: 0]) veces) con la adopción ya puesta. Bajo \
            `-uitest` eso persiste el valor VOLÁTIL del seam y deja Grupos adoptado para siempre en \
            ese simulador.
            """
        )
    }

    /// No-regresión del dispositivo normal: sin sello, la adopción no cambia nada — el bridge ya
    /// estaba permitido y lo sigue estando. Entrar al tab no puede tener efectos en el 99 % del
    /// parque.
    @Test func onADeviceWithoutTheSeal_adoptionChangesNothingForTheBridge() {
        let defaults = makeIsolatedDefaults()

        #expect(GroupsDomainAdoptionLogic.isBridgeAllowed(
            sealedForFreshStart: false, isUnlocked: false, isGroupInviteMode: false) == true)

        GroupsDomainAdoptionMarker.recordEntry(defaults)

        #expect(GroupsDomainAdoptionLogic.isBridgeAllowed(
            sealedForFreshStart: false,
            isUnlocked: defaults.bool(forKey: unlockedKey),
            isGroupInviteMode: false) == true)
    }

    // MARK: - Lo que hoy no puede pasar y a partir de G1 sí

    /// **El criterio de hecho del chip, en una tabla.** Antes de G1 estas dos cosas no podían ser
    /// verdad a la vez —el mismo predicado decidía las dos— y esa es exactamente la razón de que la
    /// retirada del gate no pudiera hacerse colapsando `isDomainOpen` a `true`:
    ///
    ///  1. sin adopción y sin modo solo-grupos, **el tab se ve** (ningún predicado lo tapa);
    ///  2. con el sello puesto, **el bridge NO escribe**.
    ///
    /// La mitad (1) es estructural y va por source-scan (`theGroupsTab_mountsItsContentUnconditionally`).
    @Test func withoutAdoption_theBridgeStaysClosedOnASealedDevice() {
        #expect(GroupsDomainAdoptionLogic.isDomainOpen(
            isUnlocked: false, isGroupInviteMode: false) == false)
        #expect(GroupsDomainAdoptionLogic.isBridgeAllowed(
            sealedForFreshStart: true, isUnlocked: false, isGroupInviteMode: false) == false)
    }

    /// `isDomainOpen` conserva sus DOS términos. Colapsarlo a `true` —la tentación obvia al retirar
    /// el gate— deja `sealedForFreshStart` sin efecto observable (es su único uso) y abre de golpe
    /// los 5 guards de `GroupTransactionBridge.isDomainOpenForBridge`.
    @Test func isDomainOpen_keepsBothTerms() {
        #expect(GroupsDomainAdoptionLogic.isDomainOpen(isUnlocked: false, isGroupInviteMode: false) == false)
        #expect(GroupsDomainAdoptionLogic.isDomainOpen(isUnlocked: true, isGroupInviteMode: false) == true)
        #expect(GroupsDomainAdoptionLogic.isDomainOpen(isUnlocked: false, isGroupInviteMode: true) == true)
    }
}

/// Retirada del gate y cableado del escritor (source-scan). Ni «el tab ya no está gateado» ni «hay
/// alguien que escriba la adopción al entrar» son afirmaciones que un test de comportamiento pueda
/// hacer: la primera es la AUSENCIA de un predicado en una vista SwiftUI, la segunda es un
/// call-site. Sin estos scans, devolver el gate o quitar el `onAppear` deja la suite entera en
/// verde. Mismo patrón y misma razón que `HandoverGroupsWiringTests` y `AttestWiringTests`.
@Suite("Retirada del gate beta · cableado de producción (source-scan)")
struct GroupsBetaGateRetirementTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Barrido del árbol de producción: del gate beta no puede quedar NADA que alguien reactive.
    /// El escáner comprueba primero que está midiendo un árbol real — un glob roto daría cero
    /// apariciones y PARECERÍA una medición (familia «Executed 0 tests»).
    @Test func noTraceOfTheBetaGate_survivesInProductionCode() throws {
        let root = Self.repoRoot
        var files: [URL] = []
        for target in ["Yala", "YalaWidgets", "YalaShare"] {
            let dir = root.appendingPathComponent(target)
            guard let walker = FileManager.default.enumerator(atPath: dir.path) else { continue }
            for case let relative as String in walker where relative.hasSuffix(".swift") {
                files.append(dir.appendingPathComponent(relative))
            }
        }
        #expect(files.count >= 500, "El escáner solo encontró \(files.count) ficheros — no está midiendo el árbol real.")

        // `GroupsBetaGateLogic` NO entra en la lista: el docblock de `GroupsDomainAdoptionLogic`
        // nombra a propósito el tipo del que viene, para que quien busque el gate llegue ahí.
        let prohibidos = [
            "GroupsBetaGateView",       // la pantalla de bloqueo
            "betaCodeEntry",            // el modifier reusable de ingreso del código
            "shouldShowGate",           // el predicado de visibilidad
            "isValidCode",              // la validación del «1050»
            "groups.beta.gate",         // las 6 keys de l10n
            "L10n.Groups.Beta",         // su accessor
        ]
        for file in files {
            // Sin `try?`: un fichero que no se pueda leer tiene que poner el test en ROJO, no
            // saltarse en silencio — un escáner que se salta ficheros da verde sin haber medido.
            let src = try String(contentsOf: file, encoding: .utf8)
            for simbolo in prohibidos where src.contains(simbolo) {
                Issue.record("«\(simbolo)» sigue vivo en \(file.lastPathComponent): el gate beta se retiró en 2.1.")
            }
        }
    }

    /// Las 6 keys de l10n se fueron de los 16 locales. Un locale que se las quedara pondría rojo
    /// `LocalizationParityTests.noOrphanKeys_inAnyBaseLocale`, pero solo si el locale de referencia
    /// (`es`) ya no las tiene: este scan las persigue en TODOS.
    @Test func theSixL10nKeys_areGoneFromEveryLocale() throws {
        let resources = Self.repoRoot.appendingPathComponent("Yala/Resources")
        let lprojs = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") }
        #expect(lprojs.count == 16, "Se esperaban 16 locales y hay \(lprojs.count) — el escáner cambió de árbol.")

        for lproj in lprojs {
            let file = resources.appendingPathComponent("\(lproj)/Localizable.strings")
            let src = try String(contentsOf: file, encoding: .utf8)
            #expect(!src.contains("groups.beta.gate"), "«\(lproj)» conserva keys `groups.beta.gate.*`.")
        }
    }

    /// El cuerpo del `case .groups:` de `ContentView.viewForTab`, acotado por el miembro que sigue
    /// al `switch`. Acotar es load-bearing en los dos escáneres que lo usan: sobre el fichero
    /// entero, un `if` cualquiera o una llamada al marker en otro sitio los satisfarían igual.
    private static func groupsCaseBody() throws -> String {
        let src = try source("Yala/App/ContentView.swift")
        let start = try #require(
            src.range(of: "        case .groups:"),
            "`viewForTab` dejó de tener un `case .groups` — este test dejó de comprobar nada.")
        let end = try #require(
            src.range(of: "private var wipingDataView", range: start.upperBound..<src.endIndex),
            "El ancla de cierre del corte desapareció — el escáner mide otra cosa.")
        return String(src[start.upperBound..<end.lowerBound])
    }

    /// El tab monta su contenido SIN condición. Es la mitad (1) del criterio de hecho: el gate era
    /// el único predicado entre `viewForTab(.groups)` y `GroupsContainerView`, y su vuelta —bajo
    /// cualquier nombre— se ve aquí.
    @Test func theGroupsTab_mountsItsContentUnconditionally() throws {
        let body = try Self.groupsCaseBody()
        let contenedor = try #require(
            body.range(of: "GroupsContainerView()"), "El corte no llegó al contenido del tab.")

        // Sin las líneas de comentario: el porqué de la retirada se explica AHÍ, y contar prosa
        // haría que documentar el invariante lo rompiera.
        let cabecera = body[..<contenedor.lowerBound]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(
            !cabecera.contains("if "),
            "Hay un `if` entre `case .groups` y `GroupsContainerView()`: el tab volvió a estar gateado.")
    }

    /// El escritor de la adopción está CABLEADO a la entrada del tab. Quitar este `onAppear` no
    /// rompe ninguna aserción de comportamiento —el marker sigue siendo correcto— y devuelve el
    /// falso negativo entero: bridge cerrado en silencio en el dispositivo sellado.
    @Test func enteringTheTab_isWiredToTheAdoptionMarker() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let veces = src.components(separatedBy: "GroupsDomainAdoptionMarker.recordEntry()").count - 1
        #expect(
            veces == 1,
            "Se esperaba exactamente 1 llamada a `GroupsDomainAdoptionMarker.recordEntry()` en `ContentView` y hay \(veces).")

        #expect(
            try Self.groupsCaseBody().contains("GroupsDomainAdoptionMarker.recordEntry()"),
            "El escritor de la adopción salió del `case .groups`: ya no lo dispara entrar al tab.")
    }

    /// La key conserva su STRING histórico. Renombrarla migraría al parque sin ganar nada, y el
    /// dispositivo que ya había adoptado Grupos volvería a contar como no adoptado — con el sello
    /// puesto, eso es el falso negativo otra vez.
    @Test func theAdoptionKey_keepsItsHistoricString() {
        #expect(AppPreferences.Keys.groupsBetaUnlocked == "groupsBetaUnlocked")
    }
}
