//
//  CloudPersonalAttestSignOutTests.swift
//  YalaTests
//
//  Cerrar sesión en la nube con un teléfono sin App Attest y cambios PERSONALES sin subir (ticket
//  `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`, decisión de Jürgen del 2026-09-15): el aviso ofrece
//  exportar todos los movimientos y, después, salir perdiendo esos cambios con confirmación.
//
//  Tres suites, y `-only-testing` filtra por TIPO, no por fichero:
//   - `CloudPersonalAttestSignOutLogicTests`: el motivo, lo aceptado y los textos (lógica pura).
//   - `CloudPersonalAttestExportTests`: la exportación de TODOS los movimientos, con SwiftData.
//   - `CloudPersonalAttestSignOutWiringTests`: el cableado por source-scan. El coordinador es privado y su camino exige
//     singletons de red, del espejo y de credenciales, igual que en las suites hermanas de `CloudSignOutFlowLogicTests`.
//  El testigo del motor personal y la racha se prueban con el runtime de verdad en `CloudSyncRuntimeTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Nube sin App Attest — el motivo personal, la cifra aceptada y los textos")
struct CloudPersonalAttestSignOutLogicTests {

    typealias L = CloudSignOutFlowLogic

    /// La parada terminal de la puerta de attest del motor personal llega como `.accountUnavailable`: con el testigo, el
    /// push-all la lleva a la fase como el teléfono sin attest; sin él sigue siendo el aviso de siempre.
    @Test("MUTACIÓN: el veredicto del push-all lleva el attest a la fase, también desde la parada terminal de la puerta")
    func pushAllVerdictCarriesTheAttestFromTheTerminalStop() {
        #expect(L.pushAllVerdict(livePendingCount: 3, cycleOutcome: .accountUnavailable, channelKilled: false,
                                 attestUnavailable: true, uploadFailed: false, iteration: 1, maxIterations: 20)
                == .blocked(pendingCount: 3, reason: .attestUnavailable))
        #expect(L.pushAllVerdict(livePendingCount: 3, cycleOutcome: .accountUnavailable, channelKilled: false,
                                 attestUnavailable: false, uploadFailed: false, iteration: 1, maxIterations: 20)
                == .blocked(pendingCount: 3, reason: .permanent))
        #expect(L.pushAllVerdict(livePendingCount: 3, cycleOutcome: .transient, channelKilled: false,
                                 attestUnavailable: true, uploadFailed: false, iteration: 1, maxIterations: 20)
                == .blocked(pendingCount: 3, reason: .attestUnavailable))
    }

    @Test("se enseña al momento, tiene su slug y la traducción de grupos no lo recibe")
    func surfacesImmediately_andTheGroupsTranslationNeverReceivesIt() {
        for elapsed in [0.0, 10, 44, 100] {
            #expect(GroupsSignOutRetryDecision.decide(
                elapsedSeconds: elapsed, budgetSeconds: GroupsSignOutRetryDecision.budgetSeconds,
                reason: .personalAttestUnavailable) == .surfacePermanent)
        }
        #expect(L.cloudSignOutGroupsBlockReason(.personalAttestUnavailable) == .permanent)
        #expect(L.BlockReason.personalAttestUnavailable.breadcrumbSlug == "personal-attest-unavailable")
    }

    /// Lo aceptado son las FILAS del aviso: una fila nueva vuelve a avisar aunque la cifra no crezca, y sin aceptación el
    /// cierre nunca descarta nada.
    @Test("MUTACIÓN: lo aceptado de lo personal son las filas de su aviso, no una cifra")
    func acceptedPersonalLossIsByRow() {
        let a = UUID(), b = UUID(), c = UUID()
        #expect(L.continuesWithoutUploading(pendingRows: [a, b], acceptance: .rows([a, b])))
        #expect(!L.continuesWithoutUploading(pendingRows: [a, c], acceptance: .rows([a, b])), "c no estaba en el aviso")
        #expect(!L.continuesWithoutUploading(pendingRows: [a], acceptance: nil), "sin aceptar, el cierre nunca descarta")
        #expect(!L.continuesWithoutUploading(pendingRows: nil, acceptance: .rows([a])), "una fila sin mirar no se descarta")
    }

    /// Al retomar el cierre, lo aceptado solo vale mientras el bloqueo siga siendo el attest. Con el attest recuperado y la
    /// subida fallando por otra cosa, seguir se llevaría cambios que un reintento subiría (review adversarial, 2026-09-15).
    @Test("MUTACIÓN: al retomar, lo aceptado solo cubre un bloqueo que siga siendo el attest")
    func acceptanceOnlyCoversARetryStillBlockedByAttest() {
        let a = UUID()
        #expect(L.continuesAfterBlockedUpload(reason: .attestUnavailable, pendingRows: [a], acceptance: .rows([a])))
        for otro in L.BlockReason.allCases where otro != .attestUnavailable {
            #expect(!L.continuesAfterBlockedUpload(reason: otro, pendingRows: [a], acceptance: .rows([a])),
                    "con \(otro) el attest ya no es la causa: un reintento podría subirlos")
        }
        #expect(!L.continuesAfterBlockedUpload(reason: .attestUnavailable, pendingRows: [a, UUID()], acceptance: .rows([a])))
        #expect(!L.continuesAfterBlockedUpload(reason: .attestUnavailable, pendingRows: [a], acceptance: nil))
    }

    @MainActor
    @Test("MUTACIÓN: el aviso de tus datos cuenta lo que se pierde solo con una cifra honesta, y no se confunde con el de grupos")
    func personalLossMessage_countsOnlyAnHonestNumber() {
        #expect(SignOutBlockedCopy.personalAttestLossMessage(pending: 3) == L10n.Settings.signOutAttestMessage(3))
        #expect(SignOutBlockedCopy.personalAttestLossMessage(pending: Int.max) == L10n.Settings.signOutAttestMessageUnknown)
        #expect(SignOutBlockedCopy.personalAttestLossMessage(pending: 0) == L10n.Settings.signOutAttestMessageUnknown)
        #expect(SignOutBlockedCopy.title(for: .personalAttestUnavailable) == L10n.Settings.signOutAttestTitle)
        #expect(SignOutBlockedCopy.message(for: .personalAttestUnavailable) == L10n.Settings.signOutAttestBlocked)
        #expect(SignOutBlockedCopy.title(for: .personalAttestUnavailable) != SignOutBlockedCopy.title(for: .attestUnavailable))
    }

    /// El texto del servicio está en español y habla de filtros: el aviso de error de esta exportación tiene los suyos.
    @MainActor
    @Test("MUTACIÓN: el error de la exportación dice «no hay movimientos» solo cuando no los hay, y si no, que falló")
    func exportFailureMessage_distinguishesNoTransactionsFromAFailure() {
        #expect(SignOutBlockedCopy.personalExportFailureMessage(for: TransactionsExportError.noTransactionsToExport)
                == L10n.Settings.signOutAttestExportEmpty)
        #expect(SignOutBlockedCopy.personalExportFailureMessage(
            for: TransactionsExportError.fileWriteFailed(underlying: NSError(domain: "test", code: 1)))
                == L10n.Settings.signOutAttestExportFailed)
        #expect(SignOutBlockedCopy.personalExportFailureMessage(for: URLError(.cancelled)) == L10n.Settings.signOutAttestExportFailed)
        #expect(L10n.Settings.signOutAttestExportEmpty != L10n.Settings.signOutAttestExportFailed)
    }

    /// Un accessor-función que formatea mal devuelve la key cruda o se come la cifra, y la paridad de los `.strings` no lo ve:
    /// compara `.strings` con `.strings` y nunca abre `L10n.swift`.
    @MainActor
    @Test("los accesores del aviso interpolan la cifra y nunca devuelven la key cruda")
    func accessors_interpolate_neverRawKey() {
        let conCifra = L10n.Settings.signOutAttestMessage(7)
        #expect(!conCifra.contains("settings."))
        #expect(conCifra.contains("7"))
        for texto in [L10n.Settings.signOutAttestTitle, L10n.Settings.signOutAttestMessageUnknown,
                      L10n.Settings.signOutAttestExportButton, L10n.Settings.signOutAttestLossButton,
                      L10n.Settings.signOutAttestBlocked, L10n.Settings.signOutAttestExportEmpty,
                      L10n.Settings.signOutAttestExportFailed] {
            #expect(!texto.contains("settings."), "accessor devolvió la key cruda: \(texto)")
        }
    }
}

@Suite("Nube sin App Attest — exportar todos los movimientos", .serialized)
@MainActor
struct CloudPersonalAttestExportTests {

    /// «Todos» es todos. `DetailPeriod.allTime` son diez años hasta el final de hoy, así que el mutante que vuelva a él deja
    /// fuera lo antiguo y lo de fecha futura. El control con ese periodo prueba que el caso los distingue.
    @Test("MUTACIÓN: la exportación del aviso lleva también lo de hace más de diez años y lo de fecha futura")
    func exportsEveryTransaction_regardlessOfDate() throws {
        let context = try makeTestContext()
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let antiguo = try #require(calendar.date(byAdding: .year, value: -20, to: now))
        let futuro = try #require(calendar.date(byAdding: .year, value: 1, to: now))
        for date in [antiguo, now, futuro] {
            context.insert(TransactionItem(date: date, amount: -10.0, currencyCode: "USD"))
        }
        try context.save()

        let todos = try TransactionsExportService.export(
            format: .csv, using: .allTransactions, columns: .default, in: context, scheduleTagBackfill: false)
        #expect(todos.exportedCount == 3)

        let periodo = DetailPeriod.allTime.dateInterval()
        var asistente = ExportFilters.allTransactions
        asistente.dateFrom = periodo.start
        asistente.dateTo = periodo.end
        let control = try TransactionsExportService.export(
            format: .csv, using: asistente, columns: .default, in: context, scheduleTagBackfill: false)
        #expect(control.exportedCount == 1, "el control no distingue: el caso no probaría nada")
    }

    /// Rellenar el espejo de etiquetas es un guardado, y en la nube serían cambios por subir que la persona no escribió: el
    /// aviso volvería con otra cifra. La exportación del aviso no lo rellena; la del asistente sí, que es el control.
    @Test("MUTACIÓN: la exportación del aviso no escribe el espejo de etiquetas, y la del asistente sí")
    func rescueExportDoesNotBackfillTheTagMirror() async throws {
        let context = try makeTestContext()
        let tag = Yala.Tag(name: "Viaje")
        context.insert(tag)
        let tx = TransactionItem(date: Date(), amount: -10.0, currencyCode: "USD")
        context.insert(tx)
        tx.tags = [tag]  // sin espejo: el estado que el relleno cura
        try context.save()
        #expect(tx.tagIDs == nil)

        _ = try TransactionsExportService.export(
            format: .csv, using: .allTransactions, columns: .default, in: context, scheduleTagBackfill: false)
        for _ in 0..<5 { await Task.yield() }
        #expect(tx.tagIDs == nil, "la exportación del aviso guardó el espejo de etiquetas")

        _ = try TransactionsExportService.export(
            format: .csv, using: .allTransactions, columns: .default, in: context, scheduleTagBackfill: true)
        for _ in 0..<5 { await Task.yield() }
        #expect(tx.tagIDs != nil, "control: con el relleno activo el espejo se escribe; si no, el caso no mide nada")
    }

    @Test("sin filtros de cuenta, categoría, etiqueta, moneda, monto ni nota, y con todas las columnas")
    func hasNoFilters() {
        let filtros = ExportFilters.allTransactions
        #expect(filtros.selectedAccounts.isEmpty)
        #expect(filtros.selectedCategories.isEmpty)
        #expect(filtros.selectedSubcategories.isEmpty)
        #expect(filtros.selectedTagNames.isEmpty)
        #expect(filtros.selectedCurrencies.isEmpty)
        #expect(filtros.amountCondition == .any)
        #expect(filtros.noteContains == nil)
        #expect(!filtros.isExcludeMode)
        #expect(ExportColumns.default.activeColumns.count == ExportColumn.allCases.count)
    }
}

@Suite("Nube sin App Attest — la salida personal, cableada (source-scan)")
struct CloudPersonalAttestSignOutWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo balanceado por llaves desde un marcador que ACABA en `{`.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    /// El tramo entre dos marcadores, para las firmas que ocupan varias líneas y no acaban en `{`.
    private static func slice(from start: String, to end: String, in source: String) throws -> String {
        let s = try #require(source.range(of: start), "no se encontró `\(start)`")
        let e = try #require(source.range(of: end, range: s.upperBound..<source.endIndex), "no se encontró `\(end)`")
        return String(source[s.upperBound..<e.lowerBound])
    }

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static let signOutPath = "Yala/Services/CloudSync/CloudSessionSignOut.swift"
    private static let profilePath = "Yala/App/Views/Profile/ProfileView.swift"

    private static func cloudSignOut() throws -> String {
        squashed(try body(of: "private func performCloudSecureSignOut(context: ModelContext) async {", in: source(signOutPath)))
    }

    @Test("MUTACIÓN: el paso 1 separa SOLO el attest, anota la oferta antes de la fase y enseña la cifra de las filas aceptadas")
    func stepOneTranslatesOnlyTheAttest() throws {
        let cloud = try Self.cloudSignOut()
        #expect(cloud.contains(Self.squashed("""
            if !CloudSignOutFlowLogic.continuesAfterBlockedUpload(
                reason: reason, pendingRows: rows, acceptance: acceptedPersonalLoss) {
                acceptedPersonalLoss = nil
                guard reason == .attestUnavailable else {
                    phase = .blocked(pendingCount: pending, reason: .permanent)
            """)), """
            El paso 1 dejó de separar el attest del resto de motivos: o todo bloqueo personal ofrecería perder datos, o \
            una aceptación dejaría pasar filas que nadie aceptó.
            """)
        let oferta = try #require(cloud.range(of: "personalLossExit = PersonalLossOffer(rows: rows)"))
        let fase = try #require(cloud.range(of: "phase = .blocked(pendingCount: shown, reason: .personalAttestUnavailable)"))
        #expect(oferta.lowerBound < fase.lowerBound, "la oferta se anota DESPUÉS de la fase: el aviso saldría sin su salida")
        #expect(cloud.contains("let shown = rows?.count ?? Int.max"), "la cifra del aviso tiene que salir de las filas que se aceptan")
    }

    /// Los tres sitios que suben con una pérdida aceptada —los pasos 1 y 2 de la nube y `pushGroupsForSignOut`— exigen que
    /// el bloqueo siga siendo el attest. Con la comparación por filas a secas, un 5xx al retomar se llevaba los cambios.
    @Test("MUTACIÓN: los tres sitios que retoman con lo aceptado exigen que el bloqueo siga siendo el attest")
    func theThreeRetrySitesRequireTheAttest() throws {
        let source = Self.squashed(try Self.source(Self.signOutPath))
        #expect(source.components(separatedBy: "CloudSignOutFlowLogic.continuesAfterBlockedUpload(").count - 1 == 3)
        #expect(source.components(separatedBy: "CloudSignOutFlowLogic.continuesWithoutUploading(").count - 1 == 3, """
            La comparación por filas a secas solo vale en los recuentos finales, tras soltar el canal: el de la nube, con \
            una llamada para lo personal y otra para grupos, y el de `finalizeSessionExit`.
            """)
        #expect(source.contains(Self.squashed("""
            case .blocked(_, let reason) where CloudSignOutFlowLogic.continuesAfterBlockedUpload(
                reason: reason, pendingRows: Self.liveGroupsPendingRowIDs(context: context), acceptance: acceptedGroupsLoss):
            """)))
        #expect(source.contains(Self.squashed("""
            case .blocked(_, let reason):
                if CloudSignOutFlowLogic.continuesAfterBlockedUpload(
                    reason: reason, pendingRows: Self.liveGroupsPendingRowIDs(context: context), acceptance: accepted) {
                    return true
                }
            """)))
    }

    @Test("MUTACIÓN: la salida personal exige su bloqueo y su oferta, y retoma el cierre en la nube con las filas del aviso")
    func theExitIsGuarded() throws {
        let exit = Self.squashed(try Self.body(
            of: "func exitDiscardingUnsyncedPersonalChanges(context: ModelContext) async {", in: Self.source(Self.signOutPath)))
        #expect(exit.contains(Self.squashed(
            "guard case .blocked(let shown, .personalAttestUnavailable) = phase, let offer = personalLossExit else { return }")), """
            Sin el guard, «Cerrar sesión y perderlos» descartaría cambios personales sin que ningún aviso lo haya ofrecido.
            """)
        #expect(exit.contains("acceptedPersonalLoss = offer.rows.map { .rows($0) } ?? .uncounted"))
        #expect(exit.contains("await performCloudSecureSignOut(context: context)"))
    }

    @Test("MUTACIÓN: el recuento final respeta cada aceptación en su outbox, y cuenta la pérdida pegada al arm")
    func theFinalCountRespectsEachAcceptance() throws {
        let cloud = try Self.cloudSignOut()
        #expect(cloud.contains(Self.squashed("""
            guard residualPersonal == 0 || CloudSignOutFlowLogic.continuesWithoutUploading(
                      pendingRows: controller.livePendingUploadRowIDs(), acceptance: acceptedPersonalLoss),
            """)), "El último recuento dejó de respetar lo aceptado de lo personal: el cierre se pararía tras soltar el canal.")
        let nota = try #require(cloud.range(of: "if acceptedPersonalLoss != nil { Self.notePersonalDiscarded(pending: residualPersonal) }"))
        let arm = try #require(cloud.range(of: "StorageModePersistence.armSignOutWipe()"))
        #expect(nota.lowerBound < arm.lowerBound)
    }

    @Test("MUTACIÓN: «Ahora no», un gesto nuevo y el desasociar retiran lo aceptado de lo personal")
    func personalAcceptanceDoesNotSurviveTheGesture() throws {
        let source = try Self.source(Self.signOutPath)
        let tramos = [
            ("acknowledgeBlocked", try Self.body(of: "func acknowledgeBlocked() {", in: source)),
            ("signOut", try Self.slice(
                from: "func signOut(context: ModelContext, confirmedPath: CloudSignOutFlowLogic.Path? = nil,",
                to: "func detachGroupsAccount(", in: source)),
            ("detachGroupsAccount", try Self.slice(from: "func detachGroupsAccount(", to: "func retryDetachPurge(", in: source)),
        ]
        for (nombre, tramo) in tramos {
            #expect(tramo.contains("personalLossExit = nil"), "`\(nombre)` no retira la oferta personal")
            #expect(tramo.contains("acceptedPersonalLoss = nil"), "`\(nombre)` no retira lo aceptado de lo personal")
        }
    }

    @Test("MUTACIÓN: el push-all personal pregunta el testigo al runtime, y el runtime lo baja antes de cualquier salida del ciclo")
    func theRuntimeWitnessIsAskedAndResetFirst() throws {
        #expect(try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift")
            .contains("attestUnavailable: runtime.stoppedByUnavailableAttest(for: outcome)"))
        let cycle = Self.squashed(try Self.body(
            of: "private func performCycle() async -> SyncCadencePolicy.CadenceOutcome {",
            in: Self.source("Yala/Services/CloudSync/CloudSyncRuntime.swift")))
        #expect(cycle.hasPrefix("lastCycleStoppedAtAttestGate = false guard let context else { return .transient }"))
    }

    @Test("MUTACIÓN: Ajustes enciende el aviso de tus datos solo con su oferta, y sus tres botones hacen lo suyo en orden")
    func settingsWiresTheNotice() throws {
        let profile = try Self.source(Self.profilePath)
        let present = Self.squashed(try Self.body(
            of: "private func presentSignOutBlock(_ reason: CloudSignOutFlowLogic.BlockReason) {", in: profile))
        #expect(present.contains(Self.squashed("""
            case .personalAttestUnavailable:
                if signOutCoordinator.offersPersonalLossExit {
                    showSignOutPersonalAttestAlert = true
                } else {
                    showSignOutBlockedAlert = true
                }
            """)))
        #expect(present.contains("showSignOutPersonalAttestAlert = false"), "el aviso no se apaga antes de presentar el siguiente")
        #expect(Self.squashed(profile).contains(Self.squashed("""
            .alert(L10n.Settings.signOutAttestTitle, isPresented: $showSignOutPersonalAttestAlert) {
                Button(L10n.Settings.signOutAttestExportButton) {
                    exportAllTransactionsBeforeLosingThem()
                }
                Button(L10n.Settings.signOutAttestLossButton, role: .destructive) {
                    Task { await CloudSessionSignOut.shared.exitDiscardingUnsyncedPersonalChanges(context: modelContext) }
                }
                Button(L10n.Action.notNow, role: .cancel) {
                    CloudSessionSignOut.shared.acknowledgeBlocked()
                }
            } message: {
                Text(SignOutBlockedCopy.personalAttestLossMessage(pending: signOutPersonalAttestPending))
            }
            """)))
        let sync = Self.squashed(try Self.body(
            of: "private func syncSignOutUI(from phase: CloudSessionSignOut.Phase) {", in: profile))
        #expect(sync.contains("if reason == .personalAttestUnavailable { signOutPersonalAttestPending = pending }"), """
            Ajustes dejó de guardar la cifra del bloqueo: el aviso saldría sin cifra y la persona aceptaría perder cambios sin \
            saber cuántos.
            """)
    }

    /// El cuerpo ENTERO de la exportación: con dos literales sueltos sobrevivían quitar el turno de espera, silenciar el
    /// error, reconocer el bloqueo por el alias del coordinador o apagar el canario (review adversarial, 2026-09-15;
    /// `testing.md`, «el source-scan de dos literales no es una red»).
    @Test("MUTACIÓN: exportar lleva TODOS los movimientos sin tocar el cierre, con indicador y texto propio, y vuelve el aviso")
    func settingsExportsEverythingAndReturnsToTheNotice() throws {
        let profile = try Self.source(Self.profilePath)
        let export = Self.squashed(try Self.body(of: "private func exportAllTransactionsBeforeLosingThem() {", in: profile))
        #expect(export == Self.squashed("""
            isExportingBeforeLosingChanges = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                defer { isExportingBeforeLosingChanges = false }
                do {
                    let result = try TransactionsExportService.export(
                        format: .csv, using: .allTransactions, columns: .default, in: modelContext,
                        scheduleTagBackfill: false)
                    CloudSessionSignOut.notePersonalLossExport(rows: result.exportedCount)
                    signOutRescueExportFile = ExportedFile(urls: [result.fileURL])
                } catch {
                    #if DEBUG
                    print("ProfileView: Error exportando los movimientos antes de cerrar sesión: \\(error)")
                    #endif
                    signOutRescueExportErrorMessage = SignOutBlockedCopy.personalExportFailureMessage(for: error)
                    showSignOutRescueExportError = true
                }
            }
            """), "La exportación del aviso cambió: revisa que siga sin tocar el cierre, con su turno, su indicador y su canario.")
        let vuelta = Self.squashed(try Self.body(of: "private func returnToPersonalAttestNotice() {", in: profile))
        #expect(vuelta == Self.squashed("""
            guard case .blocked(_, .personalAttestUnavailable) = signOutCoordinator.phase else { return }
            syncSignOutUI(from: signOutCoordinator.phase)
            """))
        let todo = Self.squashed(profile)
        #expect(todo.contains(".sheet(item: $signOutRescueExportFile, onDismiss: { returnToPersonalAttestNotice() }) { file in"))
        #expect(todo.contains(Self.squashed("""
            .alert(L10n.Export.exportError, isPresented: $showSignOutRescueExportError) {
                Button(L10n.Common.ok, role: .cancel) { returnToPersonalAttestNotice() }
            } message: {
                Text(signOutRescueExportErrorMessage)
            }
            """)))
        #expect(todo.contains("if isExportingBeforeLosingChanges {"), "el indicador de la exportación dejó de pintarse")
    }

    /// Un intercambio de los dos botones en un idioma pondría el rol destructivo sobre «Exportar». Por diseño, el botón de la
    /// pérdida dice en cada idioma lo mismo que el de grupos, así que la comparación lo caza sin leer ningún idioma.
    @Test("MUTACIÓN: en los 16 idiomas el botón de la pérdida dice lo mismo que el de grupos, y el de exportar otra cosa")
    func theButtonsKeepTheirMeaningInEveryLocale() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let locales = ["en", "en-GB", "es", "es-419", "es-AR", "es-ES", "de", "fr", "it", "nl", "pl", "pt", "pt-BR", "pt-PT",
                       "ja", "zh-Hans"]
        for locale in locales {
            let url = root.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "no se pudo leer \(locale)")
            let perder = try #require(table["settings.signOutAttestLossButton"], "\(locale) sin el botón de la pérdida")
            #expect(perder == table["groups.errors.attestUnavailableSignOutLossButton"],
                    "\(locale): el botón destructivo dejó de nombrar la pérdida como el de grupos")
            #expect(table["settings.signOutAttestExportButton"] != perder, "\(locale): exportar y perder dicen lo mismo")
        }
    }
}
