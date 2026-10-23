//
//  YalaCommands.swift
//  Yala
//
//  Atajos de teclado del iPad (fase 3 del carril adaptativo). Salen en la lista que aparece al mantener ⌘ y en la
//  barra de menús del iPad. En un iPhone sin teclado no se ven.
//
//  **Las acciones las publica la ventana, no la app.** `MainTabView` publica `RootCommandActions` con
//  `focusedSceneValue` y `RecordsStandaloneView` publica `RecordCommandActions` solo mientras Registros está delante
//  con un registro abierto en columna. Así cada ventana del iPad manda sobre sí misma, los números de ⌘1…⌘6 siguen el
//  orden real de su barra lateral, y fuera de la app montada (onboarding, splash) los atajos salen desactivados.
//

import SwiftUI

// MARK: - Qué ofrece la ventana

/// Un atajo global. Lo ejecuta `RootCommandPerformer` contra la `SceneNavigation` de la ventana.
enum RootCommand: Equatable {
    case newRecord
    case newGroupExpense
    case search
    case yalaAI
    case settings
    case section(ConfigurableTab)
    /// ⌘Z: deshace el último borrado mientras dura su aviso (UX 2.2 · L15-13).
    case undoDeletion
}

/// Lo que la ventana ofrece a los atajos globales.
struct RootCommandActions {
    /// ⌘1…⌘6, en el orden de la barra lateral (`KeyboardCommandLogic.sectionTabs`).
    let sections: [ConfigurableTab]
    /// ⌘F: solo si la pestaña Buscar existe en la barra actual (`RootTabLayoutLogic.showsSearchTab`).
    let canSearch: Bool
    /// Shell de solo grupos: el Panel no es alcanzable, así que lo que abre sobre él no se ofrece.
    let isGroupsOnly: Bool
    /// ⌘Z: hay en pantalla el aviso de un borrado con «Deshacer» (`UndoNoticeState`).
    var canUndoDeletion: Bool = false
    let perform: (RootCommand) -> Void
}

/// Lo que Registros ofrece mientras está delante con la ventana ancha.
struct RecordCommandActions {
    let hasOpenRecord: Bool
    /// ⌫: el registro abierto se puede borrar (`RecordContextActionLogic`).
    let canDeleteOpenRecord: Bool
    /// El registro abierto viene de un grupo: «Eliminar» sale apagado con su motivo (UX 2.2 · L15-13).
    var openRecordIsFromGroup: Bool = false
    let editOpenRecord: () -> Void
    let deleteOpenRecord: () -> Void
    let move: (KeyboardCommandLogic.Direction) -> Void
}

extension FocusedValues {
    @Entry var rootCommands: RootCommandActions?
    @Entry var recordCommands: RecordCommandActions?
}

// MARK: - Menús

struct YalaCommands: Commands {
    @FocusedValue(\.rootCommands) private var root
    @FocusedValue(\.recordCommands) private var records

    private var opensOnPanel: Bool { root.map { !$0.isGroupsOnly } ?? false }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L10n.Transaction.newTransaction) { root?.perform(.newRecord) }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!opensOnPanel)
            Button(L10n.Keyboard.newGroupExpense) { root?.perform(.newGroupExpense) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(root == nil)
        }

        // ⌘Z deshace el último borrado durante los segundos de su aviso (UX 2.2 · L15-13). SUSTITUYE al grupo de
        // deshacer del sistema solo mientras hay aviso: sumarse a él deja dos ⌘Z en el menú y UIKit cierra la app al
        // reconstruirlo («Replacement elements contain duplicates», medido el 2026-10-20). Fuera de esos segundos el
        // grupo del sistema queda intacto, con el deshacer de los campos de texto.
        if root?.canUndoDeletion == true {
            CommandGroup(replacing: .undoRedo) {
                Button(L10n.Inbox.undoDiscard) { root?.perform(.undoDeletion) }
                    .keyboardShortcut("z", modifiers: .command)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(L10n.Settings.title) { root?.perform(.settings) }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(!opensOnPanel)
        }

        CommandMenu(L10n.Keyboard.goMenu) {
            Button(L10n.Common.search) { root?.perform(.search) }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(root?.canSearch != true)
            Button(L10n.Chat.assistantName) { root?.perform(.yalaAI) }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(!opensOnPanel)
            Divider()
            ForEach(Array((root?.sections ?? []).enumerated()), id: \.element) { index, tab in
                Button(tab.displayName) { root?.perform(.section(tab)) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }

        CommandMenu(L10n.Keyboard.recordMenu) {
            Button(L10n.Action.edit) { records?.editOpenRecord() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(records?.hasOpenRecord != true)
            Button(role: .destructive) { records?.deleteOpenRecord() } label: {
                Text(L10n.Action.delete)
                // Apagado en un registro de grupo, y el porqué (UX 2.2 · L15-13).
                if records?.openRecordIsFromGroup == true {
                    Text(L10n.UXL08D.deleteFromGroup)
                }
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(records?.canDeleteOpenRecord != true)
            Divider()
            Button(L10n.Keyboard.previousRecord) { records?.move(.previous) }
                .keyboardShortcut(.upArrow, modifiers: [])
                .disabled(records == nil)
            Button(L10n.Keyboard.nextRecord) { records?.move(.next) }
                .keyboardShortcut(.downArrow, modifiers: [])
                .disabled(records == nil)
        }
    }
}

// MARK: - Ejecutar un atajo global

/// Cada atajo global reusa el camino que ya existe para lo mismo con el dedo, con sus puertas Pro y de
/// consentimiento: ⌘N el del Centro de Control, ⌘⇧N el del FAB de grupos. ⌘K y ⌘, los atiende el Panel
/// (`SceneNavigation.pendingKeyboardPanelRequest`), que es quien tiene Yala IA y Ajustes en una hoja propia.
@MainActor
enum RootCommandPerformer {
    /// ¿Puede un atajo abrir algo AHORA? No con el splash o un cover del shell, ni con otra cosa presentada.
    static func keyboardMayAct(_ navigation: SceneNavigation) -> Bool {
        KeyboardCommandLogic.globalCommandsAllowed(
            shellBlocker: navigation.shellModalBlocker,
            anythingPresented: ModalPresentationProbe.isAnythingPresented(
                in: SceneRegistry.shared.windowScene(for: navigation.id)))
    }

    static func perform(_ command: RootCommand, navigation: SceneNavigation, canSearch: Bool) {
        // Deshacer no abre nada: el aviso vive en su propia ventana y no cuenta como algo presentado.
        if command == .undoDeletion {
            DraftDiscardUndoNotice.performActiveUndo()
            return
        }
        guard keyboardMayAct(navigation) else { return }
        // Lo que el atajo encole en el router va a ESTA ventana, la que recibió la tecla.
        SceneRegistry.shared.noteFocused(navigation.id)
        switch command {
        case .newRecord:
            RouterEntryGate.shared.submit(.navigate(.panel))
            RouterEntryGate.shared.submit(.presentNewTransaction)
        case .newGroupExpense:
            navigation.navigateToGroupsAndComposeExpense()
        case .search:
            guard canSearch else { return }
            navigation.selectMainTab(.search)
            navigation.keyboardSearchRequest += 1
        case .yalaAI:
            navigation.pendingKeyboardPanelRequest = .yalaAI
            navigation.selectMainTab(.panel)
        case .settings:
            navigation.pendingKeyboardPanelRequest = .settings
            navigation.selectMainTab(.panel)
        case .section(let tab):
            navigation.selectMainTab(tab.appTab)
        case .undoDeletion:
            break
        }
    }
}
