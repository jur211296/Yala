//
//  AsistenteGrupoTests.swift
//  YalaTests
//
//  «Nuevo grupo» por pasos (encargo del 17-nov): las reglas del asistente (qué preguntas hay, cuándo se sigue, las ideas
//  de nombre, cuándo preguntar antes de descartar), el estado que vive en la pestaña, lo que pasa al formulario con «Usar
//  formulario», el cableado de la pestaña y del formulario, y los textos en los 16 idiomas.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Reglas

@Suite("Asistente de grupo · las reglas")
@MainActor
struct AsistenteGrupoLogicaTests {
    typealias Logica = AsistenteGrupoLogica

    @Test func lasPreguntas_sonLasDelFormulario_yTerminanEnElResumen() {
        #expect(Logica.pasos == [.nombre, .icono, .reparto, .deudas, .moneda, .resumen])
    }

    @Test func respuestasDeUnGrupoNuevo_sonLasDelFormularioRecienAbierto() {
        let r = Logica.Respuestas()
        #expect(r.icono == "person.2.fill")
        #expect(r.color == "#8B5CF6")
        #expect(r.reparto == .equal)
        #expect(r.menosPagos == GroupFormDefaults.simplifyDebtsForNewGroup)
        #expect(!r.unaSolaMoneda)
    }

    @Test func soloElNombreEsObligatorio_yNoValenSoloEspacios() {
        var r = Logica.Respuestas()
        #expect(!Logica.puedeSeguir(en: .nombre, r))
        #expect(!Logica.puedeSeguir(en: .resumen, r))
        r.nombre = "   "
        #expect(!Logica.puedeSeguir(en: .nombre, r))
        r.nombre = " Viaje a Cusco "
        #expect(Logica.puedeSeguir(en: .nombre, r))
        #expect(Logica.puedeSeguir(en: .resumen, r))
        for paso in [Logica.Paso.icono, .reparto, .deudas, .moneda] {
            #expect(Logica.puedeSeguir(en: paso, Logica.Respuestas()), "\(paso) no deja seguir con lo sugerido.")
        }
    }

    @Test func unNombreEscrito_cuentaComoRespuesta_aunqueNoSeHayaTocadoSiguiente() {
        var r = Logica.Respuestas()
        #expect(!Logica.tieneAlgo(respondidas: false, r))
        #expect(Logica.tieneAlgo(respondidas: true, r))
        r.nombre = "Casa"
        #expect(Logica.tieneAlgo(respondidas: false, r))
    }

    @Test func unaIdea_poneNombreEIcono_peroNoPisaUnIconoElegidoAMano() {
        var r = Logica.Respuestas()
        Logica.aplicar(.viaje, nombreIdea: "Viaje", a: &r, iconoElegidoAMano: false)
        #expect(r.nombre == "Viaje")
        #expect(r.icono == "airplane")
        #expect(r.color == Logica.Idea.viaje.color)

        r.icono = "car.fill"
        r.color = "#22C55E"
        Logica.aplicar(.casa, nombreIdea: "Casa", a: &r, iconoElegidoAMano: true)
        #expect(r.nombre == "Casa")
        #expect(r.icono == "car.fill", "Una idea pisó el icono elegido a mano.")
    }

    @Test func losIconos_empiezanPorElDeSiempre_ySinRepetidos() {
        #expect(Logica.iconos.first == Logica.Icono(nombre: "person.2.fill", color: "#8B5CF6"))
        #expect(Set(Logica.iconos.map(\.nombre)).count == Logica.iconos.count)
        for idea in Logica.Idea.allCases {
            #expect(Logica.iconos.contains(Logica.Icono(nombre: idea.icono, color: idea.color)),
                    "El icono de «\(idea)» no está en la rejilla: elegir la idea dejaría la rejilla sin marca.")
        }
    }

    @Test func alFormulario_pasaTodoLoRespondido() {
        var r = Logica.Respuestas(moneda: .usd)
        r.nombre = "  Depa  "
        r.icono = "house.fill"
        r.color = "#F59E0B"
        r.reparto = .shares
        r.menosPagos = false
        r.unaSolaMoneda = true
        let prefill = Logica.alFormulario(r, importacion: nil)
        #expect(prefill == GroupFormPrefill(name: "Depa", iconName: "house.fill", colorHex: "#F59E0B",
                                            splitType: .shares, simplifyDebts: false,
                                            showDebtsInSingleCurrency: true, currency: .usd, importSelection: nil))
        #expect(prefill.changesMoreOptions, "Con opciones cambiadas, el formulario tiene que abrir «Más opciones».")
    }

    @Test func conLasOpcionesDeSiempre_masOpcionesSigueAPlegada() {
        var r = Logica.Respuestas()
        r.nombre = "Casa"
        #expect(!Logica.alFormulario(r, importacion: nil).changesMoreOptions)
        r.menosPagos.toggle()
        #expect(Logica.alFormulario(r, importacion: nil).changesMoreOptions)
    }
}

// MARK: - Estado

@Suite("Asistente de grupo · el estado y «Usar formulario»")
@MainActor
struct AsistenteGrupoEstadoTests {

    @Test func empezar_dejaTodoComoNuevo_conLaMonedaPreferida() {
        let estado = AsistenteGrupoEstado()
        estado.respuestas.nombre = "Viaje"
        estado.elegir(icono: "car.fill", color: "#22C55E")
        estado.navegador.avanzar(en: estado.pasos)
        estado.usarFormulario()
        estado.empezar(moneda: .eur)
        #expect(estado.modo == .asistente)
        #expect(estado.navegador.actual == .nombre)
        #expect(!estado.navegador.tieneRespuestas)
        #expect(estado.respuestas == AsistenteGrupoLogica.Respuestas(moneda: .eur))
        #expect(!estado.iconoElegidoAMano)
        #expect(estado.importacion == nil)
        #expect(!estado.tieneAlgo)
    }

    @Test func usarFormulario_sinNada_abreElFormularioVacio() {
        let estado = AsistenteGrupoEstado()
        estado.empezar(moneda: .pen)
        estado.usarFormulario()
        #expect(estado.modo == .formulario(nil))
    }

    @Test func usarFormulario_conElNombreEscrito_loLleva_aunqueNoSeTocaraSiguiente() {
        let estado = AsistenteGrupoEstado()
        estado.empezar(moneda: .pen)
        estado.respuestas.nombre = "Viaje a Cusco"
        estado.usarFormulario()
        guard case .formulario(let prefill?) = estado.modo else {
            Issue.record("«Usar formulario» no llevó el nombre: \(estado.modo)")
            return
        }
        #expect(prefill.name == "Viaje a Cusco")
        #expect(prefill.currency == .pen)
    }

    @Test func usarFormulario_aMitadDelCamino_llevaLoRespondido() {
        let estado = AsistenteGrupoEstado()
        estado.empezar(moneda: .pen)
        estado.elegir(.pareja, nombre: "Pareja")
        estado.navegador.avanzar(en: estado.pasos)     // → icono
        estado.navegador.avanzar(en: estado.pasos)     // → reparto
        estado.respuestas.reparto = .percentage         // elegido, sin tocar «Siguiente»
        estado.usarFormulario()
        guard case .formulario(let prefill?) = estado.modo else {
            Issue.record("«Usar formulario» no llevó lo respondido: \(estado.modo)")
            return
        }
        #expect(prefill.name == "Pareja")
        #expect(prefill.iconName == "heart.fill")
        #expect(prefill.splitType == .percentage)
    }

    @Test func elegirUnIcono_hacequeLasIdeasYaNoLoCambien() {
        let estado = AsistenteGrupoEstado()
        estado.empezar(moneda: .pen)
        estado.elegir(.viaje, nombre: "Viaje")
        #expect(estado.respuestas.icono == "airplane")
        estado.elegir(icono: "gift.fill", color: "#D946EF")
        estado.elegir(.casa, nombre: "Casa")
        #expect(estado.respuestas.icono == "gift.fill")
        #expect(estado.respuestas.nombre == "Casa")
    }

    @Test func elResumen_vuelveTrasCambiarUnaRespuesta() {
        let estado = AsistenteGrupoEstado()
        estado.empezar(moneda: .pen)
        estado.respuestas.nombre = "Casa"
        for _ in 0..<5 { estado.navegador.avanzar(en: estado.pasos) }
        #expect(estado.navegador.actual == .resumen)
        estado.navegador.cambiar(.reparto, desde: .resumen)
        #expect(estado.navegador.actual == .reparto)
        estado.navegador.avanzar(en: estado.pasos)
        #expect(estado.navegador.actual == .resumen, "Tras cambiar una respuesta, «Siguiente» no volvió al resumen.")
    }
}

// MARK: - Cableado

@Suite("Asistente de grupo · el cableado de la pestaña y del formulario")
struct AsistenteGrupoCableadoTests {

    private static func code(_ path: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    /// Crear abre el asistente, que se vuelve a empezar en la misma puerta que abre la hoja (después del refresh y la
    /// decisión del canal), y el formulario sigue siendo la otra cara de la misma hoja.
    @Test func laPestana_abreElAsistente_trasLaPuerta_yConElFormularioDentro() throws {
        let tab = try Self.code("Yala/App/Views/Groups/GroupsContainerView.swift")
        let gate = try #require(tab.components(separatedBy: "private func requestCreateGroup() async {").dropFirst().first)
        let backend = try #require(gate.components(separatedBy: "case .backend:").dropFirst().first?
            .components(separatedBy: "case .channelOff:").first)
        let empezar = try #require(backend.range(of: "newGroupWizard.empezar("))
        let abrir = try #require(backend.range(of: "viewModel.showCreateGroup = true"))
        #expect(empezar.lowerBound < abrir.lowerBound, "La hoja se abre antes de vaciar lo respondido la vez anterior.")

        let hoja = try #require(tab.components(separatedBy: ".sheet(isPresented: $viewModel.showCreateGroup").dropFirst().first?
            .components(separatedBy: ".sheet(item: $groupReadyToInvite").first)
        #expect(hoja.contains("NuevoGrupoHoja("))
        #expect(hoja.contains("alCrear: { receiveCreatedGroup($0) }"), "El grupo creado en el asistente no llega a la hoja de invitar.")
        #expect(hoja.contains("GroupFormView(group: nil, onCreated: { receiveCreatedGroup($0) })"))
    }

    /// El asistente avisa del grupo ANTES de cerrar la hoja (su `onDismiss` abre la de invitar) y crea por el canal
    /// del formulario, con el attest de producción.
    @Test func elAsistente_creaPorElCanalDelFormulario_yAvisaAntesDeCerrar() throws {
        let vista = try Self.code("Yala/App/Views/Groups/AsistenteGrupo/AsistenteGrupoView.swift")
        let backend = try #require(vista.components(separatedBy: "case .backend:").dropFirst().first)
        #expect(backend.contains("GroupBackendMembershipService("))
        #expect(backend.contains("GroupsMembershipClient(attestProvider: AttestSessionProvider.live)"))
        #expect(backend.contains("SessionState.shared.incrementDataVersion()"))
        #expect(backend.contains("NudgeService.shared.recordGroupJoinIfNeeded()"))
        #expect(backend.contains("estado.importacion?.start(in: creado)"))
        let avisa = try #require(backend.range(of: "alCrear(creado)"))
        let cierra = try #require(backend.range(of: "alCerrar()"))
        #expect(avisa.lowerBound < cierra.lowerBound, "La hoja se cierra antes de apuntar el grupo para invitar.")
        #expect(vista.contains("GroupActionErrorLogic.message(for: error)"), "El error al crear sale crudo.")
    }

    /// El formulario abierto desde el asistente lee lo respondido del entorno y, con ello, pregunta antes de descartar
    /// (la X y el gesto de bajar).
    @Test func elFormulario_conLoRespondido_preguntaAntesDeDescartar() throws {
        let form = try Self.code("Yala/App/Views/Groups/GroupFormView.swift")
        #expect(form.contains("@Environment(\\.groupFormPrefill) private var prefill"))
        #expect(form.contains("if asksBeforeDiscardingPrefill { showDiscardPrefill = true } else { close() }"))
        #expect(form.contains(".asksBeforeDiscardingGroupForm("))
        #expect(form.contains("hasUnsavedInput: asksBeforeDiscardingPrefill"))
        #expect(form.contains("group == nil && prefill != nil && !isSaving"),
                "Editar un grupo o el formulario sin asistente no deben preguntar.")
    }
}

// MARK: - Textos

@Suite("Asistente de grupo · los textos en los 16 idiomas")
struct AsistenteGrupoStringsTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/AsistenteGrupo.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    private static func placeholders(_ text: String) -> [String] {
        let regex = /%(\d+\$)?[@d]/
        return text.matches(of: regex).map { String($0.output.0) }.sorted()
    }

    @Test(arguments: locales)
    func cadaIdioma_tieneCadaClave_conTexto_yLosMismosHuecos(_ locale: String) throws {
        let referencia = try Self.table("es")
        let textos = try Self.table(locale)
        #expect(Set(textos.keys) == Set(referencia.keys), "\(locale): claves distintas de es.")
        for (clave, valor) in textos {
            #expect(!valor.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(clave) vacía.")
            #expect(Self.placeholders(valor) == Self.placeholders(referencia[clave] ?? ""),
                    "\(locale): \(clave) no tiene los mismos huecos que en español.")
        }
    }

    /// Cada clave que pide el código existe en la tabla: las de las ideas y del reparto se construyen con el `rawValue`.
    @Test func lasClavesQueSeConstruyen_existen() throws {
        let es = try Self.table("es")
        for idea in AsistenteGrupoLogica.Idea.allCases {
            #expect(es["asistenteGrupo.idea.\(idea.rawValue)"] != nil, "Falta la idea «\(idea)».")
        }
        for tipo in SplitType.allCases {
            #expect(es["asistenteGrupo.split.\(tipo.rawValue).hint"] != nil, "Falta la pista de «\(tipo)».")
        }
    }

    @Test func alias_copianSuReferencia() throws {
        #expect(try Self.table("es-419") == Self.table("es"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    @Test func variantes_hablanASuManera() throws {
        #expect(try Self.table("es-AR")["asistenteGrupo.summary.detail"]?.contains("Tocá") == true)
        #expect(try Self.table("es-ES")["asistenteGrupo.split.question"]?.contains("soléis") == true)
        #expect(try Self.table("pt-PT")["asistenteGrupo.summary.detail"]?.contains("alterar") == true)
    }

    /// El botón de abajo dice lo que crea; nunca es solo «Crear» salvo a tamaños de accesibilidad.
    @Test func elEspanol_diceLoQueSePidio() throws {
        let es = try Self.table("es")
        #expect(es["asistenteGrupo.create"] == "Crear grupo")
        #expect(es["asistenteGrupo.name.question"] == "¿Cómo se llama el grupo?")
    }

    @Test(arguments: locales)
    @MainActor
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.AsistenteGrupo.string("asistenteGrupo.create", resolution: resolution)
        #expect(texto == (try Self.table(locale)["asistenteGrupo.create"]))
    }

    @Test @MainActor func unaClaveQueFalta_vuelveCruda() {
        #expect(L10n.AsistenteGrupo.string("asistenteGrupo.no.existe") == "asistenteGrupo.no.existe")
    }
}
