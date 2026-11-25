//
//  DraftNoteInlineEditor.swift
//  Yala
//
//  La descripción de una fila de «Esto leí» editable ahí mismo (encargo «X nativa en la hoja de foto», 2026-11-17).
//  Tocar el texto lo convierte en un campo con teclado; «Listo», Intro o tocar fuera confirma, y lo escrito se guarda en
//  el borrador al momento, como ya hacen las píldoras de la fila (`VoiceDraftFieldEditing.persist`). Desde la opción A
//  (2026-11-22) el resto de la tarjeta no abre nada y la fila de varios se despliega: el editor completo es «Ver todo».
//

import SwiftData
import SwiftUI

/// Qué descripción queda al confirmar: lo escrito sin espacios ni saltos a los lados. Vacío es «sin descripción», y la
/// fila vuelve a enseñar la subcategoría, como un borrador que llegó sin nota.
enum DraftNoteInlineLogic {
    static func committed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Solo se escribe si cambió: un toque y «Listo» sin tocar nada no guarda ni mueve `updatedAt`.
    static func changes(_ text: String, from note: String) -> Bool {
        committed(text) != note
    }
}

struct DraftNoteInlineEditor: View {
    let draft: InboxDraft
    /// Lo que la fila pinta como título: la descripción o, sin ella, la subcategoría.
    let title: String
    @Binding var isEditing: Bool
    /// En la tarjeta B1 de un registro (opción A, 2026-11-22) va centrada; en la hoja de varios, a la izquierda. Siempre
    /// en el color del texto (Jürgen, 25-nov-2026: en gris fino no se leía).
    var isCentered = false
    /// Con el peso de la descripción de B1 (`headline`): en la tarjeta de un registro y en la fila desplegada de varios.
    var isProminent = false

    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField(title, text: $text)
                .font(isProminent ? DS.Typography.headline : DS.Typography.label)
                .foregroundStyle(.primary)
                .multilineTextAlignment(isCentered ? .center : .leading)
                .submitLabel(.done)
                .autocorrectionDisabled(false)
                .focused($isFocused)
                .onSubmit { isEditing = false }
                .onAppear {
                    text = draft.note
                    isFocused = true
                }
                // Tocar fuera confirma: perder el foco cierra el campo, y al irse el campo se guarda.
                .onChange(of: isFocused) { _, focused in
                    if !focused { isEditing = false }
                }
                .onDisappear(perform: save)
                .accessibilityIdentifier("image_draft_note_field")
        } else {
            Button {
                isEditing = true
            } label: {
                // Toda la línea de la descripción, no solo sus letras: con un nombre corto («Wong») el dedo caía al lado
                // y abría el formulario.
                Text(title)
                    .font(isProminent ? DS.Typography.headline : DS.Typography.label)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(isCentered ? .center : .leading)
                    // Dos líneas: con una, «Restaurante El Buen Gusto» se cortaba en la fila de varios.
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("image_draft_note")
        }
    }

    /// Se guarda al cerrarse el campo, venga de «Listo», de tocar fuera o de que la hoja se vaya con él abierto.
    private func save() {
        guard !draft.isDeleted, draft.modelContext != nil, draft.status == .pending,
              DraftNoteInlineLogic.changes(text, from: draft.note) else { return }
        draft.note = DraftNoteInlineLogic.committed(text)
        VoiceDraftFieldEditing.persist(draft, context: modelContext)
    }
}
