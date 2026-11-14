/**
 * Lectura de Grupos para Yala web (lote 3, solo staging): la entrada interna `WebGroupsReader` (src/worker.ts) llama a
 * esto con el token de la web.
 *
 * Por qué aquí y no en la web: ocho columnas de Grupos están cifradas (G7) y la llave (`GROUPS_ENC_KEY`) solo vive en
 * el gateway. La web no recibe la llave: pide los grupos ya descifrados por un *service binding* (sin ruta pública).
 *
 * Invariantes, espejo de `/groups/pull`:
 * - El JWT se reenvía TAL CUAL a PostgREST: la RLS decide (`web3_01`: rol `yala_mcp_reader` + cliente OAuth de la web +
 *   membresía). JAMÁS service_role.
 * - Solo se acepta un token de rol `yala_mcp_reader`. Un token `authenticated` (el del iPhone) por esta puerta se
 *   saltaría App Attest, que es lo que exigen las rutas de Grupos para ese rol.
 * - Solo LEE: los cinco RPC lectores `groups_pull_rows_*`. Ninguna escritura.
 * - Apagado salvo `WEB_GROUPS_READER = "on"` (solo en [vars] de staging) y con el kill-switch de Grupos.
 */
import type { Env } from "../env";
import { callRpc, getRows, verifyUserToken } from "../sync/userauth";
import { parseRolloutPercent } from "../config";

export const WEB_READER_ROLE = "yala_mcp_reader";
/** Tope de grupos por lectura: la web pinta una lista, no un volcado. */
export const WEB_MAX_GROUPS = 50;
const PAGE = 1000;
const MAX_PAGES = 5;
const CONCURRENCY = 4;

const ENTITIES = ["split_groups", "group_members", "split_expenses", "split_shares", "split_settlements"] as const;
type Entity = (typeof ENTITIES)[number];

export type Row = Record<string, unknown>;

export interface WebGroupRows {
  group_id: string;
  /** La clave de miembro de quien lee en este grupo. */
  me: string;
  group: Row | null;
  members: Row[];
  expenses: Row[];
  shares: Row[];
  settlements: Row[];
}

export type WebGroupsResult =
  /** `truncated`: más grupos que `WEB_MAX_GROUPS`, o algún grupo con más filas de las que se leen de una vez. */
  | { ok: true; groups: WebGroupRows[]; truncated: boolean }
  | { ok: false; error: "disabled" | "token" | "role" | "upstream" | "groups_off" | "no_key" };

function decodeClaims(token: string): Record<string, unknown> | null {
  const part = token.split(".")[1];
  if (!part) return null;
  try {
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=");
    return JSON.parse(atob(b64)) as Record<string, unknown>;
  } catch {
    return null;
  }
}

/**
 * `only`: el detalle de UN grupo (lo pide la pantalla del grupo). Sin él, todos los de membresía activa, los más
 * recientes primero y como mucho `WEB_MAX_GROUPS`.
 */
export async function readGroupsForWeb(env: Env, token: string, only?: string): Promise<WebGroupsResult> {
  if (env.WEB_GROUPS_READER !== "on" || env.ENVIRONMENT === "production") return { ok: false, error: "disabled" };
  if (parseRolloutPercent(env.GROUPS_BACKEND_ROLLOUT_PERCENT) <= 0) return { ok: false, error: "groups_off" };
  const key = env.GROUPS_ENC_KEY;
  if (!key) return { ok: false, error: "no_key" };

  // Verificar ANTES de leer el claim: un `role` sin firma no vale nada.
  const user = await verifyUserToken(env, token);
  if (!user) return { ok: false, error: "token" };
  const claims = decodeClaims(token);
  if (!claims || claims.role !== WEB_READER_ROLE) return { ok: false, error: "role" };

  const onlyQ = only ? `&group_id=eq.${encodeURIComponent(only)}` : "";
  const memQ = `select=group_id,member_key&user_id=eq.${encodeURIComponent(user.sub)}&deleted=eq.false&status=eq.active${onlyQ}&order=joined_at.desc.nullslast,group_id.asc`;
  const mem = await getRows(env, token, "group_members", memQ);
  if (!mem.ok) return { ok: false, error: "upstream" };
  const mine = new Map<string, string>();
  for (const r of mem.rows) {
    const gid = String(r.group_id ?? "");
    const mk = String(r.member_key ?? "");
    if (gid && mk && !mine.has(gid)) mine.set(gid, mk);
  }
  const ids = [...mine.keys()];
  const truncated = ids.length > WEB_MAX_GROUPS;
  const wanted = ids.slice(0, WEB_MAX_GROUPS);

  // Una tabla que llena las MAX_PAGES páginas se corta: los saldos de ese grupo saldrían mal, así que se marca
  // `truncated` y la página lo dice.
  let capped = false;
  const readEntity = async (gid: string, entity: Entity): Promise<Row[] | null> => {
    const out: Row[] = [];
    let after = 0;
    for (let page = 0; page < MAX_PAGES; page++) {
      const res = await callRpc(env, token, `groups_pull_rows_${entity}`, {
        p_group_id: gid,
        p_after_seq: after,
        p_limit: PAGE,
        p_key: key,
      });
      if (!res.ok) return null;
      const rows = Array.isArray(res.body) ? (res.body as Row[]) : [];
      out.push(...rows);
      if (rows.length < PAGE) return out;
      after = Math.max(after, ...rows.map((r) => Number(r.server_seq) || 0));
    }
    capped = true;
    return out;
  };

  const results: (WebGroupRows | null)[] = new Array(wanted.length);
  let next = 0;
  let failed = false;
  await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, wanted.length) }, async () => {
      for (;;) {
        const i = next++;
        if (i >= wanted.length || failed) return;
        const gid = wanted[i];
        const pages = await Promise.all(ENTITIES.map((e) => readEntity(gid, e)));
        if (pages.some((p) => p === null)) {
          failed = true;
          return;
        }
        const alive = (rows: Row[] | null) => (rows ?? []).filter((r) => r.deleted !== true);
        const [groups, members, expenses, shares, settlements] = pages.map(alive);
        results[i] = { group_id: gid, me: mine.get(gid) ?? "", group: groups[0] ?? null, members, expenses, shares, settlements };
      }
    }),
  );
  if (failed) return { ok: false, error: "upstream" };
  return { ok: true, groups: results.filter((g): g is WebGroupRows => g !== null), truncated: truncated || capped };
}
