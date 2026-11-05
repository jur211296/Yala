//
//  TestSimulatorJanitor.swift
//  YalaTests
//
//  Lo que una corrida de YalaTests crea en el simulador y no es de nadie al terminar: los dominios de
//  `UserDefaults(suiteName:)` de los tests y los directorios de stores SQLite en `tmp/`.
//
//  POR QUÉ UN CONSERJE DE PROCESO Y NO UN `defer` POR TEST.
//
//   · Preferencias. `UserDefaults(suiteName:)` crea un `.plist` en `Library/Preferences` del
//     contenedor y no se va solo: medido el 2026-11-04, 2.538 ficheros en el contenedor de
//     `com.jurgenschmidt.yala.dev` del iPhone 17 Pro. Borrarlo al acabar CADA test no vale: hay suites
//     que reabren el mismo nombre para simular un relanzamiento, y un dominio borrado a mitad de test
//     es un fallo que no se parece a su causa. Se apunta al crearlo (`testDefaults(suiteName:)`,
//     `makeIsolatedDefaults`) y se borra al salir el proceso, cuando ya no lo usa nadie.
//
//   · Stores SQLite. Un test que hace `removeItem` del directorio con el `ModelContainer` todavía vivo
//     le borra el fichero a una conexión abierta, y SQLite lo dice al cerrarla: «BUG IN CLIENT OF
//     libsqlite3.dylib: database integrity compromised by API violation: vnode unlinked while in use»
//     (~550 por corrida, ticket `tests-borran-el-store-sqlite-abierto`). SwiftData no tiene `close()`:
//     el container se cierra cuando se suelta, y en el `defer` del test todavía no se ha soltado. Así
//     que `discardTestStoreDirectory(_:)` borra el directorio SOLO si el proceso ya no tiene ningún
//     descriptor abierto dentro (`fcntl(F_GETPATH)` sobre cada fd); si lo tiene, lo deja en cola y lo
//     reintenta en la siguiente llamada y al salir. El borrado llega cuando el container ya cerró.
//
//   · Preferencias del App Group REAL. Los tests escriben en él sin querer, a través de los servicios de
//     producción: medido el 2026-11-04, una corrida completa dejaba `isProUser`, `lastUsedAccountID` y
//     `siri_finance_snapshot` en `group.com.jurgenschmidt.yala`, y el `.plist` creado si no existía. Ese dominio
//     lo leen la app y los widgets de ese simulador. `TestProcessGuard` restaura cinco claves con nombre; aquí se
//     fotografía el dominio ENTERO al empezar y se devuelve tal cual al salir: lo que no estaba se quita, lo que
//     cambió vuelve a su valor, y si el fichero no existía y queda vacío, se borra.
//
//   · El onboarding. `hasCompletedOnboarding` y `hasShownWelcomeChooser` en `.standard` del host se fotografían al
//     empezar y se devuelven al salir, para que una corrida no deje la bienvenida marcada como vista. La mitad
//     de los XCUITest (los `@AppStorage` de `ContentView`) no es de este proceso: ticket aparte.
//
//  CÓMO SE ENGANCHA. Lo arma `TestProcessGuard` —el `NSPrincipalClass` del bundle, que XCTest instancia
//  antes del primer test— con su `atexit`. Al armarse, además, retira lo que dejó apuntado en el
//  manifiesto un proceso anterior que MURIÓ (crash, watchdog, `Restarting after unexpected exit`):
//  `atexit` no corre en esos casos, y sin el manifiesto lo suyo se quedaría para siempre.
//

import Foundation
import Darwin

@testable import Yala

enum TestSimulatorJanitor {

    // MARK: - Estado del proceso

    private static let lock = NSRecursiveLock()
    nonisolated(unsafe) private static var defaultsSuites: Set<String> = []
    nonisolated(unsafe) private static var pendingDirectories: [URL] = []

    /// El manifiesto de lo pendiente, para que un proceso que muere sin `atexit` no deje huérfanos: el
    /// siguiente lo lee al armarse. Vive en `Library/Caches` del contenedor (no en `tmp/`, que es lo que
    /// se limpia), una línea por entrada: `d <suite>` o `s <ruta>`.
    nonisolated static var manifestURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("YalaTestsJanitor.manifest")
    }

    // MARK: - Preferencias

    /// Apunta un dominio de `UserDefaults` creado por un test para borrarlo al salir el proceso.
    nonisolated static func registerDefaultsSuite(_ name: String) {
        lock.lock(); defer { lock.unlock() }
        guard defaultsSuites.insert(name).inserted else { return }
        appendToManifest("d \(name)")
    }

    /// ¿Está apuntado? Solo para el pin.
    nonisolated static func isRegistered(defaultsSuite name: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return defaultsSuites.contains(name)
    }

    /// Borra un dominio: las claves (`removePersistentDomain`) y su fichero. Pieza suelta para el pin; en la
    /// corrida la llama `finishProcess()`.
    nonisolated static func removeDefaultsDomain(_ name: String) {
        UserDefaults.standard.removePersistentDomain(forName: name)
        CFPreferencesAppSynchronize(name as CFString)
        let plist = defaultsPlistURL(name)
        if FileManager.default.fileExists(atPath: plist.path) {
            _ = removeItem(plist)
        }
    }

    nonisolated static func defaultsPlistURL(_ name: String) -> URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Preferences/\(name).plist")
    }

    // MARK: - Stores en disco

    /// Retira el directorio de un store de test. Si el proceso aún tiene un fichero abierto dentro (la
    /// conexión SQLite de un container que no se ha soltado), lo deja en cola en vez de borrárselo.
    nonisolated static func discardTestStoreDirectory(_ dir: URL) {
        lock.lock(); defer { lock.unlock() }
        if !pendingDirectories.contains(dir) {
            pendingDirectories.append(dir)
            appendToManifest("s \(dir.path)")
        }
        drainPendingDirectories()
    }

    /// Para el directorio que nadie borra (un `freshDir()` sin limpieza): se retira SOLO al salir el proceso. No entra
    /// en la cola que drena cada `discard`, porque otra suite en paralelo lo encontraría todavía vacío —sin fds
    /// abiertos— y se lo llevaría antes de que su test abriera el store.
    nonisolated static func retireAtExit(_ dir: URL) {
        lock.lock(); defer { lock.unlock() }
        guard !exitOnlyDirectories.contains(dir) else { return }
        exitOnlyDirectories.append(dir)
        appendToManifest("s \(dir.path)")
    }
    nonisolated(unsafe) private static var exitOnlyDirectories: [URL] = []

    /// El prefijo de los dominios de test que se crean FUERA de los helpers: `iCloudSyncService._testReset` abre
    /// `test.icloudsync.<UUID>` desde el código de la app, que este encargo no toca. Ningún dominio de producción
    /// empieza por aquí; al salir se barren sus `.plist` del contenedor.
    nonisolated static let strayDefaultsPrefix = "test."

    nonisolated static func sweepStrayDefaultsFiles() {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Preferences", isDirectory: true)
        let names: [String]
        do { names = try FileManager.default.contentsOfDirectory(atPath: dir.path) } catch {
            print("TestSimulatorJanitor: Error: \(error)")
            return
        }
        for name in names where name.hasPrefix(strayDefaultsPrefix) && name.hasSuffix(".plist") {
            removeDefaultsDomain(String(name.dropLast(".plist".count)))
        }
    }

    /// ¿Tiene este proceso algún descriptor abierto dentro de `dir`? Es lo que decide si un borrado llega a tiempo
    /// o a destiempo.
    nonisolated static func hasOpenFiles(under dir: URL) -> Bool {
        hasOpenFiles(under: dir, openPaths: openFilePaths())
    }

    /// Las rutas de todos los descriptores abiertos del proceso (`F_GETPATH` sobre cada fd). Una pasada por drenado,
    /// no una por directorio: con cientos en cola, recorrer la tabla por cada uno sería cuadrático.
    nonisolated static func openFilePaths() -> [String] {
        var paths: [String] = []
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        for fd in 0..<getdtablesize() {
            buffer.withUnsafeMutableBufferPointer { ptr in
                guard let base = ptr.baseAddress, fcntl(fd, F_GETPATH, base) != -1 else { return }
                paths.append(String(cString: base))
            }
        }
        return paths
    }

    private static func hasOpenFiles(under dir: URL, openPaths: [String]) -> Bool {
        let prefixes = Set([dir.standardizedFileURL.path, dir.resolvingSymlinksInPath().path]).map {
            $0.hasSuffix("/") ? $0 : $0 + "/"
        }
        return openPaths.contains { path in prefixes.contains { path.hasPrefix($0) } }
    }

    /// ¿Espera `dir` a que se cierre su store? Solo para el pin.
    nonisolated static func isPending(_ dir: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        drainPendingDirectories()
        return pendingDirectories.contains(dir)
    }

    private static func drainPendingDirectories() {
        guard !pendingDirectories.isEmpty else { return }
        let openPaths = openFilePaths()
        pendingDirectories.removeAll { dir in
            guard FileManager.default.fileExists(atPath: dir.path) else { return true }
            guard !hasOpenFiles(under: dir, openPaths: openPaths) else { return false }
            return removeItem(dir)
        }
    }

    private static func removeItem(_ url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("TestSimulatorJanitor: Error: \(error)")
            return false
        }
    }

    // MARK: - App Group real

    /// La foto del dominio del App Group al empezar el proceso. `nil` hasta que `startProcess` la toma.
    nonisolated(unsafe) private static var appGroupSnapshot: [String: Any]?
    nonisolated(unsafe) private static var appGroupPlistExisted = true

    /// Lo que el dominio tiene escrito, y solo eso: `dictionaryRepresentation` mezcla el global y el de registro, y
    /// restaurar desde ahí escribiría en el App Group claves que nunca fueron suyas.
    nonisolated static func persistedKeys(ofDomain name: String) -> [String: Any] {
        CFPreferencesAppSynchronize(name as CFString)
        let values = CFPreferencesCopyMultiple(nil, name as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return (values as? [String: Any]) ?? [:]
    }

    /// Devuelve el dominio `name` a la foto: quita lo que no estaba y repone lo que cambió o desapareció. Pieza pura
    /// para el pin.
    nonisolated static func restore(_ snapshot: [String: Any], domain name: String, into store: UserDefaults) {
        let now = persistedKeys(ofDomain: name)
        for key in now.keys where snapshot[key] == nil {
            store.removeObject(forKey: key)
        }
        for (key, value) in snapshot {
            guard let current = now[key] else { store.set(value, forKey: key); continue }
            if !(current as AnyObject).isEqual(value) { store.set(value, forKey: key) }
        }
        store.synchronize()
    }

    /// El identificador del App Group, leído UNA vez en `startProcess`. `SharedContainerService.appGroupIdentifier` es
    /// del main actor y el `atexit` no lo es; el principal class se instancia en el hilo principal, así que se lee allí.
    nonisolated(unsafe) private static var appGroupID: String?

    private static func appGroupPlistURL(_ id: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)?
            .appendingPathComponent("Library/Preferences/\(id).plist")
    }

    // MARK: - Onboarding

    /// Las dos claves que, escritas en `.standard` del simulador, hacen que quien abra la app después se salte la
    /// bienvenida (ticket `appstorage-onboarding-desarma-el-aislamiento-de-tests`). Medido el 2026-11-04: una corrida
    /// de YalaTests no las deja escritas, pero varias suites las fijan en `.standard` bajo su propio restore
    /// (`RemoteWipeCutTests`), y basta con que uno falle a medias para que se queden. Esta red no depende de eso.
    nonisolated static let onboardingKeys = [
        AppPreferences.Keys.hasCompletedOnboarding, AppPreferences.Keys.hasShownWelcomeChooser,
    ]
    nonisolated(unsafe) private static var onboardingSnapshot: [(key: String, value: Any?)] = []

    /// «Ausente» distinto de `false`: restaurar un ausente con `set(false)` dejaría la clave escrita.
    nonisolated static func captureOnboarding(from store: UserDefaults) -> [(key: String, value: Any?)] {
        onboardingKeys.map { ($0, store.object(forKey: $0)) }
    }

    nonisolated static func restoreOnboarding(_ snapshot: [(key: String, value: Any?)], into store: UserDefaults) {
        for (key, value) in snapshot {
            if let value { store.set(value, forKey: key) } else { store.removeObject(forKey: key) }
        }
    }

    // MARK: - Ciclo del proceso

    /// Al cargar el bundle: retira lo que dejó apuntado un proceso anterior que murió sin `atexit`.
    nonisolated static func startProcess() {
        lock.lock(); defer { lock.unlock() }
        for line in readManifest() {
            let value = String(line.dropFirst(2))
            if line.hasPrefix("d ") { removeDefaultsDomain(value) }
            if line.hasPrefix("s "), FileManager.default.fileExists(atPath: value) {
                _ = removeItem(URL(fileURLWithPath: value))
            }
        }
        resetManifest()
        onboardingSnapshot = captureOnboarding(from: .standard)
        appGroupID = Thread.isMainThread ? MainActor.assumeIsolated { SharedContainerService.appGroupIdentifier } : nil
        if let id = appGroupID, UserDefaults(suiteName: id) != nil {
            appGroupSnapshot = persistedKeys(ofDomain: id)
            appGroupPlistExisted = appGroupPlistURL(id).map { FileManager.default.fileExists(atPath: $0.path) } ?? true
        }
        #if DEBUG
        print("TestSimulatorJanitor: start appGroup=\(appGroupSnapshot?.keys.sorted() ?? [])")
        #endif
    }

    /// Al salir el proceso (`atexit`): borra los dominios apuntados y los directorios en cola. Aquí ya no se
    /// cierra ninguna conexión, así que un fd abierto ya no lo ve SQLite.
    nonisolated static func finishProcess() {
        lock.lock(); defer { lock.unlock() }
        #if DEBUG
        let summary = "suites=\(defaultsSuites.count) pendientes=\(pendingDirectories.count) alSalir=\(exitOnlyDirectories.count)"
        #endif
        for name in defaultsSuites { removeDefaultsDomain(name) }
        defaultsSuites.removeAll()
        // Un directorio cuyo store sigue ABIERTO no se borra ni al salir: el SQLite de Apple vigila el fichero y avisa
        // en el mismo instante del `unlink` (medido el 2026-11-04: 64 de los 67 avisos que quedaban salían aquí, de
        // containers que algún singleton retiene). Se queda en el manifiesto y lo retira el arranque siguiente, ya
        // sin conexión. Lo demás, ahora.
        let openPaths = openFilePaths()
        var stillOpen: [URL] = []
        for dir in pendingDirectories + exitOnlyDirectories where FileManager.default.fileExists(atPath: dir.path) {
            if hasOpenFiles(under: dir, openPaths: openPaths) { stillOpen.append(dir) } else { _ = removeItem(dir) }
        }
        pendingDirectories.removeAll()
        exitOnlyDirectories.removeAll()
        sweepStrayDefaultsFiles()
        resetManifest()
        for dir in stillOpen { appendToManifest("s \(dir.path)") }
        restoreOnboarding(onboardingSnapshot, into: .standard)
        if let snapshot = appGroupSnapshot, let id = appGroupID, let appGroup = UserDefaults(suiteName: id) {
            restore(snapshot, domain: id, into: appGroup)
            // El fichero lo creó la corrida: si el dominio se quedó sin claves propias, se va con ella.
            if !appGroupPlistExisted, let plist = appGroupPlistURL(id),
               FileManager.default.fileExists(atPath: plist.path),
               let written = NSDictionary(contentsOf: plist), written.count == 0 {
                _ = removeItem(plist)
            }
        }
        #if DEBUG
        let endKeys = appGroupID.map { persistedKeys(ofDomain: $0).keys.sorted() } ?? []
        print("TestSimulatorJanitor: finish \(summary) abiertosAlSalir=\(stillOpen.count) appGroup=\(endKeys)")
        fflush(stdout)
        #endif
    }

    // MARK: - Manifiesto

    private static func appendToManifest(_ line: String) {
        let url = manifestURL
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                print("TestSimulatorJanitor: Error: no se pudo crear \(url.path)")
                return
            }
        }
        do {
            let handle = try FileHandle(forWritingTo: url)
            defer {
                do { try handle.close() } catch { print("TestSimulatorJanitor: Error: \(error)") }
            }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((line + "\n").utf8))
        } catch {
            print("TestSimulatorJanitor: Error: \(error)")
        }
    }

    private static func readManifest() -> [Substring] {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return [] }
        do {
            return try String(contentsOf: manifestURL, encoding: .utf8)
                .split(separator: "\n").filter { $0.count > 2 }
        } catch {
            print("TestSimulatorJanitor: Error: \(error)")
            return []
        }
    }

    private static func resetManifest() {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return }
        _ = removeItem(manifestURL)
    }
}

// MARK: - API de los tests

/// `UserDefaults(suiteName:)` para tests: el mismo almacén, apuntado para borrarse al salir el proceso. Mismo
/// tipo de retorno a propósito (opcional), para sustituir a la llamada sin tocar lo que la rodea. El guard
/// `TestSimulatorJanitorTests.ningunTestCreaUnDominioSinApuntarlo` prohíbe la llamada pelada en `YalaTests/`.
func testDefaults(suiteName: String) -> UserDefaults? {
    TestSimulatorJanitor.registerDefaultsSuite(suiteName)
    return UserDefaults(suiteName: suiteName)
}

/// Apunta un directorio temporal que el test no borra, para retirarlo al salir el proceso.
func retireTestStoreDirectoryLater(_ dir: URL) {
    TestSimulatorJanitor.retireAtExit(dir)
}

/// Retira el directorio temporal de un store de test sin borrarle el fichero a una conexión abierta.
func discardTestStoreDirectory(_ dir: URL) {
    TestSimulatorJanitor.discardTestStoreDirectory(dir)
}
