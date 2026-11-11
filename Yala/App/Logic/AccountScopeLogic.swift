//
//  AccountScopeLogic.swift
//  Yala
//
//  Qué cuenta de una cuenta: su saldo y su historial, dos preguntas distintas.
//
//  Decisión de Jürgen (opción A del 2026-10-08, adelantada a 2.3 en la decisión 6 del 2026-11-09, card «Archivar una
//  cuenta: decidir si oculta su historial…»): **archivar saca la cuenta del saldo y conserva su historial**. Hasta
//  entonces las dos preguntas las contestaba un solo flag, «Excluir de las estadísticas», y archivar desde el formulario
//  lo encendía: los gastos de una tarjeta cerrada desaparecían de Registros y de «Gastos 2025».
//
//  - **¿Suma en un saldo?** La cifra del Panel, su curva, «en N cuentas», la hoja «¿Cuánto tienes hoy?», el saldo de
//    Distribución, de los widgets, del aviso de informe, de la salud financiera y de Yala IA: ni excluida ni archivada.
//  - **¿Se ven sus movimientos?** Registros, ingresos y gastos de cualquier período, tartas, tendencias y Yala IA: una
//    cuenta archivada siempre; una activa, si no está excluida.
//
//  Las cuentas sistema de Grupos que archiva la PROPIA app (`GroupBridgeSystemEntities`, al fundir duplicadas tras una
//  carrera entre dispositivos) no son un archivado de la persona: conservan sus movimientos y siguen sumando, como antes.
//
//  Una cuenta archivada con «Excluir» encendido (lo dejaba así archivar desde el formulario entre el 2026-10-03 y esta
//  decisión, también en la 2.1 publicada) enseña su historial sin tocar el dato: al desarchivarla, el flag guardado
//  vuelve a mandar. No hay migración.
//

import Foundation

nonisolated enum AccountScopeLogic {

    /// `true` si la cuenta entra en un saldo: ni excluida de las estadísticas ni archivada por la persona. Una cuenta
    /// sistema de Grupos archivada la archivó la app (duplicada) y sigue sumando.
    static func sumsInBalance(isExcludedFromStatistics: Bool, isArchived: Bool, isSystemAccount: Bool = false) -> Bool {
        !isExcludedFromStatistics && (!isArchived || isSystemAccount)
    }

    /// `true` si sus movimientos se ven y cuentan en los ingresos y gastos de un período: archivada, o activa sin excluir.
    static func keepsHistory(isExcludedFromStatistics: Bool, isArchived: Bool) -> Bool {
        isArchived || !isExcludedFromStatistics
    }
}

extension Account {
    /// `AccountScopeLogic.sumsInBalance` de esta cuenta.
    var sumsInBalance: Bool {
        AccountScopeLogic.sumsInBalance(
            isExcludedFromStatistics: excludeFromStatistics, isArchived: isArchived, isSystemAccount: isSystemAccount)
    }

    /// Archivada por la persona (no una cuenta sistema de Grupos que archivó la app): la que sale de un saldo aunque su
    /// historial se vea. Lo usan las piezas de saldo que reciben filas ya filtradas por historial y solo tienen que
    /// quitar estas (`TrendDataProcessor.fillBalanceBuckets`, la proyección del saldo).
    var isArchivedByThePerson: Bool { isArchived && !isSystemAccount }

    /// `AccountScopeLogic.keepsHistory` de esta cuenta.
    var keepsHistory: Bool {
        AccountScopeLogic.keepsHistory(isExcludedFromStatistics: excludeFromStatistics, isArchived: isArchived)
    }
}
