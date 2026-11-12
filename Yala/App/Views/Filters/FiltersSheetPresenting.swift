//
//  FiltersSheetPresenting.swift
//  Yala
//
//  Un ViewModel cuya pantalla presenta la hoja de Filtros con `showFiltersSheet` (auditoría UX 2.2, lote 8, L8-17).
//  `FilterControlBar` lo usa para que tocar una cápsula de «Filtros aplicados» abra Filtros sin que cada host tenga
//  que pasarle nada: Registros, Estadísticas › Registros (`RecordsViewModel`), Tendencias, Categorías e Insights
//  (`StatisticsViewModel`) e Informes (`FinancialReportViewModel`) ya cuelgan su hoja de esa propiedad.
//

import Foundation

protocol FiltersSheetPresenting: AnyObject {
    var showFiltersSheet: Bool { get set }
}

extension RecordsViewModel: FiltersSheetPresenting {}
extension StatisticsViewModel: FiltersSheetPresenting {}
extension FinancialReportViewModel: FiltersSheetPresenting {}
