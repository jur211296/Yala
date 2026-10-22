//
//  InAppSafariSheet.swift
//  Yala
//
//  Una página web (privacidad, términos) dentro de Yala, en la hoja de Safari con «Listo» (UX 2.2 · L16-19). Con
//  `openURL` la persona acababa en Safari y la única vuelta era el «◂ Yala» de la barra de estado.
//

import SafariServices
import SwiftUI

/// La URL que la hoja enseña. Viaja como ITEM de la presentación (`.sheet(item:)`), no como `@State` leído dentro del
/// cierre: así la hoja no puede abrirse con la URL de antes (`swiftui-ds.md`, «.sheet(isPresented:) con el contenido
/// sacado de OTRO @State»).
struct InAppWebPage: Identifiable, Equatable {
    let url: URL
    var id: String { url.absoluteString }
}

/// `SFSafariViewController` en SwiftUI. Su «Listo» lo pinta Safari; al tocarlo, el delegado cierra la hoja.
struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .done
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onDone() }
    }
}

extension View {
    /// Presenta `page` en la hoja de Safari mientras no sea `nil`. Al tocar «Listo» o deslizar, vuelve a `nil`.
    func inAppSafari(_ page: Binding<InAppWebPage?>) -> some View {
        sheet(item: page) { item in
            InAppSafariView(url: item.url) { page.wrappedValue = nil }
                .ignoresSafeArea()
                .accessibilityIdentifier("in_app_safari")
        }
    }
}
