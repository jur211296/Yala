//
//  DeletedModelMoreFormsReleaseTests.swift
//  YalaTests
//
//  Card gxa9 (ticket `more-forms-read-their-deleted-model-while-closing`), segunda mitad de la card 1w89: un formulario
//  que borra SU modelo sigue presentado mientras se cierra, y su `body` —o la lista que lo presentó— se vuelve a evaluar
//  con el modelo ya borrado. En el iPhone (iOS 27.x) leer una propiedad de un modelo borrado aborta; el simulador 27.0 no,
//  así que aquí se fija el MECANISMO de cada ViewModel: tras borrar, lo que el `body` lee deja de apuntar al borrado.
//  El cableado de las vistas lo fija `DeletedModelMoreFormsGuardWiringTests`.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`. `.serialized` por lo mismo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Formularios y listas que sueltan lo que se borra", .serialized)
struct DeletedModelMoreFormsReleaseTests {

    // MARK: - Formulario de cuenta

    /// Tras eliminar la cuenta, el ViewModel ya no apunta a ella ni a sus filas, sigue siendo una edición (la pantalla no
    /// cambia de forma mientras baja) y guardar no crea una cuenta nueva.
    @Test func cuenta_trasEliminarla_laSueltaYNoGuardaOtra() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Ahorros")
        try context.save()

        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.setContext(context)
        #expect(vm.isEditing)

        context.delete(account)
        try context.save()
        vm.releaseDeletedAccount()

        #expect(vm.accountToEdit == nil, "El ViewModel sigue apuntando a la cuenta eliminada.")
        #expect(vm.isEditing, "El formulario pasó a «nueva cuenta» mientras se cierra.")
        #expect(vm.accountTransactions.isEmpty)

        // Sin cuenta, guardar iría por la rama de crear: tiene que negarse.
        #expect(!vm.saveAccount(context: context))
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 0, "Guardar tras eliminar creó otra cuenta.")
    }

    // MARK: - Detalle de categoría

    /// Con la categoría borrada (con sus subcategorías), lo que el `body` lee ya no la toca.
    @Test func categoria_trasBorrarla_noLeeNiElla_niSusSubcategorias() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context, name: "Viajes")
        let sub = makeTestSubcategory(context: context, name: "Hotel", category: category)
        try context.save()

        let vm = CategoryDetailViewModel(category: category)
        vm.setContext(context, deletionService: EntityDeletionService.shared)
        #expect(vm.subcategories.count == 1)
        #expect(vm.readableCategory != nil)

        context.delete(sub)
        context.delete(category)
        try context.save()

        // Sin soltar nada todavía: las borradas no salen aunque sigan cargadas.
        #expect(vm.subcategories.isEmpty, "La lista de subcategorías sigue enseñando las borradas.")

        // Lo que hace la pantalla tras borrarla.
        vm.releaseDeletedCategory()
        #expect(vm.readableCategory == nil, "El ViewModel sigue ofreciendo la categoría borrada.")
        #expect(vm.isSystemCategory == false)
        #expect(vm.subcategories.isEmpty)
    }

    /// Una subcategoría eliminada desde su propio detalle (empujado encima) sale de la lista de la categoría, que sigue
    /// montada debajo, sin esperar a recargar.
    @Test func categoria_subcategoriaBorradaEncima_saleSinRecargar() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context, name: "Casa")
        let luz = makeTestSubcategory(context: context, name: "Luz", category: category)
        _ = makeTestSubcategory(context: context, name: "Agua", category: category)
        try context.save()

        let vm = CategoryDetailViewModel(category: category)
        vm.setContext(context, deletionService: EntityDeletionService.shared)
        #expect(vm.subcategories.count == 2)

        context.delete(luz)
        try context.save()

        #expect(vm.subcategories.map(\.name) == ["Agua"])
    }

    /// La lista vuelve a crear el detalle en su `NavigationLink` con la categoría ya borrada: la vista lo pide sin leerla
    /// (`readsCategory: false`) y el ViewModel no copia nada ni la ofrece.
    @Test func categoria_creadaSinLeerla_noLaLee() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context, name: "Viajes")
        try context.save()
        context.delete(category)
        try context.save()

        let vm = CategoryDetailViewModel(category: category, readsCategory: false)

        #expect(vm.name.isEmpty, "El init copió el nombre de la categoría borrada.")
        #expect(vm.readableCategory == nil)
        #expect(vm.isSystemCategory == false)
    }

    // MARK: - Listas que presentan los formularios

    /// La lista de presupuestos recalcula 150 ms después de borrar: mientras, el límite de Free no cuenta el borrado.
    @Test func presupuestos_conteoDeActivos_noCuentaElBorrado() throws {
        let context = try makeTestContext()
        let viajes = makeTestBudget(context: context, name: "Viajes")
        _ = makeTestBudget(context: context, name: "Comida")
        try context.save()

        let vm = BudgetsViewModel()
        vm.setContext(context)
        vm.loadData()
        #expect(vm.activeBudgetsCount == 2)

        context.delete(viajes)
        try context.save()

        #expect(vm.activeBudgetsCount == 1, "El conteo lee el presupuesto borrado antes de recargar.")
    }

    @Test func listaDeCategorias_noEnsenaLaBorrada() throws {
        let context = try makeTestContext()
        let viajes = makeTestCategory(context: context, name: "Viajes")
        _ = makeTestCategory(context: context, name: "Casa")
        try context.save()

        let vm = CategoriesSettingsListViewModel()
        vm.setContext(context, deletionService: EntityDeletionService.shared)
        #expect(vm.categories.count == 2)

        context.delete(viajes)
        try context.save()

        #expect(vm.categories.map(\.name) == ["Casa"])
        #expect(vm.orderedCategories.map(\.name) == ["Casa"])
    }

    @Test func listaDeEtiquetas_noEnsenaLaBorrada() throws {
        let context = try makeTestContext()
        let viaje = makeTestTag(context: context, name: "Viaje")
        _ = makeTestTag(context: context, name: "Trabajo")
        try context.save()

        let vm = TagsSettingsListViewModel()
        vm.setContext(context)
        #expect(vm.tags.count == 2)

        context.delete(viaje)
        try context.save()

        #expect(vm.tags.map(\.name) == ["Trabajo"])
    }

    // MARK: - Formulario de etiqueta

    /// La barra lee `canSave` mientras el formulario baja tras eliminar: soltada la lista, la unicidad del nombre ya no
    /// recorre las etiquetas (entre ellas, la borrada).
    @Test func etiqueta_trasEliminarla_laUnicidadNoRecorreLaLista() throws {
        let context = try makeTestContext()
        let viaje = makeTestTag(context: context, name: "Viaje")
        let trabajo = makeTestTag(context: context, name: "Trabajo")
        try context.save()

        let vm = TagFormViewModel(tagToEdit: trabajo)
        vm.setContext(context)
        vm.name = "Viaje"
        #expect(!vm.isNameUnique, "Con «Viaje» viva, el nombre está tomado.")
        #expect(vm.existingTags.count == 2)

        // Lo que hace `TagFormView.deleteTag`.
        context.delete(trabajo)
        try context.save()
        vm.releaseDeletedTag()

        #expect(vm.existingTags.isEmpty, "El ViewModel sigue apuntando a la etiqueta borrada.")
        _ = viaje
    }

    // MARK: - Detalle del grupo

    /// Salir del grupo lo borra con sus miembros. El detalle suelta el grupo antes de cerrarse: lo que se lea del ViewModel
    /// mientras baja (miembros, permisos, el aviso de un saldo inicial rechazado, una recarga) ya no toca nada borrado, y el
    /// título conserva el nombre de la última carga (ticket `group-detail-reads-the-group-after-leaving-it`).
    @Test func grupo_trasSalir_elDetalleLoSuelta_yNoVuelveALeerlo() throws {
        let context = try makeTestContext()
        GroupService.shared.setContext(context)
        GroupExpenseService.shared.setContext(context)
        defer {
            GroupService.shared._testResetContext()
            GroupExpenseService.shared._testResetContext()
        }
        let group = SplitGroup(name: "Viaje a Cusco", currencyCode: "PEN")
        context.insert(group)
        let zoneID = group.cloudKitZoneID
        let me = SplitMember(groupZoneID: zoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        try context.save()

        let vm = GroupDetailViewModel(group: group)
        vm.setContext(context)
        #expect(vm.members.count == 1)
        #expect(vm.groupName == "Viaje a Cusco")
        #expect(vm.canCurrentUserParticipate)

        // Lo que hace `GroupService.leaveGroup` (`performLocalCleanupAndDelete`) y, detrás, el detalle al verlo.
        context.delete(me)
        context.delete(group)
        try context.save()
        vm.releaseDeletedGroup()

        #expect(vm.isGroupReleased)
        #expect(vm.members.isEmpty, "El ViewModel sigue apuntando a los miembros borrados.")
        #expect(!vm.canCurrentUserParticipate)
        #expect(!vm.isOpeningBalanceManager)
        #expect(vm.groupName == "Viaje a Cusco", "El título se queda sin el nombre mientras la pantalla baja.")

        // Ni una recarga ni el aviso de un rechazo que llega tarde vuelven a leer el grupo.
        vm.loadData()
        #expect(vm.members.isEmpty)
        let notices = OpeningBalanceServerRejectionNotices()
        notices.record(groupID: zoneID, reason: .locked)
        vm.presentOpeningBalanceServerRejectionIfAny(notices: notices, windowIsPresenting: false)
        #expect(!vm.showActionError)
        #expect(notices.peek(groupID: zoneID) == .locked)
    }
}
