import { readFileSync } from "node:fs";

/**
 * Lee los prompts LITERALES de la app desde su código Swift, en vez de copiarlos.
 *
 * Por qué: el banco tiene que mandar exactamente lo que manda la app, y una copia envejece en cuanto
 * alguien toca el prompt en Swift. Aquí se extrae el literal multilínea (`"""…"""`) y se aplica la regla
 * de sangría de Swift: se quita a cada línea la sangría de la línea del `"""` de cierre. Las
 * interpolaciones `\(expr)` quedan como texto y las rellena quien llama con `interpolate`.
 */

export const REPO_ROOT = new URL("../../../", import.meta.url);

export function readRepoFile(relPath: string): string {
  return readFileSync(new URL(relPath, REPO_ROOT), "utf8");
}

/** El `nth` literal multilínea que aparece después de `marker` en `source` (0 = el primero). */
export function swiftMultilineAfter(source: string, marker: string, nth = 0): string {
  const at = source.indexOf(marker);
  if (at < 0) throw new Error(`swift: no encuentro el marcador «${marker}»`);
  let cursor = at;
  for (let i = 0; ; i++) {
    const open = source.indexOf('"""\n', cursor);
    if (open < 0) throw new Error(`swift: no hay literal ${nth} tras «${marker}»`);
    const bodyStart = open + 4;
    const closeMatch = source.slice(bodyStart).match(/^([ \t]*)"""/m);
    if (!closeMatch || closeMatch.index === undefined) throw new Error(`swift: literal sin cierre tras «${marker}»`);
    const bodyEnd = bodyStart + closeMatch.index;
    if (i === nth) {
      const indent = closeMatch[1].length;
      const lines = source.slice(bodyStart, bodyEnd).replace(/\n$/, "").split("\n");
      return lines.map((l) => l.slice(Math.min(indent, l.length - l.trimStart().length))).join("\n").replace(/\\"/g, '"').replace(/\\\\/g, "\\");
    }
    cursor = bodyEnd + closeMatch[0].length;
  }
}

/** Sustituye `\(nombre)` por su valor. Lanza si queda alguna interpolación sin rellenar. */
export function interpolate(template: string, values: Record<string, string>): string {
  const out = template.replace(/\\\(([^()]*(?:\([^()]*\))?[^()]*)\)/g, (whole, expr: string) => {
    const key = expr.trim();
    if (!(key in values)) throw new Error(`swift: interpolación sin valor: ${whole}`);
    return values[key];
  });
  return out;
}
