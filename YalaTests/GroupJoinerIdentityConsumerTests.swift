//
//  GroupJoinerIdentityConsumerTests.swift
//  YalaTests
//
//  Pinnea que los consumidores de identidad de Grupos resuelven «quién soy yo» con el resolvedor
//  CANÓNICO y no con el flag `isCurrentUser` a pelo.
//
//  Por qué existe. `5ca4dd47` (2026-09-04) alineó CINCO resolvedores, y
//  `GroupDetailIdentityConsumerTests` puso red al de la pantalla de detalle. Los otros catorce
//  seguían estrechos, y el flag NO lo enciende el pull (`GroupsSyncClient.applyMember` no lo escribe
//  nunca): en producción solo lo escribe `refreshCurrentUserFlags`, y solo en el ARRANQUE. Para quien
//  se unía a un grupo por enlace, eso significaba, sin relanzar la app:
//
//   - su gasto no llegaba a sus cuentas personales, y cuando lo repescaba
//     `GroupsPendingBridgeResume` en un arranque posterior aterrizaba en la cuenta virtual «Grupos»
//     en vez de en la cuenta real elegida en el formulario (`GroupTransactionBridge`);
//   - «Pagado por» abría en blanco y no se le ofrecía su cuenta (`GroupExpenseViewModel`);
//   - el saldo de la tarjeta salía vacío mientras la misma tarjeta ya lo reconocía (`GroupsViewModel`);
//   - sus avisos de grupo se descartaban ENTEROS y en silencio (`GroupNotificationService`).
//
//  Es un source-scan a propósito, por el mismo motivo que el de la pantalla de detalle: el fallo que
//  se persigue no es de cálculo —`GroupIdentityResolutionAlignmentTests` ya cubre el criterio— sino
//  de CABLEADO. Que un consumidor se desconecte del resolvedor canónico se ve leyendo el código, y
//  no lo ve ningún test de comportamiento: todos siguen verdes mientras el bug vuelve.
//
//  La forma concreta en que vuelve es un `FetchDescriptor` con `isCurrentUser == true` metido en el
//  `#Predicate`. Es tentadora porque el criterio canónico NO es traducible a SwiftData (lee estado de
//  sesión y de iCloud), así que quien tenga prisa escribirá el predicado. Por eso el escáner prohíbe
//  la forma, no solo exige la buena.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · los consumidores de identidad usan el canónico (source-scan)")
struct GroupJoinerIdentityConsumerTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Las líneas de CÓDIGO: el escáner tiene que ignorar los comentarios, porque varios de estos
    /// ficheros citan el patrón viejo a propósito para explicar por qué se retiró. Sin este filtro el
    /// test fallaría justo por la documentación que hace el arreglo entendible — y el atajo para
    /// ponerlo verde sería borrarla.
    private static func codeLines(_ src: String) -> [String] {
        src.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
    }

    /// Cada consumidor con un símbolo suyo, que sirve de CONTROL POSITIVO del instrumento: si el
    /// fichero se movió, se renombró o el escáner está leyendo otra cosa, esto falla en vez de pasar
    /// en verde sobre un texto vacío.
    private static let consumidores: [(ruta: String, simbolo: String)] = [
        ("Yala/Services/Groups/GroupTransactionBridge.swift", "func bridgeExpense"),
        ("Yala/App/ViewModels/GroupExpenseViewModel.swift", "var currentUserMemberID"),
        ("Yala/App/ViewModels/GroupsViewModel.swift", "func currentUserBalance"),
        ("Yala/Utils/GroupsExportBuilder.swift", "myMemberIDs"),
        ("Yala/App/Services/ScheduledPaymentDraftService.swift", "groupGateDecision"),
        ("Yala/Services/Groups/GroupService.swift", "func currentUserMember"),
        ("Yala/Services/Groups/GroupNotificationService.swift", "func currentMemberID"),
    ]

    /// La ÚNICA excepción, declarada y con motivo. `ensureCurrentUserMemberExists` no consume la
    /// identidad: la ESTABLECE. Es el write-side del canal CloudKit —dado un `recordName` de iCloud,
    /// encuentra o crea el member propio— y esta rama concreta es su fallback legacy: «hay un member
    /// marcado como mío pero sin record ID, backfilléalo». Ahí el flag pelado ES el criterio correcto,
    /// porque justo esa marca local es lo que busca.
    ///
    /// Alinearlo sería un error de categoría: el resolvedor canónico puede devolver un member del canal
    /// BACKEND (resuelto por `sub`), y esta función le estamparía encima un `cloudKitUserRecordID` —
    /// exactamente la contaminación entre canales que `GroupService` protege con un guard propio.
    ///
    /// Cualquier excepción nueva se declara aquí, con su motivo. Una lista vacía de justificaciones es
    /// lo que convierte un escáner en un sello de goma.
    private static let excepciones: [(ruta: String, fragmento: String)] = [
        ("Yala/Services/Groups/GroupService.swift",
         "if let legacy = members.first(where: { $0.isCurrentUser }) {"),
        // La SEGUNDA excepción, y ésta se alineó y luego se DESHIZO — conviene que quede escrito por
        // qué, o alguien la volverá a alinear con la mejor intención.
        //
        // El guard de removed-self de `AppBootstrapper` contesta «¿existe una fila MÍA expulsada?»,
        // que es POR FILA. El resolvedor singular contesta «¿la fila CANÓNICA está expulsada?». En una
        // zona con dos filas mías las dos preguntas divergen, y aquí divergir cuesta un borrado:
        // `performRemovedSelfCleanup` elimina el grupo con sus gastos, shares y liquidaciones, y emite
        // tombstones al backend. Con la canónica `removed` y la gemela `active` —un re-join que estrena
        // `member_key`— se nukearía el grupo al que el usuario acaba de volver.
        //
        // Alinearlo de verdad pide `resolveAllCurrentUserMembers` MÁS una decisión de producto que
        // nadie ha tomado: qué hacer cuando una fila mía está expulsada y otra activa. Vive en
        // `tickets/backlog/joiner-flag-residuals-cosmetic-and-service-guard.md`.
        ("Yala/App/AppBootstrapper.swift",
         "predicate: #Predicate { $0.isCurrentUser == true && $0.status == removedRaw }")
    ]

    @Test("ningún consumidor resuelve identidad con el flag pelado")
    func ningunConsumidorUsaElFlagPelado() throws {
        for (ruta, simbolo) in Self.consumidores {
            let src = try Self.code(ruta)

            // Control del instrumento.
            #expect(src.count > 1000, "\(ruta) mide \(src.count) caracteres — ¿se movió o se vació?")
            #expect(src.contains(simbolo), """
                No se encontró `\(simbolo)` en \(ruta). O se renombró —y entonces hay que actualizar
                este escáner— o el escáner está leyendo otra cosa.
                """)

            #expect(src.contains("GroupExpenseService.resolveCurrentUserMember"), """
                `\(ruta)` dejó de resolver la identidad con `resolveCurrentUserMember`.

                Ese resolvedor prueba tres vías (flag → `sub` del canal backend → identidad iCloud).
                El flag SOLO lo enciende `refreshCurrentUserFlags`, y solo en el arranque: quien se
                une a un grupo por enlace en sesión viva no lo tiene. Sin el canónico, a esa persona
                el gasto no le llega a sus cuentas, su saldo sale vacío y sus avisos se descartan.
                """)

            let permitidas = Set(Self.excepciones.filter { $0.ruta == ruta }.map(\.fragmento))
            for (i, linea) in Self.codeLines(src).enumerated()
            where linea.contains("isCurrentUser") && !permitidas.contains(linea) {
                #expect(!linea.contains("isCurrentUser == true"), """
                    `\(ruta)` (línea de código \(i + 1)) volvió a meter `isCurrentUser == true` en un
                    predicado: «\(linea)».

                    Esa es la forma exacta del bug. El criterio canónico no es traducible a SwiftData,
                    así que hay que traerse los members de la zona y resolver EN MEMORIA:
                    `GroupExpenseService.resolveCurrentUserMember(inZone:context:)` ya lo hace.
                    """)
                #expect(!linea.contains("first(where: { $0.isCurrentUser })")
                        && !linea.contains("first { $0.isCurrentUser }"), """
                    `\(ruta)` (línea de código \(i + 1)) volvió a resolver la identidad con el flag
                    pelado: «\(linea)». Usa `GroupExpenseService.resolveCurrentUserMember(from:)`.
                    """)
            }
        }
    }

    /// Control del ALLOWLIST. Una excepción que ya no existe en el código es una excepción muerta: deja
    /// de proteger nada y, peor, seguiría permitiendo esa línea exacta si alguien la reintroduce en otro
    /// sitio del mismo fichero. Si esto se pone rojo, la respuesta es borrar la entrada, no reescribirla.
    @Test("las excepciones declaradas siguen existiendo")
    func lasExcepcionesNoEstanMuertas() throws {
        for (ruta, fragmento) in Self.excepciones {
            let src = try Self.code(ruta)
            #expect(src.contains(fragmento), """
                La excepción declarada para `\(ruta)` ya no aparece en el fichero:
                «\(fragmento)»
                O se alineó con el resolvedor canónico —y entonces sobra en la lista— o se reescribió y
                hay que volver a decidir si sigue mereciendo la excepción.
                """)
        }
    }

    /// El helper que hace posible alinear a los consumidores que resolvían dentro de un `#Predicate`.
    /// Lo que se prueba aquí es lo que AÑADE sobre `resolveCurrentUserMember(from:)`, ya cubierto por
    /// `GroupIdentityResolutionAlignmentTests`: que el fetch se acote a la zona pedida y no se cruce
    /// con la de al lado. Un helper que devolviera el member de OTRO grupo sería peor que el bug que
    /// vino a cerrar — atribuiría el gasto a la persona equivocada.
    @Suite("el helper por zona", .serialized)
    struct HelperPorZona {

        @MainActor @Test("resuelve dentro de su zona y no se cruza con la vecina")
        func noSeCruzanLasZonas() throws {
            let context = try makeTestContext()

            let yoEnA = SplitMember(groupZoneID: "zona-A", displayName: "Yo", isCurrentUser: true)
            let otroEnA = SplitMember(groupZoneID: "zona-A", displayName: "Ana")
            let yoEnB = SplitMember(groupZoneID: "zona-B", displayName: "Yo", isCurrentUser: true)
            for m in [yoEnA, otroEnA, yoEnB] { context.insert(m) }
            try context.save()

            let enA = try GroupExpenseService.resolveCurrentUserMember(inZone: "zona-A", context: context)
            let enB = try GroupExpenseService.resolveCurrentUserMember(inZone: "zona-B", context: context)
            #expect(enA?.id == yoEnA.id)
            #expect(enB?.id == yoEnB.id)
        }

        /// Control NEGATIVO: sin ninguna de las tres identidades, el helper devuelve nil en vez de
        /// adjudicarle al usuario un member cualquiera. Es lo que separa este arreglo del backfill
        /// heurístico de `refreshCurrentUserFlags`, que adjudica por coincidencia de `displayName` y
        /// en un grupo con dos nombres iguales le da la identidad a otra persona.
        @MainActor @Test("sin identidad no adjudica a nadie")
        func sinIdentidadNoAdjudica() throws {
            let context = try makeTestContext()
            for nombre in ["Ana", "Beto"] {
                context.insert(SplitMember(groupZoneID: "zona-C", displayName: nombre))
            }
            try context.save()

            #expect(try GroupExpenseService.resolveCurrentUserMember(
                inZone: "zona-C", context: context) == nil)
        }

        /// Una zona vacía no puede resolver a nadie de otra: el `guard` de zona es lo único que
        /// separa «no soy miembro de este grupo» de «soy miembro de aquel».
        @MainActor @Test("una zona sin miembros devuelve nil")
        func zonaVaciaDevuelveNil() throws {
            let context = try makeTestContext()
            context.insert(SplitMember(groupZoneID: "zona-D", displayName: "Yo", isCurrentUser: true))
            try context.save()

            #expect(try GroupExpenseService.resolveCurrentUserMember(
                inZone: "zona-inexistente", context: context) == nil)
        }
    }
}
