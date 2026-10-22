/**
 * Guard del umbral de forzado de versión desplegado (`MIN_SUPPORTED_BUILD`).
 *
 * POR QUÉ EXISTE, y no es hipotético. `config.test.ts` prueba el PARSER (`"137"` → 137, ausente → 0,
 * basura → 0) pero nadie vigilaba el VALOR real de `wrangler.toml`, que es lo que se despliega.
 *
 * El mecanismo se apoyaba en TRES capas: el valor es 0 (`parseMinBuild` es fail-closed: ningún
 * build < 0) · el cliente de producción no fetcheaba `/config` en absoluto
 * (`CloudRemoteConfig.refreshIfDue` abre con `guard CloudBackendConfig.isConfigured`) · y sin fetch no
 * había snapshot, así que `ForceUpdateGate` leía `nil`.
 *
 * **La capa del medio YA CAYÓ.** Era el gate maestro del Modo Nube, y D-R1 paso 1 (2026-07-30) cableó
 * la URL + anon key de producción en `CloudBackendConfig`. Desde ese commit **todos** los clientes de
 * producción fetchean `/config`, y lo único entre el usuario y una pantalla BLOQUEANTE es la cadena
 * `"0"` de este fichero. Un typo, un merge, o alguien probando el flujo en staging que se equivoca de
 * bloque, y se brica cada instalación: el fallo es total, instantáneo, y solo se arregla con otro
 * deploy. Este test dejó de ser una red preventiva y pasó a ser la única que queda.
 *
 * Así que subirlo tiene que ser un acto DELIBERADO que rompe un test, no un descuido. Mismo patrón
 * que el ratchet de `coverage-index` y la paridad de schema de CloudKit: convertir «acuérdate» en
 * «el test te para».
 *
 * Si de verdad hay que forzar una versión: sube el valor Y actualiza el número esperado aquí, en el
 * mismo commit, con el build mínimo soportado en el mensaje.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const TOML = readFileSync(new URL("../wrangler.toml", import.meta.url), "utf8");

/**
 * Lee `key` dentro de la sección `[header]`. Scan manual y no un parser TOML a propósito: añadir una
 * dependencia para leer una línea no se justifica. Ignora comentarios y sale de la sección en el
 * siguiente header, que es lo que impide leer el `MIN_SUPPORTED_BUILD` de staging creyendo que es el
 * de producción — están los dos en el fichero.
 */
function varIn(header: string, key: string): string | undefined {
  let dentro = false;
  for (const linea of TOML.split("\n")) {
    const t = linea.trim();
    if (t.startsWith("[")) {
      dentro = t === `[${header}]`;
      continue;
    }
    if (!dentro || t.startsWith("#")) continue;
    const m = t.match(new RegExp(`^${key}\\s*=\\s*"([^"]*)"`));
    if (m) return m[1];
  }
  return undefined;
}

describe("wrangler.toml · umbral de forzado de versión", () => {
  // Control POSITIVO del scanner, y no es ceremonia: los dos `MIN_SUPPORTED_BUILD` valen "0", así que
  // un scanner que leyera SIEMPRE la sección equivocada pasaría los dos tests de abajo en verde
  // mientras no vigila nada. `ENFORCE` difiere entre secciones, así que prueba que las distingue.
  it("el scanner distingue las secciones (si esto falla, los tests de abajo no prueban nada)", () => {
    expect(varIn("vars", "ENFORCE")).toBe("observe");
    expect(varIn("env.production.vars", "ENFORCE")).toBe("enforce");
  });

  it("producción: MIN_SUPPORTED_BUILD = 0 (nadie forzado)", () => {
    // `toBe("0")` y no un `!== "1"`: si alguien renombra la key o la sección, `varIn` devuelve
    // undefined y esto FALLA — que es lo correcto. Un test laxo pasaría vacío.
    expect(varIn("env.production.vars", "MIN_SUPPORTED_BUILD")).toBe("0");
  });

  it("staging: MIN_SUPPORTED_BUILD = 0 (un valor > 0 bloquea la app de dogfooding)", () => {
    // Staging NO es «da igual»: es donde se prueba, y un umbral > 0 aquí bloquea la propia app con la
    // que se hace QA. A diferencia de los percents de rollout, esto no enciende superficie: la apaga.
    expect(varIn("vars", "MIN_SUPPORTED_BUILD")).toBe("0");
  });
});
