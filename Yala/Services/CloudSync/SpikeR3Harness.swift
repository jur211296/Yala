//
//  SpikeR3Harness.swift
//  Yala
//
//  Harness DEBUG del SPIKE R3 (relanzamiento cero, [[MODO-NUBE-CHIPS-RELAUNCH-CERO]]). **NO es código
//  de producción**: vive entero bajo `#if DEBUG`, no lo llama ni un solo camino de la app, y sus dos
//  superficies son (a) la card `spikeR3Card` de `CloudSyncDebugView`, gateada por el launch arg
//  `-spike-r3`, y (b) `YalaTests/Spikes/SpikeR3ContainerReleaseTests.swift`.
//
//  ## DEUDA EXPLÍCITA: este fichero SE BORRA AL CERRAR R4 (no al cerrar R3)
//
//  Sobrevive a R3 a propósito, y por dos razones que conviene no perder: el eje 3 lo necesita vivo en
//  device hasta que el owner lo corra, y **R4 lo necesita como instrumento** — su fase de «quiesce +
//  release verificado» se diseña contra estas mismas mediciones (`openDescriptorCountForSpikeStore` es
//  literalmente el criterio que R4(b) tiene que implementar sobre el container REAL). Al cerrar R4 se
//  van los tres: este fichero, la card `spikeR3Card` + su `@State` en `CloudSyncDebugView.swift`, y
//  `YalaTests/Spikes/SpikeR3ContainerReleaseTests.swift` (sin harness no hay instrumento que testear).
//
//  ## Qué responde R3 (spec §1.9/§1.10/§1.11)
//
//  El spike previo (S1–S4, §1.9) midió que SwiftData **deja convivir dos containers sobre el mismo
//  archivo sin lanzar** y que el viejo sigue leyendo y escribiendo. Ese estado ya produjo una app «en
//  cero» en device (bug `Bugs/ok_applepay-shortcut-ios27-warm-launch-datos-vacios.md`, TN3163/TN3164,
//  FB13278891), y su lección más dura es que **poner `.none` al segundo container NO bastó**: la cura
//  fue ELIMINAR la segunda conexión. ⇒ un remount in-process solo es seguro si el container viejo
//  **muere**, y de eso no había ninguna medición.
//
//   - **Eje 1 · release verificado.** ¿Muere el `ModelContainer` al soltar la última referencia, y en
//     cuánto? Con dos instrumentos, no uno: el `weak` sentinel (¿murió el objeto?) y el trío de
//     archivos SQLite (¿se cerró la CONEXIÓN? — WAL: al cerrarse la última conexión SQLite hace
//     checkpoint y BORRA `-wal`/`-shm`). El sentinel es NECESARIO y no suficiente: el objeto Swift
//     puede morir con la pila de Core Data viva.
//   - **Eje 2 · montar-tras-muerte.** Con la muerte verificada, ¿el container nuevo lee el corpus
//     COMPLETO sobre el mismo archivo?
//   - **Eje 3 · el mismo ciclo con mirror `.private` VIVO.** DEVICE-ONLY (el simulador no tiene cuenta
//     iCloud) — `runMirrorAxis()`.
//   - **Eje 4 · wipe in-process.** (4a) release verificado → borrar los 3 archivos → remontar ⇒ store
//     vacío y escribible. (4b) **control negativo**: el mismo wipe con el container VIVO, que es el
//     modo de fallo del §1.10 — se mide qué LEE y qué ESCRIBE el superviviente.
//
//  ## Reglas de la casa que aplican aquí
//
//   - **NUNCA `try?` que silencia**: cada error se captura y se IMPRIME verbatim — mostrar el error ES
//     el punto de un spike.
//   - **Todo cero necesita su control positivo.** La auditoría R1(c) del chip R1 gastó una vuelta con un
//     instrumento cuyo cero no medía nada. Aquí: el trío de archivos se lee con el container VIVO antes
//     de leerlo muerto, el eje 3 declara la medición VOID si no llega ni un evento del mirror, y el
//     sentinel se comprueba primero con un `ModelContext` retenido a propósito (si ahí muriera, el
//     instrumento estaría roto).
//   - **Cero contacto con los datos reales.** Store propio (`YalaSpikeR3`), modelo propio
//     (`SpikeR3Row`), y el borrado de archivos comprueba el prefijo del nombre antes de tocar nada.
//

#if DEBUG
import CoreData
import Foundation
import SwiftData

// MARK: - Fila del spike (DEBUG-only)

/// Fila del store del spike R3. **No entra en ningún `Schema` de producción** — solo en
/// `SpikeR3Harness.spikeSchema`. Compatible con CloudKit (defaults obligatorios, sin `.unique`, sin
/// relaciones) porque el eje 3 la monta con `cloudKitDatabase: .private`.
@Model
final class SpikeR3Row {
    var marker: String = ""
    var index: Int = 0

    init(marker: String, index: Int) {
        self.marker = marker
        self.index = index
    }
}

// MARK: - Harness

@MainActor
@Observable
final class SpikeR3Harness {

    // MARK: Gating

    /// Launch arg que revela la card en `CloudSyncDebugView`. Sin él, el harness es inalcanzable desde
    /// la UI (molde del `-spike-s6-mirror-off` del spike S6).
    static let launchArgument = "-spike-r3"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    // MARK: Store del spike

    /// Nombre DEDICADO. Jamás `databaseName`: el spike no toca el store real ni con `.none`.
    static let storeName = "YalaSpikeR3"

    static var spikeSchema: Schema { Schema([SpikeR3Row.self]) }

    /// URL derivada de una `ModelConfiguration` efímera (patrón `deleteStoreFiles` de
    /// `SwiftDataConfiguration`).
    static var storeURL: URL {
        ModelConfiguration(storeName, schema: spikeSchema, cloudKitDatabase: .none).url
    }

    private static func localConfiguration() -> ModelConfiguration {
        ModelConfiguration(storeName, schema: spikeSchema, cloudKitDatabase: .none)
    }

    private static func mirrorConfiguration() -> ModelConfiguration {
        ModelConfiguration(storeName, schema: spikeSchema,
                           cloudKitDatabase: .private(SwiftDataConfiguration.cloudKitContainerIdentifier))
    }

    // MARK: Log

    private(set) var log: String = ""
    var isWorking = false

    func clearLog() { log = "" }

    private func line(_ text: String) {
        let stamp = Self.stamp.string(from: Date())
        let entry = "[\(stamp)] \(text)"
        log += entry + "\n"
        print("[R3] " + entry)
    }

    private func section(_ title: String) {
        let entry = "\n──────── \(title) ────────"
        log += entry + "\n"
        print("[R3]" + entry)
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    // MARK: - Archivos del store

    struct FileTrio: Equatable {
        var base = false
        var wal = false
        var shm = false

        var description: String { "base=\(base ? 1 : 0) wal=\(wal ? 1 : 0) shm=\(shm ? 1 : 0)" }
    }

    static func fileTrio() -> FileTrio {
        let path = storeURL.path
        let fm = FileManager.default
        return FileTrio(base: fm.fileExists(atPath: path),
                        wal: fm.fileExists(atPath: path + "-wal"),
                        shm: fm.fileExists(atPath: path + "-shm"))
    }

    /// **El instrumento que de verdad responde «¿se cerró la CONEXIÓN?»**: cuántos descriptores abiertos
    /// de ESTE proceso apuntan al archivo del store (base, `-wal` o `-shm`).
    ///
    /// Sustituye al trío de archivos, que en la primera corrida resultó NO discriminar: `-wal`/`-shm`
    /// siguen en disco tras la muerte del objeto porque **Core Data activa el WAL persistente**
    /// (`SQLITE_FCNTL_PERSIST_WAL`) ⇒ su presencia no dice nada del estado de la conexión. El trío se
    /// conserva en el log solo como contexto (y para ver si el store se RECREA).
    ///
    /// `fcntl(F_GETPATH)` sobre cada descriptor es la lectura directa: 0 descriptores = la pila de Core
    /// Data soltó el archivo de verdad; >0 con el objeto ya muerto sería justo el estado que R4 no puede
    /// permitirse (objeto muerto, conexión viva).
    static func openDescriptorCountForSpikeStore() -> Int {
        let prefix = storeURL.path
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        var count = 0
        // 1024 cubre de sobra los descriptores de un proceso de app; `_SC_OPEN_MAX` puede ser enorme.
        for descriptor in Int32(0)..<Int32(1024) {
            guard fcntl(descriptor, F_GETPATH, &buffer) == 0 else { continue }
            if String(cString: buffer).hasPrefix(prefix) { count += 1 }
        }
        return count
    }

    /// Borra los 3 archivos del store DEL SPIKE. El guard del prefijo no es ceremonia: es lo único que
    /// separa este harness de un wipe de los datos reales si alguien cambia `storeURL`.
    @discardableResult
    static func deleteSpikeStoreFiles() -> [String] {
        var problems: [String] = []
        let url = storeURL
        guard url.lastPathComponent.hasPrefix(storeName) else {
            return ["ABORTADO: la URL del spike (\(url.lastPathComponent)) no empieza por \(storeName)"]
        }
        for path in [url.path, url.path + "-wal", url.path + "-shm"] {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch let error as NSError
                where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                // Ausente — no-op.
            } catch {
                problems.append("\((path as NSString).lastPathComponent): \(error)")
            }
        }
        return problems
    }

    // MARK: - Espera de la muerte

    /// Poll de 10 ms (nunca un `sleep` largo: la regla de tests prohíbe >0.5 s) hasta `timeoutMs`.
    /// Devuelve los ms transcurridos, o `nil` si el sentinel seguía vivo al agotarse.
    ///
    /// Una CANCELACIÓN también devuelve `nil` (= «no se le vio morir»), que es el sesgo seguro: hace
    /// abortar el wipe del eje 4a en vez de ejecutarlo sobre un release no verificado.
    private func awaitDeath(timeoutMs: Int, sentinelIsAlive: () -> Bool) async -> Int? {
        var elapsed = 0
        if !sentinelIsAlive() { return 0 }
        while elapsed < timeoutMs {
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {
                return nil
            }
            elapsed += 10
            if !sentinelIsAlive() { return elapsed }
        }
        return nil
    }

    // MARK: - EJES LOCALES (1 · 2 · 4) — simulador o device

    /// Corre los ejes que NO necesitan cuenta iCloud, sobre `cloudKitDatabase: .none`.
    /// Devuelve el log completo de la corrida (además de acumularlo en `log`).
    @discardableResult
    func runLocalAxes(rowCount: Int = 25) async -> String {
        isWorking = true
        defer { isWorking = false }

        section("R3 · ejes locales (1 · 2 · 4) — cloudKitDatabase: .none")
        line("store=\(Self.storeURL.lastPathComponent) dir=\(Self.storeURL.deletingLastPathComponent().lastPathComponent)")
        let leftovers = Self.deleteSpikeStoreFiles()
        if !leftovers.isEmpty { line("limpieza previa con problemas: \(leftovers.joined(separator: " · "))") }
        line("trio inicial \(Self.fileTrio().description)")

        await axis1AndAxis2(rowCount: rowCount)
        await axis1cRetainedModelObject(rowCount: rowCount)
        await axis4aWipeAfterVerifiedRelease(rowCount: rowCount)
        await axis4bWipeWithLiveContainer(rowCount: rowCount)

        section("FIN ejes locales")
        Self.deleteSpikeStoreFiles()
        return log
    }

    // MARK: Eje 1 + Eje 2

    func axis1AndAxis2(rowCount: Int) async {
        section("EJE 1 · ¿muere el container al soltarlo? + EJE 2 · montar-tras-muerte")

        weak var sentinel: ModelContainer?
        var retainedContext: ModelContext?
        var trioAlive = FileTrio()
        let marker = "A1-\(UUID().uuidString.prefix(8))"

        do {
            try autoreleasepool {
                let container = try ModelContainer(for: Self.spikeSchema,
                                                   configurations: Self.localConfiguration())
                sentinel = container
                let context = ModelContext(container)
                for index in 0..<rowCount {
                    context.insert(SpikeR3Row(marker: marker, index: index))
                }
                try context.save()
                trioAlive = Self.fileTrio()
                // El contexto ESCAPA del scope a propósito: es el control positivo del sentinel.
                retainedContext = context
            }
        } catch {
            line("FALLÓ el montaje inicial: \(error)")
            return
        }

        let fdsAlive = Self.openDescriptorCountForSpikeStore()
        line("control positivo · con el container VIVO tras save: trío \(trioAlive.description) · descriptores abiertos sobre el store = \(fdsAlive)")
        if fdsAlive == 0 {
            line("⚠️ CONTROL ROTO: cero descriptores con la conexión abierta ⇒ el instrumento de fds no mide nada aquí; no concluir de su cero")
        }

        // 1a — control negativo del sentinel: con un ModelContext vivo el container NO debe morir.
        let diedWithContext = await awaitDeath(timeoutMs: 500) { sentinel != nil }
        if let ms = diedWithContext {
            line("⚠️ CONTROL ROTO / hallazgo: con un `ModelContext` retenido el container MURIÓ en \(ms) ms ⇒ un contexto NO retiene el container")
        } else {
            line("control negativo OK · con un `ModelContext` retenido el container sigue VIVO tras 500 ms ⇒ el contexto SÍ retiene (y el sentinel discrimina)")
        }

        // 1b — soltar de verdad.
        line("soltando la última referencia (el contexto de control seguía retenido: \(retainedContext != nil))")
        let releasedAt = Date()
        retainedContext = nil
        let died = await awaitDeath(timeoutMs: 5000) { sentinel != nil }
        if let ms = died {
            let wall = Int(Date().timeIntervalSince(releasedAt) * 1000)
            line("EJE 1 ✅ el container MURIÓ en \(ms) ms (wall \(wall) ms) tras soltar la última referencia")
        } else {
            line("EJE 1 ❌ el container SIGUE VIVO 5000 ms después de soltar la última referencia")
        }

        let trioDead = Self.fileTrio()
        let fdsDead = Self.openDescriptorCountForSpikeStore()
        line("tras la muerte del objeto: trío \(trioDead.description) (vivo era \(trioAlive.description)) · descriptores = \(fdsDead) (vivo eran \(fdsAlive))")
        if fdsAlive > 0 && fdsDead == 0 {
            line("EJE 1 · CONEXIÓN CERRADA — el segundo instrumento (descriptores) confirma que la pila de Core Data soltó el archivo, no solo que el objeto Swift murió")
        } else if fdsDead > 0 {
            line("EJE 1 ❌ el objeto murió pero quedan \(fdsDead) descriptores abiertos sobre el store ⇒ conexión VIVA: el `weak` sentinel NO basta como release verificado")
        }
        if trioDead.wal {
            line("nota de instrumento: -wal/-shm siguen en disco CON cero descriptores abiertos (esto es lo MEDIDO; la causa —el WAL persistente que activa Core Data— es INFERIDA) ⇒ el trío NO sirve para decidir si la conexión se cerró; el que decide es el conteo de descriptores")
        }

        // EJE 2 — montar-tras-muerte y leer completo.
        guard died != nil else {
            line("EJE 2 SALTADO: sin muerte verificada, montar el segundo container sería justamente el estado del §1.10")
            return
        }
        do {
            var count = -1
            var wrongMarker = -1
            var indexSum = -1
            try autoreleasepool {
                let container = try ModelContainer(for: Self.spikeSchema,
                                                   configurations: Self.localConfiguration())
                let context = ModelContext(container)
                let rows = try context.fetch(FetchDescriptor<SpikeR3Row>())
                count = rows.count
                wrongMarker = rows.filter { $0.marker != marker }.count
                indexSum = rows.reduce(0) { $0 + $1.index }
            }
            let expectedSum = (0..<rowCount).reduce(0, +)
            let ok = count == rowCount && wrongMarker == 0 && indexSum == expectedSum
            line("EJE 2 \(ok ? "✅" : "❌") remount tras la muerte: filas=\(count)/\(rowCount) markerAjeno=\(wrongMarker) sumaIndices=\(indexSum)/\(expectedSum)")
        } catch {
            line("EJE 2 ❌ el remount lanzó: \(error)")
        }
    }

    // MARK: Eje 1c — ¿qué más retiene el container? (la pregunta que R4 tiene que responder por sitio)

    /// El eje 1 mide que soltar **la última referencia** mata el container. R4 tiene el problema
    /// contrario: saber **qué cuenta como referencia**, porque su lista son ~62 sitios (spec §1.11) y
    /// el compilador no comprueba ninguno. Aquí se miden los dos retenedores que NO son obvios:
    ///  - un `ModelContext` (ya medido en el eje 1 como control negativo), y
    ///  - **una fila `@Model` fetcheada** que sobreviva en un ViewModel: si retiene, soltar el container
    ///    y los contextos NO basta y el canario de R4 tiene que mirar el sentinel, no la lista.
    func axis1cRetainedModelObject(rowCount: Int) async {
        section("EJE 1c · ¿una fila @Model retenida mantiene vivo el container?")

        Self.deleteSpikeStoreFiles()
        weak var sentinel: ModelContainer?
        var retainedRow: SpikeR3Row?

        do {
            try autoreleasepool {
                let container = try ModelContainer(for: Self.spikeSchema,
                                                   configurations: Self.localConfiguration())
                sentinel = container
                let context = ModelContext(container)
                for index in 0..<rowCount { context.insert(SpikeR3Row(marker: "A1c", index: index)) }
                try context.save()
                // Solo la FILA escapa: ni el container ni el contexto.
                retainedRow = try context.fetch(FetchDescriptor<SpikeR3Row>()).first
            }
        } catch {
            line("FALLÓ el montaje: \(error)")
            return
        }

        guard retainedRow != nil else {
            line("⚠️ CONTROL ROTO: no se pudo retener ninguna fila ⇒ el eje no mide nada")
            return
        }

        let diedWithRow = await awaitDeath(timeoutMs: 1000, sentinelIsAlive: { sentinel != nil })
        let fdsWithRow = Self.openDescriptorCountForSpikeStore()
        if let ms = diedWithRow {
            line("EJE 1c · con una fila @Model retenida el container MURIÓ igual (en \(ms) ms) · descriptores \(fdsWithRow) ⇒ una fila NO retiene el container")
            let stillReadable = retainedRow?.marker
            line("EJE 1c · la fila huérfana sigue legible en memoria: marker=\(stillReadable ?? "nil") ⇒ el objeto sobrevive a su store (no falla: MIENTE en silencio)")
        } else {
            line("EJE 1c ⚠️ con una fila @Model retenida el container SIGUE VIVO tras 1000 ms · descriptores \(fdsWithRow) ⇒ **R4 tiene que soltar también las filas**, no solo containers y contextos")
        }

        retainedRow = nil
        let diedAfter = await awaitDeath(timeoutMs: 3000, sentinelIsAlive: { sentinel != nil })
        line("EJE 1c · tras soltar la fila: \(diedAfter.map { "MURIÓ en \($0) ms" } ?? "SIGUE VIVO tras 3000 ms") · descriptores \(Self.openDescriptorCountForSpikeStore())")
        Self.deleteSpikeStoreFiles()
    }

    // MARK: Eje 4a — wipe in-process CON release verificado

    func axis4aWipeAfterVerifiedRelease(rowCount: Int) async {
        section("EJE 4a · wipe in-process con release VERIFICADO")

        Self.deleteSpikeStoreFiles()
        weak var sentinel: ModelContainer?
        let marker = "A4a-\(UUID().uuidString.prefix(8))"

        do {
            try autoreleasepool {
                let container = try ModelContainer(for: Self.spikeSchema,
                                                   configurations: Self.localConfiguration())
                sentinel = container
                let context = ModelContext(container)
                for index in 0..<rowCount { context.insert(SpikeR3Row(marker: marker, index: index)) }
                try context.save()
            }
        } catch {
            line("FALLÓ el montaje: \(error)")
            return
        }

        guard let ms = await awaitDeath(timeoutMs: 5000, sentinelIsAlive: { sentinel != nil }) else {
            line("EJE 4a ❌ ABORTADO: el container no murió ⇒ el wipe NO se ejecuta (es exactamente el canario que R4 necesita)")
            return
        }
        let fdsAfterRelease = Self.openDescriptorCountForSpikeStore()
        line("release verificado en \(ms) ms · trío \(Self.fileTrio().description) · descriptores \(fdsAfterRelease)")
        guard fdsAfterRelease == 0 else {
            line("EJE 4a ❌ ABORTADO: quedan \(fdsAfterRelease) descriptores abiertos ⇒ el wipe NO se ejecuta (release verificado = sentinel nil Y cero descriptores)")
            return
        }

        let problems = Self.deleteSpikeStoreFiles()
        if problems.isEmpty {
            line("borrado de los 3 archivos: OK · trío \(Self.fileTrio().description)")
        } else {
            line("EJE 4a ⚠️ borrado con problemas: \(problems.joined(separator: " · "))")
        }

        do {
            var count = -1
            var afterWrite = -1
            try autoreleasepool {
                let container = try ModelContainer(for: Self.spikeSchema,
                                                   configurations: Self.localConfiguration())
                let context = ModelContext(container)
                count = try context.fetch(FetchDescriptor<SpikeR3Row>()).count
                context.insert(SpikeR3Row(marker: "post-wipe", index: 1))
                try context.save()
                afterWrite = try context.fetch(FetchDescriptor<SpikeR3Row>()).count
            }
            let ok = count == 0 && afterWrite == 1
            line("EJE 4a \(ok ? "✅" : "❌") store tras el wipe: filas=\(count) (esperado 0) · escribible=\(afterWrite == 1) (filas tras 1 insert=\(afterWrite))")
        } catch {
            line("EJE 4a ❌ el remount post-wipe lanzó: \(error)")
        }
    }

    // MARK: Eje 4b — control NEGATIVO: wipe con el container VIVO (el §1.10)

    /// Reproduce a propósito el estado que el bug de Apple Pay dejó en device: **dos conexiones y/o un
    /// archivo borrado bajo un container vivo**. Lo que se mide es qué LEE el superviviente — la
    /// patología no es un crash, es una app que se ve vacía y no lo dice.
    func axis4bWipeWithLiveContainer(rowCount: Int) async {
        section("EJE 4b · control NEGATIVO — wipe y segunda conexión con el container VIVO (§1.10)")

        Self.deleteSpikeStoreFiles()
        let marker = "A4b-\(UUID().uuidString.prefix(8))"
        var survivor: ModelContainer?
        var survivorContext: ModelContext?

        do {
            let container = try ModelContainer(for: Self.spikeSchema,
                                               configurations: Self.localConfiguration())
            let context = ModelContext(container)
            for index in 0..<rowCount { context.insert(SpikeR3Row(marker: marker, index: index)) }
            try context.save()
            let seeded = try context.fetch(FetchDescriptor<SpikeR3Row>()).count
            survivor = container
            survivorContext = context
            line("montado y sembrado: filas=\(seeded) · trío \(Self.fileTrio().description)")
        } catch {
            line("FALLÓ el montaje: \(error)")
            return
        }

        // (i) borrar los archivos DEBAJO del container vivo.
        let problems = Self.deleteSpikeStoreFiles()
        line("borrado bajo el container VIVO: \(problems.isEmpty ? "OK" : problems.joined(separator: " · ")) · trío \(Self.fileTrio().description) · descriptores \(Self.openDescriptorCountForSpikeStore())")

        // (ii) ¿qué LEE el superviviente?
        if let context = survivorContext {
            do {
                let count = try context.fetch(FetchDescriptor<SpikeR3Row>()).count
                line("(ii) el superviviente LEE \(count) filas tras el borrado (sembradas \(rowCount)) — si es \(rowCount), está leyendo por su conexión abierta a un archivo que ya no está en disco")
            } catch {
                line("(ii) el fetch del superviviente LANZÓ: \(error)")
            }
            // (iii) ¿puede ESCRIBIR? ¿recrea el archivo?
            do {
                context.insert(SpikeR3Row(marker: "zombie-write", index: 999))
                try context.save()
                line("(iii) el superviviente ESCRIBIÓ sin lanzar · trío \(Self.fileTrio().description) — si el base vuelve a 1, el ZOMBIE ha RESUCITADO el archivo que el wipe borró")
            } catch {
                line("(iii) el save del superviviente lanzó: \(error) · trío \(Self.fileTrio().description)")
            }
        }

        // (iv) segunda conexión sobre el mismo path CON el viejo vivo (S2/S4 bajo wipe).
        do {
            var newCount = -1
            try autoreleasepool {
                let second = try ModelContainer(for: Self.spikeSchema,
                                                configurations: Self.localConfiguration())
                let secondContext = ModelContext(second)
                newCount = try secondContext.fetch(FetchDescriptor<SpikeR3Row>()).count
                secondContext.insert(SpikeR3Row(marker: "second-connection", index: 1))
                try secondContext.save()
            }
            line("(iv) segunda conexión con el viejo VIVO: montó sin lanzar, leyó \(newCount) filas y escribió")
            if let context = survivorContext {
                do {
                    let seenByOld = try context.fetch(FetchDescriptor<SpikeR3Row>()).count
                    line("(iv) el VIEJO ve ahora \(seenByOld) filas — divergencia entre las dos conexiones si no coincide con lo que escribió la nueva")
                } catch {
                    line("(iv) el fetch del viejo tras la segunda conexión LANZÓ: \(error)")
                }
            }
        } catch {
            line("(iv) la segunda conexión LANZÓ: \(error)")
        }

        line("(v) el container viejo seguía retenido durante todo el eje: \(survivor != nil)")
        survivorContext = nil
        survivor = nil
        Self.deleteSpikeStoreFiles()
        line("(v) limpieza final · trío \(Self.fileTrio().description)")
    }

    // MARK: - EJE 3 (DEVICE-ONLY) — el mismo ciclo con mirror `.private` VIVO

    /// **Device-only.** Monta el store del spike con `cloudKitDatabase: .private` sobre el container
    /// CloudKit de ESTE build, mide si el `ModelContainer` muere al soltarlo y si el mirror deja de dar
    /// señales de vida.
    ///
    /// **NO inserta ni una fila a propósito**: sin export, el record type del spike NUNCA se crea en el
    /// schema de CloudKit y no se sube nada a la cuenta del owner. Lo que se mide es el CICLO DE VIDA
    /// del container, no el tráfico.
    ///
    /// Dos pasadas, porque la respuesta puede depender de si hay trabajo en vuelo:
    ///  - **A · release en vuelo**: soltar inmediatamente después de montar, con el setup/import del
    ///    mirror todavía corriendo.
    ///  - **B · release tras actividad**: esperar a ver eventos del mirror y soltar entonces.
    @discardableResult
    func runMirrorAxis() async -> String {
        isWorking = true
        defer { isWorking = false }

        section("R3 · EJE 3 (DEVICE) — cloudKitDatabase: .private")
        line("container CloudKit = \(SwiftDataConfiguration.cloudKitContainerIdentifier)")
        guard SwiftDataConfiguration.isICloudAvailable() else {
            line("❌ ABORTADO: no hay cuenta iCloud en este dispositivo (`ubiquityIdentityToken == nil`). En el simulador este eje NO se puede medir — es la razón de que sea device-only.")
            return log
        }

        let observer = MirrorEventObserver()
        observer.start()
        defer { observer.stop() }

        // ---- Pasada A: soltar EN VUELO -------------------------------------------------
        Self.deleteSpikeStoreFiles()
        observer.reset()
        weak var sentinelA: ModelContainer?
        do {
            try autoreleasepool {
                let container = try ModelContainer(for: Self.spikeSchema,
                                                   configurations: Self.mirrorConfiguration())
                sentinelA = container
                // Un solo toque al contexto para forzar que la pila se levante de verdad.
                _ = try ModelContext(container).fetch(FetchDescriptor<SpikeR3Row>()).count
            }
        } catch {
            line("A ❌ el montaje `.private` LANZÓ: \(error)")
            return log
        }
        let diedA = await awaitDeath(timeoutMs: 15000, sentinelIsAlive: { sentinelA != nil })
        line("A · release EN VUELO: \(diedA.map { "MURIÓ en \($0) ms" } ?? "SIGUE VIVO tras 15 000 ms") · descriptores tras soltar = \(Self.openDescriptorCountForSpikeStore()) · eventos del mirror durante la pasada: \(observer.summary()) · trío \(Self.fileTrio().description)")

        // ---- Pasada B: soltar TRAS actividad del mirror ---------------------------------
        Self.deleteSpikeStoreFiles()
        observer.reset()
        weak var sentinelB: ModelContainer?
        var contextB: ModelContext?
        do {
            let container = try ModelContainer(for: Self.spikeSchema,
                                               configurations: Self.mirrorConfiguration())
            sentinelB = container
            contextB = ModelContext(container)
            _ = try contextB?.fetch(FetchDescriptor<SpikeR3Row>()).count
        } catch {
            line("B ❌ el montaje `.private` LANZÓ: \(error)")
            return log
        }

        // Control positivo: sin eventos, la medición NO significa nada (lección de R1(c)).
        var waitedMs = 0
        while observer.total == 0 && waitedMs < 30000 {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { break }
            waitedMs += 250
        }
        let aliveSummary = observer.summary()
        let fdsAliveB = Self.openDescriptorCountForSpikeStore()
        if observer.total == 0 {
            line("B ⚠️ CONTROL POSITIVO FALLIDO: cero eventos de `NSPersistentCloudKitContainer` en 30 s ⇒ el mirror no dio señales de vida y la medición de este eje es VOID (mismo error de instrumento que la primera sonda de R1(c)). Anotar y NO concluir.")
        } else {
            line("B · control positivo OK — el mirror VIVE: \(aliveSummary) (esperados \(waitedMs) ms) · trío \(Self.fileTrio().description) · descriptores \(fdsAliveB)")
        }
        if let firstError = observer.firstErrorDescription {
            line("B · primer error reportado por el mirror: \(firstError)")
        }

        let eventsBeforeRelease = observer.total
        contextB = nil
        let diedB = await awaitDeath(timeoutMs: 15000, sentinelIsAlive: { sentinelB != nil })
        let fdsAfterB = Self.openDescriptorCountForSpikeStore()
        line("B · release TRAS actividad: \(diedB.map { "MURIÓ en \($0) ms" } ?? "SIGUE VIVO tras 15 000 ms") · descriptores \(fdsAfterB) (vivos eran \(fdsAliveB)) · trío \(Self.fileTrio().description)")
        if fdsAliveB > 0 && fdsAfterB == 0 {
            line("B · VEREDICTO del eje 3: con mirror `.private` VIVO el release cierra también la CONEXIÓN (cero descriptores) ⇒ verde")
        } else if fdsAfterB > 0 {
            line("B ❌ VEREDICTO del eje 3: quedan \(fdsAfterB) descriptores abiertos tras soltar ⇒ con mirror vivo el release NO es verificable con un `weak` sentinel — C se queda acotada a transiciones sin mirror, que es como nace")
        }

        // ¿Sigue emitiendo el mirror después de soltar?
        do {
            try await Task.sleep(for: .seconds(10))
        } catch {
            line("B ⚠️ la ventana de observación post-release se CANCELÓ (\(error)) ⇒ el conteo de abajo es de menos de 10 s y no se puede leer como silencio")
        }
        let after = observer.total - eventsBeforeRelease
        line("B · eventos del mirror en los 10 s POSTERIORES al release: \(after) \(after == 0 ? "(silencio — señal DÉBIL: un mirror sin datos también calla estando vivo; el conteo de descriptores es el que decide)" : "⇒ el mirror SIGUE trabajando tras soltar el container")")
        line("B · resumen final de eventos: \(observer.summary())")
        line("B · descriptores 10 s después: \(Self.openDescriptorCountForSpikeStore())")

        Self.deleteSpikeStoreFiles()
        section("FIN eje 3")
        return log
    }

    // MARK: - Observador de eventos del mirror

    /// Instrumento del eje 3, y el ÚNICO que la auditoría R1(c) encontró que discrimina de verdad entre
    /// «hay mirror adjunto» y «no lo hay»: los eventos de `NSPersistentCloudKitContainer`.
    @MainActor
    final class MirrorEventObserver {
        private var token: NSObjectProtocol?
        private(set) var counts: [String: Int] = [:]
        private(set) var firstErrorDescription: String?

        var total: Int { counts.values.reduce(0, +) }

        func start() {
            // Molde EXACTO de `iCloudSyncService.startObserving()` (`queue: .main` + `assumeIsolated`).
            token = NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                MainActor.assumeIsolated {
                    self?.handle(note)
                }
            }
        }

        private func handle(_ note: Notification) {
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            let key: String
            switch event.type {
            case .setup: key = "setup"
            case .import: key = "import"
            case .export: key = "export"
            @unknown default: key = "otro"
            }
            let suffix = event.endDate == nil ? ".start" : (event.succeeded ? ".ok" : ".fail")
            counts[key + suffix, default: 0] += 1
            if let error = event.error, firstErrorDescription == nil {
                firstErrorDescription = "\(error)"
            }
        }

        func reset() {
            counts = [:]
            firstErrorDescription = nil
        }

        func stop() {
            if let token { NotificationCenter.default.removeObserver(token) }
            token = nil
        }

        func summary() -> String {
            guard !counts.isEmpty else { return "cero eventos" }
            return counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        }
    }
}
#endif
