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
        let decision = Gate.decide(skipValidation: false, outcome: .measured(found), deviceHasData: false)
        #expect(decision == .foundData(found))
        #expect(!Gate.advancesWithoutAsking(decision), """
            si esto avanzara solo, la pantalla de reinicio volvería a ser ciega y el onboarding se montaría
            encima del histórico — que es el bug entero de este ticket.
            """)
    }

    @Test("iCloud vacío ⇒ onboarding directo, sin aviso (fila «A · iCloud vacío» de la matriz)")
    func emptyICloud_proceeds() {
        let decision = Gate.decide(skipValidation: false, outcome: .measured(.empty), deviceHasData: false)
        #expect(decision == .proceed)
        #expect(Gate.advancesWithoutAsking(decision))
    }

    /// **Las tres cifras cuentan, no solo los movimientos.** Alguien que creó sus cuentas y lo dejó tiene
    /// un corpus real y cero transacciones; tratarlo como «vacío» le borraría los datos sin preguntar.
    @Test("cualquiera de las tres cifras basta para avisar",
          arguments: [corpus(transactions: 1), corpus(accounts: 1), corpus(categories: 1)])
    func anyCountTriggersTheNotice(_ c: ICloudPersonalCorpus) {
        #expect(c.hasAnyData)
        #expect(Gate.decide(skipValidation: false, outcome: .measured(c), deviceHasData: false) == .foundData(c))
    }

    @Test("sin cuenta de iCloud (estado K) ⇒ se informa y se sigue en local, jamás se bloquea")
    func noAccount_informsAndContinues() {
        let decision = Gate.decide(skipValidation: false, outcome: .noAccount, deviceHasData: false)
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
        let decision = Gate.decide(skipValidation: false, outcome: .failed("CKError"), deviceHasData: false)
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
                      .measured(corpus(transactions: 999, accounts: 9))],
          [false, true])
    func uiTest_skipsValidationWhateverTheProbeSays(_ outcome: ICloudProbeOutcome,
                                                   _ deviceHasData: Bool) {
        // **El término del teléfono se barre en los DOS valores, y por eso el argumento es una matriz.**
        // Con `true` fijo en `false` este test pasaría aunque el corpus local se colara por delante de la
        // hermeticidad — y ese es justo el modo de fallo que rompería `WelcomeFreshStartAlertUITests`, que
        // entra por aquí CON datos sembrados.
        #expect(Gate.decide(skipValidation: true,
                            outcome: outcome,
                            deviceHasData: deviceHasData) == .proceed)
    }
}

// MARK: - (A2) El corpus que ya está en el TELÉFONO

/// **El hueco que este ticket cierra.** Una sesión solo-grupos monta el store personal neutro en todos sus
/// arranques, así que «Primera vez → privado» sale por el relanzamiento y nunca llega al
/// `onSelectPrivateAccount` que levantaba el alert de datos existentes. El aviso se perdía entero: ni
/// alert, ni borrado, ni sello de handover — y el corpus de la etapa anterior subía al iCloud del Apple ID
/// en el arranque siguiente.
@Suite("Paso 5 · el corpus que ya está en el teléfono")
struct WelcomePrivateGateDeviceCorpusTests {

    @Test("iCloud vacío pero el teléfono con datos ⇒ se avisa, y NO se sigue solo")
    func deviceData_asks() {
        let decision = Gate.decide(skipValidation: false,
                                   outcome: .measured(.empty),
                                   deviceHasData: true)
        #expect(decision == .foundDeviceData(iCloudUnverified: false))
        #expect(!Gate.advancesWithoutAsking(decision), """
            si esto avanzara solo volvería el bug entero: relanzamiento ciego, onboarding «de cero» montado
            encima de los grupos y las categorías de la etapa anterior, y ese corpus subiendo a iCloud en
            el arranque siguiente.
            """)
    }

    /// **La fila que el estado K se comía.** Sin cuenta de iCloud la puerta informaba y seguía, y ese
    /// «seguir» se llevaba por delante el aviso de lo que hay AQUÍ — que no necesita ninguna red para
    /// contarse.
    @Test("sin cuenta de iCloud, el corpus del teléfono gana al estado K")
    func noAccount_withDeviceData_stillAsks() {
        let decision = Gate.decide(skipValidation: false, outcome: .noAccount, deviceHasData: true)
        #expect(decision == .foundDeviceData(iCloudUnverified: true))
        #expect(decision != .noICloud)
    }

    /// Igual con la red caída: el remedio de `.unreachable` es reintentar CloudKit, y eso no dice nada de
    /// las filas que ya están en el disco.
    @Test("con la sonda caída, el corpus del teléfono gana a «reintentar»")
    func failure_withDeviceData_stillAsks() {
        let decision = Gate.decide(skipValidation: false,
                                   outcome: .failed("CKError"),
                                   deviceHasData: true)
        #expect(decision == .foundDeviceData(iCloudUnverified: true))
        #expect(decision != .unreachable("CKError"))
    }

    /// **`iCloudUnverified` es el término que impide que el bug vuelva por detrás.** Cuando a iCloud sí se
    /// le pudo preguntar va en `false` y el camino termina en `onProceed`; cuando no, en `true` y termina
    /// en `continueWithoutValidating`, que deja escrito el testigo del espejo tardío. Sin esa distinción,
    /// quien borra lo suyo sin red se come el histórico del Apple ID el día que iCloud vuelva.
    @Test("el término «no pudimos preguntar» viaja con la decisión",
          arguments: [(ICloudProbeOutcome.measured(.empty), false),
                      (.noAccount, true),
                      (.failed("boom"), true)])
    func unverifiedFlagFollowsTheProbe(_ outcome: ICloudProbeOutcome, _ expected: Bool) {
        #expect(Gate.decide(skipValidation: false, outcome: outcome, deviceHasData: true)
                == .foundDeviceData(iCloudUnverified: expected))
    }

    /// **El corpus REMOTO gana cuando los dos tienen datos**, y no es un empate resuelto a cara o cruz: el
    /// aviso de iCloud es el único que ofrece «traer mis datos» —la salida que no destruye nada— y su
    /// borrado ya se lleva las filas locales por delante. Avisar primero del teléfono escondería la única
    /// salida reversible.
    @Test("con datos en los dos sitios manda el aviso de iCloud")
    func remoteWins() {
        let found = corpus(transactions: 40, accounts: 2)
        #expect(Gate.decide(skipValidation: false,
                            outcome: .measured(found),
                            deviceHasData: true) == .foundData(found))
    }

    /// El control negativo de toda la familia: sin datos en ninguno de los dos lados, la puerta sigue
    /// haciendo lo de siempre. Si esto se pusiera rojo, el término nuevo estaría avisando a quien acaba de
    /// instalar la app.
    @Test("instalación fresca de verdad: ni aviso ni pantalla nueva")
    func freshInstall_stillProceeds() {
        let decision = Gate.decide(skipValidation: false,
                                   outcome: .measured(.empty),
                                   deviceHasData: false)
        #expect(decision == .proceed)
        #expect(Gate.advancesWithoutAsking(decision))
    }

    /// Y la otra mitad del control negativo: **ninguna decisión del corpus del teléfono avanza sola.** Es
    /// el invariante que este ticket existe para restaurar, y se afirma sobre los dos valores del término
    /// en vez de sobre uno.
    @Test("ningún aviso del teléfono avanza sin que la persona lo diga",
          arguments: [false, true])
    func deviceNoticeNeverAdvancesAlone(_ unverified: Bool) {
        #expect(!Gate.advancesWithoutAsking(.foundDeviceData(iCloudUnverified: unverified)))
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
        #expect(Gate.decide(skipValidation: false, outcome: .measured(cortado), deviceHasData: false)
                == .foundData(cortado))
        #expect(Gate.decideLateMirror(watching: true, iCloudAvailable: true,
                                      outcome: .measured(cortado)) == .ask(cortado))
        // Y el control en la dirección contraria: sin truncar, cero cifras SÍ es «vacío».
        #expect(Gate.decide(skipValidation: false, outcome: .measured(.empty), deviceHasData: false) == .proceed)
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

    /// Dos literales y su ORDEN. Comparar posiciones y no solo presencia es lo que separa «las dos líneas
    /// están» de «la que protege va antes».
    private static func expectOrder(_ first: String, before second: String, in source: String,
                                    _ why: String,
                                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        let a = try #require(source.range(of: first), "no está: \(first)")
        let b = try #require(source.range(of: second), "no está: \(second)")
        #expect(a.lowerBound < b.lowerBound, Comment(rawValue: why), sourceLocation: sourceLocation)
    }

    /// **El par identificador ↔ acción de un botón.** Acota al tramo que va del identificador hacia atrás
    /// hasta su propio `Button`/`YalaPrimaryButton`/`destructiveButton`, que es donde vive la acción. Un
    /// `contains` suelto sobre la función entera pasa con los dos botones INTERCAMBIADOS — mismo copy,
    /// mismos identificadores, y el que conserva borrando.
    private static func expectAction(in source: String, identifier: String, does action: String,
                                     why: String,
                                     sourceLocation: SourceLocation = #_sourceLocation) throws {
        // **El cuerpo se SEGMENTA por abridores de botón, y no se mira «hacia atrás» desde el
        // identificador.** Los dos moldes del fichero lo colocan en sitios opuestos: `YalaPrimaryButton`
        // lo lleva como modificador DESPUÉS de su closure, y `destructiveButton` como argumento ANTES.
        // Un tramo que solo mire hacia atrás deja fuera la acción del segundo, y el test falla sobre
        // código correcto.
        var segmentos: [String] = []
        var actual = ""
        for linea in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let esAbridor = linea.contains("YalaPrimaryButton(") || linea.contains("destructiveButton(")
            if esAbridor, !actual.isEmpty {
                segmentos.append(actual)
                actual = ""
            }
            actual += linea + "\n"
        }
        segmentos.append(actual)
        let bloque = try #require(segmentos.first(where: { $0.contains("\"\(identifier)\"") }),
                                  "no está el identificador \(identifier)")
        #expect(bloque.contains(action), Comment(rawValue: """
            \(identifier) dejó de hacer `\(action)`. \(why).
            Bloque leído: \(bloque)
            """), sourceLocation: sourceLocation)
    }

    /// **Los argumentos de UNA llamada, por paréntesis balanceados.** `body(of:)` cuenta LLAVES, así que
    /// sobre un marcador que abre un paréntesis —`WelcomePrivateICloudGateView(`— no acota la llamada:
    /// para en el primer `}` desbalanceado, que es el del `switch` de más arriba, y devuelve 13 o 37
    /// líneas del vecindario. Hoy no muerde porque los literales que se buscan son únicos, pero una
    /// aserción positiva sobre un rango que no es el que dice es exactamente cómo un scan empieza a
    /// cumplirse desde el `case` de al lado.
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

    /// Tramo entre dos marcadores, SIN líneas de comentario. Para leer un `case` de un `switch`, donde no
    /// hay llaves que balancear: `call(of:)` devolvería siempre la primera llamada del fichero y dejaría
    /// sin vigilar a la segunda puerta.
    private static func segment(from start: String, to end: String, in source: String) throws -> String {
        let a = try #require(source.range(of: start), "marcador no encontrado: \(start)")
        let b = try #require(source.range(of: end, range: a.upperBound..<source.endIndex),
                             "marcador de cierre no encontrado tras \(start): \(end)")
        return source[a.upperBound..<b.lowerBound]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

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
        let step = try Self.call(of: "WelcomePrivateICloudGateView(", in: src)
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
        // **El Welcome pregunta por el corpus del TELÉFONO, y la activación no.** Es el par que cierra el
        // hueco de `groups-only-private-restart-skips-the-wipe-alert`: sin este término, la rama privada
        // de un device solo-grupos sale por el relanzamiento sin que nadie haya mirado si aquí ya hay
        // datos, y el aviso de datos existentes se pierde entero.
        #expect(step.contains("deviceCorpus: deviceCorpusGate"), """
            el Welcome dejó de preguntar por lo que ya hay en el teléfono: con el mount neutro esta rama
            sale por el relanzamiento y NUNCA llega a `onSelectPrivateAccount`, que era quien levantaba el
            alert de datos existentes.
            """)
        // **Y aquí SÍ se sigue cuando iCloud no contesta**, que es la otra mitad del par del 2026-09-14:
        // quien llega a esta pantalla acaba de elegir «privado» y no ha pedido borrar nada, así que no hay
        // ningún borrado que declarar. Con el desenlace de la otra puerta, este camino volvería al chooser
        // y el primer arranque sin conexión no tendría por dónde entrar en la app — las otras dos ramas
        // también necesitan red.
        #expect(step.contains("unverifiedExit: .proceedWatchingTheMirror"), """
            el Welcome dejó de ofrecer seguir cuando a iCloud no se le pudo preguntar. El ADR es explícito:
            no poder validar JAMÁS bloquea, y sin esa salida esta pantalla es un camino muerto.
            Tramo leído: \(step)
            """)
        let gate = try Self.body(of: "private var deviceCorpusGate: WelcomePrivateICloudGateView.DeviceCorpus? {",
                                 in: src)
        #expect(gate.contains("wipe: { await performDeviceCorpusWipe() }"), """
            el aviso sin su borrado es un camino muerto: la persona confirma dos veces y no se borra nada.
            """)
        #expect(gate.contains("hasData: { hasLocalDataNow() }"), """
            el fetch tiene que ir VIVO: el espejo puede estar re-importando mientras esta pantalla está
            montada, y un snapshot del arranque diría «no hay datos» sobre un store que se está llenando.
            """)
    }

    /// **El término del teléfono se enciende SOLO cuando este camino se salta el alert, y son las dos
    /// caras del mismo hueco.** Con `shouldRelaunch == false` el portal llama a `proceed()`, corre
    /// `onSelectPrivateAccount` y el alert de `startFreshPrivateOnboarding` hace su trabajo: preguntar
    /// aquí sería enseñar DOS avisos del mismo hecho.
    ///
    /// **Y la razón dura, que es la que este test protege de verdad** (`.claude/rules/swiftdata-cloudkit
    /// .md`, «ARCHIVOS, nunca FILAS»): el borrado que cuelga del aviso quita FILAS, y con el espejo
    /// montado los deletes se quedan en la History y se EXPORTAN — vaciarían el iCloud de la persona en
    /// todos sus dispositivos. El mount neutro es `cloudKitDatabase: .none` explícito, así que en la
    /// única celda donde este término se enciende no hay espejo que pueda exportar nada. Si alguien
    /// ensancha el predicado, ese es el daño que aparece.
    @Test("el aviso del teléfono va atado al MISMO predicado que el relanzamiento")
    func deviceNoticeIsGatedByTheRelaunchPredicate() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let gate = try Self.body(of: "private var deviceCorpusGate: WelcomePrivateICloudGateView.DeviceCorpus? {",
                                 in: src)
        #expect(gate.contains("WelcomeMirrorRelaunchLogic.shouldRelaunch("), """
            sin este guard el aviso saldría también con el espejo MONTADO, y su borrado por filas
            exportaría los deletes: el iCloud de la persona vaciado en todos sus dispositivos.
            """)
        #expect(gate.contains("destination: .privateOnboarding"))
        #expect(gate.contains("mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision"), """
            el predicado tiene que leer el testigo del mount de ESTE proceso, no una versión propia.
            """)
        #expect(gate.contains("else { return nil }"), """
            fuera del mount neutro la puerta no puede recibir corpus: ahí el aviso ya lo da el alert.
            """)
        // La premisa que sostiene todo lo anterior, afirmada y no supuesta: el único mount que dispara el
        // relanzamiento de esta rama es el neutro, y el neutro no adjunta espejo.
        #expect(WelcomeMirrorRelaunchLogic.shouldRelaunch(
            destination: .privateOnboarding, mountedDecision: .neutralNoMirror))
        #expect(SwiftDataConfiguration.PersonalStoreDecision.neutralNoMirror.attachesCloudKitMirror == false)
        // `allCases` y no una lista escrita a mano: un mount NUEVO tiene que caer en esta comprobación
        // solo, o el día que alguien añada uno el aviso podría encenderse sobre un store que espeja.
        for mount in SwiftDataConfiguration.PersonalStoreDecision.allCases where mount != .neutralNoMirror {
            #expect(!WelcomeMirrorRelaunchLogic.shouldRelaunch(destination: .privateOnboarding,
                                                              mountedDecision: mount), """
                \(mount) dispararía el aviso del teléfono, y su borrado por filas exportaría los deletes.
                """)
        }
    }

    /// **La otra mitad del par, y la que protege el daño CONTRARIO.** La activación de «Yala completo»
    /// monta la misma puerta desde una sesión solo-grupos, y ahí los datos del teléfono son de la persona
    /// que está activando: preguntarle si los borra —y peor, borrarlos— se llevaría justo el corpus que
    /// esa pantalla existe para conservar.
    ///
    /// **Y recorre las DOS puertas, no la primera.** Desde el 2026-09-14 `FullModeActivationView` monta
    /// esta vista dos veces —`.privateGate` y `.restoreDiscardGate`— y un `call(of:)` suelto solo lee la
    /// de arriba: la segunda podría preguntar por el corpus del teléfono sin que nada se pusiera rojo.
    @Test("la activación de Yala completo NO pregunta por el corpus del teléfono, en NINGUNA de sus dos puertas")
    func activationNeverAsksAboutTheDeviceCorpus() throws {
        let src = try Self.source("Yala/App/Views/Groups/FullModeActivationView.swift")
        let code = try Self.code("Yala/App/Views/Groups/FullModeActivationView.swift")
        #expect(code.components(separatedBy: "WelcomePrivateICloudGateView(").count - 1 == 2, """
            la activación monta la puerta un número de veces distinto de dos. Si hay una más, este test no
            la está mirando; si hay una menos, uno de los dos caminos perdió su puerta — y el de
            «Restaurar → Empezar desde cero» sin ella no borra nada.
            """)
        // Cada puerta por su tramo del `switch`, y NO por `call(of:)`, que devuelve siempre la primera.
        for (tramo, hasta, borrado, elOtro, salida, laOtraSalida) in [
            ("case .privateGate:", "case .restoreDiscardGate:",
             "performWipe: { await performICloudZoneWipe() }",
             "performICloudZoneAndImportedRowsWipe",
             "unverifiedExit: .proceedWatchingTheMirror",
             ".returnWithoutClaimingAWipe"),
            ("case .restoreDiscardGate:", "case .relaunch:",
             "performWipe: { await performICloudZoneAndImportedRowsWipe() }",
             "performICloudZoneWipe()",
             "unverifiedExit: .returnWithoutClaimingAWipe",
             ".proceedWatchingTheMirror")] {
            let gate = try Self.segment(from: tramo, to: hasta, in: src)
            #expect(gate.contains("deviceCorpus: nil"), """
                la puerta de `\(tramo)` empezó a preguntar por el corpus del teléfono: esos grupos y esas
                categorías son de la MISMA persona que está activando, y la activación existe para
                conservarlos. Con el espejo montado, además, su borrado por filas exportaría los deletes.
                """)
            #expect(gate.contains("clearsResidualPreferencesOnWipe: false"), """
                la puerta de `\(tramo)` empezó a limpiar el nombre y la divisa: son el prefill de quien
                está activando, no restos de otra persona (decisión de Jürgen, paso 8 y 2.3A).
                """)
            // **El borrado que toca, y la PROHIBICIÓN del otro.** Los dos son closures de la misma vista
            // con el mismo tipo, así que intercambiarlos compila: `.privateGate` con el borrado de filas
            // le vacía el teléfono a quien está activando, y `.restoreDiscardGate` con el de zona vuelve
            // a dejar el corpus importado para que el espejo lo re-exporte, que es el bug entero.
            #expect(gate.contains(borrado), """
                la puerta de `\(tramo)` cambió su borrado. Tramo leído: \(gate)
                """)
            #expect(!gate.contains(elOtro), """
                la puerta de `\(tramo)` está usando el borrado de la OTRA. Intercambiarlos compila y no
                rompe ningún otro test: uno vacía el teléfono de quien activa, el otro deja el corpus
                importado re-exportándose a iCloud.
                """)
            // **Y el desenlace de «no se pudo preguntar», con la misma pareja afirmación + prohibición**
            // (2026-09-14). Es el mismo modo de fallo por otro argumento: los dos cases son del mismo
            // enum, así que intercambiarlos compila. En `.privateGate` volver atrás deja sin entrada a
            // quien abre la app sin conexión; en `.restoreDiscardGate` seguir adelante deja los datos
            // viejos enteros bajo un copy que prometió borrarlos, y encima escribe el testigo del espejo
            // tardío, cuyo borrado es `.handover` — el que purga el dominio de Grupos.
            #expect(gate.contains(salida), """
                la puerta de `\(tramo)` cambió su desenlace cuando a iCloud no se le puede preguntar.
                Tramo leído: \(gate)
                """)
            #expect(!gate.contains(laOtraSalida), """
                la puerta de `\(tramo)` está usando el desenlace de la OTRA.
                """)
        }
    }

    /// **F1 de la review · el borrado se saboteaba a sí mismo.** `wipeAllUserData` borra
    /// `hasCompletedOnboarding`, así que todo borrado hecho desde dentro del cover dispara el `onChange`
    /// de `ContentView` — y ahí `presentNextOnboardingScreen` **consume el destino del relanzamiento** y
    /// enciende `showOnboarding`. Dos daños: una segunda presentación ante el anchor que ya está mostrando
    /// el terminal «reabre Yala», y el relanzamiento desarmado (`shouldExitOnBackground` vive de que ese
    /// destino siga puesto), con lo que el onboarding privado correría entero sobre un store sin espejo.
    @Test("con el Welcome montado, el arranque no encamina por su cuenta")
    func onboardingReset_doesNotHijackTheWelcome() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let cambio = try Self.body(of: ".onChange(of: hasCompletedOnboarding) { _, newValue in", in: src)
        try Self.expectOrder("guard !showWelcomeFlow else { return }",
                             before: "presentNextOnboardingScreen()", in: cambio, """
            sin este guard, el borrado de la puerta privada consume su propio destino de relanzamiento y
            monta el onboarding encima del terminal que acaba de abrir.
            """)
    }

    /// **S1 de la review · el cable del MEDIO, que era el único que nadie vigilaba.** La decisión estaba
    /// cerrada por sus tablas y el borrado por su scan, pero entre las dos hay una línea —`measure()`
    /// consulta el corpus y se lo pasa a `decide`— que ningún test tocaba: cambiarla por `false` devolvía
    /// el ticket entero, en verde. Es «la pasarela que nadie vigila» de `.claude/rules/testing.md`, y aquí
    /// la pasarela ES el arreglo.
    @Test("la puerta MIDE el corpus del teléfono y se lo pasa a la tabla")
    func measureFeedsTheDeviceTermIntoTheDecision() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let measure = try Self.body(of: "private func measure() async {", in: src)
        #expect(measure.contains("let deviceHasData = deviceCorpus?.hasData() ?? false"), """
            `measure()` dejó de contar lo que hay en el teléfono: con ese término en `false` la puerta
            vuelve a salir de largo y el aviso se pierde entero — el bug de este ticket, sin tocar la
            tabla.
            """)
        #expect(measure.contains("deviceHasData: deviceHasData"), """
            se mide pero no se pasa: la tabla decide con un término que nadie le dio.
            """)
        // El `?? false` importa en la dirección contraria: con `?? true`, la activación de Yala completo
        // —que pasa `deviceCorpus: nil`— le enseñaría a quien está activando un aviso de datos cuyo único
        // desenlace es el fallo, porque no hay corpus que borrar.
        #expect(!measure.contains("?? true"), """
            `?? true` le enseña el aviso a quien monta la puerta SIN corpus (la activación de Yala
            completo), y ahí el único desenlace posible es la pantalla de error.
            """)
        // **Y el orden: se cuenta DESPUÉS de la sonda.** Medir antes deja un muestreo de hace segundos —lo
        // que tarde CloudKit—, y en una sesión solo-grupos el canal sigue aplicando pulls durante ese rato:
        // el aviso se perdería sobre las filas que llegaron mientras se preguntaba.
        let sonda = try #require(measure.range(of: "await ICloudPersonalCorpusProbe.probe()"))
        let medir = try #require(measure.range(of: "deviceCorpus?.hasData()"))
        let decidir = try #require(measure.range(of: "WelcomePrivateICloudGateLogic.decide("))
        #expect(sonda.lowerBound < medir.lowerBound, """
            el conteo del teléfono volvió a hacerse antes del `await` de la sonda: deja de ser vivo, que es
            lo que dos docblocks afirman de él.
            """)
        #expect(medir.lowerBound < decidir.lowerBound)
        // **S2 · el fan-out del `case` nuevo.** La decisión puede salir perfecta y tirarse a la basura.
        #expect(measure.contains("case .foundDeviceData(let unverified):"), """
            el `switch` de `measure()` dejó de tratar el desenlace nuevo: se decide bien y no se pinta.
            """)
        #expect(measure.contains("phase = .foundDevice(iCloudUnverified: unverified)"), """
            el término «no pudimos preguntar» se pierde al pintar la fase, y con él el testigo del espejo
            tardío que depende de él.
            """)
    }

    /// **S3 de la review · el emparejamiento botón ↔ acción, que un `contains` suelto no caza.** Los dos
    /// mutantes que esto mata dan la misma pantalla, el mismo copy y los mismos identificadores: en uno,
    /// «Dejarlo como está» mete a la persona en el onboarding encima de sus datos; en otro, el botón que
    /// conserva BORRA. Es el punto (2) de `.claude/rules/testing.md`: fija el par, no la presencia.
    @Test("cada botón de las pantallas del teléfono hace lo suyo, y no lo del de al lado")
    func deviceScreens_pairEachButtonWithItsAction() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")

        let aviso = try Self.body(of: "private func foundDeviceContent(iCloudUnverified: Bool) -> some View {",
                                  in: src)
        try Self.expectAction(in: aviso, identifier: "welcome_private_icloud_keep_device",
                              does: "leaveGate()",
                              why: "el botón que NO destruye acabó avanzando: es el bug del ticket con el aviso pintado por encima")
        try Self.expectAction(in: aviso, identifier: "welcome_private_icloud_wipe_device",
                              does: "phase = .confirmingDeviceWipe(iCloudUnverified: iCloudUnverified)",
                              why: "el destructivo se saltó la segunda confirmación que el ADR exige")

        let confirmar = try Self.body(of: "private func confirmDeviceContent(iCloudUnverified: Bool) -> some View {",
                                      in: src)
        try Self.expectAction(in: confirmar, identifier: "welcome_private_icloud_confirm_keep_device",
                              does: "phase = .foundDevice(iCloudUnverified: iCloudUnverified)",
                              why: "«Mejor no» BORRA")
        try Self.expectAction(in: confirmar, identifier: "welcome_private_icloud_confirm_wipe_device",
                              does: "phase = .wipingDevice(iCloudUnverified: iCloudUnverified)",
                              why: "el segundo gesto dejó de lanzar el borrado")

        // **S4 · `iCloudUnverified` cruza cinco saltos y ninguno estaba afirmado.** Un literal `false` en
        // cualquiera de ellos pierde el testigo del espejo tardío sin que nada cante.
        #expect(!src.contains("iCloudUnverified: false"), """
            alguien clavó el término a `false` en el camino: el testigo del espejo tardío no se escribe, y
            el histórico del Apple ID cae encima del onboarding el día que iCloud vuelva.
            """)
        #expect(!src.contains("iCloudUnverified: true"), """
            clavarlo a `true` escribe el testigo a quien SÍ pudo preguntar: un aviso de espejo tardío
            sobre un iCloud que ya se midió vacío.
            """)
    }

    /// **S5 de la review · la fase que nadie ejecuta es una pantalla-trampa.** Sin su `case` en
    /// `runPhase`, `.wipingDevice` cae en el `default: return`: spinner eterno **y sin botón de volver**
    /// —lo oculta `backAction` en esa fase—, o sea la persona encerrada y nada borrado.
    @Test("cada fase que trabaja tiene su rama en `runPhase`, y las que no trabajan no la tienen")
    func runPhase_coversTheWorkingPhases() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let run = try Self.body(of: "private func runPhase() async {", in: src)
        #expect(run.contains("case .checking: await measure()"))
        #expect(run.contains("case .wiping: await wipe()"))
        #expect(run.contains("case .wipingDevice(let unverified): await wipeDevice(iCloudUnverified: unverified)"), """
            sin esta rama, `.wipingDevice` cae en el `default`: spinner eterno, sin «volver» (lo oculta
            `backAction`) y sin haber borrado nada.
            """)
        // S7 · el «volver» tiene que desaparecer TAMBIÉN durante el borrado local.
        let back = try Self.body(of: "private var backAction: (() -> Void)? {", in: src)
        #expect(back.contains("if case .wipingDevice = phase { return nil }"), """
            el «volver» reaparece con el borrado local en vuelo: es la otra mitad de la kill-safety.
            """)
        // S7 · y el arm del borrado de iCloud se retira también cuando el que falló fue el del teléfono.
        let leave = try Self.body(of: "private func leaveGate() {", in: src)
        #expect(leave.contains("isDeviceWipeFailed"), """
            quien se va tras un borrado local fallido deja el arm puesto, y el arranque siguiente le pide
            terminar un borrado que acaba de retirar.
            """)
        // S8 · el reintento de la pantalla de fallo LOCAL vuelve al borrado local, no al de la zona.
        let contenido = try Self.body(of: "private var content: some View {", in: src)
        #expect(contenido.contains("primaryAction: { phase = .wipingDevice(iCloudUnverified: unverified) }"), """
            «volver a intentarlo» tras un fallo local dispara el borrado de la ZONA de CloudKit, que en
            este camino —normalmente sin cuenta— falla seguro y además se lleva las filas locales.
            """)
    }

    /// **A3 de la review · el arm del borrado de iCloud NO se arma aquí, y no es un detalle.** Ese testigo
    /// tiene dos consumidores y uno lo reanuda a ciegas con `performICloudCorpusWipe()`, que borra la ZONA
    /// del Apple ID: un kill a mitad de un borrado LOCAL acababa vaciando el iCloud de la persona sin que
    /// nadie lo pidiera, sobre una pantalla cuyo copy promete que iCloud no se toca.
    @Test("el borrado del teléfono no arma el testigo del borrado de iCloud")
    func deviceWipe_neverArmsTheICloudWipe() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let wipe = try Self.body(of: "private func wipeDevice(iCloudUnverified: Bool) async {", in: src)
        #expect(!wipe.contains("armICloudCorpusWipe"), """
            armarlo aquí convierte un kill a mitad de un borrado LOCAL en un borrado REMOTO que nadie
            confirmó: `runLateICloudMirrorCheck` lo reanuda con `performICloudCorpusWipe()`.
            """)
        #expect(!wipe.contains("clearICloudCorpusWipeArm"), """
            si no se arma, desarmar aquí retiraría el arm de OTRO borrado —el de iCloud— que puede estar
            legítimamente en pie.
            """)
        // Y el arm sigue vivo donde sí le toca: su camino de iCloud no se ha tocado.
        let icloud = try Self.body(of: "private func wipe() async {", in: src)
        #expect(icloud.contains("StorageModePersistence.armICloudCorpusWipe()"))
    }

    /// **A4 de la review · un borrado consumado termina su trabajo.** `wipeAllUserData` borra
    /// `hasCompletedOnboarding`, lo que dispara el `onChange` de `ContentView` y puede cancelar esta
    /// `.task` **con el borrado ya committeado**; volver ahí dejaba el corpus borrado y ninguna de sus
    /// consecuencias aplicadas — ni las prefs residuales, ni el testigo, ni la salida.
    @Test("tras borrar no hay punto de cancelación que se coma las consecuencias")
    func deviceWipe_hasNoCancellationPointAfterTheDelete() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let wipe = try Self.body(of: "private func wipeDevice(iCloudUnverified: Bool) async {", in: src)
        #expect(!wipe.contains("Task.isCancelled"), """
            un `guard !Task.isCancelled` después del borrado deja el corpus borrado y sin sus
            consecuencias: el propio `wipeAllUserData` puede cancelar esta task al tocar los flags de
            onboarding.
            """)
    }

    /// **S6 de la review · el borrado local tenía un solo `contains` y su hermano tiene siete.** Todo esto
    /// pasaba en verde: quitar el gate de quiescencia (vuelve el SIGTRAP), descartar su veredicto,
    /// invertir el orden de los dos borrados, tragarse el error del segundo, o devolver `nil` tras fallar
    /// —el peor: la puerta cree que borró, sigue al onboarding y los datos están intactos—.
    @Test("el borrado del teléfono respeta la quiescencia, el orden, el canario y su contrato de fallo")
    func deviceCorpusWipe_hasTheSameNetAsItsSibling() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wipe = try Self.body(of: "private func performDeviceCorpusWipe() async -> String? {", in: src)
        let linea = try #require(wipe.split(separator: "\n").first(where: { $0.contains("waitForImportQuiescence") }))
        #expect(linea.contains("guard"), """
            el veredicto de la quiescencia tiene que CORTAR el borrado: un `save()` de SwiftData durante
            un import de CloudKit dispara el SIGTRAP, y con un corpus grande agotar el tope es el caso
            NORMAL.
            Línea: \(linea)
            """)
        try Self.expectOrder("DataWipeService." + Self.wipeCall,
                             before: "DataWipeService.wipeLocalGroupsDomain(in: modelContext)", in: wipe,
                             "lo personal primero y el dominio después, como en el alert gemelo")
        // **La gracia del wipe remoto se cancela ANTES de borrar.** `wipeAllUserData` hace `save()`
        // incrementales, así que un borrado que lanza a media lista baja igual la señal; con la gracia
        // viva eso enciende el alert de «te borraron los datos», que desmonta el cover y deja la pantalla
        // negra. Estaba solo en la rama de éxito, o sea justo al revés de donde hace falta.

        // El ancla es `cancelWipeGrace()` desde el 2026-09-14: cancelar la tarea dejó de bastar cuando el
        // aviso pasó a viajar por la cola del router, así que las dos mitades —cancelar y retirar el
        // intent ya encolado— viven en esa función.
        try Self.expectOrder("cancelWipeGrace()", before: "DataWipeService." + Self.wipeCall, in: wipe,
                             "cancelar la gracia después del borrado no protege la rama de FALLO")
        #expect(wipe.contains("MetricsService.canary(.freshStartWipeFailed"), """
            sin canario, este fallo vuelve a ser invisible en producción — que es para lo que se añadió en
            su gemelo.
            """)
        let fallo = try #require(wipe.range(of: "} catch {"))
        let cuerpo = String(wipe[fallo.upperBound...])
        #expect(cuerpo.contains("return \"deviceWipeFailed\""), """
            devolver `nil` tras fallar es el peor desenlace del fichero: la puerta cree que borró, sale al
            onboarding, y los datos siguen enteros.
            """)
    }

    /// **S9 de la review · el copy del teléfono no puede prometer iCloud.** Son claves propias
    /// precisamente porque las de iCloud dicen otra cosa; cambiar la vista a las viejas —o los valores a
    /// un texto que nombre iCloud— le diría a la persona que se borra de su cuenta algo que este camino
    /// no toca.
    @Test("el copy del aviso del teléfono habla del TELÉFONO, y jamás de iCloud")
    func deviceCopy_neverPromisesICloud() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        for (fase, clave) in [("private func foundDeviceContent(iCloudUnverified: Bool) -> some View {",
                               "L10n.Welcome.PrivateICloud.foundDeviceBody"),
                              ("private func confirmDeviceContent(iCloudUnverified: Bool) -> some View {",
                               "L10n.Welcome.PrivateICloud.wipeDeviceConfirmBody")] {
            let cuerpo = try Self.body(of: fase, in: src)
            #expect(cuerpo.contains(clave), "la pantalla del teléfono volvió al copy de iCloud: \(clave)")
        }
        for locale in ["es-419", "en"] {
            let strings = try Self.source("Yala/Resources/\(locale).lproj/Localizable.strings")
            for clave in ["welcome.privateICloud.foundDeviceTitle", "welcome.privateICloud.foundDeviceBody",
                          "welcome.privateICloud.wipeDeviceConfirmBody", "welcome.privateICloud.wipingDevice",
                          "welcome.privateICloud.wipeDeviceFailedBody"] {
                let linea = try #require(strings.split(separator: "\n").first(where: { $0.contains("\"\(clave)\"") }),
                                         "falta \(clave) en \(locale)")
                // **Se mira el VALOR, no la línea.** La propia clave lleva `privateICloud` dentro, así que
                // una comparación sobre la línea entera se cumple siempre y este test no podría fallar
                // nunca — la familia de «la aserción que no puede fallar».
                let valor = try #require(linea.split(separator: "=").dropFirst().first,
                                         "línea sin valor: \(linea)")
                #expect(!valor.localizedCaseInsensitiveContains("iCloud"), """
                    \(clave) [\(locale)] promete iCloud, y este camino no toca iCloud:
                    \(linea)
                    """)
            }
        }
    }

    /// **El orden kill-safe del borrado local, y su bifurcación final.** El arm va antes de la primera
    /// escritura y se retira solo cuando el borrado confirma; y si a iCloud no se le pudo preguntar, la
    /// salida es `continueWithoutValidating`, que deja escrito el testigo del espejo tardío. Sin esa
    /// bifurcación, quien borra lo suyo sin red se come el histórico del Apple ID el día que iCloud vuelva
    /// — este mismo bug, con otro disfraz.
    @Test("el borrado del teléfono arma antes, desarma después y respeta el testigo tardío")
    func deviceWipe_isKillSafeAndKeepsTheLateWitness() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let wipe = try Self.body(of: "private func wipeDevice(iCloudUnverified: Bool) async {", in: src)
        // **El borrado va antes que sus consecuencias, y el fallo CORTA.** El arm ya no forma parte de
        // este camino (ver `deviceWipe_neverArmsTheICloudWipe`), así que lo que queda por fijar es el
        // orden entre el borrado, su veredicto y la salida.
        let call = try #require(wipe.range(of: "await deviceCorpus.wipe()"))
        let salida = try #require(wipe.range(of: "if iCloudUnverified {"))
        #expect(call.lowerBound < salida.lowerBound, "la salida no puede preceder al borrado")
        // El control de FLUJO, no solo las posiciones: sin el `return` de la rama de fallo, un borrado
        // que lanzó avanza igual, y la persona acaba en el onboarding creyendo que se borró.
        let fallo = try #require(wipe.range(of: "guard failure == nil else {"))
        #expect(fallo.lowerBound < salida.lowerBound)
        let cuerpoFallo = String(wipe[fallo.upperBound...]).prefix(while: { $0 != "}" })
        #expect(cuerpoFallo.contains("phase = .deviceWipeFailed(iCloudUnverified: iCloudUnverified)"), """
            un borrado que falla no puede seguir al onboarding: los datos siguen ahí y continuar sería
            mentirle a la persona.
            """)
        #expect(cuerpoFallo.contains("return"))
        // **Las dos ramas de la salida, EMPAREJADAS.** Un `contains("continueWithoutValidating()")` suelto
        // sobrevive a invertirlas —el literal sigue ahí, en la rama equivocada— y esa inversión escribe el
        // testigo del espejo tardío a quien SÍ pudo preguntar, y se lo niega a quien no pudo: el bug de
        // este ticket por detrás, que es justo lo que el docblock de arriba dice que evita.
        let bifurcacion = try #require(wipe.range(of: "if iCloudUnverified {"))
        let ramaSi = String(wipe[bifurcacion.upperBound...]).prefix(while: { $0 != "}" })
        #expect(ramaSi.contains("continueWithoutValidating()"), """
            sin esta salida, quien borró lo suyo sin poder preguntarle a iCloud se queda sin el testigo del
            espejo tardío, y el histórico del Apple ID le cae encima el día que iCloud vuelva.
            Rama leída: \(ramaSi)
            """)
        let resto = String(wipe[bifurcacion.upperBound...])
        let ramaNo = try #require(resto.range(of: "} else {")).upperBound
        #expect(String(resto[ramaNo...]).prefix(while: { $0 != "}" }).contains("onProceed()"), """
            la rama de quien SÍ pudo preguntarle a iCloud acabó escribiendo el testigo del espejo tardío:
            un aviso sobre un iCloud que ya se midió vacío.
            """)
        // La rama del corpus ausente también CORTA: llegar aquí sin él significa que algo se desconectó, y
        // salir al onboarding diría que se borró algo que nadie borró.
        let sinCorpus = try #require(wipe.range(of: "guard let deviceCorpus else {"))
        let cuerpoSinCorpus = String(wipe[sinCorpus.upperBound...]).prefix(while: { $0 != "}" })
        #expect(cuerpoSinCorpus.contains("phase = .deviceWipeFailed"), """
            sin corpus el camino avanza como si hubiera borrado: el fallo seguro es NO seguir.
            """)
        #expect(cuerpoSinCorpus.contains("return"))
        // **Y NO toca CloudKit.** El aviso vino de las filas locales; pedir un borrado de zona sin cuenta
        // —el caso normal de este camino— sería un fallo seguro sin nada que borrar allí.
        #expect(!wipe.contains("ICloudPersonalCorpusProbe"), """
            el borrado del teléfono empezó a hablar con CloudKit: en el caso normal de este camino no hay
            cuenta, así que sería un fallo seguro y la persona se quedaría en la pantalla de error.
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

    /// **El borrado es UNO para todos los caminos, con su scope por call-site, y el del Welcome no puede
    /// reusar solo la zona de CloudKit.** La puerta es alcanzable con el espejo ya adjunto, así que borrar
    /// solo la zona dejaría el corpus viejo entero en el dispositivo. Este test describe el CUERPO
    /// compartido; quién pide qué scope lo fijan los tests de cada consumidor.
    @Test("el borrado unificado toca la zona de iCloud Y el store local, y respeta la quiescencia")
    func wipe_clearsBothSides() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        // Paso 8 · la firma lleva un SCOPE, y desde el 2026-09-14 son tres y no dos (`ICloudWipeScope`).
        // Este test describe el cuerpo compartido: la zona siempre, y el borrado local detrás de su guard.
        // Quién pide qué lo fijan los tests de cada consumidor.
        let wipe = try Self.body(
            of: "private func performICloudCorpusWipe(_ scope: ICloudWipeScope) async -> String? {",
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
        // **La purga del dominio de Grupos SÍ va aquí desde el 2026-09-13, y solo del guard para abajo.**
        // Hasta entonces este test la prohibía entera con este motivo: «Grupos vive en OTRO contenedor y
        // el ADR §6 lo deja fuera de todo borrado; esto no es un handover, es la misma persona limpiando
        // su propio histórico». Eso describe a UN consumidor —la activación de Yala completo— y esta
        // función tiene dos: el otro es el aviso del Welcome, donde «empiezo de cero» SÍ es la frontera de
        // otro usuario en este dispositivo. El corte que los separa es el scope, así que la purga va dentro
        // de `scope.purgesGroupsDomain` y los dos caminos de la activación salen antes de llegar.
        //
        // Sin esto quedaba sin sellar la celda «iCloud con datos ∧ teléfono con datos»: el aviso remoto
        // gana, su borrado se lleva lo personal, y los grupos de la etapa anterior se quedan vivos con el
        // bridge abierto ⇒ suben al iCloud del Apple ID en el arranque siguiente (criterio nº4 del ticket).
        let compartido = String(wipe[wipe.startIndex..<(try #require(wipe.range(of: "guard scope.deletesLocalRows")).lowerBound)])
        #expect(!compartido.contains("wipeLocalGroupsDomain"), """
            la purga del dominio se salió del guard de `scope.deletesLocalRows`: los dos caminos de la
            activación de Yala completo comparten esta función y ahí los grupos son de la MISMA persona que
            está activando.
            """)
        try Self.expectOrder("guard scope.deletesLocalRows",
                             before: "DataWipeService.wipeLocalGroupsDomain(in: modelContext)", in: wipe,
                             "el corte va antes de la purga, o la activación se lleva los grupos por delante")
        // **Y la purga tiene su PROPIO guard, no cuelga del de las filas.** `.importedRows` borra filas y
        // NO purga Grupos: sin este término, «Restaurar → Empezar desde cero» dentro de la activación se
        // llevaría por delante los grupos que la activación existe para conservar (decisión 2.2A).
        #expect(wipe.contains("if scope.purgesGroupsDomain {"), """
            la purga del dominio volvió a colgar solo del guard de las filas. Hay un scope que borra filas
            SIN purgar Grupos (`.importedRows`), y sin su propio término se los lleva igual.
            Cuerpo leído: \(wipe)
            """)
        try Self.expectOrder("DataWipeService." + Self.wipeCall,
                             before: "DataWipeService.wipeLocalGroupsDomain(in: modelContext)", in: wipe,
                             "lo personal primero y el dominio después, como en el alert gemelo")
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
        //
        // **Desde el 2026-09-14 las dos salen por el BIFURCADOR, no por este helper**, porque la puerta de
        // «Restaurar → Empezar desde cero» no puede seguir: allí la persona ya confirmó un borrado que no
        // se pudo hacer. Lo que este bucle sigue afirmando es que las dos fases OFRECEN una salida (el
        // ADR dice que no poder preguntar JAMÁS bloquea); cuál de las dos es, lo fija el test de abajo.
        // **`.unreachable` se acota por su `case` siguiente y se afirma con los DOS botones emparejados**,
        // no con la presencia de un literal: intercambiarlos deja «Reintentar» saliendo de la puerta y la
        // salida re-midiendo, con los dos literales igual de presentes.
        let content = try Self.body(of: "private var content: some View {", in: src)
        let unreachable = try #require(content.range(of: "case .unreachable:"))
        let hasta = try #require(content.range(of: "case .wipeFailed:",
                                               range: unreachable.upperBound..<content.endIndex))
        let ramaUnreachable = String(content[unreachable.upperBound..<hasta.lowerBound])
        #expect(ramaUnreachable.contains("primaryAction: { phase = .checking }"), """
            `.unreachable` dejó de ofrecer reintentar, que es lo único que puede cambiar el desenlace
            cuando la red vuelve. Rama leída: \(ramaUnreachable)
            """)
        #expect(ramaUnreachable.contains("secondaryAction: exitWithoutValidating"), """
            `.unreachable` no ofrece salida: el ADR dice que no poder preguntar JAMÁS bloquea, y un botón
            que solo puede reintentar sí bloquea. Rama leída: \(ramaUnreachable)
            """)
        // Y el cableado de `.noICloud` a su propiedad. Su contenido lo vigila
        // `noICloud_offersRetryOnlyWhereTheRemedyExists`, que es quien puede acotar cada rama del `switch`.
        let noICloud = try #require(content.range(of: "case .noICloud:"))
        #expect(String(content[noICloud.upperBound..<unreachable.lowerBound])
            .contains("noICloudContent"), """
            el estado K dejó de montar su contenido: su forma depende del desenlace y sin esa propiedad
            vuelve a tener un botón único, que en la puerta que VUELVE es un camino muerto de dos
            pantallas.
            """)
    }

    /// **El copy de las dos fases también cambia con el desenlace, y nadie lo miraba** (review
    /// adversarial, 2026-09-14). Los tres mutantes que quedaban verdes: `unverifiedExitLabel` devolviendo
    /// siempre `noAccountCta` —la puerta que vuelve diciendo **«Seguir así»** mientras vuelve, que es
    /// exactamente la mentira que esa propiedad existe para evitar— y los dos cuerpos devolviendo siempre
    /// las claves viejas, que prometen un «seguir» que esa pantalla no ofrece.
    @Test("cada desenlace lleva su copy, y el de la puerta que vuelve no promete seguir")
    func unverifiedCopy_matchesItsOutcome() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        for (propiedad, sigue, vuelve) in [
            ("private var noICloudBody: String {",
             "L10n.Welcome.PrivateICloud.noAccountBody",
             "L10n.Welcome.PrivateICloud.discardUnverifiedNoAccountBody"),
            ("private var unreachableBody: String {",
             "L10n.Welcome.PrivateICloud.errorBody",
             "L10n.Welcome.PrivateICloud.discardUnverifiedBody"),
            ("private var unverifiedExitLabel: String {",
             "L10n.Welcome.PrivateICloud.noAccountCta",
             "L10n.Welcome.PrivateICloud.discardUnverifiedBack")
        ] {
            let cuerpo = try Self.body(of: propiedad, in: src)
            let a = try #require(cuerpo.range(of: "case .proceedWatchingTheMirror:"),
                                 "\(propiedad) dejó de ramificar por el desenlace")
            let b = try #require(cuerpo.range(of: "case .returnWithoutClaimingAWipe:"))
            #expect(a.lowerBound < b.lowerBound, "el switch cambió de orden; los tramos de abajo mienten")
            let fin = cuerpo.range(of: "\n        case ", range: b.upperBound..<cuerpo.endIndex)?
                .lowerBound ?? cuerpo.endIndex
            #expect(String(cuerpo[a.upperBound..<b.lowerBound]).contains(sigue), Comment(rawValue: """
                \(propiedad): la rama que SIGUE cambió de copy. Ese texto es el que lleva años en el
                Welcome y la review de este PR no lo tocó.
                """))
            #expect(String(cuerpo[b.upperBound..<fin]).contains(vuelve), Comment(rawValue: """
                \(propiedad): la rama que VUELVE usa el copy de la que sigue. Ese texto promete un
                «seguir» que esa pantalla no ofrece —y en el label, dice literalmente «Seguir así»
                mientras vuelve atrás.
                """))
        }
        // **El «sin default» del parámetro, que es lo que obliga a cada montaje a pronunciarse.** Ponerle
        // uno compila, deja los tres call-sites y sus aserciones intactos, y re-arma el bug para el
        // cuarto: heredaría el desenlace de otro sin que nadie lo decidiera.
        #expect(!src.contains("var unverifiedExit: UnverifiedExit ="), """
            `unverifiedExit` tiene valor por defecto. El montaje siguiente heredaría el desenlace de otro
            en silencio, que es la forma exacta de este bug: la puerta de «Empezar desde cero» nació
            reusando esta vista y se trajo la salida de la otra sin que nadie lo decidiera.
            """)
    }

    /// **El estado K tiene DOS formas, y la diferencia es si la pantalla tiene salida** (review
    /// adversarial, 2026-09-14).
    ///
    /// Quien sigue adelante necesita un CTA y nada más: no hay cuenta de iCloud a la que preguntar, el
    /// remedio no existe, y el ADR dice que se informa y se sigue. Quien vuelve necesita **reintentar**,
    /// porque su destino con iCloud apagado (`WelcomeRestoreView.iCloudDisabledView`) ofrece «Abrir
    /// Ajustes» y «Empezar desde cero» — o sea que sin un botón que re-mida, las dos pantallas se
    /// devuelven la pelota y la persona no puede terminar la activación sin salir del flujo.
    @Test("el estado K ofrece reintentar en la puerta que vuelve, y solo su CTA en la que sigue")
    func noICloud_offersRetryOnlyWhereTheRemedyExists() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let cuerpo = try Self.body(of: "private var noICloudContent: some View {", in: src)

        let sigue = try #require(cuerpo.range(of: "case .proceedWatchingTheMirror:"))
        let vuelve = try #require(cuerpo.range(of: "case .returnWithoutClaimingAWipe:"))
        #expect(sigue.lowerBound < vuelve.lowerBound, "el switch cambió de orden; los tramos de abajo mienten")

        let ramaSigue = String(cuerpo[sigue.upperBound..<vuelve.lowerBound])
        #expect(!ramaSigue.contains("twoWayNoticeContent("), """
            el estado K del Welcome ofrece reintentar: allí NO hay cuenta de iCloud que consultar, así que
            ese botón no puede cambiar nada y la pantalla pasa a tener un control muerto.
            Rama leída: \(ramaSigue)
            """)
        #expect(ramaSigue.contains("action: exitWithoutValidating)"), """
            la rama que sigue dejó de cablear su CTA a la salida. Rama leída: \(ramaSigue)
            """)

        // **El tramo se ACOTA por el `case` siguiente, y esa acotación es el test.** Con `String(cuerpo[
        // vuelve.upperBound...])` la aserción llegaba hasta el final del cuerpo: un mutante que cambiara
        // esta rama por el aviso de un CTA único y dejara el `twoWayNoticeContent` en un `case` de
        // relleno más abajo salía VERDE — medido el 2026-09-14, sobrevivió al primer intento.
        let finVuelve = cuerpo.range(of: "\n        case ", range: vuelve.upperBound..<cuerpo.endIndex)?
            .lowerBound ?? cuerpo.endIndex
        let ramaVuelve = String(cuerpo[vuelve.upperBound..<finVuelve])
        #expect(ramaVuelve.contains("twoWayNoticeContent("), """
            la puerta que VUELVE dejó de ofrecer dos salidas. Rama leída: \(ramaVuelve)
            """)
        #expect(ramaVuelve.contains("primaryAction: { phase = .checking }"), """
            la puerta que VUELVE dejó de ofrecer reintentar: su destino con iCloud apagado ofrece «Abrir
            Ajustes» y «Empezar desde cero», así que sin este botón las dos pantallas se devuelven la
            pelota y la activación no se puede terminar desde dentro. Rama leída: \(ramaVuelve)
            """)
        #expect(ramaVuelve.contains("secondaryAction: exitWithoutValidating"), """
            y su salida sigue siendo la que no declara ningún borrado.
            """)
    }

    /// **El chevron y el botón salen al mismo sitio, así que tienen que retirar el arm igual.** Dos
    /// controles con el mismo destino y efectos durables distintos es como un arm sobrevive a una salida
    /// deliberada — y mientras está puesto, `runLateICloudMirrorCheck` lo reanuda a ciegas con el scope
    /// del handover, que purga el dominio de Grupos.
    @Test("el «volver» de la barra retira el arm en las dos fases que no pudieron medir")
    func backButton_discardsTheArmWhenNothingCouldBeMeasured() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let leave = try Self.body(of: "private func leaveGate() {", in: src)
        #expect(leave.contains("isUnverified"), """
            el chevron sale de `.noICloud` y `.unreachable` al MISMO sitio que su botón, y ese botón retira
            el arm. Sin este término, tocar la flecha en vez del botón deja armado un borrado que ni
            siquiera se pudo medir, y el arranque siguiente lo reanuda sin preguntar.
            Cuerpo leído: \(leave)
            """)
        let predicado = try Self.body(of: "private var isUnverified: Bool {", in: src)
        for fase in ["phase == .noICloud", "phase == .unreachable"] {
            #expect(predicado.contains(fase), Comment(rawValue: """
                `isUnverified` dejó fuera \(fase): esa fase ofrece la salida que retira el arm, y su
                chevron volvería a dejarlo puesto.
                """))
        }
    }

    /// **La salida de «no se pudo preguntar» bifurca, y las dos ramas van EMPAREJADAS.**
    ///
    /// El 2026-09-14 esta salida dejó de ser una: la puerta del chooser sigue adelante con el testigo del
    /// espejo tardío puesto, y la de «Restaurar → Empezar desde cero» vuelve atrás sin declarar nada,
    /// porque allí la persona ya confirmó un borrado que no llegó a ocurrir.
    ///
    /// **Se afirma el par `case` → llamada en la MISMA línea, no la presencia de los dos literales**, que
    /// es el molde de `wipeDevice`: con las dos ramas intercambiadas los dos literales siguen ahí, y la
    /// inversión hace justo el daño del ticket —quien confirmó un borrado sale al onboarding con sus datos
    /// viejos enteros, y encima apuntado para el aviso del espejo tardío, cuyo borrado es `.handover`.
    @Test("la salida sin validar bifurca, y cada desenlace lleva su rama")
    func unverifiedExit_pairsEachOutcomeWithItsBranch() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let bifurcador = try Self.body(of: "private func exitWithoutValidating() {", in: src)
        #expect(bifurcador.contains("case .proceedWatchingTheMirror: continueWithoutValidating()"), """
            el desenlace que sigue adelante dejó de escribir el testigo del espejo tardío, o lo cambió por
            el que vuelve atrás: quien eligió privado sin poder validar se queda sin el aviso, y el
            histórico del Apple ID le cae encima el día que iCloud vuelva.
            Cuerpo leído: \(bifurcador)
            """)
        #expect(bifurcador.contains("case .returnWithoutClaimingAWipe: returnWithoutClaimingAWipe()"), """
            el desenlace que vuelve atrás pasó a seguir adelante: quien confirmó «Empezar desde cero» sin
            red acaba en el onboarding con sus datos viejos enteros, bajo un copy que prometió borrarlos —
            y con el testigo que levanta el aviso del espejo tardío, cuyo borrado purga el dominio de
            Grupos de quien activó conservándolos.
            Cuerpo leído: \(bifurcador)
            """)

        // **Y el cuerpo de la salida nueva, por sus DOS ausencias**, que son el ticket entero.
        let volver = try Self.body(of: "private func returnWithoutClaimingAWipe() {", in: src)
        #expect(!volver.contains("markPrivateChoseWithoutICloud"), """
            la salida que NO borró nada escribe el testigo del espejo tardío. Ese aviso borra con
            `performICloudCorpusWipe(.handover)` —preferencias y purga del dominio de Grupos—, que es el
            scope que quien activa CONSERVANDO sus grupos no puede recibir. Es el daño encadenado del
            ticket, y era peor que el hueco.
            """)
        #expect(!volver.contains("onProceed()"), """
            la salida que vuelve atrás sigue adelante: la persona acaba en el onboarding creyendo que se
            borró un corpus que sigue entero en su teléfono.
            """)
        #expect(volver.contains("discardPendingWipe()"), """
            volver deja el arm puesto, y mientras lo está `runLateICloudMirrorCheck` lo REANUDA A CIEGAS
            con el scope del handover. La salida de antes ya lo retiraba aquí: no hacerlo es una regresión.
            """)
        #expect(volver.contains("onBack()"), """
            la salida que vuelve atrás no vuelve a ninguna parte: en la puerta de «Empezar desde cero»,
            `onBack` es quien devuelve a Restaurar con la decisión todavía abierta.
            """)
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
        // **El scope de la reanudación a ciegas es `.handover`, y decirlo aquí importa:** este es el
        // camino que NO vuelve a preguntar —la persona ya confirmó dos veces y lo que falta es acabar—,
        // así que es el que más daño hace si su alcance cambia sin que nadie lo mire.
        #expect(rama.contains("performICloudCorpusWipe(.handover)"))
        #expect(rama.contains("clearICloudCorpusWipeArm()"), """
            sin retirar el arm, el arranque siguiente vuelve a reanudar el mismo borrado, y el siguiente,
            y el siguiente.
            """)
        #expect(rama.contains("clearPrivateChoseWithoutICloud()"))
        #expect(rama.contains("hasCompletedOnboarding = false"),
                "el borrado se llevó el corpus: la persona tiene que volver al onboarding")
        // Y el corte ante el fallo: si el borrado no confirma, NO se retira nada.
        #expect(rama.contains("guard await performICloudCorpusWipe(.handover) == nil else { return }"), """
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
                        "welcome.privateICloud.noAccountBody",
                        // Los dos cuerpos de la puerta que VUELVE atrás (2026-09-14). Nombran iCloud por
                        // la misma razón y por una más: lo que dicen es que **no** se borró nada porque no
                        // se pudo mirar ahí, y sin nombrar dónde, «no borramos nada» es una frase sin
                        // sujeto.
                        "welcome.privateICloud.discardUnverifiedBody",
                        "welcome.privateICloud.discardUnverifiedNoAccountBody"] {
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
