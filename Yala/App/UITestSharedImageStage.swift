//
//  UITestSharedImageStage.swift
//  Yala
//
//  Seam de XCUITest para la hoja de compartir. La extensión `YalaShare` es otro proceso y XCUITest no la conduce:
//  lo que hace —guardar la foto en `PendingImages/` y abrir `yala://shared-image`— se reproduce aquí. El test abre
//  `<scheme>://shared-image?uitest-stage=readable` (con `app.open(_:)` en caliente o `-uitest-deeplink-url` en frío) y
//  este seam deja el recibo de ejemplo en el App Group ANTES de que `handleIncomingURL` siga por su camino real.
//  Fuera de `-uitest` no hace nada, y en release no existe.
//

#if DEBUG
import UIKit

enum UITestSharedImageStage {

    /// Si la URL trae `uitest-stage=readable` y la app corre bajo `-uitest`, guarda el recibo de ejemplo como lo
    /// guardaría la extensión (`<UUID>.jpg`).
    static func stageIfRequested(by url: URL) {
        guard UITestHooks.isActive,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "uitest-stage" })?.value,
              value == "readable"
        else { return }
        guard let data = UIImage(named: "ExampleImages/example-receipt-es")?.jpegData(compressionQuality: 0.8) else {
            print("UITestSharedImageStage: Error: falta el recibo de ejemplo")
            return
        }
        SharedContainerService.ensurePendingImagesDirectory()
        guard let directory = SharedContainerService.pendingImagesURL else { return }
        let fileURL = directory.appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try data.write(to: fileURL, options: .atomic)
            print("UITestSharedImageStage: staged \(fileURL.lastPathComponent)")
        } catch {
            print("UITestSharedImageStage: Error: \(error)")
        }
    }
}
#endif
