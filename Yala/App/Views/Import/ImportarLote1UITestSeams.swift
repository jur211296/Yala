//
//  ImportarLote1UITestSeams.swift
//  Yala
//
//  Atajo de XCUITest para Importar registros. Solo en DEBUG y solo con `-uitest`:
//
//  - `-uitest-import-records-file <ruta>`: «Seleccionar archivo» lee ese archivo en vez de abrir Archivos. El selector
//    de documentos es del sistema y un XCUITest no lo conduce con fiabilidad; lo que se prueba es lo que pasa DESPUÉS de
//    elegir (vista previa, duplicados, «Deshacer importación»). Molde: `ImportarGrupoUITestSeams`.
//

import Foundation

enum ImportarLote1UITestSeams {

    #if DEBUG
    /// La ruta del archivo que «Seleccionar archivo» lee sin abrir Archivos, o `nil`.
    static var filePath: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uitest"), let index = arguments.firstIndex(of: "-uitest-import-records-file"),
              index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
    #else
    static var filePath: String? { nil }
    #endif
}
