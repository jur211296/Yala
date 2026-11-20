//
//  WelcomeCarruselBarrasYToqueTests.swift
//  YalaTests
//
//  La vitrina del Welcome como historias (encargo del 19-nov): las barras anteriores llenas, la actual avanzando y las
//  siguientes vacías, al avanzar solo, al deslizar y con pausa; tocar la mitad del final avanza y la del principio
//  vuelve; VoiceOver cambia de función con sus acciones. Y los dos arreglos chicos del lote: «Empezar desde cero» como
//  botón destructivo de 44 pt y el aviso de fallo que ya no dice «tus datos siguen aquí» tras un borrado a medias.
//

import Foundation
import Testing

@testable import Yala

private func source(_ path: String, file: StaticString = #filePath) throws -> String {
    let root = URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appending(path: path), encoding: .utf8)
}

// MARK: - Barras

@Suite("Welcome · las barras de la vitrina como historias")
struct WelcomeCarruselBarrasTests {
    typealias L = WelcomeShowcaseLogic

    private func fills(current: Int, count: Int, progress: Double) -> [Double] {
        (0..<count).map { L.segmentFill(at: $0, current: current, progress: progress) }
    }

    /// El bug de la build 2.3 (5): al pasar a la segunda, la primera seguía llenándose a la vez que la nueva.
    @Test func alPasarALaSegunda_laPrimeraQuedaLlenaYSoloAvanzaLaActual() {
        #expect(fills(current: 1, count: 3, progress: 0.2) == [1, 0.2, 0])
    }

    @Test func alVolverAtras_lasSiguientesQuedanVacias() {
        #expect(fills(current: 0, count: 6, progress: 0) == [0, 0, 0, 0, 0, 0])
        #expect(fills(current: 3, count: 6, progress: 0.5) == [1, 1, 1, 0.5, 0, 0])
    }

    @Test func elAvanceSeAcotaEntreCeroYUno() {
        #expect(L.segmentFill(at: 2, current: 2, progress: -0.4) == 0)
        #expect(L.segmentFill(at: 2, current: 2, progress: 1.7) == 1)
    }

    @Test func elRelojCorreYSeLlenaEnLoQueDuraCadaFuncion() {
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        let clock = L.StoryClock.started(at: t0, running: true)
        #expect(clock.progress(at: t0, dwell: 5) == 0)
        #expect(clock.progress(at: t0.addingTimeInterval(2.5), dwell: 5) == 0.5)
        #expect(clock.progress(at: t0.addingTimeInterval(9), dwell: 5) == 1)
        #expect(clock.remaining(at: t0.addingTimeInterval(4), dwell: 5) == 1)
    }

    @Test func conPausa_laBarraSeCongelaYAlReanudarSigueDesdeAhi() {
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        var clock = L.StoryClock.started(at: t0, running: true)
        clock.pause(at: t0.addingTimeInterval(2))
        #expect(clock.progress(at: t0.addingTimeInterval(30), dwell: 5) == 0.4, "La pausa tiene que congelar la barra.")
        clock.resume(at: t0.addingTimeInterval(30))
        #expect(clock.remaining(at: t0.addingTimeInterval(30), dwell: 5) == 3,
                "Al reanudar le queda lo que le faltaba, no otros cinco segundos.")
        #expect(clock.progress(at: t0.addingTimeInterval(31.5), dwell: 5) == 0.7)
    }

    @Test func unaFuncionNuevaConPausaEmpiezaVaciaYQuieta() {
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        let clock = L.StoryClock.started(at: t0, running: false)
        #expect(!clock.isRunning)
        #expect(clock.progress(at: t0.addingTimeInterval(10), dwell: 5) == 0)
    }

    @Test func pausarYReanudarDosVecesNoSumaDeMas() {
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        var clock = L.StoryClock.started(at: t0, running: true)
        clock.resume(at: t0.addingTimeInterval(1))  // ya corría: no reinicia
        clock.pause(at: t0.addingTimeInterval(1))
        clock.pause(at: t0.addingTimeInterval(4))   // ya parado: no suma
        #expect(clock.elapsed(at: t0.addingTimeInterval(9)) == 1)
    }

    @Test func lasFuncionesDuranCincoSegundos() {
        #expect(L.dwellSeconds == 5)
    }
}

// MARK: - Toque

@Suite("Welcome · tocar la vitrina")
struct WelcomeCarruselToqueTests {
    typealias L = WelcomeShowcaseLogic

    @Test func laMitadDerechaAvanza_yLaIzquierdaVuelve() {
        #expect(L.tapStep(atX: 300, width: 340) == 1)
        #expect(L.tapStep(atX: 170, width: 340) == 1)
        #expect(L.tapStep(atX: 20, width: 340) == -1)
        #expect(L.tapStep(atX: 169, width: 340) == -1)
    }

    @Test func deDerechaAIzquierda_lasMitadesSeInvierten() {
        #expect(L.tapStep(atX: 300, width: 340, rightToLeft: true) == -1)
        #expect(L.tapStep(atX: 20, width: 340, rightToLeft: true) == 1)
    }

    @Test func sinAnchoMedido_avanza() {
        #expect(L.tapStep(atX: 0, width: 0) == 1)
    }

    /// Las barras salen del reloj: ninguna anima su propio relleno (era lo que dejaba a la anterior llenándose).
    @Test func lasBarrasNoAnimanSuPropioRelleno() throws {
        let view = try source("Yala/App/Views/Onboarding/WelcomeShowcaseView.swift")
        #expect(!view.contains("withAnimation(.linear(duration: 5))"))
        #expect(view.contains("WelcomeShowcaseLogic.segmentFill(at:"))
        #expect(view.contains("TimelineView(.animation(minimumInterval: nil, paused: !rotates))"))
        #expect(view.contains(".transaction { $0.animation = nil }"))
    }

    /// Tocar la vitrina cambia de función por mitades; la pausa queda solo en su botón (un `Button` hijo, que gana su
    /// toque al de la vitrina). Y VoiceOver tiene «Siguiente» y «Anterior».
    @Test func elToqueCambiaDeFuncion_laPausaEsSuBoton_yVoiceOverTieneSusAcciones() throws {
        let view = try source("Yala/App/Views/Onboarding/WelcomeShowcaseView.swift")
        #expect(view.contains(".onTapGesture(coordinateSpace: .local) { location in"))
        #expect(view.contains("WelcomeShowcaseLogic.tapStep(atX: location.x, width: stageWidth)"))
        #expect(view.components(separatedBy: "paused.toggle()").count - 1 == 1,
                "La pausa solo la cambia su botón; el toque de la vitrina ya no pausa.")
        #expect(view.contains(".accessibilityAdjustableAction"))
        #expect(view.contains(".accessibilityAction(named: WelcomeCarruselTexto.next)"))
        #expect(view.contains(".accessibilityAction(named: WelcomeCarruselTexto.previous)"))
    }
}

// MARK: - Textos

@Suite("Welcome · textos de la vitrina en los 16 idiomas")
struct WelcomeCarruselTextosTests {
    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String) throws -> [String: String] {
        let text = try source("Yala/Resources/\(locale).lproj/WelcomeCarrusel.strings")
        let plist = try PropertyListSerialization.propertyList(from: Data(text.utf8), format: nil)
        return try #require(plist as? [String: String])
    }

    @Test(arguments: locales)
    func cadaIdioma_tieneSiguienteYAnterior(locale: String) throws {
        let tabla = try Self.table(locale)
        #expect(Set(tabla.keys) == ["welcomeCarrusel.next", "welcomeCarrusel.previous"])
        for (clave, valor) in tabla {
            #expect(!valor.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(clave) vacía.")
        }
        #expect(tabla["welcomeCarrusel.next"] != tabla["welcomeCarrusel.previous"])
    }

    @Test func esYPt_sonCopiaDeSuReferencia() throws {
        #expect(try Self.table("es") == Self.table("es-419"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    @Test func ningunTexto_enLocalizable() throws {
        #expect(try !source("Yala/Resources/es-419.lproj/Localizable.strings").contains("\"welcomeCarrusel."))
    }

    @Test func laAppLeeSuTabla() {
        #expect(WelcomeCarruselTexto.next != "welcomeCarrusel.next")
        #expect(WelcomeCarruselTexto.previous != "welcomeCarrusel.previous")
    }
}

// MARK: - Los dos arreglos chicos

@Suite("Welcome · «Empezar desde cero» y el aviso de su fallo")
struct WelcomeEmpezarDeCeroTests {

    /// Ticket `welcome-destructive-buttons-are-plain-text-taps`: los dos «Empezar desde cero» de Restaurar.
    @Test func empezarDesdeCero_esDestructivoYDe44Puntos() throws {
        let view = try source("Yala/App/Views/Onboarding/WelcomeRestoreView.swift")
        #expect(view.contains("Button(role: .destructive, action: action)"))
        #expect(view.contains(".frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)"))
        #expect(!view.contains("Button(action: secondaryAction)"), "La secundaria vuelve a ser texto pelado.")
        #expect(view.contains("startFreshButton(L10n.Welcome.Restore.startFresh)"))
        #expect(view.contains("startFreshButton(secondaryTitle, action: secondaryAction)"))
        // El peso sigue por debajo del principal: el mismo gris del sistema, sin relleno.
        let helper = try #require(view.range(of: "private func startFreshButton"))
        let cuerpo = view[helper.lowerBound...]
        #expect(cuerpo.contains("Color(uiColor: .secondaryLabel)"))
    }

    /// Ticket `welcome-fresh-start-failed-copy-says-data-is-still-here-after-partial-wipe`.
    @Test func trasBorrarLoPersonal_elAvisoNoDiceQueTusDatosSiguenAqui() {
        #expect(FreshStartWipeFailureCopy.message(personalAlreadyWiped: false) == L10n.Welcome.FreshStart.failedMessage)
        #expect(FreshStartWipeFailureCopy.message(personalAlreadyWiped: true)
                == L10n.Welcome.PrivateICloud.wipeDeviceFailedBody)
    }

    @Test func laMarcaSeEnciendeEntreLosDosBorrados() throws {
        let mod = try source("Yala/App/Views/Shared/ShellDataAlertsModifier.swift")
        // Partido a propósito: entero, `SharedStateIsolationTests` tomaría este fichero por uno que ejecuta el borrado.
        let personal = try #require(mod.range(of: "try DataWipeService.wipeAll" + "UserData("))
        let marca = try #require(mod.range(of: "personalWiped = true"))
        let grupos = try #require(mod.range(of: "try DataWipeService.wipeLocalGroupsDomain(in: modelContext)"))
        #expect(personal.lowerBound < marca.lowerBound && marca.lowerBound < grupos.lowerBound)
        #expect(mod.contains("freshStartFailedAfterPersonalWipe = personalWiped"))
        #expect(mod.contains("FreshStartWipeFailureCopy.message(personalAlreadyWiped: freshStartFailedAfterPersonalWipe)"))
    }
}
