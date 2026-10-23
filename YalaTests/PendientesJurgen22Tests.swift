//
//  PendientesJurgen22Tests.swift
//  YalaTests
//
//  Las cinco decisiones de Jürgen del 2026-10-23 (sesión «Pendientes de Jürgen 2.2»):
//  · fptw  · los avisos de grupo también en el formulario de gasto de L13-8 y, una vez, en la lista de Grupos (B).
//  · D23   · «Seguridad y cuenta» se parte en «Seguridad y privacidad» y «Tu cuenta» (B).
//  · L16-14· Face ID en «Permisos de Yala»: fila sin estado con «Ver cómo» a la guía (A).
//  · L16-5 · idioma híbrido: la fila sale siempre; iOS si ofrece «Idioma», si no el selector de Yala (B).
//  · L20-15· «Datos no disponibles» como hoja: la fija `UXAudit22Lote20NubeTests` junto a sus vecinos.
//
//  Las decisiones puras van por tabla; el cableado en vistas, por source-scan sin comentarios.
//

import Foundation
import Testing
@testable import Yala

private enum PJ22Repo {
    static func text(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }

    /// Sin líneas de comentario: documentar lo que el test prohíbe no puede ponerlo en rojo.
    static func code(_ relativePath: String) throws -> String {
        try text(relativePath).split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El tramo de `source` entre `start` y la primera aparición de `end` después de él.
    static func slice(_ source: String, from start: String, to end: String) throws -> String {
        let lower = try #require(source.range(of: start), "No está «\(start)».")
        let upper = try #require(source.range(of: end, range: lower.upperBound..<source.endIndex), "No está «\(end)».")
        return String(source[lower.lowerBound..<upper.lowerBound])
    }

    static func string(_ key: String, lang: String) throws -> String? {
        let source = try text("Yala/Resources/\(lang).lproj/Localizable.strings")
        for line in source.split(separator: "\n") where line.hasPrefix("\"\(key)\" = \"") {
            var value = line.dropFirst("\"\(key)\" = \"".count)
            guard value.hasSuffix("\";") else { continue }
            value = value.dropLast(2)
            return value.replacingOccurrences(of: "\\\"", with: "\"")
        }
        return nil
    }

    static let languages = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                            "pt", "pt-BR", "pt-PT", "zh-Hans"]
}

// MARK: - L16-5 · Idioma híbrido

@Suite("Pendientes 2.2 · L16-5 la fila de idioma lleva a iOS solo si iOS ofrece «Idioma»")
struct AppLanguageRowLogicTests {

    @Test("Sin idioma elegido en Yala: varios idiomas en el iPhone → iOS; uno solo → el selector de Yala")
    func routeFollowsWhatIOSOffers() {
        #expect(AppLanguageRowLogic.route(overrideLanguage: nil, preferredLanguages: ["es-PE", "en-US"]) == .iOSSettings)
        #expect(AppLanguageRowLogic.route(overrideLanguage: nil, preferredLanguages: ["es-PE"]) == .yalaPicker)
        #expect(AppLanguageRowLogic.route(overrideLanguage: nil, preferredLanguages: []) == .yalaPicker)
    }

    @Test("Con un idioma elegido en Yala manda el selector de Yala, aunque el iPhone tenga varios")
    func overrideKeepsTheYalaPicker() {
        // El de Yala pisa al de iOS (`LanguageManager.resolved`): cambiarlo en iOS no haría nada.
        #expect(AppLanguageRowLogic.route(overrideLanguage: "fr", preferredLanguages: ["qu-PE", "es-PE"]) == .yalaPicker)
        #expect(AppLanguageRowLogic.route(overrideLanguage: "fr", preferredLanguages: ["qu-PE"]) == .yalaPicker)
    }

    @Test("El idioma marcado: el elegido en Yala, o el del iPhone sin alias")
    func currentCode() {
        #expect(AppLanguageRowLogic.currentCode(overrideLanguage: "it", preferredLanguages: ["es-PE"], region: "PE") == "it")
        #expect(AppLanguageRowLogic.currentCode(overrideLanguage: nil, preferredLanguages: ["es-PE"], region: "PE") == "es-419")
        #expect(AppLanguageRowLogic.currentCode(overrideLanguage: nil, preferredLanguages: ["pt"], region: "BR") == "pt-BR")
        #expect(AppLanguageRowLogic.currentCode(overrideLanguage: nil, preferredLanguages: ["qu-PE"], region: nil) == "en")
    }

    @Test("La fila sale siempre y elige su camino; elegir otro idioma deja volver a Personalización")
    func personalizationWiring() throws {
        let view = try PJ22Repo.code("Yala/App/Views/Settings/PersonalizationSettingsView.swift")
        let section = try PJ22Repo.slice(view, from: "YalaSettingsSection(L10n.Settings.sectionInterface) {",
                                         to: "YalaSettingsSection {")
        #expect(section.contains("openAppLanguage()"))
        #expect(section.contains("L10n.PJ22.appLanguageInIOSFooter"))
        #expect(!view.contains("if LanguageManager.overrideLanguage != nil {"), "la fila volvió a depender del onboarding")
        let open = try PJ22Repo.slice(view, from: "private func openAppLanguage() {", to: "var body: some View")
        #expect(open.contains("case .iOSSettings:") && open.contains("UIApplication.openSettingsURLString"))
        #expect(open.contains("case .yalaPicker:") && open.contains("showingLanguagePicker = true"))

        let picker = try PJ22Repo.slice(view, from: ".sheet(isPresented: $showingLanguagePicker) {",
                                        to: "ScheduledPaymentNotificationService")
        // El orden importa: la vuelta se apunta ANTES de cambiar el idioma, que reconstruye la app en la misma vuelta.
        let mark = try #require(picker.range(of: "navigation.pendingSettingsReturn = .personalization"))
        let change = try #require(picker.range(of: "LanguageManager.overrideLanguage = code"))
        let same = try #require(picker.range(of: "guard code != currentLanguageCode else {"))
        #expect(same.lowerBound < mark.lowerBound && mark.lowerBound < change.lowerBound)
    }

    @Test("El Panel recién montado reabre Ajustes en el ajuste apuntado, y solo él")
    func panelReopensSettings() throws {
        let panel = try PJ22Repo.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(panel.contains(".modifier(PanelSettingsReturnOpening(isPresentingSettings: sheets.isPresentingSettings) {"))
        let opening = try PJ22Repo.slice(panel, from: "private struct PanelSettingsReturnOpening: ViewModifier {",
                                         to: "private struct PanelAccountAlertOpening")
        #expect(opening.contains(".onAppear { openIfFront() }"))
        #expect(!opening.contains("onChange(of: navigation.pendingSettingsReturn"),
                "el Panel de antes del cambio, con Ajustes encima, abriría una segunda hoja")
        #expect(opening.contains("navigation.pendingSettingsReturn = nil"))
        let sheets = try PJ22Repo.code("Yala/App/Views/Panel/PanelSheetsModifier.swift")
        #expect(sheets.contains("ProfileView(initialDestination: sheets.settingsInitialDestination)"))
        #expect(sheets.contains("sheets.settingsInitialDestination = nil"))
        // Ajustes abierto desde el banner de sincronización cuelga de `ContentView`, sobrevive a la reconstrucción y deja
        // a la persona donde estaba: el Panel no debe abrir otra hoja debajo.
        let content = try PJ22Repo.code("Yala/App/ContentView.swift")
        let receive = try PJ22Repo.slice(content, from: ".onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in",
                                         to: "languageVersion &+= 1")
        #expect(receive.contains("if showSyncSettingsSheet { navigation.pendingSettingsReturn = nil }"))
    }

    @Test("El pie del camino de iOS existe en los 16 idiomas")
    func footerInAllLanguages() throws {
        for lang in PJ22Repo.languages {
            let value = try #require(try PJ22Repo.string("pj22.language.inIOSFooter", lang: lang), "falta en \(lang)")
            #expect(!value.isEmpty)
        }
    }
}

// MARK: - L16-14 · Face ID en «Permisos de Yala»

@Suite("Pendientes 2.2 · L16-14 Face ID en Permisos: sin estado y con «Ver cómo» a la guía")
struct PermissionsFaceIDRowTests {

    @Test("La fila lleva a la guía y no enseña estado ni botón a Configuración")
    func rowGoesToTheGuide() throws {
        let view = try PJ22Repo.code("Yala/App/Views/Settings/PermissionsSettingsView.swift")
        let row = try PJ22Repo.slice(view, from: "private var faceIDRow: some View {", to: "private func state(of kind: Kind)")
        #expect(row.contains("NavigationLink(value: ProfileDestination.faceIDProtectionGuide) {"))
        #expect(row.contains("L10n.PJ22.permissionFaceIDSeeHow"))
        #expect(!row.contains("statusText") && !row.contains("openSettings"), "Face ID no tiene estado que leer")
        // Sale en la lista, después de los cuatro permisos con estado.
        let list = try PJ22Repo.slice(view, from: "YalaSettingsSection {", to: "} footer: {")
        let forEach = try #require(list.range(of: "ForEach(Kind.allCases)"))
        let face = try #require(list.range(of: "faceIDRow"))
        #expect(forEach.lowerBound < face.lowerBound)
    }

    @Test("El destino lo registran las dos pilas de Ajustes")
    func destinationIsRegistered() throws {
        let profile = try PJ22Repo.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.components(separatedBy: ".navigationDestination(for: ProfileDestination.self)").count - 1 == 2)
        #expect(profile.contains("case .faceIDProtectionGuide:"))
    }

    @Test("Sus tres textos existen en los 16 idiomas")
    func textsInAllLanguages() throws {
        for key in ["pj22.permissions.faceID", "pj22.permissions.faceIDDetail", "pj22.permissions.faceIDSeeHow"] {
            for lang in PJ22Repo.languages {
                #expect(try PJ22Repo.string(key, lang: lang) != nil, "falta \(key) en \(lang)")
            }
        }
    }
}

// MARK: - D23 · «Seguridad y privacidad» y «Tu cuenta»

@Suite("Pendientes 2.2 · D23 Ajustes parte «Seguridad y cuenta» en dos bloques y recoloca lo que no es seguridad")
struct SettingsSecuritySplitTests {

    private func profile() throws -> String { try PJ22Repo.code("Yala/App/Views/Profile/ProfileView.swift") }

    @Test("«Seguridad y privacidad» tiene Face ID, Permisos y Privacidad IA, y nada más de la lista vieja")
    func securityBlock() throws {
        let block = try PJ22Repo.slice(try profile(), from: "private var seguridadSection: some View {",
                                       to: "private var showsAccountSection: Bool {")
        for id in ["profile_security_faceid", "profile_permissions", "profile_ai_privacy"] {
            #expect(block.contains(id), "falta \(id)")
        }
        for gone in ["siriShortcuts", "profile_rate_app", "profile_recommend_app", "profile_yala_account", "signOutRow"] {
            #expect(!block.contains(gone), "\(gone) sigue bajo Seguridad")
        }
    }

    @Test("«Tu cuenta» es su propio bloque, con la cuenta de Yala y Cerrar sesión, y solo sale si tiene filas")
    func accountBlock() throws {
        let src = try profile()
        let block = try PJ22Repo.slice(src, from: "private var cuentaSection: some View {", to: "#if DEBUG")
        #expect(block.contains("SectionBox(title: L10n.Settings.accountSubsectionTitle) {"))
        let account = try #require(block.range(of: "profile_yala_account"))
        let signOut = try #require(block.range(of: "signOutRow"))
        #expect(account.lowerBound < signOut.lowerBound, "«Cerrar sesión» dejó de ir al final")
        #expect(src.contains("showsYalaAccountRow || !signOutRowRemovesDeviceData"))
        let order = try PJ22Repo.slice(src, from: "seguridadSection\n", to: "legalSection")
        #expect(order.contains("if showsAccountSection {") && order.contains("cuentaSection"))
        let cuenta = try #require(order.range(of: "cuentaSection"))
        let ayuda = try #require(order.range(of: "ayudaSection"))
        #expect(cuenta.lowerBound < ayuda.lowerBound)
    }

    @Test("Siri y Atajos va a Preferencias; Valorar y Recomendar cierran «¿Necesitas ayuda?»")
    func movedRows() throws {
        let src = try profile()
        let prefs = try PJ22Repo.slice(src, from: "private var preferenciasSection: some View {",
                                       to: "private var datosSection: some View {")
        #expect(prefs.contains("destination: .siriShortcuts"))
        let help = try PJ22Repo.slice(src, from: "private var ayudaSection: some View {",
                                      to: "private var legalSection: some View {")
        let contact = try #require(help.range(of: "profile_help_contact"))
        let rate = try #require(help.range(of: "profile_rate_app"))
        let recommend = try #require(help.range(of: "profile_recommend_app"))
        #expect(contact.lowerBound < rate.lowerBound && rate.lowerBound < recommend.lowerBound)
        #expect(src.components(separatedBy: "profile_rate_app").count - 1 == 1, "«Valorar Yala» está dos veces")
        #expect(src.components(separatedBy: "destination: .siriShortcuts").count - 1 == 1, "«Siri y Atajos» está dos veces")
    }

    @Test("El título del bloque ya no dice «cuenta» en ningún idioma")
    func securityTitle() throws {
        #expect(try PJ22Repo.string("settings.security", lang: "es-419") == "Seguridad y privacidad")
        #expect(try PJ22Repo.string("settings.security", lang: "en") == "Security & Privacy")
        for lang in PJ22Repo.languages {
            let value = try #require(try PJ22Repo.string("settings.security", lang: lang))
            let account = try #require(try PJ22Repo.string("settings.accountSubsectionTitle", lang: lang))
            #expect(value != account, "\(lang): el título de Seguridad repite el de «Tu cuenta»")
            for word in ["cuenta", "Account", "Konto", "compte", "account", "アカウント", "konto", "conta", "账户"] {
                #expect(!value.contains(word), "\(lang): «\(value)» sigue hablando de la cuenta")
            }
        }
    }
}

// MARK: - fptw · Los avisos de grupo por los otros caminos

@Suite("Pendientes 2.2 · fptw la tarjeta de avisos de grupo en el gasto de L13-8 y una vez en la lista")
struct GroupNotificationsOtherPathsTests {

    @Test("En la lista solo sale a quien nunca la vio; en las demás pantallas, siempre que falte algo")
    func showsCardTable() {
        typealias L = GroupNotificationsOptInLogic
        for state in [L.State.ask, .denied] {
            #expect(L.showsCard(initialState: state, onlyIfNeverSeen: true, hasSeenPrompt: false))
            #expect(!L.showsCard(initialState: state, onlyIfNeverSeen: true, hasSeenPrompt: true))
            #expect(L.showsCard(initialState: state, onlyIfNeverSeen: false, hasSeenPrompt: true))
            #expect(L.showsCard(initialState: state, onlyIfNeverSeen: false, hasSeenPrompt: false))
        }
        for onlyIfNeverSeen in [true, false] {
            for seen in [true, false] {
                #expect(!L.showsCard(initialState: .enabled, onlyIfNeverSeen: onlyIfNeverSeen, hasSeenPrompt: seen),
                        "a quien ya los tiene no se le pregunta nada")
            }
        }
    }

    @Test("La lista no la monta mientras otra pantalla está a punto de preguntar")
    func listMountsCard() {
        typealias L = GroupNotificationsOptInLogic
        #expect(L.listMountsCard(isWelcomeGroupFormOpen: false, inviteSheetPending: false))
        #expect(!L.listMountsCard(isWelcomeGroupFormOpen: true, inviteSheetPending: false))
        #expect(!L.listMountsCard(isWelcomeGroupFormOpen: false, inviteSheetPending: true))
    }

    @Test("Vista en cualquier pantalla cuenta: la tarjeta se marca al salir")
    func cardMarksItselfSeen() throws {
        let card = try PJ22Repo.code("Yala/App/Views/Groups/GroupNotificationsOptInCard.swift")
        let measure = try PJ22Repo.slice(card, from: "private func measure(initial: Bool) async {",
                                         to: "private func activateGroupsItem()")
        #expect(measure.contains("onlyIfNeverSeen: onlyIfNeverSeen,"))
        #expect(measure.contains("hasSeenPrompt: appPreferences.hasSeenGroupsNotificationPrompt)"))
        #expect(measure.contains("if showsCard { appPreferences.hasSeenGroupsNotificationPrompt = true }"))
    }

    @Test("La lista de Grupos y el formulario de gasto de L13-8 montan la tarjeta")
    func wiring() throws {
        let list = try PJ22Repo.code("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(list.contains("GroupNotificationsOptInCard(onlyIfNeverSeen: true)"))
        #expect(list.contains("inviteSheetPending: groupAwaitingInviteSheet != nil || groupReadyToInvite != nil) {"))
        let form = try PJ22Repo.code("Yala/App/Views/Groups/GroupExpenseFormView.swift")
        let notice = try PJ22Repo.slice(form, from: "if let notice {", to: "centralContent")
        #expect(notice.contains("GroupNotificationsOptInCard()"),
                "la tarjeta del formulario va con el aviso de L13-8: solo tras crear el grupo para este gasto")
    }
}
