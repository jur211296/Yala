//
//  RestoreStartFreshGateTests.swift
//  YalaTests / CloudSync
//
//  «Empezar desde cero» en la pantalla de Restaurar prometía «sin tus datos previos» y no borraba nada
//  (`restore-start-fresh-keeps-the-imported-corpus`). El corpus seguía bajando por debajo mientras la
//  persona hacía su onboarding «de cero», porque esa pantalla **solo existe con el espejo adjunto**.
//
//  **Es source-scan de principio a fin, y aquí no es una segunda opción.** Los dos lados del cambio son
//  closures dentro de vistas SwiftUI que ningún unit test puede invocar, y el bug no era una decisión mal
//  tomada: era un camino que no pasaba por la decisión. Ese defecto no da rojo en ninguna suite de
//  comportamiento — el recorrido «funciona», solo que sin preguntar. Mismo molde y mismo motivo que
//  `WelcomePrivateICloudGateWiringTests`.
//
//  **Una sola `@Suite`, y su nombre es el del fichero a propósito**: `-only-testing` filtra por TIPO, no
//  por fichero, y un fichero con dos suites corre CERO casos cuando se acota por su nombre — con
//  `TEST SUCCEEDED` y exit 0 (`.claude/rules/testing.md`).
//
//  **Lo que estos tests NO declaran verificado**, y va dicho para que nadie lo lea de más:
//   · Que el borrado deje el contenedor de iCloud a cero. CloudKit no existe en simulador ⇒ device-QA.
//   · Que el alert de fresh-start ya no salga tras el borrado. El mecanismo es una lectura viva dentro de
//     una closure capturada del `body`, y eso no lo puede afirmar un scan; bajo XCUITest tampoco, porque
//     `measure()` sale por el seam `isUITesting` antes de medir nada. ⇒ device-QA.
//
//  MUTANTES VERIFICADOS (compilados y corridos, no razonados):
//   (1) el árbol de ANTES —`showOnboarding = true` + limpieza de residuales— → 3 fallos.
//   (2) el envoltorio del borrado sin su `guard failure == nil` → 1 fallo.
//   (3) ese `guard` movido DESPUÉS de bajar las señales (compila) → 1 fallo.
//   (4) la gracia del wipe remoto cancelada después del `await` → 1 fallo.
//   (5) el borrado cambiado por `performDeviceCorpusWipe()` (borra el teléfono, no la zona) → 1 fallo.
//   (6) la activación de Yala completo mandada a la puerta → 2 fallos.
//   (7) `.cloudPaused` llamando a `onStartFresh` directo, sin confirmar → 1 fallo.
//   (8) `.found` llamando a `onStartFresh` directo, sin confirmar → 1 fallo.
//   (9) el arm del borrado sin retirar en la salida `.proceed` → 1 fallo.
//  (10) `hasShownWelcomeChooser` sin bajar en el callback → 1 fallo.
//  (11) el gate del alert de fresh-start devuelto al snapshot `hasExistingData` → 1 fallo, y lo canta
//       `FreshStartWipeAlertTests`, que es donde vive ese invariante.
//

import Foundation
import Testing

@testable import Yala

@Suite("Restaurar · «Empezar desde cero» pasa por la puerta (source-scan)")
struct RestoreStartFreshGateTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El fichero SIN sus líneas de comentario. Obligatorio siempre que se busque una AUSENCIA: los
    /// callbacks que este test vigila documentan en prosa el literal que se está prohibiendo («encendía
    /// `showOnboarding`»), así que sin el filtro explicar el invariante lo incumpliría.
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// **Los argumentos de UNA llamada, por paréntesis balanceados.** `body(of:)` cuenta LLAVES, así que
    /// sobre un marcador que abre paréntesis —`WelcomeFlowModifier(`— no acota la llamada. Acotar así
    /// mantiene el rango estable aunque mañana aparezca otro argumento con el mismo nombre por encima.
    private static func call(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "llamada no encontrada: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "(" { depth += 1 }
            if chars[i] == ")" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo entre llaves balanceadas desde un marcador, sin líneas de comentario. Acotar no es
    /// cosmético: un `contains` sobre el fichero entero comprueba que el símbolo EXISTE en
    /// `ContentView.swift` —donde hay ocho `showOnboarding = true`— y no que esté en este callback.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Dos literales y su ORDEN. Comparar posiciones y no solo presencia es lo que separa «las dos líneas
    /// están» de «la que protege va antes» — y es lo único que caza un SWAP, que compila.
    private static func expectOrder(_ first: String, before second: String, in source: String,
                                    _ why: String,
                                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        let a = try #require(source.range(of: first), "no está: \(first)")
        let b = try #require(source.range(of: second), "no está: \(second)")
        #expect(a.lowerBound < b.lowerBound, Comment(rawValue: why), sourceLocation: sourceLocation)
    }

    // MARK: - El pin del bug

    /// **EL PIN.** Si alguien devuelve `showOnboarding = true` a este callback, el recorrido sigue
    /// funcionando —pantalla a pantalla no se nota nada— y el corpus vuelve a bajar por debajo del
    /// onboarding «de cero». No hay ningún otro rojo que lo cace.
    @Test("«Empezar desde cero» de Restaurar va a la puerta de iCloud, no al onboarding")
    func startFresh_goesThroughTheGate() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let callback = try Self.body(of: "onStartFresh: {", in: src)

        #expect(callback.contains("returnToWelcomeChooser(dismissing: $showWelcomeRestore, step: .privateICloudGate)"), """
            «Empezar desde cero» tiene que entrar a la puerta del paso 4: es la única que le pregunta a
            CloudKit, enseña las cifras y borra con doble confirmación. Sin esto el botón promete
            «sin tus datos previos» y no borra nada.
            Cuerpo leído: \(callback)
            """)
        #expect(!callback.contains("showOnboarding = true"), """
            esto es el bug entero: abrir el onboarding «de cero» con el espejo adjunto deja el corpus
            bajando por debajo. La salida al onboarding la decide la puerta, por el portal de siempre.
            """)
        #expect(!callback.contains("clearResidualPreferencesForFreshStart"), """
            se limpia cuando se BORRA, no cuando se pregunta (`welcome-start-fresh-wipes-before-ask`).
            Desde que este botón lleva a la puerta hay dónde cancelar, así que limpiar aquí le quitaría el
            nombre y la divisa a quien solo estaba mirando. Si la puerta borra, limpia ella.
            """)
        #expect(callback.contains("prefilledOnboardingData = nil"), """
            el prefill del restore tiene que caer: quien va a empezar de cero no arranca con los datos
            que acaba de decidir no traerse.
            """)
        // **La persona vuelve a estar ELIGIENDO**, y de ese flag cuelgan dos cosas: que un kill aquí no
        // abra el onboarding privado directo (saltándose la puerta), y que el neutro durable del borrado
        // —`armNeutralMount`, cuyo predicado lleva `!hasShownWelcomeChooser`— no sea inerte.
        #expect(callback.contains("hasShownWelcomeChooser = false"), """
            sin bajar el flag pasan DOS cosas, las dos medidas: un kill en la puerta manda al onboarding
            privado sin chooser y sin validar iCloud (este mismo bug por detrás), y el neutro durable que
            `armICloudCorpusWipe` arma queda anulado por su propio predicado — un kill durante el borrado
            monta espejo en el arranque siguiente y re-importa justo lo que se estaba borrando.
            """)
    }

    /// **La otra mitad del par — y desde el 2026-09-14 las dos apuntan al mismo sitio.**
    ///
    /// Hasta ese día este test pinneaba la ASIMETRÍA: la activación de «Yala completo» comparte esta vista
    /// y su botón no podía pasar por la puerta, porque allí el único borrado disponible era de ZONA y con
    /// el store espejando eso dejaba las filas importadas re-exportándose. Faltaba un borrador que no
    /// existía —filas personales sin tocar preferencias— y por eso tenía ticket propio
    /// (`activation-restore-start-fresh-keeps-the-imported-rows`).
    ///
    /// Ese borrador ya existe (`ICloudWipeScope.importedRows`), así que el test se INVIERTE y ahora
    /// protege el daño contrario: que nadie devuelva este botón al onboarding directo, que es el bug.
    ///
    /// **Y el destino es `.restoreDiscardGate`, no `.privateGate`**: aquélla borra solo la zona, y desde
    /// aquí eso es exactamente el borrado que no borra.
    @Test("la activación de Yala completo manda su «Empezar desde cero» a SU puerta, la que borra las filas")
    func activationStartFreshGoesToItsDiscardGate() throws {
        let src = try Self.code("Yala/App/Views/Groups/FullModeActivationView.swift")
        let callback = try Self.body(of: "onStartFresh: {", in: src)
        #expect(callback.contains("go(to: .restoreDiscardGate)"), """
            el botón volvió a su salida vieja. Sin la puerta no borra NADA: ni la zona de iCloud ni el
            corpus que el espejo ya bajó, que se re-exporta a la zona recién creada — también al segundo
            dispositivo del mismo Apple ID.
            Cuerpo leído: \(callback)
            """)
        // **`.privateGate` prohibido, y no es redundante con lo de arriba:** las dos son la misma vista y
        // el swap compila. Con la puerta privada, el borrado que se ofrece es el de ZONA, así que la
        // pantalla promete un borrado que deja las filas importadas intactas — el bug entero, con dos
        // confirmaciones delante para hacerlo creíble.
        #expect(!callback.contains(".privateGate"), """
            el botón apunta a la puerta PRIVADA, cuyo borrado es solo de zona: con el store espejando, eso
            deja el corpus importado entero y el espejo lo vuelve a subir.
            """)
        #expect(!callback.contains(".onboarding("), """
            el botón volvió a saltar directo al onboarding: eso es el bug original, sin borrar nada.
            """)
    }

    // MARK: - El borrado que recibe el Welcome

    /// El envoltorio del borrado: **qué llama, en qué orden, y qué NO hace si falla.**
    ///
    /// La primera versión de este test comprobaba que las líneas estaban y no cuál era la llamada — así
    /// que cambiar `performICloudCorpusWipe()` por `performDeviceCorpusWipe()` (borra el teléfono y deja
    /// la zona de iCloud entera) lo dejaba en verde con el ticket entero deshecho. Lo cazó la lente de
    /// tests de la review, y es la «pasarela que nadie vigila» de `testing.md` en el fichero que más la
    /// cita.
    @Test("el borrado que recibe el Welcome es el del CORPUS, y sus señales solo bajan si fue bien")
    func welcomeWipe_isTheCorpusWipe_andLowersTheFlagsOnlyOnSuccess() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        // Acotado a la llamada del modifier y no al literal suelto: dentro de `WelcomeFlowModifier` hay
        // un reenvío con el MISMO nombre de argumento, y el que lleva el envoltorio es este.
        let modifier = try Self.call(of: "WelcomeFlowModifier(", in: src)
        let wrapper = try Self.body(of: "performICloudCorpusWipe: {", in: modifier)

        #expect(wrapper.contains("await performICloudCorpusWipe(.handover)"), """
            el envoltorio dejó de llamar al borrado del CORPUS. Su hermana `performDeviceCorpusWipe` borra
            las filas del teléfono y NO toca la zona de iCloud: con ella, el espejo vuelve a bajar el
            corpus entero y además se bajan las dos señales diciendo que no hay datos.
            Cuerpo leído: \(wrapper)
            """)
        #expect(wrapper.contains("hasExistingData = false"), """
            tras el borrado, `storeLooksEmpty` seguiría diciendo que el store tiene datos.
            """)
        #expect(wrapper.contains("hasPersonalData = false"), """
            la señal que alimenta al detector de wipe remoto se queda afirmando un corpus que ya no está.
            """)
        // **El `guard` por ORDEN y no por presencia.** Moverlo detrás de las dos asignaciones compila y
        // deja las señales en `false` sobre un corpus INTACTO: es el daño que su propio mensaje describe,
        // y un `contains` suelto no lo distingue.
        try Self.expectOrder("guard failure == nil else { return failure }",
                             before: "hasExistingData = false", in: wrapper, """
            el corte del fallo se movió detrás de las señales: un borrado que FALLÓ no borró nada, y
            bajarlas ahí es mentirle a toda la app sobre un corpus que sigue entero.
            """)
        // **La gracia se cancela ANTES del borrado, no en la rama de éxito.** `wipeAllUserData` guarda por
        // lotes, así que un borrado que lanza a media lista deja el `hasPersonalData` cayendo igual — y
        // ese `true → false` sin la gracia cancelada levanta el alert de wipe remoto, que DESMONTA el
        // cover del Welcome. Es la corrección que su hermana `performDeviceCorpusWipe` ya lleva escrita.

        // El ancla es `cancelWipeGrace()` desde el 2026-09-14: cancelar la tarea dejó de bastar cuando el
        // aviso pasó a viajar por la cola del router, así que las dos mitades —cancelar y retirar el
        // intent ya encolado— viven en esa función.
        try Self.expectOrder("cancelWipeGrace()",
                             before: "await performICloudCorpusWipe(.handover)", in: wrapper, """
            la gracia del wipe remoto se cancela DESPUÉS del borrado: un borrado que lanza a media lista
            deja las filas borradas y la gracia viva, y el alert «te borraron los datos en otro
            dispositivo» desmonta el cover del Welcome.
            """)
        #expect(!wrapper.contains("hasCompletedOnboarding"), """
            forzarlo aquí dispara el encaminamiento del arranque con el Welcome montado, que es justo lo
            que `onboardingReset_doesNotHijackTheWelcome` prohíbe. Lo borra `wipeAllUserData` por su
            cuenta.
            """)
    }

    /// **El helper que hace la navegación, pinneado por primera vez.** `returnToWelcomeChooser` es el
    /// choke-point de TRES callbacks del Welcome y nadie afirmaba su cuerpo: quitarle `showWelcomeFlow =
    /// true` deja «Empezar desde cero» cerrando el cover del restore **sobre una pantalla vacía sin
    /// salida**, que es el bug que `WelcomeFreshStartAlertUITests` existe para prevenir en la rama de al
    /// lado. Este diff le añadió el tercer llamador, así que el choke-point acaba de ganar peso.
    @Test("el helper de vuelta al Welcome baja un cover y sube el otro, en ese orden")
    func returnHelper_swapsTheCovers() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let helper = try Self.body(
            of: "private func returnToWelcomeChooser(dismissing flag: Binding<Bool>, step: WelcomeFlowStep) {",
            in: src)
        #expect(helper.contains("flag.wrappedValue = false"), """
            el helper dejó de cerrar el cover de origen: dos covers del mismo anchor a la vez es la
            carrera de presentación que la regla (4) de Presentaciones documenta.
            """)
        #expect(helper.contains("showWelcomeFlow = true"), """
            sin esto el cover de origen se cierra y no se abre nada: pantalla vacía y sin salida.
            """)
        // El step se escribe ANTES de presentar, o el container arranca en su `@State` inicial y el
        // destino pedido se pierde en silencio.
        try Self.expectOrder("welcomeFlowInitialStep = step", before: "showWelcomeFlow = true", in: helper, """
            el step se escribe después de presentar: `@State` se inicializa una sola vez, así que el
            container arranca donde estuviera y el destino pedido no llega.
            """)
    }

    // MARK: - El arm del borrado, y las salidas que lo retiran

    /// **Un arm que sobrevive a una salida deliberada no es una red, es una trampa.** Mientras está
    /// puesto, `runLateICloudMirrorCheck` lo REANUDA A CIEGAS: borra la zona de CloudKit y las filas
    /// locales sin preguntar nada. Con el mount neutro eso no mordía porque toda salida de la puerta
    /// relanza y `presentNextOnboardingScreen` retira el arm junto al destino pendiente; **la puerta
    /// alcanzada con el espejo ya adjunto no relanza**, y ese camino dejó de ser una esquina el día que
    /// «Restaurar → Empezar desde cero» empezó a entrar por aquí.
    @Test("las salidas de la puerta que no dejan un borrado a medias retiran el arm")
    func gateExits_discardThePendingWipeArm() throws {
        let gate = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")

        let continueWithout = try Self.body(of: "private func continueWithoutValidating() {", in: gate)
        #expect(continueWithout.contains("discardPendingWipe()"), """
            seguir sin poder validar deja el arm puesto: el arranque siguiente borra la zona de iCloud y
            todo lo local sin preguntar, incluido lo que la persona haya creado desde entonces.
            """)

        // La rama `.proceed` de la medida: la sonda acaba de decir que no queda nada que borrar.
        let measure = try Self.body(of: "private func measure() async {", in: gate)
        let proceed = try #require(measure.range(of: "case .proceed:"))
        let siguiente = measure.range(of: "case .", range: proceed.upperBound..<measure.endIndex)?.lowerBound
            ?? measure.endIndex
        #expect(String(measure[proceed.upperBound..<siguiente]).contains("discardPendingWipe()"), """
            `.proceed` es el desenlace de quien vuelve aquí tras un kill con el borrado a medias: la zona
            ya está vacía. Dejar el arm puesto hace que un arranque posterior «reanude» un borrado que ya
            no tiene objeto y se lleve por delante lo que la persona haya creado.
            """)

        // Y la tercera salida, que vive en el container porque es él quien traduce «restaurar».
        let container = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let onRestore = try Self.body(of: "onRestore: {", in: container)
        #expect(onRestore.contains("clearICloudCorpusWipeArm()"), """
            «Traer mis datos» es la voluntad expresada DESPUÉS de pedir el borrado. Sin retirar el arm,
            quien sale por aquí restaura su histórico y el arranque siguiente se lo borra entero.
            """)
        #expect(onRestore.contains("handleExistingOption(.restoreICloud)"), """
            y sigue saliendo por el helper que ya traduce «restaurar» a su destino.
            """)
    }

    // MARK: - La primera confirmación

    /// **La primera confirmación se queda donde estaba, y en los DOS estados que afirman que hay datos.**
    /// Al llevar el botón a la puerta se podría haber retirado —la puerta vuelve a preguntar, con
    /// cifras—, y sería un error: esta vista tiene dos consumidores y en los dos el diálogo es la
    /// PRIMERA confirmación de un gesto destructivo. Desde el 2026-09-14 el segundo (la activación)
    /// también pasa por una puerta que vuelve a preguntar, así que ya no es la única — pero se suman
    /// confirmaciones, no se restan, y retirarla dejaría el gesto con una sola en el camino más
    /// destructivo de los dos.
    ///
    /// Los dos estados van ACOTADOS. La primera versión afirmaba el diálogo sobre el fichero entero, y
    /// esa aserción la cumplía `cloudPausedView` solo: cablear `.found` directo al callback dejaba el
    /// camino principal del ticket sin confirmación y el test en verde.
    @Test("los dos estados que afirman que hay datos siguen confirmando antes de empezar de cero")
    func bothStatesThatClaimDataStillConfirm() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomeRestoreView.swift")

        // El diálogo existe y su botón destructivo hace algo: montarlo con la closure vacía lo deja
        // presente y muerto.
        let dialog = try Self.body(of: "isPresented: $showStartFreshConfirm,", in: src)
        #expect(dialog.contains("onStartFresh()"), """
            el botón destructivo del diálogo dejó de llamar al callback: la confirmación sigue saliendo y
            ya no lleva a ninguna parte.
            """)

        // `.found` es el camino principal del ticket: el que enseña las cifras de lo que bajó.
        let found = try Self.body(of: "private func foundView(summary: ICloudAccountSummary) -> some View {",
                                  in: src)
        #expect(found.contains("showStartFreshConfirm = true"), """
            el estado que acaba de enseñar «encontramos tus datos» descarta el restore sin confirmar.
            """)
        #expect(!found.contains("onStartFresh()"), """
            y lo hace por el diálogo, no llamando al callback directo — que es el swap que compila.
            """)

        // `.cloudPaused` lo REUSA en vez de llamar directo, y es el único estado vacío que lo hace:
        // los otros tres no afirman nada sobre los datos del usuario, éste afirma que EXISTEN.
        let paused = try Self.body(of: "private var cloudPausedView: some View {", in: src)
        #expect(paused.contains("showStartFreshConfirm = true"), """
            «la nube está en pausa» afirma que los datos existen: empezar de cero desde ahí sin confirmar
            arranca un dataset paralelo que convivirá con la cuenta que ese mismo texto prometió intacta.
            """)

        // Y la exclusividad en la otra dirección: los tres estados que NO afirman datos siguen llamando
        // directo. Cablearlos al diálogo (o al revés) es el mismo swap, por el otro lado.
        for vacio in ["private var notFoundView: some View {",
                      "private var iCloudDisabledView: some View {",
                      "private var wipedView: some View {"] {
            let cuerpo = try Self.body(of: vacio, in: src)
            #expect(!cuerpo.contains("showStartFreshConfirm"), Comment(rawValue: """
                \(vacio) pasó a confirmar: ese estado afirma que NO hay datos, así que la confirmación
                pregunta por algo que la propia pantalla acaba de negar. La doble confirmación de la
                puerta es la que cubre el borrado.
                """))
        }
    }
}
