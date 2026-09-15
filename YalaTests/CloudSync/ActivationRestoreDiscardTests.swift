//
//  ActivationRestoreDiscardTests.swift
//  YalaTests
//
//  Ticket `activation-restore-start-fresh-keeps-the-imported-rows`.
//
//  **El bug:** «Activar Yala completo → privado → Restaurar → Empezar desde cero» saltaba directo al
//  onboarding personal y no borraba NADA. A esa pantalla solo se llega tras un relanzamiento, así que el
//  store ESPEJA: el corpus que la persona acababa de decidir no traerse seguía entero en el dispositivo y
//  `NSPersistentCloudKitContainer` lo re-exportaba a la zona recién creada — y al segundo dispositivo del
//  mismo Apple ID. Un borrado que no borra, bajo un copy que promete lo contrario.
//
//  **Las tres mitades del arreglo, y cada una tiene aquí su red:**
//   1. el botón va a una puerta que MIDE y borra (`.restoreDiscardGate`);
//   2. esa puerta recibe un borrado de scope propio (`.importedRows`): filas sí, preferencias y dominio
//      de Grupos no;
//   3. y `wipeAllUserData(resetsPreferences: false)` reabre las puertas del seed, sin las cuales la
//      persona termina el onboarding SIN NINGUNA CATEGORÍA.
//
//  **La tabla de scopes se prueba EJECUTÁNDOLA, no escaneando el fichero** — es lógica pura y por eso
//  vive fuera de la vista (`ICloudWipeScope`). El cableado de SwiftUI, que no es invocable desde un unit
//  test, sí va por source-scan, con el molde de `WelcomePrivateICloudGateWiringTests`: exigir el destino
//  nuevo y **prohibir el viejo**, que es lo único que impide que el bug vuelva sin ningún otro rojo.
//
//  ## Mutantes verificados (compilados y corridos, no razonados)
//
//  Aplicados con `cp` y no con `git checkout` (el árbol está sucio), compilados y corridos sobre las seis
//  suites del área. El número es de tests ÚNICOS en rojo.
//
//  Los diez del primer diseño:
//   (1) `.importedRows` devolviendo `purgesGroupsDomain = true` → 2 (2.2A rota: le purga los grupos).
//   (2) `.importedRows` devolviendo `resetsPreferences = true` → 2 (al Welcome a mitad de activar).
//   (3) `.zoneOnly` devolviendo `deletesLocalRows = true` → 1 (le vacía el teléfono a quien activa).
//   (4) `onStartFresh` devuelto a `go(to: .onboarding(.freshPrivate))` → 1 (el bug original).
//   (5) `onStartFresh` apuntando a `.privateGate` → 1 (la puerta que solo borra la zona).
//   (6) el `onBack` del case nuevo cambiado a `backFromRestore()` → 1 (echa de la activación).
//   (7) el `clearICloudCorpusWipeArm()` del `onRestore` borrado → 1 (el arm huérfano).
//   (8) `reopenSeedGates` vaciada → 2 (la persona termina sin categorías).
//   (9) la rama `else` de `resetsPreferences` borrada → 2 (lo mismo, por el otro lado).
//  (10) `ProfileImageStorage.delete()` sacado del `if resetsPreferences` → 1 (borra la cara, deja el nombre).
//
//  Y los seis de las correcciones de la review adversarial, que es donde estaban los defectos graves:
//  (11) `&& !showFullModeActivation` quitado del `onChange` → 1 (el alert que desmonta la sheet).
//  (12) `markPending()` quitado del envoltorio → 1 (los gastos de grupo no vuelven al Panel).
//  (13) `prefilledSummary = buildPrefilledSummary()` quitado → 1 (el onboarding salta las categorías).
//  (14) `removeRowDerivedKeys` vaciada → 1 (contadores y punteros de un corpus que ya no está).
//  (15) el `proceed` del `onRestore` cambiado por el del `onProceed` → 1 («Traer mis datos» al onboarding).
//  (16) `SetupChecklistManager.shared.resetAll()` quitado de la rama → 1.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized, .wipeAppGroupMirrorIsolated)
struct ActivationRestoreDiscardTests {

    // MARK: - Helpers de source-scan

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Fuente sin líneas de comentario: documentar un invariante no puede hacer que se «cumpla».
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo entre llaves balanceadas a partir de un marcador, sin comentarios.
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

    /// Argumentos de una llamada, entre paréntesis balanceados y sin comentarios.
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

    /// Tramo entre dos marcadores, sin comentarios. Para leer UN `case` de un `switch`, donde no hay
    /// llaves que balancear y un `contains` sobre el fichero entero lo cumpliría el vecino.
    private static func segment(from start: String, to end: String, in source: String) throws -> String {
        let a = try #require(source.range(of: start), "marcador no encontrado: \(start)")
        let b = try #require(source.range(of: end, range: a.upperBound..<source.endIndex),
                             "marcador de cierre no encontrado tras \(start): \(end)")
        return source[a.upperBound..<b.lowerBound]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Afirma que `first` aparece ANTES que `second`. Un `contains` de cada uno pasa con el orden
    /// invertido, y en un borrado el orden ES la corrección.
    private static func expectOrder(_ first: String, before second: String, in source: String,
                                    _ porque: String,
                                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        let a = try #require(source.range(of: first), "no encontrado: \(first)")
        let b = try #require(source.range(of: second), "no encontrado: \(second)")
        #expect(a.lowerBound < b.lowerBound, Comment(rawValue: porque), sourceLocation: sourceLocation)
    }

    // MARK: - La tabla de scopes (lógica pura, ejecutada)

    /// **Las tres políticas, celda a celda.** Es la tabla del ticket, y cada celda tiene un daño detrás:
    /// una fila que cambia no rompe la compilación y no la ve ningún otro test.
    @Test("cada scope de borrado hace exactamente lo suyo")
    func wipeScopes_matchTheirTable() {
        // scope            filas  prefs  Grupos
        let esperado: [ICloudWipeScope: (Bool, Bool, Bool)] = [
            .zoneOnly:     (false, false, false),
            .importedRows: (true,  false, false),
            .handover:     (true,  true,  true),
        ]
        // `allCases` y no una lista escrita a mano: un scope NUEVO tiene que aparecer aquí o el test cae,
        // en vez de estrenarse sin que nadie haya dicho qué borra.
        #expect(Set(ICloudWipeScope.allCases) == Set(esperado.keys), """
            hay un scope de borrado sin fila en esta tabla. Cada uno tiene que declarar qué se lleva
            ANTES de tener un call-site: lo que está en juego es el corpus de una persona.
            """)
        for (scope, fila) in esperado {
            #expect(scope.deletesLocalRows == fila.0,
                    Comment(rawValue: "\(scope).deletesLocalRows debería ser \(fila.0)"))
            #expect(scope.resetsPreferences == fila.1,
                    Comment(rawValue: "\(scope).resetsPreferences debería ser \(fila.1)"))
            #expect(scope.purgesGroupsDomain == fila.2,
                    Comment(rawValue: "\(scope).purgesGroupsDomain debería ser \(fila.2)"))
        }
    }

    /// **Las dos celdas que separan `.importedRows` de `.handover`, dichas por su daño.** Están arriba en
    /// la tabla, y se repiten aquí porque un `for` sobre un diccionario no dice POR QUÉ importa cada una:
    /// si alguien «simplifica» `.importedRows` a `.handover` —que es lo que un lector apresurado haría,
    /// porque los dos borran filas— estos dos mensajes son los que explican qué se rompe.
    @Test("«Empezar desde cero» dentro de la activación NO resetea preferencias NI purga Grupos")
    func importedRowsScope_preservesPreferencesAndGroups() {
        #expect(ICloudWipeScope.importedRows.resetsPreferences == false, """
            resetear las preferencias se lleva `hasCompletedOnboarding`, y eso manda al Welcome a quien
            está a mitad de activar Yala completo — con la marca de reanudación a medias (restricción del
            paso 8). También se llevaría el nombre y la divisa, que son su prefill (decisión 2.3A).
            """)
        #expect(ICloudWipeScope.importedRows.purgesGroupsDomain == false, """
            purgar el dominio de Grupos aquí es el daño CONTRARIO al que la activación existe para evitar:
            esos grupos son de la misma persona que está activando, y conservarlos es el motivo del flujo
            entero (decisión 2.2A).
            """)
        #expect(ICloudWipeScope.importedRows.deletesLocalRows == true, """
            sin borrar las filas locales esto es el bug original: la zona se vacía, el store espeja, y el
            corpus importado se re-exporta a la zona recién creada.
            """)
    }

    // MARK: - `wipeAllUserData(resetsPreferences:)`, ejecutado

    /// **El borrado que conserva la identidad, corriendo de verdad.** Las filas se van; el nombre, la
    /// divisa y `hasCompletedOnboarding` se quedan; y las puertas del seed se reabren.
    ///
    /// Lo último es H1 del ticket y es lo que más duele si falta: un alta solo-grupos deja
    /// `seedCategoriesExecuted == true`, `seedCategoriesIfNeeded` sale por su flag guard antes de mirar la
    /// base, y la persona termina el onboarding **sin ninguna categoría** — sin «Ajuste de saldo»
    /// incluida, con lo que el saldo inicial falla en silencio.
    @Test("el borrado sin reset conserva la identidad y REABRE las puertas del seed")
    func wipeWithoutPreferenceReset_keepsIdentityAndReopensSeeds() throws {
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.yala.app"
        let snapshot = defaults.persistentDomain(forName: domain) ?? [:]
        defer { defaults.setPersistentDomain(snapshot, forName: domain) }

        let context = try makeTestContext()

        // La identidad de quien está activando, y el estado que la activación necesita vivo.
        defaults.set("Jürgen", forKey: "userName")
        defaults.set("EUR", forKey: "defaultCurrencyCode")
        defaults.set(true, forKey: "hasCompletedOnboarding")
        // Las puertas del seed, cerradas por el alta solo-grupos.
        CategorySeedSentinel.allKeys.forEach { defaults.set(true, forKey: $0) }
        defaults.set(true, forKey: "notificationsSeeded")
        // Los contadores y punteros del corpus que se va.
        defaults.set(42, forKey: "transactionsSavedCount")
        defaults.set(["abc"], forKey: "processedInboxDraftSignatures")
        defaults.set(Date(), forKey: "exchangeRate_lastTodayUpdate")
        let appGroup = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier)
        appGroup?.set(UUID().uuidString, forKey: AppPreferences.Keys.lastUsedAccountID)

        context.insert(Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#111111",
                               iconName: "banknote", type: "cash"))
        context.insert(Yala.Tag(name: "Comida"))
        context.insert(SplitGroup(name: "Viaje"))
        try context.save()

        try DataWipeService.wipeAllUserData(in: context, broadcastSignal: false,
                                            resetsPreferences: false)

        // Las filas personales se van.
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Yala.Tag>()) == 0)
        // El dominio de Grupos NO (2.2A) — `wipeAllUserData` nunca lo nombra, y aquí nadie llama a
        // `wipeLocalGroupsDomain`.
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1, """
            el borrado se llevó el dominio de Grupos: son los grupos de la misma persona que está
            activando, y conservarlos es el motivo de la activación (2.2A).
            """)

        // La identidad se queda (2.3A) — y `hasCompletedOnboarding` es lo que impide el Welcome.
        #expect(defaults.string(forKey: "userName") == "Jürgen", """
            se borró el nombre: es el prefill de quien está activando, no un resto de otra persona.
            """)
        #expect(defaults.string(forKey: "defaultCurrencyCode") == "EUR")
        #expect(defaults.bool(forKey: "hasCompletedOnboarding") == true, """
            se borró `hasCompletedOnboarding`: quien está a mitad de activar Yala completo acaba en el
            Welcome, con la marca de reanudación puesta. Es la restricción del paso 8, literal.
            """)

        // Y las puertas del seed SÍ se reabren: no son preferencias, son estado que tiene que casar con
        // las filas que acabamos de borrar.
        for key in CategorySeedSentinel.allKeys {
            #expect(defaults.object(forKey: key) == nil, """
                el centinela `\(key)` sobrevivió al borrado. `seedCategoriesIfNeeded` sale por su flag
                guard ANTES de mirar la base, así que el seed del final del onboarding es un no-op
                silencioso: la persona termina sin ninguna categoría y sin «Ajuste de saldo».
                """)
        }
        #expect(defaults.object(forKey: "notificationsSeeded") == nil, """
            el centinela de notificaciones sobrevivió: el bootstrap no volverá a sembrarlas sobre una
            base que acaba de quedarse sin ninguna.
            """)

        // Y lo mismo con los contadores y punteros del corpus.
        for key in ["transactionsSavedCount", "processedInboxDraftSignatures", "exchangeRate_lastTodayUpdate"] {
            #expect(defaults.object(forKey: key) == nil, """
                `\(key)` sobrevivió al borrado. Describe a las filas que se acaban de ir, no a la persona:
                dejarlo puesto silencia un barrido, un recordatorio o una recarga que sí hacían falta.
                """)
        }
        #expect(appGroup?.string(forKey: AppPreferences.Keys.lastUsedAccountID) == nil, """
            la última cuenta usada sigue apuntando a una `Account` que este borrado acaba de eliminar: el
            atajo de gasto rápido y el borrador de Apple Pay resuelven a nada.
            """)
    }

    /// **La rama de siempre no cambia**, que es la mitad que 2.1A pedía («default preserva el
    /// comportamiento actual»). Sus tres consumidores —«Vaciar datos», el wipe remoto y el handover del
    /// Welcome— siguen borrando la identidad entera.
    @Test("el default sigue reseteando las preferencias, como antes de partir la función")
    func wipeWithPreferenceReset_stillClearsIdentity() throws {
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.yala.app"
        let snapshot = defaults.persistentDomain(forName: domain) ?? [:]
        defer { defaults.setPersistentDomain(snapshot, forName: domain) }

        let context = try makeTestContext()
        defaults.set("Jürgen", forKey: "userName")
        defaults.set(true, forKey: "hasCompletedOnboarding")

        try DataWipeService.wipeAllUserData(in: context, broadcastSignal: false)

        #expect(defaults.object(forKey: "userName") == nil, """
            el default dejó de resetear las preferencias: «Vaciar datos» de Ajustes y el wipe remoto
            conservarían el nombre del usuario anterior en un dispositivo que declaró el relevo.
            """)
        #expect(defaults.bool(forKey: "hasCompletedOnboarding") == false)
    }

    /// **El helper es UNO, y por eso no puede divergir.** Las dos ramas del borrado necesitan reabrir las
    /// mismas puertas; dos listas que «siempre van juntas» divergen en el commit siguiente, en silencio y
    /// hacia el lado que deja al usuario sin categorías.
    @Test("las puertas del seed las reabre un solo helper, llamado por las dos ramas")
    func seedGatesHaveASingleSource() throws {
        let src = try Self.code("Yala/Utils/DataWipeService.swift")
        #expect(src.components(separatedBy: "CategorySeedSentinel.allKeys").count - 1 == 1, """
            el centinela de categorías se enumera en más de un sitio de este fichero. La lista vive en
            `reopenSeedGates` y nadie más la repite: si una copia se queda atrás, el borrado que la use
            deja al usuario sin categorías y ningún test lo canta.
            """)
        let reopen = try Self.body(of: "static func reopenSeedGates(in defaults: UserDefaults) {", in: src)
        #expect(reopen.contains("CategorySeedSentinel.allKeys"), """
            las DOS keys del centinela, no una: está namespaceado por store (personal vs
            `YalaModel-UITest`) y `UserDefaults.standard` es el mismo almacén para los dos.
            """)
        #expect(reopen.contains("notificationsSeeded"))
        // Las dos llamadas: la rama de siempre (vía `removeUserPreferenceKeys`) y la nueva.
        #expect(src.components(separatedBy: "reopenSeedGates(in:").count - 1 == 2, """
            una de las dos ramas del borrado dejó de reabrir las puertas del seed.
            """)
    }

    /// **La foto de perfil va con la identidad, no con las filas.** Vive fuera de
    /// `resetAllUserPreferences` (es un archivo, no una key), así que sin meterla en el `if` el borrado
    /// conservaba `userName`, `userAlias` y `userProfileIcon` mientras se llevaba la cara.
    @Test("la foto de perfil solo se borra cuando se resetean las preferencias")
    func profilePhotoFollowsTheIdentityFlag() throws {
        let wipe = try Self.body(
            of: "resetsPreferences: Bool = true\n    ) throws {",
            in: try Self.code("Yala/Utils/DataWipeService.swift"))
        let gate = try Self.segment(from: "if resetsPreferences {", to: "}", in: wipe)
        #expect(gate.contains("ProfileImageStorage.shared.delete()"), """
            la foto de perfil salió del gate: se borraría también en el borrado que conserva la identidad,
            dejando el nombre y el icono de quien activa junto a una cara que ya no está.
            """)
    }

    // MARK: - El cableado (source-scan: vive en SwiftUI, no es invocable)

    /// **La puerta nueva y sus tres diferencias con la privada.** Las dos montan la MISMA vista, así que
    /// copiar el cableado de una en la otra compila y no rompe nada más.
    @Test("la puerta de «Empezar desde cero» tiene su borrado, su vuelta y su retirada del arm")
    func discardGate_isWiredToItsOwnExits() throws {
        let src = try Self.source("Yala/App/Views/Groups/FullModeActivationView.swift")
        let gate = try Self.segment(from: "case .restoreDiscardGate:", to: "case .relaunch:", in: src)

        #expect(gate.contains("performWipe: { await performICloudZoneAndImportedRowsWipe() }"), """
            la puerta nueva dejó de recibir el borrado que se lleva las filas importadas. Con el de zona
            vuelve el bug entero: la zona se vacía, el corpus importado se queda, y el espejo lo re-exporta
            — ahora con dos confirmaciones delante para hacerlo creíble.
            Tramo leído: \(gate)
            """)
        #expect(gate.contains("onBack: { go(to: .restore) }"), """
            el «volver» de la puerta nueva dejó de devolver a Restaurar. `backFromRestore()`, tras un
            relanzamiento, es CANCELAR la activación entera
            (`screenBeforeRestore(hasResume: true) == nil`): echaría de la activación a quien solo se
            arrepintió de tocar un botón.
            """)
        // El arm, y va ANTES de salir. Mientras está puesto, `runLateICloudMirrorCheck` lo reanuda a
        // ciegas y con el scope del handover: el recorrido medido en el PR hermano es «borrado fallido →
        // Traer mis datos → restaurar el histórico → terminar → el arranque siguiente lo borra entero».
        let restore = try Self.body(of: "onRestore: {", in: gate)
        #expect(restore.contains("StorageModePersistence.clearICloudCorpusWipeArm()"), """
            «Traer mis datos» sale de la puerta sin retirar el arm del borrado. Mientras está puesto,
            `ContentView.runLateICloudMirrorCheck` lo REANUDA A CIEGAS —y con el scope del handover, o sea
            preferencias y purga de Grupos incluidas—. Esa es la diferencia entre una red y una trampa.
            """)
        // **Y su DESTINO, que tres líneas más arriba tiene su gemelo.** Copiar el `proceed` del `onProceed`
        // aquí compila y no rompe nada: a quien pidió traerse sus datos lo mandaría al onboarding de cero.
        // Es el daño de este mismo ticket por la otra salida.
        #expect(restore.contains("proceed(to: .fullActivationRestore, otherwise: .restore)"), """
            «Traer mis datos» dejó de volver a Restaurar. Cuerpo leído: \(restore)
            """)
    }

    /// **El destino tras borrar NO es el Welcome**, que es el criterio nº2 del ticket. Los dos `proceed`
    /// de la puerta nueva caen por su `otherwise` porque a este punto solo se llega tras un relanzamiento
    /// (el mount ya no es `.neutralNoMirror`), y ese `otherwise` es el onboarding personal de la
    /// activación — no el Welcome ni el chooser.
    @Test("tras borrar, la persona sigue DENTRO de la activación")
    func afterWiping_theUserStaysInsideTheActivation() throws {
        let src = try Self.source("Yala/App/Views/Groups/FullModeActivationView.swift")
        let gate = try Self.segment(from: "case .restoreDiscardGate:", to: "case .relaunch:", in: src)
        let proceed = try Self.body(of: "onProceed: {", in: gate)
        #expect(proceed.contains("proceed(to: .fullActivationPrivate, otherwise: .onboarding(.freshPrivate))"), """
            el desenlace del borrado cambió de destino. Tiene que ser el onboarding personal DE LA
            ACTIVACIÓN: la sesión de grupos sigue intacta y la persona no puede acabar en el Welcome.
            Cuerpo leído: \(proceed)
            """)
        // Y la premisa que lo sostiene, ejecutada y no supuesta.
        //
        // **El control POSITIVO va primero, y sin él este bucle no probaba nada:** `shouldRelaunch` es
        // `requiresMirror(destino) && mount == .neutralNoMirror`, así que filtrar los mounts por
        // `!= .neutralNoMirror` deja el segundo término en `false` y la negación se cumple para CUALQUIER
        // destino — la lista sería decorativa y cambiarla por `.cloudAccount` la dejaría igual de verde.
        // Lo que distingue a estos dos es que SÍ piden espejo, y eso es lo que afirma la primera mitad.
        for destino in [WelcomeMirrorRelaunchLogic.Destination.fullActivationPrivate,
                        .fullActivationRestore] {
            #expect(WelcomeMirrorRelaunchLogic.shouldRelaunch(destination: destino,
                                                              mountedDecision: .neutralNoMirror), """
                \(destino) dejó de pedir espejo: entonces el camino a `.restore` ya no relanza, el store
                NO espeja, y el borrado de esta puerta se lleva por delante lo local de quien activa sin
                que nada lo hubiera importado de iCloud.
                """)
            for mount in SwiftDataConfiguration.PersonalStoreDecision.allCases where mount != .neutralNoMirror {
                #expect(!WelcomeMirrorRelaunchLogic.shouldRelaunch(destination: destino,
                                                                   mountedDecision: mount), """
                    con el mount \(mount), \(destino) volvería a relanzar: la persona vería otra vez la
                    pantalla de «reabre la app» justo después de confirmar un borrado.
                    """)
            }
        }
    }

    // MARK: - Los tres scopes, cada uno en SU call-site

    /// **Un scope en el call-site equivocado compila y no rompe ningún otro test.** Son cinco llamadas y
    /// tres políticas: el enum obliga a elegir, no a elegir BIEN. Cada una con su literal, y el del aviso
    /// tardío es el que este PR estrenó como modo de fallo —antes no había scope que equivocar ahí—.
    @Test("cada call-site del borrado pide el scope que le toca")
    func everyWipeCallSite_asksForItsOwnScope() throws {
        let src = try Self.code("Yala/App/ContentView.swift")

        // El aviso del espejo tardío: handover completo. Con `.zoneOnly` dejaría el corpus viejo entero en
        // el teléfono; con `.importedRows` no sellaría el dominio de Grupos, que es el criterio nº4 del
        // ticket hermano.
        let late = try Self.call(of: "LateICloudMirrorNoticeView(", in: src)
        #expect(late.contains("performWipe: { await performICloudCorpusWipe(.handover) }"), """
            el aviso del espejo tardío cambió de scope. Es el borrado de una frontera de usuario: tiene que
            llevarse las filas, las preferencias y el dominio de Grupos. Tramo leído: \(late)
            """)

        // **El reenvío de dentro del modifier NO lleva scope, y esa ausencia es lo que se afirma.** Es el
        // eslabón del medio de la cadena (call-site → reenvío → container) y el único que nadie miraba:
        // cambiarlo por `performDeviceCorpusWipe()` compila y deja verde todo lo demás, con lo que el
        // Welcome pasaría a borrar el teléfono y a dejar la zona de iCloud entera.
        let modifier = try Self.body(of: "private struct WelcomeFlowModifier: ViewModifier {", in: src)
        #expect(modifier.contains("performICloudCorpusWipe: { await performICloudCorpusWipe() }"), """
            el reenvío de `WelcomeFlowModifier` dejó de reenviar su propio closure. Quien elige el scope es
            el envoltorio que se lo pasa, no este eslabón, y cambiarlo por `performDeviceCorpusWipe()`
            —que borra las filas del teléfono y NO toca la zona— haría que el espejo vuelva a bajar el
            corpus entero.
            """)
        // **La prohibición va por la PAREJA argumento→closure, no por el nombre suelto**, y esa es una
        // corrección: el modifier reenvía también `performDeviceCorpusWipe`, con razón, así que prohibir
        // el identificador a secas ponía rojo el árbol sano.
        #expect(!modifier.contains("performICloudCorpusWipe: { await performDeviceCorpusWipe() }"), """
            el reenvío del borrado de iCloud pasó al del TELÉFONO: borra las filas locales y deja la zona
            entera, así que el espejo vuelve a bajar el corpus.
            """)
    }

    // MARK: - Lo que el borrado deliberado NO puede despertar

    /// **El alert de wipe remoto, y este `guard` cierra un defecto ALTA que el PR introdujo.**
    ///
    /// El borrado de «Empezar desde cero» baja `hasPersonalData` desde su propio envoltorio, y cancelar la
    /// gracia allí no sirve: la tarea la crea este `onChange` en el update SIGUIENTE. El término
    /// `hasCompletedOnboarding` tampoco tapa, porque `.importedRows` lo conserva a propósito — es el único
    /// scope que llega aquí con el guard abierto. Cinco segundos después saltaba un alert que dice que te
    /// borraron los datos en otro dispositivo, **sobre la sheet de la activación, desmontándola**.
    @Test("un borrado hecho DENTRO de la activación no levanta el alert de wipe remoto")
    func deliberateWipeInsideActivation_neverLooksLikeARemoteWipe() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let onChange = try Self.body(of: ".onChange(of: hasPersonalData) { oldValue, newValue in", in: src)
        #expect(onChange.contains("&& !showFullModeActivation"), """
            el guard perdió el término de la activación. Quien está activando y acaba de confirmar un
            borrado ve, cinco segundos después, un alert que le dice que le borraron los datos en OTRO
            dispositivo — y ese alert, colgado del anchor de `ContentView`, le desmonta la sheet.
            Cuerpo leído: \(onChange)
            """)
        // El orden importa: el término va DENTRO de la condición que arma la gracia, no en el `else if`
        // que la cancela (ese sí tiene que seguir corriendo cuando los datos reaparecen).
        //
        // **El ancla de la derecha dejó de ser el encendido del alert el 2026-09-14**
        // (`remote-wipe-alert-skips-the-router`): la gracia ya no enciende nada, PIDE el aviso por la
        // cola del router. El término sigue teniendo que ir por delante de esa petición, que es lo que
        // impide que la tarea NAZCA mientras la activación está en pantalla.
        try Self.expectOrder("&& !showFullModeActivation",
                             before: "RouterEntryGate.shared.submit(.presentRemoteWipeNotice)",
                             in: onChange, """
            el término quedó por debajo del armado de la gracia: entonces no la impide, solo la adorna.
            """)
    }

    /// **Las filas puenteadas de los grupos vuelven.** El borrado se las lleva —`wipeAllUserData` borra
    /// `TransactionItem` sin predicado— y ningún camino las repone: `retryPendingBridges` solo mira las
    /// `bridgePending`, y el plan de cierre de `.freshPrivate` no converge. Sin la intención durable, la
    /// persona conserva sus grupos y sus saldos con el Panel y el Inbox vacíos de gastos de grupo.
    @Test("tras el borrado queda pedida la convergencia del bridge de Grupos")
    func discardWipe_asksForTheGroupsBridgeToConverge() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wrapper = try Self.body(of: "performICloudZoneAndImportedRowsWipe: {", in: src)
        #expect(wrapper.contains("GroupsBridgeRestoreConvergenceStore.markPending()"), """
            el borrado dejó de pedir la convergencia: las filas personales de los gastos de grupo se van
            con el resto y no las repone nadie. Cuerpo leído: \(wrapper)
            """)
        // Detrás del corte del fallo: un borrado que no ocurrió no dejó nada que converger, y la marca
        // durable haría re-puentear todo el dominio en el arranque siguiente sin motivo.
        try Self.expectOrder("guard failure == nil else { return failure }",
                             before: "GroupsBridgeRestoreConvergenceStore.markPending()", in: wrapper, """
            la marca de convergencia se pide también cuando el borrado FALLÓ: nada se borró, así que no hay
            nada que reponer, y el arranque siguiente re-puentea el dominio entero por nada.
            """)
    }

    /// **El prefill se re-mide tras el borrado.** Se construye una sola vez en el `.onAppear` de la raíz,
    /// que aquí corre DESPUÉS del relanzamiento — o sea contando las categorías que el borrado se va a
    /// llevar. Con el conteo rancio, `OnboardingStepPlan` salta el paso de categorías y la persona se
    /// queda sin la pantalla donde podía decir que no las quiere.
    @Test("el prefill del onboarding se recalcula cuando el borrado lo invalida")
    func discardGate_rebuildsThePrefillAfterWiping() throws {
        let src = try Self.source("Yala/App/Views/Groups/FullModeActivationView.swift")
        let gate = try Self.segment(from: "case .restoreDiscardGate:", to: "case .relaunch:", in: src)
        let proceed = try Self.body(of: "onProceed: {", in: gate)
        #expect(proceed.contains("prefilledSummary = buildPrefilledSummary()"), """
            el prefill no se recalcula: `prefilledCategoriesCount` sigue diciendo que hay categorías sobre
            un store recién vaciado, y el onboarding salta su paso sin preguntar. Cuerpo leído: \(proceed)
            """)
        try Self.expectOrder("prefilledSummary = buildPrefilledSummary()", before: "proceed(to:",
                             in: proceed, """
            el recálculo va DESPUÉS de salir: para entonces el onboarding ya fijó su primer paso con el
            resumen viejo (`OnboardingView.init`).
            """)
    }

    /// **El estado derivado de las filas lo barre un solo helper**, igual que las puertas del seed. Dos
    /// listas que «siempre van juntas» divergen en el commit siguiente.
    @Test("los contadores y punteros del corpus los barre un solo helper, llamado por las dos ramas")
    func rowDerivedKeysHaveASingleSource() throws {
        let src = try Self.code("Yala/Utils/DataWipeService.swift")
        #expect(src.components(separatedBy: "\"transactionsSavedCount\"").count - 1 == 1, """
            los contadores del corpus se enumeran en más de un sitio de este fichero. La lista vive en
            `removeRowDerivedKeys` y nadie más la repite.
            """)
        #expect(src.components(separatedBy: "removeRowDerivedKeys(from:").count - 1 == 2, """
            una de las dos ramas del borrado dejó de barrer el estado derivado de las filas.
            """)
        // Y los dos singletons que no son keys, que por eso no caben en el helper.
        // Acotado al cuerpo del `if resetsPreferences`, cuyo `else` es la rama que nos interesa. Un
        // `segment(from: "} else {")` cogería el primero del fichero, que no es éste.
        // Acotado al cuerpo del `else` de `if resetsPreferences`, y con marcadores de CÓDIGO: `src` viene
        // de `code(...)`, que ya quitó los comentarios, así que un `// ===` como cierre no existe ahí.
        let rama = try Self.segment(from: "resetAllUserPreferences()\n        } else {",
                                    to: "WidgetDataCache.clearCache()", in: src)
        #expect(rama.contains("SetupChecklistManager.shared.resetAll()"), """
            la checklist de puesta en marcha sigue afirmando «tu primer gasto» y «tu primer presupuesto»
            sobre filas que ya no existen. Sus siete pasos son todos de la vida PERSONAL, así que
            resetearla aquí no toca nada del dominio de Grupos.
            """)
        // **Las DOS ausencias son la decisión**, y las dos por el mismo motivo: el dominio de Grupos
        // sobrevive a este borrado, y los dos resets se llevan cosas suyas por delante.
        for (llamada, porque) in [
            ("AppRouter.shared.resetAll()",
             "se lleva `PendingJoinStore` y los arms de invitación de Grupos"),
            ("DeferredIntentBuffer.shared.clear()",
             "su `SerializableIntent` tiene un case `.navigateGroupDetail(groupID:)`, así que el buffer puede llevar dentro la navegación a un grupo que SIGUE vivo")] {
            #expect(!rama.contains(llamada), Comment(rawValue: """
                la rama que conserva las preferencias llama a `\(llamada)`, y eso \(porque) — el dominio                 que este borrado existe para NO tocar.
                """))
        }
    }

    /// **El case nuevo va al FINAL del enum.** Uno en medio corre los índices de los `Screen`, que es
    /// exactamente el número por el que se diagnostica un flujo por pantalla en device.
    @Test("el case nuevo se añadió al final de Screen")
    func newScreenCaseIsLast() throws {
        let src = try Self.code("Yala/App/Logic/FullModeActivationFlowLogic.swift")
        let enumBody = try Self.body(of: "enum Screen: Equatable {", in: src)
        let cases = enumBody.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }
        #expect(cases.last == "case restoreDiscardGate", """
            el case nuevo dejó de ser el último: un case en medio cambia el número de pantalla con el que
            se diagnostica el flujo en device. Cases leídos: \(cases)
            """)
    }
}
