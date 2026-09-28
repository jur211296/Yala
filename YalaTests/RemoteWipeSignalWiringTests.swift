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
    /// **`ContentView` tiene TRES lecturas del eje desde el 2026-09-14, y las tres se miden.** El
    /// drenaje —el que borra—, la gracia de 5 s (que decide si PIDE el aviso) y el drenaje de ese aviso
    /// (que decide si todavía es verdad cuando toca enseñarlo). Las tres calculan el valor con la misma
    /// sentencia literal, así que verificar solo la primera dejaba a las otras sin red sin que nada se
    /// pusiera rojo.
    @Test("MUTACIÓN: el drenaje calcula el eje con la lectura estricta, y ese valor es el que pasa")
    func drainWiresTheStrictReading() throws {
        try assertWiring(path: "Yala/App/ContentView.swift", defaultsArg: "", lecturas: 3, daño: """
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
    /// así que lo que hay que fijar es el ORDEN COMPLETO: dormir → leer → decidir → pedir.
    ///
    /// Que el literal incluya los `.seconds(5)` es deliberado: cambiar el debounce obliga a pasar por
    /// aquí, que es donde está escrito por qué el eje se lee después y no antes.
    ///
    /// **El cuarto paso dejó de ENCENDER y pasó a PEDIR el 2026-09-14** (`remote-wipe-alert-skips-the-
    /// router`): este productor es una tarea de fondo, así que su aviso viaja por la cola del router y
    /// lo enciende el drenaje, con el anchor libre. Los dos extremos tienen su escáner —éste y el de
    /// más abajo— porque el eje se mide en los dos: aquí decide si el aviso llega a pedirse, y allí si
    /// sigue siendo verdad cuando toca enseñarlo.
    @Test("MUTACIÓN: dormir → leer el eje → decidir → PEDIR el aviso, sin nada entre medias y en un solo sitio")
    func theNoticeIsGatedByTheAxisAtItsOnlyProducer() throws {
        let vista = try Self.code("Yala/App/ContentView.swift")

        let tramo = "try await Task.sleep(for: .seconds(5)) "
            + Self.origenEsperado(defaultsArg: "")
            + " guard sessionObeysWipeSignal else { return } "
            + "RouterEntryGate.shared.submit(.presentRemoteWipeNotice)"
        #expect(Self.count(tramo, in: vista) == 1, """
            el tramo de la gracia de vaciado remoto cambió de forma. Los cuatro pasos van SEGUIDOS y en
            este orden: dormir los 5 s, leer el eje, decidir, pedir el aviso. Si la lectura sube por
            encima del `sleep`, el eje se evalúa con el estado de cinco segundos antes; si entra
            cualquier cosa entre el `guard` y la petición, aparece una rama que pide sin pasar por el
            eje. En los dos casos vuelve el bug: a quien acaba de vaciar sus datos en una sesión
            solo-grupos le salta «Tus datos fueron eliminados de iCloud».

            Y si lo que cambió es que el aviso vuelve a encenderse AQUÍ —un `showRemoteWipeAlert = true`
            en lugar del `submit`— el que vuelve es el otro bug, el de este ticket: encender un `.alert`
            desde esta tarea de fondo desmonta lo que el anchor tuviera presentado, y si no llega a
            montar deja la matriz de readiness bloqueada el resto de la sesión.

            Esperado exactamente: \(tramo)
            """)

        // **DOS y no una, y las dos están nombradas**: la de arriba —el único productor de producción— y
        // el seam de uitest de `AppBootstrapper`, que encola el intent bajo `UITestHooks` para poder
        // probar la presentación (el productor real no es ejercitable: no hay forma de hacer desaparecer
        // las filas del store bajo el proceso vivo). Un TERCER `submit` sube la cuenta y pone esto rojo,
        // que es lo que se quiere: al que venga, ponle el mismo eje delante.
        #expect(try Self.countInProduction("RouterEntryGate.shared.submit(.presentRemoteWipeNotice)") == 2, """
            el aviso de vaciado remoto se pide desde un número inesperado de sitios en `Yala/`. Son dos:
            la gracia de `ContentView` (con el eje delante) y el seam de uitest de `AppBootstrapper`. Si
            hay un productor nuevo, ponle el mismo eje: el aviso afirma que los datos borrados son los
            del Apple ID de este teléfono, y eso solo es cierto en una sesión privada con su iCloud
            detrás.
            """)
        #expect(Self.count("RouterEntryGate.shared.submit(.presentRemoteWipeNotice)", in: vista) == 1,
                "el productor de producción del aviso dejó de ser único dentro de `ContentView`")
        let seam = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(seam.contains("if UITestHooks.showRemoteWipeNotice { "
                              + "RouterEntryGate.shared.submit(.presentRemoteWipeNotice) }"), """
            el seam de uitest del aviso perdió su guard: encolar el intent fuera de `-uitest` le enseña a
            producción un aviso que nadie pidió.
            """)

        #expect(try Self.countInProduction("showRemoteWipeAlert.toggle()") == 0, """
            alguien enciende el aviso con `toggle()`, que se salta el eje y además lo APAGA cuando ya
            estaba puesto.
            """)

        // **El censo de escritores del flag, que se perdió al reescribir esta suite y lo cazó la review
        // (2026-09-14).** Antes eran DOS y el número los fijaba a los dos; con la red de presentación
        // toggleando son SIETE, y sin este conteo un productor nuevo que vuelva a encender el `@State`
        // a pelo —el bug exacto que este ticket cierra— no pondría rojo nada: los otros escáneres
        // cuentan el `submit` y la condición viva, que un bypass directo no toca.
        //
        // Los siete, y por qué: el drenaje lo enciende (1); la red lo apaga y lo re-enciende en el
        // reintento (2); el desarme del cap lo apaga (1); y lo apagan las tres salidas —«Empezar de
        // cero», «Ahora no» y la llegada de la señal explícita— (3).
        #expect(try Self.countInProduction("showRemoteWipeAlert = ") == 7, """
            las asignaciones al flag del aviso cambiaron de número en `Yala/`. Si añadiste un escritor,
            pregúntate primero si debería ser un `submit(.presentRemoteWipeNotice)`: quien enciende este
            aviso desde fuera del drenaje se salta la matriz de readiness y desmonta lo que el anchor
            tuviera presentado, que es el bug que este ticket cierra. Si de verdad hace falta, súbelo
            aquí explicando cuál es.
            """)

        // Control del instrumento, y éste sí puede fallar solo: si el recorrido del árbol se rompiera o
        // el flag se renombrara, las cuentas de arriba darían 0 por el motivo equivocado.
        #expect(try Self.countInProduction("@State private var showRemoteWipeAlert") == 1,
                "el flag del aviso no está declarado exactamente una vez: el escáner mide otra cosa")
    }

    /// **El drenaje del aviso RE-MIDE las tres condiciones vivas antes de enseñarlo.** El intent no es
    /// transitorio: puede esperar en cola bajo un cover a través de un background entero, y el aviso
    /// afirma un hecho sobre AHORA. Las tres son las que lo hacen verdadero —las filas siguen sin estar,
    /// el onboarding sigue completo, la sesión sigue siendo de las que obedecen la señal— y el orden
    /// importa tanto como en el productor: cualquier cosa entre el último `guard` y el encendido abre
    /// una rama que enseña sin haber medido.
    ///
    /// **Y el encendido de la CONDICIÓN VIVA es único.** El `@State` del alert se enciende dos veces (el
    /// drenaje y el re-toggle de la red de presentación, que es lo que lo re-presenta cuando UIKit no
    /// llegó a montarlo); `remoteWipeNoticePending` no: quien retiene al router se enciende en un solo
    /// sitio y con las tres mediciones delante.
    @Test("MUTACIÓN: el drenaje del aviso re-mide las tres condiciones vivas antes de encenderlo")
    func theNoticeDrainRemeasuresBeforePresenting() throws {
        let vista = try Self.code("Yala/App/ContentView.swift")

        let tramo = "guard !hasPersonalData else { return } "
            + "guard hasCompletedOnboarding else { return } "
            + Self.origenEsperado(defaultsArg: "")
            + " guard sessionObeysWipeSignal else { return } "
            + "remoteWipeNoticePending = true showRemoteWipeAlert = true "
            + "armRemoteWipeNoticePresentationNet()"
        #expect(Self.count(tramo, in: vista) == 1, """
            el drenaje del aviso de vaciado remoto cambió de forma. Se mide TODO el tramo, no solo que
            los guards existan: si uno se mueve por debajo del encendido, o si entra algo entre el
            último `guard` y las dos asignaciones, el aviso puede salir sobre unos datos que ya
            volvieron, sobre alguien a quien otro camino acaba de mandar al Welcome, o en una sesión que
            no guarda sus datos en el iCloud de este Apple ID.

            Y si lo que falta es `armRemoteWipeNoticePresentationNet()`, lo que se pierde es la red del
            criterio 3: nadie comprobaría que UIKit presentó de verdad, y un aviso que no monta deja el
            router retenido hasta que se mata la app.

            Esperado exactamente: \(tramo)
            """)

        #expect(try Self.countInProduction("remoteWipeNoticePending = true") == 1, """
            la condición viva del aviso se enciende desde más de un sitio en `Yala/`. Es la que retiene
            al router: un encendido sin las tres re-mediciones delante puede dejar la matriz bloqueada
            por un aviso que ya no es verdad.
            """)

        #expect(try Self.countInProduction("@State private var remoteWipeNoticePending") == 1,
                "la condición viva del aviso no está declarada exactamente una vez: el escáner mide otra cosa")
    }

    /// **La matriz de readiness cuelga de la CONDICIÓN VIVA, nunca del `@State` del alert.** Es la regla
    /// (4) de Presentaciones para blockers, y aquí es load-bearing: la red de presentación apaga y
    /// vuelve a encender `showRemoteWipeAlert` para re-presentar, así que una matriz colgada de ese flag
    /// se abriría en cada reintento y el router drenaría lo siguiente justo debajo del aviso.
    ///
    /// **Y el desarme del cap tiene que apagar la condición viva**, que es lo que cierra el brick: nueve
    /// segundos sin conseguir presentar significan que algo tapa el anchor para siempre, y quedarse
    /// retenido cuesta la sesión entera.
    @Test("MUTACIÓN: el blocker es la condición viva, y el cap de la red la suelta")
    func theBlockerIsTheLiveConditionAndTheNetReleasesIt() throws {
        #expect(try Self.countInProduction("showRemoteWipeAlert: remoteWipeNoticePending") == 2, """
            la matriz de readiness ya no cuelga de la condición viva del aviso en sus DOS sitios (el
            observador que dispara el recálculo y el snapshot que entra a la lógica pura). Si volvió a
            colgar del `@State` del alert, cada reintento de la red de presentación abre la matriz
            durante el toggle y el router monta otra cosa debajo del aviso.
            """)
        // Acotado a `ContentView`, que es quien alimenta la matriz. Las otras dos apariciones del árbol
        // —`ContentViewReadinessLogic.withWelcomeChainCleared` y el struct interno de
        // `ReadinessGateObservers`— propagan el CAMPO del snapshot, que sigue llamándose así, y contarlas
        // aquí mediría otra cosa.
        let vista = try Self.code("Yala/App/ContentView.swift")
        #expect(Self.count("showRemoteWipeAlert: showRemoteWipeAlert", in: vista) == 0, """
            alguien volvió a pasar el `@State` del alert a la matriz de readiness. Ese flag es la red
            VISUAL; el blocker es `remoteWipeNoticePending`.
            """)
        let desarme = "case .exhausted: remoteWipeNoticePending = false showRemoteWipeAlert = false "
            + "MetricsService.canary(.remoteWipeNoticeNotPresented) return"
        #expect(Self.count(desarme, in: vista) == 1, """
            el desarme de la red de presentación cambió de forma. Al agotarse el cap del ciclo tiene que
            soltar la condición viva —o el router se queda retenido el resto de la sesión, que es
            exactamente el brick que este ticket cierra— y dejar el canario, que es lo único que dice
            desde producción que un aviso no llegó a presentarse.

            Esperado exactamente: \(desarme)
            """)
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

    // MARK: - Lo que BORRA el receptor

    /// **El receptor borra con el borrado que corta por la hora de la señal, y con ninguno más** (tickets
    /// `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged` y `late-remote-wipe-signal-also-wipes-rows-created-
    /// after-it`). Lo que hace ese borrado —llevarse solo lo que existía al vaciar, sin re-emitir la señal— lo fijan
    /// `RemoteWipeCutBehaviourTests`. Lo que no pueden ver es que `performLocalWipeForRemoteSync`, que es `private` de una
    /// `View`, lo llame con la hora de ESTA señal y con «alguien terminó el onboarding después»: volver a `wipeAllUserData`
    /// a pelo deja esos casos en verde y reabre el bug —un dispositivo que procesa la señal tarde se lleva lo que el
    /// origen apuntó después de vaciar, y su borrado viaja al origen—.
    @Test("MUTACIÓN: el receptor de la señal borra por `wipeLocallyForRemoteWipeSignal`, con la hora de esa señal")
    func theReceiverWipesThroughTheCutWipe() throws {
        // Los nombres se parten del paréntesis a propósito: `SharedStateIsolationTests` cuenta como «ejecuta el wipe» todo
        // fichero de test cuyo código contenga `<borrado>(`, y este solo los BUSCA en el código de producción.
        let receptor = "wipeLocallyForRemoteWipeSignal", abre = "("
        let vista = try Self.code("Yala/App/ContentView.swift")
        let inicio = try #require(vista.range(of: "private func performLocalWipeForRemoteSync("),
                                  "no existe el receptor de la señal: el escáner mide otra cosa")
        let resto = vista[inicio.upperBound...]
        let fin = try #require(resto.range(of: " private "), "no se encuentra el final del receptor")
        let cuerpo = String(resto[resto.startIndex..<fin.lowerBound])

        #expect(Self.count("try DataWipeService." + receptor + abre + "in: modelContext, signaledAt: signaledAt, "
                           + "fleetStartedOver: skipOnboarding)", in: cuerpo) == 1, """
            el receptor de la señal de vaciado ya no borra por `wipeLocallyForRemoteWipeSignal`, o no le pasa si el parque \
            ya empezó de nuevo. Sin el corte se lleva lo que otro dispositivo apuntó después de vaciar, y ese borrado \
            viaja al origen.

            Cuerpo encontrado: \(cuerpo.prefix(400))
            """)
        #expect(!cuerpo.contains("wipeAllUserData" + abre) && !cuerpo.contains("wipePersonalDataKeepingGroups" + abre), """
            el receptor llama además a otro borrado. Los dos borran sin corte: se llevarían lo creado después de la señal.
            """)
        #expect(!cuerpo.contains("signalWipeInitiated"), """
            el receptor emite una señal de vaciado propia: rebotaría el vaciado entre los dispositivos del Apple ID.
            """)
        // Y la hora del corte es la de ESTA señal: la que lee el drenaje del KV, no otra.
        #expect(Self.count("performLocalWipeForRemoteSync(skipOnboarding: onboardingAlreadyDone, "
                           + "signaledAt: Date(timeIntervalSince1970: remoteWipe))", in: vista) == 1, """
            el receptor ya no recibe la hora de la señal que está procesando. Con otra hora corta mal: o se lleva lo que \
            el origen apuntó después de vaciar, o deja lo que había antes.
            """)
        #expect(try Self.countInProduction(receptor + abre) == 2, """
            el borrado del receptor tiene un número inesperado de apariciones en `Yala/` (se esperan la definición y la
            llamada de `ContentView`). Si otro camino borra por él, comprueba que de verdad responde a una señal: no
            re-emite la suya.
            """)
    }

    // MARK: - Quien repone lo que un receptor sin grupos declaró

    /// **El arranque atiende las declaraciones de vaciado tardío, y en su sitio** (ticket
    /// `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows`). Los casos de comportamiento llaman a
    /// `returnIfDeclared` a mano; lo que no ven es que `retryPendingBridges` lo llame, ni dónde. Sin la llamada, el receptor
    /// sin grupos declara y nadie repone: el bug entero, en verde. Detrás del store listo (un `save()` durante el import es
    /// el SIGTRAP de la quiescencia), del dominio abierto y DESPUÉS de la convergencia: lo que ella repone ya está presente
    /// y no se vuelve a pedir.
    @Test("MUTACIÓN: el arranque atiende las declaraciones tras la convergencia, detrás de sus gates")
    func theBootReturnsDeclaredRowsAfterTheConvergence() throws {
        let llamada = "GroupsRemoteWipeReturn.returnIfDeclared(context: context)"
        #expect(try Self.countInProduction(llamada) == 1, "el arranque ya no atiende las declaraciones, o las atiende dos veces")
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let inicio = try #require(boot.range(of: "func retryPendingBridges(context: ModelContext) async {"))
        let cuerpo = boot[inicio.upperBound...]
        let atiende = try #require(cuerpo.range(of: llamada), "retryPendingBridges no atiende las declaraciones")
        for antes in ["guard await awaitPersonalStoreReady() else", "guard GroupTransactionBridge.isDomainOpenForBridge() else",
                      "GroupsBridgeRestoreConvergence.convergeIfPending(context: context)"] {
            let r = try #require(cuerpo.range(of: antes), "no existe «\(antes)» en retryPendingBridges")
            #expect(r.upperBound <= atiende.lowerBound, "las declaraciones se atienden antes de «\(antes)»")
        }

        let fuente = try Self.code("Yala/Services/Groups/GroupsRemoteWipeReturn.swift")
        let funcion = try #require(fuente.range(of: "static func returnIfDeclared("))
        let resto = fuente[funcion.upperBound...]
        let escribe = try #require(resto.range(of: "bridgeRemoteExpenses(ids:"))
        for guarda in ["guard SessionState.shared.hasPrivateSession, obeysWipeSignal else { return }",
                       "guard GroupTransactionBridge.isDomainOpenForBridge(defaults: defaults) else { return }"] {
            let r = try #require(resto.range(of: guarda), "returnIfDeclared perdió «\(guarda)»")
            #expect(r.upperBound <= escribe.lowerBound, """
                returnIfDeclared re-puentea antes de «\(guarda)»: en solo-grupos el bridge borra las transacciones reales \
                que re-puentea, y con el dominio cerrado no se toca nada
                """)
        }
    }

    /// **El arranque poda los borradores de liquidación que otro dispositivo creó antes de ver la marca de aprobación**
    /// (ticket `settlement-approval-leaves-no-trace-so-a-rebridge-asks-again`). Sin la llamada, el Inbox vuelve a preguntar
    /// por un pago ya registrado. Detrás de los mismos gates y DESPUÉS de la devolución: lo que ella re-puentea ya sustituye
    /// sus pendientes, y un `save()` durante el import es el SIGTRAP de la quiescencia.
    @Test("MUTACIÓN: el arranque poda los borradores de una liquidación ya resuelta, tras la devolución y sus gates")
    func theBootPrunesSettlementDraftsAlreadyResolved() throws {
        let llamada = "GroupTransactionBridge.pruneSettlementDraftsAlreadyResolved(context: context)"
        #expect(try Self.countInProduction(llamada) == 1, "el arranque ya no poda los borradores, o los poda dos veces")
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let inicio = try #require(boot.range(of: "func retryPendingBridges(context: ModelContext) async {"))
        let cuerpo = boot[inicio.upperBound...]
        let poda = try #require(cuerpo.range(of: llamada), "retryPendingBridges no poda los borradores")
        for antes in ["guard await awaitPersonalStoreReady() else", "guard GroupTransactionBridge.isDomainOpenForBridge() else",
                      "GroupsRemoteWipeReturn.returnIfDeclared(context: context)"] {
            let r = try #require(cuerpo.range(of: antes), "no existe «\(antes)» en retryPendingBridges")
            #expect(r.upperBound <= poda.lowerBound, "la poda corre antes de «\(antes)»")
        }
    }

    /// **El receptor pide la convergencia ANTES de borrar, borra con el corte y no declara** (tickets
    /// `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged` y `late-remote-wipe-signal-also-wipes-rows-
    /// created-after-it`). Pedir después dejaría que un corte entre las dos cosas perdiera la petición; declarar ya no
    /// tiene nada que declarar, porque lo posterior a la señal se queda. Los casos de comportamiento lo ven con sus
    /// fixtures; este scan ve el orden en la función entera.
    @Test("MUTACIÓN: el receptor pide antes de borrar, borra con el corte y no declara")
    func theReceiverAsksBeforeWiping_withTheCut_andDoesNotDeclare() throws {
        let abre = "("
        let fuente = try Self.code("Yala/Utils/DataWipeService.swift")
        let inicio = try #require(fuente.range(of: "static func wipeLocallyForRemoteWipeSignal" + abre))
        let resto = fuente[inicio.upperBound...]
        let fin = try #require(resto.range(of: "static func rescheduleSurvivingReminders"), "no se encuentra el final")
        let cuerpo = String(resto[resto.startIndex..<fin.lowerBound])
        let pide = try #require(cuerpo.range(of: "GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults) "
                                             + "GroupsBridgeRestoreConvergenceStore.markPending(defaults)"),
                                "el receptor ya no pide la convergencia, o no pide las liquidaciones antes que los gastos")
        let borra = try #require(cuerpo.range(of: "try wipeAllUserData" + abre + "in: context, reseedInitialData: false, "
                                              + "broadcastSignal: false, remoteWipeCut: cut) "
                                              + "if cut != nil { rescheduleReminders(context) }"),
                                 "el receptor ya no borra con el corte de la señal, o no reprograma los avisos")
        #expect(pide.upperBound <= borra.lowerBound, "el receptor pide después de borrar: un corte en medio pierde la petición")
        #expect(Self.count("let cut = RemoteWipeCutLogic.cut(signaledAt: signaledAt, fleetStartedOver: fleetStartedOver)",
                           in: cuerpo) == 1, "el corte ya no sale de la hora de ESTA señal")
        for prohibido in ["GroupsRemoteWipeReturn.declare" + abre, "wipePersonalDataKeepingGroups" + abre,
                          "signalWipeInitiated"] {
            #expect(!cuerpo.contains(prohibido), "el receptor volvió a llamar a «\(prohibido)»")
        }
    }

    // MARK: - El reparto del origen (ticket `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere`)

    /// **«Vaciar datos» escribe el reparto ANTES de la señal y con su MISMA hora, y solo si avisa al parque.** Los casos de
    /// comportamiento llaman a `declare` a mano (la señal real escribiría en el iCloud-KV del simulador), así que solo este
    /// scan ve que el vaciado lo llame. Sin la llamada el receptor espera 30 días y lo suelta: el bug entero, en verde. Con
    /// otra hora, el receptor no reconoce el reparto de su señal. Después de la señal, un fallo en medio la dejaría sin él.
    @Test("MUTACIÓN: «Vaciar datos» escribe el reparto antes de la señal, con su misma hora")
    func emptyMyDataDeclaresTheDivisionBeforeTheSignal() throws {
        let abre = "("
        let fuente = try Self.code("Yala/Utils/DataWipeService.swift")
        let inicio = try #require(fuente.range(of: "static func wipePersonalDataKeepingGroups" + abre))
        let resto = fuente[inicio.upperBound...]
        let fin = try #require(resto.range(of: "static func wipeLocallyForRemoteWipeSignal"), "no se encuentra el final")
        let cuerpo = String(resto[resto.startIndex..<fin.lowerBound])
        let reparte = try #require(cuerpo.range(of: "let signalTimestamp = Date.now if broadcastSignal { "
                                                + "GroupsRemoteWipeDivision.declare" + abre + " context: context, "
                                                + "signaledAt: signalTimestamp, kv: divisionStore, domainOpen: "
                                                + "GroupTransactionBridge.isDomainOpenForBridge(defaults: defaults)) }"), """
            «Vaciar datos» ya no escribe el reparto, lo escribe sin avisar al parque o con otra hora que la de la señal.             Cuerpo encontrado: \(cuerpo.prefix(600))
            """)
        let borra = try #require(cuerpo.range(of: "try wipeAllUserData" + abre + "in: context, reseedInitialData: false, "
                                              + "broadcastSignal: broadcastSignal, signalTimestamp: signalTimestamp)"),
                                 "el vaciado ya no emite la señal con la hora del reparto")
        #expect(reparte.upperBound <= borra.lowerBound, "el reparto se escribe después de la señal y del borrado")
        #expect(fuente.contains("PreferenceSyncService.shared.signalWipeInitiated(at: signalTimestamp ?? .now)"),
                "la señal ya no sale con la hora que le pasa el vaciado")
        let prefs = try Self.code("Yala/App/Services/PreferenceSyncService.swift")
        #expect(prefs.contains("func signalWipeInitiated(at date: Date = .now) { let timestamp = date.timeIntervalSince1970"),
                "la señal ya no escribe la hora que recibe")
        #expect(try Self.countInProduction("GroupsRemoteWipeDivision.declare" + abre) == 1,
                "el reparto se escribe desde más de un sitio, o desde ninguno")
    }

    /// **El receptor del orden normal apunta que espera el reparto, antes de borrar; el tardío no.** Los casos de
    /// comportamiento lo ven con sus fixtures; este scan ve la rama y el orden en la función entera.
    @Test("MUTACIÓN: el receptor del orden normal espera el reparto antes de borrar")
    func theNormalOrderReceiverAwaitsTheDivisionBeforeWiping() throws {
        let abre = "("
        let fuente = try Self.code("Yala/Utils/DataWipeService.swift")
        let inicio = try #require(fuente.range(of: "static func wipeLocallyForRemoteWipeSignal" + abre))
        let resto = fuente[inicio.upperBound...]
        let fin = try #require(resto.range(of: "static func rescheduleSurvivingReminders"), "no se encuentra el final")
        let cuerpo = String(resto[resto.startIndex..<fin.lowerBound])
        let espera = try #require(cuerpo.range(of: "GroupsBridgeRestoreConvergenceStore.markPending(defaults) } else { "
                                              + "GroupsRemoteWipeDivision.awaitOrigin" + abre
                                              + "signaledAt: cut.signaledAt, defaults: defaults) }"),
                                  "el receptor del orden normal ya no espera el reparto del origen, o lo espera también en el tardío")
        let borra = try #require(cuerpo.range(of: "try wipeAllUserData" + abre))
        #expect(espera.upperBound <= borra.lowerBound, "el receptor apunta la espera después de borrar: un corte la pierde")
    }

    /// **El arranque resuelve el reparto justo antes de la convergencia, detrás de sus gates.** Sin la llamada, el receptor
    /// espera y nadie pide: el bug entero. Después de la convergencia, la petición esperaría otro arranque en frío.
    @Test("MUTACIÓN: el arranque resuelve el reparto antes de la convergencia, detrás de sus gates")
    func theBootResolvesTheDivisionBeforeTheConvergence() throws {
        let llamada = "GroupsRemoteWipeDivision.resolveIfArrived()"
        #expect(try Self.countInProduction(llamada) == 1, "el arranque ya no resuelve el reparto, o lo resuelve dos veces")
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let inicio = try #require(boot.range(of: "func retryPendingBridges(context: ModelContext) async {"))
        let cuerpo = boot[inicio.upperBound...]
        let resuelve = try #require(cuerpo.range(of: llamada), "retryPendingBridges no resuelve el reparto")
        for antes in ["guard await awaitPersonalStoreReady() else", "guard GroupTransactionBridge.isDomainOpenForBridge() else"] {
            let r = try #require(cuerpo.range(of: antes), "no existe «\(antes)» en retryPendingBridges")
            #expect(r.upperBound <= resuelve.lowerBound, "el reparto se resuelve antes de «\(antes)»")
        }
        let converge = try #require(cuerpo.range(of: "GroupsBridgeRestoreConvergence.convergeIfPending(context: context)"))
        #expect(resuelve.upperBound <= converge.lowerBound, """
            el reparto se resuelve después de la convergencia: lo que pide espera a otro arranque en frío
            """)
    }

    /// **El arranque retoma lo que el origen prometió y no llegó, después de la convergencia y detrás de sus gates** (ticket
    /// `wipe-division-exclusion-trusts-the-origin-to-converge`). Los casos de comportamiento llaman a `takeOverIfOverdue` a
    /// mano; sin la llamada, lo prometido no vuelve nunca: el bug entero, en verde. Antes de la convergencia, la retoma vería
    /// sin filas lo que la convergencia va a reponer en ese mismo arranque.
    @Test("MUTACIÓN: el arranque retoma lo prometido tras la convergencia, detrás de sus gates")
    func theBootTakesOverWhatTheOriginPromisedAfterTheConvergence() throws {
        let llamada = "GroupsRemoteWipeDivision.takeOverIfOverdue(context: context)"
        #expect(try Self.countInProduction(llamada) == 1, "el arranque ya no retoma lo prometido, o lo retoma dos veces")
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let inicio = try #require(boot.range(of: "func retryPendingBridges(context: ModelContext) async {"))
        let cuerpo = boot[inicio.upperBound...]
        let retoma = try #require(cuerpo.range(of: llamada), "retryPendingBridges no retoma lo prometido")
        for antes in ["guard await awaitPersonalStoreReady() else", "guard GroupTransactionBridge.isDomainOpenForBridge() else",
                      "GroupsRemoteWipeDivision.resolveIfArrived()",
                      "GroupsBridgeRestoreConvergence.convergeIfPending(context: context)"] {
            let r = try #require(cuerpo.range(of: antes), "no existe «\(antes)» en retryPendingBridges")
            #expect(r.upperBound <= retoma.lowerBound, "la retoma corre antes de «\(antes)»")
        }

        let fuente = try Self.code("Yala/Services/Groups/GroupsRemoteWipeDivision.swift")
        let funcion = try #require(fuente.range(of: "static func takeOverIfOverdue("))
        let resto = fuente[funcion.upperBound...]
        let escribe = try #require(resto.range(of: "bridgeRemoteExpenses(ids:"))
        for guarda in ["guard GroupsRemoteWipeDivisionStore.awaiting(defaults) == nil else { return }",
                       "guard SessionState.shared.hasPrivateSession else { return }",
                       "guard GroupTransactionBridge.isDomainOpenForBridge(defaults: defaults) else { return }"] {
            let r = try #require(resto.range(of: guarda), "takeOverIfOverdue perdió «\(guarda)»")
            #expect(r.upperBound <= escribe.lowerBound, """
                takeOverIfOverdue re-puentea antes de «\(guarda)»: en solo-grupos el bridge borra las reales, con el dominio \
                cerrado no se toca nada, y con un reparto nuevo por llegar decide él
                """)
        }
    }

    /// **La promesa se apunta antes que la petición con exclusión.** Al revés, un corte entre las dos deja lo del origen
    /// excluido y sin techo: el bug del ticket. Ningún test de comportamiento puede cortar entre dos escrituras.
    @Test("MUTACIÓN: el reparto apunta la promesa antes de pedir la convergencia sin lo del origen")
    func theDivisionRecordsTheTrustBeforeTheScopedRequest() throws {
        let fuente = try Self.code("Yala/Services/Groups/GroupsRemoteWipeDivision.swift")
        let inicio = try #require(fuente.range(of: "static func resolveIfArrived("))
        let resto = fuente[inicio.upperBound...]
        let promete = try #require(resto.range(of: "try GroupsRemoteWipeDivisionStore.setTrusted("),
                                   "el reparto ya no apunta la promesa")
        let pide = try #require(resto.range(of: "try GroupsBridgeRestoreConvergenceStore.markPending("))
        #expect(promete.upperBound <= pide.lowerBound, "la promesa se apunta después de pedir: un corte la pierde")
    }

    /// **El alcance se escribe antes que la marca.** Al revés, un corte entre las dos deja una petición ENTERA, que repone
    /// lo que repone el origen: el duplicado del 27-sep. Ningún test de comportamiento puede cortar entre dos `set`.
    @Test("MUTACIÓN: la petición con exclusión escribe el alcance antes que la marca")
    func theScopedRequestWritesTheScopeFirst() throws {
        let fuente = try Self.code("Yala/Services/Groups/GroupsBridgeRestoreConvergence.swift")
        let inicio = try #require(fuente.range(of: "static func markPending(excluding scope: Exclusion,"))
        let resto = fuente[inicio.upperBound...]
        let fin = try #require(resto.range(of: "enum GroupsBridgeRestoreConvergenceLogic"), "no se encuentra el final")
        let cuerpo = String(resto[resto.startIndex..<fin.lowerBound])
        #expect(Self.count("defaults.set(true, forKey: key)", in: cuerpo) == 1, "la petición con exclusión pone la marca dos veces")
        #expect(cuerpo.contains("defaults.set(try JSONEncoder().encode(scope), forKey: excludedKey) "
                                + "defaults.set(true, forKey: key) }"), """
            la petición con exclusión ya no escribe el alcance justo antes que la marca: un corte entre las dos dejaría \
            una convergencia entera
            """)
    }

    /// Quien repone solo lo hace en una sesión que obedece la señal de vaciado: el valor por defecto de producción es el
    /// predicado del receptor. Los casos de comportamiento lo pasan a mano, así que solo este scan ve que sigue ahí.
    @Test("MUTACIÓN: quien repone decide con el mismo predicado que obedece la señal")
    func theReturnerUsesTheWipeSignalPredicate() throws {
        let fuente = try Self.code("Yala/Services/Groups/GroupsRemoteWipeReturn.swift")
        #expect(fuente.contains("obeysWipeSignal: Bool = DestructiveScopeLogic.wipeSignalObeyedByThisSession( "
                                + "confirmedPrivateSession: PrivateSessionMark.confirmedPrivateSession(), "
                                + "storageMode: CloudSyncFlags.storageMode)"),
                "el valor por defecto de `obeysWipeSignal` ya no es el predicado del receptor de la señal")
    }
}
