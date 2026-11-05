//
//  StoreSaveCounter.swift
//  Yala
//
//  Cuántas veces se ha guardado algo en SwiftData en este proceso, desde cualquier contexto.
//
//  Es la señal de «los datos pudieron cambiar» que no depende de que cada escritor llame a
//  `SessionState.incrementDataVersion()`: hay más de setenta escritores y no todos avisan (inventario en el ticket
//  `panel-recalculates-everything-on-every-return-to-the-tab`). `ModelContext.didSave` lo publica cualquier contexto al
//  guardar, también el autoguardado y los de los almacenes de Grupos. Solo se cuenta: nadie reacciona a cada guardado,
//  lo leen quienes quieren saber si algo cambió desde la última vez que miraron (`PanelReloadFreshness`).
//

import Foundation
import SwiftData

@MainActor
final class StoreSaveCounter {

    static let shared = StoreSaveCounter()

    private(set) var count = 0
    private var observer: NSObjectProtocol?

    /// Nace con su primera lectura. Lo que se guardó antes no hace falta contarlo: quien lee compara contra lo que leyó
    /// la vez anterior, y la primera lectura siempre es «no sé nada todavía».
    init(center: NotificationCenter = .default) {
        // Un contexto de fondo publica en su propia cola: el contador vive en el main actor.
        observer = center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.count &+= 1 }
        }
    }
}
