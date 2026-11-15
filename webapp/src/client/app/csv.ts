/**
 * Exportar a CSV (lote 2b). El archivo es el del iPhone (`TransactionsExportService.makeCSVData`), para que se lea igual
 * y vuelva a entrar en Yala por «Importar»: cabeceras fijas en inglés y en el orden de la app (`ExportColumn.allCases`),
 * coma como separador, BOM UTF-8 delante (Excel lee bien las tildes), fechas `AAAA-MM-DD`, importes con punto y dos
 * decimales sin separador de miles, etiquetas unidas por «;» y saltos de línea `\n`. Las comillas, como `csvEscaped`.
 *
 * La web no tiene la hora, la tarjeta, el reparto, la tasa ni la necesidad de cada registro: van las ocho columnas que sí
 * tiene, que son las que la app trae encendidas casi siempre.
 */
/** Lo que el archivo necesita de un registro (`Movimiento` de `api.ts` lo cumple). */
export interface CsvRow {
  fecha: string | null;
  importe: number | null;
  divisa: string | null;
  cuenta: string | null;
  categoria: string | null;
  subcategoria: string | null;
  etiquetas: string[];
  nota: string | null;
}

export const CSV_HEADERS = ["date", "amount", "currency", "account", "category", "subcategory", "tags", "note"] as const;

/** `TransactionsExportService.csvEscaped`: entre comillas si lleva coma, comillas o salto de línea; comillas dobladas. */
export function csvEscaped(value: string): string {
  if (!value) return "";
  const escaped = value.replace(/"/g, '""');
  return /[",\n\r]/.test(value) ? `"${escaped}"` : escaped;
}

function amount(v: number | null): string {
  if (v === null || !Number.isFinite(v)) return "0.00";
  const s = v.toFixed(2);
  return s === "-0.00" ? "0.00" : s;
}

export function buildCsv(rows: CsvRow[]): string {
  const lines = [CSV_HEADERS.join(",")];
  for (const m of rows) {
    const cells = [
      m.fecha ?? "",
      amount(m.importe),
      (m.divisa ?? "").toUpperCase(),
      m.cuenta ?? "",
      m.categoria ?? "",
      m.subcategoria ?? "",
      m.etiquetas.join(";"),
      m.nota ?? "",
    ];
    lines.push(cells.map(csvEscaped).join(","));
  }
  return `﻿${lines.join("\n")}`;
}

/** Tope de registros por exportación: 25 páginas de 200, dentro del límite de 120 peticiones por minuto. */
export const CSV_MAX_ROWS = 5_000;
