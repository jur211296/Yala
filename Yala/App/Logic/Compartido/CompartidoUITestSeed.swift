//
//  CompartidoUITestSeed.swift
//  Yala
//
//  Compartido (lote 3): una persona sembrada en local para XCUITest y capturas (`-uitest-seed-compartido-persona`). La de
//  verdad nace en el servidor (`create_person_group`), que un XCUITest no alcanza; esta tiene la misma forma: un grupo de
//  dos con `isPerson`, el miembro propio y el sitio reservado «Marta» sin cuenta. Solo DEBUG y solo bajo `-uitest`.
//

import Foundation
import SwiftData

#if DEBUG
@MainActor
enum CompartidoUITestSeed {

    static var isRequested: Bool {
        UITestHooks.isActive && ProcessInfo.processInfo.arguments.contains("-uitest-seed-compartido-persona")
    }

    /// Siembra a «Marta» una vez (si ya hay una persona, no hace nada).
    static func plantIfRequested(context: ModelContext) {
        guard isRequested else { return }
        do {
            let people = try context.fetch(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.isPerson == true }))
            guard people.isEmpty else { return }
            let person = SplitGroup(name: "Marta", iconName: "person.fill",
                                    colorHex: CompartidoPersonaAltaLogic.colorHex(for: "Marta"),
                                    currencyCode: "PEN", isOwner: true)
            person.isBackendGroup = true
            person.isPerson = true
            context.insert(person)
            let me = SplitMember(groupZoneID: person.cloudKitZoneID, displayName: "Jürgen", role: "admin",
                                 status: .active, isGroupOwner: true, isCurrentUser: true)
            let seat = SplitMember(groupZoneID: person.cloudKitZoneID, displayName: "Marta", role: "member",
                                   status: .active)
            seat.memberKey = "seat-marta"
            context.insert(me)
            context.insert(seat)
            try context.save()
        } catch {
            print("CompartidoUITestSeed: Error: \(error)")
        }
    }
}
#endif
