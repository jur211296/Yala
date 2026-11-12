//
//  ExportRecordsLogicTests.swift
//  YalaTests
//
//  Lote decidido 2.2 · 03 (Exportar y Vaciar): la lógica pura de «Llévate tus registros» (L20-1/L20-2), el aviso tras
//  compartir (L20-3/L19-16), el nombre del archivo (L20-4), la fila y la frase de Vaciar (L20-5) y la confirmación de
//  «Salir de todos mis grupos» (L19-12).
//

import Foundation
import Testing

@testable import Yala

struct ExportRecordsLogicTests {

    typealias Logic = ExportRecordsLogic

    // MARK: - L20-1 · Las fichas del período

    @Test func periodChips_areTheFourOfTheChosenVariant_inOrder() {
        #expect(Logic.PeriodChoice.allCases == [.all, .thisYear, .thisMonth, .dates])
        #expect(Logic.PeriodChoice.all.detailPeriod == .allTime)
        #expect(Logic.PeriodChoice.thisYear.detailPeriod == .thisYear)
        #expect(Logic.PeriodChoice.thisMonth.detailPeriod == .thisMonth)
        #expect(Logic.PeriodChoice.dates.detailPeriod == .custom)
    }

    // MARK: - L20-2 · Los filtros activos

    private func active(
        accounts: (Int, Int) = (3, 3), subs: (Int, Int) = (0, 10), tags: (Int, Int) = (0, 2),
        needs: (Int, Int) = (4, 4), currencies: [String] = [], availableCurrencies: Int = 2,
        amount: Bool = false, note: String = "", exclude: Bool = false
    ) -> [Logic.ActiveFilter] {
        Logic.activeFilters(
            markedAccounts: accounts.0, offeredAccounts: accounts.1,
            selectedSubcategories: subs.0, visibleSubcategories: subs.1,
            selectedTags: tags.0, allTags: tags.1,
            selectedNeeds: needs.0, allNeeds: needs.1,
            selectedCurrencies: currencies, availableCurrencies: availableCurrencies,
            amountIsActive: amount, note: note, isExcludeMode: exclude)
    }

    @Test func everythingChosen_noActiveFilters() {
        #expect(active().isEmpty)
        // Todo elegido explícitamente (las subcategorías y etiquetas marcadas todas) tampoco recorta.
        #expect(active(subs: (10, 10), tags: (2, 2), currencies: ["PEN", "USD"]).isEmpty)
    }

    /// El caso del informe: una nota olvidada y el modo «Ocultar» tienen que verse.
    @Test func noteAndHiding_areShown() {
        // En «Ocultar» nada marcado no recorta (card k4iz): solo la nota y el modo.
        #expect(active(accounts: (0, 3), needs: (0, 4), note: "  taxi ", exclude: true) == [.note("taxi"), .hidingSelected])
        #expect(active(note: "   ").isEmpty, "Una nota en blanco no filtra nada.")
    }

    @Test func eachFilter_appearsOnlyWhenItNarrows_inRowOrder() {
        let all = active(accounts: (1, 3), subs: (4, 10), tags: (1, 2), needs: (2, 4),
                         currencies: ["USD"], amount: true, note: "cena", exclude: true)
        #expect(all == [.accounts(1), .categories(4), .tags(1), .needs(2), .currencies(["USD"]), .amount,
                        .note("cena"), .hidingSelected])
    }

    @Test func noAccountsOffered_isNotAFilter() {
        #expect(active(accounts: (0, 0)).isEmpty)
    }

    // MARK: - L20-2 · La cifra

    @Test func countLine_countingNoneOrSome() {
        #expect(Logic.countLine(for: nil) == .counting)
        #expect(Logic.countLine(for: 0) == .none)
        #expect(Logic.countLine(for: 2326) == .some(2326))
    }

    /// Con cero no se exporta: el botón se apaga ANTES del archivo vacío (L20-2). Mientras cuenta, tampoco.
    @Test func canExport_needsAPositiveCount_andTheRestValid() {
        #expect(Logic.canExport(count: 5, hasAccountSelected: true, amountIsValid: true, hasColumns: true))
        #expect(!Logic.canExport(count: 0, hasAccountSelected: true, amountIsValid: true, hasColumns: true))
        #expect(!Logic.canExport(count: nil, hasAccountSelected: true, amountIsValid: true, hasColumns: true))
        #expect(!Logic.canExport(count: 5, hasAccountSelected: false, amountIsValid: true, hasColumns: true))
        #expect(!Logic.canExport(count: 5, hasAccountSelected: true, amountIsValid: false, hasColumns: true))
        #expect(!Logic.canExport(count: 5, hasAccountSelected: true, amountIsValid: true, hasColumns: false))
    }

    @Test func endsToday_byCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 10))!
        let endOfToday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 23, minute: 59, second: 59))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 23, minute: 59, second: 59))!
        let start = calendar.date(from: DateComponents(year: 2024, month: 10, day: 17))!
        #expect(Logic.endsToday(DateInterval(start: start, end: endOfToday), now: now, calendar: calendar))
        #expect(!Logic.endsToday(DateInterval(start: start, end: yesterday), now: now, calendar: calendar))
    }

    // MARK: - L20-3 · Lo que pasó al compartir

    /// Cancelar no es «completada»: no enseña nada. Es el corazón de L20-3 y L19-16.
    @Test func cancelled_showsNothing() {
        #expect(Logic.shareOutcome(completed: false, activityType: nil) == .cancelled)
        #expect(Logic.shareOutcome(completed: false, activityType: "com.apple.DocumentManagerUICore.SaveToFiles")
                == .cancelled)
    }

    @Test func knownDestinations_areNamed() {
        #expect(Logic.shareOutcome(completed: true, activityType: "com.apple.DocumentManagerUICore.SaveToFiles")
                == .sharedTo(.files))
        #expect(Logic.shareOutcome(completed: true, activityType: "com.apple.UIKit.activity.Mail") == .sharedTo(.mail))
        #expect(Logic.shareOutcome(completed: true, activityType: "com.apple.UIKit.activity.Message")
                == .sharedTo(.messages))
        #expect(Logic.shareOutcome(completed: true, activityType: "com.apple.mobilenotes.SharingExtension")
                == .sharedTo(.notes))
        #expect(Logic.shareOutcome(completed: true, activityType: "net.whatsapp.WhatsApp.ShareExtension")
                == .sharedTo(.brand("WhatsApp")))
        #expect(Logic.shareOutcome(completed: true, activityType: "com.google.Drive.ShareExtension")
                == .sharedTo(.brand("Google Drive")))
        #expect(Logic.shareOutcome(completed: true, activityType: "com.google.Gmail.ShareExtension")
                == .sharedTo(.brand("Gmail")))
        #expect(Logic.shareOutcome(completed: true, activityType: "com.microsoft.Office.Excel.ShareExtension")
                == .sharedTo(.brand("Excel")))
    }

    /// AirDrop, copiar o una app desconocida: se compartió, pero no hay un «sitio» que nombrar.
    @Test func unknownOrPlacelessDestinations_areGeneric() {
        #expect(Logic.shareOutcome(completed: true, activityType: "com.apple.UIKit.activity.AirDrop") == .sharedSomewhere)
        #expect(Logic.shareOutcome(completed: true, activityType: "com.apple.UIKit.activity.CopyToPasteboard")
                == .sharedSomewhere)
        #expect(Logic.shareOutcome(completed: true, activityType: "com.example.Unknown.Share") == .sharedSomewhere)
        #expect(Logic.shareOutcome(completed: true, activityType: nil) == .sharedSomewhere)
    }

    @MainActor
    @Test func alertTitle_namesTheAppOrSaysItGeneric() {
        let files = ExportShareResult.title(for: .sharedTo(.files))
        #expect(files == L10n.UXL20D.doneIn(L10n.UXL20D.appFiles))
        #expect(ExportShareResult.title(for: .sharedTo(.brand("WhatsApp"))).contains("WhatsApp"))
        #expect(ExportShareResult.title(for: .sharedSomewhere) == L10n.UXL20D.doneShared)
        #expect(files != L10n.UXL20D.doneShared)
    }

    // MARK: - L20-4 · El nombre del archivo

    @Test func fileName_readableDate_inTheAppLanguage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 12))!
        let es = Logic.fileName(stem: "Registros", date: date, locale: Locale(identifier: "es_PE"), fileExtension: "xlsx")
        #expect(es.hasPrefix("Yala_Registros_17-oct"), "\(es)")
        #expect(es.hasSuffix("2026.xlsx"), "\(es)")
        let en = Logic.fileName(stem: "Records", date: date, locale: Locale(identifier: "en_US"), fileExtension: "csv")
        #expect(en == "Yala_Records_Oct-17-2026.csv", "\(en)")
    }

    /// Nada de lo que un nombre de archivo lleva mal: puntos, comas, barras, dos puntos ni espacios.
    @Test func fileName_hasNoUnsafeCharacters_inAnyLanguage() {
        let date = Date(timeIntervalSince1970: 1_792_000_000)
        for id in ["es_PE", "es_ES", "es_AR", "en_US", "en_GB", "de_DE", "fr_FR", "it_IT", "pt_BR", "pt_PT", "nl_NL",
                   "pl_PL", "ja_JP", "zh_Hans_CN"] {
            let name = Logic.fileName(stem: "Stem", date: date, locale: Locale(identifier: id), fileExtension: "xlsx")
            let body = String(name.dropLast(".xlsx".count))
            #expect(!body.contains(where: { " /\\:.,".contains($0) }), "\(id): \(name)")
            #expect(!body.contains("--"), "\(id): \(name)")
        }
    }

    @Test func sanitize_collapsesSeparators() {
        #expect(Logic.sanitizedForFileName("17. Okt. 2026") == "17-Okt-2026")
        #expect(Logic.sanitizedForFileName("17 oct 2026") == "17-oct-2026")
        #expect(Logic.sanitizedForFileName("Oct 17, 2026") == "Oct-17-2026")
    }

    // MARK: - L20-5 · Vaciar

    @Test func wipeRow_promisesOnlyWhatThereIs() {
        #expect(Logic.wipeRowKeeps(hasYalaAccount: true, hasGroups: true) == .accountAndGroups)
        #expect(Logic.wipeRowKeeps(hasYalaAccount: true, hasGroups: false) == .account)
        #expect(Logic.wipeRowKeeps(hasYalaAccount: false, hasGroups: true) == .groups)
        #expect(Logic.wipeRowKeeps(hasYalaAccount: false, hasGroups: false) == .nothing)
    }

    @Test func wipeSentence_followsTheOperationAndWhereThePersonalDataLives() {
        #expect(Logic.wipeSentence(for: .wipeDataFull, cloudLabel: .icloud) == .deviceAndICloud)
        #expect(Logic.wipeSentence(for: .wipeDataFull, cloudLabel: .cloudAccount) == .deviceAndCloudAccount)
        #expect(Logic.wipeSentence(for: .wipeDataGroupsOnly, cloudLabel: .icloud) == .profileOnly)
        #expect(Logic.wipeSentence(for: .wipeDataGroupsOnly, cloudLabel: .cloudAccount) == .profileOnly)
    }

    /// «Exportar una copia antes» solo donde hay registros que copiar.
    @Test func exportCopy_onlyInTheFullWipe() {
        #expect(Logic.offersExportCopy(for: .wipeDataFull))
        #expect(!Logic.offersExportCopy(for: .wipeDataGroupsOnly))
    }

    // MARK: - L19-12 · La confirmación nombra los grupos

    @MainActor
    @Test func leaveAllConfirmation_listsTheGroups() {
        let message = GroupsGlobalSettingsView.confirmMessage(
            for: ["Viaje a Cusco", "Viaje a Lima"], locale: Locale(identifier: "es_PE"))
        #expect(message.contains("Viaje a Cusco"))
        #expect(message.contains("Viaje a Lima"))
        #expect(GroupsGlobalSettingsView.confirmMessage(for: []) == L10n.UXL20D.leaveAllConfirmMessageGeneric)
    }

    @MainActor
    @Test func leaveAllOffer_sameConditionsAsBefore() {
        // Sin seams (unit), decide el canal: con deuda o sin grupos, no se ofrece.
        let debt = AccountDeletionGroupsSummary(outstandingDebtGroupCount: 1, hasLegacyCloudKitFootprint: false,
                                                hasGroups: true)
        let none = AccountDeletionGroupsSummary(outstandingDebtGroupCount: 0, hasLegacyCloudKitFootprint: false,
                                                hasGroups: false)
        let settled = AccountDeletionGroupsSummary(outstandingDebtGroupCount: 0, hasLegacyCloudKitFootprint: false,
                                                   hasGroups: true)
        #expect(!GroupsGlobalSettingsView.offersLeaveAllGroups(debt))
        #expect(!GroupsGlobalSettingsView.offersLeaveAllGroups(none))
        #expect(GroupsGlobalSettingsView.offersLeaveAllGroups(settled) == CloudSyncFlags.groupsBackendEnabled)
    }
}
