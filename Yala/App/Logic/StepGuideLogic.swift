//
//  StepGuideLogic.swift
//  Yala
//
//  El estado de una guía por pasos con la forma de la referencia del 2026-09-15
//  (`docs/design/referencias/2026-09-15-flujo-por-pasos-cancelar-suscripcion.jpg`): cuántos pasos van hechos,
//  cuál es el único que se puede tocar y qué dicen las barras y el «Paso N de M» de arriba.
//
//  Los pasos de estas guías se hacen FUERA de Yala (Atajos, la pantalla de inicio) e iOS no le cuenta a la app si
//  se hicieron, así que el progreso lo marca la persona: «Hecho» en el paso activo, o la acción del paso cuando la
//  acción ES el paso (abrir Atajos). Decisión de Jürgen, 2026-10-02.
//

import Foundation

/// En qué punto está un paso respecto al activo.
nonisolated enum StepGuidePhase: Equatable {
    case done
    case active
    case upcoming
}

nonisolated struct StepGuideProgress: Equatable {
    let total: Int
    /// Pasos marcados como hechos, de 0 a `total`. Siempre son los primeros: se avanza en orden.
    private(set) var completed: Int

    init(total: Int, completed: Int = 0) {
        self.total = max(0, total)
        self.completed = min(max(0, completed), self.total)
    }

    /// El único paso accionable. `nil` cuando ya están todos hechos.
    var activeIndex: Int? { completed < total ? completed : nil }

    var isFinished: Bool { completed >= total }

    /// El N de «Paso N de M»: el paso activo, o el último cuando ya no queda ninguno. Nunca 0 ni mayor que M.
    var displayedStep: Int { total == 0 ? 0 : min(completed + 1, total) }

    func phase(of index: Int) -> StepGuidePhase {
        if index < completed { return .done }
        if index == completed { return .active }
        return .upcoming
    }

    /// Las barras de arriba se llenan hasta el paso que se está mirando, él incluido: «Paso 1 de 3» ya pinta la
    /// primera, como en la referencia.
    func isBarFilled(_ index: Int) -> Bool { index < displayedStep }

    /// Marca el paso activo como hecho. Solo avanza desde el activo: un toque tardío sobre un paso que ya no lo es
    /// (doble toque, o la vuelta de abrir otra app) no se salta el siguiente.
    mutating func complete(_ index: Int) {
        guard index == activeIndex else { return }
        completed += 1
    }
}

/// El avance de una guía, guardado por guía: el pie promete «tu avance se guarda» mientras faltan pasos (auditoría UX
/// 2.2, lote 15, L15-10), así que salir y volver tiene que dejarla donde estaba. Terminar la guía lo borra: volver a
/// entrar después es para repasarla desde el principio. Es del dispositivo (los pasos se hacen en ESTE iPhone), no se
/// sincroniza.
nonisolated enum StepGuideProgressStore {
    /// Las guías que guardan avance: Apple Pay (Tutoriales) y Face ID (Seguridad).
    static let applePay = "applePay"
    static let faceID = "faceID"
    static let guideIDs = [applePay, faceID]

    static func key(_ guideID: String) -> String { "stepGuide.progress.\(guideID)" }

    static func load(_ guideID: String, total: Int, defaults: UserDefaults = .standard) -> StepGuideProgress {
        StepGuideProgress(total: total, completed: defaults.integer(forKey: key(guideID)))
    }

    static func save(_ progress: StepGuideProgress, guideID: String, defaults: UserDefaults = .standard) {
        defaults.set(progress.completed, forKey: key(guideID))
    }

    static func clear(_ guideID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(guideID))
    }
}

extension StepGuideProgress {
    /// Los pasos que quedan, el activo incluido: «Te faltan 2 pasos» en el paso 3 de 4.
    nonisolated var remaining: Int { total - completed }
}

