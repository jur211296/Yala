import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import app from "../src/index";
import { parseRolloutPercent, parseMinBuild } from "../src/config";

/**
 * GET /config (DIFERIDOS #34) — remote-config pública de flags de rollout (§j.1/§j.2).
 * Sin auth, sin bindings: el env se pasa directo a app.request. Fail-closed: ausente/inválido → 0.
 */

interface ConfigBody {
  v: number;
  flags: {
    cloudModeRolloutPercent: number;
    cloudOnboardingChoiceRolloutPercent: number;
    groupsBackendRolloutPercent: number;
  };
  forceUpdate: {
    minSupportedBuild: number;
  };
}

function getConfig(env: Record<string, string>): Response | Promise<Response> {
  return app.request("/config", { method: "GET" }, env);
}

describe("GET /config — shape y semántica fail-closed", () => {
  it("golden del shape: v=1 + los 3 percents + forceUpdate, con valores parseados del env", async () => {
    const res = await getConfig({
      CLOUD_MODE_ROLLOUT_PERCENT: "25",
      CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT: "0",
      GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
      MIN_SUPPORTED_BUILD: "137",
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as ConfigBody;
    expect(body).toEqual({
      v: 1,
      flags: {
        cloudModeRolloutPercent: 25,
        cloudOnboardingChoiceRolloutPercent: 0,
        groupsBackendRolloutPercent: 100,
      },
      forceUpdate: {
        minSupportedBuild: 137,
      },
    });
  });

  it("vars AUSENTES → 0 en los 3 percents + minSupportedBuild (fail-closed: nada enciende)", async () => {
    const body = (await (await getConfig({})).json()) as ConfigBody;
    expect(body.flags.cloudModeRolloutPercent).toBe(0);
    expect(body.flags.cloudOnboardingChoiceRolloutPercent).toBe(0);
    expect(body.flags.groupsBackendRolloutPercent).toBe(0);
    expect(body.forceUpdate.minSupportedBuild).toBe(0);
  });

  it("MIN_SUPPORTED_BUILD inválido → 0; número grande se PRESERVA (sin clamp, ≠ percents)", async () => {
    const invalid = (await (await getConfig({ MIN_SUPPORTED_BUILD: "garbage" })).json()) as ConfigBody;
    expect(invalid.forceUpdate.minSupportedBuild).toBe(0);
    const large = (await (await getConfig({ MIN_SUPPORTED_BUILD: "999999" })).json()) as ConfigBody;
    expect(large.forceUpdate.minSupportedBuild).toBe(999999);
  });

  it("var INVÁLIDA → 0 (no NaN, no crash)", async () => {
    const body = (await (await getConfig({ CLOUD_MODE_ROLLOUT_PERCENT: "garbage" })).json()) as ConfigBody;
    expect(body.flags.cloudModeRolloutPercent).toBe(0);
  });

  it("clamp a [0,100]: 150 → 100, -5 → 0", async () => {
    const body = (await (
      await getConfig({ CLOUD_MODE_ROLLOUT_PERCENT: "150", GROUPS_BACKEND_ROLLOUT_PERCENT: "-5" })
    ).json()) as ConfigBody;
    expect(body.flags.cloudModeRolloutPercent).toBe(100);
    expect(body.flags.groupsBackendRolloutPercent).toBe(0);
  });

  it("cache pública corta (el edge absorbe el fan-out; un flip propaga en ≤ max-age)", async () => {
    const res = await getConfig({});
    expect(res.headers.get("cache-control")).toBe("public, max-age=300");
    expect(res.headers.get("content-type")).toContain("application/json");
  });

  it("sin auth ni attest: responde 200 sin Authorization (config pre-sesión)", async () => {
    const res = await getConfig({ CLOUD_MODE_ROLLOUT_PERCENT: "100" });
    expect(res.status).toBe(200);
  });
});

describe("parseRolloutPercent — tabla fail-closed", () => {
  it("casos borde", () => {
    expect(parseRolloutPercent(undefined)).toBe(0);
    expect(parseRolloutPercent("")).toBe(0);
    expect(parseRolloutPercent("0")).toBe(0);
    expect(parseRolloutPercent("1")).toBe(1);
    expect(parseRolloutPercent("99")).toBe(99);
    expect(parseRolloutPercent("100")).toBe(100);
    expect(parseRolloutPercent("101")).toBe(100);
    expect(parseRolloutPercent("-1")).toBe(0);
    expect(parseRolloutPercent("garbage")).toBe(0);
    expect(parseRolloutPercent("50.9")).toBe(50); // parseInt trunca — entero siempre
  });
});

describe("parseMinBuild — piso 0, sin techo (fail-closed)", () => {
  it("casos borde", () => {
    expect(parseMinBuild(undefined)).toBe(0);
    expect(parseMinBuild("")).toBe(0);
    expect(parseMinBuild("garbage")).toBe(0);
    expect(parseMinBuild("-5")).toBe(0); // piso 0
    expect(parseMinBuild("0")).toBe(0);
    expect(parseMinBuild("1")).toBe(1);
    expect(parseMinBuild("137")).toBe(137);
    expect(parseMinBuild("999999")).toBe(999999); // SIN clamp superior
    expect(parseMinBuild("137.9")).toBe(137); // parseInt trunca
  });
});

// MARK: - Los percents DESPLEGADOS (no el parser: el valor real de wrangler.toml)

const TOML = readFileSync(new URL("../wrangler.toml", import.meta.url), "utf8");

/**
 * Lee `key` dentro de la sección `[header]`. Scan manual y no un parser TOML por el mismo motivo que
 * en `wrangler.forceupdate.test.ts` —añadir una dependencia para leer tres líneas no se justifica— y
 * DUPLICADO de allí a propósito: son doce líneas, `test/` es plano (no hay convención de helpers) y
 * aquel fichero es la única red que queda contra brickear la app, así que no se refactoriza de paso.
 * Si aparece un tercer consumidor, se extrae. Cada copia lleva SU control positivo, que es lo que
 * caza un scanner roto.
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

/**
 * POR QUÉ EXISTE. Los tests de arriba prueban el PARSER con envs sintéticos; nadie vigilaba el VALOR
 * que se despliega. El 2026-09-09 se midió la consecuencia: producción servía
 * `cloudOnboardingChoiceRolloutPercent: 100` y este repo llevaba `"0"` —Jürgen la subió en un PR que
 * después se borró—, así que el siguiente `npm run deploy:production` hecho por CUALQUIER otro motivo
 * habría apagado la card «Tu cuenta en la nube» del Welcome en todo el parque sin decisión de nadie.
 * Un rollout es un acto deliberado que rompe un test, no un efecto colateral de un deploy.
 *
 * LÍMITE CONOCIDO: esto fija el REPO, no el gateway. Un cambio hecho a mano desde el dashboard de
 * Cloudflare no lo ve nadie aquí (el test es determinista y sin red a propósito, para correr sin
 * credenciales). La contraprueba es el `curl` al `/config` de producción, que va en el PR.
 */
describe("wrangler.toml · percents de rollout DESPLEGADOS en producción", () => {
  // Control POSITIVO del scanner, y aquí carga más peso que en su hermano: los tres percents de
  // producción valen "100" y los de staging TAMBIÉN, así que un scanner que leyera siempre la sección
  // equivocada —o que ignorara el header— pasaría los tests de abajo en verde sin vigilar nada.
  // `ENFORCE` difiere entre las dos secciones, así que prueba que las distingue de verdad.
  it("el scanner distingue las secciones (si esto falla, los tests de abajo no prueban nada)", () => {
    expect(varIn("vars", "ENFORCE")).toBe("observe");
    expect(varIn("env.production.vars", "ENFORCE")).toBe("enforce");
  });

  // Control NEGATIVO: una key que no existe tiene que dar `undefined`, no una cadena vacía. Es lo que
  // impide que un `toBe("100")` pase por accidente si alguien renombra la key o borra la línea.
  it("una key ausente da undefined (el guard no falla ABIERTO)", () => {
    expect(varIn("env.production.vars", "NO_EXISTE_ESTA_KEY")).toBeUndefined();
    expect(varIn("env.no.existe.vars", "ENFORCE")).toBeUndefined();
  });

  it("los TRES percents vivos de producción están en 100", () => {
    // `toBe("100")` y no un `!== "0"`: si alguien renombra la key o la sección, `varIn` devuelve
    // undefined y esto FALLA, que es lo correcto. Un test laxo pasaría con la línea borrada.
    expect(varIn("env.production.vars", "CLOUD_MODE_ROLLOUT_PERCENT")).toBe("100");
    expect(varIn("env.production.vars", "CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT")).toBe("100");
    expect(varIn("env.production.vars", "GROUPS_BACKEND_ROLLOUT_PERCENT")).toBe("100");
  });

  // El valor que sirve el gateway sale de ESTAS vars pasando por el parser, así que el shape publicado
  // se puede componer sin red: cierra el hueco entre «el .toml dice 100» y «/config publica 100».
  it("compuestos con el parser, publican 100 en los tres (lo que ve el cliente)", async () => {
    const env = {
      CLOUD_MODE_ROLLOUT_PERCENT: varIn("env.production.vars", "CLOUD_MODE_ROLLOUT_PERCENT")!,
      CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT: varIn(
        "env.production.vars",
        "CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT",
      )!,
      GROUPS_BACKEND_ROLLOUT_PERCENT: varIn("env.production.vars", "GROUPS_BACKEND_ROLLOUT_PERCENT")!,
    };
    const body = (await (await getConfig(env)).json()) as ConfigBody;
    expect(body.flags.cloudModeRolloutPercent).toBe(100);
    expect(body.flags.cloudOnboardingChoiceRolloutPercent).toBe(100);
    expect(body.flags.groupsBackendRolloutPercent).toBe(100);
  });
});
