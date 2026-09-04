//
//  DevSeedGroups.swift
//  Yala
//
//  Seed dev de un grupo de gastos compartidos (perfiles `.grupos` / `.gruposInvitado` /
//  `.gruposSaldado`). Datos LOCALES
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
        // C3: del canal BACKEND, como todo grupo que puede nacer hoy. Sin esto el seed acuña grupos LEGACY
        // (el default del modelo es `false`, `SplitGroup:52`) y `LegacyGroupsRetirement` los oculta en el
        // arranque siguiente ⇒ los XCUITest de Grupos se quedan sin datos. Ver `devSeed_createsBackendGroups`.
        group.isBackendGroup = true
        context.insert(group)
        let zoneID = group.cloudKitZoneID

        // XCUI de deep link en cold launch: publica el id del PRIMER grupo sembrado para
        // que `-uitest-deeplink-url yala://groups/seeded-first` lo resuelva a un id real en
        // una corrida posterior (el store uitest persiste en disco → 2 launches). El router
        // resuelve `.groupDetail(groupID:)` como `UUID` contra `SplitGroup.id`
        // (GroupsContainerView.openPendingGroupIfAvailable), por eso se expone `id`, NO el zoneID.
        if UITestHooks.isActive {
            UserDefaults.standard.set(group.id.uuidString, forKey: UITestHooks.seededGroupIDKey)
        }

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
        group2.isBackendGroup = true  // C3: ver el porqué en el primer grupo.
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

    /// Variante SALDADA (perfil `.gruposSaldado`): el MISMO dataset de `create` (2 grupos, multi-moneda,
    /// yo owner) MÁS las liquidaciones CONFIRMADAS que dejan el neto del usuario actual en CERO en todos
    /// sus grupos y monedas. Es el único perfil con grupos VIVOS y SIN deuda, que es el estado que ofrece
    /// el batch D10 "También salir de mis grupos" de la hoja de Vaciar (`canLeaveAllGroups` exige
    /// `hasGroups && !hasOutstandingDebt`): `create` deja al usuario acreedor por construcción (+190 PEN y
    /// +46,66 USD en Cusco, +140 PEN en Lima) y `createAsInvitee` lo deja deudor, así que ninguno de los
    /// dos ejercita esa rama.
    ///
    /// Los montos NO están hardcodeados: se derivan de los balances REALES de `GroupBalanceService`, así
    /// que editar la lista de gastos de `create` no rompe el invariante "neto del usuario = 0". El usuario
    /// se liquida PRIMERO (cero exacto garantizado); con lo que queda se cuadra al resto entre sí, donde sí
    /// puede quedar un residuo de céntimos del redondeo de las shares (`600/3` cuadra, `50/3` no).
    /// Igual que `create`: datos LOCALES sin CKShare/zona (el sync uitest está gateado).
    static func createSettled(in context: ModelContext) {
        create(in: context)
        do {
            for group in try context.fetch(FetchDescriptor<SplitGroup>()) {
                let zoneID = group.cloudKitZoneID
                let members = try context.fetch(FetchDescriptor<SplitMember>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let expenses = try context.fetch(FetchDescriptor<SplitExpense>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let shares = try context.fetch(FetchDescriptor<SplitShare>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let settlements = try context.fetch(FetchDescriptor<SplitSettlement>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                // Sin member propio no hay neto que liquidar (ni resumen de deuda que producir).
                guard let me = members.first(where: { $0.isCurrentUser }) else { continue }

                let balances = GroupBalanceService.calculateBalances(
                    expenses: expenses, shares: shares, members: members, settlements: settlements)
                // Un grupo cross-currency aporta un neto POR moneda y la deuda se detecta si CUALQUIERA
                // pasa de epsilon (`AccountDeletionDebtLogic`) ⇒ hay que saldar todas.
                for (currency, perCurrency) in Dictionary(grouping: balances, by: \.currencyCode) {
                    settleToZero(
                        nets: Dictionary(perCurrency.map { ($0.memberID, $0.netBalance) },
                                        uniquingKeysWith: { first, _ in first }),
                        myMemberID: me.id.uuidString,
                        currencyCode: currency,
                        zoneID: zoneID,
                        in: context)
                }
            }
            try context.save()
        } catch {
            print("DevSeedGroups: createSettled error: \(error)")
        }
    }

    /// Mismo umbral que `GroupBalanceService` / `AccountDeletionDebtLogic`.
    private static let settleEpsilon: Double = 0.01

    /// Emite las liquidaciones confirmadas de UNA moneda de UN grupo. Primero la del usuario (su neto
    /// ENTERO contra el neto opuesto más grande → cero exacto, sin depender de que el resto cuadre);
    /// después un greedy mayor-deudor ↔ mayor-acreedor con lo que queda.
    private static func settleToZero(
        nets: [String: Double],
        myMemberID: String,
        currencyCode: String,
        zoneID: String,
        in context: ModelContext
    ) {
        var nets = nets
        let myNet = nets[myMemberID] ?? 0
        if abs(myNet) > settleEpsilon {
            let others = nets.filter { $0.key != myMemberID }
            // Neto > 0 = me deben ⇒ me paga el que más debe. Neto < 0 = debo ⇒ le pago al que más se le debe.
            let counterparty = myNet > 0
                ? others.min(by: { $0.value < $1.value })?.key
                : others.max(by: { $0.value < $1.value })?.key
            if let counterparty {
                insertSettlement(
                    from: myNet > 0 ? counterparty : myMemberID,
                    to: myNet > 0 ? myMemberID : counterparty,
                    amount: abs(myNet), currencyCode: currencyCode, zoneID: zoneID, in: context)
                nets[myMemberID] = 0
                // La liquidación traslada el neto del usuario ENTERO a la contraparte (en los dos sentidos:
                // el `from` suma al `paid` y el `to` al `owes`, así que el delta es `myNet` con su signo).
                nets[counterparty, default: 0] += myNet
            }
        }

        // Resto: empareja al mayor deudor con el mayor acreedor. Cada vuelta deja a uno de los dos en cero
        // ⇒ el tope de iteraciones es holgado y garantiza terminación pase lo que pase con el redondeo.
        for _ in 0..<nets.count {
            guard let creditor = nets.max(by: { $0.value < $1.value }), creditor.value > settleEpsilon,
                  let debtor = nets.min(by: { $0.value < $1.value }), debtor.value < -settleEpsilon
            else { break }
            let amount = (min(creditor.value, -debtor.value) * 100).rounded() / 100
            insertSettlement(from: debtor.key, to: creditor.key, amount: amount,
                             currencyCode: currencyCode, zoneID: zoneID, in: context)
            nets[creditor.key] = creditor.value - amount
            nets[debtor.key] = debtor.value + amount
        }
    }

    private static func insertSettlement(
        from: String,
        to: String,
        amount: Double,
        currencyCode: String,
        zoneID: String,
        in context: ModelContext
    ) {
        let settlement = SplitSettlement(
            groupZoneID: zoneID, fromMemberID: from, toMemberID: to,
            amount: amount, currencyCode: currencyCode)
        // `calculateBalances` solo aplica las CONFIRMADAS — sin esto el neto no se movería.
        settlement.isConfirmed = true
        context.insert(settlement)
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
        group.isBackendGroup = true  // C3: ver el porqué en `create(in:)`.
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

    /// Grupo del canal backend donde el member propio llegó POR EL PULL: sin `isCurrentUser`.
    ///
    /// Es el estado que de verdad ocurre en producción y que ningún otro perfil reproduce, porque
    /// todos siembran el flag a mano (`create` :46 y :121, `createAsInvitee` :302). Sin él, la suite
    /// de UI no puede distinguir «la app me reconoce» de «la app da por hecho que soy yo», que es
    /// justo lo que hay que probar de la resolución de identidad.
    ///
    /// Cómo se reconoce al usuario aquí: por `cloudKitUserRecordID`, que
    /// `-uitest-icloud-identity` siembra con este mismo literal. El flag se deja APAGADO a
    /// propósito — encenderlo devolvería la ceguera.
    ///
    /// El usuario es ADMIN para poder ejercitar las acciones de administración, y hay un miembro
    /// PENDIENTE para que esas acciones tengan sobre quién actuar.
    static func createAsBackendJoiner(in context: ModelContext) {
        let group = SplitGroup(
            name: "Viaje a Cusco",
            iconName: "airplane",
            currencyCode: "PEN",
            isOwner: false
        )
        group.isBackendGroup = true
        context.insert(group)
        let zoneID = group.cloudKitZoneID
        // Sin esto el token `seeded-first` del deep link no resuelve y los tests de este perfil
        // mueren antes de llegar a la pantalla — el rojo dice «no se abrió el detalle» y no menciona
        // el fixture. Mismo motivo y misma forma que en `create(in:)`.
        if UITestHooks.isActive {
            UserDefaults.standard.set(group.id.uuidString, forKey: UITestHooks.seededGroupIDKey)
        }

        // Ana es la dueña. Yo soy admin, y mi fila viene del pull: identidad por recordName y
        // `isCurrentUser` APAGADO — el corazón de este perfil.
        let ana = SplitMember(
            groupZoneID: zoneID, displayName: "Ana",
            cloudKitUserRecordID: "uitest-member-ana",
            role: "admin", status: .active, isGroupOwner: true
        )
        let me = SplitMember(
            groupZoneID: zoneID, displayName: "Tú",
            cloudKitUserRecordID: "uitest-current-user",
            role: "admin", status: .active
        )
        let pendiente = SplitMember(
            groupZoneID: zoneID, displayName: "Carla",
            cloudKitUserRecordID: "uitest-member-carla",
            status: .pendingApproval
        )
        for m in [ana, me, pendiente] { context.insert(m) }

        do {
            try context.save()
        } catch {
            print("DevSeedGroups: createAsBackendJoiner save error: \(error)")
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
