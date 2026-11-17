/**
 * Lo que deciden las pantallas del lote 5 de «Yala web como la app», sin navegador ni API, para probarlo con
 * `test/lote5.test.ts` (como `registro.ts` en el lote 4). Los tipos son los mínimos que usa cada función.
 */
import type { LucideIcon } from "lucide-react";
import { COLOR_POR_DEFECTO, colorSeguro, iconoLucide, SIMBOLO_POR_DEFECTO } from "./simbolos";

/** Lo que hace falta de una categoría de `/api/categorias` para buscar su ícono. */
export interface CategoriaConSimbolo {
  id?: string;
  es_ingreso?: boolean;
  nombre: string;
  oculta: boolean;
  icono: string | null;
  color: string | null;
  subcategorias: { id: string; nombre: string; oculta: boolean; icono: string | null; color: string | null }[];
}

export interface Dinero {
  divisa: string;
  importe: number;
}

export interface Simbolo {
  /** El SF Symbol encontrado (o el respaldo), para probar la búsqueda sin comparar componentes. */
  sf: string;
  Icono: LucideIcon;
  color: string;
}

/**
 * El ícono y el color de un nombre. `primero` dice dónde se busca antes: la subcategoría para lo que la app nombra con
 * ella (un cobro, un borrador, un gasto de grupo) y la categoría para un trozo de Estadísticas o un presupuesto. Una
 * subcategoría sin color propio toma el de su categoría, como en la app.
 */
export function simboloPorNombre(
  cats: readonly CategoriaConSimbolo[] | null,
  nombre: string | null | undefined,
  opts: { primero?: "categoria" | "subcategoria"; sf?: string; color?: string } = {},
): Simbolo {
  const sfRespaldo = opts.sf ?? SIMBOLO_POR_DEFECTO;
  const colorRespaldo = opts.color ?? COLOR_POR_DEFECTO;
  const clave = (nombre ?? "").trim().toLocaleLowerCase();
  const lista = (cats ?? []).filter((c) => !c.oculta);
  const deCategoria = (): Simbolo | null => {
    const c = lista.find((x) => x.nombre.trim().toLocaleLowerCase() === clave);
    if (!c) return null;
    const sf = c.icono ?? sfRespaldo;
    return { sf, Icono: iconoLucide(sf, sfRespaldo), color: colorSeguro(c.color, colorRespaldo) };
  };
  const deSubcategoria = (): Simbolo | null => {
    for (const c of lista) {
      const s = c.subcategorias.find((x) => !x.oculta && x.nombre.trim().toLocaleLowerCase() === clave);
      if (s) {
        const sf = s.icono ?? c.icono ?? sfRespaldo;
        return { sf, Icono: iconoLucide(sf, sfRespaldo), color: colorSeguro(s.color ?? c.color, colorRespaldo) };
      }
    }
    return null;
  };
  const hallado = clave
    ? opts.primero === "subcategoria"
      ? deSubcategoria() ?? deCategoria()
      : deCategoria() ?? deSubcategoria()
    : null;
  return hallado ?? { sf: sfRespaldo, Icono: iconoLucide(sfRespaldo), color: colorRespaldo };
}

/**
 * El resumen de arriba con una sola divisa: lo que te deben, lo que debes y el neto, como la cabecera de Grupos de la app.
 * Con más de una divisa no hay neto (no se convierten): `null`, y se enseñan las líneas por divisa.
 */
export function resumenNeto(r: { teDeben: Dinero[]; debes: Dinero[] }): { divisa: string | null; teDeben: number; debes: number; neto: number } | null {
  const divisas = new Set([...r.teDeben, ...r.debes].map((d) => d.divisa));
  if (divisas.size > 1) return null;
  const sum = (xs: Dinero[]) => Math.round(xs.reduce((a, d) => a + d.importe, 0) * 100) / 100;
  const teDeben = sum(r.teDeben);
  const debes = sum(r.debes);
  return { divisa: [...divisas][0] ?? null, teDeben, debes, neto: Math.round((teDeben - debes) * 100) / 100 };
}

/** El color de la barra, como `BudgetProgressBar`: el de la categoría; ámbar en riesgo y rosa al pasarse. */
export function colorBarra(p: { estado: string }, color: string): string {
  if (p.estado === "excedido") return "var(--owe)";
  if (p.estado === "en_riesgo") return "var(--risk-fill)";
  return color;
}
