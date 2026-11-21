//
//  FlujoFluidezLogica.swift
//  Yala
//
//  Cuándo Reportes vuelve a calcular (encargo de fluidez del 20-nov-2026). El Flujo de caja recalculaba la proyección
//  entera en cada aparición de la pestaña, al cerrar cualquier hoja (también la de solo mirar una línea) y al volver de
//  Registros; la Comparativa, con cada cambio de filtro aunque no se viera. Ahora cada una recuerda con qué calculó y
//  solo repite si algo de eso cambió. El molde es `StatisticsCalculationStamp`.
//

import Foundation

/// Lo que lee la proyección del flujo de caja y puede cambiar sin que la vista lo oiga.
struct FlujoRecalculoFirma: Equatable {
    /// Sube con cada cambio del plan que no pasa por una hoja (`CashFlowPlanViewModel.planRevision`).
    let planRevision: Int
    let dataVersion: Int
    /// Cualquier guardado de SwiftData en el proceso (`StoreSaveCounter`): una edición en sitio, una tasa nueva, un
    /// cambio de línea guardado desde una hoja.
    let storeSaves: Int
    let transacciones: Int
    let pagosProgramados: Int
    let cuentas: Int
    let categorias: Int
    let currencyCode: String
    let includeGroups: Bool
    /// El día: el mes en curso y lo que ya pasó se miden contra hoy.
    let dia: Date

    /// La misma firma con otro recuento de guardados: el que queda tras el cálculo, que puede guardar él mismo.
    func conGuardados(_ guardados: Int) -> FlujoRecalculoFirma {
        FlujoRecalculoFirma(
            planRevision: planRevision, dataVersion: dataVersion, storeSaves: guardados, transacciones: transacciones,
            pagosProgramados: pagosProgramados, cuentas: cuentas, categorias: categorias, currencyCode: currencyCode,
            includeGroups: includeGroups, dia: dia
        )
    }
}

enum FlujoFluidezLogica {

    /// `true` si hay que volver a calcular la proyección. Sin cálculo previo, o con cambios sin guardar en el contexto
    /// (una línea editada que aún no se guardó), siempre.
    static func flujoDebeRecalcular(
        ultima: FlujoRecalculoFirma?,
        actual: FlujoRecalculoFirma,
        hayProyeccion: Bool,
        hayCambiosSinGuardar: Bool
    ) -> Bool {
        guard hayProyeccion, let ultima else { return true }
        return hayCambiosSinGuardar || ultima != actual
    }

    /// La Comparativa no calcula mientras no se ve: queda pendiente y calcula al aparecer. Al aparecer calcula si quedó
    /// algo pendiente, si se guardó algo desde la última vez (una edición en sitio no cambia el número de movimientos) o
    /// si cambió el día.
    static func comparativaDebeCalcular(
        pendiente: Bool,
        guardadosVistos: Int?,
        guardadosAhora: Int,
        diaVisto: Date?,
        diaAhora: Date
    ) -> Bool {
        pendiente || guardadosVistos != guardadosAhora || diaVisto != diaAhora
    }
}
