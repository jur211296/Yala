//
//  DevSeedGroups.swift
//  Yala
//
//  Seed dev de un grupo de gastos compartidos (perfiles `.grupos` / `.gruposInvitado`). Datos LOCALES
//  (sin CKShare ni zona real): los modelos Split* se enlazan por IDs string
//  (groupZoneID / memberID / expenseID), así que el tab Grupos los muestra desde
//  SwiftData directo. El sync (SplitSyncManager) está gateado en modo uitest, por
//  lo que estos records no se suben a CloudKit.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedGroups {
    static func create(in context: ModelContext) {
        // 1. Grupo (yo soy owner)
        let group = SplitGroup(
            name: "Viaje a Cusco",
            iconName: "airplane",
            currencyCode: "PEN",
            isOwner: true
        )
        context.insert(group)
        let zoneID = group.cloudKitZoneID

        // 2. Miembros: tú + 2 amigos (todos activos)
        let me = SplitMember(
            groupZoneID: zoneID, displayName: "Tú",
            cloudKitUserRecordID: "uitest-current-user",
            role: "admin", status: .active, isGroupOwner: true, isCurrentUser: true
        )
        let ana = SplitMember(
            groupZoneID: zoneID, displayName: "Ana",
            cloudKitUserRecordID: "uitest-member-ana", status: .active
        )
        let beto = SplitMember(
            groupZoneID: zoneID, displayName: "Beto",
            cloudKitUserRecordID: "uitest-member-beto", status: .active
        )
        let members = [me, ana, beto]
        for m in members { context.insert(m) }
        let memberIDs = members.map { $0.id.uuidString }

        // 3. Gastos + shares (split equal entre los 3). Distribuidos en 4 meses (día 15 de
        //    cada mes) y mezclando PEN + USD + subcategorías reales para ejercitar
        //    balances/stats multi-moneda, el donut por subcategoría y la TENDENCIA mensual
        //    del carrusel del modo "Todas" (≥2 puntos por moneda → el chart de tendencia
        //    se renderiza en ambas páginas).
        let cal = Calendar.current
        func monthsAgo(_ n: Int) -> Date {
            let base = cal.date(byAdding: .month, value: -n, to: Date.now) ?? Date.now
            let comps = cal.dateComponents([.year, .month], from: base)
            return cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 15)) ?? base
        }
        let expenses: [(desc: String, amount: Double, currency: String, payer: SplitMember, subcat: String?, monthsAgo: Int)] = [
            // Hace 3 meses
            ("Hospedaje", 600, "PEN", me, "Alojamiento", 3),
            ("Tour guiado", 150, "USD", ana, "Entretenimiento", 3),
            // Hace 2 meses
            ("Cena grupal", 240, "PEN", ana, "Restaurantes", 2),
            ("Taxi aeropuerto", 50, "USD", beto, "Transporte", 2),
            // Hace 1 mes
            ("Almuerzo criollo", 180, "PEN", beto, "Restaurantes", 1),
            ("Entradas museo", 90, "USD", me, "Entretenimiento", 1),
            // Este mes
            ("Transporte", 90, "PEN", beto, "Transporte", 0),
            ("Mercado", 120, "PEN", ana, "Compras", 0),
            ("Souvenirs", 80, "USD", me, "Compras", 0),
        ]
        for e in expenses {
            let expense = SplitExpense(
                groupZoneID: zoneID, amount: e.amount, currencyCode: e.currency,
                expenseDescription: e.desc, paidByMemberID: e.payer.id.uuidString,
                splitType: "equal",
                subcategoryName: e.subcat
            )
            expense.date = monthsAgo(e.monthsAgo)
            context.insert(expense)
            let perHead = ((e.amount / Double(memberIDs.count)) * 100).rounded() / 100
            for mid in memberIDs {
                let share = SplitShare(
                    expenseID: expense.id, memberID: mid, amount: perHead,
                    isPaid: mid == e.payer.id.uuidString, groupZoneID: zoneID
                )
                context.insert(share)
            }
        }

        // ── 2º grupo "Viaje a Lima" (yo owner/activo). Habilita el chip EDITABLE del
        //    composer "Nuevo gasto" (>1 grupo elegible) y el cambio de grupo en el picker.
        //    Ordena DESPUÉS de "Viaje a Cusco" (Cusco < Lima) → no altera el primer
        //    `group_card` que tapean los smoke tests de gasto/borrado.
        let group2 = SplitGroup(
            name: "Viaje a Lima",
            iconName: "airplane",
            currencyCode: "PEN",
            isOwner: true
        )
        context.insert(group2)
        let zone2 = group2.cloudKitZoneID
        let me2 = SplitMember(
            groupZoneID: zone2, displayName: "Tú",
            cloudKitUserRecordID: "uitest-current-user",
            role: "admin", status: .active, isGroupOwner: true, isCurrentUser: true
        )
        let caro = SplitMember(
            groupZoneID: zone2, displayName: "Caro",
            cloudKitUserRecordID: "uitest-member-caro", status: .active
        )
        for m in [me2, caro] { context.insert(m) }
        let member2IDs = [me2, caro].map { $0.id.uuidString }
        let expenses2: [(desc: String, amount: Double, payer: SplitMember, subcat: String?, monthsAgo: Int)] = [
            ("Hotel Miraflores", 400, me2, "Alojamiento", 1),
            ("Ceviche", 120, caro, "Restaurantes", 0),
        ]
        for e in expenses2 {
            let expense = SplitExpense(
                groupZoneID: zone2, amount: e.amount, currencyCode: "PEN",
                expenseDescription: e.desc, paidByMemberID: e.payer.id.uuidString,
                splitType: "equal",
                subcategoryName: e.subcat
            )
            expense.date = monthsAgo(e.monthsAgo)
            context.insert(expense)
            let perHead = ((e.amount / Double(member2IDs.count)) * 100).rounded() / 100
            for mid in member2IDs {
                let share = SplitShare(
                    expenseID: expense.id, memberID: mid, amount: perHead,
                    isPaid: mid == e.payer.id.uuidString, groupZoneID: zone2
                )
                context.insert(share)
            }
        }

        do {
            try context.save()
        } catch {
            print("DevSeedGroups: save error: \(error)")
        }
    }

    /// Variante invitado (perfil `.gruposInvitado`): el MISMO grupo "Viaje a Cusco" pero
    /// desde la perspectiva de un miembro NO-owner recién unido — simula el 2º usuario
    /// cross-device SALTANDO el accept de CKShare (imposible en sim). "Tú" es
    /// `isCurrentUser` pero NO owner/admin; Ana es la owner/admin. Los montos dejan al
    /// usuario actual como DEUDOR neto (debe 260 a Ana + 10 a Beto) → habilita QA del
    /// Caso C (yo pago una liquidación → opt-in con bridge OFF), imposible con `create`
    /// (ahí soy acreedor). Incluye 1 gasto propio ("Souvenirs", Caso A del invitado).
    /// Combinable con `-uitest-group-invite`: CON el flag actúo como usuario solo-grupos
    /// (par virtual M5); SIN él, como usuario completo que es miembro no-owner.
    /// Igual que `create`: datos LOCALES sin CKShare/zona (el sync uitest está gateado).
    static func createAsInvitee(in context: ModelContext) {
        // 1. Grupo (NO soy owner — me uní por invitación)
        let group = SplitGroup(
            name: "Viaje a Cusco",
            iconName: "airplane",
            currencyCode: "PEN",
            isOwner: false
        )
        context.insert(group)
        let zoneID = group.cloudKitZoneID

        // 2. Miembros: Ana (owner/admin), tú (invitado activo, no-owner), Beto. Todos activos.
        let ana = SplitMember(
            groupZoneID: zoneID, displayName: "Ana",
            cloudKitUserRecordID: "uitest-member-ana",
            role: "admin", status: .active, isGroupOwner: true
        )
        let me = SplitMember(
            groupZoneID: zoneID, displayName: "Tú",
            cloudKitUserRecordID: "uitest-current-user",
            status: .active, isCurrentUser: true
        )
        let beto = SplitMember(
            groupZoneID: zoneID, displayName: "Beto",
            cloudKitUserRecordID: "uitest-member-beto", status: .active
        )
        let members = [ana, me, beto]
        for m in members { context.insert(m) }
        let memberIDs = members.map { $0.id.uuidString }

        // 3. Gastos + shares (split equal entre los 3). Configurados para que el usuario
        //    actual ("Tú") quede DEUDOR neto: Ana/Beto pagan casi todo (Caso B) y un único
        //    gasto propio ("Souvenirs", Caso A del invitado) deja a los otros debiéndome poco.
        //    Net tras simplificar: debo 260 a Ana + 10 a Beto (montos exactos, sin redondeo).
        let expenses: [(desc: String, amount: Double, payer: SplitMember)] = [
            ("Hospedaje", 600, ana),     // Caso B: Ana pagó → debo 200 a Ana
            ("Cena grupal", 240, ana),   // Caso B: Ana pagó → debo 80 a Ana
            ("Transporte", 90, beto),    // Caso B: Beto pagó → debo 30 a Beto
            ("Souvenirs", 60, me),       // Caso A (yo pagué) → me deben 20 c/u
        ]
        for e in expenses {
            let expense = SplitExpense(
                groupZoneID: zoneID, amount: e.amount, currencyCode: "PEN",
                expenseDescription: e.desc, paidByMemberID: e.payer.id.uuidString,
                splitType: "equal"
            )
            context.insert(expense)
            let perHead = ((e.amount / Double(memberIDs.count)) * 100).rounded() / 100
            for mid in memberIDs {
                let share = SplitShare(
                    expenseID: expense.id, memberID: mid, amount: perHead,
                    isPaid: mid == e.payer.id.uuidString, groupZoneID: zoneID
                )
                context.insert(share)
            }
        }

        do {
            try context.save()
        } catch {
            print("DevSeedGroups: createAsInvitee save error: \(error)")
        }
    }

    /// Borra TODOS los modelos de grupos (Split* + GroupBridgePreference) del store local.
    /// Lo usa el reset del modo uitest: `DataWipeService.wipeAllUserData` los preserva a
    /// propósito (decisión de producto — los grupos son compartidos vía CloudKit y el
    /// usuario los abandona, no los borra). Sin esto, re-sembrar el perfil `.grupos`
    /// apilaría un "Viaje a Cusco" duplicado encima del residual de la corrida anterior.
    /// Los Split* no tienen `@Relationship` entre sí (se enlazan por `groupZoneID`), así
    /// que el orden de borrado es indiferente.
    static func reset(in context: ModelContext) {
        deleteAll(SplitShare.self, in: context)
        deleteAll(SplitExpense.self, in: context)
        deleteAll(SplitSettlement.self, in: context)
        deleteAll(SplitMember.self, in: context)
        deleteAll(SplitGroup.self, in: context)
        deleteAll(GroupBridgePreference.self, in: context)
        do {
            try context.save()
        } catch {
            print("DevSeedGroups: reset save error: \(error)")
        }
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        do {
            try context.delete(model: T.self)
        } catch {
            print("DevSeedGroups: Error deleting \(T.self): \(error)")
        }
    }
}
#endif
