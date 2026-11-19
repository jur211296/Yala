//
//  DraftNoteInlineEditor.swift
//  Yala
//
//  La descripción de una fila de «Esto leí» editable ahí mismo (encargo «X nativa en la hoja de foto», 2026-11-17).
//  Tocar el texto lo convierte en un campo con teclado; «Listo», Intro o tocar fuera confirma, y lo escrito se guarda en
//  el borrador al momento, como ya hacen las píldoras de la fila (`VoiceDraftFieldEditing.persist`). El resto de la fila
//  sigue abriendo el formulario completo: el campo es un botón propio dentro de la etiqueta de la fila.
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

    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField(title, text: $text)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
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
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
