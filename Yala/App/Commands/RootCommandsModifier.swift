//
//  RootCommandsModifier.swift
//  Yala
//
//  Lo que la raíz de una ventana aporta al teclado y al arrastrar (fase 3 del carril adaptativo): publica las
//  acciones de los atajos globales para su escena y recibe los recibos que se sueltan sobre la app.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct RootCommandsModifier: ViewModifier {
    let navigation: SceneNavigation
    let sections: [ConfigurableTab]
    let canSearch: Bool
    let isGroupsOnly: Bool

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.rootCommands, actions)
            .onDrop(of: ReceiptDropHandler.acceptedTypes, isTargeted: nil) { providers in
                ReceiptDropHandler.handle(providers, isGroupsOnly: isGroupsOnly, navigation: navigation)
            }
            .modifier(UITestReceiptDropSeam(navigation: navigation, isGroupsOnly: isGroupsOnly))
    }

    private var actions: RootCommandActions {
        let navigation = navigation
        let canSearch = canSearch
        return RootCommandActions(
            sections: KeyboardCommandLogic.sectionTabs(orderedTabs: sections),
            canSearch: canSearch,
            isGroupsOnly: isGroupsOnly,
            perform: { RootCommandPerformer.perform($0, navigation: navigation, canSearch: canSearch) }
        )
    }
}

// MARK: - Soltar un recibo

/// Soltar una imagen o un PDF sobre Yala abre Nuevo registro por imagen (`ReceiptDropLogic`). Solo el primer
/// elemento. Un PDF se guarda tal cual y la hoja lo lee página a página (`PDFPageImport`, desde el 2026-10-08); si tiene
/// contraseña, la pide la hoja.
///
/// Lo que no se puede abrir (PDF vacío o dañado, imagen dañada) abre el mismo registro por imagen en su fallo
/// «No pude abrir este archivo», el de Archivo desde dentro. Hasta el 2026-10-07 solo se escribía en el log: el sistema
/// ya había dado el soltar por aceptado y el usuario no veía nada. Lo que nunca es imagen ni PDF no llega aquí: el
/// `onDrop` solo acepta `acceptedTypes`, así que el sistema lo rechaza antes de soltar.
@MainActor
enum ReceiptDropHandler {
    static let acceptedTypes: [UTType] = [.image, .pdf]

    /// `true` si acepta el arrastre. Con algo presentado no lo acepta: el recibo se abriría debajo de esa hoja.
    static func handle(_ providers: [NSItemProvider], isGroupsOnly: Bool, navigation: SceneNavigation) -> Bool {
        guard ReceiptDropLogic.accepts(isGroupsOnly: isGroupsOnly) else { return false }
        guard KeyboardCommandLogic.globalCommandsAllowed(
            shellBlocker: navigation.shellModalBlocker,
            anythingPresented: ModalPresentationProbe.isAnythingPresented(
                in: SceneRegistry.shared.windowScene(for: navigation.id))
        ) else { return false }
        guard let provider = providers.first(where: { provider in
            acceptedTypes.contains { provider.hasItemConformingToTypeIdentifier($0.identifier) }
        }) else { return false }

        // El recibo se abre en la ventana sobre la que se soltó, que no tiene por qué ser la que está al frente.
        let windowID = navigation.id
        SceneRegistry.shared.noteFocused(windowID)
        switch ReceiptDropLogic.decide(canAccessImageInput: FeatureGateService.shared.canAccess(.imageInput)) {
        case .upgrade:
            RouterEntryGate.shared.submit(.navigate(.panel))
            RouterEntryGate.shared.submit(.presentUpgradeSheet(.image))
        case .present:
            let isPDF = provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
            let type = isPDF ? UTType.pdf : UTType.image
            _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                #if DEBUG
                if data == nil {
                    print("ReceiptDropHandler: Error: no se pudo leer lo soltado: \(String(describing: error))")
                }
                #endif
                Task { @MainActor in
                    receive(data, isPDF: isPDF, sink: .live(windowID: windowID))
                }
            }
        }
        return true
    }

    /// Lo que sale de lo soltado, sin efectos: el fichero que se va a leer (una imagen en JPEG, o el PDF tal cual, bloqueado
    /// o no), o el fallo que se le enseña al usuario.
    enum Outcome: Equatable {
        case readable(file: Data, isPDF: Bool)
        case failed(ImageEntryFailure)
    }

    static func outcome(for data: Data?, isPDF: Bool) -> Outcome {
        guard let data else { return .failed(.unreadableFile) }
        if isPDF {
            guard PDFPageImport.canOpen(data) else {
                #if DEBUG
                print("ReceiptDropHandler: Error: lo soltado no es un PDF legible")
                #endif
                return .failed(.unreadableFile)
            }
            return .readable(file: data, isPDF: true)
        }
        guard let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.9) else {
            #if DEBUG
            print("ReceiptDropHandler: Error: lo soltado no es una imagen legible")
            #endif
            return .failed(.unreadableFile)
        }
        return .readable(file: jpeg, isPDF: false)
    }

    /// A dónde va lo soltado. Separado para probar que ningún camino termina en silencio.
    struct Sink {
        var store: (_ file: Data, _ isPDF: Bool) -> URL?
        var present: (URL) -> Void
        var fail: (ImageEntryFailure) -> Void

        static func live(windowID: UUID) -> Sink {
            Sink(
                store: writePending,
                present: { url in
                    // La lectura es asíncrona: entretanto el usuario pudo poner otra ventana al frente.
                    SceneRegistry.shared.noteFocused(windowID)
                    AppBootstrapper.shared.presentDroppedReceipt(url)
                },
                fail: { failure in
                    SceneRegistry.shared.noteFocused(windowID)
                    AppBootstrapper.shared.presentDroppedReceiptFailure(failure)
                }
            )
        }
    }

    /// Todo camino acaba en la hoja: con la foto, o con su fallo. Si no se puede guardar en `PendingImages/`, el archivo
    /// está bien y falló lo nuestro: `.generic`, no «no pude abrirlo».
    static func receive(_ data: Data?, isPDF: Bool, sink: Sink) {
        switch outcome(for: data, isPDF: isPDF) {
        case .failed(let failure):
            sink.fail(failure)
        case .readable(let file, let isPDF):
            guard let url = sink.store(file, isPDF) else {
                sink.fail(.generic)
                return
            }
            sink.present(url)
        }
    }

    /// Al mismo sitio que la extensión de compartir (`SharedContainerService.pendingImagesURL`), con extensión `.jpg` o
    /// `.pdf` para que `pendingImageURLs()` lo reconozca si hay que recuperarlo (y la purga del App Group, si hay que
    /// borrarlo).
    private static func writePending(_ file: Data, isPDF: Bool) -> URL? {
        SharedContainerService.ensurePendingImagesDirectory()
        guard let directory = SharedContainerService.pendingImagesURL else { return nil }
        let url = directory.appendingPathComponent("drop-\(UUID().uuidString).\(isPDF ? "pdf" : "jpg")")
        do {
            try file.write(to: url, options: .atomic)
            return url
        } catch {
            #if DEBUG
            print("ReceiptDropHandler: Error: \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - Seam de XCUITest

/// `-uitest-receipt-drop` (`UITestHooks.receiptDrop`): suelta un recibo por `ReceiptDropHandler.handle` en cuanto la
/// ventana queda libre, una sola vez. Fuera de los XCUITest no hace nada.
private struct UITestReceiptDropSeam: ViewModifier {
    let navigation: SceneNavigation
    let isGroupsOnly: Bool
    @State private var dropped = false

    func body(content: Content) -> some View {
        #if DEBUG
        content.onChange(of: navigation.shellModalBlocker, initial: true) { _, blocker in
            guard !dropped, blocker == nil, let kind = UITestHooks.receiptDrop else { return }
            dropped = true
            let provider = NSItemProvider()
            let type: UTType
            let data: Data?
            switch kind {
            case "readable":
                type = .png
                data = UIImage(named: "ExampleImages/example-receipt-es")?.pngData()
            case "pdf3", "pdf3-locked":
                // Un extracto ficticio de tres páginas; `-locked`, con la contraseña «1234».
                type = .pdf
                data = UITestStatementPDF.make(pages: 3, password: kind == "pdf3-locked" ? "1234" : nil)
            default:
                type = .pdf
                data = Data("no es un PDF".utf8)
            }
            provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
                completion(data, nil)
                return nil
            }
            let accepted = ReceiptDropHandler.handle([provider], isGroupsOnly: isGroupsOnly, navigation: navigation)
            print("UITestReceiptDropSeam: \(kind) aceptado=\(accepted)")
        }
        #else
        content
        #endif
    }
}

#if DEBUG
/// El extracto de los XCUITest de PDF: N páginas con un movimiento por página, opcionalmente con contraseña.
enum UITestStatementPDF {
    static func make(pages: Int, password: String?) -> Data? {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { context in
            for page in 1...max(1, pages) {
                context.beginPage()
                let text = "Extracto ficticio · página \(page) de \(pages)\n\nMovimiento \(page)   -\(9 + page),00"
                (text as NSString).draw(
                    in: CGRect(x: 48, y: 64, width: 500, height: 200),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
                )
            }
        }
        guard let password else { return data }
        return PDFDocument(data: data)?.dataRepresentation(options: [
            PDFDocumentWriteOption.userPasswordOption: password,
            PDFDocumentWriteOption.ownerPasswordOption: password,
        ])
    }
}
#endif
