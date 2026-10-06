//
//  RemoteWipeGraceLogicTests.swift
//  YalaTests
//
//  **Un borrado hecho en ESTE teléfono no arranca la gracia del aviso «tus datos fueron eliminados de iCloud»**
//  (ticket `wipe-data-does-not-cancel-the-remote-wipe-grace`).
//
//  Dos celdas lo arrancaban porque reponen `hasCompletedOnboarding` y dejan abierto el guard que salvaba a los
//  demás borrados: «Vaciar datos» en solo-grupos y el restore remoto con el onboarding ya hecho en otro
//  dispositivo. **Todo se mide con el eje de sesión a `true`**: en solo-grupos el eje da `false` y calla el aviso
//  por su cuenta, así que con el eje apagado el arreglo y el tapón no se distinguen.
//
//  Dos mitades, en una sola `@Suite` a propósito (`-only-testing` filtra por TIPO: una segunda suite en este
//  fichero no correría cuando el gate acota por la primera):
//    · el COMPORTAMIENTO del tipo puro que `ContentView` usa tal cual;
//    · el CABLEADO en los tres sitios que no son invocables (`ContentView` y `UserDataResetView` son vistas, sus
//      funciones son `private`). Sin él, quitar una llamada deja la primera mitad en verde con el bug vivo.
//

import Foundation
import Testing

@testable import Yala

@Suite("La gracia del vaciado remoto · un borrado deliberado de este teléfono no la arranca")
struct RemoteWipeGraceLogicTests {

    // MARK: - Comportamiento

    /// **Cómo se fuerza el eje a `true`**: la decisión de la transición NO lo lee —el eje solo interviene al vencer
    /// la gracia, dentro de la tarea—, así que todo lo de abajo vale igual con el eje encendido. Lo que sí hay que
    /// fijar es que el eje de la celda con daño real —el restore remoto, que solo corre en una sesión privada— está
    /// encendido: si no lo estuviera, el aviso se callaría solo y el arreglo no se distinguiría del tapón.
    @Test("el eje de la sesión privada da `true`: el arreglo no se apoya en el tapón")
    func theAxisIsOnWhereTheDamageWas() {
        #expect(DestructiveScopeLogic.wipeSignalObeyedByThisSession(confirmedPrivateSession: true,
                                                                    storageMode: .icloud), """
            el eje de una sesión privada ya no obedece la señal. Estos tests suponen que sí: con el eje en `false` el \
            aviso se calla solo y no distinguen el arreglo del tapón.
            """)
    }

    @Test("«Vaciar datos» en solo-grupos: la caída se absorbe aunque el aterrizaje reponga el onboarding")
    func wipeDataInGroupsOnly_doesNotStartTheGrace() {
        var grace = RemoteWipeGraceLogic()
        grace.settleAfterDeliberateWipe(measuredPersonalData: false)
        let reaction = grace.personalDataChanged(from: true, to: false,
                                                 hasCompletedOnboarding: true,   // `applyWipeLanding(.groupsShell)`
                                                 isShowingFullModeActivation: false)
        #expect(reaction == .absorbDeliberateDrop, """
            a quien acaba de vaciar sus datos le salta, cinco segundos después, que se los borraron desde otro \
            dispositivo.
            """)
    }

    @Test("restore remoto, las dos ramas de `skipOnboarding`: la caída se absorbe en las dos",
          arguments: [true, false])
    func remoteRestore_doesNotStartTheGrace(onboardingRestored: Bool) {
        var grace = RemoteWipeGraceLogic()
        grace.settleAfterDeliberateWipe(measuredPersonalData: false)
        let reaction = grace.personalDataChanged(from: true, to: false,
                                                 hasCompletedOnboarding: onboardingRestored,
                                                 isShowingFullModeActivation: false)
        #expect(reaction == .absorbDeliberateDrop, """
            el aviso «tus datos fueron eliminados de iCloud» sale justo después del toast que dice lo contrario.
            """)
    }

    @Test("el vaciado remoto DE VERDAD —nadie borró aquí— sigue arrancando la gracia y pidiendo el aviso")
    func aRealRemoteWipe_stillStartsTheGrace() {
        var grace = RemoteWipeGraceLogic()
        let reaction = grace.personalDataChanged(from: true, to: false,
                                                 hasCompletedOnboarding: true,
                                                 isShowingFullModeActivation: false)
        #expect(reaction == .startGrace, "el vaciado remoto real se quedó sin aviso")
    }

    @Test("la absorción vale para UNA caída: la siguiente, tras volver los datos, vuelve a arrancar la gracia")
    func theAbsorptionIsSingleUse() {
        var grace = RemoteWipeGraceLogic()
        grace.settleAfterDeliberateWipe(measuredPersonalData: false)
        #expect(grace.personalDataChanged(from: true, to: false, hasCompletedOnboarding: true,
                                          isShowingFullModeActivation: false) == .absorbDeliberateDrop)
        #expect(grace.personalDataChanged(from: false, to: true, hasCompletedOnboarding: true,
                                          isShowingFullModeActivation: false) == .cancelGrace)
        #expect(grace.personalDataChanged(from: true, to: false, hasCompletedOnboarding: true,
                                          isShowingFullModeActivation: false) == .startGrace, """
            la absorción sobrevivió a su caída: un vaciado remoto posterior quedaría mudo.
            """)
    }

    @Test("sin caída que absorber —la señal ya era `false`—, la subida siguiente desarma la absorción")
    func aRiseDisarmsAnAbsorptionThatNeverFired() {
        var grace = RemoteWipeGraceLogic()
        grace.settleAfterDeliberateWipe(measuredPersonalData: false)
        #expect(grace.personalDataChanged(from: false, to: true, hasCompletedOnboarding: true,
                                          isShowingFullModeActivation: false) == .cancelGrace)
        #expect(!grace.absorbsNextDrop)
        #expect(grace.personalDataChanged(from: true, to: false, hasCompletedOnboarding: true,
                                          isShowingFullModeActivation: false) == .startGrace)
    }

    @Test("si la medida dice que los datos siguen —el borrado lanzó antes de tocar nada—, no se arma nada")
    func aWipeThatLeftTheDataArmsNothing() {
        var grace = RemoteWipeGraceLogic()
        grace.settleAfterDeliberateWipe(measuredPersonalData: true)
        #expect(!grace.absorbsNextDrop)
        #expect(grace.personalDataChanged(from: true, to: false, hasCompletedOnboarding: true,
                                          isShowingFullModeActivation: false) == .startGrace)
    }

    /// Los cuatro hermanos —el «empiezo de cero» del Welcome, el corpus del dispositivo, la puerta privada y
    /// «Restaurar → empezar desde cero»— se salvan por los dos guards de siempre. Sin absorción armada, siguen igual.
    @Test("los guards de siempre no regresan: sin onboarding, o con la activación en pantalla, no hay gracia")
    func theExistingGuardsStillHold() {
        var grace = RemoteWipeGraceLogic()
        #expect(grace.personalDataChanged(from: true, to: false, hasCompletedOnboarding: false,
                                          isShowingFullModeActivation: false) == .ignore)
        #expect(grace.personalDataChanged(from: true, to: false, hasCompletedOnboarding: true,
                                          isShowingFullModeActivation: true) == .ignore)
        #expect(grace.personalDataChanged(from: false, to: true, hasCompletedOnboarding: true,
                                          isShowingFullModeActivation: false) == .cancelGrace)
    }

    @Test("pedir el asentamiento avanza el contador que observa `ContentView`")
    @MainActor
    func requestingTheSettleIsObservable() {
        let session = SessionState()
        let before = session.deliberateWipeSettleRequests
        session.requestDeliberateWipeSettle()
        session.requestDeliberateWipeSettle()
        #expect(session.deliberateWipeSettleRequests == before &+ 2, """
            la petición de «Vaciar datos» ya no cambia nada que `ContentView` observe: el cableado de abajo sigue en \
            verde y el aviso vuelve.
            """)
    }

    // MARK: - Cableado

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // …/YalaTests
        .deletingLastPathComponent()   // raíz

    /// Texto sin comentarios —también los de cola— y con los espacios colapsados a uno.
    private static func code(_ path: String) throws -> String {
        var raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        raw = raw.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// El cuerpo entre llaves balanceadas que abre la primera `{` tras `marker`, sin las llaves de fuera.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let tail = source[start.upperBound...]
        let open = try #require(tail.firstIndex(of: "{"), "sin llave tras el marcador: \(marker)")
        var depth = 0
        var index = open
        while index < tail.endIndex {
            if tail[index] == "{" { depth += 1 }
            if tail[index] == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            index = tail.index(after: index)
        }
        return String(tail[tail.index(after: open)..<index]).trimmingCharacters(in: .whitespaces)
    }

    /// El tramo entre la primera aparición de `from` y la primera de `to` que la sigue.
    private static func between(_ from: String, and to: String, in source: String) throws -> String {
        let start = try #require(source.range(of: from), "no aparece «\(from)»")
        let end = try #require(source[start.upperBound...].range(of: to), "«\(to)» no aparece detrás de «\(from)»")
        return String(source[start.upperBound..<end.lowerBound])
    }

    private static func count(_ needle: String, in source: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    private static let abre = "("

    @Test("MUTACIÓN: `ContentView` decide la transición con el tipo puro, y absorber CANCELA")
    func contentViewReactsThroughTheLogic() throws {
        let vista = try Self.code("Yala/App/ContentView.swift")
        // El marcador acaba ANTES de la llave del closure: `body(of:)` abre en la primera `{` que lo sigue.
        let onChange = try Self.body(of: ".onChange(of: hasPersonalData)", in: vista)
        let cabecera = "oldValue, newValue in switch wipeGrace.personalDataChanged(from: oldValue, to: newValue, "
            + "hasCompletedOnboarding: hasCompletedOnboarding, "
            + "isShowingFullModeActivation: showFullModeActivation) {"
        #expect(onChange.hasPrefix(cabecera), """
            el `onChange` de `hasPersonalData` ya no decide por `RemoteWipeGraceLogic`, o delante hay algo que \
            corre antes de la decisión. Los tests de comportamiento de arriba quedarían en verde sin medir nada.
            Cuerpo leído: \(onChange.prefix(300))
            """)
        #expect(onChange.contains("case .absorbDeliberateDrop: cancelWipeGrace() case .startGrace:"), """
            la caída absorbida ya no cancela la gracia: una que ya corría —por un hueco de CloudKit de antes del \
            borrado— seguiría y pediría el aviso sobre datos que la persona acaba de borrar.
            """)
        let arranque = try Self.between("case .startGrace:", and: "case .cancelGrace:", in: onChange)
        #expect(arranque.contains("wipeGraceTask = Task {")
                && arranque.contains("RouterEntryGate.shared.submit(.presentRemoteWipeNotice)"), """
            la gracia ya no nace SOLO en la rama `.startGrace`: otra reacción la arrancaría.
            """)
    }

    /// **Por IGUALDAD, no por `contains`**: una sentencia antepuesta —un `hasPersonalData = …` delante de
    /// `settleAfterDeliberateWipe`— escribe la señal con la absorción todavía desarmada, y un `contains` lo deja pasar.
    @Test("MUTACIÓN: el asentamiento arma la absorción ANTES de escribir la señal")
    func theSettleArmsBeforeItWrites() throws {
        let vista = try Self.code("Yala/App/ContentView.swift")
        let cuerpo = try Self.body(of: "private func settleSignalsAfterDeliberateWipe()", in: vista)
        #expect(cuerpo == "cancelWipeGrace() hasExistingData = checkHasExistingData() "
                + "let measuredPersonalData = checkHasPersonalData() "
                + "wipeGrace.settleAfterDeliberateWipe(measuredPersonalData: measuredPersonalData) "
                + "hasPersonalData = measuredPersonalData", """
            el asentamiento cambió de forma. Tiene que medir, armar la absorción y SOLO ENTONCES escribir la señal: \
            al revés, el `onChange` de la caída puede encontrarla desarmada y arrancar la gracia.
            Cuerpo leído: \(cuerpo)
            """)
        #expect(vista.contains(".onChange(of: SessionState.shared.deliberateWipeSettleRequests) { _, _ in "
                               + "settleSignalsAfterDeliberateWipe() }"), """
            `ContentView` ya no atiende las peticiones de asentamiento: «Vaciar datos» las pide y nadie las oye.
            """)
        #expect(Self.count("settleSignalsAfterDeliberateWipe()", in: vista) == 6, """
            el asentamiento tiene un número inesperado de apariciones: la definición, el observador de «Vaciar \
            datos», el receptor de la señal remota y, desde el 2026-10-06, los tres borrados del Welcome que \
            conservan los grupos del aviso tardío (el de iCloud, el del teléfono y el del alert, por su closure).
            """)
    }

    @Test("MUTACIÓN: el restore remoto asienta tras borrar, antes de cualquier `await` y fuera de las dos ramas")
    func theRemoteRestoreSettlesInBothBranches() throws {
        let vista = try Self.code("Yala/App/ContentView.swift")
        let receptor = try Self.body(of: "private func performLocalWipeForRemoteSync(", in: vista)
        // **Por igualdad del tramo, no por ausencia de `await`** (review adversarial): con un `between` sobrevivían
        // el asentamiento movido SOLO al `catch` —la primera aparición caía ahí y el éxito se quedaba sin él— y el
        // envuelto en un `Task { }`, que lo difiere detrás del render sin escribir la palabra `await`.
        let tramo = "print(\"ContentView: Remote wipe failed: \\(error)\") #endif } "
            + "settleSignalsAfterDeliberateWipe() try? await Task.sleep(for: .milliseconds(200))"
        #expect(Self.count(tramo, in: receptor) == 1, """
            el asentamiento del restore remoto ya no va justo DETRÁS del `do/catch` del borrado y antes de su primer \
            `await`. Dentro del `do` se pierde el caso de fallo; dentro del `catch`, el de éxito; detrás del `sleep` o \
            en un `Task`, un render intermedio baja la señal sin la absorción; en una rama de `skipOnboarding`, la \
            otra vuelve a arrancar la gracia.
            Esperado: \(tramo)
            """)
        #expect(Self.count("settleSignalsAfterDeliberateWipe()", in: receptor) == 1)
        let borrado = "try DataWipeService.wipeLocallyForRemoteWipeSignal" + Self.abre
        _ = try Self.between(borrado, and: tramo, in: receptor)
        _ = try Self.between(tramo, and: "if skipOnboarding {", in: receptor)
    }

    @Test("MUTACIÓN: «Vaciar datos» pide el asentamiento en la vuelta del borrado, en éxito y en fallo")
    func wipeDataRequestsTheSettle() throws {
        let vista = try Self.code("Yala/App/Views/Settings/UserDataResetView.swift")
        let cuerpo = try Self.body(of: "private func handleWipeAllData() async", in: vista)
        let borrado = "try DataWipeService.wipePersonalDataKeepingGroups" + Self.abre
        let peticion = "sessionState.requestDeliberateWipeSettle()"
        let tramo = try Self.between(borrado, and: peticion, in: cuerpo)
        #expect(!tramo.contains("await"), """
            entre el borrado y la petición hay un `await`: un render intermedio puede bajar la señal con la absorción \
            desarmada, y en solo-grupos vuelve el aviso a los cinco segundos. Tramo: \(tramo)
            """)
        // Por igualdad, pegada al aterrizaje: un `Task { }` alrededor la difiere sin escribir `await`.
        #expect(Self.count("applyWipeLanding(landing) " + peticion + " themeManager.resetToDefaults()", in: cuerpo) == 1, """
            la petición ya no va pegada al aterrizaje, en la misma vuelta del borrado. Tramo: \(tramo)
            """)
        let fallo = try Self.body(of: "} catch", in: String(cuerpo[try #require(cuerpo.range(of: borrado)).upperBound...]))
        #expect(fallo.hasPrefix(peticion + " isProcessing = false"), """
            un borrado que falla a media lista baja la señal igual, y ya no lo anuncia como deliberado.
            Rama leída: \(fallo)
            """)
        #expect(Self.count(peticion, in: cuerpo) == 2)
    }
}
