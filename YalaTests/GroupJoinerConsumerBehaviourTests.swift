//
//  GroupJoinerConsumerBehaviourTests.swift
//  YalaTests
//
//  Lo que la review adversarial del 2026-09-05 dejó claro: `GroupJoinerIdentityConsumerTests` valida
//  que el cambio SE APLICÓ (que ningún consumidor resuelve identidad con el flag pelado), no lo que el
//  cambio HACE. Los tres casos de abajo son los que se escaparon por ese hueco, y los tres son la
//  misma familia: **el resolvedor canónico devuelve UNA fila por zona, mientras el flag pelado
//  devolvía TODAS las que lo tuvieran, y no filtra por estado.**
//
//  Sustituir uno por otro sin pensar en esas dos diferencias produce cambios de comportamiento que no
//  se ven en un source-scan y que empeoran justo al usuario que el arreglo venía a atender.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · lo que hace la identidad resuelta en cada consumidor", .serialized)
@MainActor
struct GroupJoinerConsumerBehaviourTests {

    private static func fechaVencida() -> Date {
        var c = DateComponents(); c.year = 2020; c.month = 1; c.day = 15; c.hour = 12
        return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 1_579_000_000)
    }

    // MARK: - El pago programado de quien espera aprobación

    /// A quien está `pendingApproval` NO se le apaga su pago recurrente del grupo.
    ///
    /// El gate solo distingue «existe» de «está activo», y su rama de no-activo es `.pause`, que
    /// escribe `payment.isActive = false` y no lo vuelve a encender nadie. Antes de resolver la
    /// identidad, el member del pendiente no se encontraba y el gate reintentaba; al resolverlo, sin
    /// guard, el arreglo le habría APAGADO el pago. El propio comentario del gate dice a quién quiere
    /// pausar: «removido/salido».
    @Test("un miembro pendiente de aprobación no pierde su pago programado")
    func pendienteNoPierdeSuPagoProgramado() throws {
        let context = try makeTestContext()
        iCloudSyncService.shared._testReset()
        defer { iCloudSyncService.shared._testReset() }

        let zone = "SplitGroup-PENDIENTE"
        let group = SplitGroup(name: "Casa", isOwner: false)
        group.cloudKitZoneID = zone
        context.insert(group)

        // El recién llegado: SIN el flag (así lo deja el pull) y todavía esperando al admin.
        let yo = SplitMember(groupZoneID: zone, displayName: "Yo",
                             cloudKitUserRecordID: "_yo", status: .pendingApproval)
        context.insert(yo)

        let pago = ScheduledPayment(name: "Internet", amount: 50, currencyCode: "PEN",
                                    transactionType: "expense",
                                    nextDueDate: Self.fechaVencida(), isActive: true)
        pago.groupZoneID = zone
        pago.splitTotalAmount = 100
        pago.splitType = "exact"
        context.insert(pago)
        try context.save()

        let recordPrevio = GroupUserIdentityService.shared.cachedRecordName
        GroupUserIdentityService.shared._testSetCachedRecordName("_yo")
        defer { GroupUserIdentityService.shared._testSetCachedRecordName(recordPrevio) }

        _ = ScheduledPaymentDraftService.processDuePayments(context: context)

        #expect(pago.isActive, """
            El pago programado quedó DESACTIVADO para un miembro que solo está esperando aprobación.
            `.pause` escribe `isActive = false` de forma persistente y nada lo re-activa cuando el
            admin aprueba: el usuario tendría que volver a crearlo a mano. Un pendiente es «todavía no
            se sabe» (`.retryLater`), no «removido o salido» (`.pause`).
            """)
    }

    /// El otro lado del mismo guard: a quien SÍ fue expulsado se le sigue pausando. Sin esto, el
    /// arreglo de arriba podría haberse escrito como «no pausar nunca» y nadie se enteraría.
    @Test("a quien expulsaron del grupo sí se le pausa el pago")
    func expulsadoSiPierdeElPago() throws {
        let context = try makeTestContext()
        iCloudSyncService.shared._testReset()
        defer { iCloudSyncService.shared._testReset() }

        let zone = "SplitGroup-EXPULSADO"
        let group = SplitGroup(name: "Casa", isOwner: false)
        group.cloudKitZoneID = zone
        context.insert(group)
        context.insert(SplitMember(groupZoneID: zone, displayName: "Yo",
                                   cloudKitUserRecordID: "_yo", status: .removed))

        let pago = ScheduledPayment(name: "Internet", amount: 50, currencyCode: "PEN",
                                    transactionType: "expense",
                                    nextDueDate: Self.fechaVencida(), isActive: true)
        pago.groupZoneID = zone
        pago.splitTotalAmount = 100
        pago.splitType = "exact"
        context.insert(pago)
        try context.save()

        let recordPrevio = GroupUserIdentityService.shared.cachedRecordName
        GroupUserIdentityService.shared._testSetCachedRecordName("_yo")
        defer { GroupUserIdentityService.shared._testSetCachedRecordName(recordPrevio) }

        _ = ScheduledPaymentDraftService.processDuePayments(context: context)

        #expect(!pago.isActive, """
            A un miembro `removed` hay que pausarle el pago del grupo: seguir generando borradores de
            un grupo del que lo echaron es basura en su Inbox. Si esto falla, el guard del pendiente se
            escribió demasiado ancho.
            """)
    }

    // MARK: - El prefill de «Pagado por» con dos filas mías

    /// Resolver SOBRE LOS ACTIVOS no es lo mismo que resolver y filtrar después.
    ///
    /// En una zona migrada el mismo humano puede tener dos filas. Si la más antigua está inactiva, el
    /// canónico la elige —desempata por `joinedAt`, no por estado— y un filtro posterior la convierte
    /// en «no hay nadie»: el formulario abriría EN BLANCO, que es el síntoma exacto que el arreglo
    /// venía a quitar.
    @Test("con una fila mía vieja e inactiva, «Pagado por» viene puesto en la activa")
    func prefillEligeLaFilaActiva() throws {
        let group = SplitGroup(name: "Viaje", currencyCode: "PEN")

        let viejaInactiva = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo",
                                        cloudKitUserRecordID: "_yo", status: .left)
        let nuevaActiva = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo",
                                      cloudKitUserRecordID: "_yo", status: .active)
        nuevaActiva.joinedAt = viejaInactiva.joinedAt.addingTimeInterval(60)

        let recordPrevio = GroupUserIdentityService.shared.cachedRecordName
        GroupUserIdentityService.shared._testSetCachedRecordName("_yo")
        defer { GroupUserIdentityService.shared._testSetCachedRecordName(recordPrevio) }

        let vm = GroupExpenseViewModel(
            group: group,
            members: [viejaInactiva, nuevaActiva],
            memberNameLookup: [:]
        )

        #expect(vm.paidByMemberID == nuevaActiva.id.uuidString, """
            «Pagado por» no vino puesto en mi fila activa. Con `\(vm.paidByMemberID)` vacío, el
            formulario abre en blanco; con la fila `left`, ofrece como pagador a alguien que ya no
            está en el grupo.
            """)
    }

    // MARK: - El nombre elegido en el onboarding, en una zona con dos filas mías

    /// El fetch viejo (`isCurrentUser == true`) devolvía TODAS mis filas marcadas; el canónico
    /// devuelve UNA por zona. Sustituir uno por otro dejaba al gemelo con el nombre viejo para
    /// siempre — y como el filtro de trabajo es `displayName != nuevo`, la función volvería a entrar
    /// en cada arranque sin arreglarlo nunca.
    @Test("renombrar propaga a TODAS mis filas de la zona, no solo a la canónica")
    func renombrarAlcanzaAlGemelo() async throws {
        let context = try makeTestContext()
        GroupService.shared.setContext(context)
        defer { GroupService.shared._testResetContext() }

        let recordPrevio = GroupUserIdentityService.shared.cachedRecordName
        GroupUserIdentityService.shared._testSetCachedRecordName("_yo")
        defer { GroupUserIdentityService.shared._testSetCachedRecordName(recordPrevio) }

        let group = SplitGroup(name: "Casa", isOwner: false)
        context.insert(group)
        let zone = group.cloudKitZoneID

        // Dos filas del mismo humano en la misma zona: una con el flag encendido y otra que bajó del
        // pull sin él, reconocible por la MISMA identidad de iCloud. Es el caso del 2º device o del
        // restore.
        //
        // La otra vía por la que aparece un gemelo —el `sub` del canal backend— no se puede montar
        // desde un test: `CloudAuthService.currentUserID` no tiene seam A PROPÓSITO (fingir el `sub`
        // volvería alcanzables los resolvedores con una identidad que no existe, y su docblock lo dice).
        // Esa rama la cubre `GroupIdentityResolutionAlignmentTests` por la vía pura, pasando el
        // `currentUserID` como parámetro. Lo que se prueba aquí es que el consumidor NO COLAPSA, y eso
        // es independiente de por cuál de las tres identidades se reconozca cada fila.
        let conFlag = SplitMember(groupZoneID: zone, displayName: "Nombre viejo",
                                  cloudKitUserRecordID: "_yo", isCurrentUser: true)
        let gemelo = SplitMember(groupZoneID: zone, displayName: "Nombre viejo",
                                 cloudKitUserRecordID: "_yo")
        gemelo.joinedAt = conFlag.joinedAt.addingTimeInterval(60)
        context.insert(conFlag)
        context.insert(gemelo)
        try context.save()

        try await GroupService.shared.updateCurrentUserDisplayName("Nombre nuevo")

        #expect(conFlag.displayName == "Nombre nuevo")
        #expect(gemelo.displayName == "Nombre nuevo", """
            El gemelo se quedó con «\(gemelo.displayName)». Quedarse solo con la fila canónica deja al
            otro con el nombre viejo de forma permanente, y esta función reintenta en cada arranque sin
            converger nunca.
            """)
    }
}
