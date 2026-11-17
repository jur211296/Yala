/**
 * Lo que la fila de un registro decide sin pintar nada (lote 4 de «Yala web como la app»): qué título lleva, si enseña la
 * píldora de necesidad y lo gastado en un día. Aparte de `FilaRegistro.tsx` para probarlo sin navegador, como `csv.ts`.
 */
import { texts } from "../i18n";

const t = texts();

/** Lo que estas reglas leen de un registro (`Movimiento` de `api.ts` lo cumple). */
export interface RegistroBase {
  nota: string | null;
  tipo: "gasto" | "ingreso" | "transferencia" | "ajuste_de_saldo";
  categoria: string | null;
  subcategoria: string | null;
  cuenta: string | null;
  importe_en_divisa_preferida: number | null;
  necesidad?: string | null;
}

/** Lo que dice la fila en grande: la nota y, sin nota, la subcategoría, la categoría o el tipo. */
export function tituloDe(m: RegistroBase): string {
  return m.nota || m.subcategoria || m.categoria || t.app.tipos[m.tipo] || "";
}

/** La línea de debajo: «subcategoría · cuenta». */
export function subtituloDe(m: RegistroBase): string {
  return [m.subcategoria ?? m.categoria ?? t.app.sinCategoria, m.cuenta ?? t.app.sinCuenta].join(" · ");
}

/** La píldora de necesidad solo en los gastos con subcategoría (`RecordRowPresentationLogic.showsNeedPill`). */
export function muestraNecesidad(m: RegistroBase): boolean {
  return m.tipo === "gasto" && !!m.subcategoria && !!m.necesidad;
}

/**
 * Lo gastado en un día, como la cabecera de día de la app (`DailySpendingCalculator.dayTotals(...).expense`): los gastos
 * con signo (una devolución resta), en la divisa preferida, sin ingresos, transferencias ni ajustes de saldo. `null` si no
 * hay nada que enseñar: ningún gasto, un total de 0 o algún gasto sin importe convertido (no se inventa una conversión).
 */
export function gastadoDelDia(rows: RegistroBase[]): number | null {
  let gastado = 0;
  let hay = false;
  for (const m of rows) {
    if (m.tipo !== "gasto") continue;
    if (m.importe_en_divisa_preferida == null) return null;
    gastado -= m.importe_en_divisa_preferida;
    hay = true;
  }
  // `shownSpent` de la app: por debajo de medio céntimo no se enseña.
  return hay && gastado >= 0.005 ? Math.round(gastado * 100) / 100 : null;
}
