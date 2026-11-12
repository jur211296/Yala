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

    /// Hay algo arrastrándose encima de la ventana: se marca dónde soltar (UX 2.2 · L4-11). Antes `isTargeted: nil`
    /// y nada decía que soltar fuera a hacer algo.
    @State private var isDropTargeted = false

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.rootCommands, actions)
            .onDrop(of: ReceiptDropHandler.acceptedTypes, isTargeted: $isDropTargeted) { providers in
                ReceiptDropHandler.handle(providers, isGroupsOnly: isGroupsOnly, navigation: navigation)
            }
            // Con una hoja o un aviso delante el arrastre cae sobre ellos (o sobre su fondo oscurecido), no sobre esta raíz:
            // lo recoge la ventana (UX 2.2 · L15-12).
            .background { ReceiptWindowDropProbe(navigation: navigation, isGroupsOnly: isGroupsOnly) }
            .overlay {
                if isDropTargeted && ReceiptDropLogic.accepts(isGroupsOnly: isGroupsOnly)
                    && !ReceiptDropLogic.refusesWhile(shellBlocker: navigation.shellModalBlocker) {
                    ReceiptDropTargetOverlay()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .modifier(UITestReceiptDropSeam(navigation: navigation, isGroupsOnly: isGroupsOnly))
    }

    private var actions: RootCommandActions {
        let navigation = navigation
        let canSearch = canSearch
        return RootCommandActions(
            sections: KeyboardCommandLogic.sectionTabs(orderedTabs: sections),
            canSearch: canSearch,
            isGroupsOnly: isGroupsOnly,
            canUndoDeletion: UndoNoticeState.shared.isActive,
            perform: { RootCommandPerformer.perform($0, navigation: navigation, canSearch: canSearch) }
        )
    }
}

// MARK: - Marco al arrastrar un recibo (UX 2.2 · L4-11)

/// Marco y rótulo «Suelta para leer el recibo» mientras se arrastra un archivo encima. Relleno índigo de marca con texto
/// blanco (AA), sin brillo; no recibe toques.
private struct ReceiptDropTargetOverlay: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .strokeBorder(Color.selectedIndigoFill, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .fill(Color.selectedIndigoFill.opacity(0.08))
                )
                .padding(DS.Spacing.md)
            Label(L10n.Image.Entry.dropToRead, systemImage: "doc.viewfinder")
                .font(DS.Typography.headline)
                .foregroundStyle(Color.white)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(Capsule().fill(Color.selectedIndigoFill))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Soltar un recibo

/// Soltar una imagen o un PDF sobre Yala abre Nuevo registro por imagen (`ReceiptDropLogic`). Un PDF se guarda tal cual
/// y la hoja lo lee página a página (`PDFPageImport`, desde el 2026-10-08); si tiene contraseña, la pide la hoja.
///
/// **Con algo abierto y con varios archivos (UX 2.2 · L15-12, opción C, Jürgen 2026-10-18).** Antes, con una hoja, un
/// aviso o un bloqueo en la ventana el archivo volvía a su sitio sin explicación, y de varios se leía el primero y los
/// demás se perdían en silencio. Ahora se acepta y entra por el camino de la foto compartida, que espera a que se
/// cierre lo abierto (`RouterConsumerGateLogic`); y de varios se leen hasta 10 como una tanda (`SharedImageBatch`), con
/// el mismo aviso de los que no entraron. Solo rechazan los estados en los que la ventana no opera
/// (`ReceiptDropLogic.refusesWhile`).
///
/// Lo que no se puede abrir (PDF vacío o dañado, imagen dañada) abre el mismo registro por imagen en su fallo
/// «No pude abrir este archivo», el de Archivo desde dentro. Hasta el 2026-10-07 solo se escribía en el log: el sistema
/// ya había dado el soltar por aceptado y el usuario no veía nada. Lo que nunca es imagen ni PDF no llega aquí: el
/// `onDrop` solo acepta `acceptedTypes`, así que el sistema lo rechaza antes de soltar.
@MainActor
enum ReceiptDropHandler {
    static let acceptedTypes: [UTType] = [.image, .pdf]

    /// `true` si acepta el arrastre. Con una hoja abierta SÍ lo acepta: la hoja de lectura espera a que se cierre.
    static func handle(_ providers: [NSItemProvider], isGroupsOnly: Bool, navigation: SceneNavigation) -> Bool {
        guard ReceiptDropLogic.accepts(isGroupsOnly: isGroupsOnly) else { return false }
        guard !ReceiptDropLogic.refusesWhile(shellBlocker: navigation.shellModalBlocker) else { return false }
        let readable = providers.filter { provider in
            acceptedTypes.contains { provider.hasItemConformingToTypeIdentifier($0.identifier) }
        }
        guard !readable.isEmpty else { return false }

        // El recibo se abre en la ventana sobre la que se soltó, que no tiene por qué ser la que está al frente.
        let windowID = navigation.id
        SceneRegistry.shared.noteFocused(windowID)
        switch ReceiptDropLogic.decide(canAccessImageInput: FeatureGateService.shared.canAccess(.imageInput)) {
        case .upgrade:
            RouterEntryGate.shared.submit(.navigate(.panel))
            RouterEntryGate.shared.submit(.presentUpgradeSheet(.image))
        case .present:
            let taken = Array(readable.prefix(SharedImageBatch.maxImages))
            let droppedCount = readable.count
            // Todas las peticiones salen DENTRO del soltar, a la vez: lo arrastrado desde otra app se pide mientras dura
            // la sesión de arrastre. Y lo pesado (convertir cada foto a JPEG) se hace donde llega cada una, fuera del
            // hilo principal: diez fotos de 48 MP lo bloqueaban segundos (review adversarial del 2026-10-20).
            let collector = DropOutcomeCollector(count: taken.count) { outcomes in
                Task { @MainActor in
                    let sink = Sink.live(windowID: windowID)
                    if outcomes.count == 1, let only = outcomes.first {
                        deliver(only, sink: sink)
                    } else {
                        receiveBatch(outcomes, droppedCount: droppedCount, sink: sink)
                    }
                }
            }
            for (index, provider) in taken.enumerated() {
                let isPDF = provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
                let type = isPDF ? UTType.pdf : UTType.image
                _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                    #if DEBUG
                    if data == nil {
                        print("ReceiptDropHandler: Error: no se pudo leer lo soltado: \(String(describing: error))")
                    }
                    #endif
                    let result = autoreleasepool { outcome(for: data, isPDF: isPDF) }
                    collector.set(result, at: index)
                }
            }
        }
        return true
    }

    /// Lo que sale de lo soltado, sin efectos: el fichero que se va a leer (una imagen en JPEG, o el PDF tal cual, bloqueado
    /// o no), o el fallo que se le enseña al usuario.
    nonisolated enum Outcome: Equatable, Sendable {
        case readable(file: Data, isPDF: Bool)
        case failed(ImageEntryFailure)
    }

    nonisolated static func outcome(for data: Data?, isPDF: Bool) -> Outcome {
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
        /// Guarda un archivo de una tanda con su nombre (`SharedImageBatch.fileName`).
        var storeInBatch: (_ file: Data, _ fileName: String) -> URL? = { _, _ in nil }

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
                },
                storeInBatch: writePending
            )
        }
    }

    /// Varios archivos soltados a la vez: los legibles se guardan como una tanda y la hoja los lee juntos, como varias
    /// fotos compartidas. `droppedCount` cuenta también los que no entraron por el tope, para el aviso de la hoja. Lo
    /// ilegible se salta; si no queda nada, el fallo de siempre.
    static func receiveBatch(_ outcomes: [Outcome], droppedCount: Int, sink: Sink) {
        let batchID = SharedImageBatch.newBatchID()
        var first: URL?
        var index = 0
        for item in outcomes {
            guard case .readable(let file, let isPDF) = item else { continue }
            let name = ReceiptDropLogic.batchFileName(
                batchID: batchID, index: index, droppedCount: droppedCount, isPDF: isPDF)
            guard let url = sink.storeInBatch(file, name) else { continue }
            index += 1
            if first == nil { first = url }
        }
        guard let first else {
            sink.fail(.unreadableFile)
            return
        }
        sink.present(first)
    }

    /// Todo camino acaba en la hoja: con la foto, o con su fallo. Si no se puede guardar en `PendingImages/`, el archivo
    /// está bien y falló lo nuestro: `.generic`, no «no pude abrirlo».
    static func receive(_ data: Data?, isPDF: Bool, sink: Sink) {
        deliver(outcome(for: data, isPDF: isPDF), sink: sink)
    }

    /// Lo mismo que `receive`, con lo soltado ya convertido.
    static func deliver(_ outcome: Outcome, sink: Sink) {
        switch outcome {
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
        writePending(file, fileName: "drop-\(UUID().uuidString).\(isPDF ? "pdf" : "jpg")")
    }

    private static func writePending(_ file: Data, fileName: String) -> URL? {
        SharedContainerService.ensurePendingImagesDirectory()
        guard let directory = SharedContainerService.pendingImagesURL else { return nil }
        let url = directory.appendingPathComponent(fileName)
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

/// Junta lo que llega de cada elemento soltado, en su orden, y avisa una vez cuando han llegado todos. Las respuestas de
/// `NSItemProvider` llegan en cualquier hilo y en cualquier orden.
private nonisolated final class DropOutcomeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [ReceiptDropHandler.Outcome?]
    private var remaining: Int
    private let done: @Sendable ([ReceiptDropHandler.Outcome]) -> Void

    init(count: Int, done: @escaping @Sendable ([ReceiptDropHandler.Outcome]) -> Void) {
        outcomes = Array(repeating: nil, count: count)
        remaining = count
        self.done = done
    }

    func set(_ outcome: ReceiptDropHandler.Outcome, at index: Int) {
        lock.lock()
        outcomes[index] = outcome
        remaining -= 1
        let finished = remaining == 0 ? outcomes.map { $0 ?? .failed(.unreadableFile) } : nil
        lock.unlock()
        if let finished { done(finished) }
    }
}

// MARK: - Soltar sobre lo que está abierto (UX 2.2 · L15-12)

/// Recoge en la VENTANA lo que se suelta encima de una hoja, un aviso o su fondo oscurecido. El `onDrop` de la raíz no lo
/// ve: UIKit busca quién acepta el arrastre subiendo desde la vista que hay debajo del dedo, y lo presentado no cuelga
/// de la raíz sino de la ventana. Sin nada presentado no actúa: ahí contesta antes el `onDrop` de la raíz, que es más
/// profundo, y pinta su marco.
private struct ReceiptWindowDropProbe: UIViewRepresentable {
    let navigation: SceneNavigation
    let isGroupsOnly: Bool

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.delegateBox.navigation = navigation
        view.delegateBox.isGroupsOnly = isGroupsOnly
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.delegateBox.navigation = navigation
        view.delegateBox.isGroupsOnly = isGroupsOnly
    }

    static func dismantleUIView(_ view: ProbeView, coordinator: ()) {
        view.detach()
    }

    final class ProbeView: UIView {
        let delegateBox = WindowDropDelegate()
        private lazy var interaction = UIDropInteraction(delegate: delegateBox)
        private weak var installedWindow: UIWindow?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window !== installedWindow else { return }
            detach()
            guard let window else { return }
            window.addInteraction(interaction)
            installedWindow = window
        }

        func detach() {
            installedWindow?.removeInteraction(interaction)
            installedWindow = nil
        }
    }

    final class WindowDropDelegate: NSObject, UIDropInteractionDelegate {
        weak var navigation: SceneNavigation?
        var isGroupsOnly = false

        private var acceptsNow: Bool {
            guard let navigation, ReceiptDropLogic.accepts(isGroupsOnly: isGroupsOnly),
                  !ReceiptDropLogic.refusesWhile(shellBlocker: navigation.shellModalBlocker)
            else { return false }
            return ModalPresentationProbe.isAnythingPresented(in: SceneRegistry.shared.windowScene(for: navigation.id))
        }

        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            session.hasItemsConforming(toTypeIdentifiers: ReceiptDropHandler.acceptedTypes.map(\.identifier))
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            UIDropProposal(operation: acceptsNow ? .copy : .forbidden)
        }

        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            guard let navigation, acceptsNow else { return }
            _ = ReceiptDropHandler.handle(
                session.items.map(\.itemProvider), isGroupsOnly: isGroupsOnly, navigation: navigation)
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
