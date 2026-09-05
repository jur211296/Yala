//
//  GroupDetailIdentityConsumerTests.swift
//  YalaTests
//
//  Pinnea que la pantalla de detalle de grupo resuelve «quién soy yo» con el resolvedor CANÓNICO y
//  no con el flag pelado, y que la caption de perspectiva no puede volver a afirmar sobre una
//  identidad que no conoce.
//
//  Por qué existe. El 2026-08-28, en dos teléfonos, A creó un gasto de 20 soles mitad y mitad y B lo
//  vio como «No participaste». Causa: `GroupDetailViewModel.currentUserMember` era
//  `members.first { $0.isCurrentUser }`, y ese flag NO lo enciende nunca el pull
//  (`GroupsSyncClient.applyMember`); en producción solo lo escribe `refreshCurrentUserFlags`, cuyo
//  único call-site está en el ARRANQUE. Quien se unía por enlace en sesión viva no tenía identidad
//  local hasta relanzar la app — y por eso el force-quit «arreglaba» el gasto.
//
//  El commit `5ca4dd47` (2026-09-04) alineó ese consumidor con
//  `GroupExpenseService.resolveCurrentUserMember`. Pero lo dejó SIN RED: los tests que existen
//  pinnean el RESOLVEDOR, así que si alguien vuelve a escribir `first { $0.isCurrentUser }` en el
//  ViewModel, siguen todos verdes y el bug vuelve en silencio. Eso es lo que cierra este fichero.
//
//  Es un source-scan a propósito: `GroupDetailViewModel.members` es `private(set)` y se puebla desde
//  SwiftData, así que el consumidor no se monta sin un store. El fallo que se persigue no es de
//  cálculo —la lógica pura ya está cubierta— sino de CABLEADO: que un consumidor se desconecte del
//  resolvedor canónico. Eso se ve leyendo el código, y no lo ve ningún test de comportamiento.
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos · el detalle resuelve identidad por el canónico (source-scan)")
struct GroupDetailIdentityConsumerTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Los consumidores que alimentan la caption de perspectiva del detalle de grupo.
    private static let consumidores = [
        "Yala/App/ViewModels/GroupDetailViewModel.swift"
    ]

    @Test("el detalle no resuelve identidad con el flag pelado")
    func elDetalleUsaElResolvedorCanonico() throws {
        for ruta in Self.consumidores {
            let src = try Self.code(ruta)

            // Control del instrumento: si el escáner deja de leer el fichero, que se note aquí y no
            // en un verde vacío.
            #expect(src.count > 1000, "\(ruta) mide \(src.count) caracteres — ¿se movió o se vació?")
            #expect(src.contains("currentUserMember"), """
                No se encontró `currentUserMember` en \(ruta). O se renombró —y entonces hay que
                actualizar este escáner— o el escáner está leyendo otra cosa.
                """)

            #expect(src.contains("GroupExpenseService.resolveCurrentUserMember"), """
                `\(ruta)` dejó de resolver la identidad con `resolveCurrentUserMember`.

                Ese resolvedor prueba tres vías (flag → `sub` del canal backend → identidad iCloud).
                El flag SOLO lo enciende `refreshCurrentUserFlags`, y solo en el arranque: quien se
                une por enlace en sesión viva no lo tiene. Sin el canónico, a esa persona la pantalla
                le dice «No participaste» en gastos que sí comparte, y el otro teléfono muestra otra
                cosa. Pasó en device el 2026-08-28 y lo cerró `5ca4dd47`.
                """)

            #expect(!src.contains("first { $0.isCurrentUser }"), """
                `\(ruta)` volvió a resolver la identidad con el flag pelado
                (`first { $0.isCurrentUser }`). Es exactamente la línea que causó el bug del
                2026-08-28. Usa `GroupExpenseService.resolveCurrentUserMember(from:)`.
                """)
        }
    }

    /// La otra mitad del arreglo: aunque la identidad no resuelva, la pantalla no puede AFIRMAR.
    @Test("los llamadores del resolver de perspectiva no inventan un id vacío")
    func nadieVuelveAlCentinelaVacio() throws {
        let llamadores = [
            "Yala/App/Views/Groups/GroupRecordsView.swift",
            "Yala/App/Views/Groups/GroupExpenseDetailSheet.swift"
        ]
        for ruta in llamadores {
            let src = try Self.code(ruta)
            #expect(src.contains("GroupExpenseAmountResolver.resolve"), """
                No se encontró la llamada al resolver en \(ruta) — ¿se movió la caption de sitio?
                Si es así, este escáner hay que apuntarlo al fichero nuevo, no borrarlo.
                """)
            #expect(!src.contains("currentMemberID ?? \"\""), """
                `\(ruta)` volvió a pasar `currentMemberID ?? ""` al resolver de perspectiva.

                Ese centinela vacío no casa con ningún `paidByMemberID` ni con ningún share, así que
                convierte «no sé quién eres» en «no participaste» — una afirmación categórica sobre
                el dinero de alguien, construida sobre una ignorancia. El resolver acepta `String?`
                justamente para poder distinguirlas: pásale el opcional tal cual.
                """)
        }
    }

    /// `PersonalShareStatus` tiene que seguir distinguiendo los dos estados. Si alguien fusiona
    /// `identityUnresolved` con `notIncluded` «porque los dos pintan lo mismo», el bug vuelve: pintan
    /// igual en el feed por casualidad, no por ser lo mismo.
    @Test("`identityUnresolved` y `notIncluded` siguen siendo estados distintos")
    func losDosEstadosNoSeFusionan() throws {
        let src = try Self.code("Yala/App/Logic/GroupExpenseAmountResolver.swift")
        #expect(src.contains("case identityUnresolved"), """
            Desapareció `PersonalShareStatus.identityUnresolved`. Sin él, la pantalla vuelve a tener
            un solo cajón para «no participas» y «no sé quién eres».
            """)
        #expect(src.contains("case notIncluded"), "Desapareció `notIncluded` — ¿se renombró?")
    }
}
