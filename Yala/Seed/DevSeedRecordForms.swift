//
//  DevSeedRecordForms.swift
//  Yala
//
//  Fixture de QA del registro unificado (`-uitest-seed-registro-unificado`, opción A de Jürgen, 2026-10-31): un borrador
//  pendiente en la Bandeja sobre la tarjeta «Visa QA» (la del perfil `tarjeta-dos-lineas`, con su línea en dólares), en
//  «Restaurantes» y con la etiqueta «Trabajo». Con él la aprobación enseña a la vez la tarjeta, sus dos líneas, la
//  subcategoría y una etiqueta puesta: los cuatro selectores que la opción A ordena en dos filas.
//
//  Discriminante: con la aprobación de antes (una fila con desplazamiento), la etiqueta queda fuera de la pantalla y la
//  categoría en la misma fila que las líneas; con la opción A, la categoría empieza fila debajo de la tarjeta.
//
//  Aditivo al perfil de `-uitest-seed`. Sin la tarjeta, usa la primera cuenta propia.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedRecordForms {

    static let draftNote = "Almuerzo con el equipo"
    static let draftAmount: Double = -86.50
    static let tagName = "Trabajo"

    @MainActor
    static func create(in context: ModelContext) {
        let accounts: [Account]
        let subcategories: [Subcategory]
        let tags: [Tag]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
            subcategories = try context.fetch(FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\.name)]))
            tags = try context.fetch(FetchDescriptor<Tag>())
        } catch {
            print("DevSeedRecordForms: Error: \(error)")
            return
        }
        guard let account = accounts.first(where: { $0.name == DevSeedAccountLines.UITest.cardName })
            ?? accounts.first(where: { !$0.isSystemAccount }) else { return }
        let restaurants = L10n.Subcategory.restaurants
        let subcategory = subcategories.first { $0.name == restaurants }
            ?? subcategories.first { !$0.safeCategory.isIncome }
        let tag: Tag
        if let existing = tags.first(where: { $0.name == tagName }) {
            tag = existing
        } else {
            tag = Tag(name: tagName, colorHex: "#2563EB", iconName: "briefcase.fill")
            context.insert(tag)
        }
        let draft = InboxDraft(
            note: draftNote,
            amount: draftAmount,
            date: .now,
            account: account,
            subcategory: subcategory,
            tags: [tag],
            sourceType: .manual,
            needsUserInput: [],
            status: .pending
        )
        context.insert(draft)
        do {
            try context.save()
        } catch {
            print("DevSeedRecordForms: Error: \(error)")
        }
        SessionState.shared.incrementDataVersion()
    }
}
#endif
