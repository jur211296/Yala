//
//  CloudProgressStepsLogic.swift
//  Yala
//
//  Los pasos que enseña «Dónde viven tus datos» mientras se activa la nube o se vuelve a iCloud (opción B del lienzo de
//  propuestas, decisión de Jürgen del 2026-10-22; ticket `cloud-progress-shows-real-steps-and-counts`, cards igt9, ppxk y
//  27z3). Hasta ese día la tarjeta era una barra por fases (22, 35, 55, 75, 80 %) que se quedaba quieta minutos mientras
//  la subida avanzaba de verdad, y la vuelta enseñaba «Pendientes de subir: 448» sin bajar.
//
//  Cada paso tiene su estado (hecho, en marcha, pendiente) y, si hay una cifra real que contar, la lleva: cuántos datos
//  subieron de cuántos, cuántos faltan por llegar a iCloud, cuántos se borraron de lo de antes. Cuando lo que se espera es
//  a iCloud, el paso lo dice con su nombre.
//
//  Pura: la vista solo pinta lo que sale de aquí.
//

import Foundation

nonisolated enum CloudProgressStepsLogic {

    /// Qué paso es. El título y la explicación los pone la vista.
    enum Kind: Equatable {
        // Ida
        case connect
        case prepare
        case upload
        case confirm
        // Las dos direcciones: la app espera a que iCloud termine de traer datos (el import del espejo).
        case waitICloud
        // Vuelta
        case wipePrior
        case bring
        case review
        case uploadToICloud
    }

    enum State: Equatable { case done, active, pending }

    /// La cifra de un paso. Solo existe si hay algo real que contar.
    enum Count: Equatable {
        /// Datos subidos a la nube de un total. `fraction` es lo que llena la barra.
        case uploaded(done: Int, total: Int, fraction: Double)
        /// Datos que todavía no llegaron a iCloud.
        case pendingToICloud(Int)
        /// Datos de antes borrados de iCloud hasta ahora.
        case wiped(Int)
    }

    struct Step: Equatable {
        let kind: Kind
        let state: State
        var count: Count? = nil
    }

    /// Lo que sube la ida: filas de las 16 tablas, confirmadas por el servidor, de cuántas hay.
    struct UploadProgress: Equatable {
        let done: Int
        let total: Int
    }

    // MARK: - Ida

    /// Los pasos de «Activar la nube» para la fase journaleada.
    ///
    /// - `adoptEffectPending`: la fase es `notStarted` con el efecto del adopt pendiente (se está trayendo la cuenta a este
    ///   dispositivo): es el paso de preparar.
    /// - `waitingForICloud`: la app está esperando a que iCloud termine de traer datos (la pre-espera del controller o la del
    ///   runner). Si la espera llega antes de subir, ocupa el sitio de «Preparar tus datos» —lo que el lienzo B2 enseña—; si
    ///   llega después, va delante del paso que espera, que queda pendiente.
    /// - `upload`: el progreso de la subida, si ya se conoce.
    static func forwardSteps(
        phase: MigrationPhase, adoptEffectPending: Bool, waitingForICloud: Bool, upload: UploadProgress?
    ) -> [Step] {
        let order: [Kind] = [.connect, .prepare, .upload, .confirm]
        let active = forwardActiveIndex(phase: phase, adoptEffectPending: adoptEffectPending)
        var steps: [Step] = order.enumerated().map { index, kind in
            Step(kind: kind, state: state(index: index, active: active))
        }
        if let uploadIndex = steps.firstIndex(where: { $0.kind == .upload }), steps[uploadIndex].state == .active {
            steps[uploadIndex].count = uploadCount(phase: phase, upload: upload)
        }
        guard waitingForICloud, active < order.count else { return steps }
        if active <= 1 {
            // La espera llega antes de preparar nada: conectar ya está hecho y la espera es el paso en marcha.
            steps[0] = Step(kind: .connect, state: .done)
            steps[1] = Step(kind: .waitICloud, state: .active)
            return steps
        }
        steps[active] = Step(kind: steps[active].kind, state: .pending)
        steps.insert(Step(kind: .waitICloud, state: .active), at: active)
        return steps
    }

    /// Índice del paso en marcha (4 = todo hecho).
    static func forwardActiveIndex(phase: MigrationPhase, adoptEffectPending: Bool) -> Int {
        switch phase {
        case .notStarted:
            return adoptEffectPending ? 1 : 0
        case .dryRun, .consent, .authenticating, .claimingMigration, .waitingForLeader, .failedRollback:
            return 0
        case .assigningIdentity:
            return 1
        case .uploadingSnapshot, .verifying:
            return 2
        case .cutover:
            return 3
        case .done:
            return 4
        case .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend,
             .reverseMountMirror, .reverseReconcile, .reverseUpload, .icloudActive, .reverseFailedRollback:
            return 0
        }
    }

    /// La cifra de la subida. En la verificación todo subió: la barra va llena aunque la pasada no la haya contado (tras
    /// relanzar no hay progreso en memoria).
    static func uploadCount(phase: MigrationPhase, upload: UploadProgress?) -> Count? {
        if phase == .verifying {
            guard let upload, upload.total > 0 else { return nil }
            return .uploaded(done: upload.total, total: upload.total, fraction: 1)
        }
        guard let upload, upload.total > 0 else { return nil }
        let done = min(max(upload.done, 0), upload.total)
        return .uploaded(done: done, total: upload.total, fraction: Double(done) / Double(upload.total))
    }

    // MARK: - Vuelta

    /// Los pasos de «Volver a iCloud».
    ///
    /// - `wipingDeleted`: «Borrar y volver a iCloud» está borrando lo de antes (cuántos lleva). Es el primer paso.
    /// - `startingReverse`: la vuelta se pidió y el journal aún no se movió (la app espera a iCloud antes de empezar, o el
    ///   primer guardado no llegó). Sin esto la pantalla se quedaba con «Volver a iCloud» apagado y nada más.
    /// - `pending`: cuántos datos faltan por llegar a iCloud (la última muestra).
    /// - `firstPending`: la primera muestra de esta subida. Mientras la cifra no baje de ahí, iCloud todavía no subió nada:
    ///   está revisando lo que ya tiene (el lienzo B3).
    static func reverseSteps(
        phase: MigrationPhase, waitingForICloud: Bool, wipingDeleted: Int?, startingReverse: Bool,
        pending: Int?, firstPending: Int?
    ) -> [Step] {
        let order: [Kind] = [.bring, .review, .uploadToICloud]
        var steps: [Step]
        if let wipingDeleted {
            steps = [Step(kind: .wipePrior, state: .active, count: .wiped(wipingDeleted))]
                + order.map { Step(kind: $0, state: .pending) }
            return steps
        }
        let active = reverseActiveIndex(
            phase: phase, startingReverse: startingReverse, pending: pending, firstPending: firstPending)
        steps = order.enumerated().map { index, kind in Step(kind: kind, state: state(index: index, active: active)) }
        if let pending, active < order.count {
            steps[2].count = .pendingToICloud(pending)
        }
        guard waitingForICloud, active < order.count, active != 1 else { return steps }
        // En «iCloud revisa lo que ya tiene» la espera ES el paso (el espejo importa lo que guarda): no se duplica.
        steps[active] = Step(kind: steps[active].kind, state: .pending, count: steps[active].count)
        steps.insert(Step(kind: .waitICloud, state: .active), at: active)
        return steps
    }

    /// Índice del paso en marcha de la vuelta (3 = todo hecho).
    static func reverseActiveIndex(phase: MigrationPhase, startingReverse: Bool, pending: Int?, firstPending: Int?) -> Int {
        switch phase {
        case .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend,
             .reverseMountMirror, .reverseFailedRollback:
            return 0
        case .reverseReconcile:
            return 1
        case .reverseUpload:
            guard let pending, let firstPending else { return 1 }
            if pending == 0 { return 2 }
            return pending < firstPending ? 2 : 1
        case .icloudActive:
            return 3
        case .notStarted, .dryRun, .consent, .authenticating, .claimingMigration, .assigningIdentity,
             .uploadingSnapshot, .verifying, .cutover, .done, .failedRollback, .waitingForLeader:
            // Fuera de la vuelta: solo se pinta si la vuelta se acaba de pedir y el journal todavía no la recoge.
            return startingReverse ? 0 : 3
        }
    }

    /// La primera muestra de pendientes de la subida de la vuelta, para saber si iCloud ya empezó a subir. Se conserva
    /// mientras la fase siga en `reverseUpload`; fuera, se olvida. Si una muestra trae MÁS que la primera (iCloud contó
    /// filas que antes no veía), la primera sube con ella: la cifra de partida no puede quedar por debajo de lo que hay.
    static func firstPending(previous: Int?, phase: MigrationPhase, pending: Int?) -> Int? {
        guard phase == .reverseUpload else { return nil }
        guard let pending else { return previous }
        guard let previous else { return pending }
        return max(previous, pending)
    }

    // MARK: - Re-empuje de la pantalla

    /// Cada cuántos segundos re-empuja la pantalla una migración aparcada. 30 s es el de siempre (C-1, para que los techos
    /// lleguen a evaluarse). En las fases donde lo único que falta es OBSERVAR algo local de iCloud —el marcador, el
    /// espejo apagado o montado, lo que queda por subir de la vuelta— cada pasada es barata (lee el disco, no la red salvo
    /// un latido de ≤1/min) y la espera de 30 s era tiempo perdido y una cifra congelada (cards ppxk y 27z3): 5 s.
    static func screenRekickSeconds(phase: MigrationPhase) -> Int {
        switch phase {
        case .cutover(.markerWritten), .cutover(.mirrorOff), .reverseMountMirror, .reverseUpload:
            return 5
        case .reverseReconcile(.awaitingQuiescence):
            return 5
        default:
            return 30
        }
    }

    private static func state(index: Int, active: Int) -> State {
        if index < active { return .done }
        return index == active ? .active : .pending
    }
}

/// Los nombres de fase del canario `cloudMigrationStep`. Viajan: renombrar uno parte la serie del dashboard. Cortos y sin
/// valores asociados que cambien (el sub-estado del cutover y del reconcile sí van, porque dicen en qué espera).
nonisolated enum CloudMigrationTimelineLogic {
    static func label(_ phase: MigrationPhase) -> String {
        switch phase {
        case .notStarted:            return "notStarted"
        case .dryRun:                return "dryRun"
        case .consent:               return "consent"
        case .authenticating:        return "auth"
        case .claimingMigration:     return "claim"
        case .assigningIdentity:     return "identity"
        case .uploadingSnapshot:     return "upload"
        case .verifying:             return "verify"
        case let .cutover(sub):      return "cutover.\(sub)"
        case .done:                  return "done"
        case .failedRollback:        return "failed"
        case .waitingForLeader:      return "follower"
        case .reverseConfirm:        return "rConfirm"
        case .reverseClaimLeader:    return "rClaim"
        case .reverseDrainAll:       return "rDrain"
        case .reverseVerify:         return "rVerify"
        case .reverseFreezeBackend:  return "rFreeze"
        case .reverseMountMirror:    return "rMount"
        case let .reverseReconcile(sub): return "rReconcile.\(sub)"
        case .reverseUpload:         return "rUpload"
        case .icloudActive:          return "icloudActive"
        case .reverseFailedRollback: return "rFailed"
        }
    }

    /// Segundos que duró el paso que se deja: `nil` si empezó antes de este proceso (no hay hora en memoria) o si el reloj
    /// fue hacia atrás.
    static func previousStepSeconds(since: Date?, now: Date) -> Double? {
        guard let since else { return nil }
        let seconds = now.timeIntervalSince(since)
        return seconds >= 0 ? seconds.rounded() : nil
    }
}
