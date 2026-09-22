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
//  (7b) `.cloudUnverified` llamando a `onStartFresh` directo, sin confirmar → 1 fallo aquí
//       (2026-09-17; el estado que no sabe si hay datos es el que MENOS puede saltarse el diálogo).
//   (9) el arm del borrado sin retirar en la salida `.proceed` → 1 fallo.
//  (10) `hasShownWelcomeChooser` sin bajar en el callback → 1 fallo.
//  (11) el gate del alert de fresh-start devuelto al snapshot `hasExistingData` → 1 fallo, y lo canta
//       `FreshStartWipeAlertTests`, que es donde vive ese invariante.
//
//  Tanda del 2026-09-20 (`restore-says-no-data-when-the-icloud-import-never-settled`). Conteo del
//  CONJUNTO que se lanzó —esta suite, `RestoreImportSettlementTests`, `WelcomeRestoreEmptyOutcomeTests`
//  e `ICloudRestoreSignalWiringTests`: 25 casos— con el control positivo sin mutar en verde:
//  (12) `.iCloudDisabled` devuelto a `onStartFresh` directo → 1 fallo.
//  (13) `.importIncomplete` llamando directo, sin confirmar → 1 fallo.
//  (14) `.notFound` devuelto a `primaryAction: onStartFresh` → 1 fallo. (La versión con el gesto
//       CONDICIONAL —`if conclusive`— también moría, y aun así se retiró: su rama directa solo la
//       alcanzaba quien tiene presupuestos o grupos, o sea gente con datos. El mutante moría y el
//       término sobraba. Desde el 2026-09-21 los presupuestos cuentan en `hasAnyData` y los grupos no
//       —`restore-treats-budgets-and-groups-as-no-data`, y los grupos nunca estuvieron «en iCloud»—,
//       así que la rama conserva población y la conclusión no cambia.)
//  (15) el corte `!settlement.consultsRemoteConfig` desactivado, o sea el bug entero con el enum nuevo
//       puesto y la tabla de decisión en verde → 2 fallos.
//  (16) `hasObservedImportActivity:` cableado a `settled` en la pantalla de progreso → 1 fallo.
//  (17) `.iCloudDisabled` fuera de `showRefreshToolbar` → 1 fallo. **Este SOBREVIVÍA** hasta que la
//       review lo cazó: sin su test, quitar el refresco del único estado «puede tener datos» que no lo
//       tenía dejaba la tanda entera en verde.
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

        // `.cloudPaused` lo REUSA en vez de llamar directo: los estados que niegan que haya datos no
        // afirman nada que proteger, éste afirma que EXISTEN.
        let paused = try Self.body(of: "private var cloudPausedView: some View {", in: src)
        #expect(paused.contains("showStartFreshConfirm = true"), """
            «la nube está en pausa» afirma que los datos existen: empezar de cero desde ahí sin confirmar
            arranca un dataset paralelo que convivirá con la cuenta que ese mismo texto prometió intacta.
            """)

        // `.cloudUnverified` (2026-09-17) también, y por el motivo simétrico: no afirma que existan,
        // pero tampoco que falten. Sin saberlo, el gesto destructivo se pregunta — quien lo pulsa
        // podría tener su histórico entero esperando en el servidor al otro lado de la red caída.
        let unverified = try Self.body(of: "private var cloudUnverifiedView: some View {", in: src)
        #expect(unverified.contains("showStartFreshConfirm = true"), """
            «no pudimos comprobar tus datos» pasó a descartar sin confirmar: es el único estado que no
            sabe si hay algo que perder, así que es el que MENOS puede permitirse saltarse el diálogo.
            """)
        #expect(!unverified.contains("onStartFresh()"), """
            y lo hace por el diálogo, no llamando al callback directo — que es el swap que compila.
            """)

        // `.importIncomplete` (2026-09-20) es el caso más fuerte de los cuatro: no es que no sepamos si
        // hay datos, es que los estamos viendo bajar.
        let importing = try Self.body(of: "private var importIncompleteView: some View {", in: src)
        #expect(importing.contains("showStartFreshConfirm = true"), """
            «seguimos trayendo tus datos» pasó a descartar sin confirmar. Ese texto acaba de afirmar
            que el histórico EXISTE y está entrando: empezar de cero encima abre un dataset paralelo
            que convivirá con él en cuanto el import termine.
            """)
        #expect(!importing.contains("onStartFresh()"), """
            y por el diálogo, no llamando al callback directo — el swap que compila.
            """)

        // `.iCloudDisabled` (2026-09-20). Estuvo en el bucle de abajo hasta hoy, clasificado como
        // estado que NIEGA los datos, y el propio criterio de este test es «negar, no callar». Medido
        // contra su copy (`es-419.lproj/Localizable.strings:4101`): «Necesitas tener iCloud activado
        // para RECUPERAR TUS DATOS» no niega nada — los presupone. Aquí no hubo búsqueda, así que es
        // el mismo hecho que `.cloudUnverified` y le toca la misma red.
        let disabled = try Self.body(of: "private var iCloudDisabledView: some View {", in: src)
        #expect(disabled.contains("showStartFreshConfirm = true"), """
            «activa iCloud para continuar» volvió a descartar sin confirmar. Con iCloud apagado no se
            comprobó NADA: quien pulsa ahí puede tener su histórico entero en la cuenta que acaba de
            quedarse sin Drive.
            """)
        #expect(!disabled.contains("onStartFresh()"), """
            y por el diálogo. Ojo: `onOpenSettings` sigue siendo el primario y es el que no se toca.
            """)

        // `.notFound` (2026-09-20), y es el camino principal del ticket: el mensaje que NIEGA los datos
        // es justo el que la búsqueda no siempre puede sostener.
        let notFound = try Self.body(of: "private var notFoundView: some View {", in: src)
        #expect(notFound.contains("primaryAction: { showStartFreshConfirm = true }"), """
            «No encontramos tus datos» volvió a borrar sin preguntar. Aquí caen el usuario realmente
            nuevo Y el teléfono al que CloudKit no contestó, y la señal del import no los separa —
            `settled` es `false` para los dos—, así que la búsqueda nunca concluye de forma legítima y
            la confirmación es incondicional. Un `if` que la haga condicional NO es una simplificación
            pendiente: su rama directa tiene una sola población y es gente con datos, la de
            `restore-treats-budgets-and-groups-as-no-data`.
            """)
        #expect(!notFound.contains("primaryAction: onStartFresh"), """
            y por el diálogo, no pasando el callback como acción — el swap que compila.
            """)

        // Y la exclusividad en la otra dirección: el ÚNICO estado que sigue llamando directo sin
        // condición es `.wiped`. Cablearlo al diálogo es el mismo swap, por el otro lado.
        // Ojo al leer esto: el criterio NO es «niega que haya datos» —`.iCloudDisabled` estuvo aquí
        // por eso y su copy no niega nada—. El criterio es que la búsqueda haya CONCLUIDO, y en
        // `.wiped` concluye por acto de la propia persona: acaba de borrar en este dispositivo.
        let wiped = try Self.body(of: "private var wipedView: some View {", in: src)
        #expect(!wiped.contains("showStartFreshConfirm"), """
            `.wiped` pasó a confirmar. Es el único desenlace concluyente por decisión del propio
            usuario —acaba de borrar aquí—, así que la confirmación preguntaría por algo que él mismo
            decidió hace un momento. La doble confirmación de la puerta es la que cubre el borrado.
            """)
    }

    // MARK: - El cable de la señal del import (2026-09-20)

    /// **La decisión pura puede estar perfecta y no llegar nunca.** `RestoreImportSettlementTests` fija
    /// la tabla; esto fija que la pantalla la ALIMENTA con lo vivo y la CONSUME donde toca. Los dos
    /// extremos viven en closures de vistas SwiftUI que ningún unit test puede invocar, así que el scan
    /// es la única red — y entonces se fija el emparejamiento y el orden, no la presencia de literales.
    ///
    /// Tres swaps que compilan y dejan el ticket deshecho con el enum nuevo puesto:
    ///  · alimentar `hasObservedImportActivity:` con `settled` (o con `true`/`false` fijos);
    ///  · leer el flag DESPUÉS del mínimo de exhibición, describiendo otro instante que el `settled`;
    ///  · mandar `.stillImporting` por `resolveEmptyState`, que no conoce el import y lo devuelve a
    ///    `.notFound` — el bug entero, con la tabla en verde.
    @Test("La señal del import se toma de lo vivo, junto al `settled`, y corta la consulta de red")
    func theImportSignalIsWiredFromTheLiveFlag() throws {
        let progress = try Self.code("Yala/App/Views/Onboarding/RestoreProgressView.swift")

        // **El testigo del import viaja por una variable desde el 2026-09-21**
        // (`restore-timeout-closes-the-session-window-with-the-import-still-running`): ahora lo leen
        // DOS consumidores en el mismo instante —este `resolve`, que elige el copy, y la puerta que
        // decide si se apaga la ventana de sesión— y se lee una sola vez para que no hablen de dos
        // momentos. El invariante de este test no cambia: sigue teniendo que salir del flag VIVO. Lo
        // que cambia es que hay que fijar los dos extremos del cable, porque cada uno por separado
        // deja pasar un swap: la variable sola podría venir de una constante, y el argumento solo
        // podría alimentarse de `settled`.
        #expect(progress.contains("let sawImport = iCloudSyncService.shared.hasObservedImportActivity"), """
            El testigo del import dejó de leerse del flag VIVO del servicio. Cableado a `settled`, a una
            constante o a un valor de otro instante, el veredicto es el de antes del ticket y ninguna
            tabla se pone roja: `resolve` sigue siendo correcta, solo que nadie le cuenta lo que pasó.
            """)

        // Las TRES entradas vivas, por su lectura completa y no por la etiqueta del argumento: un
        // `hasObservedImportActivity:` a secas casa primero con la etiqueta, que no puede moverse sola.
        for lectura in ["hasObservedImportActivity: sawImport",
                        "lastImportErrorAt: iCloudSyncService.shared.lastImportErrorAt",
                        "lastSuccessfulImportAt: iCloudSyncService.shared.lastSuccessfulImportDate"] {
            #expect(progress.contains(lectura), Comment(rawValue: """
                La resolución dejó de alimentarse de `\(lectura)`. Cableada a `settled`, a `nil` o a una
                constante, el veredicto es el de antes del ticket y ninguna tabla se pone roja: `resolve`
                sigue siendo correcta, solo que nadie le cuenta lo que pasó. Las dos fechas cargan el
                término que separa un import que TARDA de uno que FALLA.
                """))
        }

        // El ORDEN: la señal se lee entre la espera y el apagado de la ventana, que es lo que separa
        // «el testigo describe esta medida» de «describe otra». El ancla de abajo es
        // `noteRestoreFinished()` y no el `sleep(0.8)`: ese 0,8 es un número de UX que alguien puede
        // tocar sin que este invariante cambie, y anclarlo ahí sería un rojo falso esperando a ocurrir.
        try Self.expectOrder("await iCloudSyncService.shared.waitForImportQuiescence",
                             before: "RestoreImportSettlement.resolve(", in: progress, """
            la señal se lee ANTES de la espera: entonces describe el estado previo al import y no el
            que produjo el `settled` que la acompaña.
            """)
        try Self.expectOrder("RestoreImportSettlement.resolve(",
                             before: "ICloudRestoreSessionSignal.noteRestoreFinished(", in: progress, """
            la señal se lee después de cerrar la ventana, o sea más tarde que la medida que dice
            describir. La pareja `settled` + actividad pasaría a hablar de dos momentos distintos.
            """)

        // Y que el veredicto VIAJE. `settled` está medido por su propio test; lo que aquí puede morir
        // sin que nada se ponga rojo es el segundo argumento, porque el compilador se conforma con
        // cualquier `RestoreImportSettlement` — incluido un `.settledEmpty` literal, que deja el log
        // sin la distinción entera del ticket y sigue usando `settlement` en el callback de al lado.
        for paso in ["settlement: settlement", "onSettled(counts ??"] {
            #expect(progress.contains(paso), Comment(rawValue: """
                `\(paso)` desapareció: el veredicto se calcula y no llega a su consumidor. Con un caso
                literal en su sitio compila, no deja warning y la tanda entera sigue verde.
                """))
        }
        let breadcrumb = try Self.call(of: "RestoreBreadcrumb.settled(", in: progress)
        #expect(breadcrumb.contains("settlement: settlement"), """
            el rastro dejó de llevar el veredicto VIVO. Es la única ventana sobre este flujo —el bug
            reproduce en CloudKit Production, sin dSYM ni simulador— y con una constante ahí Console.app
            deja de distinguir «CloudKit contestó que no hay nada» de «CloudKit no contestó», que es la
            pregunta del ticket.
            """)

        // Y el consumo. Cada rama se acota hasta la siguiente: un `contains` sobre la closure entera lo
        // cumple el vecino, y aquí el vecino es el bug — intercambiar los dos cuerpos del `if` compila,
        // devuelve `.stillImporting` a `resolveEmptyState` (o sea al mensaje que niega los datos) y deja
        // al usuario nuevo en «seguimos trayendo tus datos» para siempre. Lo cazó la review.
        let view = try Self.code("Yala/App/Views/Onboarding/WelcomeRestoreView.swift")
        let closure = try Self.body(of: "RestoreProgressView(flowToken: flowToken) { summary, settlement in",
                                    in: view)

        let ramas = ["if summary.hasAnyData {",
                     "} else if !settlement.consultsRemoteConfig {",
                     "} else {"]
        func cuerpo(_ i: Int) throws -> String {
            let desde = try #require(closure.range(of: ramas[i]),
                                     Comment(rawValue: "falta la rama `\(ramas[i])`"))
            let hasta = i + 1 < ramas.count
                ? (closure.range(of: ramas[i + 1], range: desde.upperBound..<closure.endIndex)?.lowerBound
                   ?? closure.endIndex)
                : closure.endIndex
            return String(closure[desde.upperBound..<hasta])
        }

        #expect(try cuerpo(0).contains("state = .found(summary)"), """
            la rama con datos dejó de pintar `.found`: el restore que SÍ puede ocurrir se va por otro
            camino.
            """)

        let vienen = try cuerpo(1)
        #expect(vienen.contains("state = .importIncomplete"), """
            la rama del import en marcha no pinta su estado. Mandarla a `resolveEmptyState` es el bug
            entero: ese camino no conoce el import y devuelve el `.notFound` que niega los datos.
            """)
        #expect(vienen.contains("RestoreBreadcrumb.importIncomplete()"), """
            y sin rastro. En pantalla este desenlace y el `.notFound` legítimo se parecen.
            """)
        #expect(!vienen.contains("resolveEmptyState"), """
            la rama del import en marcha volvió a consultar el backend. Su kill-switch gobierna la nube
            de Yala, no el espejo de Apple: no puede cambiar este desenlace, y el fetch es más espera
            para quien ya agotó el tope.
            """)

        let resto = try cuerpo(2)
        #expect(resto.contains("resolveEmptyState(settlement)"), """
            el resto dejó de seguir al desenlace de siempre, que es el único que distingue «la nube está
            en pausa» de «no pudimos comprobar» de «no hay datos» — y el que recibe también al import
            que FALLA, porque un error vigente lo devuelve a `.inconclusive`.
            """)
        #expect(!resto.contains("state = .importIncomplete"), """
            y no pinta «seguimos trayendo tus datos»: ahí caen el usuario realmente nuevo y el teléfono
            cuyo import está fallando. A los dos esa frase les miente.
            """)
    }

    /// **Todo estado que pueda tener datos ofrece volver a buscar, `.iCloudDisabled` incluido.**
    /// Lo añadió la review del 2026-09-20 y lo pide este test porque **el mutante sobrevivía**: quitar
    /// `.iCloudDisabled` de la lista dejaba las 27 aserciones de la tanda en verde.
    ///
    /// No es cosmético. `startSearch()` cuelga de un `.task` que corre UNA vez (no hay `onAppear` ni
    /// `scenePhase` en el fichero), así que sin el refresco de toolbar quien sigue el consejo primario
    /// de esa pantalla —«Actívalo en Ajustes y vuelve a intentar»— se encuentra al volver exactamente
    /// la misma pantalla, sin forma de repetir la búsqueda. Y su población TIENE datos: la puerta que
    /// manda ahí lee `ubiquityIdentityToken`, que mide iCloud **Drive** y no CloudKit.
    ///
    /// `.found` y `.wiped` quedan fuera a propósito y por motivos opuestos: uno ya encontró lo que
    /// buscaba, el otro es una decisión de la persona que repetir la búsqueda no cambia.
    @Test("Los estados que pueden tener datos ofrecen volver a buscar; `.found` y `.wiped` no")
    func everyStateThatMightHaveDataOffersToSearchAgain() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomeRestoreView.swift")
        let cuerpo = try Self.body(of: "private var showRefreshToolbar: Bool {", in: src)

        for estado in [".notFound", ".importIncomplete", ".cloudPaused", ".cloudUnverified",
                       ".iCloudDisabled", ".error"] {
            #expect(cuerpo.contains(estado), Comment(rawValue: """
                `\(estado)` perdió el botón de volver a buscar. En esos estados la búsqueda o no
                concluyó o puede cambiar de desenlace sin que la app haga nada —el kill se conmuta
                desde el backend, la red vuelve, el import termina, iCloud se enciende en Ajustes—, así
                que repetirla es lo único que puede resolverlos.
                """))
        }
        // El control por el otro lado, que es lo que impide «arreglar» esto poniendo `return true`.
        #expect(cuerpo.contains("default: return false"), """
            el gate se abrió para todos. `.searching` con un botón de reintentar encima de su propia
            barra de progreso, y `.found` ofreciendo repetir la búsqueda que acaba de encontrar algo.
            """)
        #expect(!cuerpo.contains(".found") && !cuerpo.contains(".wiped"), """
            `.found` o `.wiped` entraron en la lista: el primero ya encontró lo que buscaba y el
            segundo es una decisión de la persona que volver a buscar no cambia — ahí el botón
            invitaría a deshacer algo que nadie pidió deshacer.
            """)
    }
}
