//
//  PagoLogoPropioSyncTests.swift
//  YalaTests / PagoLogoPropio
//
//  Logo propio de un pago planificado (encargo del 2026-11-20), la parte con almacén. Lo que fija:
//   - guardar: una foto nueva estrena referencia, la misma la conserva, quitarla deja el pago sin foto ni referencia;
//   - se pinta la foto antes que el banco de logos;
//   - Modo Nube, `scheduled_payments.custom_logo_ref` con `since: 7` (molde de `SplitLinesSyncTests`): con v6 no se
//     emite y se APUNTA; con v7, sí; ida y vuelta entre dos teléfonos (la referencia nueva suelta la foto vieja, el eco
//     no); la subida de v6 a v7 reemite lo apuntado con solo esa columna;
//   - la pasada de Storage contra un Storage de mentira: sube, baja en el otro teléfono y borra lo huérfano.
//  La ida y vuelta contra el Worker y el Storage de staging la mide `qa/cloud/g32_01-staging-probe.sh`.
//
//  Container ON-DISK temp con los 3 stores + `.serialized`. `SyncCapability.defaults` se aísla en cada caso.
//

import Foundation
import SwiftData
import Testing
import UIKit

@testable import Yala

@Suite("Logo propio · guardar, pintar, Modo Nube (custom_logo_ref, v7) y Storage", .serialized)
@MainActor
struct PagoLogoPropioSyncTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PagoLogoPropio-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        retireTestStoreDirectoryLater(dir)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "PLP-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "PLP-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "PLP-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func isolateCapability(backend level: Int?) -> () -> Void {
        let previous = SyncCapability.defaults
        let suite = "test.syncCapability.\(UUID().uuidString)"
        let isolated = testDefaults(suiteName: suite) ?? previous
        SyncCapability.defaults = isolated
        if let level { isolated.set(level, forKey: SyncCapability.backendManifestVersionKey) }
        return {
            isolated.removePersistentDomain(forName: suite)
            SyncCapability.defaults = previous
        }
    }

    private let node = "0123456789abcdef"
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }

    private func photo(_ color: UIColor) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300), format: format).image { ctx in
            color.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
        return PagoLogoPropioFoto.datosParaGuardar(imagen: image) ?? Data()
    }

    private func payment(_ context: ModelContext, name: String = "Colegio San Martín") -> ScheduledPayment {
        let payment = ScheduledPayment(name: name, amount: 850, currencyCode: "PEN",
                                       nextDueDate: Date(timeIntervalSince1970: 1_700_000_000))
        payment.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(payment)
        return payment
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    // MARK: - Guardar

    @Test func save_newPhotoGetsANewReference_samePhotoKeepsIt_removingClearsBoth() throws {
        let context = try makeContext(freshDir())
        let pago = payment(context)
        let red = photo(.red)

        ScheduledPaymentEditorViewModel.applyCustomLogo(red, to: pago)
        let first = try #require(pago.customLogoRef)
        #expect(pago.customLogoData == red)
        #expect(PagoLogoPropioFoto.esReferenciaValida(first))

        ScheduledPaymentEditorViewModel.applyCustomLogo(red, to: pago)
        #expect(pago.customLogoRef == first, "guardar otra cosa del pago no vuelve a subir la foto")

        ScheduledPaymentEditorViewModel.applyCustomLogo(photo(.blue), to: pago)
        #expect(pago.customLogoRef != first && pago.customLogoRef != nil, "una foto nueva estrena referencia")

        ScheduledPaymentEditorViewModel.applyCustomLogo(nil, to: pago)
        #expect(pago.customLogoData == nil && pago.customLogoRef == nil)
    }

    /// El editor guarda el logo solo si cambió en esta edición: una foto que llegó con el editor abierto sobrevive a
    /// guardar otra cosa del pago.
    @Test func editorSavesTheLogoOnlyIfItChangedHere() throws {
        let red = photo(.red), blue = photo(.blue)
        #expect(ScheduledPaymentEditorViewModel.logoEdit(red, loaded: red, isGroupExpense: false) == .none)
        #expect(ScheduledPaymentEditorViewModel.logoEdit(nil as Data?, loaded: nil, isGroupExpense: false) == .none)
        #expect(ScheduledPaymentEditorViewModel.logoEdit(blue, loaded: red, isGroupExpense: false) == .some(blue))
        #expect(ScheduledPaymentEditorViewModel.logoEdit(nil, loaded: red, isGroupExpense: false) == .some(nil))
        #expect(ScheduledPaymentEditorViewModel.logoEdit(red, loaded: red, isGroupExpense: true) == .some(nil),
                "un gasto de grupo no lleva logo")

        // El caso del revisor: el editor abrió sin foto, la foto llegó, se guarda otra cosa → la foto se queda.
        let context = try makeContext(freshDir())
        let pago = payment(context)
        let llegada = photo(.green)
        pago.customLogoData = llegada
        pago.customLogoRef = PagoLogoPropioFoto.nuevaReferencia()
        if case .some(let edit) = ScheduledPaymentEditorViewModel.logoEdit(nil as Data?, loaded: nil, isGroupExpense: false) {
            ScheduledPaymentEditorViewModel.applyCustomLogo(edit, to: pago)
        }
        #expect(pago.customLogoData == llegada && pago.customLogoRef != nil)
    }

    // MARK: - Pintar

    @Test func paint_thePhotoWinsOverTheLogoBank() throws {
        PagoLogoPropioImagenes._testReset()
        let context = try makeContext(freshDir())
        let pago = payment(context, name: "Spotify")
        #expect(PagoLogoComercio.logo(for: pago)?.id == "spotify", "sin foto, el del banco")

        pago.customLogoData = photo(.red)
        pago.brandLogoID = SubscriptionBrandCatalog.noneID
        let logo = try #require(PagoLogoComercio.logo(for: pago))
        #expect(logo.id == PaymentLogo.customPhotoID)
        #expect(logo.photo != nil)
        #expect(logo.name == "Spotify", "VoiceOver lo lee con el nombre del pago")

        pago.customLogoData = nil
        #expect(PagoLogoComercio.logo(for: pago) == nil, "sin foto y con «sin logo»: el icono de siempre")
    }

    // MARK: - Modo Nube: emisión

    @Test func emission_v7_carriesTheReference_v6_doesNot() throws {
        let context = try makeContext(freshDir())
        let pago = payment(context)
        pago.customLogoRef = PagoLogoPropioFoto.nuevaReferencia()
        let emission = EntityEmissionMap.scheduledPayment

        let v7 = DeltaEmitter.emit(model: pago, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 7)
        #expect(v7.fields["custom_logo_ref"] == .string(try #require(pago.customLogoRef)))

        let v6 = DeltaEmitter.emit(model: pago, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 6)
        #expect(v6.fields["custom_logo_ref"] == nil)
        #expect(v6.fields["name"] == .string("Colegio San Martín"), "el resto de la fila sí viaja")
    }

    @Test func emission_neverCarriesThePhotoItself() throws {
        let context = try makeContext(freshDir())
        let pago = payment(context)
        pago.customLogoData = photo(.red)
        pago.customLogoRef = PagoLogoPropioFoto.nuevaReferencia()
        let emission = EntityEmissionMap.scheduledPayment
        let v7 = DeltaEmitter.emit(model: pago, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 7)
        #expect(!emission.columns.contains { $0.contains("logo_data") })
        #expect(v7.fields.count == emission.columns.count)
    }

    @Test func drain_v6_notesThePayment_v7_sendsOnlyTheReference() throws {
        let restoreCapability = isolateCapability(backend: 6)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let pago = payment(context)
        try context.save()
        engine.drainOnce(context: context)

        ScheduledPaymentEditorViewModel.applyCustomLogo(photo(.red), to: pago)
        try context.save()
        engine.drainOnce(context: context)
        let rows = try outbox(context).filter { $0.syncID == pago.id }
        #expect(rows.count == 1, "con v6, cambiar solo la foto no saca ninguna fila")
        #expect(SyncCapability.suppressedCustomLogos == [pago.id])

        SyncCapability.defaults.set(7, forKey: SyncCapability.backendManifestVersionKey)
        ScheduledPaymentEditorViewModel.applyCustomLogo(photo(.blue), to: pago)
        try context.save()
        engine.drainOnce(context: context)
        let update = try #require(try outbox(context).last { $0.syncID == pago.id })
        #expect(Set(try fields(update).keys) == ["custom_logo_ref"], "la foto no viaja por el motor: viaja su nombre")
        #expect(try fields(update)["custom_logo_ref"] as? String == pago.customLogoRef)
    }

    // MARK: - Modo Nube: ida y vuelta

    private func page(for pago: ScheduledPayment, columns: Set<String>, counter: Int) throws -> PulledPage {
        let emission = EntityEmissionMap.scheduledPayment
        let emitted = DeltaEmitter.emit(model: pago, emission: emission, changedColumns: columns, hlc: hlc(counter),
                                        capabilityLevel: 7)
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(counter))\"" }.joined(separator: ",")
        let delta = """
        {"entity_type":"scheduled_payments","sync_id":"\(pago.id.uuidString.lowercased())","op":"upsert",\
        "fields":\(fieldsJSON),"field_hlcs":{\(hlcs)},"hlc":"\(hlc(counter))","server_seq":\(counter),"schema_version":1}
        """
        let json = "{\"deltas\":[\(delta)],\"max_server_seq\":\(counter),\"manifest_version\":7}"
        return try SyncPullClient.decodePage(Data(json.utf8))
    }

    @Test func roundTrip_aNewReferenceDropsTheOldPhoto_theEchoKeepsIt() throws {
        let restoreCapability = isolateCapability(backend: 7)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let pago = payment(phoneA)
        ScheduledPaymentEditorViewModel.applyCustomLogo(photo(.red), to: pago)
        try phoneA.save()

        let phoneB = try makeContext(freshDir())
        let engineB = CloudSyncEngine()
        #expect(engineB.applyPage(try page(for: pago, columns: EntityEmissionMap.scheduledPayment.columns, counter: 2),
                                  context: phoneB, now: applyNow))
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<ScheduledPayment>()).first { $0.id == pago.id })
        #expect(arrived.customLogoRef == pago.customLogoRef)
        #expect(arrived.customLogoData == nil, "la foto la baja la pasada de Storage, no el motor")

        // Ya bajada: el eco de la misma referencia no la suelta.
        arrived.customLogoData = photo(.red)
        try phoneB.save()
        #expect(engineB.applyPage(try page(for: pago, columns: ["custom_logo_ref"], counter: 3),
                                  context: phoneB, now: applyNow))
        #expect(arrived.customLogoData != nil)

        // Otra foto en A: B suelta la vieja hasta bajar la nueva.
        ScheduledPaymentEditorViewModel.applyCustomLogo(photo(.blue), to: pago)
        try phoneA.save()
        #expect(engineB.applyPage(try page(for: pago, columns: ["custom_logo_ref"], counter: 4),
                                  context: phoneB, now: applyNow))
        #expect(arrived.customLogoRef == pago.customLogoRef)
        #expect(arrived.customLogoData == nil)

        // Quitarla en A la quita en B.
        ScheduledPaymentEditorViewModel.applyCustomLogo(nil, to: pago)
        try phoneA.save()
        #expect(engineB.applyPage(try page(for: pago, columns: ["custom_logo_ref"], counter: 5),
                                  context: phoneB, now: applyNow))
        #expect(arrived.customLogoRef == nil && arrived.customLogoData == nil)
        #expect(arrived.name == "Colegio San Martín")
    }

    // MARK: - Modo Nube: subida de v6 a v7

    @Test func upgradeToV7_reemitsTheNotedPayment_withOnlyTheReference() throws {
        let restoreCapability = isolateCapability(backend: 6)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let pago = payment(context)
        try context.save()
        engine.drainOnce(context: context)
        ScheduledPaymentEditorViewModel.applyCustomLogo(photo(.red), to: pago)
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }
        try context.save()
        #expect(SyncCapability.suppressedCustomLogos == [pago.id])

        SyncCapability.defaults.set(6, forKey: SyncCapability.lastDeclaredLevelKey)
        SyncCapability.recordBackendManifestVersion(7)
        #expect(SyncCapability.upgradePending)
        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        let reemitted = try #require(try outbox(context).last { $0.syncID == pago.id })
        #expect(Set(try fields(reemitted).keys) == ["custom_logo_ref"])
        #expect(try fields(reemitted)["custom_logo_ref"] as? String == pago.customLogoRef)
        #expect(SyncCapability.suppressedCustomLogos.isEmpty)
    }

    // MARK: - Storage

    @Test func storagePass_uploadsHere_downloadsThere_andDeletesTheOrphan() async throws {
        let restoreCapability = isolateCapability(backend: 7)
        defer { restoreCapability() }
        let storage = FakeLogoStorage()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sync = PagoLogoPropioSync()
        sync.storage = storage
        sync.session = { ("user-1", "jwt") }

        let phoneA = try makeContext(freshDir())
        let pago = payment(phoneA)
        ScheduledPaymentEditorViewModel.applyCustomLogo(photo(.red), to: pago)
        try phoneA.save()
        let ref = try #require(pago.customLogoRef)
        storage.files["viejo.jpg".replacingOccurrences(of: "viejo", with: UUID().uuidString.lowercased())] =
            (Data([1]), now.addingTimeInterval(-3 * 24 * 3600))

        await sync.run(context: phoneA, pullComplete: true, now: now)
        #expect(storage.files[ref]?.0 == pago.customLogoData, "se subió la foto elegida aquí")
        #expect(storage.files.count == 1, "la vieja, que nadie nombra, se borró")

        // El otro teléfono recibió la referencia (sin foto) y la baja.
        let phoneB = try makeContext(freshDir())
        let copia = payment(phoneB)
        copia.customLogoRef = ref
        try phoneB.save()
        await sync.run(context: phoneB, pullComplete: true, now: now)
        #expect(copia.customLogoData == pago.customLogoData)
        #expect(storage.uploads == 1, "B no vuelve a subir lo que bajó")
    }

    /// El tope de páginas del pull sale `.completed` con la cola a medias: no cuenta como «sé todo lo que hay».
    @Test func pullCap_isNotAQueueDrained() {
        let cap = PullApplyOutcome.defaultMaxPages
        #expect(PullApplyOutcome.completed(pagesApplied: 0).drainedTheQueue())
        #expect(PullApplyOutcome.completed(pagesApplied: cap - 1).drainedTheQueue())
        #expect(!PullApplyOutcome.completed(pagesApplied: cap).drainedTheQueue())
        #expect(!PullApplyOutcome.transient(pagesApplied: 1).drainedTheQueue())
        #expect(!PullApplyOutcome.busy.drainedTheQueue())
        #expect(!PullApplyOutcome.sessionExpired.drainedTheQueue())
    }

    /// Si la lista de Storage falla, la pasada no sube, no baja y no borra nada.
    @Test func storagePass_whenTheListingFails_touchesNothing() async throws {
        let restoreCapability = isolateCapability(backend: 7)
        defer { restoreCapability() }
        let storage = FakeLogoStorage()
        storage.listFails = true
        let sync = PagoLogoPropioSync()
        sync.storage = storage
        sync.session = { ("user-1", "jwt") }
        let context = try makeContext(freshDir())
        let pago = payment(context)
        ScheduledPaymentEditorViewModel.applyCustomLogo(photo(.red), to: pago)
        let otro = payment(context, name: "Alquiler")
        otro.customLogoRef = PagoLogoPropioFoto.nuevaReferencia()
        try context.save()
        await sync.run(context: context, pullComplete: true, now: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(storage.uploads == 0 && storage.downloads == 0 && storage.deletes == 0)
        #expect(otro.customLogoData == nil)
    }

    /// Con un Worker v6 este teléfono no recibe referencias: las fotos de la carpeta no son huérfanas, son de otro.
    @Test func storagePass_withTheWorkerAtV6_neverDeletes() async throws {
        let restoreCapability = isolateCapability(backend: 6)
        defer { restoreCapability() }
        let storage = FakeLogoStorage()
        let other = PagoLogoPropioFoto.nuevaReferencia()
        storage.files[other] = (Data([1]), Date(timeIntervalSince1970: 1_700_000_000))
        let sync = PagoLogoPropioSync()
        sync.storage = storage
        sync.session = { ("user-1", "jwt") }
        let context = try makeContext(freshDir())
        _ = payment(context)
        try context.save()
        await sync.run(context: context, pullComplete: true, now: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(storage.files[other] != nil)
    }

    @Test func storagePass_aDownloadThatIsNotAnImage_isNotStored() async throws {
        let storage = FakeLogoStorage()
        let sync = PagoLogoPropioSync()
        sync.storage = storage
        sync.session = { ("user-1", "jwt") }
        let context = try makeContext(freshDir())
        let pago = payment(context)
        let ref = PagoLogoPropioFoto.nuevaReferencia()
        pago.customLogoRef = ref
        try context.save()
        storage.files[ref] = (Data("<html>".utf8), Date())
        await sync.run(context: context, pullComplete: true)
        #expect(pago.customLogoData == nil)
    }

    @Test func storagePass_givesAReferenceToAPhotoThatCameFromICloud_evenOffline() async throws {
        let sync = PagoLogoPropioSync()
        sync.storage = FakeLogoStorage()
        sync.session = { nil }
        let context = try makeContext(freshDir())
        let pago = payment(context)
        pago.customLogoData = photo(.red)
        try context.save()
        await sync.run(context: context, pullComplete: false)
        #expect(pago.customLogoRef.map(PagoLogoPropioFoto.esReferenciaValida) == true)
    }

    @Test func deleteAll_emptiesTheUsersFolder() async {
        let storage = FakeLogoStorage()
        storage.files = ["a.jpg": (Data([1]), Date()), "b.jpg": (Data([2]), Date())]
        let sync = PagoLogoPropioSync()
        sync.storage = storage
        await sync.deleteAll(userID: "USER-1", token: "jwt")
        #expect(storage.files.isEmpty)
        #expect(storage.lastUserID == "user-1", "la carpeta es la del auth.uid() en minúsculas")
    }

    /// El cableado: el ciclo del motor corre la pasada y el borrado de la cuenta vacía la carpeta antes de borrarla.
    @Test func wiring_engineCycleAndAccountDeletion() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let runtime = try String(contentsOf: root.appendingPathComponent("Yala/Services/CloudSync/CloudSyncRuntime.swift"),
                                 encoding: .utf8)
        #expect(runtime.contains("PagoLogoPropioSync.shared.runIfDue(context: context, pullComplete: pullOutcome.drainedTheQueue())"))
        let deletion = try String(contentsOf: root.appendingPathComponent(
            "Yala/Services/CloudSync/AccountDeletionService.swift"), encoding: .utf8)
        let wipe = try #require(deletion.range(of: "PagoLogoPropioSync.shared.deleteAll"))
        let delete = try #require(deletion.range(of: "client.deleteAccount(jwt: jwt)"))
        #expect(wipe.lowerBound < delete.lowerBound, "la carpeta se vacía antes de borrar la cuenta")
    }
}

// MARK: - Storage de mentira

private final class FakeLogoStorage: PagoLogoPropioStorage, @unchecked Sendable {
    var files: [String: (Data, Date)] = [:]
    var uploads = 0
    var downloads = 0
    var deletes = 0
    var listFails = false
    var lastUserID: String?

    func list(userID: String, token: String) async throws -> [PagoLogoPropioPlan.Remote] {
        lastUserID = userID
        if listFails { throw PagoLogoPropioStorageError.http(503) }
        return files.map { .init(name: $0.key, createdAt: $0.value.1) }
    }
    func upload(_ data: Data, name: String, userID: String, token: String) async throws {
        uploads += 1
        files[name] = (data, Date(timeIntervalSince1970: 1_800_000_000))
    }
    func download(name: String, userID: String, token: String) async throws -> Data {
        downloads += 1
        guard let file = files[name] else { throw PagoLogoPropioStorageError.http(404) }
        return file.0
    }
    func delete(names: [String], userID: String, token: String) async throws {
        deletes += 1
        lastUserID = userID
        for name in names { files[name] = nil }
    }
}
