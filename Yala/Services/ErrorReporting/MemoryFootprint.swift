//
//  MemoryFootprint.swift
//  Yala
//
//  Cuánta memoria usa la app ahora y cuánta le queda antes de que iOS la cierre. Es la cifra que mira el sistema para
//  cerrar una app por exceso de memoria (`phys_footprint`, la misma de Xcode e Instruments), no la memoria del
//  teléfono. Se lee en microsegundos y sin datos del usuario: va a Sentry tal cual (`MemoryDiagnostics`).
//

import Darwin
import Foundation
import os

nonisolated enum MemoryFootprint {

    struct Sample: Equatable, Sendable {
        /// Memoria propia de la app, en bytes.
        let footprintBytes: UInt64
        /// Lo que le queda antes del límite del sistema, en bytes. `nil` donde iOS no lo da (simulador, Mac).
        let availableBytes: UInt64?
    }

    static func current() -> Sample? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), raw, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            #if DEBUG
            print("MemoryFootprint: Error: task_info devolvió \(result)")
            #endif
            return nil
        }
        let available = os_proc_available_memory()
        return Sample(footprintBytes: info.phys_footprint, availableBytes: available > 0 ? UInt64(available) : nil)
    }
}
