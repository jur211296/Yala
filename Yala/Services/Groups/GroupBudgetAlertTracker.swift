//
//  GroupBudgetAlertTracker.swift
//  Yala
//
//  «De qué umbrales del presupuesto de un grupo ya avisé» (G14). Molde de `BudgetAlertTracker`, que
//  hace lo mismo para el presupuesto personal.
//
//  LA CLAVE LLEVA EL TOPE DENTRO, Y ESO ES EL DISEÑO, NO UN DETALLE. El presupuesto personal reparte
//  sus claves por PERÍODO (`yyyy-MM`, `yyyy-Www`…), porque un presupuesto mensual estrena mes y con él
//  su derecho a volver a avisar. Un presupuesto de grupo no tiene períodos: es un tope fijo para un
//  viaje. Lo que sí cambia es el TOPE, y cuando cambia, los avisos tienen que reabrirse — subir el
//  límite de 3.000 a 6.000 y volver a cruzar el 50 % es un aviso legítimo, no un duplicado. Con una
//  clave que solo llevara el grupo, ese segundo 50 % no llegaría nunca.
//
//  Y al revés: bajar el tope de 6.000 a 3.000 con el grupo ya al 80 % estrena clave y avisa
//  inmediatamente, que es justo lo que hay que decirle a quien acaba de recortar el presupuesto.
//

import Foundation

@MainActor
final class GroupBudgetAlertTracker {

    static let shared = GroupBudgetAlertTracker()

    /// Prefijo de las claves de dedup. Expuesto porque `DataWipeService` las barre POR PREFIJO: llevan
    /// dentro el zone id del grupo y el importe del tope, así que ninguna lista explícita las nombra.
    static let keyPrefix = "GroupBudgetAlerts.notified."

    private let defaults: UserDefaults

    private init() {
        self.defaults = .standard
    }

    /// Init de test — `UserDefaults` aislado; jamás en producción.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - Clave

    /// El tope entra en la clave con escala fija: `Double.description` daría `3000.0` en un sitio y
    /// `3000` en otro para el mismo número, y eso partiría la clave en dos.
    private func key(groupZoneID: String, limitAmount: Double) -> String {
        let limit = limitAmount.isFinite ? limitAmount : 0
        return "\(Self.keyPrefix)\(groupZoneID).\(String(format: "%.4f", limit))"
    }

    // MARK: - Lectura y escritura

    func notifiedThresholds(groupZoneID: String, limitAmount: Double) -> [Int] {
        defaults.array(forKey: key(groupZoneID: groupZoneID, limitAmount: limitAmount)) as? [Int] ?? []
    }

    /// `false` la PRIMERA vez que se mira este par (grupo, tope) en este teléfono.
    ///
    /// Distinguir "nunca lo he mirado" de "lo miré y no había nada cruzado" es lo que permite sembrar
    /// una línea base en vez de avisar hacia atrás: sin esto, reinstalar la app haría sonar «llegasteis
    /// al presupuesto» por un viaje que terminó hace meses, y ponerle hoy un tope a un grupo con año y
    /// medio de gastos dispararía los cuatro umbrales de golpe.
    func hasBaseline(groupZoneID: String, limitAmount: Double) -> Bool {
        defaults.array(forKey: key(groupZoneID: groupZoneID, limitAmount: limitAmount)) != nil
    }

    /// Siembra los umbrales ya cruzados SIN notificarlos. Se escribe aunque venga vacío: el propio hecho
    /// de que la clave exista es lo que marca "ya observado".
    func setBaseline(groupZoneID: String, limitAmount: Double, thresholds: [Int]) {
        defaults.set(thresholds, forKey: key(groupZoneID: groupZoneID, limitAmount: limitAmount))
    }

    func markNotified(groupZoneID: String, limitAmount: Double, threshold: Int) {
        let k = key(groupZoneID: groupZoneID, limitAmount: limitAmount)
        var current = defaults.array(forKey: k) as? [Int] ?? []
        guard !current.contains(threshold) else { return }
        current.append(threshold)
        defaults.set(current, forKey: k)
    }

    // MARK: - Limpieza

    /// Barre las claves de topes que ya no están vigentes en ningún grupo.
    ///
    /// No se puede limpiar «por antigüedad» como hacen los trackers con período: aquí la clave no tiene
    /// fecha. Lo que sí se sabe es qué pares (grupo, tope) siguen VIVOS, y todo lo demás es de un tope
    /// que se cambió o de un grupo que ya no está.
    func cleanupOrphanedEntries(liveKeys: Set<String>) {
        for k in defaults.dictionaryRepresentation().keys where k.hasPrefix(Self.keyPrefix) {
            if !liveKeys.contains(k) { defaults.removeObject(forKey: k) }
        }
    }

    /// La clave viva de un grupo con presupuesto, para pasársela a `cleanupOrphanedEntries`.
    func liveKey(groupZoneID: String, limitAmount: Double) -> String {
        key(groupZoneID: groupZoneID, limitAmount: limitAmount)
    }
}
