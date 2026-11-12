//
//  GroupChangeRoleBackendTests.swift
//  YalaTests / CloudSync
//
//  «Hacer admin» / «Quitar admin» en un grupo de la nube (auditoría UX 2.2 · L19-3, decisión B de Jürgen). Hasta ese
//  día `GroupService.changeRole` lanzaba `.backendActionUnavailable` en el canal backend, porque el servidor no sabía
//  cambiar un rol. Ahora existe `set_member_role` (`qa/cloud/g22_01_set_member_role.sql`) y `changeRole` va
//  server-first: las validaciones locales antes de la red, el rol en local solo con el sí del servidor.
//
//  Molde de `GroupRejectMemberBackendTests` (container ON-DISK con los 3 stores; `.serialized` porque togglea
//  `CloudSyncFlags.groupsBackendEnabled` e inyecta `GroupService.shared.backendMembershipFactory`). La «persona que
//  llama» es admin por el fallback de `requireCurrentUserAdmin` (`group.isOwner`, sin miembro propio resuelto).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Cambiar el rol en un grupo de la nube (L19-3)", .serialized)
@MainActor
struct GroupChangeRoleBackendTests {

    private let base = URL(string: "https://gw.test")!

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupRole-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("No se pudo crear el directorio del test: \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        do { try FileManager.default.removeItem(at: dir) } catch { print("GroupChangeRoleBackendTests: cleanup: \(error)") }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GCR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GCR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GCR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func makeService(_ session: GroupsSyncClientTests.StubHTTPSession) -> GroupBackendMembershipService {
        let client = GroupsMembershipClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        client.sleeper = { _ in }
        return GroupBackendMembershipService(client: client, sessionCheck: { true })
    }

    private func stub(_ json: String, status: Int = 200) -> GroupsSyncClientTests.StubHTTPSession {
        GroupsSyncClientTests.StubHTTPSession(responseData: Data(json.utf8), statusCode: status)
    }

    /// El envelope de error con el que el gateway devuelve un `yala_*` del RPC (400 `yala_rpc_error`).
    private func rejection(_ code: String) -> GroupsSyncClientTests.StubHTTPSession {
        stub(#"{"error":{"message":"\#(code)","type":"yala_rpc_error","code":"\#(code)"}}"#, status: 400)
    }

    /// Prepara flag + factory y devuelve la limpieza.
    private func wire(flag: Bool, _ session: GroupsSyncClientTests.StubHTTPSession, context: ModelContext) -> () -> Void {
        GroupService.shared.setContext(context)
        let prevFactory = GroupService.shared.backendMembershipFactory
        CloudSyncFlags.groupsBackendEnabled = flag
        GroupService.shared.backendMembershipFactory = { self.makeService(session) }
        return {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
    }

    /// Un grupo del canal backend que administra quien llama, con DOS admins (Ana y Bea) y un miembro (Ciro). Con dos
    /// admins la validación local del último admin no corta, así que lo que se mide es el camino del servidor.
    private struct Seed {
        let group: SplitGroup
        let ana: SplitMember
        let bea: SplitMember
        let ciro: SplitMember
    }

    private func makeSeed(_ context: ModelContext, backend: Bool = true) throws -> Seed {
        let group = SplitGroup(name: "Roles")
        group.isOwner = true
        group.isBackendGroup = backend
        context.insert(group)
        func member(_ name: String, role: String, key: String) -> SplitMember {
            let m = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: name,
                                cloudKitUserRecordID: "", role: role, status: .active)
            m.memberKey = key
            m.userID = key
            context.insert(m)
            return m
        }
        let ana = member("Ana", role: "admin", key: "mk-ana")
        let bea = member("Bea", role: "admin", key: "mk-bea")
        let ciro = member("Ciro", role: "member", key: "mk-ciro")
        try context.save()
        return Seed(group: group, ana: ana, bea: bea, ciro: ciro)
    }

    private func sentBody(_ session: GroupsSyncClientTests.StubHTTPSession) throws -> [String: Any] {
        let body = try #require(session.lastRequest?.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    /// El rol que hay en el STORE (un contexto fresco sobre el mismo container), no el del objeto en memoria.
    private func storedRole(_ member: SplitMember, in context: ModelContext) throws -> String? {
        let fresh = ModelContext(context.container)
        let id = member.id
        return try fresh.fetch(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == id })).first?.role
    }

    // MARK: - Con el sí del servidor

    /// Hacer admin: `set_member_role` con la clave del miembro y `admin`; el rol llega al store y la pantalla se entera.
    @Test func hacerAdmin_vaAlServidor_yElRolLlegaAlStore() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-ciro","role":"admin","changed":true}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let seed = try makeSeed(context)
        let versionAntes = SessionState.shared.dataVersion

        try await GroupService.shared.changeRole(seed.ciro, to: "admin", in: seed.group)

        #expect(s.callCount == 1)
        #expect(s.lastRequest?.url?.lastPathComponent == "set_member_role")
        let body = try sentBody(s)
        #expect(body["p_group_id"] as? String == seed.group.cloudKitZoneID)
        #expect(body["p_member_key"] as? String == "mk-ciro")   // JAMÁS member.id
        #expect(body["p_role"] as? String == "admin")
        #expect(try storedRole(seed.ciro, in: context) == "admin")
        #expect(SessionState.shared.dataVersion > versionAntes)
    }

    /// Quitar el admin a un admin con otro admin al lado.
    @Test func quitarAdmin_vaAlServidor_yElRolLlegaAlStore() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-bea","role":"member","changed":true}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let seed = try makeSeed(context)

        try await GroupService.shared.changeRole(seed.bea, to: "member", in: seed.group)

        #expect(s.callCount == 1)
        #expect(try sentBody(s)["p_role"] as? String == "member")
        #expect(try storedRole(seed.bea, in: context) == "member")
        #expect(try storedRole(seed.ana, in: context) == "admin")   // el otro admin, intacto
    }

    /// El no-op del servidor (`changed: false`) también deja lo local con el rol que el servidor confirma.
    @Test func servidorNoOp_localSigueAlServidor() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-ciro","role":"admin","changed":false}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let seed = try makeSeed(context)

        try await GroupService.shared.changeRole(seed.ciro, to: "admin", in: seed.group)

        #expect(s.callCount == 1)
        #expect(try storedRole(seed.ciro, in: context) == "admin")
    }

    // MARK: - El servidor dice que no: lo local, intacto

    /// Cada rechazo propio de `set_member_role` llega al llamador como su `GroupsRPCError` y no toca el store. Los
    /// escenarios son los que la validación local NO puede ver: el creador sin `isGroupOwner` en este teléfono (el pull
    /// no lo escribe), un último admin que en local aún parece tener compañía, y un hueco sin reclamar.
    @Test func servidorRechaza_lanzaSuError_yLoLocalQuedaIntacto() async throws {
        let casos: [(code: String, expected: GroupsRPCError, quien: KeyPath<Seed, SplitMember>, rol: String)] = [
            ("yala_cannot_change_owner_role", .cannotChangeOwnerRole, \.ana, "member"),
            ("yala_last_admin", .lastAdmin, \.bea, "member"),
            ("yala_member_not_eligible", .memberNotEligible, \.ciro, "admin"),
        ]
        for caso in casos {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let s = rejection(caso.code)
            let restore = wire(flag: true, s, context: context); defer { restore() }
            let seed = try makeSeed(context)
            let target = seed[keyPath: caso.quien]
            let rolAntes = target.role

            await #expect(throws: caso.expected, "\(caso.code)") {
                try await GroupService.shared.changeRole(target, to: caso.rol, in: seed.group)
            }
            #expect(s.callCount == 1, "\(caso.code)")
            #expect(target.role == rolAntes, "\(caso.code): el objeto en memoria no se tocó")
            #expect(try storedRole(target, in: context) == rolAntes, "\(caso.code): el store no se tocó")
        }
    }

    /// Un fallo pasajero (sin red, 5xx) tampoco escribe nada.
    @Test func servidorNoResponde_loLocalQuedaIntacto() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"error":{"message":"upstream"}}"#, status: 502)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let seed = try makeSeed(context)

        await #expect(throws: GroupsRPCError.transient(status: 502)) {
            try await GroupService.shared.changeRole(seed.ciro, to: "admin", in: seed.group)
        }
        #expect(try storedRole(seed.ciro, in: context) == "member")
    }

    // MARK: - Las validaciones locales cortan ANTES de la red

    /// Cada una con su error y `callCount == 0`. El control positivo es `hacerAdmin_vaAlServidor_…` (mismo seed, sí
    /// llama): sin él, «no llamó» podría deberse a cualquier cosa.
    @Test func validacionesLocales_cortanAntesDelServidor() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"x","role":"admin","changed":true}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let seed = try makeSeed(context)

        func expectLocal(_ etiqueta: String, _ member: SplitMember, _ role: String, in group: SplitGroup,
                         _ matches: @escaping (GroupServiceError) -> Bool) async {
            var lanzo = false
            do {
                try await GroupService.shared.changeRole(member, to: role, in: group)
            } catch let error as GroupServiceError {
                lanzo = matches(error)
                if !lanzo { Issue.record("\(etiqueta): lanzó \(error)") }
            } catch {
                Issue.record("\(etiqueta): lanzó \(error), no un GroupServiceError")
            }
            #expect(lanzo, "\(etiqueta)")
        }

        // Rol inventado.
        await expectLocal("rol inválido", seed.ciro, "owner", in: seed.group) {
            if case .invalidRole = $0 { return true }; return false
        }
        // Miembro de otro grupo.
        let otro = SplitGroup(name: "Otro")
        otro.isBackendGroup = true
        context.insert(otro)
        let ajeno = SplitMember(groupZoneID: otro.cloudKitZoneID, displayName: "Dani",
                                cloudKitUserRecordID: "", role: "member", status: .active)
        ajeno.memberKey = "mk-dani"
        context.insert(ajeno)
        // Miembro que no está activo.
        let pendiente = SplitMember(groupZoneID: seed.group.cloudKitZoneID, displayName: "Eva",
                                    cloudKitUserRecordID: "", role: "member", status: .pendingApproval)
        pendiente.memberKey = "mk-eva"
        context.insert(pendiente)
        // El creador, marcado como tal en este teléfono.
        let creador = SplitMember(groupZoneID: seed.group.cloudKitZoneID, displayName: "Fede",
                                  cloudKitUserRecordID: "", role: "admin", status: .active, isGroupOwner: true)
        creador.memberKey = "mk-fede"
        context.insert(creador)
        // Un miembro sin `member_key`.
        let sinClave = SplitMember(groupZoneID: seed.group.cloudKitZoneID, displayName: "Gabi",
                                   cloudKitUserRecordID: "", role: "member", status: .active)
        context.insert(sinClave)
        try context.save()

        await expectLocal("otro grupo", ajeno, "admin", in: seed.group) {
            if case .memberNotInGroup = $0 { return true }; return false
        }
        await expectLocal("no activo", pendiente, "admin", in: seed.group) {
            if case .inactiveMember = $0 { return true }; return false
        }
        await expectLocal("quitarle el admin al creador", creador, "member", in: seed.group) {
            if case .ownerMemberImmutable = $0 { return true }; return false
        }
        await expectLocal("sin member_key", sinClave, "admin", in: seed.group) {
            if case .missingMemberKey = $0 { return true }; return false
        }

        // Quien llama no administra el grupo.
        let ajenoAMi = SplitGroup(name: "No es mío")
        ajenoAMi.isOwner = false
        ajenoAMi.isBackendGroup = true
        context.insert(ajenoAMi)
        let alguien = SplitMember(groupZoneID: ajenoAMi.cloudKitZoneID, displayName: "Hugo",
                                  cloudKitUserRecordID: "", role: "member", status: .active)
        alguien.memberKey = "mk-hugo"
        context.insert(alguien)
        try context.save()
        await expectLocal("no soy admin", alguien, "admin", in: ajenoAMi) {
            if case .adminRequired = $0 { return true }; return false
        }

        #expect(s.callCount == 0, "ninguna validación local dejó salir el RPC")
        #expect(pendiente.role == "member" && creador.role == "admin" && seed.ciro.role == "member")
    }

    /// El último admin en local: con un solo admin, quitárselo corta en local (`GroupServiceError.lastAdmin`), sin red.
    @Test func ultimoAdminEnLocal_cortaAntesDelServidor() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-ana","role":"member","changed":true}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let seed = try makeSeed(context)
        seed.bea.memberStatus = .left   // Ana se queda como única admin activa
        try context.save()

        await #expect {
            try await GroupService.shared.changeRole(seed.ana, to: "member", in: seed.group)
        } throws: { error in
            if case GroupServiceError.lastAdmin = error { return true }
            return false
        }
        #expect(s.callCount == 0)
        #expect(try storedRole(seed.ana, in: context) == "admin")
    }

    /// En la nube, un hueco admin sin reclamar no cuenta como el «otro admin» (regla 6 de `set_member_role`, espejo en
    /// local): con Ana como única admin CON CUENTA, quitárselo corta en local. Control en el mismo grupo: quitarle el
    /// admin al hueco sí sale al servidor, porque queda Ana.
    @Test func ultimoAdminConCuenta_unHuecoNoCuenta_enLaNube() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"legacy-hueco","role":"member","changed":true}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let seed = try makeSeed(context)
        seed.bea.memberStatus = .left
        let hueco = SplitMember(groupZoneID: seed.group.cloudKitZoneID, displayName: "Hueco",
                                cloudKitUserRecordID: "", role: "admin", status: .active)
        hueco.memberKey = "legacy-hueco"
        hueco.userID = nil
        context.insert(hueco)
        try context.save()

        await #expect {
            try await GroupService.shared.changeRole(seed.ana, to: "member", in: seed.group)
        } throws: { error in
            if case GroupServiceError.lastAdmin = error { return true }
            return false
        }
        #expect(s.callCount == 0)
        #expect(try storedRole(seed.ana, in: context) == "admin")

        try await GroupService.shared.changeRole(hueco, to: "member", in: seed.group)
        #expect(s.callCount == 1)
        #expect(try storedRole(hueco, in: context) == "member")
    }

    /// Fuera de la nube el conteo no cambia: el hueco admin sí cuenta (es el comportamiento de `removeMemberLocal` y del
    /// camino local de siempre), así que quitarle el admin a Ana se hace en local.
    @Test func ultimoAdmin_fueraDeLaNube_elConteoDeSiempre() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub("{}")
        let restore = wire(flag: false, s, context: context); defer { restore() }
        let seed = try makeSeed(context)
        seed.bea.memberStatus = .left
        let hueco = SplitMember(groupZoneID: seed.group.cloudKitZoneID, displayName: "Hueco",
                                cloudKitUserRecordID: "", role: "admin", status: .active)
        hueco.memberKey = "legacy-hueco"
        hueco.userID = nil
        context.insert(hueco)
        try context.save()

        try await GroupService.shared.changeRole(seed.ana, to: "member", in: seed.group)
        #expect(s.callCount == 0)
        #expect(try storedRole(seed.ana, in: context) == "member")
    }

    /// Un grupo congelado (migrado y aún no reabierto en este teléfono) no escribe, aunque su ZONA sea del canal
    /// backend: la fila en mano está congelada y la gemela de la zona enruta al servidor.
    @Test func grupoCongelado_cortaAntesDelServidor() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-ciro","role":"admin","changed":true}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let seed = try makeSeed(context)
        let congelado = SplitGroup(name: "Roles (vieja)")
        congelado.cloudKitZoneID = seed.group.cloudKitZoneID
        congelado.isBackendGroup = false
        congelado.movedToBackendAt = Date(timeIntervalSince1970: 1_760_000_000)
        context.insert(congelado)
        try context.save()
        #expect(congelado.isMigratedFrozen)   // control del escenario

        await #expect {
            try await GroupService.shared.changeRole(seed.ciro, to: "admin", in: congelado)
        } throws: { error in
            if case GroupServiceError.movedToBackend = error { return true }
            return false
        }
        #expect(s.callCount == 0)
        #expect(try storedRole(seed.ciro, in: context) == "member")
    }

    // MARK: - Fuera del canal backend, como siempre

    /// Flag apagado: cambio local, sin red (el camino de los grupos locales no cambió).
    @Test func flagApagado_cambiaEnLocal_sinRed() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-ciro","role":"admin","changed":true}"#)
        let restore = wire(flag: false, s, context: context); defer { restore() }
        let seed = try makeSeed(context)

        try await GroupService.shared.changeRole(seed.ciro, to: "admin", in: seed.group)

        #expect(s.callCount == 0)
        #expect(try storedRole(seed.ciro, in: context) == "admin")
    }

    // MARK: - Qué se ofrece (`roleChangeOffer`)

    @Test func roleChangeOffer_tabla() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub("{}")
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let seed = try makeSeed(context)
        let g = seed.group
        func add(_ role: String, _ status: SplitMemberStatus, userID: String?, owner: Bool = false,
                 in group: SplitGroup) -> SplitMember {
            let m = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "x", cloudKitUserRecordID: "",
                                role: role, status: status, isGroupOwner: owner)
            m.memberKey = userID ?? "legacy-\(UUID().uuidString)"
            m.userID = userID
            context.insert(m)
            return m
        }
        let hueco = add("member", .active, userID: nil, in: g)
        let huecoAdmin = add("admin", .active, userID: nil, in: g)
        let pendiente = add("member", .pendingApproval, userID: "mk-p", in: g)
        let salio = add("admin", .left, userID: "mk-l", in: g)
        let creador = add("admin", .active, userID: "mk-o", owner: true, in: g)
        let local = SplitGroup(name: "Local")
        local.isOwner = true
        context.insert(local)
        let huecoLocal = add("member", .active, userID: nil, in: local)
        let congelado = SplitGroup(name: "Congelado")
        congelado.movedToBackendAt = Date(timeIntervalSince1970: 1_760_000_000)
        context.insert(congelado)
        let enCongelado = add("member", .active, userID: "mk-c", in: congelado)
        try context.save()
        #expect(congelado.isMigratedFrozen)   // control del escenario

        let svc = GroupService.shared
        #expect(svc.roleChangeOffer(for: seed.ciro, in: g) == .makeAdmin)
        #expect(svc.roleChangeOffer(for: seed.bea, in: g) == .removeAdmin)
        #expect(svc.roleChangeOffer(for: hueco, in: g) == nil)              // nube + sin cuenta: no se puede hacer admin
        #expect(svc.roleChangeOffer(for: huecoAdmin, in: g) == .removeAdmin) // …pero quitárselo sí
        #expect(svc.roleChangeOffer(for: pendiente, in: g) == nil)
        #expect(svc.roleChangeOffer(for: salio, in: g) == nil)
        #expect(svc.roleChangeOffer(for: creador, in: g) == nil)
        #expect(svc.roleChangeOffer(for: huecoLocal, in: local) == .makeAdmin) // fuera de la nube `userID` no cuenta
        #expect(svc.roleChangeOffer(for: enCongelado, in: congelado) == nil)

        // Con el canal apagado el grupo de la nube se trata como local: el hueco vuelve a poder ser admin.
        CloudSyncFlags.groupsBackendEnabled = false
        #expect(svc.roleChangeOffer(for: hueco, in: g) == .makeAdmin)
        #expect(svc.roleChangeOffer(for: creador, in: g) == nil)
    }
}
