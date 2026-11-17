/**
 * Qué sección abre cada dirección y qué entrada de la navegación se marca (lote 3 de «Yala web como la app»).
 *
 * Planificación reúne Presupuestos y Pagos planificados, como la pestaña de la app. Las direcciones de antes siguen
 * valiendo: `/presupuestos` y `/pagos` abren Planificación en su segmento, y `/planificacion` en Presupuestos.
 *
 * Puro, sin React ni textos, para poder probarlo sin navegador (`test/navegacion.test.ts`).
 */

export type Sec =
  | "panel"
  | "bandeja"
  | "registros"
  | "planificacion"
  | "presupuestos"
  | "pagos"
  | "estadisticas"
  | "grupos"
  | "configurar"
  | "mas";

export const SECTIONS: readonly Sec[] = [
  "panel",
  "bandeja",
  "registros",
  "planificacion",
  "presupuestos",
  "pagos",
  "estadisticas",
  "grupos",
  "configurar",
  "mas",
];

/** Lo que vive en la nube completa: una cuenta «solo Grupos» no tiene nada que ver ahí. */
export const FULL_CLOUD: readonly Sec[] = ["panel", "bandeja", "registros", "planificacion", "presupuestos", "pagos", "estadisticas"];

/** Las direcciones que abren Planificación. */
const PLAN: readonly Sec[] = ["planificacion", "presupuestos", "pagos"];

export type Segmento = "presupuestos" | "pagos";

/** La sección de una dirección; una que no existe abre la de inicio. */
export function secFromPath(pathname: string, home: Sec): Sec {
  const p = pathname.replace(/^\/+|\/+$/g, "");
  return (SECTIONS as readonly string[]).includes(p) ? (p as Sec) : home;
}

/** La dirección de una sección: la de inicio es `/`. */
export function pathOf(s: Sec, home: Sec): string {
  return s === home ? "/" : `/${s}`;
}

export function isPlan(s: Sec): boolean {
  return PLAN.includes(s);
}

/** El segmento de Planificación que abre una dirección: Pagos solo con `/pagos`. */
export function segmentOf(s: Sec): Segmento {
  return s === "pagos" ? "pagos" : "presupuestos";
}

/** La entrada de la barra lateral que se marca: Presupuestos y Pagos marcan Planificación. */
export function sideOf(s: Sec): Sec {
  return isPlan(s) ? "planificacion" : s;
}

/**
 * La pestaña del celular que se marca. Panel, Registros y Grupos son la suya; la Bandeja tiene su botón arriba y no
 * marca ninguna; el resto vive en «Más». Una cuenta «solo Grupos» tiene dos pestañas: Grupos y Configurar.
 */
export function tabOf(s: Sec, solo: boolean): Sec | null {
  if (solo) return s === "configurar" || s === "grupos" ? s : null;
  if (s === "panel" || s === "registros" || s === "grupos") return s;
  if (s === "bandeja") return null;
  return "mas";
}

/** El atajo de la búsqueda como lo escribe cada sistema: ⌘K en Apple, Ctrl K en el resto. */
export function shortcutLabel(platform: string): string {
  return /mac|iphone|ipad|ipod/i.test(platform) ? "⌘K" : "Ctrl K";
}
