//
//  ComerciosEnComunLinea.swift
//  Yala
//
//  «✓ Así suele categorizarse Tambo+ en Yala. Cambiar»: la línea de la tarjeta de «Esto leí» cuando la categoría la
//  propuso la lista común (decisión 4 de la propuesta, recomendada). Sin memoria de ese comercio y con la subcategoría
//  que da la lista; al guardar pasa a la memoria y la próxima vez ya no sale. «Cambiar» abre el selector de categoría.
//

import SwiftData
import SwiftUI

struct ComerciosEnComunLinea: View {
    let comercio: String
    let onCambiar: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DS.Semantic.successForeground)
                .accessibilityHidden(true)
            Text(L10n.ComerciosEnComun.linea(comercio))
                .foregroundStyle(.secondary)
            Button(L10n.ComerciosEnComun.lineaCambiar, action: onCambiar)
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .foregroundStyle(.thAccentText)
                .padding(.vertical, DS.Spacing.xs)
                .contentShape(Rectangle())
                .accessibilityIdentifier("comercios_comun_cambiar")
        }
        .font(DS.Typography.caption)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("comercios_comun_linea")
    }

    /// El comercio que nombra la línea, o `nil` si no sale: solo gastos, sin memoria de ese comercio, y con la
    /// subcategoría del borrador igual a la que da la lista común.
    @MainActor
    static func comercio(
        note: String,
        subcategory: Subcategory,
        isExpense: Bool,
        subcategories: [Subcategory],
        context: ModelContext,
        comunes: ComerciosEnComun? = nil
    ) -> String? {
        let comunes = comunes ?? .shared
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isExpense, !trimmed.isEmpty, comunes.tipo(paraComercio: trimmed) != nil,
              comunes.subcategoria(paraComercio: trimmed, isExpense: true, en: subcategories)?.persistentModelID
                == subcategory.persistentModelID,
              !MerchantMemoryService(modelContext: context, comunes: comunes).hasMemory(for: trimmed)
        else { return nil }
        return MerchantCanonicalizer.displayName(for: trimmed)
    }
}
