//
//  RestoreDataPresenceWiringTests.swift
//  YalaTests / CloudSync
//
//  `restore-treats-budgets-and-groups-as-no-data` · **la invariante que se rompió tres veces.**
//
//  El bug del ticket no fue un predicado mal escrito: fue un predicado que creció y dejó atrás a sus
//  consumidores. Tres veces, medidas:
//
//   1. `hasAnyData` contaba las categorías y `WelcomePrivateICloudGateView.countsLine` no las pintaba →
//      aviso de borrado irreversible con la línea en blanco (cerrado el 2026-09-10).
//   2. `hasAnyData` contaba las categorías y `WelcomeRestoreView.visibleCountItems` tampoco → pantalla
//      «Encontramos tus datos en iCloud:» sobre un grid vacío (cerrado aquí, 2026-09-21).
//   3. `ICloudAccountSummary` transportaba `budgetsCount` y `groupsCount`, su predicado los ignoraba y
//      `RestoreProgressView.liveCounts` los pintaba subiendo → la pantalla los enseñaba llegar y la
//      siguiente negaba que existieran (el ticket).
//
//  Un test por caso no cierra la clase: lo que hace falta es que **cada término del predicado tenga
//  consumidor**, y eso solo lo puede comprobar algo que DERIVE la lista de términos del propio código en
//  vez de repetirla. Por eso este fichero es source-scan y no una tabla de casos: una tabla escrita a
//  mano se queda corta exactamente igual que se quedaron los consumidores.
//
//  **Lo que NO prueba, y va dicho:** que las cifras estén bien contadas (eso es
//  `ICloudAccountSummaryTests`, contra un store real) ni que la sonda lea CloudKit (device-QA: no hay
//  CloudKit en simulador ni en CI). Aquí se prueba el cableado entre un predicado y quien lo enseña.
//
//  **Una sola `@Suite` a propósito**: `-only-testing` filtra por TIPO, no por fichero.
//

import Foundation
import Testing

@testable import Yala

@Suite("Restaurar · todo término de «hay datos» tiene quien lo pinte (source-scan)")
struct RestoreDataPresenceWiringTests {

    // MARK: - Lectura del árbol

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// El fichero SIN sus líneas de comentario. **Obligatorio aquí**: los docblocks de los predicados
    /// nombran en prosa los mismos identificadores que se buscan —`budgetsCount`, `CD_SplitGroup`—, así
    /// que sin el filtro un término borrado del código seguiría «apareciendo» y el test pasaría sobre el
    /// bug. `///` empieza por `//`, así que cae con los demás.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo entre llaves balanceadas desde un marcador. Acotar no es cosmético: `RestoreProgressView`
    /// nombra las mismas cifras en `liveCounts` y en el summary de reserva de `startFlow`, así que un
    /// `contains` sobre el fichero entero confundiría «tiene su chip» con «aparece en el fichero».
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker),
                                 Comment(rawValue: "marcador no encontrado: \(marker)"))
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    /// **Los argumentos de UNA llamada, por PARÉNTESIS balanceados.** `body(of:)` cuenta LLAVES, así
    /// que sobre un marcador que abre paréntesis —`ICloudPersonalCorpus(`— no acota nada: seguiría
    /// hasta la primera `}` que cierre el bloque de fuera y devolvería medio fichero, con lo que un
    /// `contains` lo cumpliría cualquier vecino. Es el mismo helper de `RestoreStartFreshGateTests`.
    private static func call(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker),
                                 Comment(rawValue: "llamada no encontrada: \(marker)"))
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "(" { depth += 1 }
            if chars[i] == ")" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    /// Los identificadores que un predicado compara contra cero: `x > 0` → `x`. Derivar la lista es el
    /// punto entero del fichero — repetirla a mano la dejaría desactualizada en el mismo commit en que
    /// alguien añada el sexto término.
    private static func terminos(delPredicado cuerpo: String) throws -> [String] {
        let patron = try NSRegularExpression(pattern: #"([A-Za-z_][A-Za-z0-9_]*)\s*>\s*0"#)
        let rango = NSRange(cuerpo.startIndex..<cuerpo.endIndex, in: cuerpo)
        var vistos: [String] = []
        for m in patron.matches(in: cuerpo, range: rango) {
            guard let r = Range(m.range(at: 1), in: cuerpo) else { continue }
            let nombre = String(cuerpo[r])
            if !vistos.contains(nombre) { vistos.append(nombre) }
        }
        return vistos
    }

    private static func terminosDelResumen() throws -> [String] {
        try terminos(delPredicado: body(of: "var hasAnyData: Bool {",
                                        in: code("Yala/Services/iCloudSyncService.swift")))
    }

    // MARK: - (A) El predicado del resumen y sus dos pantallas

    /// **El control positivo va primero**, y no es ceremonia: si el marcador cambia de forma o la regex
    /// falla, `terminos` devuelve `[]` y TODOS los `for` de abajo pasan sin comprobar nada — una
    /// medición que falla abierto. Los cuatro términos se escriben aquí a mano justamente para que el
    /// día que alguien añada o quite uno este test se ponga rojo y le obligue a mirar los consumidores.
    ///
    /// **Y `groupsCount` NO está, que es la mitad que más protege.** Es el término que el ticket pedía
    /// añadir y que la review refutó: los grupos no vienen de iCloud, y como `WelcomeRestoreView`
    /// decide con un `if hasAnyData` que cortocircuita, contarlos volvería inalcanzables
    /// `.importIncomplete`, `.cloudPaused`, `.cloudUnverified` y `.notFound` para todo el que tenga
    /// uno — por construcción en `FullModeActivationView`, a la que solo se llega desde una sesión
    /// solo-grupos. El razonamiento largo está en el docblock del predicado.
    @Test("el predicado del resumen tiene CUATRO términos, y los grupos no son uno de ellos")
    func summaryPredicate_isReadable() throws {
        let leidos = try Self.terminosDelResumen()

        #expect(Set(leidos) == ["accountsCount", "transactionsCount", "categoriesCount",
                                "budgetsCount"], """
            los términos de `ICloudAccountSummary.hasAnyData` cambiaron (leídos: \(leidos)). No es un
            fallo del test: es la señal de que hay que decidir qué pantalla enseña el término nuevo —o
            por qué el que se fue ya no hace falta— y actualizar esta lista a conciencia.
            """)
        #expect(!leidos.contains("groupsCount"), """
            los grupos volvieron al predicado. Antes de quitar esta línea, lee por qué salieron: no es
            una asimetría pendiente de alinear con `visibleCountItems`, es que este predicado contesta
            «¿trajo algo el espejo de iCloud?» y los grupos no pasan por ahí.
            """)
        // Control negativo en la dirección contraria: el extractor no se inventa nombres.
        #expect(!leidos.contains("inventadoCount"))
    }

    /// El consumidor que este ticket arregló. Cada término, su card.
    @Test("cada término del resumen tiene card en la pantalla del hallazgo")
    func everyTerm_hasCardInFoundScreen() throws {
        let lista = try Self.body(
            of: "private func visibleCountItems(for s: ICloudAccountSummary) -> [CountItem] {",
            in: Self.code("Yala/App/Views/Onboarding/WelcomeRestoreView.swift"))

        let terminos = try Self.terminosDelResumen()
        #expect(!terminos.isEmpty, "sin términos no se comprueba nada: ver el control positivo")
        for termino in terminos {
            // **No basta con que la CONDICIÓN esté: tiene que añadir algo.** Comprobar solo el `if`
            // dejaba vivo el mutante que de verdad importa —el que vacía su cuerpo—, y ese es
            // exactamente el defecto que este fichero existe para cazar: una rama que mira el término
            // y no pinta nada se lee igual que no tenerla. Medido el 2026-09-21: con el `contains` a
            // secas, el mutante SOBREVIVÍA.
            let rama = try Self.body(of: "s.\(termino) > 0 {", in: lista)
            #expect(rama.contains("items.append(CountItem("), Comment(rawValue: """
                `\(termino)` enciende `hasAnyData` y `visibleCountItems` no añade su card. Esa
                combinación no es un detalle cosmético: `countCards` con cero items cae en su
                `default` y dibuja un grid vacío bajo «Encontramos tus datos en iCloud:».
                """))
            #expect(rama.contains("count: s.\(termino)"), Comment(rawValue: """
                la card de `\(termino)` se añade con OTRA cifra: el `if` mira un término y el número
                que se enseña es el del vecino. Compila, y en pantalla son dos números creíbles.
                """))
        }
    }

    /// Y la pantalla de progreso, que es donde la persona ve las cifras SUBIR. Su hueco fue el que
    /// hizo visible el bug: enseñaba llegar unos datos que la pantalla siguiente negaba.
    @Test("cada término del resumen tiene chip en la pantalla de progreso")
    func everyTerm_hasChipInProgressScreen() throws {
        let chips = try Self.body(of: "private var liveCounts: some View {",
                                  in: Self.code("Yala/App/Views/Onboarding/RestoreProgressView.swift"))

        let terminos = try Self.terminosDelResumen()
        #expect(!terminos.isEmpty)
        for termino in terminos {
            #expect(chips.contains("counts?.\(termino)"), Comment(rawValue: """
                `\(termino)` cuenta para «hay datos» y no aparece entre los chips del progreso: la
                persona no lo ve bajar y luego se le dice que existe (o que no).
                """))
        }
    }

    /// **La dirección contraria, para el único término que va suelto: los grupos siguen teniendo su
    /// card aunque NO estén en el predicado.** Sin esto, quien lea `summaryPredicate_isReadable` y vea
    /// que los grupos no cuentan tiene una invitación a quitar también su card — y entonces alguien con
    /// presupuestos bajados y tres grupos vería «Encontramos tus datos» sin rastro de sus grupos, que
    /// es la mitad de lo que tiene.
    @Test("los grupos se PINTAN aunque no decidan")
    func groupsStillHaveTheirCard() throws {
        let lista = try Self.body(
            of: "private func visibleCountItems(for s: ICloudAccountSummary) -> [CountItem] {",
            in: Self.code("Yala/App/Views/Onboarding/WelcomeRestoreView.swift"))
        let rama = try Self.body(of: "s.groupsCount > 0 {", in: lista)
        #expect(rama.contains("count: s.groupsCount"))
        let chips = try Self.body(of: "private var liveCounts: some View {",
                                  in: Self.code("Yala/App/Views/Onboarding/RestoreProgressView.swift"))
        #expect(chips.contains("counts?.groupsCount"))
    }

    // MARK: - (B) El predicado de la sonda y su línea de cifras

    /// Misma invariante, otra mitad del par. Aquí los términos son CUATRO: los grupos no pueden estar
    /// (ver el test de abajo), y esa ausencia se fija para que nadie la "arregle" añadiendo un cero.
    @Test("cada término del corpus aparece en la línea de cifras de la puerta")
    func everyCorpusTerm_hasLineInGate() throws {
        let predicado = try Self.body(
            of: "var hasAnyData: Bool {",
            in: Self.code("Yala/Services/CloudSync/ICloudPersonalCorpusProbe.swift"))
        let linea = try Self.body(
            of: "static func countsLine(_ corpus: ICloudPersonalCorpus, forVoiceOver: Bool = false) -> String {",
            in: Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift"))

        let terminos = try Self.terminos(delPredicado: predicado)
        #expect(Set(terminos) == ["transactions", "accounts", "categories", "budgets"], """
            los términos de `ICloudPersonalCorpus.hasAnyData` cambiaron (leídos: \(terminos)).
            """)
        for termino in terminos {
            // Misma lección que arriba: se acota la rama y se exige que AÑADA, no que mire.
            let rama = try Self.body(of: "corpus.\(termino) > 0 {", in: linea)
            #expect(rama.contains("parts.append("), Comment(rawValue: """
                `\(termino)` levanta el aviso de la puerta y `countsLine` no añade su fragmento: la
                persona confirmaría un borrado irreversible con la línea de cifras en blanco.
                """))
            #expect(rama.contains("corpus.\(termino)"), Comment(rawValue: """
                el fragmento de `\(termino)` se compone con otra cifra.
                """))
        }
    }

    // MARK: - (C) El conteo que ningún test puede ejecutar

    /// **`classify` no se puede probar aquí y por eso se escanea.** Es `private static`, recibe un
    /// `CKRecord` y solo corre dentro de `measureFromCloudKit`, que habla con un `CKContainer` real: no
    /// existe en simulador ni en CI. Sin este test, borrar el `case "CD_Budget"` deja la sonda contando
    /// cero presupuestos para siempre, con la suite entera en verde y el ticket a medio cerrar.
    ///
    /// Se fija el `case`, el incremento **y** que el valor VIAJE al corpus construido. Los tres, porque
    /// cada uno muere solo: un `case` sin su `+= 1` compila, y contar bien y pasar un literal al
    /// constructor también.
    @Test("la sonda cuenta `CD_Budget` y el número llega al corpus")
    func probe_countsBudgetRecords() throws {
        let fuente = try Self.code("Yala/Services/CloudSync/ICloudPersonalCorpusProbe.swift")
        // El marcador es el CIERRE de la signatura y no su apertura: `body(of:)` cuenta llaves desde
        // donde se le diga, así que empezar en `func classify(` —que aún no ha abierto ninguna— haría
        // que el cierre de la función bajara a 1 y no a 0, y el tramo se comería el resto del fichero.
        // Medido: `oldest: inout Date?) {` es único en él.
        let clasificador = try Self.body(of: "oldest: inout Date?) {", in: fuente)

        #expect(clasificador.contains("case \"CD_Budget\":"), """
            la sonda dejó de reconocer el tipo. Es el único término de `hasAnyData` que sí existe en el
            contenedor personal y que este fichero puede contar.
            """)
        #expect(clasificador.contains("budgets += 1"), """
            reconoce el tipo y no lo suma: el `case` está y cuenta cero.
            """)

        let construccion = try Self.call(of: ".measured(ICloudPersonalCorpus(", in: fuente)
        #expect(construccion.contains("budgets: budgets"), """
            se cuenta y no viaja. Un literal ahí compila y deja la sonda diciendo siempre «cero
            presupuestos».
            """)
    }

    /// **La ausencia de grupos en la sonda es ESTRUCTURAL y se fija como tal.** `SplitGroup` vive en
    /// `groupsSchema`, cuyo store monta `cloudKitDatabase: .none`, y sus filas llegan por el backend de
    /// Yala: no hay ningún `CD_SplitGroup` que contar en el contenedor personal. El riesgo real es el
    /// contrario al de siempre — que alguien vea la asimetría con `ICloudAccountSummary` y la "alinee"
    /// añadiendo un término que solo puede valer cero, o peor, enumerando el contenedor de Grupos, que
    /// este fichero no toca a propósito (ADR §6).
    @Test("la sonda NO cuenta grupos, y la asimetría está explicada donde se lee el predicado")
    func probe_doesNotCountGroups() throws {
        let ruta = "Yala/Services/CloudSync/ICloudPersonalCorpusProbe.swift"
        #expect(!(try Self.code(ruta)).contains("CD_SplitGroup"), """
            apareció un conteo de grupos en la sonda del contenedor PERSONAL. Ahí no hay grupos: o el
            término vale cero siempre, o se está enumerando un contenedor que este fichero no debe
            tocar.
            """)
        // Y el docblock sigue ahí para explicarlo: sin él la siguiente persona lee un olvido. Esta
        // mitad se busca en el fichero SIN filtrar, que es donde viven los comentarios — y de paso es
        // el control positivo de `code()`: si el filtro no borrara nada, las dos mitades coincidirían
        // y este `#expect` sería inalcanzable.
        let conComentarios = try String(
            contentsOf: Self.repoRoot.appendingPathComponent(ruta), encoding: .utf8)
        #expect(conComentarios.contains("CD_SplitGroup"), """
            se borró la explicación de por qué la sonda no cuenta grupos. Sin ella la asimetría con
            `ICloudAccountSummary.hasAnyData` se lee como un descuido y se "arregla".
            """)
    }
}
