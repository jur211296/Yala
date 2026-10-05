//
//  RecalculationDebouncerTests.swift
//  YalaTests
//
//  El freno de 150 ms de Grupos (`RecalculationDebouncer`), probado sin reloj real y sin
//  `UIApplication.shared.applicationState`: la espera la suelta el test a mano y «la app está
//  activa» se inyecta. Así el coalescing es determinista en cualquier host.
//
//  La espera de prueba IGNORA la cancelación a propósito: es el peor caso. Con `Task.sleep` una
//  tarea cancelada sale por el `catch`; aquí llega viva al final de la espera, y lo único que le
//  impide publicar es el `guard !Task.isCancelled`. Si ese guard falta, estos tests lo ven.
//
//  Y en el mismo fichero, el cableado de los Ajustes del grupo: que su recálculo pesado cuelgue
//  del freno del detalle y no de cada `dataVersion`.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Espera controlada por el test

/// Cada `sleep` se queda esperando hasta que el test lo suelta. No mira la cancelación.
@MainActor
final class ManualDebounceSleeper {
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var waitingCount: Int { waiters.count }

    func sleep() async {
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Suelta la espera más antigua.
    func releaseOldest() {
        guard !waiters.isEmpty else { return }
        waiters.removeFirst().resume()
    }

    func releaseAll() {
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }

    /// Un debouncer con esta espera y la app dada por activa (o no).
    func makeDebouncer(isApplicationActive: Bool = true) -> RecalculationDebouncer {
        RecalculationDebouncer(
            sleep: { _ in await self.sleep() },
            isApplicationActive: { isApplicationActive }
        )
    }
}

/// Deja correr las tareas del main actor hasta que `condition` se cumpla, con techo.
@MainActor
func yieldUntil(_ condition: () -> Bool, maxYields: Int = 10_000) async {
    var yields = 0
    while !condition() && yields < maxYields {
        await Task.yield()
        yields += 1
    }
}

/// Deja correr las tareas pendientes un buen rato sin esperar nada concreto: para afirmar que
/// algo NO pasó, hay que haberle dado ocasión de pasar.
@MainActor
func drainMainActor(yields: Int = 200) async {
    for _ in 0..<yields { await Task.yield() }
}

// MARK: - El freno

@MainActor
struct RecalculationDebouncerTests {

    @Test func burstOfRequests_inTheSameTurn_publishesOnce() async {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer()
        var performed: [Bool] = []

        for _ in 0..<5 {
            debouncer.schedule(reload: true) { performed.append($0) }
        }
        // Las cinco tareas llegan a la espera (las cuatro canceladas también: la espera de prueba
        // no mira la cancelación). Control del escenario: sin esto el test pasaría sin recorrer nada.
        await yieldUntil { sleeper.waitingCount == 5 }
        #expect(sleeper.waitingCount == 5)
        #expect(performed.isEmpty)

        sleeper.releaseAll()
        await drainMainActor()

        #expect(performed == [true])
    }

    @Test func burstSpreadAcrossTheWindow_publishesOnce() async {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer()
        var performed: [Bool] = []

        // Cada petición llega cuando la anterior YA está esperando: la ráfaga de un pull que aplica
        // páginas una tras otra, no cinco llamadas en el mismo turno.
        for request in 1...5 {
            debouncer.schedule(reload: true) { performed.append($0) }
            await yieldUntil { sleeper.waitingCount == request }
            #expect(sleeper.waitingCount == request)
        }

        sleeper.releaseAll()
        await drainMainActor()

        #expect(performed == [true])
    }

    @Test func staleTask_thatFinishesWaitingAfterItsReplacement_doesNotPublish() async {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer()
        var performed: [String] = []

        debouncer.schedule(reload: true) { _ in performed.append("vieja") }
        await yieldUntil { sleeper.waitingCount == 1 }
        debouncer.schedule(reload: true) { _ in performed.append("nueva") }
        await yieldUntil { sleeper.waitingCount == 2 }
        #expect(sleeper.waitingCount == 2)

        // La vieja termina de esperar DESPUÉS de que la nueva la sustituyera: no publica.
        sleeper.releaseOldest()
        await drainMainActor()
        #expect(performed.isEmpty)

        sleeper.releaseOldest()
        await drainMainActor()
        #expect(performed == ["nueva"])
    }

    @Test func reloadRequestedInTheWindow_survivesALaterCalcOnlyRequest() async {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer()
        var performed: [Bool] = []

        debouncer.schedule(reload: true) { performed.append($0) }
        debouncer.schedule(reload: false) { performed.append($0) }
        await yieldUntil { sleeper.waitingCount == 2 }
        sleeper.releaseAll()
        await drainMainActor()

        #expect(performed == [true])
    }

    @Test func calcOnlyRequest_doesNotReload() async {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer()
        var performed: [Bool] = []

        debouncer.schedule(reload: false) { performed.append($0) }
        await yieldUntil { sleeper.waitingCount == 1 }
        sleeper.releaseAll()
        await drainMainActor()

        #expect(performed == [false])
    }

    @Test func cancel_beforeTheWaitEnds_doesNotPublish() async {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer()
        var performed: [Bool] = []

        debouncer.schedule(reload: true) { performed.append($0) }
        await yieldUntil { sleeper.waitingCount == 1 }
        #expect(sleeper.waitingCount == 1)

        debouncer.cancel()
        sleeper.releaseAll()
        await drainMainActor()

        #expect(performed.isEmpty)
    }

    @Test func goingToBackground_dropsThePendingRecalculation_andItsReload() async {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer()
        var performed: [Bool] = []

        debouncer.schedule(reload: true) { performed.append($0) }
        await yieldUntil { sleeper.waitingCount == 1 }
        debouncer.setBackground(true)
        sleeper.releaseAll()
        await drainMainActor()
        #expect(performed.isEmpty)

        // En segundo plano no se programa nada.
        debouncer.schedule(reload: true) { performed.append($0) }
        await drainMainActor()
        #expect(sleeper.waitingCount == 0)
        #expect(performed.isEmpty)

        // De vuelta, el reload que se pidió antes de irse no se arrastra: lo que pide la vuelta manda.
        debouncer.setBackground(false)
        debouncer.schedule(reload: false) { performed.append($0) }
        await yieldUntil { sleeper.waitingCount == 1 }
        sleeper.releaseAll()
        await drainMainActor()
        #expect(performed == [false])
    }

    @Test func inactiveApp_ignoresRequests() async {
        let sleeper = ManualDebounceSleeper()
        let debouncer = sleeper.makeDebouncer(isApplicationActive: false)
        var performed: [Bool] = []

        debouncer.schedule(reload: true) { performed.append($0) }
        await drainMainActor()

        #expect(sleeper.waitingCount == 0)
        #expect(performed.isEmpty)
    }

    /// Con la espera de verdad: lo que cambia respecto a la de prueba es que la tarea cancelada
    /// sale por el `catch` de `Task.sleep`. El resultado tiene que ser el mismo.
    @Test func realSleep_burstPublishesOnce() async throws {
        let debouncer = RecalculationDebouncer(
            delay: .milliseconds(20),
            isApplicationActive: { true }
        )
        var performed = 0

        for _ in 0..<5 {
            debouncer.schedule(reload: true) { _ in performed += 1 }
        }
        try await Task.sleep(for: .milliseconds(300))

        #expect(performed == 1)
    }
}

// MARK: - El cableado de los Ajustes del grupo

/// `GroupSettingsView` es una vista y su recálculo vive en ella, así que el cable se fija leyendo
/// el código. Lo que se fija es el CUERPO entero de cada reacción, no la presencia de un nombre:
/// un `contains` dejaría pasar que el recálculo volviera al `onChange(dataVersion)` junto al reset.
struct GroupSettingsRecomputeWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Solo líneas de código: documentar el invariante no puede ponerlo en rojo.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Lo que va entre la primera `{` tras `marker` y su `}`, normalizado: líneas trimmeadas, sin
    /// vacías, unidas por un espacio.
    private static func block(after marker: String, in code: String) throws -> String {
        let start = try #require(code.range(of: marker), "no está: \(marker)")
        let afterMarker = code[start.upperBound...]
        let open = try #require(afterMarker.firstIndex(of: "{"), "sin llave tras: \(marker)")
        var depth = 0
        var out = ""
        for ch in afterMarker[afterMarker.index(after: open)...] {
            if ch == "{" { depth += 1 }
            if ch == "}" {
                if depth == 0 { break }
                depth -= 1
            }
            out.append(ch)
        }
        return out.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let settingsPath = "Yala/App/Views/Groups/GroupSettingsView.swift"

    @Test func dataVersion_onlyResetsTheServerRefusal_withoutRecomputing() throws {
        let code = Self.codeOnly(try Self.source(Self.settingsPath))

        // Se cuenta el TOKEN y no la grafía del `onChange`: un `.task(id:)` o un `onChange(..., initial:)`
        // colgado de `dataVersion` también contaría como segunda reacción.
        let reactions = code.components(separatedBy: "sessionState.dataVersion").count - 1
        #expect(reactions == 1)

        let body = try Self.block(after: ".onChange(of: sessionState.dataVersion)", in: code)
        #expect(body == "_, _ in transferRefusedByServer = false")
    }

    @Test func recompute_hangsFromTheDetailBrake() throws {
        let code = Self.codeOnly(try Self.source(Self.settingsPath))

        let reactions = code.components(separatedBy: "coalescedReloadRevision").count - 1
        #expect(reactions == 1)

        let body = try Self.block(after: ".onChange(of: viewModel.coalescedReloadRevision)", in: code)
        #expect(body == "_, _ in recomputeAfterRemoteChange()")

        let recompute = try Self.block(after: "private func recomputeAfterRemoteChange()", in: code)
        #expect(recompute == "recomputeOwnerExit() recomputeShareableSummary()")
    }

    /// Abrir los Ajustes sigue calculando en el acto: el freno es solo para lo que llega de fuera.
    @Test func openingTheSettings_stillComputesImmediately() throws {
        let code = Self.codeOnly(try Self.source(Self.settingsPath))
        let disappear = try #require(code.range(of: ".onDisappear { saveIdentity() }"))
        let rest = code[disappear.upperBound...].drop { $0.isWhitespace }
        #expect(rest.hasPrefix(".onAppear {"))
        let body = try Self.block(after: ".onAppear", in: String(rest))
        #expect(body == "recomputeOwnerExit() recomputeShareableSummary()")
    }

    /// Los Ajustes no programan el recálculo: lo programa el detalle, que es quien los presenta. Si
    /// el detalle dejara de hacerlo, los Ajustes no volverían a recalcular ante cambios remotos. Y
    /// tiene que ir DETRÁS del dismiss-first, que no programa nada sobre una vista que se cierra.
    @Test func theDetail_schedulesTheRecalculation_afterDecidingNotToDismiss() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Groups/GroupDetailView.swift"))
        let body = try Self.block(after: ".onChange(of: sessionState.dataVersion)", in: code)

        let dismiss = try #require(body.range(of: "GroupDetailDismissDecision.shouldDismiss("))
        let schedule = try #require(body.range(of: "viewModel.reloadAndRecalculate()"))
        #expect(dismiss.lowerBound < schedule.lowerBound)
        #expect(body.hasSuffix("close() return } viewModel.reloadAndRecalculate()"))

        let settings = code.components(separatedBy: "GroupSettingsView(group: group, viewModel: viewModel)").count - 1
        #expect(settings == 1)
    }

    /// Las dos VMs mandan el cambio remoto al freno y a nada más: un `recalculate()` en el acto al lado
    /// daría N recálculos por ráfaga con el resultado final idéntico, y ningún test de resultado lo vería.
    @Test func bothViewModels_sendRemoteChangesOnlyThroughTheBrake() throws {
        for path in ["Yala/App/ViewModels/GroupsViewModel.swift", "Yala/App/ViewModels/GroupDetailViewModel.swift"] {
            let code = Self.codeOnly(try Self.source(path))
            let body = try Self.block(after: "func reloadAndRecalculate()", in: code)
            #expect(body == "scheduleRecalculation(reload: true)", "\(path)")
            let schedule = try Self.block(after: "private func scheduleRecalculation(reload: Bool)", in: code)
            #expect(schedule.hasPrefix("debouncer.schedule(reload: reload) { [weak self] shouldReload in"), "\(path)")
        }
    }

    /// Los tests del freno inyectan su propio «¿está la app activa?», así que el valor de verdad no lo
    /// recorre ninguno. Antes vivía en las dos VMs; hoy solo aquí, y esto es lo que lo vigila.
    @Test func theRealDefaults_areThe150msWait_andTheApplicationState() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/ViewModels/RecalculationDebouncer.swift"))
        // La firma acaba en `) {`, no en la primera llave: el default de `sleep` ya lleva una.
        let initArgs = try #require(code.range(of: "init(")).upperBound
        let signatureEnd = try #require(code.range(of: ") {", range: initArgs..<code.endIndex)).lowerBound
        let signature = String(code[initArgs..<signatureEnd])
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        #expect(signature.contains("delay: Duration = .milliseconds(150),"))
        #expect(signature.contains("sleep: @escaping Sleep = { try await Task.sleep(for: $0) },"))
        #expect(signature.contains("isApplicationActive: (@MainActor () -> Bool)? = nil"))
        #expect(code.contains("self.isApplicationActive = isApplicationActive ?? { UIApplication.shared.applicationState == .active }"))
    }
}
