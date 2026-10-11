//
//  UITestSharedImageStage.swift
//  Yala
//
//  Seam de XCUITest para la hoja de compartir. La extensión `YalaShare` es otro proceso y XCUITest no la conduce:
//  lo que hace —guardar la foto en `PendingImages/` y abrir `yala://shared-image`— se reproduce aquí. El test abre
//  `<scheme>://shared-image?uitest-stage=readable` (con `app.open(_:)` en caliente o `-uitest-deeplink-url` en frío) y
//  este seam deja el recibo de ejemplo en el App Group ANTES de que `handleIncomingURL` siga por su camino real.
//  Con `uitest-shared=N` (N > 1) deja una tanda como la de varias fotos compartidas a la vez: las primeras
//  `SharedImageBatch.maxImages` con el nombre de la tanda y `N` como total compartido.
//  Fuera de `-uitest` no hace nada, y en release no existe.
//

#if DEBUG
import UIKit

enum UITestSharedImageStage {

    /// Si la URL trae `uitest-stage=readable` y la app corre bajo `-uitest`, guarda el recibo de ejemplo como lo
    /// guardaría la extensión: `<UUID>.jpg` con una foto, la tanda (`SharedImageBatch`) con `uitest-shared=N`.
    static func stageIfRequested(by url: URL) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard UITestHooks.isActive,
              items.first(where: { $0.name == "uitest-stage" })?.value == "readable"
        else { return }
        guard let data = UIImage(named: "ExampleImages/example-receipt-es")?.jpegData(compressionQuality: 0.8) else {
            print("UITestSharedImageStage: Error: falta el recibo de ejemplo")
            return
        }
        SharedContainerService.ensurePendingImagesDirectory()
        guard let directory = SharedContainerService.pendingImagesURL else { return }
        let shared = items.first(where: { $0.name == "uitest-shared" })?.value.flatMap(Int.init) ?? 1
        let names: [String]
        if shared > 1 {
            let batchID = SharedImageBatch.newBatchID()
            names = (0..<min(shared, SharedImageBatch.maxImages)).map {
                SharedImageBatch.fileName(batchID: batchID, index: $0, sharedCount: shared)
            }
        } else {
            names = ["\(UUID().uuidString).jpg"]
        }
        for name in names {
            let fileURL = directory.appendingPathComponent(name)
            do {
                try data.write(to: fileURL, options: .atomic)
                print("UITestSharedImageStage: staged \(fileURL.lastPathComponent)")
            } catch {
                print("UITestSharedImageStage: Error: \(error)")
            }
        }
    }
}
#endif
