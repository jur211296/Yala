//
//  CompartidoPersonDetailModel.swift
//  Yala
//
//  Lo que carga el detalle de una persona (lote 2 de Compartido, 26-nov-2026): un `GroupDetailViewModel` por cada grupo
//  que compartes con ella, el mismo que monta el detalle de ese grupo. Así gastos, repartos, pagos y deudas salen del
//  MISMO cálculo que ves dentro del grupo; aquí solo se juntan y se filtran (`CompartidoPersonDetailLogic`).
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class CompartidoPersonDetailModel {

    /// La persona, tal como la juntó la lista de Personas.
    let person: CompartidoPersonasLogic.Person
    /// Lo compartido fuera de un grupo se nombra así («Sin grupo»).
    let noGroupLabel: String

    /// Los grupos de la persona, en el orden de sus membresías (el de la lista de Grupos), con su ViewModel.
    private(set) var groups: [SplitGroup] = []
    private(set) var viewModels: [String: GroupDetailViewModel] = [:]
    /// Ya se intentó cargar: sin esto, «sin grupos» y «cargando» se verían igual.
    private(set) var hasLoaded = false

    private var modelContext: ModelContext?

    init(person: CompartidoPersonasLogic.Person, noGroupLabel: String) {
        self.person = person
        self.noGroupLabel = noGroupLabel
    }

    // MARK: - Carga

    func setContext(_ context: ModelContext) {
        modelContext = context
        loadGroups()
    }

    /// Busca los grupos de la persona y monta (o reusa) el ViewModel de cada uno. Un grupo borrado o escondido sale.
    func loadGroups() {
        guard let context = modelContext else { return }
        let keys = orderedGroupKeys
        do {
            let all = try context.fetch(FetchDescriptor<SplitGroup>())
            let byKey = Dictionary(all.map { ($0.cloudKitZoneID, $0) }, uniquingKeysWith: { first, _ in first })
            let found = keys.compactMap { byKey[$0] }.filter { !$0.isDeleted && !$0.isHiddenForAll }
            var models: [String: GroupDetailViewModel] = [:]
            for group in found {
                let key = group.cloudKitZoneID
                if let existing = viewModels[key], existing.group === group {
                    models[key] = existing
                    existing.loadData()
                } else {
                    let model = GroupDetailViewModel(group: group)
                    model.setContext(context)
                    models[key] = model
                }
            }
            groups = found
            viewModels = models
        } catch {
            #if DEBUG
            print("CompartidoPersonDetailModel: Error fetching groups: \(error)")
            #endif
        }
        hasLoaded = true
    }

    /// Un cambio que llega por sync: cada grupo recarga con su freno de siempre (150 ms).
    func reloadAndRecalculate() {
        for model in viewModels.values { model.reloadAndRecalculate() }
    }

    func cancelRecalculation() {
        for model in viewModels.values { model.cancelRecalculation() }
    }

    func setBackground(_ value: Bool) {
        for model in viewModels.values { model.setBackground(value) }
    }

    var hasUnfinishedRecalculation: Bool { viewModels.values.contains { $0.hasUnfinishedRecalculation } }

    /// Lo que bajó de la nube al abrir: el mismo canal que el detalle de grupo, una vez para todos.
    func refreshFromCloud() async {
        await GroupsSyncClient.shared.syncNowFromUI()
        for model in viewModels.values { model.loadData() }
    }

    /// Todos los grupos cargaron al menos una vez.
    var isReady: Bool { hasLoaded && viewModels.values.allSatisfy(\.isReady) }

    // MARK: - Qué grupos

    private var orderedGroupKeys: [String] {
        var seen = Set<String>()
        return person.memberships.compactMap { seen.insert($0.groupKey).inserted ? $0.groupKey : nil }
    }

    /// Las filas de la persona en un grupo.
    func personMemberIDs(in groupKey: String) -> Set<String> {
        Set(person.memberships.filter { $0.groupKey == groupKey }.map(\.memberID))
    }

    // MARK: - Lo que leen las páginas

    /// Los grupos como los lee la lógica, en orden y con sus deudas de hoy.
    var slices: [CompartidoPersonDetailLogic.Slice] {
        liveGroups.compactMap { group in
            guard let model = viewModels[group.cloudKitZoneID] else { return nil }
            return CompartidoPersonDetailLogic.Slice(
                groupKey: group.cloudKitZoneID,
                groupName: group.isPerson ? noGroupLabel : group.name,
                isPerson: group.isPerson,
                myMemberID: model.currentMemberID,
                personMemberIDs: personMemberIDs(in: group.cloudKitZoneID),
                debts: model.debts,
                debtsWereConverted: model.debtsWereConverted)
        }
    }

    /// Los grupos que se pueden leer: uno borrado por sync con el detalle abierto aborta al leerlo en iOS 27.x
    /// (`swiftui-ds.md`, filas con `@Model` borrado).
    var liveGroups: [SplitGroup] { groups.filter { !$0.isDeleted && $0.modelContext != nil } }

    func group(for key: String) -> SplitGroup? { liveGroups.first { $0.cloudKitZoneID == key } }

    func viewModel(for key: String) -> GroupDetailViewModel? { viewModels[key] }

    /// Los grupos del filtro, con su ViewModel.
    func entries(in filter: CompartidoPersonDetailLogic.Filter) -> [(group: SplitGroup, model: GroupDetailViewModel)] {
        let keys = Set(CompartidoPersonDetailLogic.slices(slices, in: filter).map(\.groupKey))
        return liveGroups.compactMap { group in
            guard keys.contains(group.cloudKitZoneID), let model = viewModels[group.cloudKitZoneID] else { return nil }
            return (group, model)
        }
    }

    /// El nombre de cada grupo para la etiqueta de la fila: el suyo, o «Sin grupo».
    func tagName(for groupKey: String) -> String {
        guard let group = group(for: groupKey) else { return "" }
        return group.isPerson ? noGroupLabel : group.name
    }
}
