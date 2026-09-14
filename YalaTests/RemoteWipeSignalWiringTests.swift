//
//  RemoteWipeSignalWiringTests.swift
//  YalaTests
//
//  El CABLEADO del eje de sesión de la señal de vaciado remoto, en sus TRES superficies: los dos
//  extremos del canal —la detección, que encola, y el drenaje, que borra— y el AVISO que la gracia de
//  5 s le enseña a quien ve desaparecer sus filas. La tercera entró el 2026-09-14 y no borra nada: lo
//  que hace es AFIRMAR («tus datos fueron eliminados de iCloud») y ofrecer un botón que expulsa al
//  onboarding. Comparte eje con las otras dos porque comparte la pregunta —«¿los datos de este
//  teléfono son los del Apple ID?»— y el signo de su error: hacia `true` se daña, hacia `false` solo
//  se conserva o se calla.
//
//  **Por qué vive en su propio fichero y no junto a `RemoteWipeSignalDeciderTests`.** `-only-testing`
//  filtra por TIPO, no por fichero: una segunda `@Suite` en el mismo fichero NO se ejecuta cuando el
//  gate acota por el nombre de la primera, y no se nota — la corrida cuadra con las suites PEDIDAS
//  (`.claude/rules/testing.md`, «la segunda suite de un fichero suele ser justamente la de source-scan
//  del cableado»). Esta es exactamente esa suite, así que no puede ser la segunda de nadie.
//
//  **Por qué hace falta un source-scan.** El decisor es puro y la matriz de 16 combinaciones lo fija
//  entero, pero eso solo cubre el CUERPO de la función. Ninguno de los call-sites es invocable
//  (`checkForRemoteWipeSignal` es `private` de un singleton con `private init`, y
//  `handleRemoteWipeSignal` es `private` de una `View`), y hay cuatro mutaciones que dejan la matriz
//  verde con el bug del ticket vivo:
//    · pasar `true` literal, o leer `hasPrivateSession` en vez de `confirmedPrivateSession`
//      (con la marca PUESTA las dos lecturas coinciden ⇒ ningún test de comportamiento lo nota);
//    · dar un valor por defecto al parámetro, que devuelve a los call-sites futuros el derecho a no
//      pronunciarse — la forma exacta del bug que este ticket cierra;
//    · envolver el guard en `#if DEBUG`, con lo que la build de la App Store sale sin el eje.
//
//  (El aviso añade las suyas, y viven en su propio `@Test`: la LECTURA del eje movida por encima del
//  `sleep` —que la decidiría con el estado de cinco segundos antes—, cualquier cosa colada entre el
//  guard y el encendido, y un escritor nuevo del flag a través de su `@Binding`.)
//
//  Lo que este fichero NO puede dar es un test de COMPORTAMIENTO del camino que borra: eso pide hacer
//  `checkForRemoteWipeSignal` invocable con sus dos `UserDefaults`/iKV inyectados. Ticket
//  `remote-wipe-receiver-has-no-behaviour-test`.
//

import Foundation
import Testing

@testable import Yala

@Suite("La señal de vaciado · el eje de sesión, cableado en sus tres superficies")
struct RemoteWipeSignalWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // …/YalaTests
        .deletingLastPathComponent()   // raíz

    /// Texto normalizado: fuera los comentarios —**también los de cola**, que es lo que permite
    /// documentar un invariante sin romperlo— y los espacios colapsados a uno.
    private static func code(_ path: String) throws -> String {
        var raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        raw = raw.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// **La sentencia COMPLETA que empieza en `needle`**, hasta el siguiente `let ` o el cierre del
    /// bloque. Es lo que permite comparar por IGUALDAD en vez de por `contains`: un `contains` no puede
    /// cerrar el extremo derecho de una expresión, así que `… CloudSyncFlags.storageMode) || loQueSea`
    /// lo satisface — y con ese `||` el bug de este ticket vuelve, con la suite en verde.
    private static func sentencia(desde needle: String, en fuente: String) throws -> String {
        let inicio = try #require(fuente.range(of: needle), "no existe la sentencia que empieza por «\(needle)»")
        return sentencia(enRango: inicio, needle: needle, fuente: fuente)
    }

    /// **El corte es el delimitador MÁS CERCANO, no el primero de la lista que exista.** Con el `??`
    /// encadenado que tenía esto hasta el 2026-09-14, un ` let ` lejano ganaba a un ` } ` cercano y la
    /// sentencia se devolvía de más. Y el ` guard ` entró el mismo día: la lectura del eje que precede
    /// al aviso de la gracia va seguida de su propio `guard`, no de un `let`, así que sin él la
    /// sentencia arrastraba media línea de más y la comparación por igualdad fallaba por el motivo
    /// equivocado — un rojo que parece del cableado y es del instrumento.
    private static func sentencia(enRango inicio: Range<String.Index>, needle: String, fuente: String) -> String {
        let resto = fuente[inicio.lowerBound...]
        let cola = resto.dropFirst(needle.count)
        let corte = [" let ", " guard ", " }"]
            .compactMap { cola.range(of: $0)?.lowerBound }
            .min() ?? resto.endIndex
        return String(resto[resto.startIndex..<corte])
    }

    /// **TODAS las sentencias que empiezan por `needle`, no solo la primera.** `sentencia(desde:)` usa
    /// `range(of:)`, que devuelve la primera aparición — y desde el 2026-09-14 `ContentView` calcula el
    /// eje en DOS sitios (el drenaje y el aviso de la gracia). Medir solo la primera dejaba al drenaje
    /// sin red **en verde**, porque las dos sentencias son literalmente idénticas: el test habría
    /// seguido pasando midiendo la otra. Lo mismo pasaría con cualquier tercer call-site futuro.
    private static func sentencias(desde needle: String, en fuente: String) -> [String] {
        var encontradas: [String] = []
        var desde = fuente.startIndex
        while let r = fuente.range(of: needle, range: desde..<fuente.endIndex) {
            encontradas.append(sentencia(enRango: r, needle: needle, fuente: fuente))
            desde = r.upperBound
        }
        return encontradas
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// El conteo sobre TODO el target de producción, no sobre los ficheros que ya sé que están bien.
    /// Un call-site nuevo en un fichero que no mire es exactamente donde el `true` a mano se cuela, y
    /// medirlo solo en los dos conocidos lo habría dejado pasar en verde (la lección ya está escrita en
    /// `PrivateSessionMarkWiringTests`, y este fichero la heredaba mal en su primera versión).
    private static func countInProduction(_ needle: String) throws -> Int {
        let base = repoRoot.appendingPathComponent("Yala")
        let e = try #require(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
        var total = 0
        for case let url as URL in e where url.pathExtension == "swift" {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let sinComentarios = raw.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            total += count(needle, in: sinComentarios)
        }
        return total
    }

    private static func origenEsperado(defaultsArg: String) -> String {
        "let sessionObeysWipeSignal = DestructiveScopeLogic.wipeSignalObeyedByThisSession( "
            + "confirmedPrivateSession: PrivateSessionMark.confirmedPrivateSession(\(defaultsArg)), "
            + "storageMode: CloudSyncFlags.storageMode)"
    }

    // MARK: - Los dos extremos del canal

    /// Donde la señal se DETECTA: el único sitio de producción que pone el intent `.remoteWipe` en la
    /// cola, así que una sesión que no obedece ni siquiera lo encola.
    @Test("MUTACIÓN: la detección calcula el eje con la lectura estricta, y ese valor es el que pasa")
    func detectionWiresTheStrictReading() throws {
        try assertWiring(path: "Yala/App/Services/PreferenceSyncService.swift", defaultsArg: "local", lecturas: 1, daño: """
            una sesión en la nube vuelve a encolar el vaciado y sus borrados suben a SU cuenta
            """)
    }

    /// Y donde se DRENA: el único sitio que llama a `DataWipeService.wipeAllUserData` por una señal
    /// remota. Aquí el fallo es el borrado en sí.
    /// **`ContentView` tiene DOS lecturas del eje desde el 2026-09-14, y las dos se miden.** El drenaje
    /// —el que borra— y el aviso de la gracia de 5 s, que es el `@Test` de más abajo. Las dos calculan
    /// el valor con la misma sentencia literal, así que verificar solo la primera dejaba a la otra sin
    /// red sin que nada se pusiera rojo.
    @Test("MUTACIÓN: el drenaje calcula el eje con la lectura estricta, y ese valor es el que pasa")
    func drainWiresTheStrictReading() throws {
        try assertWiring(path: "Yala/App/ContentView.swift", defaultsArg: "", lecturas: 2, daño: """
            el teléfono se vacía aunque la detección lo hubiera frenado, o el aviso de datos borrados
            vuelve a salirle a quien tiene el móvil prestado
            """)
    }

    /// Las dos mitades van juntas y ninguna sola basta: la primera fija de dónde SALE el valor (la
    /// lectura estricta, con el `storageMode`, y sin nada colgado detrás); la segunda, que es ESE valor
    /// —y no un `true`, ni otra variable— el que llega al decisor.
    private func assertWiring(path: String, defaultsArg: String, lecturas: Int, daño: String) throws {
        let fuente = try Self.code(path)

        let origenes = Self.sentencias(desde: "let sessionObeysWipeSignal =", en: fuente)
        #expect(origenes.count == lecturas, """
            \(path) tiene \(origenes.count) lecturas del eje de sesión y se esperaban \(lecturas). Si
            añadiste una, cablea su sentencia igual que las otras y sube el número aquí; si desapareció
            una, comprueba que el camino que cubría no quedó sin eje.
            """)
        for origen in origenes {
            #expect(origen == Self.origenEsperado(defaultsArg: defaultsArg), """
                el eje de sesión ya no se calcula tal cual en \(path). Con `hasPrivateSession`, sin el
                `storageMode`, o con cualquier término extra colgado de la expresión, \(daño) — y toda la
                suite del decisor sigue verde, porque el cuerpo del decisor no ha cambiado.

                Esperado: \(Self.origenEsperado(defaultsArg: defaultsArg))
                Encontrado: \(origen)
                """)
        }

        // Y el paso, buscado DENTRO de la llamada al decisor y no en el fichero entero: `ContentView`
        // pasa de las 4.000 líneas y cualquier otra aparición de la etiqueta satisfaría un `contains`.
        let llamada = try Self.sentencia(desde: "RemoteWipeSignalDecider.decide(", en: fuente)
        #expect(llamada.contains("sessionObeysWipeSignal: sessionObeysWipeSignal"), """
            el eje se calcula pero el decisor recibe otra cosa en \(path). El cálculo correcto a la
            vista no protege de nada si no es el valor que llega: \(daño).

            Argumentos encontrados: \(llamada)
            """)
    }

    // MARK: - El tercer extremo: el AVISO, que no borra nada pero afirma

    /// **El aviso de «tus datos fueron eliminados de iCloud» no cuelga de la señal: cuelga de que las
    /// filas desaparezcan del store.** Ticket
    /// `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`. Quien llega ahí en producción **no
    /// es** el caso que da nombre al ticket —un solo-grupos de hoy monta sin espejo, y uno anterior al
    /// 2026-09-10 recibe `hasPrivateSession = true` del backfill— sino el aviso AUTO-INFLIGIDO tras
    /// «Vaciar datos» en solo-grupos: ese camino no cancela la gracia y `applyWipeLanding(.groupsShell)`
    /// repone `hasCompletedOnboarding`, así que a quien acaba de vaciar sus propios datos le saltaba a los
    /// cinco segundos un aviso diciendo que se los borraron desde otro dispositivo.
    ///
    /// **Por qué un escáner y no un test de comportamiento.** El `onChange` vive en el `body` de una
    /// `View` y no es invocable, y no hay seam de uitest que haga desaparecer las filas del store bajo el
    /// proceso vivo. Es el mismo hueco que ya registra `remote-wipe-receiver-has-no-behaviour-test`.
    ///
    /// **Se fija el TRAMO ENTERO, y esa es la corrección que trajo la review (2026-09-14).** La primera
    /// versión solo fijaba que el `guard` fuera pegado al encendido, y con eso **el mutante que este test
    /// dice cazar sobrevivía en verde**: mover la LECTURA del eje a antes del `sleep` —dejando cualquier
    /// otro `let` detrás— pasaba las cuatro aserciones con el eje decidido cinco segundos antes. El
    /// mutante que se probó a mano cayó por accidente, porque arrastró el `sleep` a la sentencia medida;
    /// con una línea intermedia habría pasado. El estado rancio lo produce mover el `let`, no el `guard`,
    /// así que lo que hay que fijar es el ORDEN COMPLETO: dormir → leer → decidir → encender.
    ///
    /// Que el literal incluya los `.seconds(5)` es deliberado: cambiar el debounce obliga a pasar por
    /// aquí, que es donde está escrito por qué el eje se lee después y no antes.
    @Test("MUTACIÓN: dormir → leer el eje → decidir → encender, sin nada entre medias y en un solo sitio")
    func theAlertIsGatedByTheAxisAtItsOnlyWriter() throws {
        let vista = try Self.code("Yala/App/ContentView.swift")

        let tramo = "try await Task.sleep(for: .seconds(5)) "
            + Self.origenEsperado(defaultsArg: "")
            + " guard sessionObeysWipeSignal else { return } showRemoteWipeAlert = true"
        #expect(Self.count(tramo, in: vista) == 1, """
            el tramo de la gracia de vaciado remoto cambió de forma. Los cuatro pasos van SEGUIDOS y en
            este orden: dormir los 5 s, leer el eje, decidir, encender. Si la lectura sube por encima del
            `sleep`, el eje se evalúa con el estado de cinco segundos antes; si entra cualquier cosa entre
            el `guard` y el encendido, aparece una rama que enciende sin pasar por el eje. En los dos
            casos vuelve el bug: a quien acaba de vaciar sus datos en una sesión solo-grupos le salta
            «Tus datos fueron eliminados de iCloud», y su botón lo manda al onboarding por el camino
            genérico de degradación.

            Esperado exactamente: \(tramo)
            """)

        // Y que ese sea el ÚNICO escritor. **Se cuenta la ASIGNACIÓN, no el literal `= true`**: el flag
        // viaja como `@Binding` a `ShellDataAlertsModifier`, así que un `= loQueSea` o un `.toggle()`
        // desde allí lo encendería sin eje y sin tocar ninguna de las dos líneas de arriba.
        #expect(try Self.countInProduction("showRemoteWipeAlert = ") == 2, """
            las asignaciones al flag del aviso de vaciado remoto cambiaron de número en `Yala/`. Son DOS:
            la que lo enciende tras la gracia (con el eje delante) y la que lo apaga en el drenaje. Si
            aparece una tercera, ponle el mismo eje: el aviso afirma que los datos borrados son los del
            Apple ID de este teléfono, y eso solo es cierto en una sesión privada con su iCloud detrás.
            """)
        #expect(try Self.countInProduction("showRemoteWipeAlert.toggle()") == 0, """
            alguien enciende el aviso con `toggle()`, que se salta el eje y además lo APAGA cuando ya
            estaba puesto.
            """)

        // Control del instrumento, y éste sí puede fallar solo: si el recorrido del árbol se rompiera o
        // el flag se renombrara, las dos cuentas de arriba darían 0 por el motivo equivocado. Un `>=`
        // holgado no servía —el flag sale 20 veces en `Yala/`, así que ningún mutante lo movía.
        #expect(try Self.countInProduction("@State private var showRemoteWipeAlert") == 1,
                "el flag del aviso no está declarado exactamente una vez: el escáner mide otra cosa")
    }

    // MARK: - Lo que vive FUERA del cuerpo del decisor

    /// **El parámetro del eje no puede tener valor por defecto.** Es la mutación más barata que reabre
    /// el bug entero: con `= true` los 16 casos de la matriz siguen verdes —los pasan explícitos— y un
    /// call-site nuevo vuelve a obedecer la señal sin haberse pronunciado, que es literalmente la forma
    /// del bug que este ticket cierra. Y el `#if` es su gemelo: dejaría el eje fuera de la build de
    /// Release mientras el target de tests, que compila DEBUG, no nota nada.
    @Test("MUTACIÓN: el eje no tiene default en la firma ni vive bajo una configuración de build")
    func theAxisParameterHasNoDefaultAndNoBuildGate() throws {
        let decisor = try Self.code("Yala/App/Logic/RemoteWipeSignalDecider.swift")

        #expect(decisor.contains("sessionObeysWipeSignal: Bool )")
                || decisor.contains("sessionObeysWipeSignal: Bool ) ->"), """
            la firma de `decide` cambió. Si le pusiste un valor por defecto a `sessionObeysWipeSignal`,
            deshazlo: el compilador dejaría de obligar a cada call-site a decidir, y ese permiso es el
            bug que este parámetro existe para cerrar.
            """)

        #expect(!decisor.contains("#if"), """
            apareció una configuración de build en el decisor. El target de tests compila DEBUG, así que
            un guard bajo `#if DEBUG` pasa los 16 casos de la matriz y sale de la App Store sin el eje
            de sesión.
            """)

        // Y el guard sigue ahí, con su forma. Control de que los dos `#expect` de arriba no están
        // midiendo un fichero que ya no contiene lo que creen.
        #expect(Self.count("if !sessionObeysWipeSignal {", in: decisor) == 1,
                "el guard del eje de sesión desapareció o se duplicó en el decisor")
    }

    /// El decisor tiene DOS consumidores **en todo `Yala/`**. El compilador ya obliga a pasar el
    /// parámetro; lo que no puede obligar es a pasar el valor correcto, y un tercer call-site con un
    /// `true` a mano es donde eso se cuela.
    @Test("MUTACIÓN: el decisor sigue teniendo exactamente dos consumidores en producción")
    func theDeciderHasExactlyTwoConsumersInProduction() throws {
        #expect(try Self.countInProduction("RemoteWipeSignalDecider.decide(") == 2, """
            los consumidores del decisor cambiaron de número en `Yala/`. Si hay uno nuevo, cablea su eje
            como los otros dos y añádelo a `assertWiring`; si desapareció uno, comprueba que el camino
            que cubría no quedó sin eje.
            """)
        // Control del instrumento: si el recorrido del árbol se rompiera, el conteo daría 0 y la
        // aserción de arriba fallaría por el motivo equivocado. Este needle no puede estar en cero.
        #expect(try Self.countInProduction("RemoteWipeSignalDecider") >= 3,
                "el escáner de producción no encuentra el decisor: el recorrido del árbol está roto")
    }

    /// **La premisa de la que depende que el caso «no obedece» no marque nada.** El decisor devuelve
    /// `shouldMarkSignalsAsProcessed: false` ahí porque quien DETECTA la señal ya escribió
    /// `WipeKey.localWipe`, y esa escritura tiene que ser **incondicional**: dentro de un `if`, el caso
    /// mid-wipe dejaría de consumirla y la premisa se caería sin que nada lo dijera.
    @Test("MUTACIÓN: la señal se consume donde se detecta, incondicionalmente y antes de decidir")
    func theSignalIsConsumedWhereItIsDetected() throws {
        let servicio = try Self.code("Yala/App/Services/PreferenceSyncService.swift")

        // La sentencia ENTERA, no un `contains`: así un `if …  { local.set(…) }` no la satisface,
        // porque la sentencia empezaría por el `if` y no por la escritura.
        let consumo = try Self.sentencia(desde: "if remoteWipe > 0 && remoteWipe > localWipe {", en: servicio)
        #expect(consumo.hasPrefix("if remoteWipe > 0 && remoteWipe > localWipe { local.set(remoteWipe, forKey: WipeKey.localWipe)"), """
            la detección ya no consume la señal como PRIMERA cosa e incondicionalmente. Si la escritura
            de `WipeKey.localWipe` quedó bajo una condición o después de la decisión, una sesión que no
            obedece re-encola el vaciado en cada arranque y en cada pull-to-refresh del Panel — y el
            decisor no marca nada en ese caso precisamente porque esta línea ya lo hacía.

            Encontrado: \(consumo.prefix(200))
            """)

        #expect(try Self.countInProduction("RouterEntryGate.shared.submit(.remoteWipe(") == 1, """
            el intent `.remoteWipe` se emite desde más de un sitio (o desde ninguno) en `Yala/`.
            Comprueba que el emisor nuevo consulta el eje de sesión y consume la señal antes de encolar.
            """)
    }
}
