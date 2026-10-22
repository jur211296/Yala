//
//  AccountKindLogicTests.swift
//  YalaTests
//
//  El fail-safe del tipo de cuenta y su sello. Lo que se fija aquí es una DECISIÓN de producto
//  (Jürgen, 2026-09-09), no una implementación: «`kind` ausente ⇒ `groups_only`, pero con corrección
//  al refrescar». Cada test nombra qué se rompería si la regla cambiara.
//

import Foundation
import Testing
@testable import Yala

private typealias L = AccountKindLogic

private let usuario = "sub-de-jurgen"
private let otro = "sub-de-otra-persona"
private let ahora = Date(timeIntervalSince1970: 1_757_500_000)

private func snap(_ kind: AccountKind, de userID: String = usuario) -> AccountKindSnapshot {
    AccountKindSnapshot(userID: userID, kind: kind, refreshedAt: ahora)
}

@Suite("Tipo de cuenta · qué se cree la app y cuándo")
struct AccountKindResolveTests {

    @Test("sin nada cacheado, la app asume solo-grupos")
    func sinCache_asumeSoloGrupos() {
        // El fail-safe apunta a lo MENOS invasivo: equivocarse hacia `complete` es enseñar un Panel
        // y unas cuentas que pueden no ser de quien mira.
        #expect(L.resolve(cached: nil, sessionUserID: usuario) == .groupsOnly)
    }

    @Test("con el dato del dueño, se cree el dato")
    func conCacheDelDueño_seCree() {
        #expect(L.resolve(cached: snap(.complete), sessionUserID: usuario) == .complete)
        #expect(L.resolve(cached: snap(.groupsOnly), sessionUserID: usuario) == .groupsOnly)
    }

    /// EL test del sello. Sin él, la caché escrita por una cuenta se aplicaría a la siguiente que
    /// entre en el dispositivo: alguien vería «tu cuenta lleva tus finanzas» por el dato de otro.
    @Test("un dato de OTRA cuenta no vale, aunque diga complete")
    func cacheDeOtraCuenta_noSeAplica() {
        #expect(L.resolve(cached: snap(.complete, de: otro), sessionUserID: usuario) == .groupsOnly)
    }

    @Test("sin sesión no hay tipo que resolver")
    func sinSesion_asumeSoloGrupos() {
        #expect(L.resolve(cached: snap(.complete), sessionUserID: nil) == .groupsOnly)
        #expect(L.resolve(cached: snap(.complete), sessionUserID: "") == .groupsOnly)
    }
}

@Suite("Tipo de cuenta · qué se persiste tras hablar con el servidor")
struct AccountKindPersistTests {

    @Test("lo que dice el servidor se guarda")
    func remotoNuevo_sePersiste() {
        let s = L.snapshotToPersist(remote: .complete, sessionUserID: usuario, cached: nil, now: ahora)
        #expect(s?.kind == .complete)
        #expect(s?.userID == usuario)
    }

    /// **El caso que carga el peso.** Un gateway viejo, o caído, no es una prueba de que la cuenta
    /// haya dejado de ser completa. Si el silencio borrara el dato, el fail-safe transitorio se
    /// convertiría en una degradación permanente: la cuenta completa rodaría como solo-grupos sin
    /// que nada volviera a corregirla.
    @Test("si el servidor calla, NO se toca lo que ya sabíamos")
    func remotoAusente_noBorraLoCacheado() {
        #expect(L.snapshotToPersist(remote: nil, sessionUserID: usuario, cached: snap(.complete), now: ahora) == nil)
        #expect(L.snapshotToPersist(remote: nil, sessionUserID: usuario, cached: nil, now: ahora) == nil)
    }

    @Test("si no cambia nada, no se reescribe")
    func mismoValor_noReescribe() {
        #expect(L.snapshotToPersist(remote: .complete, sessionUserID: usuario, cached: snap(.complete), now: ahora) == nil)
    }

    /// La degradación del reverse cutover llega por aquí: es la ÚNICA vía por la que una cuenta pasa
    /// de completa a solo-grupos, y tiene que poder sobrescribir lo cacheado.
    @Test("una degradación del servidor SÍ pisa lo cacheado")
    func degradacion_sePersiste() {
        let s = L.snapshotToPersist(remote: .groupsOnly, sessionUserID: usuario, cached: snap(.complete), now: ahora)
        #expect(s?.kind == .groupsOnly)
    }

    @Test("un dato cacheado de otra cuenta no impide guardar el de la sesión viva")
    func cacheDeOtro_seSobrescribeConElDeLaSesion() {
        let s = L.snapshotToPersist(remote: .complete, sessionUserID: usuario, cached: snap(.complete, de: otro), now: ahora)
        #expect(s?.userID == usuario)
    }

    @Test("sin sesión no se guarda nada")
    func sinSesion_noPersiste() {
        #expect(L.snapshotToPersist(remote: .complete, sessionUserID: nil, cached: nil, now: ahora) == nil)
        #expect(L.snapshotToPersist(remote: .complete, sessionUserID: "", cached: nil, now: ahora) == nil)
    }
}

@Suite("Tipo de cuenta · el contrato con el servidor")
struct AccountKindWireTests {

    /// El `rawValue` ES el wire (`profiles.kind` y el campo de `/account/exists`). Un renombrado que
    /// lo cambiara no rompería la compilación: dejaría de decodificar y caería al fail-safe, o sea
    /// fallaría en silencio y hacia el lado equivocado.
    @Test("los rawValue son los del backend, literales")
    func rawValues() {
        #expect(AccountKind.complete.rawValue == "complete")
        #expect(AccountKind.groupsOnly.rawValue == "groups_only")
        #expect(AccountKind(rawValue: "groups_only") == .groupsOnly)
        #expect(AccountKind(rawValue: "groupsOnly") == nil)
        #expect(AccountKind(rawValue: "premium") == nil)
    }

    @Test("el snapshot va y vuelve de JSON sin perder el sello")
    func snapshotRoundTrip() throws {
        let original = snap(.complete)
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(AccountKindSnapshot.self, from: data) == original)
    }
}

@Suite("Tipo de cuenta · el almacén", .serialized)
@MainActor
struct AccountKindStoreTests {

    private func almacenLimpio() -> (AccountKindStore, UserDefaults) {
        let suite = "test.accountkind.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (AccountKindStore(defaults: defaults), defaults)
    }

    @Test("guarda y devuelve")
    func guardaYDevuelve() {
        let (store, _) = almacenLimpio()
        store.write(snap(.complete))
        #expect(store.read() == snap(.complete))
    }

    @Test("borrar deja el almacén sin nada que aplicar a la siguiente cuenta")
    func clear() {
        let (store, _) = almacenLimpio()
        store.write(snap(.complete))
        store.clear()
        #expect(store.read() == nil)
    }

    /// Un JSON corrupto se lee como «no sé» y nunca como un tipo concreto: si devolviera un valor por
    /// defecto, un fichero dañado decidiría el modo de la app en silencio.
    @Test("un snapshot ilegible se lee como ausente, no como un valor")
    func corruptoSeIgnora() {
        let (store, defaults) = almacenLimpio()
        defaults.set(Data("{no es json".utf8), forKey: "cloudSync.accountKind")
        #expect(store.read() == nil)
    }
}
