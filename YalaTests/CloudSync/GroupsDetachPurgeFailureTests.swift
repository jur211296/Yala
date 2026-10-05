//
//  GroupsDetachPurgeFailureTests.swift
//  YalaTests / CloudSync
//
//  **Si el borrado local falla, el desasociar no puede decir que soltó la cuenta.** Ticket
//  `detach-failure-looks-like-success`.
//
//  Hasta el 2026-09-11 `CloudSessionSignOut.purgeGroupsDomainForDetach` se tragaba el error —lo imprimía
//  bajo `#if DEBUG` y devolvía como si nada— y `detachGroupsAccount` seguía adelante a
//  `GroupsAccountAssociation.shared.clear()`, el marker y `phase = .idle`. Estado resultante: **asociación
//  borrada + los cinco `Split*`, el outbox y el cursor intactos**, con la pantalla diciendo que ya no hay
//  cuenta. Y como el borrado es UNA transacción con rollback, el fallo es todo-o-nada: no queda a medias,
//  queda ENTERO, que es justo lo que la pantalla negaba.
//
//  ## Las tres redes, y por qué cada una es del tipo que es
//
//   1. **El veredicto** — comportamiento donde vive la garantía: `DataWipeService.deleteLocalGroupsRows`
//      es el escritor de los tres caminos, y su `alsoDeleting` es un fallo REAL inyectable (el fetch del
//      outbox o del cursor, que `purgeGroupsDomainForDetach` mete en esa misma transacción). Lo que ese
//      escritor propague sale del desasociar, y que salga lo fija un escáner de UNA línea: que el
//      borrado no haya recuperado su `catch`, que era exactamente el bug.
//   2. **La re-entrancia del libro de conservados** — comportamiento, invocable. Es el camino que este
//      arreglo ABRE: al no limpiar la asociación, la sección vuelve a ofrecer el gesto y `detachBridge`
//      corre una segunda vez. Sin el sello, esa pasada borraba el libro que la primera escribió y
//      re-asociar duplicaba en el Panel cada gasto conservado.
//   3. **El cableado del coordinador** — source-scan, y no por comodidad. `detachGroupsAccount` toca cinco
//      singletons de PROCESO (`GroupsSyncClient.shared` y su espejo del App Group, `CloudAuthService` y su
//      llavero, `GroupsAccountAssociation` y su iCloud-KV, `GroupsSessionHistoryMarker`,
//      `WidgetDataCache`), así que invocarlo desde aquí no mide el invariante: lo que hay que fijar es
//      **dónde está `clear()` respecto del `catch`**, que es exactamente la clase de invariante que este
//      repo pinnea con un escáner (molde `FreshStartWipeAlertTests`, mismo defecto en el alert hermano).
//      El escáner NO busca dos literales sueltos: mide el ORDEN dentro del cuerpo del método, que es lo
//      único que el bug podía violar.
//
//  MUTACIONES verificadas a exit 65 (ver el ticket): (1) devolver el `do/catch` a tragar; (2) mover
//  `clear()` por delante del borrado; (3) quitar el `return .purgeFailed`; (4) quitar el canario;
//  (5) devolver el `clear()` incondicional del libro.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · el desasociar no finge un borrado que no ocurrió", .serialized)
@MainActor
struct GroupsDetachPurgeFailureTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GDPF-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    /// Los tres stores, como en producción. Molde de `GroupsDetachHistoryReplayTests`.
    private func makeFullContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GDPF-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GDPF-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GDPF-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Los tres stores con el **personal en solo lectura**: el `save()` de `detachBridge` lanza. El
    /// personal es el store que ese método toca —`TransactionItem` e `InboxDraft` viven ahí, no en el de
    /// Grupos—, así que es el que hay que cerrar para reproducir su fallo.
    private func makeContextWithReadOnlyPersonalStore(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GDPF-ROP-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), allowsSave: false, cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GDPF-ROP-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GDPF-ROP-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    // MARK: - (1) El veredicto

    /// Error de juguete para el `alsoDeleting` del borrado. Un fallo REAL del fetch del outbox o del
    /// cursor —los dos que `purgeGroupsDomainForDetach` mete en esa misma transacción— llega aquí igual.
    private struct FalloDelStore: Error {}

    @Test("El escritor del dominio Grupos PROPAGA el fallo y deja el contexto limpio")
    func deleteLocalGroupsRows_propagatesAndRollsBack() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeFullContext(dir)

        // Filas reales, persistidas: son las que el borrado va a encolar para borrar antes de morir.
        let group = SplitGroup(name: "Viaje")
        group.isBackendGroup = true
        context.insert(group)
        let expense = SplitExpense(groupZoneID: group.cloudKitZoneID, amount: 20, expenseDescription: "Cena")
        context.insert(expense)
        try context.save()
        #expect(!context.hasChanges)

        // El fallo llega DESPUÉS de los cinco `delete` y ANTES del `save()`: el peor sitio, el que deja
        // el contexto con una transacción sucia si nadie hace rollback.
        #expect(throws: FalloDelStore.self) {
            try DataWipeService.deleteLocalGroupsRows(in: context, includingBridgePreferences: false) {
                throw FalloDelStore()
            }
        }

        // **El contexto queda LIMPIO**, y eso es lo que hace del fallo un todo-o-nada. Es el testigo del
        // `rollback()`: sin él los `delete` se quedarían sucios y el siguiente `save()` de cualquier otro
        // camino los comitearía bajo el autor POR DEFECTO — traducibles a tombstones, que es el borrado
        // remoto que el paso 10 existe para no escribir.
        #expect(!context.hasChanges, """
            Tras el fallo el contexto sigue sucio: el borrado quedó a medias en memoria y el próximo \
            `save()` de cualquier camino lo comitearía bajo el autor por defecto.
            """)

        // Y los datos siguen ENTEROS, que es justo lo que la pantalla negaba. No queda a medias.
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 1)
    }

    @Test("El borrado del desasociar no tiene `catch`: lo que el escritor propague sale de aquí")
    func purgeForDetach_hasNoSwallowingCatch() throws {
        let source = try Self.code("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        guard let start = source.range(of: "static func purgeGroupsDomainForDetach(") else {
            Issue.record("`purgeGroupsDomainForDetach` desapareció o se renombró")
            return
        }
        let tail = source[start.lowerBound...]
        let body = tail.range(of: "\n    }\n").map { String(tail[..<$0.upperBound]) } ?? String(tail)

        #expect(body.contains("throws"), """
            `purgeGroupsDomainForDetach` dejó de ser `throws`: su llamador no puede saber si el borrado \
            entró, que es la pregunta entera de este ticket.
            """)
        // Normalizado a UNA línea: `} catch` partido en dos (`}\n        catch {`) devolvía el bug
        // tragón en VERDE. Lo cazó la lente de tests del 2026-09-11.
        let plano = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
        #expect(!plano.contains("catch"), """
            Volvió a haber un `catch` dentro del borrado del desasociar. Ése era el bug: el error se \
            imprimía bajo `#if DEBUG` y el gesto seguía a `clear()` con los grupos enteros en el teléfono.
            El `do/catch` vive en `writeDetachUnderQuiescence`, y quien decide qué hacer con el fallo es \
            `detachGroupsAccount`.
            """)
    }

    @Test("Control positivo: con los tres stores montados, el mismo borrado entra y vacía el dominio")
    func purgeForDetach_succeedsWithGroupsStore() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeFullContext(dir)

        // Sin este control, el test de arriba pasaría igual con la función rota de cualquier otra forma
        // —lanzando siempre, por ejemplo—, y estaría midiendo el harness en vez del arreglo.
        let group = SplitGroup(name: "Viaje")
        group.isBackendGroup = true
        context.insert(group)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)

        try CloudSessionSignOut.purgeGroupsDomainForDetach(context: context)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
    }

    // MARK: - (2) El libro de conservados sobrevive al reintento

    /// `UserDefaults` aislado: el host de los unit tests es la propia app, así que `.standard` es el del
    /// simulador y el libro escrito ahí sobreviviría a la corrida.
    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Reintentar el desasociar NO borra el libro de conservados de la MISMA cuenta")
    func detachBridge_secondPass_keepsLedgerOfSameAccount() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeFullContext(dir)
        let suite = "GDPF-ledger-same-\(UUID().uuidString)"
        let defaults = isolatedDefaults(suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        // Primera pasada: hay puente, se conserva, el libro queda escrito y sellado con el `sub`.
        let sub = "sub-de-la-cuenta-que-se-va"
        GroupsDetachedBridgeLedger.record(
            sub: sub, expenseIDs: ["gasto-1", "gasto-2"], settlementIDs: [], defaults: defaults)
        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults)?.expenseIDs.count == 2)

        // Segunda pasada: el puente ya está soltado, así que `detachBridge` no encuentra filas. Es
        // EXACTAMENTE el estado en el que queda un desasociar cuyo borrado local falló y se reintenta.
        let outcome = GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: sub, defaults: defaults)

        #expect(outcome != nil, "sin puente que soltar no es un fallo: es un no-op")
        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults)?.expenseIDs == ["gasto-1", "gasto-2"], """
            El reintento del desasociar borró el libro que la PRIMERA pasada escribió. Al re-asociar esa \
            misma cuenta, el bridge no sabría que esos gastos ya están en el Panel y los duplicaría todos.
            """)
    }

    @Test("El libro de OTRA cuenta sí se va: es lo que el clear() hacía bien")
    func detachBridge_secondPass_clearsLedgerOfAnotherAccount() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeFullContext(dir)
        let suite = "GDPF-ledger-other-\(UUID().uuidString)"
        let defaults = isolatedDefaults(suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        GroupsDetachedBridgeLedger.record(
            sub: "cuenta-anterior", expenseIDs: ["gasto-viejo"], settlementIDs: [], defaults: defaults)

        GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "cuenta-de-ahora", defaults: defaults)

        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults) == nil, """
            El libro de una cuenta ANTERIOR frena el puente de la que entra ahora: sus gastos llegarían \
            sin transacción en el Panel.
            """)
    }

    @Test("Sin `sub` con el que comparar, el libro se va: la marca es positiva, no derivada de una ausencia")
    func detachBridge_secondPass_clearsLedgerWhenSubIsMissing() throws {
        for sub: String? in [nil, ""] {
            let dir = freshDir()
            defer { cleanup(dir) }
            let context = try makeFullContext(dir)
            let suite = "GDPF-ledger-nosub-\(UUID().uuidString)"
            let defaults = isolatedDefaults(suite)
            defer { defaults.removePersistentDomain(forName: suite) }

            GroupsDetachedBridgeLedger.record(
                sub: "alguna-cuenta", expenseIDs: ["g"], settlementIDs: [], defaults: defaults)

            GroupsAssociationDetach.detachBridge(
                context: context, choice: .keep, associatedSub: sub, defaults: defaults)

            #expect(GroupsDetachedBridgeLedger.read(defaults: defaults) == nil,
                    "con `sub` \(sub.map { "«\($0)»" } ?? "nulo") no hay sello que comparar")
        }
    }

    @Test("Con `.remove` y el puente ya soltado, el libro de la misma cuenta también sobrevive")
    func detachBridge_removeWithEmptyBridge_keepsLedgerOfSameAccount() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeFullContext(dir)
        let suite = "GDPF-ledger-remove-\(UUID().uuidString)"
        let defaults = isolatedDefaults(suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let sub = "sub-de-la-cuenta-que-se-va"
        GroupsDetachedBridgeLedger.record(
            sub: sub, expenseIDs: ["gasto-1"], settlementIDs: [], defaults: defaults)

        // El par `(.remove, puente vacío)` que los otros tres casos no cubrían (lente de sync,
        // 2026-09-11). Con puente VIVO, `.remove` sí borra el libro: se lleva las transacciones, así que
        // lo que el libro afirma deja de ser cierto. Aquí no hay puente que llevarse —esos gastos ya son
        // movimientos personales normales, y `.remove` no puede quitarlos porque dejaron de ser de
        // grupo—, así que borrarlo solo conseguiría duplicarlos al re-asociar.
        GroupsAssociationDetach.detachBridge(
            context: context, choice: .remove, associatedSub: sub, defaults: defaults)

        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults)?.expenseIDs == ["gasto-1"])
    }

    // MARK: - (3) El desasociar aborta si no pudo tocar el puente

    @Test("Si el `save()` del puente falla, `detachBridge` devuelve nil y el desasociar tiene que abortar")
    func detachBridge_returnsNilWhenSaveFails() throws {
        let dir = freshDir()
        defer { cleanup(dir) }

        // Los archivos primero: con `allowsSave: false` SwiftData no puede crear el store y el container
        // no monta (`loadIssueModelContainer`), que sería un rojo del harness y no del arreglo.
        _ = try makeFullContext(dir)
        let context = try makeContextWithReadOnlyPersonalStore(dir)

        // Una transacción puenteada a una zona del canal backend: es lo que `detachBridge` va a mutar,
        // y su `save()` es el que no puede entrar.
        let group = SplitGroup(name: "Viaje")
        group.isBackendGroup = true
        group.cloudKitZoneID = "zona-1"
        context.insert(group)
        let tx = TransactionItem(date: .now, amount: -20, currencyCode: "PEN")
        tx.splitExpenseID = UUID().uuidString
        tx.splitGroupZoneID = "zona-1"
        context.insert(tx)

        let outcome = GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "sub-x")

        #expect(outcome == nil, """
            El `save()` del des-puenteo falló y `detachBridge` devolvió un `Outcome` en vez de `nil`. El \
            `guard … != nil` del desasociar lo lee como éxito, sigue a la purga y borra las cinco \
            `Split*` — dejando las transacciones cuyos punteros el `rollback()` acaba de reponer \
            apuntando a una zona sin filas vivas. A ésas no las recoge nadie: es dinero atrapado.
            """)
    }

    // MARK: - (4) La marca no sobrevive a las fronteras que la tienen que borrar

    @Test("El relevo de humano se lleva la marca del desasociar a medias")
    func freshStartClearsPendingPurgeMark() throws {
        let suite = "GDPF-wipe-\(UUID().uuidString)"
        let defaults = isolatedDefaults(suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        GroupsDetachPendingPurge.arm(sub: "sub-x", defaults: defaults)
        #expect(GroupsDetachPendingPurge.isArmed(for: "sub-x", defaults: defaults), "el harness no armó nada")

        DataWipeService.removeGroupsDomainPreferenceKeys(from: defaults)

        #expect(!GroupsDetachPendingPurge.isArmed(for: "sub-x", defaults: defaults), """
            La marca sobrevivió al «Empiezo de cero». Esa función es una LISTA de keys, no un barrido por \
            prefijo, así que el `groups.*` del nombre no la borra solo: hay que nombrarla. Quien recibe \
            el teléfono vería en «¿Dónde viven tus datos?» un botón para «terminar de soltar» una cuenta \
            que nunca asoció.
            """)
    }

    @Test("La marca va SELLADA: no casa con otra cuenta, ni sin `sub` con el que comparar")
    func pendingPurgeMark_isSealedBySub() throws {
        let suite = "GDPF-seal-\(UUID().uuidString)"
        let defaults = isolatedDefaults(suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        GroupsDetachPendingPurge.arm(sub: "cuenta-A", defaults: defaults)

        #expect(GroupsDetachPendingPurge.isArmed(for: "cuenta-A", defaults: defaults))
        #expect(!GroupsDetachPendingPurge.isArmed(for: "cuenta-B", defaults: defaults), """
            La marca de la cuenta A dice que sí a la cuenta B. Con eso, «Terminar de soltar la cuenta» \
            borra el dominio Grupos de una cuenta que nunca quedó a medias.
            """)
        #expect(!GroupsDetachPendingPurge.isArmed(for: nil, defaults: defaults))
        #expect(!GroupsDetachPendingPurge.isArmed(for: "", defaults: defaults))

        // Y sin `sub` NO se arma: sin sello no hay forma de saber a quién pertenece lo pendiente.
        GroupsDetachPendingPurge.clear(defaults: defaults)
        GroupsDetachPendingPurge.arm(sub: nil, defaults: defaults)
        #expect(GroupsDetachPendingPurge.armedSub(defaults: defaults) == nil)
        GroupsDetachPendingPurge.arm(sub: "", defaults: defaults)
        #expect(GroupsDetachPendingPurge.armedSub(defaults: defaults) == nil)
    }

    // MARK: - (5) El cableado del coordinador

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Código SIN líneas de comentario: el porqué de cada pieza se explica ahí nombrándola, y contar prosa
    /// haría que documentar el invariante lo satisficiera solo.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de `detachGroupsAccount`, del `func` hasta la llave de cierre de su primer nivel.
    private static func detachBody() throws -> String {
        let source = try code("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        guard let start = source.range(of: "func detachGroupsAccount(") else {
            Issue.record("`detachGroupsAccount` desapareció o se renombró")
            return ""
        }
        let tail = source[start.lowerBound...]
        // El cuerpo termina en la primera línea que cierra a la indentación del método (`    }`).
        guard let end = tail.range(of: "\n    }\n") else { return String(tail) }
        return String(tail[..<end.upperBound])
    }

    @Test("El borrado es la ÚLTIMA condición: nada del tramo final corre si lanzó")
    func detachGroupsAccount_doesNotClearWhenPurgeThrows() throws {
        let body = try Self.detachBody()

        guard let purge = body.range(of: "case .purgeFailed:"),
              let failure = body.range(of: "return .purgeFailed"),
              let clear = body.range(of: "finishDetach(context: context)") else {
            Issue.record("""
                El cableado del desasociar cambió de forma. Las tres piezas que este invariante exige son \
                la rama `.purgeFailed` del borrado, su `return .purgeFailed`, y el remate \
                `finishDetach`. Si el método se reescribió, relee el ticket antes de reescribir este test: \
                lo que se fija es que la asociación NO se limpie sobre unos datos que siguen ahí.
                """)
            return
        }

        #expect(purge.lowerBound < failure.lowerBound && failure.lowerBound < clear.lowerBound, """
            `finishDetach` —el remate que limpia la asociación— ya no está DESPUÉS del \
            `return .purgeFailed` del borrado. Tal como queda, un borrado que lanza sigue adelante y borra la asociación con los \
            grupos enteros en el teléfono: la pantalla dice que soltó la cuenta y el teléfono dice que no.
            """)

        // Las otras tres afirmaciones del tramo final van con `clear()`: si una se colara por delante del
        // `return`, el desasociar volvería a mentir por otra vía (el marker, el widget o la fase).
        // El canario entra en la comparación de ORDEN y no solo en un `contains`: moverlo al camino de
        // éxito dejaba los dos tests en verde (lente de tests, 2026-09-11).
        if let canary = body.range(of: ".groupsDetachPurgeFailed") {
            #expect(purge.lowerBound < canary.lowerBound && canary.lowerBound < failure.lowerBound, """
                El canario del borrado fallido ya no está entre el borrado y su `return`: se emite en un \
                camino que no es el del fallo, así que la métrica deja de contar lo que dice contar.
                """)
        }

        guard let arm = body.range(of: "GroupsDetachPendingPurge.arm(sub: associatedSub)") else {
            Issue.record("el fallo del borrado ya no arma la marca durable"); return
        }
        #expect(purge.lowerBound < arm.lowerBound && arm.lowerBound < failure.lowerBound, """
            La marca `GroupsDetachPendingPurge` ya no se arma en el `catch` del borrado, o dejó de ir \
            sellada con el `sub` de la cuenta que se estaba soltando. Sin ella, al \
            reabrir la app la sección vuelve a ofrecer el gesto entero con sus dos salidas y la segunda \
            ya no puede aplicarse: quien pida «quitar» sus movimientos del Panel se los queda, en silencio.
            """)
        guard let detached = body.range(of: "return .detached") else {
            Issue.record("`return .detached` desapareció del desasociar"); return
        }
        #expect(failure.lowerBound < detached.lowerBound,
                "`return .detached` corre aunque el borrado haya fallado")
    }

    /// El cuerpo de `retryDetachPurge`, para las dos afirmaciones que el refactor dejó fuera del escáner
    /// del gesto: que no re-ejecuta el gesto entero, y que comprueba el sello antes de borrar.
    private static func retryBody() throws -> String {
        let source = try code("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        guard let start = source.range(of: "func retryDetachPurge(") else {
            Issue.record("`retryDetachPurge` desapareció o se renombró"); return ""
        }
        let tail = source[start.lowerBound...]
        guard let end = tail.range(of: "\n    }\n") else { return String(tail) }
        return String(tail[..<end.upperBound])
    }

    @Test("El reintento NO repite el gesto: no vuelve a entrar por el push-all tras el teardown")
    func retryDetachPurge_doesNotReRunTheWholeGesture() throws {
        let body = try Self.retryBody()

        for prohibido in ["detachGroupsAccount", "pushGroupsForSignOut", "teardownForSignOut",
                          "CloudAuthService.shared.signOut", "detachBridge"] {
            #expect(!body.contains(prohibido), """
                `retryDetachPurge` volvió a llamar a `\(prohibido)`. El reintento tiene que ser ACOTADO \
                al borrado: repetir el gesto entra por el push-all DESPUÉS del teardown —lo que prohíben \
                los docblocks de `pushAllPendingGroupsForSignOut` y `attemptGroupsOnlyClose`— y un gasto \
                añadido entre el fallo y el reintento deja History que ese drain traduce a outbox, \
                quemando 20 ciclos sin credenciales hasta `.blocked`: el desasociar deja de poder \
                terminarse. Y `detachBridge` en segunda pasada ignora la salida elegida.
                """)
        }
        #expect(body.contains("GroupsDetachPendingPurge.isArmed(for:"), """
            El reintento ya no comprueba el sello de la marca. Sin esa comprobación borra el dominio \
            Grupos de la cuenta que esté asociada AHORA, no de la que quedó a medias.
            """)
        #expect(body.contains("CloudAuthService.shared.currentUserID != GroupsDetachPendingPurge.armedSub()"), """
            El reintento ya no descarta la sesión viva de la cuenta pendiente. Este método no hace \
            teardown ni suelta credenciales: correrlo con esa sesión repuesta deja a la persona dentro \
            de una cuenta cuyos datos locales acaba de borrar y cuya asociación acaba de limpiar.
            """)
        #expect(body.contains("finishDetach(context: context)"),
                "el reintento ya no remata: la asociación se quedaría puesta sobre un dominio vacío")
    }

    @Test("El remate `finishDetach` sigue afirmando las cuatro cosas, y limpia la marca")
    func finishDetach_stillAssertsEverything() throws {
        let source = try Self.code("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        guard let start = source.range(of: "private func finishDetach(") else {
            Issue.record("`finishDetach` desapareció o se renombró"); return
        }
        let tail = source[start.lowerBound...]
        let body = tail.range(of: "\n    }\n").map { String(tail[..<$0.upperBound]) } ?? String(tail)

        // El refactor sacó estas cuatro líneas del cuerpo del gesto, donde el escáner de orden las
        // miraba. Sin este test, vaciar `finishDetach` deja los otros dos en VERDE.
        for afirmacion in ["GroupsAccountAssociation.shared.clear()",
                           "GroupsSessionHistoryMarker.markSessionSeen()",
                           "GroupsDetachPendingPurge.clear()",
                           "WidgetDataCache.updateCache(context: context)",
                           "phase = .idle"] {
            #expect(body.contains(afirmacion), """
                `finishDetach` ya no hace `\(afirmacion)`. Es el remate COMPARTIDO por el gesto y su \
                reintento: lo que se pierda aquí se pierde en los dos, y sin `GroupsDetachPendingPurge \
                .clear()` la marca se queda armada para siempre sobre una cuenta ya soltada.
                """)
        }
    }

    @Test("El fallo del borrado emite su canario, y fuera de `#if DEBUG`")
    func detachGroupsAccount_emitsCanaryOnPurgeFailure() throws {
        let body = try Self.detachBody()

        #expect(body.contains(".groupsDetachPurgeFailed"), """
            El `catch` del borrado ya no emite `MetricsService.canary(.groupsDetachPurgeFailed)`. Sin él \
            este fallo vuelve a ser invisible en producción, que es la mitad del defecto que el ticket \
            arregla: nadie se entera de un borrado que no ocurre.
            """)

        // Fuera de Debug, igual que su hermano `freshStartWipeFailed`: el `#if DEBUG` de al lado envuelve
        // solo el `print`, y meter el canario dentro lo apagaría justo en el build donde importa.
        guard let canary = body.range(of: ".groupsDetachPurgeFailed") else { return }
        let antes = body[..<canary.lowerBound]
        let debugAbiertos = antes.components(separatedBy: "#if DEBUG").count - 1
        let debugCerrados = antes.components(separatedBy: "#endif").count - 1
        #expect(debugAbiertos == debugCerrados, """
            El canario del borrado fallido quedó DENTRO de un `#if DEBUG`: en producción no se emite, que \
            es exactamente donde hace falta.
            """)

        let metrics = try Self.code("Yala/Services/Metrics/MetricsService.swift")
        #expect(metrics.contains("case groupsDetachPurgeFailed"),
                "el canario no está en el inventario de `MetricsCanary`")
    }
}
