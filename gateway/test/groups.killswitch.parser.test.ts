/**
 * Pin ESTRUCTURAL del kill-switch de Grupos: `groupsChannelKilled` decide con `parseRolloutPercent` de
 * `config.ts`, el MISMO parser que alimenta lo que `GET /config` publica — no con un parseo propio.
 *
 * ## Por qué hace falta un fichero aparte, y por qué NO es un source-scan
 *
 * La tabla de equivalencia de `groups.killswitch.test.ts` caza un parser propio **divergente** (sus tres
 * valores DISCRIMINANTES matan un `Number(raw) > 0`, medido en las dos direcciones). Lo que NO puede cazar
 * es un parser propio **equivalente-hoy**: un `parseInt(raw, 10) > 0` inline da el mismo veredicto binario
 * que `parseRolloutPercent` —el clamp a [0,100] no altera el signo del `> 0`— así que ningún test de
 * valores los distingue. Y lo que se pierde al duplicarlo es la garantía por CONSTRUCCIÓN: el día que
 * `parseRolloutPercent` cambie (otro trato de `""`, otro clamp, otra base), el guard y `/config` divergen
 * en silencio y la tabla sigue verde, porque se escribió contra los valores de hoy.
 *
 * El pin es CONDUCTUAL y no un source-scan a propósito: leer el fichero exigiría `node:fs` +
 * `import.meta.url`, que son exactamente los dos errores de `tsc` que arrastra
 * `wrangler.forceupdate.test.ts` por no tener `@types/node` — un pin nuevo no debe empeorar ese baseline.
 * En su lugar se MOCKEA el módulo del parser: si el guard lo usa, el mock manda; si parsea por su cuenta,
 * el mock es invisible y estos dos tests caen. Mata las tres variantes (Number, parseInt inline, y
 * cualquier otra) sin depender de cómo esté escrito el código.
 *
 * Va en su propio fichero porque `vi.mock` es hoisted y afecta a TODO el módulo de test: mockear el parser
 * dentro de la suite principal falsearía sus 38 casos.
 */
import { describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";

/**
 * Parser SENTINELA: ignora el valor real y devuelve lo que diga `fakePercent`. Un guard que use el parser
 * compartido obedece esto; uno que parsee por su cuenta lo ignora.
 */
const fakePercent = { value: 0 };
vi.mock("../src/config", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/config")>();
  return { ...actual, parseRolloutPercent: vi.fn(() => fakePercent.value) };
});

const { groupsChannelKilled } = await import("../src/groups/killSwitch");

function envWith(percent: string): Env {
  return { GROUPS_BACKEND_ROLLOUT_PERCENT: percent } as unknown as Env;
}

describe("groupsChannelKilled decide con el parser COMPARTIDO de config.ts", () => {
  it("el parser dice 0 con la var en \"100\" → RECHAZA (manda el parser, no el string)", () => {
    fakePercent.value = 0;
    const res = groupsChannelKilled(envWith("100"));
    expect(res).not.toBeNull();
    expect(res?.status).toBe(403);
  });

  it("el parser dice 100 con la var en \"0\" → NO rechaza (manda el parser, no el string)", () => {
    fakePercent.value = 100;
    expect(groupsChannelKilled(envWith("0"))).toBeNull();
  });

  it("el umbral es > 0 sobre lo que devuelve ESE parser: 1 pasa, 0 rechaza", () => {
    fakePercent.value = 1;
    expect(groupsChannelKilled(envWith("0"))).toBeNull();
    fakePercent.value = 0;
    expect(groupsChannelKilled(envWith("100"))).not.toBeNull();
  });
});
