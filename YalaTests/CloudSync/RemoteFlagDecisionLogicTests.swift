//
//  RemoteFlagDecisionLogicTests.swift
//  YalaTests / CloudSync
//
//  Pure-logic del remote-config (DIFERIDOS #34): bucket estable, decisión por percent con
//  `absentDefault` PARAMÉTRICO (ajuste A1 del review: los tests corren siempre bajo DEV_BUILD —
//  la rama prod fail-closed entra a la tabla por parámetro) y cadencia de refresh.
//

import Foundation
import Testing

@testable import Yala

@Suite("RemoteFlagDecisionLogic — bucket, percent y refresh (tabla)")
struct RemoteFlagDecisionLogicTests {

    // MARK: - Bucket estable

    @Test func bucket_goldenVectors_stability() {
        // GOLDEN de estabilidad cross-launch: FNV-1a mod 100 con vectores FIJOS. Si estos valores
        // cambian, TODA cohorte de rollout se re-baraja (usuarios entran/salen del %) — jamás
        // cambiar el hash sin migrar el seed.
        #expect(RemoteFlagDecisionLogic.stableBucket(seed: "00000000-0000-0000-0000-000000000000") == 89)
        #expect(RemoteFlagDecisionLogic.stableBucket(seed: "A5CA9791-EFCB-4B8C-88DC-5926E62F50D2") == 37)
        #expect(RemoteFlagDecisionLogic.stableBucket(seed: "seed-a") == 30)
        #expect(RemoteFlagDecisionLogic.stableBucket(seed: "seed-b") == 19)
    }

    @Test func bucket_deterministic_andInRange() {
        for _ in 0..<20 {
            let seed = UUID().uuidString
            let first = RemoteFlagDecisionLogic.stableBucket(seed: seed)
            #expect(first == RemoteFlagDecisionLogic.stableBucket(seed: seed))
            #expect((0..<100).contains(first))
        }
    }

    // MARK: - isEnabled (percent × bucket × absentDefault)

    @Test func isEnabled_table() {
        typealias Row = (percent: Int?, bucket: Int, absentDefault: Bool, expected: Bool)
        let rows: [Row] = [
            // percent presente: bucket < clamp(percent) — absentDefault IRRELEVANTE.
            (0, 0, true, false),     // 0% = OFF universal aunque el default fuera ON
            (0, 99, false, false),
            (100, 0, false, true),   // 100% = ON universal
            (100, 99, false, true),
            (50, 49, false, true),   // frontera: dentro
            (50, 50, false, false),  // frontera: fuera
            (1, 0, false, true),
            (1, 1, false, false),
            // clamp fuera de rango (el server ya clampa; el cliente NO confía)
            (150, 99, false, true),
            (-5, 0, true, false),
            // percent AUSENTE → absentDefault (prod false fail-closed / DEV true)
            (nil, 0, false, false),
            (nil, 0, true, true),
        ]
        for row in rows {
            #expect(
                RemoteFlagDecisionLogic.isEnabled(
                    percent: row.percent, bucket: row.bucket, absentDefault: row.absentDefault
                ) == row.expected,
                "percent=\(String(describing: row.percent)) bucket=\(row.bucket) absent=\(row.absentDefault)"
            )
        }
    }

    // MARK: - shouldRefresh

    @Test func shouldRefresh_table() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // Jamás fetcheado → sí.
        #expect(RemoteFlagDecisionLogic.shouldRefresh(lastFetchedAt: nil, now: now))
        // Fresco (1 h) → no.
        #expect(!RemoteFlagDecisionLogic.shouldRefresh(lastFetchedAt: now.addingTimeInterval(-3600), now: now))
        // Justo en el min-interval (6 h) → sí.
        #expect(RemoteFlagDecisionLogic.shouldRefresh(
            lastFetchedAt: now.addingTimeInterval(-RemoteFlagDecisionLogic.refreshMinInterval), now: now))
        // fetchedAt en el FUTURO (reloj movido hacia atrás) → futuro = stale, refresca YA
        // (fix del review: sin esto, un reloj mal adelantado congelaría el kill-switch).
        #expect(RemoteFlagDecisionLogic.shouldRefresh(lastFetchedAt: now.addingTimeInterval(600), now: now))
    }
}

@Suite("StorageRowGateLogic — visibilidad de la fila Almacenamiento (tabla 2⁴)")
struct StorageRowGateLogicTests {

    @Test func table() {
        typealias Row = (configured: Bool, remote: Bool, engaged: Bool, visible: Bool)
        let rows: [Row] = [
            // Sin backend configurado: JAMÁS visible, da igual el resto. Ya NO es el estado de producción
            // (D-R1 paso 1 la configuró), pero la rama del gate sigue existiendo y hay que pinnearla.
            (false, true, true, false),
            (false, false, false, false),
            // Configurado + remoto ON: visible (engaged irrelevante).
            (true, true, false, true),
            (true, true, true, true),
            // Configurado + remoto OFF (kill-switch): SOLO engaged la conserva
            // (gestión + resume + REVERSA — decisión owner: el kill corta la ENTRADA).
            (true, false, true, true),
            (true, false, false, false),
        ]
        for row in rows {
            #expect(
                StorageRowGateLogic.isVisible(
                    isConfigured: row.configured,
                    remoteEnabled: row.remote,
                    isEngaged: row.engaged
                ) == row.visible,
                "configured=\(row.configured) remote=\(row.remote) engaged=\(row.engaged)"
            )
        }
    }

    /// **El eje nuevo, en sus cuatro celdas del dueño configurado — no solo en la que motivó el ticket.**
    ///
    /// Las tres de arriba (`remote` o `engaged` ya abiertos) parecen gratis y no lo son: sin ellas, un
    /// mutante que invirtiera el término solo cuando hay cuenta que soltar
    /// —`hasGroupsAccountToDetach ? !(remoteEnabled || isEngaged) : (remoteEnabled || isEngaged)`—
    /// pasa la tabla de arriba (que nunca lo pone en `true`) y pasa la celda del kill. Verificado con ese
    /// mutante exacto: sobrevivía a la suite entera.
    @Test func groupsAccountAxis_allFourCells() {
        typealias Row = (remote: Bool, engaged: Bool, groups: Bool, visible: Bool)
        let rows: [Row] = [
            (true, false, true, true),
            (false, true, true, true),
            (true, true, true, true),
            (false, false, true, true),   // la celda del ticket: solo la abre el término nuevo
            (false, false, false, false), // y sin cuenta que soltar, el kill sigue cerrando
        ]
        for row in rows {
            #expect(
                StorageRowGateLogic.isVisible(
                    isConfigured: true,
                    remoteEnabled: row.remote, isEngaged: row.engaged,
                    hasGroupsAccountToDetach: row.groups
                ) == row.visible,
                "remote=\(row.remote) engaged=\(row.engaged) groups=\(row.groups)")
        }
    }

    /// **La celda del ticket `cloud-killswitch-hides-the-only-door-to-detach-groups`.**
    ///
    /// Con el kill de la nube bajado y una sesión privada NO engaged, la fila era la única superficie
    /// desde la que soltar la cuenta de grupos y desaparecía — mientras Grupos seguía funcionando, porque
    /// va por su propio flag. Las dos mitades del arreglo se miden juntas a propósito: la puerta se abre
    /// (`isVisible`) y lo que el incidente cerró sigue cerrado (`offersCloudMigrationEntry`). Fijar solo
    /// la primera dejaría pasar un arreglo que reabre «Migrar a la nube» en pleno incidente.
    @Test func killSwitchKeepsTheDoorToDetachGroups_butNotTheEntry() {
        let visible = StorageRowGateLogic.isVisible(
            isConfigured: true,
            remoteEnabled: false, isEngaged: false,
            hasGroupsAccountToDetach: true)
        #expect(visible, """
            con el kill de la nube bajado y una cuenta de grupos asociada, la fila «¿Dónde viven tus \
            datos?» volvió a ocultarse: quien tenga esa cuenta se queda sin ninguna pantalla desde la \
            que soltarla, y Grupos sigue encendido por su propio flag.
            """)
        #expect(!StorageRowGateLogic.offersCloudMigrationEntry(remoteEnabled: false, isEngaged: false), """
            la fila abierta por la asociación de grupos volvió a ofrecer la ENTRADA personal a la nube \
            con el kill-switch bajado. El kill corta la entrada: abrir la puerta para desasociar no \
            puede abrir también la migración.
            """)

        // El control negativo —sin cuenta que soltar el kill sigue cerrando— vive en
        // `groupsAccountAxis_allFourCells`, con las otras tres celdas del eje.
    }

    /// El guard de arriba manda sobre el término nuevo, y no es cosmético: sin backend configurado
    /// `CloudMigrationController.shared` es `nil`, la pantalla degrada al mensaje genérico y la sección de
    /// grupos NO se monta ⇒ la fila abriría a una puerta sin nada detrás.
    @Test func groupsAssociationDoesNotOverrideTheConfiguredGuard() {
        for remote in [true, false] {
            for engaged in [true, false] {
                #expect(!StorageRowGateLogic.isVisible(
                    isConfigured: false,
                    remoteEnabled: remote, isEngaged: engaged,
                    hasGroupsAccountToDetach: true), """
                    la asociación de grupos abrió la fila SIN backend configurado (remote=\(remote) \
                    engaged=\(engaged)): detrás no se monta la sección de grupos, así que es una puerta \
                    a la pantalla de error.
                    """)
            }
        }
    }

    /// La tabla 2² de la entrada personal a la nube. Es corta y aun así hay que pinnearla entera: es el
    /// único candado que le queda a «Migrar a la nube» desde que la fila puede abrirse por otra razón.
    @Test func cloudMigrationEntryTable() {
        #expect(StorageRowGateLogic.offersCloudMigrationEntry(remoteEnabled: true, isEngaged: false))
        #expect(StorageRowGateLogic.offersCloudMigrationEntry(remoteEnabled: true, isEngaged: true))
        // Engaged bajo el kill: conserva su panel ENTERO, retomar incluido. El kill corta la entrada de
        // los que están fuera, no el camino de vuelta de los que ya están dentro.
        #expect(StorageRowGateLogic.offersCloudMigrationEntry(remoteEnabled: false, isEngaged: true))
        #expect(!StorageRowGateLogic.offersCloudMigrationEntry(remoteEnabled: false, isEngaged: false))
    }

}

/// **La puerta para soltar la cuenta de grupos bajo el kill-switch · cableado (source-scan).**
///
/// La tabla de `StorageRowGateLogicTests` dice qué DEBERÍA pasar; estas afirmaciones dicen quién llama, y
/// ninguna se puede hacer desde un test de comportamiento: la fila vive en una vista SwiftUI, el `if` de la
/// entrada a migrar en otra, y el resolver que las une no tiene estado que inspeccionar. Sin ellas, el
/// término puede quedarse sin cablear —o cableado a un `true`— con la suite entera en verde y el gesto otra
/// vez sin superficie.
///
/// **Sobre el kill-switch en XCUITest, medido el 2026-09-11 y no como se creía:** bajo `-uitest`,
/// `CloudRemoteFlags.decide()` corta en su primera línea y devuelve `absentDefault`, que **depende del
/// scheme** — `true` en `Yala Dev` (`DEV_BUILD`), `false` en `Yala`. O sea que el kill SÍ se reproduce en
/// una corrida de UI, pero solo con el scheme de producción, y el gate y el CI corren `Yala Dev`. Un test
/// cuyo veredicto cambie de signo según el scheme es peor que no tenerlo, así que el caso no baja a
/// `YalaUITests`; y el caso POSITIVO necesitaría además sembrar la asociación, que es el ticket
/// `uitest-seam-for-a-seeded-groups-association`. El recorrido real va al device-QA, con el toggle
/// «Simular remote OFF» del panel DEBUG.
@Suite("Kill-switch de la nube · la fila conserva la puerta de grupos (source-scan)")
struct StorageRowGroupsAssociationWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Código SIN comentarios — los docblocks de esta familia NOMBRAN lo que prohíben, y contar la prosa
    /// haría que documentar el invariante lo satisficiera solo.
    ///
    /// **Se quitan los de bloque además de los de línea, y no es celo:** con solo el filtro de `//`,
    /// envolver el `if` del gate en `/* */` y montar la fila sin él dejaba los cuatro scans en VERDE —
    /// medido sobre estos mismos ficheros. El barrido de `/* */` es no-greedy y multilínea; los `//` se
    /// quitan después, ya sin bloques que los escondan.
    private static func code(_ path: String) throws -> String {
        let raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        let withoutBlocks = raw.replacing(/\/\*[\s\S]*?\*\//, with: " ")
        return withoutBlocks
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Espacios colapsados: el scan mide la ESTRUCTURA de la llamada, no cómo la partió el formateador.
    private static func flat(_ source: String) -> String {
        source.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    @Test("la fila de Ajustes pregunta por el gesto que hay detrás, no por el registro")
    func profileRowAsksForTheDetachGesture() throws {
        let profile = Self.flat(try Self.code("Yala/App/Views/Profile/ProfileView.swift"))
        #expect(profile.contains(
            "hasGroupsAccountToDetach: GroupsAssociationPresence.offersDetach( "
            + "hasCompletedOnboarding: appPreferences.hasCompletedOnboarding)"), """
            la fila «¿Dónde viven tus datos?» dejó de preguntar por la cuenta de grupos que hay que \
            soltar. Con el kill-switch de la nube bajado vuelve a desaparecer, y con ella la ÚNICA \
            superficie desde la que se suelta esa cuenta — mientras Grupos sigue encendido por su flag.
            """)
        // **El registro persistido NO es el criterio**, y escribirlo aquí es volver al primer intento:
        // la sección ofrece «Desasociar» también con sesión viva y sin registro, y esa gente se quedaba
        // otra vez sin puerta. Lo cazaron dos lentes el 2026-09-11.
        #expect(!profile.contains("hasGroupsAccountToDetach: GroupsAccountAssociation"), """
            el término volvió a salir del registro persistido en vez del gesto: diverge de lo que la \
            sección ofrece, y en esa divergencia vive el bug del ticket.
            """)
        #expect(!profile.contains("hasGroupsAccountToDetach: true"), """
            un `true` literal enseña la fila del almacenamiento personal a todo el mundo, kill incluido.
            """)
        // UN solo consumidor del gate: un segundo `isVisible` sin el término monta la misma fila por la
        // puerta de al lado, y las tres aserciones de arriba seguirían verdes.
        let gates = profile.components(separatedBy: "StorageRowGateLogic.isVisible(").count - 1
        #expect(gates == 1, """
            `StorageRowGateLogic.isVisible(` se llama \(gates) veces en ProfileView; el término nuevo \
            solo viaja en una, así que cualquier otra es una fila sin el arreglo.
            """)
    }

    /// **La sección y la fila leen del MISMO sitio.** Es la aserción que impide que el defecto vuelva:
    /// mientras cada una derivaba su estado, divergían en dos celdas —sesión viva sin registro, registro
    /// sin sesión privada— y las dos dejaban al usuario sin puerta o con una puerta a nada.
    @Test("nadie vuelve a derivar el estado de la sección por su cuenta")
    func sectionAndRowShareOneReading() throws {
        let section = Self.flat(try Self.code("Yala/App/Views/Settings/GroupsAssociationSection.swift"))
        #expect(section.contains(
            "GroupsAssociationPresence.sectionState( "
            + "hasCompletedOnboarding: appPreferences.hasCompletedOnboarding)"), """
            la sección volvió a resolver su estado por su cuenta. El gate de la fila pregunta por el \
            mismo estado: con dos lecturas, se separan — ya pasó.
            """)
        #expect(!section.contains("GroupsAssociationLogic.sectionState("), """
            la sección llama a la tabla pura directamente en vez de al resolver: eso es la segunda \
            derivación, con sus tres lecturas propias, que es exactamente lo que divergía.
            """)
        // Y el resolver es el único que las hace: si alguien añade un tercer derivador, esta cuenta sube.
        let logic = try Self.code("Yala/App/Logic/GroupsAssociationPresence.swift")
        #expect(Self.flat(logic).contains("GroupsAssociationLogic.sectionState( deviceState:"), """
            `GroupsAssociationPresence` dejó de ser quien arma el estado; si la lectura se mudó, este \
            scan tiene que mudarse con ella o deja de vigilar nada.
            """)
    }

    /// **El `if` entero, no dos literales sueltos.** Lo que hay que fijar es que la card de migrar quede
    /// DENTRO del gate: un scan de «el fichero nombra el término» lo pasaría también un fichero que lo
    /// llama para otra cosa y deja `migrateCard` suelto al lado.
    @Test("la entrada personal a la nube sigue cerrada bajo el kill, en el render y en la acción")
    func migrateCardAndItsActionStayBehindTheEntryGate() throws {
        let storage = Self.flat(try Self.code("Yala/App/Views/Settings/StorageSettingsView.swift"))
        // El booleano se calcula FUERA del `#expect` a propósito: dentro, el macro vuelca la vista entera
        // —mil líneas aplanadas— en el mensaje del rojo y esconde lo que hay que leer.
        let cardIsBehindTheGate = storage.contains("if offersCloudMigrationEntry { migrateCard(controller) }")
        #expect(cardIsBehindTheGate, """
            «Migrar a la nube» dejó de estar detrás del gate de entrada. Desde que la fila se abre también \
            por una cuenta de grupos que soltar, este `if` es el candado que le queda a la migración bajo \
            el kill-switch: sin él, quien entra a soltar su cuenta durante un incidente se encuentra \
            abierta la puerta que el incidente cerró.
            """)
        // UN solo montaje: si apareciera otro fuera del `if`, la aserción de arriba seguiría verde.
        // Dos apariciones esperadas y no una: la declaración de la función y ese único montaje.
        // (`components(separatedBy:)` devuelve N+1 trozos para N apariciones — el `-1` es eso.)
        let appearances = storage.components(separatedBy: "migrateCard(").count - 1
        #expect(appearances == 2, """
            `migrateCard(` aparece \(appearances) veces y deberían ser 2 (su declaración y el montaje \
            del `case .idle`). El gate solo cubre ese montaje, así que cualquier otro es una puerta \
            abierta bajo el kill-switch.
            """)

        // El término, con su cuerpo entero: un swap de `||` por `&&`, o leer otro flag, pasa cualquier
        // scan que solo busque el nombre de la función.
        let termIsIntact = storage.contains(
            "private var offersCloudMigrationEntry: Bool { "
            + "StorageRowGateLogic.offersCloudMigrationEntry( "
            + "remoteEnabled: CloudRemoteFlags.cloudModeEnabled, "
            + "isEngaged: StorageModePersistence.read() == .cloud "
            + "|| (controller?.uiState ?? .idle) != .idle) }")
        #expect(termIsIntact, """
            el término del kill-switch cambió de forma. Se fija entero porque es el único candado de la \
            migración bajo el kill: leer otro flag, o un `&&` donde va un `||`, lo apaga sin tocar nada más.
            """)

        // **Y la acción, que no es el render.** Los dos arranques del flujo tienen que re-medirlo: la card
        // puede haberse dibujado con el snapshot viejo y el flag caer mientras el consent está arriba.
        #expect(storage.contains("private func proceedToSignInStep() { guard !abortIfCloudEntryClosed() else { return }"), """
            `proceedToSignInStep` dejó de re-medir el kill-switch: un flujo empezado antes de que bajara \
            el flag llega a `startMigration` con el incidente ya declarado.
            """)
        #expect(storage.contains("private func onChooserDismissed() { guard !abortIfCloudEntryClosed() else { return }"), """
            el arranque desde el chooser de proveedor dejó de re-medir el kill-switch. Es el OTRO punto \
            que llama a `startMigration`, y el flag puede caer mientras el chooser está arriba.
            """)
    }
}
