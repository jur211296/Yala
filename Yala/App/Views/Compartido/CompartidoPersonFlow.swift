//
//  CompartidoPersonFlow.swift
//  Yala
//
//  Compartido (lote 3, 26-nov-2026): el camino de dar de alta a una persona desde la pestaña. Dos entradas —«Añadir
//  persona» de la barra y «¿Con quién?» cuando no hay nadie con quien apuntar— y tres salidas: invitarla, o el gasto con
//  ella por Nuevo gasto, Voz, Foto o Yala IA (las pantallas de Grupos). Las hojas cuelgan de la pestaña en un modificador
//  propio (el presupuesto del type-checker del CI, `swiftui-ds.md`), y cada una pide la siguiente en su `onDismiss`: dos
//  presentaciones seguidas del mismo ancla sin esperar a que la primera se cierre se pierden.
//

import SwiftUI

@MainActor
@Observable
final class CompartidoPersonFlowState {

    /// Para qué se da de alta a la persona: lo que se abre después.
    enum Purpose: Equatable {
        case invite
        case newExpense
        case receipt(GroupReceiptEntryKind)
    }

    struct WhoRequest: Identifiable {
        let id = UUID()
        let purpose: Purpose
    }

    struct Pending {
        let name: String
        let purpose: Purpose
        let at: Date
    }

    /// «¿Con quién?» sin nadie elegible (el selector de Grupos con «Escribir un nombre»).
    var who: WhoRequest?
    /// La hoja de «Añadir persona».
    var showAddPerson = false
    var isCreating = false
    var errorMessage: String? {
        didSet { showsErrorAlert = errorMessage != nil && !showAddPerson && who == nil }
    }
    /// La alerta del error del alta, solo sin hojas delante: con «Añadir persona» abierta, el error va dentro de la hoja.
    var showsErrorAlert = false
    /// La persona que se estaba añadiendo cuando hubo que pedir la cuenta o el consentimiento. Caduca: si la persona
    /// cerró esas hojas sin terminar, no se crea sola horas después al iniciar sesión por otro lado.
    var pendingAfterIdentity: Pending?

    /// Lo que pidió «¿Con quién?» antes de cerrarse; se ejecuta en su `onDismiss`.
    var nameFromWho: (name: String, purpose: Purpose)?
    var pickedFromWho: (group: SplitGroup, purpose: Purpose)?
    /// La persona ya creada desde la hoja de «Añadir persona», para invitarla cuando la hoja termine de cerrarse.
    var readyAfterDismiss: SplitGroup?

    static let identityWindow: TimeInterval = 10 * 60

    func ask(_ purpose: Purpose) {
        errorMessage = nil
        who = WhoRequest(purpose: purpose)
    }

    func waitForIdentity(name: String, purpose: Purpose, now: Date = .now) {
        showAddPerson = false
        pendingAfterIdentity = Pending(name: name, purpose: purpose, at: now)
    }

    /// La pendiente, si sigue fresca. Se consume: un segundo aviso de sesión no la vuelve a crear.
    func takePendingIfFresh(now: Date = .now) -> Pending? {
        guard let pending = pendingAfterIdentity else { return nil }
        pendingAfterIdentity = nil
        return CompartidoPersonFlowLogic.isFresh(createdAt: pending.at, now: now) ? pending : nil
    }

    /// Con la hoja de «Añadir persona» abierta, la invitación espera a que se cierre. Devuelve si la dejó esperando.
    func deferIfSheetOpen(_ person: SplitGroup, purpose: Purpose) -> Bool {
        guard showAddPerson else { return false }
        readyAfterDismiss = person
        showAddPerson = false
        return true
    }
}

nonisolated enum CompartidoPersonFlowLogic {
    /// ¿La persona pendiente de la cuenta sigue valiendo? Diez minutos desde que se pidió.
    static func isFresh(createdAt: Date, now: Date, window: TimeInterval = 10 * 60) -> Bool {
        let elapsed = now.timeIntervalSince(createdAt)
        return elapsed >= 0 && elapsed <= window
    }
}

/// Las hojas del alta de persona, colgadas de la pestaña Compartido.
struct CompartidoPersonFlowPresentations: ViewModifier {
    @Bindable var flow: CompartidoPersonFlowState
    /// Con quién se puede apuntar ya (grupos y personas), para el selector.
    let knownGroups: [SplitGroup]
    let memberCount: (SplitGroup) -> Int
    let onCreate: (String, CompartidoPersonFlowState.Purpose) -> Void
    let onPick: (SplitGroup, CompartidoPersonFlowState.Purpose) -> Void
    let onInviteReady: (SplitGroup) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $flow.showAddPerson, onDismiss: addPersonDismissed) {
                CompartidoAddPersonSheet(isBusy: flow.isCreating, errorMessage: flow.errorMessage) { name in
                    flow.errorMessage = nil
                    onCreate(name, .invite)
                }
                .yalaSheetDetents([.medium, .large])
            }
            .sheet(item: $flow.who, onDismiss: whoDismissed) { request in
                GroupPickerSheet(
                    groups: knownGroups,
                    selectedGroupID: nil,
                    memberCount: memberCount,
                    onNewPerson: { name in
                        flow.nameFromWho = (name, request.purpose)
                        flow.who = nil
                    },
                    opensAtMediumHeight: true
                ) { group in
                    flow.pickedFromWho = (group, request.purpose)
                    flow.who = nil
                }
            }
            .alert(L10n.Common.error, isPresented: $flow.showsErrorAlert) {
                Button(L10n.Common.ok) { flow.errorMessage = nil }
            } message: {
                Text(flow.errorMessage ?? "")
            }
    }

    private func addPersonDismissed() {
        guard let person = flow.readyAfterDismiss else { return }
        flow.readyAfterDismiss = nil
        onInviteReady(person)
    }

    private func whoDismissed() {
        if let request = flow.nameFromWho {
            flow.nameFromWho = nil
            onCreate(request.name, request.purpose)
        } else if let picked = flow.pickedFromWho {
            flow.pickedFromWho = nil
            onPick(picked.group, picked.purpose)
        }
    }
}
