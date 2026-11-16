//
//  ImportarGrupoUITestSeams.swift
//  Yala
//
//  Atajos de XCUITest y QA para «Traer un grupo de Splitwise o Tricount». Solo en DEBUG y solo con `-uitest`:
//
//  - `-uitest-import-csv <ruta>`: «Elegir archivo» lee ese archivo en vez de abrir Archivos. El selector de documentos
//    es del sistema y un XCUITest no lo conduce con fiabilidad; lo que se prueba es lo que pasa DESPUÉS de elegir.
//  - `-uitest-import-pending`: al abrir un grupo que gestionas sin nada pendiente, se apunta un import de Splitwise con
//    tu nombre, el del primer otro miembro y una persona que aún no se unió («Carla»). No decide nada: solo siembra lo
//    que dejaría un import real al crear el grupo, para probar el aviso y el emparejamiento sin servidor.
//
//  Viven aquí y no en `UITestHooks` para no tocar ese fichero desde este encargo.
//

import Foundation

enum ImportarGrupoUITestSeams {

    #if DEBUG
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }
    private static var isUITest: Bool { arguments.contains("-uitest") }

    /// La ruta del CSV que «Elegir archivo» lee sin abrir Archivos, o `nil`.
    static var csvPath: String? {
        guard isUITest, let index = arguments.firstIndex(of: "-uitest-import-csv"), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    static var seedsPending: Bool { isUITest && arguments.contains("-uitest-import-pending") }

    /// Siembra lo que espera para `group` si no hay nada: tú con +120, el primer otro miembro con −50 y Carla con −70.
    @MainActor
    static func seedPendingIfRequested(group: SplitGroup, activeMembers: [SplitMember]) {
        guard seedsPending else { return }
        let zoneID = group.cloudKitZoneID
        let store = PendingGroupImportStore.shared
        guard store.pending(for: zoneID) == nil,
              let me = activeMembers.first(where: \.isCurrentUser),
              let other = activeMembers.first(where: { !$0.isCurrentUser }) else { return }
        let myName = me.displayName.isEmpty ? "Yo" : me.displayName
        let balances = ["PEN": [myName: 12_000, other.displayName: -5_000, "Carla": -7_000]]
        store.save(PendingGroupImport(
            zoneID: zoneID,
            source: .splitwise,
            people: [myName, other.displayName, "Carla"],
            balances: balances,
            debts: ImportedDebtPlanLogic.debts(from: balances),
            mapping: [myName: me.id.uuidString],
            applied: [],
            createdAt: .now
        ))
    }
    #else
    static var csvPath: String? { nil }
    static var seedsPending: Bool { false }
    @MainActor
    static func seedPendingIfRequested(group: SplitGroup, activeMembers: [SplitMember]) {}
    #endif
}
