//
//  WidgetGroupsSnapshotTests.swift
//  YalaTests
//
//  El widget «Grupos» (S35f3) dice lo que dice la lista de Grupos.
//
//  1. **Paridad**: la parte de grupos de la foto (`WidgetGroupsSnapshotBuilder`) da las mismas cifras que
//     `GroupsViewModel` con los mismos datos: el resumen de arriba (`globalSummary`, con el filtro de
//     `GroupSummaryHeader.amounts`) y, por grupo, lo que debes o te deben neteado como la banda del detalle.
//     El fixture trae lo que separa las reglas: un grupo archivado y otro oculto para todos con deuda (el resumen
//     cuenta el oculto y no el archivado; las filas, ninguno), dos divisas y un grupo con «simplificar» y otro sin.
//  2. **Orden de filas** del widget (`WidgetInsightsLogic.orderedGroupRows`): primero lo que debes.
//  3. **Refresco** (`WidgetGroupsRefreshLogic`): solo rehace la foto si los grupos cambiaron y se pudieron leer.
//  4. **Cableado**: quién llama a quién (source-scan), porque `YalaTests` no compila `YalaWidgets` y el embudo de
//     `dataVersion` no se puede llamar sin arrastrar a media app.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Widget de Grupos · paridad con la lista", .serialized)
struct WidgetGroupsSnapshotParityTests {

    // MARK: - Fixture

    private func member(_ context: ModelContext, _ group: SplitGroup, _ name: String, me: Bool = false,
                        status: SplitMemberStatus = .active) -> SplitMember {
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: name, status: status, isCurrentUser: me)
        context.insert(member)
        return member
    }

    private func expense(
        _ context: ModelContext, _ group: SplitGroup, payer: SplitMember, among members: [SplitMember],
        amount: Double, currency: String
    ) {
        let expense = SplitExpense(
            groupZoneID: group.cloudKitZoneID, amount: amount, currencyCode: currency,
            expenseDescription: "Gasto", paidByMemberID: payer.id.uuidString
        )
        context.insert(expense)
        for m in members {
            context.insert(SplitShare(expenseID: expense.id, memberID: m.id.uuidString,
                                      amount: amount / Double(members.count), groupZoneID: group.cloudKitZoneID))
        }
    }

    private func group(_ context: ModelContext, _ name: String, simplify: Bool = false) -> SplitGroup {
        let group = SplitGroup(name: name, iconName: "airplane", colorHex: "#00C2CB", currencyCode: "PEN",
                               simplifyDebts: simplify)
        context.insert(group)
        return group
    }

    /// Cinco grupos:
    /// - «Depa» (sin simplificar): Ana pagó 100 PEN entre los dos ⇒ debo 50 PEN.
    /// - «Viaje» (simplificado): pagué 90 USD entre tres ⇒ me deben 60 USD; y Beto pagó 30 PEN entre los tres ⇒ debo 10 PEN.
    /// - «Fútbol»: sin gastos ⇒ al día.
    /// - «Archivado»: Ana pagó 40 PEN entre los dos ⇒ debo 20 PEN, pero archivado (ni resumen ni fila).
    /// - «Oculto»: pagué 80 PEN entre los dos ⇒ me deben 40 PEN, oculto para todos (cuenta en el resumen, sin fila).
    /// - «Cena» (sin simplificar, el escenario de la review): Maria paga 150 y yo 90, los dos entre Maria, Juan y yo ⇒
    ///   la tarjeta dice «Le debes a Maria S/ 20» y «Juan te debe S/ 30»; la cabecera del detalle, «te deben S/ 10».
    /// - «Pendiente»: estoy esperando aprobación ⇒ cuenta como grupo, pero sin fila (la tarjeta enseña un chip).
    private func seed(_ context: ModelContext) throws {
        let depa = group(context, "Depa")
        let meD = member(context, depa, "Yo", me: true)
        let ana = member(context, depa, "Ana")
        expense(context, depa, payer: ana, among: [meD, ana], amount: 100, currency: "PEN")

        let viaje = group(context, "Viaje", simplify: true)
        let meV = member(context, viaje, "Yo", me: true)
        let beto = member(context, viaje, "Beto")
        let caro = member(context, viaje, "Caro")
        expense(context, viaje, payer: meV, among: [meV, beto, caro], amount: 90, currency: "USD")
        expense(context, viaje, payer: beto, among: [meV, beto, caro], amount: 30, currency: "PEN")

        let futbol = group(context, "Fútbol")
        _ = member(context, futbol, "Yo", me: true)
        _ = member(context, futbol, "Dani")

        let archivado = group(context, "Archivado")
        archivado.isArchived = true
        let meA = member(context, archivado, "Yo", me: true)
        let anaA = member(context, archivado, "Ana")
        expense(context, archivado, payer: anaA, among: [meA, anaA], amount: 40, currency: "PEN")

        let cena = group(context, "Cena")
        let meC = member(context, cena, "Yo", me: true)
        let maria = member(context, cena, "Maria")
        let juan = member(context, cena, "Juan")
        expense(context, cena, payer: maria, among: [meC, maria, juan], amount: 150, currency: "PEN")
        expense(context, cena, payer: meC, among: [meC, maria, juan], amount: 90, currency: "PEN")

        let pendiente = group(context, "Pendiente")
        _ = member(context, pendiente, "Yo", me: true, status: .pendingApproval)
        _ = member(context, pendiente, "Lu")

        let oculto = group(context, "Oculto")
        oculto.isHiddenForAll = true
        let meO = member(context, oculto, "Yo", me: true)
        let eva = member(context, oculto, "Eva")
        expense(context, oculto, payer: meO, among: [meO, eva], amount: 80, currency: "PEN")

        try context.save()
    }

    private func withServices(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupService.shared.setContext(context)
        GroupExpenseService.shared.setContext(context)
        defer {
            GroupService.shared._testResetContext()
            GroupExpenseService.shared._testResetContext()
        }
        try body()
    }

    private func amounts(_ items: [WidgetGroupAmount]) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.currencyCode, $0.amount) })
    }

    // MARK: - Paridad

    @Test func elResumenEsElDeArribaDeLaLista() throws {
        let context = try makeTestContext()
        try seed(context)
        try withServices(context) {
            let vm = GroupsViewModel()
            vm.setContext(context)
            let summary = try #require(vm.globalSummary)
            let widget = try #require(WidgetGroupsSnapshotBuilder.build(context: context))

            let listIOwe = GroupSummaryHeader.amounts(summary.totalIOwe)
            let listOwed = GroupSummaryHeader.amounts(summary.totalOwedToMe)
            #expect(widget.iOwe.map(\.currencyCode) == listIOwe.map(\.currencyCode))
            #expect(widget.iOwe.map(\.amount) == listIOwe.map(\.amount))
            #expect(widget.owedToMe.map(\.currencyCode) == listOwed.map(\.currencyCode))
            #expect(widget.owedToMe.map(\.amount) == listOwed.map(\.amount))

            // Control del escenario: el resumen cuenta el oculto (me deben 40 PEN) y no el archivado (debo 20 PEN), y
            // trae las dos divisas. Sin esto, la paridad pasaría también con un fixture que no separa nada.
            // El resumen simplifica las deudas de todos los grupos juntos (`globalSummary`): en «Cena», Juan le paga a
            // Maria y a mí, y yo no debo nada. Debo 50 (Depa) + 10 (Viaje); me deben 40 (Oculto) + 10 (Cena) y 60 USD.
            #expect(amounts(widget.iOwe) == ["PEN": 60])
            #expect(amounts(widget.owedToMe) == ["PEN": 50, "USD": 60])

            let archived = try #require(vm.archivedSummary)
            #expect((widget.archivedIOwe ?? []).map(\.amount) == GroupSummaryHeader.amounts(archived.totalIOwe).map(\.amount))
            #expect(amounts(widget.archivedIOwe ?? []) == ["PEN": 20])
            #expect((widget.archivedOwedToMe ?? []).isEmpty)
        }
    }

    @Test func cadaFilaEsLaCabeceraDelDetalleQueAbre() throws {
        let context = try makeTestContext()
        try seed(context)
        try withServices(context) {
            let vm = GroupsViewModel()
            vm.setContext(context)
            let widget = try #require(WidgetGroupsSnapshotBuilder.build(context: context))

            #expect(widget.activeGroupCount == vm.activeGroups.count)
            let withBalances = vm.activeGroups.filter {
                GroupCardDisplayLogic.displayMode(memberStatus: vm.currentMemberStatus(for: $0),
                                                  migrationState: $0.migrationState) == .active
            }
            #expect(widget.groups.map(\.id) == withBalances.map(\.id.uuidString), """
                Las filas son los grupos de la lista cuya tarjeta enseña saldos, en su orden.
                """)
            #expect(!widget.groups.contains { $0.name == "Pendiente" }, "Control: el pendiente enseña un chip, no cifras.")

            for group in withBalances {
                let row = try #require(widget.groups.first { $0.id == group.id.uuidString })
                let detail = GroupDetailViewModel(group: group)
                detail.setContext(context)
                let band = try #require(detail.headerBalance, "\(group.name): el detalle no tiene cabecera")
                #expect(amounts(row.iOwe) == band.iOwe, "\(group.name)")
                #expect(amounts(row.owedToMe) == band.owedToMe, "\(group.name)")
                #expect(row.name == group.name)
                #expect(row.iconName == group.iconName)
                #expect(row.colorHex == group.colorHex)
            }

            let depa = try #require(widget.groups.first { $0.name == "Depa" })
            #expect(amounts(depa.iOwe) == ["PEN": 50] && depa.owedToMe.isEmpty)
            let viaje = try #require(widget.groups.first { $0.name == "Viaje" })
            #expect(amounts(viaje.iOwe) == ["PEN": 10] && amounts(viaje.owedToMe) == ["USD": 60])
            let cena = try #require(widget.groups.first { $0.name == "Cena" })
            #expect(amounts(cena.owedToMe) == ["PEN": 10] && cena.iOwe.isEmpty, "El neto del grupo, como su cabecera.")
            let futbol = try #require(widget.groups.first { $0.name == "Fútbol" })
            #expect(futbol.iOwe.isEmpty && futbol.owedToMe.isEmpty)
        }
    }

    /// El paso 9 del arranque escribe la foto antes de que los servicios de grupos tengan contexto: el builder no
    /// puede depender de ellos.
    @Test func calculaSinLosServiciosDeGrupos() throws {
        let context = try makeTestContext()
        try seed(context)
        GroupService.shared._testResetContext()
        GroupExpenseService.shared._testResetContext()
        let widget = try #require(WidgetGroupsSnapshotBuilder.build(context: context))
        #expect(widget.activeGroupCount == 5)
        #expect(amounts(widget.iOwe) == ["PEN": 60])
    }

    @Test func sinGruposDaElResumenVacioYNoNil() throws {
        let context = try makeTestContext()
        let widget = try #require(WidgetGroupsSnapshotBuilder.build(context: context), """
            Sin grupos el widget invita a crear uno; `nil` diría «Abre Yala», que es para la foto sin grupos.
            """)
        #expect(widget.activeGroupCount == 0)
        #expect(widget.iOwe.isEmpty && widget.owedToMe.isEmpty && widget.groups.isEmpty)
    }

    @Test func laFotoLlevaLosGrupos() throws {
        let context = try makeTestContext()
        try seed(context)
        let built = WidgetDataCache.buildSnapshot(context: context)
        #expect(built.widget.groups == WidgetGroupsSnapshotBuilder.build(context: context))
        #expect(built.widget.groups?.activeGroupCount == 5)
    }
}

// MARK: - Orden de filas

@Suite("Widget de Grupos · orden de las filas")
struct WidgetGroupRowOrderTests {

    private struct Row: Equatable {
        let name: String
        let owes: Bool
        let isOwed: Bool
    }

    private func ordered(_ rows: [Row], limit: Int) -> [String] {
        WidgetInsightsLogic.orderedGroupRows(rows, limit: limit) {
            WidgetInsightsLogic.groupSide(owes: $0.owes, isOwed: $0.isOwed)
        }.map(\.name)
    }

    @Test func primeroDebesLuegoTeDebenYAlFinalAlDia() {
        let rows = [
            Row(name: "A al día", owes: false, isOwed: false),
            Row(name: "B me deben", owes: false, isOwed: true),
            Row(name: "C debo", owes: true, isOwed: false),
            Row(name: "D me deben", owes: false, isOwed: true),
            Row(name: "E debo", owes: true, isOwed: false),
        ]
        #expect(ordered(rows, limit: 10) == ["C debo", "E debo", "B me deben", "D me deben", "A al día"])
        #expect(ordered(rows, limit: 2) == ["C debo", "E debo"])
        #expect(ordered(rows, limit: 0).isEmpty)
    }

    @Test func conLosDosLadosCuentaComoDebes() {
        #expect(WidgetInsightsLogic.groupSide(owes: true, isOwed: true) == .iOwe)
        #expect(WidgetInsightsLogic.groupSide(owes: false, isOwed: true) == .owedToMe)
        #expect(WidgetInsightsLogic.groupSide(owes: false, isOwed: false) == .settled)
    }
}

// MARK: - Refresco

@MainActor
@Suite("Widget de Grupos · cuándo se rehace la foto")
struct WidgetGroupsRefreshLogicTests {

    private let a = WidgetGroupsSummary(iOwe: [WidgetGroupAmount(currencyCode: "PEN", amount: 50)], owedToMe: [],
                                        activeGroupCount: 1, groups: [])
    private let b = WidgetGroupsSummary(iOwe: [WidgetGroupAmount(currencyCode: "PEN", amount: 70)], owedToMe: [],
                                        activeGroupCount: 1, groups: [])

    @Test func tabla() {
        // Cambió ⇒ se rehace.
        #expect(WidgetGroupsRefreshLogic.needsRebuild(published: a, current: b))
        // Tras retirar la foto («Vaciar datos» conserva los grupos) ⇒ el primer cambio la rehace.
        #expect(WidgetGroupsRefreshLogic.needsRebuild(published: nil, current: a))
        // Igual ⇒ no (un guardado personal ya la rehízo).
        #expect(!WidgetGroupsRefreshLogic.needsRebuild(published: a, current: a))
        // No se pudo leer ⇒ no (no borra lo que el widget ya enseña).
        #expect(!WidgetGroupsRefreshLogic.needsRebuild(published: a, current: nil))
    }

    @Test func unaFotoEscritaDespuesDeLaPeticionLaCubre() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        // Foto después de la petición ⇒ cubierta (no se recalcula).
        #expect(WidgetGroupsRefreshLogic.alreadyCovered(requestedAt: t0, publishedAt: t0.addingTimeInterval(0.1)))
        // Petición después de la foto (un cambio de grupo durante la espera) ⇒ se comprueba.
        #expect(!WidgetGroupsRefreshLogic.alreadyCovered(requestedAt: t0.addingTimeInterval(0.2),
                                                          publishedAt: t0.addingTimeInterval(0.1)))
        // Sin foto o sin petición ⇒ se comprueba.
        #expect(!WidgetGroupsRefreshLogic.alreadyCovered(requestedAt: t0, publishedAt: nil))
        #expect(!WidgetGroupsRefreshLogic.alreadyCovered(requestedAt: nil, publishedAt: t0))
    }

    /// La hora que cuenta es la de la ÚLTIMA subida de `dataVersion` en la espera, no la primera.
    @Test func laPeticionGuardaLaUltimaHora() throws {
        let code = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Yala/Services/WidgetGroupsRefresh.swift"), encoding: .utf8)
        let start = try #require(code.range(of: "func requestCheck("))
        let body = String(code[start.lowerBound...].prefix(400))
        let stamp = try #require(body.range(of: "requestedAt = now"))
        let early = try #require(body.range(of: "guard pending == nil else { return }"))
        #expect(stamp.lowerBound < early.lowerBound, """
            Si la hora se apunta solo al abrir la espera, un gasto de grupo que llega tras una foto de un guardado \
            personal se da por cubierto y no llega al widget.
            """)
    }
}

// MARK: - Cableado

@Suite("Widget de Grupos · cableado (source-scan)")
struct WidgetGroupsWiringTests {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// El cuerpo de la primera función `func <firma>` del fichero (la firma hasta donde la distinga), sin comentarios.
    private func body(of name: String, in path: String) throws -> String {
        let code = try source(path)
        let start = try #require(code.range(of: "func \(name)"), "\(path) ya no declara \(name)")
        var depth = 0
        var opened = false
        var out = ""
        for ch in code[start.lowerBound...] {
            out.append(ch)
            if ch == "{" { depth += 1; opened = true }
            if ch == "}" { depth -= 1; if opened && depth == 0 { break } }
        }
        return out.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test func dataVersionPideLaComprobacion() throws {
        let code = try body(of: "incrementDataVersion(", in: "Yala/App/Models/SessionState.swift")
        #expect(code.contains("WidgetGroupsRefresh.shared.requestCheck()"), """
            Sin esto, un gasto de grupo o un pull del canal no llega al widget: los escritores de Grupos no llaman a
            `WidgetDataCache.updateCache`.
            """)
    }

    @Test func laFotoApuntaYRetiraSusGrupos() throws {
        let update = try body(of: "updateCache(", in: "Yala/Services/WidgetDataCache.swift")
        #expect(update.contains("WidgetGroupsRefresh.shared.notePublished(built.widget.groups)"))
        let gate = try #require(update.range(of: "guard !isWipeArmed"))
        let note = try #require(update.range(of: "notePublished"))
        #expect(gate.lowerBound < note.lowerBound, "Con un borrado armado no se apunta nada.")
        let clear = try body(of: "clearCache(in", in: "Yala/Services/WidgetDataCache.swift")
        #expect(clear.contains("WidgetGroupsRefresh.shared.noteCleared()"))
        let build = try body(of: "buildSnapshot(", in: "Yala/Services/WidgetDataCache.swift")
        #expect(build.contains("groups: WidgetGroupsSnapshotBuilder.build(context: context)"))
    }

    @Test func elArranqueDaYQuitaElContexto() throws {
        let code = try source("Yala/App/AppBootstrapper.swift")
        #expect(code.contains("WidgetGroupsRefresh.shared.setContext(context)"))
        #expect(code.contains("WidgetGroupsRefresh.shared.setContext(nil)"), """
            En el swap de persona: sin soltarlo, un `incrementDataVersion` rehará la foto con el contenedor que se va.
            """)
    }

    /// La copia del LECTOR no la decodifica ningún test (`YalaTests` no compila `YalaWidgets`): que siga opcional y
    /// con default lo fija este scan (regla «Un campo Codable NUEVO…» de `swiftdata-cloudkit.md`).
    @Test func elLectorDeclaraLosGruposOpcionales() throws {
        let reader = try source("YalaWidgets/Services/WidgetDataService.swift")
        #expect(reader.contains("    var groups: WidgetGroupsSummary? = nil\n"))
        let writer = try source("Yala/Services/WidgetDataCache.swift")
        #expect(writer.contains("    var groups: WidgetGroupsSummary? = nil\n"))
    }

    @Test func elWidgetEstaEnElBundleConSusDosTamanos() throws {
        let bundle = try source("YalaWidgets/YalaWidgetsBundle.swift")
        #expect(bundle.contains("GroupsWidget()"))
        let widget = try source("YalaWidgets/Widgets/GroupsWidget.swift")
        #expect(widget.contains(".supportedFamilies([.systemMedium, .systemLarge])"))
        #expect(widget.contains(".invitesToActivateFullWhenGroupsOnly()"))
        #expect(widget.contains("MonthSummaryLinks.url(\"groups/\\(group.id)\")"))
    }
}
