//
//  GroupJoinerBridgeReachesRealAccountTests.swift
//  YalaTests
//
//  La demostración con dinero de por medio: el gasto de quien acaba de unirse a un grupo llega a su
//  CUENTA REAL en el mismo gesto que lo crea, sin necesidad de relanzar la app.
//
//  El bug. `SplitMember.isCurrentUser` es device-local: `GroupsSyncClient.applyMember` no lo escribe
//  nunca y en producción solo lo enciende `refreshCurrentUserFlags`, cuyo único call-site está en el
//  ARRANQUE. `GroupTransactionBridge` resolvía «quién soy yo» con ese flag metido en un `#Predicate`,
//  así que a quien se unía por enlace en sesión viva no lo encontraba y devolvía `false` sin crear
//  nada. El gasto se quedaba fuera de sus cuentas hasta el arranque siguiente, y cuando
//  `GroupsPendingBridgeResume` lo repescaba allí, corría con `accountForCurrentUser: nil` y aterrizaba
//  en la cuenta virtual «Grupos» — la cuenta real elegida en el formulario se perdía.
//
//  Los dos tests son un par: el positivo prueba que con la identidad resuelta el dinero llega a la
//  cuenta real, y el negativo prueba que el instrumento sabe fallar. Sin el segundo, el primero podría
//  estar pasando por cualquier otro motivo.
//
//  Molde del montaje (heredado de `GroupBridgeCloudSyncIntegrationTests`, y sus tres razones):
//  container ON-DISK con los tres stores porque el History es por-container; `shouldSave: false` con
//  save manual, porque los side-effects de `saveIfNeeded` son la causa de la blacklist R8; y
//  `.serialized` porque el bridge es un singleton compartido.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · el gasto del recién llegado llega a su cuenta real", .serialized)
@MainActor
struct GroupJoinerBridgeReachesRealAccountTests {

    // MARK: - Montaje

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("JoinerBridge-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "JB-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "JB-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "JB-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    private struct Escena {
        let group: SplitGroup
        let expense: SplitExpense
        let cuentaReal: Account
    }

    /// El estado EXACTO del recién llegado: su `SplitMember` existe y está activo, pero con
    /// `isCurrentUser` APAGADO — que es como lo deja el pull. Su única identidad es la de iCloud
    /// (`cloudKitUserRecordID`), la misma que el resolvedor canónico usa como tercera vía.
    private func montarGastoDelJoiner(_ context: ModelContext, recordName: String) throws -> Escena {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        context.insert(group)

        let yo = SplitMember(
            groupZoneID: group.cloudKitZoneID,
            displayName: "Yo",
            cloudKitUserRecordID: recordName,
            isCurrentUser: false          // ← el corazón del caso
        )
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(yo)
        context.insert(ana)

        let cuentaReal = Account(
            name: "Efectivo", currencyCode: "USD", colorHex: "#111111",
            iconName: "banknote", type: "cash"
        )
        context.insert(cuentaReal)

        // Caso A: lo pago yo, mitad y mitad.
        let expense = SplitExpense(
            groupZoneID: group.cloudKitZoneID,
            amount: 100,
            currencyCode: "USD",
            expenseDescription: "Cena",
            paidByMemberID: yo.id.uuidString
        )
        context.insert(expense)
        for (miembro, monto) in [(yo, 50.0), (ana, 50.0)] {
            context.insert(SplitShare(
                expenseID: expense.id, memberID: miembro.id.uuidString,
                amount: monto, groupZoneID: group.cloudKitZoneID
            ))
        }
        try context.save()
        return Escena(group: group, expense: expense, cuentaReal: cuentaReal)
    }

    private func conEntornoDeBridge(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        let modoPrevio = SessionState.shared.onboardingMode
        SessionState.shared.onboardingMode = .full   // Caso A real exige != .groupInvite
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.onboardingMode = modoPrevio
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    private func transacciones(de expense: SplitExpense, in context: ModelContext) throws -> [TransactionItem] {
        let id = expense.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == id }
        ))
    }

    // MARK: - El caso

    @Test("con la identidad resuelta, el gasto aterriza en la cuenta real elegida")
    func elGastoLlegaALaCuentaReal() throws {
        let dir = freshDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)

        let recordNamePrevio = GroupUserIdentityService.shared.cachedRecordName
        GroupUserIdentityService.shared._testSetCachedRecordName("_joiner")
        defer { GroupUserIdentityService.shared._testSetCachedRecordName(recordNamePrevio) }

        let escena = try montarGastoDelJoiner(context, recordName: "_joiner")

        try conEntornoDeBridge(context) {
            let atendido = try GroupTransactionBridge.shared.bridgeExpense(
                escena.expense, in: escena.group,
                accountForCurrentUser: escena.cuentaReal,
                shouldSave: false
            )
            try context.save()

            #expect(atendido, """
                El bridge no dio por atendido el gasto del recién llegado. Antes de este arreglo
                devolvía `false` aquí: resolvía identidad con `isCurrentUser`, que el pull no enciende.
                """)

            let txs = try transacciones(de: escena.expense, in: context)
            let enCuentaReal = txs.filter { $0.account?.isSystemAccount == false }
            #expect(enCuentaReal.count == 1, """
                Se esperaba UNA transacción en cuenta real y hay \\(enCuentaReal.count).
                Total de transacciones puenteadas: \\(txs.count).
                """)
            #expect(enCuentaReal.first?.account?.id == escena.cuentaReal.id, """
                La transacción no fue a la cuenta que el usuario eligió en el formulario. Si aterrizó
                en la cuenta de sistema «Grupos», es el síntoma exacto del ticket: el repesque tardío
                corre con `accountForCurrentUser: nil` y pierde la cuenta real.
                """)
        }
    }

    /// CONTROL NEGATIVO del instrumento. Sin ninguna de las tres identidades —ni flag, ni `sub`, ni
    /// `recordName`— el bridge tiene que seguir devolviendo `false` y NO crear nada: es un estado
    /// incompleto que se resolverá más tarde, y darlo por atendido desarmaría
    /// `GroupsPendingBridgeIntent`, que es lo único que evita perder el gasto para siempre.
    ///
    /// Sin este test, el positivo de arriba pasaría igual aunque el bridge creara transacciones para
    /// cualquiera.
    @Test("sin ninguna identidad, el bridge no inventa una transacción")
    func sinIdentidadNoSePuentea() throws {
        let dir = freshDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)

        let recordNamePrevio = GroupUserIdentityService.shared.cachedRecordName
        GroupUserIdentityService.shared._testSetCachedRecordName(nil)
        defer { GroupUserIdentityService.shared._testSetCachedRecordName(recordNamePrevio) }

        // El member existe y está activo, pero su `cloudKitUserRecordID` no coincide con NADA
        // conocido y el flag sigue apagado: identidad irresoluble.
        let escena = try montarGastoDelJoiner(context, recordName: "_otro-humano")

        try conEntornoDeBridge(context) {
            let atendido = try GroupTransactionBridge.shared.bridgeExpense(
                escena.expense, in: escena.group,
                accountForCurrentUser: escena.cuentaReal,
                shouldSave: false
            )
            try context.save()

            #expect(!atendido, """
                El bridge dio por ATENDIDO un gasto cuya identidad no puede resolver. Eso desarma la
                intención pendiente y el gasto no se puentea nunca — pérdida permanente.
                """)
            #expect(try transacciones(de: escena.expense, in: context).isEmpty, """
                Se creó una transacción sin saber quién es el usuario.
                """)
        }
    }
}
