//
//  Bienvenida23BaseTests.swift
//  YalaTests
//
//  Lote 01 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): pestañas por defecto y «días después» (Y23-15), el
//  mazo de Primeros pasos (Y23-05) y los permisos dentro del tutorial (Y23-17).
//

import Foundation
import Testing
import UserNotifications

@testable import Yala

// MARK: - Y23-15 · pestañas por defecto

@MainActor
@Suite("Bienvenida 2.3 · pestañas por defecto (Y23-15)")
struct TabBarDefaults23Tests {

    private func isolatedDefaults() throws -> UserDefaults {
        try #require(testDefaults(suiteName: "TabBarDefaults23Tests.\(UUID().uuidString)"))
    }

    @Test func freshInstall_seesPanelGroupsRecords() throws {
        let defaults = try isolatedDefaults()
        #expect(TabBarDefaultsMigration.runIfNeeded(defaults: defaults) == .freshInstall)
        #expect(defaults.string(forKey: TabBarConfiguration.storageKey) == nil, "lee el valor por defecto, no lo fija")
        #expect(TabBarConfiguration.default.activeTabs == [.panel, .groups, .records])
        #expect(TabBarDefaultsMigration.isFreshInstall(defaults: defaults))
    }

    /// Quien ya usaba Yala sin tocar la barra la sigue viendo igual: la de antes queda escrita.
    @Test func existingUser_withoutStoredBar_keepsTheOldOne() throws {
        let defaults = try isolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        #expect(TabBarDefaultsMigration.runIfNeeded(defaults: defaults) == .pinnedLegacy)
        let stored = try #require(defaults.string(forKey: TabBarConfiguration.storageKey))
        #expect(TabBarConfiguration.fromJSON(stored).activeTabs == [.panel, .statistics, .planning])
        #expect(!TabBarDefaultsMigration.isFreshInstall(defaults: defaults))
    }

    /// Quien configuró sus pestañas no se toca.
    @Test func configuredBar_isNeverTouched() throws {
        let defaults = try isolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        let mine = TabBarConfiguration(activeTabs: [.panel, .reports]).toJSON()
        defaults.set(mine, forKey: TabBarConfiguration.storageKey)
        #expect(TabBarDefaultsMigration.runIfNeeded(defaults: defaults) == .keptStored)
        #expect(defaults.string(forKey: TabBarConfiguration.storageKey) == mine)
    }

    /// Una sola vez: tras terminar el alta, el segundo arranque de una instalación nueva no le escribe la de antes.
    @Test func runsOnce_aNewInstallStaysNewAfterOnboarding() throws {
        let defaults = try isolatedDefaults()
        #expect(TabBarDefaultsMigration.runIfNeeded(defaults: defaults) == .freshInstall)
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        #expect(TabBarDefaultsMigration.runIfNeeded(defaults: defaults) == .alreadyDecided)
        #expect(defaults.string(forKey: TabBarConfiguration.storageKey) == nil)
        #expect(TabBarConfiguration.loadFromJSONOrDefault(nil).activeTabs == [.panel, .groups, .records])
    }
}

/// La migración corre en el arranque, antes de que ninguna vista lea la barra, y solo en el almacén real.
@Suite("Bienvenida 2.3 · cableado de la migración de pestañas (source-scan)")
struct TabBarDefaults23WiringTests {
    @Test func appPreferences_runsTheMigrationOnTheRealStore() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let code = try String(
            contentsOf: root.appendingPathComponent("Yala/App/Services/AppPreferences.swift"), encoding: .utf8)
        #expect(code.contains("if publishesToSync { TabBarDefaultsMigration.runIfNeeded(defaults: defaults) }"))
        let boot = try String(contentsOf: root.appendingPathComponent("Yala/App/AppBootstrapper.swift"), encoding: .utf8)
        #expect(boot.contains("TabBarDefaultsMigration.applyForUITest(freshInstall: UITestHooks.freshInstall)"))
    }
}

private extension TabBarConfiguration {
    static func loadFromJSONOrDefault(_ json: String?) -> TabBarConfiguration {
        fromJSON(json ?? TabBarConfiguration.default.toJSON())
    }
}

// MARK: - Y23-15 · «días después» y guías

@MainActor
@Suite("Bienvenida 2.3 · guías «dónde vive cada cosa» (Y23-15)", .serialized)
struct PlaceGuide23Tests {

    private let due = LaterChartsGuideLogic.Inputs(
        isFreshInstall: true, alreadyShown: false, statisticsInBar: false, hasMoreTab: true,
        guideOnScreen: false, stepSixResolved: false, silencedForUITest: false)

    @Test func later_isDue_onlyWithAllItsConditions() {
        #expect(LaterChartsGuideLogic.mayCheck(due))
        var c = due; c.isFreshInstall = false
        #expect(!LaterChartsGuideLogic.mayCheck(c), "a quien ya usaba Yala no se le movieron las gráficas")
        c = due; c.alreadyShown = true
        #expect(!LaterChartsGuideLogic.mayCheck(c), "una sola vez")
        c = due; c.statisticsInBar = true
        #expect(!LaterChartsGuideLogic.mayCheck(c), "si Estadísticas está en la barra, no viven en Más")
        c = due; c.hasMoreTab = false
        #expect(!LaterChartsGuideLogic.mayCheck(c))
        c = due; c.guideOnScreen = true
        #expect(!LaterChartsGuideLogic.mayCheck(c))
        c = due; c.stepSixResolved = true
        #expect(!LaterChartsGuideLogic.mayCheck(c), "el paso 6 ya la dio")
    }

    /// Registros en 2 o más días distintos: el mismo día dos veces no cuenta.
    @Test func later_countsCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 8)))
        let night = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 23, minute: 59)))
        let nextDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 0)))
        #expect(LaterChartsGuideLogic.distinctDays(in: [morning, night], calendar: calendar) == 1)
        #expect(LaterChartsGuideLogic.distinctDays(in: [morning, nextDay], calendar: calendar) == 2)
        #expect(LaterChartsGuideLogic.minimumDistinctDays == 2)
    }

    /// «Días después»: Configurar Panel → la pestaña Más → Más con foco en Estadísticas; termina con «Entendido».
    @Test func chartsLater_walksItsThreeMoments_andFinishesOnce() {
        let center = PlaceGuideCenter()
        var finished = 0
        #expect(center.start(.chartsLater) { finished += 1 })
        #expect(center.stage?.target == .panelConfigure)
        #expect(center.stage?.title == L10n.PlaceGuide.configureTitle)
        center.advance()
        #expect(center.stage?.target == .moreTab)
        #expect(center.stage?.advance == .tapTab)
        center.tabDidChange(to: .more)
        #expect(center.stage?.target == .moreItems(["insights", "trends", "categories"]))
        center.advance()
        #expect(!center.isActive)
        #expect(finished == 1)
    }

    /// «Omitir» la cierra sin darla por terminada; irse a otra pestaña también.
    @Test func skipping_orLeaving_doesNotFinish() {
        let center = PlaceGuideCenter()
        var finished = 0
        center.start(.chartsStep) { finished += 1 }
        center.skip()
        #expect(!center.isActive)
        center.start(.chartsStep) { finished += 1 }
        center.tabDidChange(to: .records)
        #expect(!center.isActive)
        #expect(finished == 0)
    }

    @Test func oneGuideAtATime() {
        let center = PlaceGuideCenter()
        #expect(center.start(.budgets))
        #expect(!center.start(.groups))
        #expect(center.stage?.title == L10n.PlaceGuide.budgetsTabTitle)
    }

    /// Las que quedan listas para los pasos 3, 4 y 5: dos toques a Más, o la pestaña Grupos.
    @Test func stepGuides_pointWhereEachThingLives() {
        #expect(PlaceGuide.budgets.stages.map(\.target) == [.moreTab, .moreItems(["budgets"])])
        #expect(PlaceGuide.scheduledPayments.stages.map(\.target) == [.moreTab, .moreItems(["scheduledPayments"])])
        #expect(PlaceGuide.groups.stages.map(\.target) == [.groupsTab])
        let center = PlaceGuideCenter()
        center.start(.groups)
        center.tabDidChange(to: .groups)
        #expect(!center.isActive, "tocar Grupos la cumple")
    }

    /// Cada texto existe en el catálogo (sin la clave cruda).
    @Test func everyStage_hasItsCopy() {
        for guide in PlaceGuide.allCases {
            for stage in guide.stages {
                #expect(!stage.title.hasPrefix("placeGuide."), "\(guide) sin título")
                #expect(!stage.message.hasPrefix("placeGuide."), "\(guide) sin texto")
            }
        }
    }
}

// MARK: - Y23-05 · el mazo

@Suite("Bienvenida 2.3 · mazo de Primeros pasos (Y23-05)")
struct SetupDeck23Tests {

    private let order = SetupStepID.deck

    @Test func deck_startsAtOne_withTheNextTwoPeeking() throws {
        let deck = try #require(SetupDeckLogic.deck(order: order, isResolved: { _ in false }))
        #expect(deck.current == .firstAccount)
        #expect(deck.position == 1)
        #expect(deck.total == 7)
        #expect(deck.upcoming == [.firstExpense, .firstBudget])
    }

    /// Avanza al completar u omitir; lo que asoma detrás son los siguientes que FALTAN.
    @Test func deck_advances_andSkipsResolvedOnesBehind() throws {
        let resolved: Set<SetupStepID> = [.firstAccount, .firstExpense, .groups]
        let deck = try #require(SetupDeckLogic.deck(order: order, isResolved: { resolved.contains($0) }))
        #expect(deck.current == .firstBudget)
        #expect(deck.position == 3)
        #expect(deck.upcoming == [.scheduledPayment, .whereMoneyGoes])
    }

    @Test func deck_lastStep_hasNothingBehind_andDisappearsAfterIt() throws {
        let allButLast = Set(order.dropLast())
        let last = try #require(SetupDeckLogic.deck(order: order, isResolved: { allButLast.contains($0) }))
        #expect(last.current == .homeScreen)
        #expect(last.position == 7)
        #expect(last.upcoming.isEmpty)
        #expect(SetupDeckLogic.deck(order: order, isResolved: { _ in true }) == nil)
    }

    @Test func deckCopy_existsForEveryStep() {
        for step in SetupStepID.deck {
            #expect(!step.localizedTitle.hasPrefix("setup.deck."), "\(step) sin título")
            #expect(!step.localizedSubtitle.hasPrefix("setup.deck."), "\(step) sin línea")
        }
        #expect(L10n.SetupChecklist.Deck.counter(2, 7) != "setup.deck.counter")
    }
}

// MARK: - Y23-17 · permisos dentro del tutorial

@Suite("Bienvenida 2.3 · permisos dentro del tutorial (Y23-17)")
struct TutorialPermissions23Tests {

    /// Voz: primero el aviso de IA (una vez) y luego el del micrófono. Foto: solo el de IA; la cámara la pide iOS al
    /// elegir «Cámara», y la fototeca no se pide nunca.
    @Test func voiceAndPhoto_askInOrder_onlyWhatIsMissing() {
        #expect(TutorialPermissionLogic.asks(for: .voice, aiConsentAccepted: false, microphoneUndetermined: true)
            == [.aiNotice, .microphone])
        #expect(TutorialPermissionLogic.asks(for: .voice, aiConsentAccepted: true, microphoneUndetermined: true)
            == [.microphone])
        #expect(TutorialPermissionLogic.asks(for: .voice, aiConsentAccepted: true, microphoneUndetermined: false).isEmpty)
        #expect(TutorialPermissionLogic.asks(for: .photo, aiConsentAccepted: false, microphoneUndetermined: true)
            == [.aiNotice])
    }

    /// «Sí, recuérdame»: el aviso de iOS solo si nunca preguntó; si ya respondió, nada se repite.
    @Test func remindMe_asksTheSystemOnlyOnce() {
        #expect(TutorialPermissionLogic.afterYesRemindMe(status: .notDetermined) == .systemPrompt)
        #expect(TutorialPermissionLogic.afterYesRemindMe(status: .authorized) == .nothing)
        #expect(TutorialPermissionLogic.afterYesRemindMe(status: .denied) == .nothing)
    }

    /// Paso 4: sin aviso elegido, nada; nunca preguntó → la hoja de la app y luego iOS; se negó → a Configuración.
    @Test func scheduledPayment_retry() {
        #expect(TutorialPermissionLogic.scheduledPaymentReminder(wantsReminder: false, status: .notDetermined) == .nothing)
        #expect(TutorialPermissionLogic.scheduledPaymentReminder(wantsReminder: true, status: .notDetermined)
            == .appSheetThenSystem)
        #expect(TutorialPermissionLogic.scheduledPaymentReminder(wantsReminder: true, status: .denied) == .settingsAlert)
        #expect(TutorialPermissionLogic.scheduledPaymentReminder(wantsReminder: true, status: .authorized) == .nothing)
    }

    /// El respaldo del tercer registro no pide nada mientras se aprende a registrar (los registros de prueba).
    @Test func recordsFallback_isSilentWhileLearningToRecord() {
        #expect(!TutorialPermissionLogic.recordsFallbackAllowed(learningToRecord: true))
        #expect(TutorialPermissionLogic.recordsFallbackAllowed(learningToRecord: false))
    }

    /// Fotos no se pide: ningún `requestAuthorization` de la fototeca en la app.
    @Test func photoLibrary_isNeverRequested() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala")
        let files = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        for case let url as URL in files where url.pathExtension == "swift" {
            let code = try String(contentsOf: url, encoding: .utf8)
            #expect(!code.contains("PHPhotoLibrary.requestAuthorization"), "\(url.lastPathComponent) pide la fototeca")
        }
    }
}
