//
//  SharedStateIsolationTests.swift
//  YalaTests
//
//  El pin de `SharedStateIsolation`. SON DOS MITADES Y NINGUNA CUBRE A LA OTRA:
//
//   · Comportamiento — que el scope restaura de verdad, incluso cuando el cuerpo lanza. Se ejercita
//     `withSharedStateIsolated` directamente porque un `Test` no se puede construir a mano, así que
//     el `provideScope` del trait es inalcanzable desde aquí.
//   · Cableado (source-scan) — que cada suite que ensucia LLEVA su trait, y que el trait DELEGA en
//     esa función. Sin esto, quitar el trait de un `@Suite` devolvería la fuga entera con el test de
//     comportamiento en verde: exactamente el modo de fallo que este fichero existe para impedir.
//     Medido el 2026-08-05: al quitar `.appLanguageStateIsolated` de `AppLanguageSyncTests`, sus 9
//     tests siguieron pasando y solo cayó el scan.
//

import Foundation
import Testing

@testable import Yala

// Los tres scopes, porque esta suite planta valores en las celdas de los tres ANTES de abrir su
// scope interno: sin ellos el propio pin sería una fuga. Anidar el mismo scope dos veces es seguro
// (el turno global es reentrante y cada capa restaura lo que capturó).
@Suite("Aislamiento de estado compartido", .serialized,
       .appLanguageStateIsolated, .lastUsedAccountIsolated, .wipeAppGroupMirrorIsolated)
@MainActor
struct SharedStateIsolationTests {

    private static let sentinelKey = SharedStateScope.migrationSentinelKey

    /// Celdas de juguete: `UserDefaults` de verdad, en suites con UUID, para que el pin ejercite el
    /// mismo tipo que corre en producción y no un fake que podría divergir.
    private func makeFakeCells(count: Int = 3) -> [SharedStateCell] {
        (0..<count).map {
            SharedStateCell(makeIsolatedDefaults(prefix: "test.shared.\($0)"), "k\($0)", "fake\($0)")
        }
    }

    // MARK: - Comportamiento

    @Test func scope_devuelveCeldasAusentesAAusentes() async throws {
        let cells = makeFakeCells()

        try await withSharedStateIsolated(cells: cells) {
            cells[0].store.set("de", forKey: cells[0].key)
            cells[1].store.set(true, forKey: cells[1].key)
            cells[2].store.set("pt", forKey: cells[2].key)
        }

        for cell in cells {
            #expect(
                cell.store.object(forKey: cell.key) == nil,
                "«\(cell.key)» quedó escrita en \(cell.storeLabel)."
            )
        }
    }

    @Test func scope_devuelveLosValoresQueHabiaAntes() async throws {
        let cells = makeFakeCells()
        cells[0].store.set("es-419", forKey: cells[0].key)
        cells[1].store.set(true, forKey: cells[1].key)
        cells[2].store.set("legacy", forKey: cells[2].key)

        try await withSharedStateIsolated(cells: cells) {
            cells[0].store.set("de", forKey: cells[0].key)
            cells[1].store.removeObject(forKey: cells[1].key)
            cells[2].store.set("pt", forKey: cells[2].key)
        }

        #expect(cells[0].store.object(forKey: cells[0].key) as? String == "es-419")
        #expect(cells[1].store.object(forKey: cells[1].key) as? Bool == true)
        #expect(cells[2].store.object(forKey: cells[2].key) as? String == "legacy")
    }

    /// El centinela de migración es `Bool`: `false` presente y ausente son estados DISTINTOS, y
    /// restaurar `false` como "quitar la clave" re-dispararía la migración en el siguiente arranque.
    @Test func scope_distingueFalsePresenteDeAusente() async throws {
        let cells = makeFakeCells(count: 1)
        cells[0].store.set(false, forKey: cells[0].key)

        try await withSharedStateIsolated(cells: cells) {
            cells[0].store.set(true, forKey: cells[0].key)
        }

        #expect(cells[0].store.object(forKey: cells[0].key) as? Bool == false)
        #expect(cells[0].store.object(forKey: cells[0].key) != nil, "`false` no es lo mismo que ausente.")
    }

    /// La entrada se normaliza. Es lo que permite borrar los `removeObject` de los `init()` de las
    /// suites, que era de donde salía la fuga de `lastUsedAccountID`.
    @Test func scope_limpiaElEstadoAntesDeEjecutarElCuerpo() async throws {
        let cells = makeFakeCells(count: 1)
        cells[0].store.set("de", forKey: cells[0].key)

        var vistoDentro: String?
        var loViDentro = false
        try await withSharedStateIsolated(cells: cells) {
            vistoDentro = cells[0].store.object(forKey: cells[0].key) as? String
            loViDentro = true
        }

        #expect(loViDentro, "El cuerpo no llegó a ejecutarse.")
        #expect(vistoDentro == nil, "El cuerpo vio estado de una corrida anterior.")
        #expect(cells[0].store.object(forKey: cells[0].key) as? String == "de", "La limpieza se comió la restauración.")
    }

    /// El modo de fallo original: una limpieza escrita al final del cuerpo no corre cuando un
    /// `#expect` falla antes.
    @Test func scope_restauraAunqueElCuerpoLance() async throws {
        struct Boom: Error {}
        let cells = makeFakeCells(count: 1)
        cells[0].store.set("es-419", forKey: cells[0].key)

        await #expect(throws: Boom.self) {
            try await withSharedStateIsolated(cells: cells) {
                cells[0].store.set("de", forKey: cells[0].key)
                throw Boom()
            }
        }

        #expect(cells[0].store.object(forKey: cells[0].key) as? String == "es-419")
    }

    // MARK: - Comportamiento contra los almacenes REALES (los que filtran)

    /// Lo protege el trait de esta suite: el scope externo restaura lo que este test deja.
    @Test func scopeAppLanguage_restauraElAppGroupReal() async throws {
        let shared = LanguageManager.sharedDefaults
        let key = LanguageManager.overrideKey
        shared.set("es-419", forKey: key)
        shared.set(true, forKey: Self.sentinelKey)

        try await withSharedStateIsolated(.appLanguage) {
            LanguageManager.overrideLanguage = "de"
            LanguageManager.bootstrapMigrationIfNeeded()
        }

        #expect(
            shared.object(forKey: key) as? String == "es-419",
            "El App Group real quedó con el idioma del test — el siguiente XCUITest arranca en ese idioma."
        )
    }

    /// El caso de `ApplePayDraftServiceTests`: `LastUsedAccountStore` no es inyectable, así que sus
    /// tests leen y escriben el App Group real.
    @Test func scopeLastUsedAccount_restauraElAppGroupReal() async throws {
        let appGroup = try #require(UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier))
        let key = AppPreferences.Keys.lastUsedAccountID
        let cuentaDelUsuario = UUID().uuidString
        appGroup.set(cuentaDelUsuario, forKey: key)

        try await withSharedStateIsolated(.lastUsedAccount) {
            LastUsedAccountStore.write(UUID().uuidString)
        }

        #expect(
            appGroup.string(forKey: key) == cuentaDelUsuario,
            "La última cuenta usada del simulador se perdió — es la que elige cuenta en Apple Pay."
        )
    }

    /// El scope tiene que EMPEZAR limpio también contra el almacén real: es lo que sustituye al
    /// `removeObject` que hacía el `init()` de la suite de Apple Pay.
    @Test func scopeLastUsedAccount_entraSinUltimaCuenta() async throws {
        let appGroup = try #require(UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier))
        appGroup.set(UUID().uuidString, forKey: AppPreferences.Keys.lastUsedAccountID)

        var vistoDentro: String?
        try await withSharedStateIsolated(.lastUsedAccount) {
            vistoDentro = LastUsedAccountStore.read()
        }

        #expect(vistoDentro == nil, "El test habría visto la última cuenta de la corrida anterior.")
    }

    /// Las TRES claves que barre `DataWipeService.resetAllUserPreferences()` en el App Group. Se
    /// ejercita la función REAL, que es la que ejecutan los tests de wipe.
    @Test func scopeWipeMirror_restauraLasTresClaves() async throws {
        let appGroup = try #require(UserDefaults(suiteName: SharedContainerService.appGroupIdentifier))
        let previos: [(String, Any)] = [
            (AppPreferences.Keys.expensesOnlyMode, true),
            ("firstWeekday", 5),
            (AppPreferences.Keys.lastUsedAccountID, "CUENTA-DEL-USUARIO"),
        ]
        for (key, value) in previos { appGroup.set(value, forKey: key) }

        try await withSharedStateIsolated(.wipeAppGroupMirror) {
            for (key, _) in previos { appGroup.removeObject(forKey: key) }
        }

        #expect(appGroup.object(forKey: AppPreferences.Keys.expensesOnlyMode) as? Bool == true)
        #expect(appGroup.object(forKey: "firstWeekday") as? Int == 5)
        #expect(
            appGroup.string(forKey: AppPreferences.Keys.lastUsedAccountID) == "CUENTA-DEL-USUARIO",
            "Un `wipeAllUserData` de un test se llevó por delante el espejo del App Group del simulador."
        )
    }

    // MARK: - Cableado (source-scan)

    /// Los conteos esperados no son decoración: sin ellos, un fichero movido o un símbolo renombrado
    /// dejarían al escáner sin encontrar nada y la suite pasaría en verde sin comprobar nada.
    @Test func cadaSuiteQueEnsuciaLlevaSuTrait() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        // Las líneas de comentario van fuera: el porqué se explica ahí nombrando estos mismos
        // símbolos, y contar prosa haría que documentar el invariante lo rompiera.
        func code(of fileName: String) throws -> String {
            try String(contentsOf: testsDir.appending(path: fileName), encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
        }

        let cableado = [
            ("AppLanguageSyncTests.swift", ".appLanguageStateIsolated"),
            ("LocaleResolutionTests.swift", ".appLanguageStateIsolated"),
            ("ApplePayDraftServiceTests.swift", ".lastUsedAccountIsolated"),
            // Los TRES que ejecutan `wipeAllUserData` de verdad: su paso 2 barre tres claves del
            // App Group y su snapshot/restore solo cubre `.standard`. Eran dos hasta el 2026-08-05;
            // al tercero lo cazó una sonda KVO sobre las claves del espejo, no esta lista. ⇒ el
            // criterio para entrar aquí es EJECUTAR el wipe, no aparecer en la lista — y quien lo
            // hace cumplir es `todaSuiteQueEjecutaElWipeLlevaSuTrait`, de abajo.
            ("DataWipePreservesGroupsTests.swift", ".wipeAppGroupMirrorIsolated"),
            ("CloudSync/WipeMassRowsCloudDrainTests.swift", ".wipeAppGroupMirrorIsolated"),
            ("CloudSync/GroupsSignOutFlowTests.swift", ".wipeAppGroupMirrorIsolated"),
        ]
        for (file, trait) in cableado {
            let applied = try code(of: file).components(separatedBy: trait).count - 1
            #expect(
                applied == 1,
                """
                \(file) ya no declara `\(trait)` (\(applied) apariciones). Sin el trait, sus tests \
                vuelven a dejar estado en un almacén COMPARTIDO que sobrevive al proceso, y el rojo \
                aparece en la corrida siguiente y en otro target.
                """
            )
        }

        // Que el trait DELEGUE: si `provideScope` se vacía, el `@Suite` seguiría "llevando" el trait
        // y no pasaría absolutamente nada.
        let mecanismo = try code(of: "SharedStateIsolation.swift")
        let firma = try #require(
            mecanismo.range(of: "func provideScope"),
            "El escáner no encontró `provideScope` — el mecanismo se movió o se renombró."
        )
        #expect(
            mecanismo[firma.lowerBound...].contains("withSharedStateIsolated("),
            "`provideScope` ya no delega en el scope: el trait quedaría decorativo."
        )
    }

    /// El pin de arriba enumera y por eso ENVEJECE: se escribió con dos suites de wipe y para el
    /// 2026-08-05 eran tres — a la tercera la cazó una sonda KVO, no la lista, y llevaba meses
    /// barriendo el App Group real sin que nada lo dijera. Este escáner fija el CRITERIO en vez de
    /// la enumeración: quien ejecute el wipe lleva el trait, lo hayan añadido a la lista o no.
    ///
    /// **Es la mitad que carga el peso, y se midió**: un fichero NUEVO que ejecute el wipe sin
    /// trait deja la lista de arriba en VERDE —no lo enumera nadie— y solo cae aquí.
    ///
    /// El conteo mínimo no es decoración: sin él, renombrar el método dejaría al escáner sin
    /// encontrar nada y la suite pasaría en verde sin comprobar absolutamente nada.
    @Test func todaSuiteQueEjecutaElWipeLlevaSuTrait() throws {
        let selfFile = URL(fileURLWithPath: #filePath)
        let testsDir = selfFile.deletingLastPathComponent()
        let files = (FileManager.default.enumerator(at: testsDir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? [])

        var ejecutanElWipe: [String] = []
        var sinTrait: [String] = []
        for url in files {
            // Este fichero se excluye: el literal que busca el escáner está en SU PROPIO código
            // (la línea de abajo), así que sin esto se cuenta a sí mismo e infla el mínimo.
            guard url.lastPathComponent != selfFile.lastPathComponent else { continue }
            // Las líneas de comentario van fuera: varios ficheros NOMBRAN el método al explicar el
            // invariante, y contar prosa haría que documentarlo lo rompiera. `HandoverGroupsDomainTests`
            // es el caso exacto — lo menciona seis veces y no lo invoca ni una.
            let code = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            guard code.contains("wipeAllUserData(") else { continue }
            ejecutanElWipe.append(url.lastPathComponent)
            if !code.contains(".wipeAppGroupMirrorIsolated") { sinTrait.append(url.lastPathComponent) }
        }

        #expect(
            ejecutanElWipe.count >= 3,
            """
            El escáner solo encontró \(ejecutanElWipe.count) ficheros que ejecutan el wipe y \
            esperaba al menos 3. O se renombró el método, o se movieron los ficheros: en los dos \
            casos este test dejó de comprobar nada.
            """
        )
        #expect(
            sinTrait.isEmpty,
            """
            \(sinTrait.joined(separator: ", ")) ejecuta(n) el wipe sin `.wipeAppGroupMirrorIsolated`. \
            Su PASO 2 barre tres claves del App Group REAL —`expensesOnlyMode`, `firstWeekday`, \
            `lastUsedAccountID`— que sobreviven al proceso y comparten los dos hosts del scheme \
            `Yala Dev`. El snapshot/restore del `persistentDomain` que suelen llevar estas suites \
            cubre solo `UserDefaults.standard`, así que el App Group queda fuera y la pérdida \
            aparece en la corrida SIGUIENTE y en otro target.
            """
        )
    }

    /// Defensa en profundidad, y conviene ser exacto sobre qué defiende. **Medido**: el scope
    /// envuelve también la construcción de la suite, así que un `removeObject` en el `init()` corre
    /// DESPUÉS del capture y hoy sería redundante con el clear — con el trait puesto, un centinela
    /// plantado en el App Group sobrevive igual. Lo que lo hace peligroso es que esa inocuidad
    /// depende POR COMPLETO de que nadie quite el trait: con las dos cosas a la vez —que es como
    /// estaba el fichero— el centinela desaparece. Es además el patrón que se copia a la siguiente
    /// suite que alguien escriba.
    @Test func ningunInitDeSuiteBorraLaUltimaCuentaUsada() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "ApplePayDraftServiceTests.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        let borrados = source
            .components(separatedBy: "removeObject(forKey: AppPreferences.Keys.lastUsedAccountID)")
            .count - 1
        #expect(
            borrados == 0,
            """
            ApplePayDraftServiceTests vuelve a borrar `lastUsedAccountID` a mano (\(borrados) veces). \
            La premisa «arranca sin última cuenta» ya la da el clear del trait, así que la línea solo \
            añade una forma de perder la última cuenta del simulador el día que alguien quite \
            `.lastUsedAccountIsolated` — que es exactamente como estaba este fichero.
            """
        )
    }
}
