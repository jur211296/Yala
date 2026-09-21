//
//  RestoreImportSettlementTests.swift
//  YalaTests / CloudSync
//
//  «Restaurar desde iCloud» decía «No hay datos asociados a tu cuenta de iCloud» a quien tenía su
//  histórico entero en el servidor, y debajo ponía un «Empezar desde cero» que no preguntaba nada. Le
//  bastaba con que el primer import de CloudKit tardase más de 90 s — histórico grande, conexión lenta,
//  o CloudKit entregando por lotes (`restore-says-no-data-when-the-icloud-import-never-settled`).
//
//  **Lo que decide el ticket es una sola pregunta, y estas son sus mitades.** El tope se agota igual
//  para el histórico que tarda que para quien de verdad no tiene nada, así que `settled` a secas no
//  vale como señal: usarlo tal cual convertiría toda instalación nueva en un «no pudimos comprobar»
//  tras 90 s de espera, que es justo lo que `reinstall-without-network-has-no-cloud-door` descartó a
//  propósito el 2026-09-17. Quien las separa es el flag del propio import — **y, desde la review, la
//  palabra VIGENTE de CloudKit encima**, porque ese flag lo enciende también el import que falla.
//
//  **Suite ÚNICA y con el nombre del fichero, a propósito**: `-only-testing` filtra por TIPO, no por
//  fichero, y un fichero con dos suites corre CERO casos al acotarlo por su nombre — con `TEST
//  SUCCEEDED` y exit 0 (`.claude/rules/testing.md`, L161 y L157). El source-scan del cableado vive en
//  `RestoreStartFreshGateTests`, que es donde ya estaban sus hermanos.
//
//  MUTANTES VERIFICADOS (compilados y corridos, no razonados), con el control positivo sin mutar en
//  verde. El conteo es del CONJUNTO que se lanzó —esta suite, `RestoreStartFreshGateTests`,
//  `WelcomeRestoreEmptyOutcomeTests` e `ICloudRestoreSignalWiringTests`— y la tabla con los números de
//  cada uno está en el PR.
//
//  **Un mutante SOBREVIVIÓ y por eso este fichero es más corto de lo que fue.** El enum llevó un
//  segundo derivado, `isConclusive`, que decidía si «Empezar desde cero» preguntaba en `.notFound`;
//  cablearlo a `true` fijo mataba 5 casos, así que parecía cubierto. Lo que no estaba medido era su
//  POBLACIÓN: `settled` exige `hasCompletedFirstImport` (`iCloudSyncService.swift:586`), o sea que
//  CloudKit trajo algo, y si trajo algo y `hasAnyData` sigue en `false` es porque son presupuestos o
//  grupos, que ese predicado no cuenta (`iCloudSyncService.swift:773-775`). La rama «concluyente» solo
//  la alcanzaba GENTE CON DATOS, a la que el botón dejaba borrar sin preguntar. No faltaba un test:
//  sobraba el término. `.notFound` confirma siempre y el hueco tiene ticket propio
//  (`restore-treats-budgets-and-groups-as-no-data`).
//

import Foundation
import Testing

@testable import Yala

@Suite("Restaurar · el tope agotado NO es un vacío (import settlement)")
struct RestoreImportSettlementTests {

    private static let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private static func t(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    /// **El caso del ticket.** El tope se agotó, el import estaba en marcha y CloudKit no ha dicho
    /// nada malo: los datos existen y están bajando. Es el único desenlace en el que negar que existan
    /// es falso, y era el que producía el mensaje.
    @Test("Tope agotado, import observado y sin error ⇒ los datos siguen llegando, no faltan")
    func timeoutWithHealthyActivityIsNotEmptiness() {
        let settlement = RestoreImportSettlement.resolve(
            settled: false, hasObservedImportActivity: true,
            lastImportErrorAt: nil, lastSuccessfulImportAt: nil)

        #expect(settlement == .stillImporting, """
            El desenlace de quien tiene histórico grande y esperó los 90 s completos. Mandarlo a
            `.inconclusive` es el bug entero: la pantalla acaba afirmando «No hay datos asociados a tu
            cuenta de iCloud» sobre un import que en ese momento está entrando.
            """)
        #expect(!settlement.consultsRemoteConfig, """
            y no se le pregunta al backend: su kill-switch gobierna la nube de Yala, no el espejo de
            CloudKit, así que su respuesta no puede cambiar este desenlace — y otro fetch encima es
            más espera para quien ya agotó el tope.
            """)
    }

    /// **El control que impide el remedio fácil.** Un usuario realmente nuevo agota EL MISMO tope: su
    /// store vacío no dispara ningún `.importEvent`, así que `forceFetchAndWait` se come los 90 s y
    /// `settled` vuelve `false` igual que arriba. Si la señal fuese el tope, esta persona vería
    /// «seguimos trayendo tus datos» esperando un import que no existe — y nunca llegaría a poder
    /// empezar. Es el motivo por el que la opción 2 del ticket (subir el tope) no es el remedio.
    @Test("Tope agotado SIN import observado ⇒ el usuario nuevo no se convierte en «no lo sabemos»")
    func timeoutWithoutActivityStaysInconclusive() {
        let settlement = RestoreImportSettlement.resolve(
            settled: false, hasObservedImportActivity: false,
            lastImportErrorAt: nil, lastSuccessfulImportAt: nil)

        #expect(settlement == .inconclusive, """
            Sin un solo `.importEvent` no hay nada que prometer: aquí caen el usuario realmente nuevo y
            el teléfono al que CloudKit no contestó, y esta señal no los separa.
            """)
        #expect(settlement.consultsRemoteConfig, """
            y por eso SÍ se sigue al desenlace de siempre: es el remote-config el que aún puede
            distinguir «la nube está en pausa» de «no pudimos comprobar» de «no hay datos».
            """)
    }

    /// **El agujero que cazaron las tres lentes de la review a la vez.** `hasObservedImportActivity` se
    /// enciende en la CABECERA del `case .importEvent`, antes del `if let error`, así que lo pone igual
    /// un import que trae datos que uno que FALLA. Sin el término de error, dos poblaciones leían
    /// «seguimos trayendo tus datos» con un «Reintentar» que devolvía al mismo sitio para siempre:
    /// quien tiene un fallo terminal (cuota, cuenta gestionada, permisos) y —peor— **el usuario
    /// realmente nuevo con red inestable**, a quien un solo `.importEvent` con `networkUnavailable` le
    /// enciende el flag con la cuenta vacía. O sea el remedio descartado, por la puerta de atrás.
    @Test("Un import que FALLA no promete datos: el error vigente lo devuelve al desenlace de siempre")
    func aCurrentImportErrorBreaksThePromise() {
        // Error y ningún éxito: la palabra de CloudKit es lo último que se sabe.
        #expect(RestoreImportSettlement.resolve(
            settled: false, hasObservedImportActivity: true,
            lastImportErrorAt: Self.t(0), lastSuccessfulImportAt: nil) == .inconclusive, """
            Con un error de import y ningún import bueno detrás, afirmar que el histórico está bajando
            es tan falso como el «no hay datos» que este ticket vino a arreglar — y el botón primario
            de esa pantalla es «Reintentar», que devuelve al mismo desenlace indefinidamente.
            """)

        // Error POSTERIOR al último éxito: los lotes que entraron ya no dicen nada del estado de ahora.
        #expect(RestoreImportSettlement.resolve(
            settled: false, hasObservedImportActivity: true,
            lastImportErrorAt: Self.t(60), lastSuccessfulImportAt: Self.t(30)) == .inconclusive, """
            un error posterior al último import con éxito es la palabra vigente: el import venía bien y
            ahora no.
            """)
    }

    /// El otro lado del mismo término, y sin él la mitad de arriba se cumpliría con
    /// `lastImportErrorAt != nil` a secas — que es el latch que este repo ya sabe que no se limpia
    /// (`lastImportError = nil` no existe fuera de `_testReset()`, igual que su gemelo del export).
    @Test("Un error SUPERADO no cuenta: lo que manda es la palabra vigente, no el latch")
    func aStaleImportErrorDoesNotCount() {
        #expect(RestoreImportSettlement.resolve(
            settled: false, hasObservedImportActivity: true,
            lastImportErrorAt: Self.t(0), lastSuccessfulImportAt: Self.t(30)) == .stillImporting, """
            El import falló al principio y luego entregó un lote. Leer el latch sin comparar fechas le
            quitaría «tus datos siguen llegando» a alguien cuyo histórico está entrando ahora mismo —
            el mismo defecto que `ICloudCutoverGateLogic` ya documenta para el export.
            """)

        // Y la ambigüedad no cuenta tampoco: un evento sin fechas no puede desmentir nada.
        #expect(RestoreImportSettlement.resolve(
            settled: false, hasObservedImportActivity: true,
            lastImportErrorAt: nil, lastSuccessfulImportAt: Self.t(30)) == .stillImporting, """
            sin fecha de error no hay palabra vigente que oponer, y el lado seguro aquí es NO negar los
            datos: quien los tiene bajando es la población del ticket.
            """)
    }

    /// El import asentó: el tope no llegó a agotarse, así que ni la actividad ni el error aportan nada
    /// — lo que esas señales distinguían era POR QUÉ se agotó. El caso se conserva separado de
    /// `.inconclusive` porque viaja al log, la única ventana sobre este flujo en CloudKit Production.
    @Test("Import asentado ⇒ `.settledEmpty`, pase lo que pase con los otros tres términos")
    func settledCollapsesWhateverTheOtherTermsSay() {
        for activity in [true, false] {
            for error in [nil, Self.t(60)] as [Date?] {
                let settlement = RestoreImportSettlement.resolve(
                    settled: true, hasObservedImportActivity: activity,
                    lastImportErrorAt: error, lastSuccessfulImportAt: Self.t(30))
                #expect(settlement == .settledEmpty, Comment(rawValue: """
                    actividad=\(activity) error=\(String(describing: error)): con el import asentado el
                    tope no llegó a agotarse. Que el `guard !settled` mire primero no es cosmético —
                    moverlo por debajo de los otros términos cambia el veredicto de esta fila.
                    """))
                #expect(settlement.consultsRemoteConfig, Comment(rawValue: """
                    actividad=\(activity): y se sigue preguntando, porque un vacío real puede seguir
                    siendo «la nube está en pausa» para un nacido-en-nube.
                    """))
            }
        }
    }

    /// **La tabla entera, fila a fila.** Cruza los tres términos y fija además el COMPLEMENTO del
    /// derivado: sin esa segunda mitad, invertir `consultsRemoteConfig` también deja un solo elemento
    /// en el filtro, solo que el equivocado.
    @Test("La tabla entera de los tres términos, con el derivado cruzado contra su inversión")
    func theWholeTableWithBothDirectionsOfTheDerivedFlag() {
        let tabla: [(settled: Bool, activity: Bool, errorAt: Date?, successAt: Date?,
                     esperado: RestoreImportSettlement)] = [
            (true,  true,  nil,        nil,        .settledEmpty),
            (true,  false, nil,        nil,        .settledEmpty),
            (true,  true,  Self.t(60), Self.t(30), .settledEmpty),
            (false, true,  nil,        nil,        .stillImporting),
            (false, true,  Self.t(0),  Self.t(30), .stillImporting),
            (false, true,  Self.t(60), Self.t(30), .inconclusive),
            (false, true,  Self.t(0),  nil,        .inconclusive),
            (false, false, nil,        nil,        .inconclusive),
            (false, false, Self.t(0),  nil,        .inconclusive),
        ]

        for fila in tabla {
            let s = RestoreImportSettlement.resolve(
                settled: fila.settled, hasObservedImportActivity: fila.activity,
                lastImportErrorAt: fila.errorAt, lastSuccessfulImportAt: fila.successAt)
            #expect(s == fila.esperado, Comment(rawValue: """
                settled=\(fila.settled) actividad=\(fila.activity) \
                error=\(String(describing: fila.errorAt)) éxito=\(String(describing: fila.successAt)) \
                ⇒ \(s), esperado \(fila.esperado)
                """))
            // `consultsRemoteConfig` no es una etiqueta: decide si se llama a la red. Se afirma en las
            // DOS direcciones sobre cada fila, porque con `true` fijo el caso «los datos vienen» vuelve
            // a pasar por `WelcomeRestoreEmptyOutcome` —que no conoce el import y lo manda a
            // `.notFound`— y con la inversión pasa lo contrario en las otras ocho.
            #expect(s.consultsRemoteConfig == (fila.esperado != .stillImporting), Comment(rawValue: """
                settled=\(fila.settled) actividad=\(fila.activity): el derivado dejó de seguir al caso.
                Solo el import EN MARCHA se salta la consulta de red; los otros dos la necesitan para
                distinguir «la nube está en pausa» de «no pudimos comprobar» de «no hay datos».
                """))
        }
    }
}
