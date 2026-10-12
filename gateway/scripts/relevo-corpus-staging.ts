/**
 * Purga del corpus de Grupos ACUMULADO en los usuarios de test A y B de staging, con el mismo relevo que corren los
 * goldens al terminar (`test/corpusRelevo.ts`): traspasa al custodio los grupos que crearon los goldens y saca a A y
 * B. Solo RPCs públicos y el JWT de cada usuario; nunca `groups_forget_user`, nunca `service_role`.
 *
 * Alcance: membresías de A y B que el pull cuenta, en grupos con prefijo `g2-goldens-` o `g8-fanout-` (los que crean
 * `groups.goldens` y `push.fanout`). Nada más.
 *
 * Uso, desde `gateway/`, con las credenciales cargadas (`qa/cloud/README.md` §Credenciales):
 *   npx vite-node scripts/relevo-corpus-staging.ts             # DRY-RUN: cuenta y clasifica, no escribe
 *   npx vite-node scripts/relevo-corpus-staging.ts -- --aplicar
 *   npx vite-node scripts/relevo-corpus-staging.ts -- --aplicar --solo=<gid>,<gid>   # piloto acotado
 */
import app from "../src/index";
import type { Env } from "../src/env";
import type { GroupPushResponse } from "../src/groups/types";
import {
  REF_STAGING,
  credencialCustodio,
  describirResiduo,
  entrar,
  exigirStaging,
  puertoStaging,
  relevarGrupos,
} from "../test/corpusRelevo";

declare const process: { env: Record<string, string | undefined>; argv: string[]; exit(code: number): never };

const URL = `https://${REF_STAGING}.supabase.co`;
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";
const PREFIJOS = ["g2-goldens-", "g8-fanout-"];

function exigirVar(nombre: string): string {
  const v = process.env[nombre];
  if (!v) {
    console.error(`Falta ${nombre} en el entorno (ver qa/cloud/README.md §Credenciales).`);
    process.exit(2);
  }
  return v;
}

async function main(): Promise<void> {
  const aplicar = process.argv.includes("--aplicar");
  exigirStaging(URL);
  const encKey = exigirVar("GROUPS_ENC_KEY");
  const a = await entrar(URL, ANON, "A", process.env.USER_A_EMAIL ?? "i5-user-a@test.yala", exigirVar("USER_A_PASS"));
  const b = await entrar(URL, ANON, "B", process.env.USER_B_EMAIL ?? "i5-user-b@test.yala", exigirVar("USER_B_PASS"));
  const c = credencialCustodio(process.env);
  const custodio = await entrar(URL, ANON, "Custodio", c.email, c.password);

  const env = {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    JWT_SIGNING_SECRET: "test-secret-please-change-0123456789",
    SUPABASE_URL: URL,
    SUPABASE_ANON_KEY: ANON,
    GROUPS_ENC_KEY: encKey,
    GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
  } as unknown as Env;
  const ctx = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;
  const push = async (jwt: string, deltas: unknown[]) => {
    const res = await app.fetch(
      new Request("https://gw.local/groups/push", {
        method: "POST",
        headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
        body: JSON.stringify({ deltas }),
      }),
      env,
      ctx,
    );
    return { status: res.status, body: (await res.json()) as GroupPushResponse };
  };
  const puerto = puertoStaging({ url: URL, anon: ANON, encKey, push });

  const memA = await puerto.membresias(a);
  const memB = await puerto.membresias(b);
  const enAlcance = (gid: string) => PREFIJOS.some((p) => gid.startsWith(p));
  const todos = [...new Set([...memA.keys(), ...memB.keys()])].filter(enAlcance).sort();
  const solo = process.argv.find((x) => x.startsWith("--solo="))?.slice("--solo=".length).split(",").filter(Boolean);
  if (solo && solo.some((g) => !todos.includes(g))) {
    console.error(`--solo trae gids fuera de alcance o fuera del pull de A/B: ${solo.filter((g) => !todos.includes(g)).join(", ")}`);
    process.exit(2);
  }
  const gids = solo ?? todos;

  const porEstado = (m: Map<string, string>) => {
    const out: Record<string, number> = {};
    for (const [gid, st] of m) if (enAlcance(gid)) out[st] = (out[st] ?? 0) + 1;
    return out;
  };
  console.log(`staging ${REF_STAGING} · ${aplicar ? "APLICAR" : "DRY-RUN"}`);
  console.log(`pull de A: ${memA.size} grupos · en alcance ${[...memA.keys()].filter(enAlcance).length}`, porEstado(memA));
  console.log(`pull de B: ${memB.size} grupos · en alcance ${[...memB.keys()].filter(enAlcance).length}`, porEstado(memB));
  console.log(`grupos distintos a relevar: ${gids.length} (prefijos ${PREFIJOS.join(", ")})`);
  console.log(`primeros: ${gids.slice(0, 3).join(", ")} · últimos: ${gids.slice(-3).join(", ")}`);
  if (!aplicar) {
    console.log("DRY-RUN: no se ha escrito nada. Repite con `-- --aplicar` para relevar.");
    return;
  }

  const t0 = Date.now();
  const r = await relevarGrupos(puerto, gids, { a, b, custodio }, {
    concurrencia: 6,
    alAvanzar: (hechos, total) => {
      if (hechos % 50 === 0 || hechos === total) console.log(`  ${hechos}/${total} · ${Math.round((Date.now() - t0) / 1000)} s`);
    },
  });
  const finA = await puerto.membresias(a);
  const finB = await puerto.membresias(b);
  console.log(`relevados ${r.relevados.length} · sin A ni B ${r.intactos.length} · residuo ${r.residuo.length}`);
  console.log(`pull de A: ${memA.size} → ${finA.size} · pull de B: ${memB.size} → ${finB.size}`);
  if (r.residuo.length) {
    const motivos: Record<string, number> = {};
    for (const x of r.residuo) {
      const clave = x.motivo.replace(/g\d-[\w-]+/g, "<gid>").replace(/\{.*\}/, "{…}").slice(0, 90);
      motivos[clave] = (motivos[clave] ?? 0) + 1;
    }
    console.log("residuo por motivo:", motivos);
    console.log(describirResiduo({ ...r, residuo: r.residuo.slice(0, 10) }));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
