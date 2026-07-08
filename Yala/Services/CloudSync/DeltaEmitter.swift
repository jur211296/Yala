//
//  DeltaEmitter.swift
//  Yala
//
//  Proyecta un `@Model` mutado + el set de columnas TOCADAS al `fields` (dominio limpio, PATCH parcial)
//  y `field_hlcs` (por unidad de coherencia) que sube un delta del Modo Nube (incremento I8c). Es el
//  puente entre el drain de I3 (`CloudSyncEngine`) y el codec canónico c1 de I8a: DeltaEmitter arma el
//  mapa `[columna: CanonValue]` (NO lo codifica — eso lo hace `Canonc1Codec.encode` en el consumidor,
//  que puede lanzar) + el mapa `[unidad: hlc]`.
//
//  INVARIANTE DE EMISIÓN (§d.4bis): si una columna tocada pertenece a un grupo de coherencia
//  (money/split/budget/tx_split), se EXPANDE al grupo ENTERO — se leen del modelo los valores actuales
//  de las columnas del grupo NO tocadas y se emite el grupo completo. Un grupo NUNCA viaja parcial (o el
//  merge por-campo del backend divergiría el "número mal convertido"). La expansión es total por
//  construcción; el guard client-side (`coherenceGroupPartial`) es una RED defensiva — no debe dispararse.
//
//  UNIDADES de `field_hlcs` (§d.4bis): la unidad de una columna emitida = su `group_key` si lo tiene, si
//  no la columna misma (singleton field-level). TODAS las unidades tocadas en esta transacción reciben el
//  MISMO `hlc` (el de la transacción de History) → `{"money": hlc, "note": hlc}`.
//
//  `@MainActor`: los builders leen `@Model`/relaciones.
//

import Foundation

@MainActor
enum DeltaEmitter {

    /// Resultado de una emisión: el `fields` (columna → valor canónico tipado) y el `field_hlcs`
    /// (unidad de coherencia → HLC). `fields` va al codec c1; `field_hlcs` se serializa como JSON plano.
    struct Result: Equatable {
        let fields: [String: CanonValue]
        let fieldHlcs: [String: String]
    }

    /// Emite el delta para `model` dado el set de columnas Postgres tocadas.
    /// - Parameters:
    ///   - model: la entidad mutada.
    ///   - emission: la proyección declarativa de la entidad (`EntityEmissionMap.*`).
    ///   - changedColumns: columnas Postgres TOCADAS (PATCH parcial). En un INSERT = todas las columnas.
    ///   - hlc: el HLC de la transacción de History (el mismo para todas las unidades de esta emisión).
    ///   - calendar: calendario para derivar `local_day` (inyectable para determinismo; default `.current`).
    /// - Returns: `fields` (dominio limpio) + `field_hlcs` (por unidad).
    static func emit<Model: AnyObject>(
        model: Model,
        emission: EntityEmission<Model>,
        changedColumns: Set<String>,
        hlc: String,
        calendar: Calendar = .current
    ) -> Result {
        // 1) Índices de grupo desde los emisores: group_key → [columnas], y columna → group_key.
        var columnsByGroup: [String: [String]] = [:]
        var groupByColumn: [String: String] = [:]
        for emitter in emission.emitters {
            guard let group = emitter.group else { continue }
            columnsByGroup[group, default: []].append(emitter.column)
            groupByColumn[emitter.column] = group
        }

        // 2) Expansión del invariante: toda columna tocada que pertenezca a un grupo arrastra el grupo
        //    ENTERO. `targetColumns` = tocadas ∪ (columnas de los grupos tocados).
        var touchedGroups: Set<String> = []
        for column in changedColumns {
            if let group = groupByColumn[column] { touchedGroups.insert(group) }
        }
        var targetColumns = changedColumns
        for group in touchedGroups {
            for column in columnsByGroup[group] ?? [] { targetColumns.insert(column) }
        }

        // 3) Construir `fields` para las columnas objetivo (leyendo el estado ACTUAL del modelo).
        var fields: [String: CanonValue] = [:]
        for emitter in emission.emitters where targetColumns.contains(emitter.column) {
            fields[emitter.column] = emitter.build(model, calendar)
        }

        // 4) Guard client-side del invariante (RED defensiva §d.4bis): tras la expansión, todo grupo
        //    tocado debe tener TODAS sus columnas en `fields`. Si no, es un bug del emisor → canario.
        for group in touchedGroups {
            let groupColumns = columnsByGroup[group] ?? []
            let present = groupColumns.filter { fields[$0] != nil }.count
            if present != groupColumns.count {
                CloudSyncBreadcrumb.coherenceGroupPartial(entity: emission.table, group: group)
                TelemetryService.cloudSyncCoherenceGroupPartial(entity: emission.table, group: group)
            }
        }

        // 5) `field_hlcs`: unidad de cada columna que VIAJARÁ en `fields` = su grupo, si no la columna
        //    misma. Todas las unidades reciben el mismo `hlc` de la transacción.
        //    §d.4bis (MODO-NUBE-ARQUITECTURA:487): "field_hlcs con SOLO las unidades cuyas columnas están
        //    en `fields`". El codec OMITE del wire toda `.uuidArray` VACÍA **SINGLETON** (§d.1/O8 —
        //    sin-filtro ≠ null ≠ []) → esa columna NO está en el `fields` que viaja → su unidad NO debe ir
        //    en `field_hlcs`. Derivar las unidades de `fields.keys` a secas embarcaba un unit huérfano
        //    (p.ej. "tag_refs" en un insert sin tags) sin columna en el wire: el Worker
        //    (`validateUpsertShape` solo valida fields→field_hlcs, no el reverso) lo ACEPTA y el RPC
        //    avanzaría el reloj de esa unidad SIN valor → rechazo espurio de un update legítimo posterior
        //    de OTRO device (LWW por unidad). Excluir aquí las columnas que el codec omitirá reproduce el
        //    contrato del wire. Una `.uuidArray` vacía DENTRO de un grupo SÍ viaja (`[]` explícito,
        //    DIFERIDOS #25 opción 1) → su unidad SÍ cuenta (el skip es solo-singleton).
        var units: Set<String> = []
        for (column, value) in fields {
            if case .uuidArray(let ids) = value, ids.isEmpty, groupByColumn[column] == nil {
                continue  // singleton vacía: el codec la OMITE → no viaja
            }
            units.insert(groupByColumn[column] ?? column)
        }
        var fieldHlcs: [String: String] = [:]
        for unit in units { fieldHlcs[unit] = hlc }

        return Result(fields: fields, fieldHlcs: fieldHlcs)
    }
}
