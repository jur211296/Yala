//
//  GroupsAccountAssociationTests.swift
//  YalaTests
//
//  Paso 10 · la asociación entre una sesión privada y su cuenta de grupos. Cuatro bloques, y ninguno
//  cubre a los otros:
//    1. la TABLA pura de la sección (`GroupsAssociationLogic`) — los cuatro estados y sus dos gestos
//    2. el REGISTRO (`GroupsAccountAssociation`) — los dos almacenes, la unión, y lo que se retira
//    3. el REGISTRADOR — a quién cubre y, sobre todo, a quién NO (el sello del handover)
//    4. el CABLEADO (source-scan) — lo que un test de comportamiento no puede ver desde aquí
//
//  El des-puenteo tiene su propio fichero (`GroupsAssociationDetachTests`): necesita los tres stores
//  on-disk y aquí no haría falta ninguno.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Dobles

/// iCloud-KV de juguete. Guarda los tres tipos que la asociación usa, para poder afirmar sobre la
/// escritura Y sobre la lectura — un doble que solo registre keys no puede probar la unión.
private final class FakeKV: BeaconKeyValueStore, @unchecked Sendable {
    var bools: [String: Bool] = [:]
    var strings: [String: String] = [:]
    var doubles: [String: Double] = [:]
    private(set) var removedKeys: [String] = []
    private(set) var synchronizeCalls = 0

    func setBool(_ value: Bool, forKey key: String) { bools[key] = value }
    func setString(_ value: String, forKey key: String) { strings[key] = value }
    func setDouble(_ value: Double, forKey key: String) { doubles[key] = value }

    func bool(forKey key: String) -> Bool { bools[key] ?? false }
    func string(forKey key: String) -> String? { strings[key] }
    func double(forKey key: String) -> Double { doubles[key] ?? 0 }

    func removeObject(forKey key: String) {
        bools[key] = nil
        strings[key] = nil
        doubles[key] = nil
        removedKeys.append(key)
    }

    @discardableResult func synchronize() -> Bool {
        synchronizeCalls += 1
        return true
    }
}

private func isolatedDefaults() -> UserDefaults {
    UserDefaults(suiteName: "test.assoc.\(UUID().uuidString)")!
}

// MARK: - 1 · La tabla de la sección

@Suite("GroupsAssociationLogic · qué pinta la sección «Grupos» de la fila de almacenamiento")
struct GroupsAssociationLogicTests {

    private typealias Estado = GroupsAssociationLogic.SectionState

    private func estado(
        _ device: CloudIdentityRoutingLogic.DeviceSessionState,
        asociada: Bool = false,
        sesion: Bool = false
    ) -> Estado {
        GroupsAssociationLogic.sectionState(
            deviceState: device, hasPersistedAssociation: asociada, hasLiveGroupsSession: sesion)
    }

    @Test("Sesión privada sin cuenta ni sesión → ofrece asociar")
    func privadaSinCuenta() {
        #expect(estado(.privateSession) == .noAccount)
        #expect(GroupsAssociationLogic.offersAssociate(.noAccount))
        #expect(GroupsAssociationLogic.offersDetach(.noAccount) == false)
    }

    @Test("Sesión privada con sesión de grupos viva → asociada, y se puede soltar")
    func privadaConSesion() {
        #expect(estado(.privateSession, asociada: true, sesion: true) == .associated)
        #expect(GroupsAssociationLogic.offersDetach(.associated))
        // Decisión de Jürgen (2026-09-09): para cambiar de cuenta hay que desasociar primero.
        #expect(GroupsAssociationLogic.offersAssociate(.associated) == false)
    }

    /// **La fila del segundo móvil, que era el hueco de la matriz.** La asociación viaja por el
    /// iCloud-KV del Apple ID; la sesión es un JWT del llavero de UN dispositivo y no viaja.
    @Test("Asociación registrada sin sesión viva → ofrece entrar, y también desasociar")
    func segundoMovil() {
        #expect(estado(.privateSession, asociada: true, sesion: false) == .associatedNeedsSignIn)
        #expect(GroupsAssociationLogic.offersDetach(.associatedNeedsSignIn), """
            Sin esto, quien llega a su segundo móvil y ya no quiere esa cuenta tendría que ENTRAR en
            ella para poder soltarla.
            """)
        #expect(GroupsAssociationLogic.offersAssociate(.associatedNeedsSignIn) == false)
    }

    @Test("La sesión viva manda sobre el registro: asociada aunque el registro no haya llegado")
    func sesionVivaSinRegistro() {
        // El registro puede tardar (iCloud-KV) o venir de un arranque anterior; lo que la persona ve
        // en pantalla tiene que casar con lo que la app está haciendo AHORA.
        #expect(estado(.privateSession, asociada: false, sesion: true) == .associated)
    }

    @Test("Nube completa → informa y NO ofrece nada (ADR §4)")
    func nubeCompleta() {
        for asociada in [true, false] {
            for sesion in [true, false] {
                #expect(estado(.cloudComplete, asociada: asociada, sesion: sesion) == .sameAccountAsPersonal)
            }
        }
        #expect(GroupsAssociationLogic.offersDetach(.sameAccountAsPersonal) == false)
        #expect(GroupsAssociationLogic.offersAssociate(.sameAccountAsPersonal) == false)
    }

    @Test("Sin sesión privada que asociar, la sección no existe")
    func sinPrivada() {
        for device in [CloudIdentityRoutingLogic.DeviceSessionState.fresh, .cloudGroupsOnly] {
            for asociada in [true, false] {
                for sesion in [true, false] {
                    #expect(estado(device, asociada: asociada, sesion: sesion) == .notApplicable, """
                        \(device) no tiene sesión privada a la que ligar una cuenta de grupos.
                        """)
                }
            }
        }
    }

    /// El eje entero, para que un caso nuevo de `DeviceSessionState` no se cuele sin decidir su celda.
    @Test("Los cuatro estados del dispositivo tienen celda, y solo `privateSession` depende de los flags")
    func ejeCompleto() {
        var porDevice: [CloudIdentityRoutingLogic.DeviceSessionState: Set<Estado>] = [:]
        // Por `allCases` y no por una lista a mano: escrita a mano, un caso NUEVO del enum se pliega en
        // el `case .fresh, .cloudGroupsOnly:` del switch y su celda queda decidida por omisión, sin que
        // este test —que existe justo para impedirlo— se entere.
        #expect(CloudIdentityRoutingLogic.DeviceSessionState.allCases.count == 4,
                "apareció un estado del dispositivo nuevo: decide su celda en `sectionState`")
        for device in CloudIdentityRoutingLogic.DeviceSessionState.allCases {
            var vistos: Set<Estado> = []
            for asociada in [true, false] {
                for sesion in [true, false] {
                    vistos.insert(estado(device, asociada: asociada, sesion: sesion))
                }
            }
            porDevice[device] = vistos
        }
        #expect(porDevice[.privateSession]?.count == 3)
        #expect(porDevice[.cloudComplete]?.count == 1)
        #expect(porDevice[.fresh]?.count == 1)
        #expect(porDevice[.cloudGroupsOnly]?.count == 1)
    }

    // MARK: Cómo se nombra la cuenta

    @Test("El correo manda; sin correo, el proveedor; sin ninguno, no se inventa nada")
    func nombreDeLaCuenta() {
        #expect(GroupsAssociationLogic.displayName(email: "a@b.com", provider: "google")
                == .email("a@b.com"))
        #expect(GroupsAssociationLogic.displayName(email: nil, provider: "apple")
                == .provider(.apple))
        #expect(GroupsAssociationLogic.displayName(email: "   ", provider: "google")
                == .provider(.google), "Un correo en blanco no es un correo.")
        #expect(GroupsAssociationLogic.displayName(email: nil, provider: nil) == .unnamed)
        #expect(GroupsAssociationLogic.displayName(email: nil, provider: "facebook") == .unnamed)
    }
}

// MARK: - 2 · El registro

@Suite("GroupsAccountAssociation · los dos almacenes de la asociación")
struct GroupsAccountAssociationStoreTests {

    @MainActor
    private func store() -> (GroupsAccountAssociation, FakeKV, UserDefaults) {
        let kv = FakeKV()
        let defaults = isolatedDefaults()
        return (GroupsAccountAssociation(iKV: kv, defaults: defaults), kv, defaults)
    }

    @MainActor
    @Test("Nace sin asociación")
    func naceVacio() {
        let (sut, _, _) = store()
        #expect(sut.read() == nil)
        #expect(sut.hasAssociation == false)
        #expect(sut.associatedSub == nil)
    }

    @MainActor
    @Test("Asociar escribe en los DOS almacenes")
    func escribeEnLosDos() {
        let (sut, kv, defaults) = store()
        #expect(sut.associate(sub: "sub-1", provider: "google", email: "a@b.com", kind: .groupsOnly))

        #expect(defaults.data(forKey: GroupsAccountAssociation.localKey) != nil, "falta el espejo local")
        #expect(kv.bool(forKey: GroupsAccountAssociation.Keys.associated))
        #expect(kv.string(forKey: GroupsAccountAssociation.Keys.sub) == "sub-1")
        #expect(kv.string(forKey: GroupsAccountAssociation.Keys.email) == "a@b.com")
        #expect(kv.string(forKey: GroupsAccountAssociation.Keys.kind) == AccountKind.groupsOnly.rawValue)
        // El proveedor y la fecha también: sin ellos el segundo móvil, que lee del iCloud-KV, cae a
        // `.unnamed` y la fila dice «tienes una cuenta» sin decir cuál.
        #expect(kv.string(forKey: GroupsAccountAssociation.Keys.provider) == "google")
        #expect(kv.double(forKey: GroupsAccountAssociation.Keys.associatedAt) > 0)
        #expect(kv.synchronizeCalls >= 1, "sin `synchronize` la asociación no sale de este dispositivo")

        let leido = sut.read()
        #expect(leido?.sub == "sub-1")
        #expect(leido?.email == "a@b.com")
        #expect(leido?.kind == .groupsOnly)
    }

    /// El caso del SEGUNDO móvil: el espejo local no existe (nunca se escribió aquí) y la asociación
    /// llega por el iCloud-KV. Si `read()` solo mirara lo local, la fila diría «no tienes cuenta».
    @MainActor
    @Test("Sin espejo local, la asociación se lee del iCloud-KV")
    func leeDelICloudKV() {
        let kv = FakeKV()
        kv.setBool(true, forKey: GroupsAccountAssociation.Keys.associated)
        kv.setString("sub-remoto", forKey: GroupsAccountAssociation.Keys.sub)
        kv.setString("apple", forKey: GroupsAccountAssociation.Keys.provider)
        let sut = GroupsAccountAssociation(iKV: kv, defaults: isolatedDefaults())

        #expect(sut.read()?.sub == "sub-remoto")
        #expect(sut.read()?.provider == "apple")
        #expect(sut.hasAssociation)
    }

    /// El `sub` es lo único sin lo que el registro no contesta ninguna de sus tres preguntas.
    @MainActor
    @Test("Un registro del iCloud-KV sin `sub` se trata como ausente")
    func iCloudKVaMedias() {
        let kv = FakeKV()
        kv.setBool(true, forKey: GroupsAccountAssociation.Keys.associated)
        kv.setString("google", forKey: GroupsAccountAssociation.Keys.provider)
        let sut = GroupsAccountAssociation(iKV: kv, defaults: isolatedDefaults())
        #expect(sut.read() == nil)
    }

    @MainActor
    @Test("Sin `sub` no se escribe nada, y se dice")
    func asociarSinSub() {
        let (sut, kv, defaults) = store()
        #expect(sut.associate(sub: nil, provider: "google", email: "a@b.com", kind: .complete) == false)
        #expect(sut.associate(sub: "", provider: "google", email: "a@b.com", kind: .complete) == false)
        #expect(defaults.data(forKey: GroupsAccountAssociation.localKey) == nil)
        #expect(kv.bool(forKey: GroupsAccountAssociation.Keys.associated) == false)
    }

    /// Re-escribir la MISMA cuenta refresca lo que puede cambiar (correo capturado más tarde, `kind`
    /// promovido) y NO mueve la fecha: si la moviera, el dato pasaría a significar «cuándo se abrió la
    /// app por última vez».
    @MainActor
    @Test("Re-asociar la misma cuenta conserva `associatedAt` y refresca el resto")
    func reasociarIdempotente() {
        let (sut, _, _) = store()
        let t0 = Date(timeIntervalSince1970: 1_000)
        sut.associate(sub: "s", provider: "apple", email: nil, kind: .groupsOnly, now: t0)
        sut.associate(sub: "s", provider: "apple", email: "tarde@b.com", kind: .complete,
                      now: t0.addingTimeInterval(9_999))

        let leido = sut.read()
        #expect(leido?.associatedAt == t0)
        #expect(leido?.email == "tarde@b.com")
        #expect(leido?.kind == .complete)
    }

    @MainActor
    @Test("Otra cuenta reemplaza la fecha y no hereda el correo de la anterior")
    func otraCuentaNoHereda() {
        let (sut, kv, _) = store()
        let t0 = Date(timeIntervalSince1970: 1_000)
        sut.associate(sub: "s1", provider: "google", email: "primera@b.com", kind: .groupsOnly, now: t0)
        let t1 = t0.addingTimeInterval(500)
        sut.associate(sub: "s2", provider: "apple", email: nil, kind: .groupsOnly, now: t1)

        #expect(sut.read()?.sub == "s2")
        #expect(sut.read()?.associatedAt == t1)
        #expect(sut.read()?.email == nil, "el correo de la cuenta anterior haría mentir a la fila")
        #expect(kv.string(forKey: GroupsAccountAssociation.Keys.email) == nil,
                "en el iCloud-KV el opcional se RETIRA, no se deja como estaba")
    }

    @MainActor
    @Test("Desasociar limpia los dos almacenes, key a key")
    func limpiaLosDos() {
        let (sut, kv, defaults) = store()
        sut.associate(sub: "s", provider: "google", email: "a@b.com", kind: .groupsOnly)
        sut.clear()

        #expect(sut.read() == nil)
        #expect(defaults.data(forKey: GroupsAccountAssociation.localKey) == nil)
        for key in GroupsAccountAssociation.Keys.all {
            #expect(kv.removedKeys.contains(key), "la key \(key) sobrevivió al desasociar")
        }
    }

    /// **El tombstone, y por qué no basta con borrar las keys.** El iCloud-KV es del Apple ID: su
    /// ausencia no distingue «nunca hubo cuenta» de «se acaba de soltar», y el registrador de OTRO
    /// dispositivo con sesión viva la reponía en su siguiente arranque.
    @MainActor
    @Test("Desasociar deja tombstone, y asociar lo retira")
    func tombstoneDelDesasociar() {
        let (sut, kv, _) = store()
        sut.associate(sub: "s", provider: "google", email: nil, kind: .groupsOnly)
        #expect(sut.isDetached == false)

        sut.clear()
        #expect(sut.read() == nil)
        #expect(sut.isDetached, "sin tombstone, «desasociado» es solo una ausencia y se repone sola")
        #expect(kv.double(forKey: GroupsAccountAssociation.Keys.detachedAt) > 0)

        sut.associate(sub: "s", provider: "google", email: nil, kind: .groupsOnly)
        #expect(sut.isDetached == false, "asociar es el único gesto que deshace un desasociar")
    }

    /// **La otra mitad del sello**, y la que faltaba: con el teléfono relevado, escribir en el iCloud-KV
    /// metería el correo del humano NUEVO en la cuenta de iCloud del ANTERIOR.
    @MainActor
    @Test("Con el dominio sellado, la asociación se guarda SOLO en local")
    func selloCierraTambienLaEscritura() {
        let kv = FakeKV()
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart)
        let sut = GroupsAccountAssociation(iKV: kv, defaults: defaults)

        #expect(sut.associate(sub: "del-nuevo", provider: "apple", email: "nuevo@b.com", kind: .groupsOnly))
        #expect(kv.bool(forKey: GroupsAccountAssociation.Keys.associated) == false, """
            El correo del humano nuevo acabó en el iCloud-KV del Apple ID del anterior.
            """)
        #expect(kv.string(forKey: GroupsAccountAssociation.Keys.email) == nil)
        // Y el espejo local SÍ, que es el alcance que le corresponde a un teléfono prestado.
        #expect(defaults.data(forKey: GroupsAccountAssociation.localKey) != nil)
        #expect(sut.read()?.sub == "del-nuevo")
    }

    /// Tri-estado, y el `nil` no es un detalle: la tabla de [I] lo trata como «no puedo probarlo» y
    /// bloquea la promoción. Devolver `false` sin registro sería afirmar con más confianza de la que hay.
    @MainActor
    @Test("`isAssociated` distingue «no hay registro» de «es otra cuenta»")
    func isAssociatedTriEstado() {
        let (sut, _, _) = store()
        #expect(sut.isAssociated(sub: "s") == nil)

        sut.associate(sub: "s", provider: "google", email: nil, kind: .groupsOnly)
        #expect(sut.isAssociated(sub: "s") == true)
        #expect(sut.isAssociated(sub: "otra") == false)
        #expect(sut.isAssociated(sub: nil) == false)
    }

    /// **La puerta al humano siguiente.** El «empiezo de cero» barre el espejo local pero NO puede borrar
    /// el iCloud-KV (viaja al Apple ID entero), así que lo que impide que el nuevo lea el correo del
    /// anterior es este guard.
    @MainActor
    @Test("Con el dominio sellado, la asociación del iCloud-KV NO se lee")
    func selloCierraLaLecturaDelICloudKV() {
        let kv = FakeKV()
        kv.setBool(true, forKey: GroupsAccountAssociation.Keys.associated)
        kv.setString("sub-del-anterior", forKey: GroupsAccountAssociation.Keys.sub)
        kv.setString("anterior@b.com", forKey: GroupsAccountAssociation.Keys.email)
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart)

        let sut = GroupsAccountAssociation(iKV: kv, defaults: defaults)
        #expect(sut.read() == nil)
        #expect(sut.hasAssociation == false)
    }

    /// El control positivo del anterior: sin sello, ESA MISMA copia sí se lee. Sin este caso, el test de
    /// arriba pasaría igual con la lectura del iCloud-KV rota del todo.
    @MainActor
    @Test("Sin sello, esa misma copia del iCloud-KV sí se lee")
    func sinSelloLaCopiaSeLee() {
        let kv = FakeKV()
        kv.setBool(true, forKey: GroupsAccountAssociation.Keys.associated)
        kv.setString("sub-del-anterior", forKey: GroupsAccountAssociation.Keys.sub)
        let sut = GroupsAccountAssociation(iKV: kv, defaults: isolatedDefaults())
        #expect(sut.read()?.sub == "sub-del-anterior")
    }

    @MainActor
    @Test("Un espejo local corrupto se descarta y se cae al iCloud-KV")
    func espejoCorrupto() {
        let kv = FakeKV()
        let defaults = isolatedDefaults()
        defaults.set(Data("{ esto no es".utf8), forKey: GroupsAccountAssociation.localKey)
        kv.setBool(true, forKey: GroupsAccountAssociation.Keys.associated)
        kv.setString("sub-remoto", forKey: GroupsAccountAssociation.Keys.sub)

        let sut = GroupsAccountAssociation(iKV: kv, defaults: defaults)
        #expect(sut.read()?.sub == "sub-remoto")
        #expect(defaults.data(forKey: GroupsAccountAssociation.localKey) == nil,
                "el payload ilegible se retira en vez de quedarse para fallar en cada lectura")
    }
}

// MARK: - 3 · El registrador

@Suite("GroupsAssociationRegistrar · a quién cubre el segundo armador, y a quién no")
struct GroupsAssociationRegistrarTests {

    /// **La razón de existir del segundo armador.** El parque que ya tenía sesión de grupos no va a
    /// pasar por ningún sign-in nuevo, así que sin esto su fila diría «no tienes cuenta».
    @MainActor
    @Test("Con sesión privada y sesión de grupos viva, registra la asociación")
    func registraAlParque() {
        let kv = FakeKV()
        let defaults = isolatedDefaults()
        let store = GroupsAccountAssociation(iKV: kv, defaults: defaults)

        GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded(
            deviceState: .privateSession, identity: .init(hasSession: true, sub: "s1", provider: "google", email: "a@b.com"), kind: .groupsOnly,
            store: store, defaults: defaults)

        #expect(store.read()?.sub == "s1")
        #expect(store.read()?.kind == .groupsOnly)
        #expect(store.read()?.email == "a@b.com")
    }

    /// **El agujero que este guard cierra.** El «empiezo de cero» del Welcome NO cierra la sesión en la
    /// nube —el JWT vive en su propio llavero—, así que sin el sello el primer arranque del humano
    /// SIGUIENTE volvería a escribir la asociación del ANTERIOR, deshaciendo el barrido del handover.
    @MainActor
    @Test("Con el dominio sellado para un usuario nuevo, NO registra nada")
    func noRegistraTrasElHandover() {
        let kv = FakeKV()
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart)
        let store = GroupsAccountAssociation(iKV: kv, defaults: defaults)

        GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded(
            deviceState: .privateSession, identity: .init(hasSession: true, sub: "del-anterior", provider: "google", email: "anterior@b.com"),
            kind: .groupsOnly, store: store, defaults: defaults)

        #expect(store.read() == nil)
    }

    /// **El agujero que cerró el tombstone.** El dispositivo que NO desasoció sigue con su sesión viva y
    /// reponía las keys en su siguiente arranque: la desasociación se deshacía sola, en el otro teléfono,
    /// sin que nadie tocara nada.
    @MainActor
    @Test("Con un desasociar registrado, el otro dispositivo NO repone la asociación")
    func noReponeTrasUnDesasociar() {
        let kv = FakeKV()
        let defaults = isolatedDefaults()
        let store = GroupsAccountAssociation(iKV: kv, defaults: defaults)
        store.associate(sub: "s1", provider: "google", email: "a@b.com", kind: .groupsOnly)
        store.clear()

        GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded(
            deviceState: .privateSession,
            identity: .init(hasSession: true, sub: "s1", provider: "google", email: "a@b.com"),
            kind: .groupsOnly, store: store, defaults: defaults)

        #expect(store.read() == nil)
    }

    @MainActor
    @Test("Fuera de una sesión privada no hay nada que asociar")
    func soloEnSesionPrivada() {
        for device in [CloudIdentityRoutingLogic.DeviceSessionState.fresh, .cloudComplete, .cloudGroupsOnly] {
            let defaults = isolatedDefaults()
            let store = GroupsAccountAssociation(iKV: FakeKV(), defaults: defaults)
            GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded(
                deviceState: device, identity: .init(hasSession: true, sub: "s", provider: "apple", email: nil), kind: .complete,
                store: store, defaults: defaults)
            #expect(store.read() == nil, "\(device) no tiene sesión privada a la que ligar la cuenta")
        }
    }

    @MainActor
    @Test("Sin sesión viva no inventa una asociación")
    func sinSesionNoRegistra() {
        let defaults = isolatedDefaults()
        let store = GroupsAccountAssociation(iKV: FakeKV(), defaults: defaults)
        GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded(
            deviceState: .privateSession, identity: .init(hasSession: false, sub: "s", provider: "apple", email: nil), kind: nil,
            store: store, defaults: defaults)
        #expect(store.read() == nil)
    }
}

// MARK: - 3-bis · Lo que la asociación cambia en el tab de Grupos

@Suite("GroupsEmptyStateLogic · el segundo móvil ya no lee «crea una cuenta»")
struct GroupsEmptyStateAssociationTests {

    private func decide(hadSessionEver: Bool, asociada: Bool) -> GroupsEmptyStateLogic.Kind {
        GroupsEmptyStateLogic.decide(
            flagOn: true, hasSeenEducational: true, hadSessionEver: hadSessionEver,
            hasSession: false, isConsented: true, hasAssociatedAccount: asociada)
    }

    /// **El hueco que este parámetro cierra.** `hadSessionEver` es per-DEVICE: en el segundo móvil del
    /// mismo Apple ID vale `false` aunque la persona tenga sus grupos en una cuenta, así que sin mirar la
    /// asociación se le ofrecía CREAR la cuenta que ya tiene.
    @Test("Sin latch pero CON asociación → «vuelve a tu cuenta», no «crea una»")
    func segundoMovilConAsociacion() {
        #expect(decide(hadSessionEver: false, asociada: true) == .signInToView)
    }

    @Test("Sin latch y sin asociación sigue siendo «crea una cuenta»")
    func sinNadaSigueIgual() {
        #expect(decide(hadSessionEver: false, asociada: false) == .createAccount)
    }

    /// El latch sigue mandando por su cuenta: quien tuvo sesión en ESTE dispositivo lee lo mismo que
    /// antes, haya o no asociación registrada. Es la no-regresión del camino de C2.
    @Test("Con el latch puesto, la asociación no cambia nada")
    func elLatchSigueValiendo() {
        #expect(decide(hadSessionEver: true, asociada: false) == .signInToView)
        #expect(decide(hadSessionEver: true, asociada: true) == .signInToView)
    }
}

// MARK: - 4 · El cableado

@Suite("Paso 10 · el cableado de la asociación (source-scan)")
struct GroupsAssociationWiringTests {

    private static func source(_ relative: String) -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent(relative)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    /// El fichero SIN líneas de comentario. Los scans que CUENTAN ocurrencias lo necesitan: sin esto,
    /// documentar el invariante que el test cuenta lo pone en rojo sin que producción cambie — pasó ya en
    /// este repo.
    private static func codeOnly(_ relative: String) -> String {
        source(relative)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Normaliza para comparar cuerpos: sin comentarios, sin indentación y en una línea. Un `contains`
    /// sobre el fichero crudo depende de dónde caiga el salto de línea, y basta un reformateo para que
    /// deje de casar (verde por accidente en la dirección peligrosa).
    private static func flattened(_ relative: String) -> String {
        codeOnly(relative)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    /// El único destino de [I] que escribe la asociación. Un test de comportamiento no puede verlo:
    /// `routeIdentityDestination` es privado de un `ViewModifier` y su rama viva exige un sign-in real.
    @Test("La asociación se escribe ANTES de arrancar el canal, y solo para su destino")
    func escrituraAntesDeArrancarElCanal() {
        let src = Self.flattened("Yala/App/Views/Shared/GroupsBackendInviteModifier.swift")
        // El emparejamiento ENTERO, no tres `contains` sueltos: con literales desacoplados, mover la
        // escritura a otra rama deja el test verde y la asociación se escribiría para quien no tiene
        // sesión privada.
        #expect(src.contains("""
            if destino == .associateGroupsAccount { GroupsAccountAssociation.shared.associate(
            """.trimmingCharacters(in: .whitespacesAndNewlines)), """
            La escritura de la asociación ya no cuelga de `destino == .associateGroupsAccount`.
            """)

        // **El ORDEN es lo que la hace útil.** `startIfEligible` arranca el canal en el acto y su primer
        // ciclo puede llamar al puente, que pregunta por la cuenta asociada: escrita después, el libro de
        // conservados lee `nil` y cada gasto conservado se duplica en el Panel.
        guard let escritura = src.range(of: "GroupsAccountAssociation.shared.associate("),
              let arranque = src.range(of: "GroupsSyncClient.shared.startIfEligible(")
        else { return #expect(Bool(false), "no se encontraron las dos llamadas") }
        #expect(escritura.upperBound < arranque.lowerBound, """
            La asociación se escribe DESPUÉS de arrancar el canal. El primer ciclo del canal puede
            puentear los gastos que el usuario conservó al desasociar y duplicarlos en su Panel.
            """)

        // Y el bloqueo sigue sin escribir nada: el `guard` que lo corta va antes que todo esto.
        guard let bloqueo = src.range(of: "guard destino != .blockedAccountIsComplete else { return }")
        else { return #expect(Bool(false), "el guard del bloqueo [I] desapareció") }
        #expect(bloqueo.upperBound < escritura.lowerBound, """
            La asociación se escribiría incluso con la cuenta RECHAZADA por el bloqueo [I].
            """)
    }

    /// El segundo armador. Sin el call-site, la suite de arriba pasa entera y el parque instalado se
    /// queda sin asociación para siempre — el mismo hueco que cubre el `onAppear` del tab en C2.
    @Test("El arranque llama al registrador, después de corregir el `kind`")
    func registradorCableadoEnElArranque() {
        let src = Self.source("Yala/App/AppBootstrapper.swift")
        #expect(src.contains("GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded("))
        // **En el MISMO `Task`, y en ese orden.** Comparar posiciones de texto sobre el fichero entero
        // no basta: sacar el registrador a su propio `Task` escrito más abajo conserva el orden del
        // TEXTO y los pone a correr en paralelo, que es justo lo que este test dice impedir.
        let bloque = src.components(separatedBy: "await AccountKindService.shared.refresh()")
        #expect(bloque.count == 2, "`AccountKindService.shared.refresh()` ya no es único en el fichero")
        let despues = bloque.last ?? ""
        guard let registro = despues.range(of: "GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded("),
              let finDelTask = despues.range(of: "\n        }")
        else { return #expect(Bool(false), "no se encontró el registrador tras el refresco") }
        #expect(registro.lowerBound < finDelTask.lowerBound, """
            El registrador ya no está dentro del mismo `Task` que el refresco del `kind`: en paralelo
            guarda el `kind` que el Welcome dedujo sin respuesta del gateway.
            """)
    }

    /// El handover barre el espejo local **y no toca el iCloud-KV**: esa copia la cierra el sello, no un
    /// borrado. Las dos mitades van juntas porque quitar cualquiera de ellas reabre la fuga.
    @Test("El relevo de humano retira el espejo local y NO borra el iCloud-KV")
    func handoverBarreElEspejoYRespetaElICloudKV() {
        let src = Self.codeOnly("Yala/Utils/DataWipeService.swift")
        #expect(src.contains("defaults.removeObject(forKey: GroupsAccountAssociation.localKey)"))
        #expect(src.contains("defaults.removeObject(forKey: GroupsDetachedBridgeLedger.userDefaultsKey)"))
        // Por SÍMBOLO y no por los literales de las keys: la versión que había que cerrar las nombraba
        // con `GroupsAccountAssociation.Keys.all`, así que un scan de literales daba cero y pasaba verde
        // sobre exactamente el código que dice prohibir.
        for prohibido in ["GroupsAccountAssociation.Keys", "clearHandoverGroupsAssociation"] {
            #expect(src.contains(prohibido) == false, """
                `DataWipeService` nombra `\(prohibido)`. Ese camino tiene una invariante propia —al iKV va
                UNA sola key, porque lo que se escriba ahí viaja a TODOS los dispositivos del Apple ID— y
                borrar la asociación le quitaría al dueño la suya en el iPad. La puerta al humano nuevo es
                el SELLO, en `GroupsAccountAssociation`. Lo pinnea además, por comportamiento,
                `HandoverGroupsDomainTests.wipeLocalGroupsDomain_touchesNothingInTheIKV`.
                """)
        }
    }

    /// El bridge tiene que consultar el libro de conservados en sus DOS puertas. Con una sola, la mitad
    /// de las filas que el usuario conservó se duplicarían al re-asociar.
    @Test("Las dos puertas del bridge consultan el libro de conservados")
    func bridgeConsultaElLibro() {
        let src = Self.flattened("Yala/Services/Groups/GroupTransactionBridge.swift")
        // El `guard !` va DENTRO del match: sin la negación, el guard se invierte y el puente deja de
        // puentear todo lo que NO esté conservado, o sea todo. Test verde, feature apagada.
        #expect(src.contains("guard !GroupsDetachedBridgeLedger.isConserved( expenseID: expense.id.uuidString,"))
        #expect(src.contains("guard !GroupsDetachedBridgeLedger.isConserved( settlementID: settlement.id.uuidString,"))
        // El libro se consulta SELLADO con la cuenta asociada. Sin el sello, los conservados de una
        // cuenta frenarían el puente de otra — y ahí sí se perderían gastos que nadie pidió conservar.
        let sellos = src.components(
            separatedBy: "associatedSub: GroupsAccountAssociation.shared.associatedSub").count - 1
        #expect(sellos == 2, "las dos consultas van selladas con el `sub` asociado; vistas: \(sellos)")
    }

    /// El empty state del tab de Grupos en el segundo móvil.
    @Test("El empty state de Grupos mira también la asociación")
    func emptyStateMiraLaAsociacion() {
        let src = Self.codeOnly("Yala/App/Views/Groups/GroupsContainerView.swift")
        let apariciones = src.components(
            separatedBy: "hasAssociatedAccount: GroupsAccountAssociation.shared.hasAssociation").count - 1
        #expect(apariciones == 2, """
            Son DOS los call-sites de `GroupsEmptyStateLogic.decide` en esa vista (el empty state y el
            gate del CTA) y los dos tienen que contestar lo mismo; vistos: \(apariciones).
            """)
    }
}
