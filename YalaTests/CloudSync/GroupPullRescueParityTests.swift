//
//  GroupPullRescueParityTests.swift
//  YalaTests / CloudSync
//
//  C-4 (PIEZA 2): el cruce entre los DOS namespaces que el rescate atraviesa.
//
//  EL FALLO QUE ATAN. Lo ADOPTABLE se decide con `CKConstants.RecordType` (namespace CloudKit); lo
//  EMISIBLE al backend, con `GroupEntityEmissionMap.emittableGroupEntityNames` (nombres de clase
//  `@Model`). Si divergen, el rescate inserta dinero que el drain descarta EN SILENCIO: la fila queda
//  local, nunca sube, y el usuario no ve ni un error. Es el peor fallo posible de esta feature —
//  indistinguible del bug que viene a arreglar— y sin este test sería mudo.
//
//  La trampa es real, no teórica: los dos namespaces NO coinciden. `GroupMeta` (record type) es
//  `SplitGroup` (clase). Un futuro «pues añadamos también el grupo» cruzaría la asimetría sin avisar.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("GroupPullRescueGate · paridad de los dos namespaces")
struct GroupPullRescueParityTests {

    /// Toda clase que el rescate puede insertar TIENE que ser emisible por el drain del canal backend.
    @Test func everyRescuableTypeIsEmittableByTheBackendDrain() {
        for (recordType, entityName) in GroupPullRescueGate.rescuableTypes {
            #expect(
                GroupEntityEmissionMap.emittableGroupEntityNames.contains(entityName),
                "El rescate adoptaría \(recordType) → \(entityName), pero el drain no lo emite: la fila quedaría local para siempre")
        }
    }

    /// La columna izquierda son record types que CloudKit entrega de verdad (no literales inventados).
    @Test func everyRescuableTypeIsARealCloudKitRecordType() {
        let known: Set<String> = [
            CKConstants.RecordType.groupMeta,
            CKConstants.RecordType.splitExpense,
            CKConstants.RecordType.splitMember,
            CKConstants.RecordType.splitShare,
            CKConstants.RecordType.splitSettlement,
        ]
        for recordType in GroupPullRescueGate.rescuableTypes.keys {
            #expect(known.contains(recordType), "\(recordType) no es un record type del container de grupos")
        }
    }

    /// Invariante 3, la mitad de `SplitMember`: es PULL-ONLY. Adoptarlo insertaría filas que el drain
    /// descarta sin decir nada — el fallo mudo en su forma más pura.
    @Test func splitMemberIsNotRescuable_itIsPullOnly() {
        #expect(GroupPullRescueGate.entityName(forRecordType: CKConstants.RecordType.splitMember) == nil)
        #expect(!GroupEntityEmissionMap.emittableGroupEntityNames.contains(GroupSyncEntityType.splitMember))
    }

    /// Invariante 3, la mitad de `GroupMeta`: el grupo existe por definición (es lo que pone la zona en
    /// `backendZoneNames`), así que adoptarlo solo podría significar aplicar meta stale.
    ///
    /// El segundo `#expect` es el que importa de verdad: NOMBRA la asimetría de namespaces. Si algún día
    /// los dos nombres convergen, este test se pone rojo y obliga a releer el invariante en vez de dejar
    /// que alguien añada `GroupMeta` al mapa creyendo que `"GroupMeta"` es también el nombre de la clase.
    @Test func groupMetaIsNotRescuable_andItsNamespacesDiffer() {
        #expect(GroupPullRescueGate.entityName(forRecordType: CKConstants.RecordType.groupMeta) == nil)
        #expect(
            CKConstants.RecordType.groupMeta != GroupSyncEntityType.splitGroup,
            "Record type y nombre de clase del grupo dejaron de diferir: releer el invariante 3 antes de tocar rescuableTypes")
    }

    /// Los tres rescatables son exactamente los del dinero de un grupo: gasto, reparto y liquidación.
    @Test func theRescuableSetIsExactlyTheMoney() {
        #expect(Set(GroupPullRescueGate.rescuableTypes.keys) == [
            CKConstants.RecordType.splitExpense,
            CKConstants.RecordType.splitShare,
            CKConstants.RecordType.splitSettlement,
        ])
    }
}
