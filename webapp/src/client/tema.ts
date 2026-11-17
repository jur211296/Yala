/**
 * El tema de Yala web (lote 1 de «Yala web como la app»): «Como el sistema» (por defecto: claro, o Liquid Glass con el
 * sistema en oscuro), «Claro», «Oscuro» (el negro plano de la app) o «Liquid Glass». Se elige en Configurar y se guarda
 * en este navegador, como el idioma. Los colores de cada uno viven en `styles.css`.
 *
 * `aplicarTema` se llama al arrancar, antes de pintar (`main.tsx`): la CSP no deja scripts en línea en `index.html`. Sin
 * preferencia guardada no hace falta: el CSS ya sigue al sistema solo.
 */
export type Tema = "sistema" | "claro" | "oscuro" | "liquid";

export const TEMAS: Tema[] = ["sistema", "claro", "oscuro", "liquid"];
const KEY = "yala-web-tema";

/** El color de la barra del navegador en el celular, el del fondo de cada tema. */
const BARRA: Record<Exclude<Tema, "sistema">, string> = { claro: "#fafbff", oscuro: "#000000", liquid: "#26275f" };

/** El almacén del navegador, si lo hay (también compila con los tipos del Worker, donde lo leen las pruebas). */
function storage(): { getItem(k: string): string | null; setItem(k: string, v: string): void; removeItem(k: string): void } | undefined {
  return (globalThis as { localStorage?: ReturnType<typeof storage> }).localStorage;
}

/** El tema elegido. En una ventana privada o con el almacenamiento bloqueado, «Como el sistema». */
export function temaElegido(): Tema {
  try {
    const v = storage()?.getItem(KEY) ?? null;
    return v && (TEMAS as string[]).includes(v) ? (v as Tema) : "sistema";
  } catch {
    return "sistema";
  }
}

export function guardarTema(t: Tema): void {
  try {
    if (t === "sistema") storage()?.removeItem(KEY);
    else storage()?.setItem(KEY, t);
  } catch {
    // Sin almacenamiento: el tema vale para esta visita.
  }
}

/** Lo que `aplicarTema` usa del documento (sin los tipos del DOM: las pruebas compilan con los del Worker). */
interface Doc {
  documentElement: { dataset: Record<string, string | undefined> };
  querySelectorAll(sel: string): ArrayLike<{ content: string; dataset: Record<string, string | undefined> }>;
}

/** Pone el tema en la página: `data-tema` en `<html>` (nada con «Como el sistema») y el color de la barra del navegador. */
export function aplicarTema(t: Tema, doc: Doc | undefined = (globalThis as { document?: Doc }).document): void {
  if (!doc) return;
  const ds = doc.documentElement.dataset;
  if (t === "sistema") delete ds.tema;
  else ds.tema = t;
  for (const meta of Array.from(doc.querySelectorAll('meta[name="theme-color"]'))) {
    const porSistema = meta.dataset.sistema ?? meta.content;
    meta.dataset.sistema = porSistema;
    meta.content = t === "sistema" ? porSistema : BARRA[t];
  }
}
