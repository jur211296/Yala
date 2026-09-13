//
//  WelcomePrivateICloudGateTests.swift
//  YalaTests / CloudSync
//
//  Paso 4 del rediseño de sesiones · «Primera vez → privado» le pregunta a iCloud ANTES de pedir reinicio.
//
//  Cuatro mitades, y la última es la que de verdad protege:
//
//   (A) LA DECISIÓN de la puerta: la tabla entera de `decide`, con cada desenlace por separado.
//   (B) EL AVISO TARDÍO: `decideLateMirror`, incluido el término que decide si se paga la sonda.
//   (C) LOS ARMS: que armar el borrado arme también el neutro durable, que desarmar limpie los dos, y que
//       el par resultante haga lo que la tabla de mounts espera.
//   (D) CABLEADO (source-scan): quién llama a la puerta, en qué orden y desde dónde. La lógica puede estar
//       perfecta y sus tablas verdes mientras nadie la invoca donde hace falta — familia de
//       `AttestWiringTests`. **Y aquí carga más peso que de costumbre:** el bug que este ticket arregla NO
//       era una decisión mal tomada, era una decisión que no se tomaba porque el camino no pasaba por
//       ella.
//
//  **Lo que estos tests NO pueden declarar verificado, y va dicho para que nadie lo lea de más:** ni una
//  sola línea de CloudKit corre aquí. `ICloudPersonalCorpusProbe` habla con un `CKContainer` real, que en
//  simulador y en CI no existe — los tres seams del enum están para poder sustituirlo, no para simularlo.
//  Que la sonda cuente bien los `CD_*`, que `modifyRecordZones` deje el contenedor a cero y que el espejo
//  recree la zona vacía al reabrir son DEVICE-QA, y viven en `tickets/qa/`.
//

import Foundation
import Testing

@testable import Yala

private typealias Gate = WelcomePrivateICloudGateLogic

private func corpus(transactions: Int = 0, accounts: Int = 0, categories: Int = 0,
                    oldest: Date? = nil, truncated: Bool = false) -> ICloudPersonalCorpus {
    ICloudPersonalCorpus(transactions: transactions, accounts: accounts, categories: categories,
                         oldestTransactionDate: oldest, truncated: truncated)
}

// MARK: - (A) La decisión de la puerta

@Suite("Paso 4 · la puerta de iCloud de la rama privada")
struct WelcomePrivateICloudGateDecisionTests {

    @Test("iCloud con datos ⇒ se avisa con las cifras, y NO se sigue solo")
    func foundData_asks() {
        let found = corpus(transactions: 128, accounts: 3)
        let decision = Gate.decide(skipValidation: false, outcome: .measured(found))
        #expect(decision == .foundData(found))
        #expect(!Gate.advancesWithoutAsking(decision), """
            si esto avanzara solo, la pantalla de reinicio volvería a ser ciega y el onboarding se montaría
            encima del histórico — que es el bug entero de este ticket.
            """)
    }

    @Test("iCloud vacío ⇒ onboarding directo, sin aviso (fila «A · iCloud vacío» de la matriz)")
    func emptyICloud_proceeds() {
        let decision = Gate.decide(skipValidation: false, outcome: .measured(.empty))
        #expect(decision == .proceed)
        #expect(Gate.advancesWithoutAsking(decision))
    }

    /// **Las tres cifras cuentan, no solo los movimientos.** Alguien que creó sus cuentas y lo dejó tiene
    /// un corpus real y cero transacciones; tratarlo como «vacío» le borraría los datos sin preguntar.
    @Test("cualquiera de las tres cifras basta para avisar",
          arguments: [corpus(transactions: 1), corpus(accounts: 1), corpus(categories: 1)])
    func anyCountTriggersTheNotice(_ c: ICloudPersonalCorpus) {
        #expect(c.hasAnyData)
        #expect(Gate.decide(skipValidation: false, outcome: .measured(c)) == .foundData(c))
    }

    @Test("sin cuenta de iCloud (estado K) ⇒ se informa y se sigue en local, jamás se bloquea")
    func noAccount_informsAndContinues() {
        let decision = Gate.decide(skipValidation: false, outcome: .noAccount)
        #expect(decision == .noICloud)
        // No avanza SOLO: la persona tiene que leer el aviso y tocar «seguir». Ahí es donde se escribe el
        // testigo del aviso tardío, así que colapsar esto con `.proceed` perdería las dos cosas.
        #expect(!Gate.advancesWithoutAsking(decision))
    }

    /// **La fila que separa «no hay a quién preguntar» de «no pudimos preguntar».** Con red caída el
    /// espejo SÍ se adjunta, así que seguir a ciegas trae el corpus viejo encima en cuanto vuelva la
    /// conexión. Si esta fila cayera en `.proceed` o en `.noICloud`, el bug volvería con otro disfraz.
    @Test("la sonda falla ⇒ se ofrece reintentar, NI se sigue NI se trata como «sin iCloud»")
    func failure_offersRetry() {
        let decision = Gate.decide(skipValidation: false, outcome: .failed("CKError"))
        #expect(decision == .unreachable("CKError"))
        #expect(decision != .proceed)
        #expect(decision != .noICloud)
        #expect(!Gate.advancesWithoutAsking(decision))
    }

    /// El término de hermeticidad va PRIMERO, y esta es su prueba: bajo XCUITest el recorrido queda
    /// byte-idéntico al de antes del ticket **sea cual sea** lo que diga la sonda. Sin esa posición, el
    /// simulador —que no tiene cuenta iCloud— caería en `.noICloud` y todo XCUITest que entre por «Soy
    /// nuevo» vería una pantalla que no existía.
    @Test("bajo UITest la puerta no valida nada y sigue de largo",
          arguments: [ICloudProbeOutcome.noAccount,
                      .failed("boom"),
                      .measured(corpus(transactions: 999, accounts: 9))])
    func uiTest_skipsValidationWhateverTheProbeSays(_ outcome: ICloudProbeOutcome) {
        #expect(Gate.decide(skipValidation: true, outcome: outcome) == .proceed)
    }
}

// MARK: - (B) El aviso del espejo que llega tarde

@Suite("Paso 4 · el espejo que se adjunta TARDE")
struct LateICloudMirrorDecisionTests {

    @Test("sin testigo no se hace nada, aunque haya iCloud y datos")
    func noWitness_isIdle() {
        #expect(Gate.decideLateMirror(
            watching: false, iCloudAvailable: true,
            outcome: .measured(corpus(transactions: 50))) == .idle)
    }

    @Test("con testigo pero sin iCloud todavía: se sigue esperando")
    func noICloudYet_keepsWatching() {
        #expect(Gate.decideLateMirror(watching: true, iCloudAvailable: false, outcome: nil) == .idle)
    }

    @Test("con testigo y datos previos ⇒ se avisa con las cifras")
    func dataFound_asks() {
        let old = corpus(transactions: 300, accounts: 4)
        #expect(Gate.decideLateMirror(
            watching: true, iCloudAvailable: true, outcome: .measured(old)) == .ask(old))
    }

    @Test("con testigo y iCloud vacío ⇒ se retira el testigo: ya no hay nada que vigilar")
    func emptyICloud_standsDown() {
        #expect(Gate.decideLateMirror(
            watching: true, iCloudAvailable: true, outcome: .measured(.empty)) == .standDown)
    }

    /// **`standDown` es lo único que retira el testigo, y por eso un fallo NO puede caer ahí.** Si la
    /// sonda falla por red y el testigo se retirase, el aviso se perdería para siempre: la próxima vez que
    /// el espejo baje el corpus viejo no habría nadie mirando.
    @Test("no se pudo preguntar ⇒ el testigo SIGUE puesto",
          arguments: [ICloudProbeOutcome.failed("network"), .noAccount])
    func probeProblems_keepTheWitness(_ outcome: ICloudProbeOutcome) {
        let decision = Gate.decideLateMirror(watching: true, iCloudAvailable: true, outcome: outcome)
        #expect(decision == .idle)
        #expect(decision != .standDown, "retirar el testigo por un fallo de red pierde el aviso para siempre")
    }
}

// MARK: - (C) Los arms

@Suite("Paso 4 · el arm del borrado y el neutro durable", .serialized)
struct ICloudCorpusWipeArmTests {

    private func freshDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "test.privateICloudGate.\(name).\(UUID().uuidString)"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    @Test("armar el borrado arma TAMBIÉN el neutro durable")
    func arming_alsoArmsTheNeutralMount() {
        let d = freshDefaults()
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(d), "premisa: empieza desarmado")
        #expect(!StorageModePersistence.isNeutralMountArmed(d))

        StorageModePersistence.armICloudCorpusWipe(d)

        #expect(StorageModePersistence.isICloudCorpusWipeArmed(d))
        #expect(StorageModePersistence.isNeutralMountArmed(d), """
            sin el neutro, un kill durante el borrado deja al arranque siguiente montando `.iCloudMirror`
            —el mount neutro dura UN arranque, porque el primero crea el archivo del store— y el espejo
            importa justo el corpus que se estaba borrando.
            """)
    }

    /// El par que el arm deja puesto tiene que significar lo que la tabla de mounts espera. Se comprueba
    /// contra el predicado REAL y no contra su descripción.
    @Test("con el arm puesto y el chooser sin ver, el mount es NEUTRO")
    func armedAndChooserUnseen_mountsNeutral() {
        let d = freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)

        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: StorageModePersistence.isNeutralMountArmed(d),
            hasShownWelcomeChooser: false, groupsOnlySessionArmed: false,
            persistedMode: .icloud, mirrorOffArmed: false))
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
            freshInstall: false,
            neutralDurable: true) == .neutralNoMirror, """
            con iCloud disponible y sin este término la decisión sería `.iCloudMirror`: el espejo adjunto
            durante el borrado es exactamente lo que hay que impedir.
            """)
    }

    /// **El anti-bucle, y no es una precaución: sin él la app gira para siempre.** En cuanto el usuario
    /// cruza el portal, `hasShownWelcomeChooser` queda `true` y el neutro se apaga solo — si no, el
    /// relanzamiento del onboarding privado volvería a montar neutro y volvería a pedir reabrir.
    @Test("en cuanto el chooser se ve, el neutro queda INERTE aunque el arm siga puesto")
    func chooserSeen_makesTheNeutralInert() {
        let d = freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        #expect(!SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: StorageModePersistence.isNeutralMountArmed(d),
            hasShownWelcomeChooser: true, groupsOnlySessionArmed: false,
            persistedMode: .icloud, mirrorOffArmed: false))
    }

    @Test("desarmar limpia los DOS: el arm y el neutro que puso")
    func clearing_removesBoth() {
        let d = freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.clearICloudCorpusWipeArm(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(d))
        #expect(!StorageModePersistence.isNeutralMountArmed(d), """
            un estado que sobrevive a su motivo hace que la próxima lectura de la tabla de mounts
            signifique otra cosa.
            """)
    }

    @Test("re-armar es idempotente (el arranque que reanuda vuelve a armar antes de reintentar)")
    func armingTwice_isIdempotent() {
        let d = freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.clearICloudCorpusWipeArm(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(d))
        #expect(!StorageModePersistence.isNeutralMountArmed(d))
    }

    @Test("el testigo del aviso tardío se pone y se quita por su cuenta")
    func lateWitness_roundTrips() {
        let d = freshDefaults()
        #expect(!StorageModePersistence.privateChoseWithoutICloud(d))
        StorageModePersistence.markPrivateChoseWithoutICloud(d)
        #expect(StorageModePersistence.privateChoseWithoutICloud(d))
        StorageModePersistence.clearPrivateChoseWithoutICloud(d)
        #expect(!StorageModePersistence.privateChoseWithoutICloud(d))
    }

    /// Los dos testigos son INDEPENDIENTES. El del aviso tardío tiene que sobrevivir a un borrado
    /// —alguien puede elegir privado sin iCloud, activarlo, borrar el corpus viejo y seguir— y por eso
    /// `clearICloudCorpusWipeArm` no lo toca: quien lo retira es el desenlace del aviso.
    @Test("desarmar el borrado NO retira el testigo del aviso tardío")
    func clearingTheWipeArm_leavesTheLateWitness() {
        let d = freshDefaults()
        StorageModePersistence.markPrivateChoseWithoutICloud(d)
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.clearICloudCorpusWipeArm(d)
        #expect(StorageModePersistence.privateChoseWithoutICloud(d))
    }
}

// MARK: - (C bis) Las cifras que ve el usuario

/// `@MainActor` porque `countsLine` compone texto con `L10n`, que en este target está aislado al
/// MainActor. Es la misma razón por la que la función de producción no es `nonisolated`.
@Suite("Paso 4 · la línea de cifras del aviso")
@MainActor
struct ICloudCorpusCountsTests {

    @Test("un corpus vacío no dice nada: la línea queda en blanco")
    func emptyCorpus_rendersNothing() {
        #expect(WelcomePrivateICloudGateView.countsLine(.empty).isEmpty)
    }

    /// **Cada cifra tiene que aparecer con su literal.** La primera versión comprobaba
    /// `!line.contains("0 ")`, que no es una aserción sobre la estructura sino sobre los DÍGITOS: pasaba
    /// con `transactions: 12` y se ponía roja con `transactions: 10` sin que producción cambiara.
    @Test("cada cifra presente aparece con su texto, y las ausentes no")
    func onlyPresentCountsAppear() {
        let soloTx = WelcomePrivateICloudGateView.countsLine(corpus(transactions: 12))
        #expect(soloTx == L10n.Welcome.Restore.foundTransactions(12))

        let soloCuentas = WelcomePrivateICloudGateView.countsLine(corpus(accounts: 3))
        #expect(soloCuentas == L10n.Welcome.Restore.foundAccounts(3))
    }

    /// **El hueco que caía justo entre dos tests que sí existían.** `anyCountTriggersTheNotice` prueba
    /// que un corpus de solo categorías DISPARA el aviso; nada probaba qué dice su línea. Y no decía
    /// nada: `Text("")` en medio de una pantalla que pide confirmar un borrado irreversible.
    @Test("un corpus de solo categorías tiene línea, no una cadena vacía")
    func categoriesOnly_stillRenders() {
        let line = WelcomePrivateICloudGateView.countsLine(corpus(categories: 7))
        #expect(!line.isEmpty)
        #expect(line == L10n.Welcome.PrivateICloud.foundCategories(7))
    }

    /// **El tope de la sonda cambia lo que la línea AFIRMA, no cómo se ve.** Con el corpus truncado la
    /// cifra es un mínimo; presentarla como total sería decirle a la persona que tiene menos datos de los
    /// que va a borrar. La primera versión comparaba `full != capped`, que sobrevive a **invertir el
    /// ternario** — el mutante que de verdad importa: las dos líneas siguen siendo distintas, solo que
    /// intercambiadas. Aquí se fija qué literal usa CADA rama.
    @Test("con el corpus truncado la cifra se presenta como un MÍNIMO, y solo entonces")
    func truncatedCorpus_saysAtLeast() {
        let total = WelcomePrivateICloudGateView.countsLine(corpus(transactions: 20_000))
        #expect(total == L10n.Welcome.Restore.foundTransactions(20_000))

        let tope = WelcomePrivateICloudGateView.countsLine(
            corpus(transactions: 20_000, truncated: true))
        #expect(tope == L10n.Welcome.PrivateICloud.foundAtLeast(20_000))
    }

    /// El tope agotado ANTES de llegar a ningún tipo contable: `hasAnyData` lo trata como «sí hay», así
    /// que la línea no puede salir vacía.
    @Test("truncado sin ninguna cifra dice que hay datos, no nada")
    func truncatedWithNoCounts_saysSomething() {
        let c = corpus(truncated: true)
        #expect(c.hasAnyData, "un escaneo cortado significa «no lo sé», nunca «no hay»")
        #expect(WelcomePrivateICloudGateView.countsLine(c)
                == L10n.Welcome.PrivateICloud.foundUnknownAmount)
    }

    @Test("con fecha del más antiguo, la línea añade su fragmento «desde»")
    func oldestDate_appears() {
        let date = Date(timeIntervalSince1970: 1_741_000_000)  // marzo de 2025
        let line = WelcomePrivateICloudGateView.countsLine(corpus(transactions: 5, oldest: date))
        let sinFecha = WelcomePrivateICloudGateView.countsLine(corpus(transactions: 5))
        // Se fija la ESTRUCTURA, no la longitud: comparar `count` pasaba con cualquier cosa más larga —
        // otro template de fecha, la key equivocada, o un separador de más.
        #expect(line.hasPrefix(sinFecha + " · "))
        #expect(line.dropFirst(sinFecha.count + 3).hasPrefix(
            L10n.Welcome.PrivateICloud.foundSince("").trimmingCharacters(in: .whitespaces)))
    }

    /// La lectura hablada y la escrita afirman lo MISMO. Si divergieran, la pantalla y VoiceOver estarían
    /// contando dos cosas distintas sobre unos datos que se van a borrar.
    @Test("la línea de VoiceOver cambia el separador y nada más")
    func voiceOverLine_saysTheSameThing() {
        let c = corpus(transactions: 4, accounts: 2)
        let visible = WelcomePrivateICloudGateView.countsLine(c)
        let hablada = WelcomePrivateICloudGateView.countsLine(c, forVoiceOver: true)
        #expect(hablada == visible.replacingOccurrences(of: " · ", with: ", "))
        #expect(!hablada.contains("·"))
    }
}

// MARK: - (C ter) La sonda, por sus seams

/// **Los tres seams existían y no los usaba nadie**, y eso lo cazó la review adversarial: el `_testReset`
/// tenía un docblock que decía «lo llaman los tests entre casos» y no había una sola llamada. Los seams
/// no están para simular CloudKit —eso es device-QA— sino para poder ejercitar lo que la app hace CON su
/// respuesta, que es código puro y estaba entero sin cubrir.
@Suite("Paso 4 · la sonda y su contrato", .serialized)
@MainActor
struct ICloudPersonalCorpusProbeSeamTests {

    private func withSeams(probe: @escaping @MainActor () async -> ICloudProbeOutcome = { .measured(.empty) },
                           wipe: @escaping @MainActor () async -> String? = { nil },
                           mirrorWillSync: @escaping @MainActor () -> Bool = { true },
                           _ body: () async -> Void) async {
        ICloudPersonalCorpusProbe.probe = probe
        ICloudPersonalCorpusProbe.wipe = wipe
        ICloudPersonalCorpusProbe.mirrorWillSync = mirrorWillSync
        await body()
        ICloudPersonalCorpusProbe._testReset()
    }

    @Test("los seams se reponen: `_testReset` deja los tres como los de producción")
    func testResetRestoresProduction() async {
        await withSeams(probe: { .failed("x") }) {
            #expect(await ICloudPersonalCorpusProbe.probe() == .failed("x"))
        }
        // Tras el reset el seam vuelve a apuntar a la implementación real. No se llama —hablaría con
        // CloudKit— pero sí se comprueba que `mirrorWillSync` volvió a derivar del testigo de mount, que
        // es puro y seguro de invocar.
        #expect(ICloudPersonalCorpusProbe.mirrorWillSync()
                == SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror)
    }

    /// El pre-filtro que la review corrigió: `mirrorWillSync` deriva del testigo de mount, NO de
    /// `ubiquityIdentityToken`. La diferencia es el defecto más grave del primer diseño — el token mide
    /// iCloud **Drive**, y `.localNoMirror` adjunta el espejo igual.
    @Test("el pre-filtro pregunta por el ESPEJO, no por iCloud Drive",
          arguments: [(SwiftDataConfiguration.PersonalStoreDecision.iCloudMirror, true),
                      (.localNoMirror, true),
                      (.neutralNoMirror, false),
                      (.cloudMirrorOff, false)])
    func mirrorWillSync_derivesFromTheMountWitness(
        _ pair: (SwiftDataConfiguration.PersonalStoreDecision, Bool)
    ) {
        #expect(pair.0.attachesCloudKitMirror == pair.1, """
            `.localNoMirror` ADJUNTA el mirror (cae en `cloudKitDatabase: .automatic`, medido en la
            auditoría R1(c)). Si esta fila se invierte, la puerta deja de validar justo a la población
            que el token de ubicuidad clasificaba mal.
            """)
    }

    /// `truncated` es la salvaguarda contra el peor desenlace posible: escaneo cortado ⇒ cifras a cero ⇒
    /// «iCloud vacío» ⇒ borrado sin avisar. Se comprueba contra la DECISIÓN, no solo contra la propiedad.
    @Test("un escaneo truncado nunca se lee como «iCloud vacío»")
    func truncatedNeverReadsAsEmpty() {
        let cortado = corpus(truncated: true)
        #expect(Gate.decide(skipValidation: false, outcome: .measured(cortado)) == .foundData(cortado))
        #expect(Gate.decideLateMirror(watching: true, iCloudAvailable: true,
                                      outcome: .measured(cortado)) == .ask(cortado))
        // Y el control en la dirección contraria: sin truncar, cero cifras SÍ es «vacío».
        #expect(Gate.decide(skipValidation: false, outcome: .measured(.empty)) == .proceed)
        #expect(Gate.decideLateMirror(watching: true, iCloudAvailable: true,
                                      outcome: .measured(.empty)) == .standDown)
    }

    /// La identidad del corpus son sus CIFRAS: dos sondas que miden lo mismo no re-presentan la hoja.
    @Test("`Identifiable` colapsa dos medidas iguales y separa las distintas")
    func corpusIdentityFollowsTheCounts() {
        #expect(corpus(transactions: 3).id == corpus(transactions: 3).id)
        #expect(corpus(transactions: 3).id != corpus(transactions: 4).id)
        #expect(corpus(transactions: 3).id != corpus(transactions: 3, truncated: true).id)
        // La fecha NO entra en la identidad: el espejo puede bajar una fila más vieja entre dos sondas del
        // mismo arranque sin que el hecho cambie.
        #expect(corpus(transactions: 3).id == corpus(transactions: 3, oldest: .now).id)
    }
}

// MARK: - (D) Cableado (source-scan)

@Suite("Paso 4 · cableado de la puerta (source-scan)")
struct WelcomePrivateICloudGateWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// El nombre del método de borrado, PARTIDO a propósito. `SharedStateIsolationTests` barre
    /// `YalaTests/` buscando ese literal para exigirle a toda suite que lo EJECUTA el trait
    /// `.wipeAppGroupMirrorIsolated`, y no distingue una llamada real de una cadena de búsqueda: escrito
    /// entero, esta suite —que solo lee ficheros— aparecía como infractora y ponía el escáner en rojo.
    /// Partirlo es lo que mantiene los dos escáneres compatibles, y es el mismo remedio que
    /// `NeutralMountWiringTests` usa con `ModelConfiguration(`.
    private static let wipeCall = "wipeAll" + "UserData("

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El fichero SIN sus líneas de comentario. Hace falta siempre que se busque la AUSENCIA de algo: el
    /// container documenta en prosa por qué la puerta no puede ser un alert, y esa frase cita el literal
    /// que se está prohibiendo — sin este filtro, explicar el invariante lo incumple.
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo entre llaves balanceadas a partir de un marcador, SIN líneas de comentario. Acotar al cuerpo
    /// no es cosmético: un rango ancho comprobaría que el símbolo EXISTE en el fichero, no que se use
    /// aquí, y contar la prosa haría que documentar el invariante lo «cumpliera».
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
    /// **El pre-filtro del espejo NO puede estar en la puerta**, y es la corrección de una corrección: la
    /// review sustituyó `isICloudAvailable()` por `mirrorWillSync()`, y ese término devuelve `false` para
    /// `.neutralNoMirror` —el mount de TODA instalación fresca, que es la población entera de este
    /// ticket—. Con él, la rama privada volvía a salir del Welcome sin preguntarle nada a iCloud: el bug
    /// original, reintroducido por su propio arreglo.
    ///
    /// El test vive en dos mitades porque el defecto también las tenía: la PROPIEDAD del mount (abajo) y
    /// el CALL-SITE que no debe consultarla (aquí).
    @Test("la puerta no filtra por el espejo: en instalación fresca todavía no hay ninguno")
    func gateDoesNotPreFilterByTheMirror() throws {
        #expect(SwiftDataConfiguration.PersonalStoreDecision.neutralNoMirror.attachesCloudKitMirror == false, """
            premisa: el mount de una instalación fresca NO adjunta espejo — lo adjunta el arranque
            siguiente, tras el relanzamiento.
            """)
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let measure = try Self.body(of: "private func measure() async {", in: src)
        #expect(!measure.contains("mirrorWillSync"), """
            con este pre-filtro la puerta se apaga en instalación fresca —`.neutralNoMirror` da `false`—
            y «Primera vez → privado» vuelve a salir sin validar nada. Quien decide si hay cuenta es
            CloudKit, con su `notAuthenticated`.
            """)
        #expect(!measure.contains("isICloudAvailable"), """
            y tampoco el token de ubicuidad, que mide iCloud DRIVE: con Drive apagado y CloudKit vivo, el
            espejo baja el histórico igual.
            """)
        // El control en la dirección contraria: el camino TARDÍO sí tiene que filtrar por el espejo,
        // porque allí la pregunta es si hay algo bajando AHORA.
        let cv = try Self.code("Yala/App/ContentView.swift")
        let late = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: cv)
        #expect(late.contains("mirrorWillSync()"), """
            sin espejo adjunto no hay nada que pueda caer encima del onboarding recién hecho: sondear ahí
            sería pagar red en cada arranque para nada.
            """)
    }

    /// **EL PIN DEL BUG.** Hasta el 2026-09-10 la card privada llamaba a `leaveWelcome(.privateOnboarding)`
    /// directo, y con el mount neutro eso persiste el destino sin ejecutar `onSelectPrivateAccount` — el
    /// único callback que consultaba si había datos. Resultado medido en device: pantalla de reinicio
    /// ciega y onboarding sobre un histórico intacto. Si alguien devuelve esa llamada a su sitio, el bug
    /// vuelve **sin ningún otro rojo**: el recorrido sigue funcionando, solo que sin preguntar.
    @Test("la card privada va a la PUERTA, no directa al portal")
    func privateCard_goesThroughTheGate() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let handler = try Self.body(of: "private func handleNewOption(_ option: WelcomeAccountChoiceLogic.NewOption) {",
                                    in: src)
        let privateCase = try #require(handler.range(of: "case .privateAccount:"))
        let cloudCase = try #require(handler.range(of: "case .cloudAccount:"))
        let branch = String(handler[privateCase.upperBound..<cloudCase.lowerBound])
        #expect(branch.contains("goTo(.privateICloudGate)"), """
            la rama privada tiene que entrar a la puerta. Sin esto, «Primera vez → privado» vuelve a pedir
            reinicio sin haberle preguntado a iCloud (ADR §9, punto 4).
            """)
        // El literal que se prohíbe VIVE en un comentario de esta misma rama («es el mismo
        // `leaveWelcome(to: .privateOnboarding)` de siempre»), así que se busca sobre el cuerpo ya
        // filtrado —`body(of:)` quita las líneas de comentario— y además se ancla al PREFIJO de línea:
        // un comentario al final de línea no lo filtra nadie.
        for line in branch.split(separator: "\n") {
            #expect(!line.trimmingCharacters(in: .whitespaces).hasPrefix("leaveWelcome(to: .privateOnboarding)"), """
                salir por el portal desde la card es exactamente el bug: con el mount neutro el portal
                persiste el destino y NO llama a `onSelectPrivateAccount`, así que nadie comprueba nada.
                """)
        }
    }

    /// La puerta no sustituye al portal, va delante: su `onProceed` sigue siendo la misma salida de
    /// siempre. Si la puerta saliera del cover por su cuenta, el relanzamiento del mirror se perdería y el
    /// onboarding privado correría sobre un store sin espejo.
    @Test("el `onProceed` de la puerta cruza el portal, y su `onRestore` reusa el helper existente")
    func gateProceed_crossesThePortal() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        // **Se acota al bloque del step y no al `case`**: `body(of:)` cuenta llaves desde un marcador, y
        // `case .privateICloudGate:` no abre ninguna — recorrería hasta cerrar el `switch` entero y el
        // literal que se busca es IDÉNTICO al del step de al lado (`.privateSecondaryNotice`), así que el
        // test se cumpliría desde el vecino.
        let step = try Self.body(of: "WelcomePrivateICloudGateView(", in: src)
        #expect(step.contains("leaveWelcome(to: .privateOnboarding) { onSelectPrivateAccount() }"))
        #expect(step.contains("handleExistingOption(.restoreICloud)"), """
            la tercera salida del aviso («esto es mío, restauralo») tiene que reusar el helper que YA
            traduce restaurar a su `Destination`; escribir la traducción otra vez es como divergen dos
            caminos que deben acabar en la misma pantalla.
            """)
        #expect(step.contains("performWipe: performICloudCorpusWipe"), """
            la puerta no borra: el borrado necesita el `modelContext` porque tiene que llevarse también
            las filas que el espejo hubiera bajado ya.
            """)
    }

    /// La puerta es una PANTALLA. Un `.alert` desde el anchor de `ContentView` desmonta el cover del
    /// Welcome (medido el 2026-09-03, `ShellDataAlertsModifier`), y aquí eso se llevaría por delante el
    /// chooser al que «cancelar» promete volver.
    @Test("la puerta no monta un `.alert(` en el container")
    func gateIsAScreenAndNeverAnAlert() throws {
        let container = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        #expect(!container.contains(".alert("),
                "un alert aquí desmonta el cover y «cancelar» se queda sin chooser al que volver")
        #expect(container.contains("case .privateICloudGate:"),
                "el step tiene que RENDERIZARSE, no solo estar declarado en el enum")
    }

    /// **El orden del arranque, y no es preferencia.** Y su corrección: el destino pendiente GANA, porque
    /// quien abandonó la puerta y pidió restaurar expresó su voluntad después — hacer ganar al arm le
    /// borraría justo lo que acaba de pedir recuperar.
    @Test("el arm manda salvo que haya un destino pendiente, que es más reciente")
    func startup_checksTheWipeArmFirst() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let present = try Self.body(of: "private func presentNextOnboardingScreen() {", in: src)
        let arm = try #require(present.range(of: "StorageModePersistence.isICloudCorpusWipeArmed()"), """
            sin esta lectura, matar la app a mitad del borrado deja el arm puesto y a nadie mirándolo.
            """)
        let pending = try #require(present.range(of: "WelcomePendingDestinationStore.consume()"))
        #expect(arm.lowerBound < pending.lowerBound)
        let chooser = try #require(present.range(of: "!hasShownWelcomeChooser"))
        #expect(arm.lowerBound < chooser.lowerBound)
        // Y lo que la rama HACE, no solo dónde está: mandarla al `.hero` dejaría el arm sin consumidor.
        let rama = String(present[arm.lowerBound..<pending.lowerBound])
        #expect(rama.contains("welcomeFlowInitialStep = .privateICloudGate"))
        #expect(rama.contains("showWelcomeFlow = true"))
        #expect(rama.contains("WelcomePendingDestinationStore.peek() == nil"), """
            sin este término el arm pisa un destino que el usuario eligió DESPUÉS de abandonarlo: pidió
            restaurar de iCloud y se le borra el corpus que quería recuperar.
            """)
        #expect(rama.contains("clearICloudCorpusWipeArm()"), """
            si el destino gana, la petición de borrado ya no está en pie y su arm tiene que irse con ella.
            """)
    }

    /// El aviso tardío corre en la población CONTRARIA a la de la puerta: quien ya completó su onboarding
    /// en este device. Si colgara de `presentNextOnboardingScreen` no se ejecutaría nunca para ellos.
    @Test("el aviso tardío se dispara en los post-checks del returning user")
    func lateNotice_runsForReturningUsers() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let checks = try Self.body(of: "private func runReturningUserPostChecks() {", in: src)
        #expect(checks.contains("runLateICloudMirrorCheck()"))
    }

    /// **El borrado es UNO para los dos caminos, y no puede reusar solo la zona de CloudKit.** La puerta
    /// es alcanzable con el espejo ya adjunto, así que borrar solo la zona dejaría el corpus viejo entero
    /// en el dispositivo.
    @Test("el borrado unificado toca la zona de iCloud Y el store local, y respeta la quiescencia")
    func wipe_clearsBothSides() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        // Paso 8 · la firma ganó `includingLocalRows` (la activación de Yala completo borra solo la zona). Su
        // DEFAULT es `true`, y es lo que mantiene este test con sentido: la puerta del Welcome y el aviso
        // tardío la llaman sin argumento y siguen borrando los dos lados.
        let wipe = try Self.body(
            of: "private func performICloudCorpusWipe(includingLocalRows: Bool = true) async -> String? {",
            in: src)
        #expect(wipe.contains("ICloudPersonalCorpusProbe.wipe()"))
        #expect(wipe.contains("DataWipeService." + Self.wipeCall))
        #expect(wipe.contains("waitForImportQuiescence"), """
            un `save()` de SwiftData durante un import de CloudKit dispara el SIGTRAP que ese gate existe
            para evitar, y borrar la zona con el import a medias deja al espejo re-creando filas.
            """)
        // **El resultado de la espera se MIRA.** Descartarlo con `_ =` y seguir al agotar el tope es el
        // crash-loop: con un corpus grande el timeout es el caso NORMAL.
        let linea = try #require(wipe.split(separator: "\n")
            .first(where: { $0.contains("waitForImportQuiescence") }))
        #expect(linea.contains("guard"), """
            el veredicto de la quiescencia tiene que CORTAR el borrado, no solo consultarse: descartarlo
            con `_ =` y seguir al agotar el tope es el crash-loop —con un corpus grande el timeout es el
            caso NORMAL, y detrás viene un `save()` durante el import.
            Línea: \(linea)
            """)
        #expect(!wipe.contains("wipeLocalGroupsDomain"), """
            Grupos vive en OTRO contenedor de CloudKit y el ADR §6 lo deja fuera de todo borrado. Esto no
            es un handover de dispositivo: es la misma persona limpiando su propio histórico.
            """)
    }

    /// El orden kill-safe: **armar antes de la primera llamada, desarmar después de que confirme**. Al
    /// revés, un kill entre el borrado y el arm deja el contenedor a medias sin nadie que reintente.
    @Test("la puerta arma ANTES de tocar CloudKit, y el fallo SALE sin desarmar")
    func wipe_armsBeforeAndDisarmsAfter() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let wipe = try Self.body(of: "private func wipe() async {", in: src)
        let arm = try #require(wipe.range(of: "armICloudCorpusWipe()"))
        let call = try #require(wipe.range(of: "await performWipe()"))
        let clear = try #require(wipe.range(of: "clearICloudCorpusWipeArm()"))
        #expect(arm.lowerBound < call.lowerBound, "armar después de llamar deja la ventana sin cubrir")
        #expect(call.lowerBound < clear.lowerBound, "desarmar es SIEMPRE el último paso")
        // **El control de FLUJO, no solo las posiciones.** Comparar índices sobrevive a borrar el `return`
        // de la rama de fallo — y sin ese corte, un borrado fallido desarma y avanza al onboarding con el
        // corpus intacto, que es el peor desenlace del fichero.
        let fallo = try #require(wipe.range(of: "guard failure == nil else {"))
        #expect(fallo.lowerBound < clear.lowerBound)
        let cuerpoFallo = String(wipe[fallo.upperBound...]).prefix(while: { $0 != "}" })
        #expect(cuerpoFallo.contains("phase = .wipeFailed"))
        #expect(cuerpoFallo.contains("return"), """
            sin el `return`, el fallo cae en el desarme y en `onProceed()`: la persona acaba en el
            onboarding creyendo que borró un corpus que sigue entero en su iCloud.
            """)
    }

    /// El testigo del aviso tardío se escribe cuando la persona CONTINÚA, no al entrar en la rama. Quien
    /// retrocede al chooser no ha elegido nada y no debe dejar marca.
    @Test("el testigo del aviso tardío se escribe en UN solo sitio: el que continúa")
    func lateWitness_writtenOnContinueOnly() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let occurrences = src.components(separatedBy: "markPrivateChoseWithoutICloud()").count - 1
        #expect(occurrences == 1, "un segundo sitio que lo escriba es como diverge de su significado")
        let helper = try Self.body(of: "private func continueWithoutValidating() {", in: src)
        #expect(helper.contains("markPrivateChoseWithoutICloud()"))
        #expect(helper.contains("onProceed()"))
        // Y sus DOS consumidores: sin cuenta y sin red. La segunda es la que impidió que `.unreachable`
        // fuera un camino muerto — sin ella, un primer arranque sin conexión no podía entrar en la app.
        let content = try Self.body(of: "private var content: some View {", in: src)
        for rama in ["case .noICloud:", "case .unreachable:"] {
            let idx = try #require(content.range(of: rama))
            let hasta = content.range(of: "case .", range: idx.upperBound..<content.endIndex)?.lowerBound
                ?? content.endIndex
            #expect(String(content[idx.upperBound..<hasta]).contains("continueWithoutValidating"), """
                \(rama) no ofrece seguir: el ADR dice que no poder preguntar JAMÁS bloquea, y un botón que
                solo puede reintentar sí bloquea.
                """)
        }
    }

    /// El sheet nuevo cuelga del anchor de `ContentView`, así que la regla (3) de Presentaciones exige que
    /// entre en la matriz de readiness — y con la CONDICIÓN VIVA, no con un `@State` de red visual.
    @Test("el aviso tardío es blocker de la matriz de readiness, y lo devuelve `blocker()`")
    func lateNotice_blocksReadiness() throws {
        let logic = try Self.source("Yala/App/Logic/ContentViewReadinessLogic.swift")
        // No basta con que el campo EXISTA: tiene que devolverlo el resolvedor.
        let blocker = try Self.body(of: "static func blocker(", in: logic)
        #expect(blocker.contains("state.showLateICloudNotice"), """
            declarar el campo sin ramificar en `blocker()` deja la matriz ciega: el router presentaría
            debajo del aviso, y dentro de él vive un borrado irreversible.
            """)
        let observers = try Self.source("Yala/App/Views/Shared/ReadinessGateObservers.swift")
        #expect(observers.contains(".onChange(of: showLateICloudNotice)"))
        // Y la condición viva en el call-site, no un flag paralelo que pueda divergir.
        let cv = try Self.code("Yala/App/ContentView.swift")
        #expect(cv.contains("showLateICloudNotice: lateICloudCorpus != nil"))
    }

    /// **Un borrado reanudado tiene que CERRAR su ciclo.** `performICloudCorpusWipe` no retira los
    /// testigos —los retiran las vistas al acabar su fase—, así que sin esto un reanudado con éxito deja
    /// el arm puesto y el arranque siguiente vuelve a reanudarlo: bucle en cada apertura de la app.
    @Test("el borrado reanudado retira sus testigos y reabre el onboarding")
    func resumedWipe_closesItsCycle() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: src)
        let arm = try #require(check.range(of: "isICloudCorpusWipeArmed()"))
        let bloque = String(check[arm.lowerBound...])
        let hasta = bloque.range(of: "let watching")?.lowerBound ?? bloque.endIndex
        let rama = String(bloque[..<hasta])
        #expect(rama.contains("performICloudCorpusWipe()"))
        #expect(rama.contains("clearICloudCorpusWipeArm()"), """
            sin retirar el arm, el arranque siguiente vuelve a reanudar el mismo borrado, y el siguiente,
            y el siguiente.
            """)
        #expect(rama.contains("clearPrivateChoseWithoutICloud()"))
        #expect(rama.contains("hasCompletedOnboarding = false"),
                "el borrado se llevó el corpus: la persona tiene que volver al onboarding")
        // Y el corte ante el fallo: si el borrado no confirma, NO se retira nada.
        #expect(rama.contains("guard await performICloudCorpusWipe() == nil else { return }"), """
            retirar los testigos tras un borrado fallido deja el corpus en iCloud y a nadie mirándolo.
            """)
    }

    /// El aviso tardío se presenta por el ROUTER. Encender el `@State` a pelo desde un `Task` async es la
    /// regla (3) de Presentaciones: para cuando la sonda contesta, el anchor puede estar presentando el
    /// cover de idioma o el sheet del trial.
    @Test("el aviso tardío entra por el router, no encendiendo el estado a pelo")
    func lateNotice_goesThroughTheRouter() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: src)
        #expect(check.contains("RouterEntryGate.shared.submit(.presentLateICloudMirrorNotice"))
        #expect(!check.contains("lateICloudCorpus ="), """
            asignar el corpus aquí salta la matriz de readiness: el sheet se montaría encima de lo que el
            anchor estuviera presentando.
            """)
    }

    /// **El copy tiene que nombrar iCloud** (decisión de Jürgen, 2026-09-09): los datos están en tu iCloud
    /// y borrarlos los quita de iCloud, no solo de este teléfono. Reusar el alert viejo
    /// (`welcome.freshStart.*`, «Detectamos datos previos en tu dispositivo») diría otra cosa.
    @Test("el copy de la puerta es propio y nombra iCloud")
    func copy_isOwnAndNamesICloud() throws {
        // **Se comprueba el VALOR, no la línea entera.** La primera versión miraba la línea completa del
        // `.strings`, clave incluida — y todas las claves son `welcome.privateICloud.*`, así que el
        // substring «iCloud» venía en el nombre: el test pasaba con el valor puesto a `"xxx"`. Era la
        // ÚNICA red de una decisión de producto de Jürgen, y no podía fallar.
        //
        // Y se comprueban los DOS idiomas de referencia, porque la decisión es del copy y no del
        // castellano: `LocalizationParityTests` cubre que la clave EXISTA en los 16, nunca qué dice.
        for locale in ["es-419", "en"] {
            let strings = try Self.source("Yala/Resources/\(locale).lproj/Localizable.strings")
            for key in ["welcome.privateICloud.foundTitle", "welcome.privateICloud.foundBody",
                        "welcome.privateICloud.wipeConfirmBody", "welcome.privateICloud.lateBody",
                        "welcome.privateICloud.noAccountBody"] {
                let line = try #require(strings.split(separator: "\n").first(where: { $0.contains(key) }),
                                        "falta la key \(key) en \(locale)")
                let value = try #require(line.split(separator: "=").last.map(String.init),
                                         "línea sin valor: \(line)")
                #expect(value.localizedCaseInsensitiveContains("iCloud"), """
                    \(key) [\(locale)] no nombra iCloud en su VALOR: \(value)
                    La persona tiene que saber que lo que se borra sale de su iCloud y no solo de este
                    teléfono — es irreversible y el copy tiene que decirlo (decisión de Jürgen, 2026-09-09).
                    """)
            }
        }
        // `code` y no `source`: el escáner busca una AUSENCIA, y documentar por qué no se reusa aquella
        // clave lo pondría rojo sin que producción cambiara.
        for file in ["Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift",
                     "Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift"] {
            #expect(!(try Self.code(file)).contains("L10n.Welcome.FreshStart."), """
                \(file) reusa el copy de «empiezo de cero», que describe otro hecho y promete otra
                consecuencia: aquel alert habla de datos en el DISPOSITIVO.
                """)
        }
    }
}
