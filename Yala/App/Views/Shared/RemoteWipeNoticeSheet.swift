//
//  RemoteWipeNoticeSheet.swift
//  Yala
//
//  «Datos no disponibles» como hoja propia (UX 2.2 · L20-15, opción B de Jürgen, 2026-10-23). Era un `.alert`, y en un
//  aviso del sistema el orden y el relleno de los botones no se eligen: «Seguir esperando» —la salida que no borra—
//  iba abajo, y relleno salía con el texto del mismo índigo que el fondo (medido el 2026-10-22, `swiftui-ds.md`). En
//  una hoja va ARRIBA y rellena (`YalaPrimaryButton`), y «Empezar de cero» debajo, en rojo y sin relleno: borrar tiene
//  que ser un gesto deliberado. Molde: `AppleIDCloseNoticeView`.
//
//  La hoja solo pinta y elige. Lo que cada botón hace sigue en `ContentView` (`startFreshAfterRemoteWipeNotice`,
//  `dismissRemoteWipeNotice`), y se ejecuta en el `onDismiss` de la hoja, con ella ya fuera
//  (`RemoteWipeNoticeSheetModifier`, abajo): «Empezar de cero» presenta el Welcome en el mismo ancla, y un ancla no
//  presenta dos cosas a la vez.
//

import SwiftUI

struct RemoteWipeNoticeSheet: View {

    /// Lo que la persona eligió. Se lo pasa a quien presenta la hoja, que lo ejecuta al cerrarse.
    enum Choice: Equatable {
        case keepWaiting
        case startFresh
    }

    let onChoose: (Choice) -> Void

    var body: some View {
        // Con el texto grande o en un SE la hoja no cabe: se desplaza (`swiftui-ds.md`, pantallas con `Spacer`s).
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    Spacer(minLength: DS.Spacing.lg)
                    header
                    actions
                    Spacer(minLength: DS.Spacing.lg)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .yalaScreenBackground(.subtle)
        // Como el aviso que sustituye: se sale por sus botones. Un deslizamiento no dice cuál de los dos era.
        .interactiveDismissDisabled()
    }

    /// El identificador va en la cabecera y no en el contenedor: ahí pisaría el de los botones (`testing.md`).
    private var header: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 44)) // A11Y-DT: icono decorativo hero, tamaño fijo (molde de AppleIDCloseNoticeView)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.iCloud.remoteWipeTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.iCloud.remoteWipeMessage)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("remote_wipe_notice")
    }

    private var actions: some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaPrimaryButton(L10n.iCloud.remoteWipeCancel) { onChoose(.keepWaiting) }
                .accessibilityIdentifier("remote_wipe_keep_waiting")
            Button(role: .destructive) {
                onChoose(.startFresh)
            } label: {
                Text(L10n.iCloud.remoteWipeConfirm)
                    .font(DS.Typography.label)
                    .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("remote_wipe_start_fresh")
        }
    }
}

/// Presenta `RemoteWipeNoticeSheet` desde el ancla de `ContentView`, en su propio modificador. **No va dentro de
/// `ShellDataAlertsModifier`**: colgada de ése, ni la hoja ni el aviso de iCloud de su lado llegaban a presentarse
/// (medido el 2026-10-23, `RemoteWipeNoticeRoutingUITests` 1 de 5), igual que con las anclas propias del 22-oct.
///
/// **Lo elegido se ejecuta en el `onDismiss`, con la hoja ya fuera.** Al tocar, `onAnswered` cierra la hoja y para la red
/// de presentación sin soltar la condición viva: la matriz sigue reteniendo la cola mientras la hoja se va. Sin elección
/// (UIKit la tumbó, o la red la está re-presentando) el `onDismiss` no hace nada y la red sigue vigilando.
struct RemoteWipeNoticeSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    /// La condición viva del aviso. Si ya se soltó cuando la hoja termina de irse —la señal explícita del Apple ID llegó
    /// entre el toque y el cierre y lanzó su propio borrado—, la salida elegida ya no corre: pisaría la de la señal.
    let noticePending: Bool
    let onAnswered: () -> Void
    let onStartFreshChosen: () -> Void
    let onKeepWaitingChosen: () -> Void

    @State private var choice: RemoteWipeNoticeSheet.Choice?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: { runChoice() }) {
                RemoteWipeNoticeSheet { picked in choose(picked) }
            }
    }

    /// Manda el primer toque: la hoja aún acepta toques mientras se va, y un segundo no puede cambiar la salida.
    private func choose(_ picked: RemoteWipeNoticeSheet.Choice) {
        guard choice == nil else { return }
        choice = picked
        onAnswered()
    }

    private func runChoice() {
        let picked = choice
        choice = nil
        guard noticePending else { return }
        switch picked {
        case .startFresh: onStartFreshChosen()
        case .keepWaiting: onKeepWaitingChosen()
        case nil: break
        }
    }
}
