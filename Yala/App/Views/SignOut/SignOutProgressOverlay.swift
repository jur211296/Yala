//
//  SignOutProgressOverlay.swift
//  Yala
//
//  Card p9q0 (recorrido de la bienvenida con Jürgen, 13-nov-2026): cerrar sesión, quitar los datos y eliminar la cuenta
//  tienen su propia pantalla mientras trabajan. Hasta ese día la app volvía a Ajustes con la fila girando y dejaba
//  navegar —en E08, con «Subiendo tus cambios a iCloud… 3168» en una tarjeta de la lista— y, en la nube, enseñaba «Ya
//  casi está — vuelve a abrir Yala» mientras el almacén se cambiaba en caliente.
//
//  **Por qué una ventana de UIKit y no una hoja o un cover.** Ajustes es una hoja con sus propias hojas, y el cierre en la
//  nube desmonta la jerarquía entera durante el cambio de almacén (`PersonalContainerSwap`): una presentación de SwiftUI
//  moriría con ella, y un cover más en el ancla de `ContentView` sería el segundo dueño ante el mismo observable que
//  `swiftui-ds.md` prohíbe. Una `UIWindow` de nivel alto en la escena queda por encima de todo y sobrevive al remonte: es
//  el recurso de `LeaderSignOutBusyOverlay`, con la misma ventana y el mismo fondo.
//
//  **Quién la quita.** La pantalla se mira a sí misma: lee el coordinador del cierre y el del borrado (los dos
//  `@Observable`) y se retira cuando ya no trabajan. Si el cierre se bloquea, sale su aviso de siempre en Ajustes; si
//  termina en caliente, debajo ya está el Welcome; si hay que reabrir, debajo está «Ya casi está». El borrado de la cuenta
//  que termina en caliente se queda en «Tu cuenta se eliminó» hasta «Continuar».
//

import SwiftUI
import UIKit

/// Qué enseña la pantalla, decidido en una tabla pura.
nonisolated enum SignOutProgressLogic {

    enum Activity: Equatable {
        case signingOut
        case removingData
        case deletingAccount
    }

    enum Screen: Equatable {
        case working(Activity)
        /// El borrado de la cuenta terminó sin reabrir: se dice antes de dejar ver el Welcome.
        case accountDeleted
        case hidden
    }

    /// - Parameters:
    ///   - signOutWorking: `CloudSessionSignOut.phase == .working`.
    ///   - signOutAwaitingRelaunch: `CloudSessionSignOut.phase == .awaitingRelaunch`.
    ///   - swapInFlight: `CloudSessionSignOut.inPlaceSwapInFlight`. Con la fase en `.awaitingRelaunch` todavía no se sabe
    ///     si hará falta reabrir: la pantalla se queda.
    ///   - deletionWorking: `AccountDeletionService.phase == .working` (servidor y cierre local, cambio incluido).
    ///   - deletionFinishedInPlace: la pantalla se presentó para un borrado y el borrado está en `.idle`. De `.working` solo
    ///     pasa a `.idle` cuando cerró sin reabrir (los fallos van a `.failed`, el que pide reabrir a `.awaitingRelaunch`).
    ///     Se deriva del estado, no de un `onChange` del paso: con dos `onChange` en la misma vuelta, el de la pantalla
    ///     podía ver `.hidden` antes de que el otro apuntara el final y retirarla sin decir que la cuenta se eliminó.
    ///   - presentedActivity: lo que se pidió al presentar (cerrar sesión o quitar los datos).
    static func screen(signOutWorking: Bool, signOutAwaitingRelaunch: Bool, swapInFlight: Bool,
                       deletionWorking: Bool, deletionFinishedInPlace: Bool,
                       presentedActivity: Activity) -> Screen {
        if deletionWorking { return .working(.deletingAccount) }
        if deletionFinishedInPlace { return .accountDeleted }
        if signOutWorking || (signOutAwaitingRelaunch && swapInFlight) { return .working(presentedActivity) }
        return .hidden
    }

    /// La actividad que se presenta según lo que se confirmó: el borrado manda; si no, el verbo de la fila.
    static func activity(deletionWorking: Bool, removesDeviceData: Bool) -> Activity {
        if deletionWorking { return .deletingAccount }
        return removesDeviceData ? .removingData : .signingOut
    }
}

/// Lo que la ventana recuerda entre repintados: qué se pidió.
@MainActor
@Observable
final class SignOutProgressModel {
    var activity: SignOutProgressLogic.Activity

    init(activity: SignOutProgressLogic.Activity) {
        self.activity = activity
    }
}

/// La ventana de UIKit que tapa la escena mientras dura el cierre. Una por proceso: el cierre de sesión es del proceso.
@MainActor
enum SignOutProgressWindow {
    private static var window: UIWindow?
    private static var previousKey: UIWindow?
    private static var model: SignOutProgressModel?

    static var isPresented: Bool { window != nil }

    /// Presenta la pantalla, o actualiza lo que dice si ya está puesta (un borrado que entra con ella delante).
    static func present(activity: SignOutProgressLogic.Activity, in scene: UIWindowScene?, theme: ThemeManager) {
        if let model {
            if model.activity != .deletingAccount { model.activity = activity }
            return
        }
        guard let scene = scene ?? Self.foregroundScene() else { return }
        let model = SignOutProgressModel(activity: activity)
        let window = UIWindow(windowScene: scene)
        // El mismo nivel que `SceneBusyWindows`: por encima de las hojas y de los avisos de la escena.
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: SignOutProgressRoot(model: model, theme: theme))
        host.view.backgroundColor = .systemBackground
        // El modo claro u oscuro de Yala, no el del sistema (molde de `DraftDiscardUndoNotice`): la app lo elige con
        // `preferredColorScheme` solo en su ventana, y sin esto el texto salía blanco sobre el fondo claro (XCUITest, 13-nov).
        if let appStyle = scene.keyWindow?.traitCollection.userInterfaceStyle {
            window.overrideUserInterfaceStyle = appStyle
        }
        window.rootViewController = host
        previousKey = scene.keyWindow
        // Key y no solo visible: con un teclado físico, un campo de Ajustes seguiría recibiendo lo que se escribe.
        window.makeKeyAndVisible()
        Self.window = window
        Self.model = model
    }

    static func dismiss() {
        guard let window else { return }
        window.isHidden = true
        Self.window = nil
        Self.model = nil
        // La ventana de antes puede haber desaparecido con el remonte; entonces la escena elige.
        previousKey?.makeKey()
        previousKey = nil
    }

    private static func foregroundScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}

/// La raíz de la ventana: el tema de la app, que una ventana propia no hereda (lo pone `YalaApp.rootView` en la suya).
struct SignOutProgressRoot: View {
    let model: SignOutProgressModel
    let theme: ThemeManager

    var body: some View {
        SignOutProgressScreenView(model: model)
            .tint(theme.resolved.accent)
            .environment(\.yalaTheme, theme.resolved)
            .environment(theme)
    }
}

/// La pantalla. Lee los dos coordinadores vivos y se retira sola.
struct SignOutProgressScreenView: View {
    @Bindable var model: SignOutProgressModel

    private var signOut: CloudSessionSignOut { CloudSessionSignOut.shared }
    private var deletion: AccountDeletionService { AccountDeletionService.shared }

    private var screen: SignOutProgressLogic.Screen {
        SignOutProgressLogic.screen(
            signOutWorking: signOut.phase == .working,
            signOutAwaitingRelaunch: signOut.phase == .awaitingRelaunch,
            swapInFlight: signOut.inPlaceSwapInFlight,
            deletionWorking: deletion.phase == .working,
            deletionFinishedInPlace: model.activity == .deletingAccount && deletion.phase == .idle,
            presentedActivity: model.activity)
    }

    var body: some View {
        content
            .frame(maxWidth: DS.Adaptive.readableWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Plano y no `.panel`: la ventana no hereda el tema de la app, y el degradado sin él salía gris a media altura
            // con el texto blanco encima (medido en el XCUITest del 13-nov). El plano sigue al modo claro u oscuro.
            .yalaScreenBackground(.subtle)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("signout_progress_screen")
            .onChange(of: screen, initial: true) { _, new in
                if new == .hidden { SignOutProgressWindow.dismiss() }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .working(let activity):
            workingContent(activity)
        case .accountDeleted:
            accountDeletedContent
        case .hidden:
            Color.clear
        }
    }

    private func workingContent(_ activity: SignOutProgressLogic.Activity) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .accessibilityHidden(true)
            Text(title(for: activity))
                .font(DS.Typography.title3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("signout_progress_title")
            detail
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    /// Lo que está pasando dentro del cierre: la subida a iCloud con su cifra (antes, una tarjeta en la lista de Ajustes),
    /// la espera de lo pendiente, o que Yala siga abierta.
    @ViewBuilder
    private var detail: some View {
        VStack(spacing: DS.Spacing.xs) {
            if signOut.phase == .working, let wait = signOut.iCloudExportWait {
                Text(L10n.UXCS.signOutUploadTitle)
                    .font(DS.Typography.subheadlineEmphasized)
                if let pending = wait.pending, pending > 0 {
                    Text(L10n.UXCS.signOutUploadPending(pending))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else if signOut.phase == .working && signOut.waitingForPending {
                Text(L10n.Settings.signOutWorking)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(L10n.UXCS.progressKeepOpen)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("signout_progress_detail")
    }

    private var accountDeletedContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(DS.Semantic.successForeground)
                .accessibilityHidden(true)
            Text(L10n.UXCS.progressAccountDeletedTitle)
                .font(DS.Typography.title2)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("signout_progress_account_deleted")
            Text(L10n.UXCS.progressAccountDeletedBody)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            YalaPrimaryButton(L10n.UXCS.progressContinue) {
                SignOutProgressWindow.dismiss()
            }
            .padding(.bottom, DS.Spacing.xl)
            .accessibilityIdentifier("signout_progress_continue")
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    private func title(for activity: SignOutProgressLogic.Activity) -> String {
        switch activity {
        case .signingOut: return L10n.UXCS.progressSigningOut
        case .removingData: return L10n.UXCS.progressRemovingData
        case .deletingAccount: return L10n.UXCS.progressDeletingAccount
        }
    }
}

/// Lo cuelga Ajustes: en cuanto el cierre o el borrado que ESTA pantalla confirmó empieza a trabajar, la tapa.
struct SignOutProgressPresenter: ViewModifier {
    /// El verbo de la fila que se confirmó («Quitar mis datos» o «Cerrar sesión»), o `nil` si aún no se sabe.
    let removesDeviceData: Bool
    @Environment(SceneNavigation.self) private var navigation
    @Environment(ThemeManager.self) private var themeManager

    private var signOutWorking: Bool { CloudSessionSignOut.shared.phase == .working }
    private var deletionWorking: Bool { AccountDeletionService.shared.phase == .working }

    func body(content: Content) -> some View {
        content
            .onChange(of: signOutWorking, initial: true) { _, working in
                if working { present() }
            }
            .onChange(of: deletionWorking, initial: true) { _, working in
                if working { present() }
            }
    }

    private func present() {
        SignOutProgressWindow.present(
            activity: SignOutProgressLogic.activity(deletionWorking: deletionWorking,
                                                    removesDeviceData: removesDeviceData),
            in: SceneRegistry.shared.windowScene(for: navigation.id),
            theme: themeManager)
    }
}

extension View {
    /// La pantalla propia de cerrar sesión, quitar los datos y eliminar la cuenta (card p9q0).
    func presentsSignOutProgress(removesDeviceData: Bool) -> some View {
        modifier(SignOutProgressPresenter(removesDeviceData: removesDeviceData))
    }
}
