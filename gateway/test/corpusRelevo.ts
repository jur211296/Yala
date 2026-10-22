/**
 * Relevo del corpus de Grupos de staging: saca a los usuarios de test A y B de los grupos que crean los goldens,
 * para que su pull deje de crecer con cada corrida.
 *
 * POR QUÉ UN RELEVO Y NO UN BORRADO. Un pull cuesta 5 peticiones por grupo del usuario, y hasta el 2026-10-12 cada
 * corrida completa dejaba 19 grupos más en el pull de A y 14 en el de B, para siempre: con A en 736 y B en 838 los
 * goldens que hacen pull ya no cabían en su timeout. Medido en las funciones de staging, el DUEÑO de un grupo no
 * puede salir por ninguna vía pública (`leave_group` → `yala_owner_cannot_leave`, `remove_member` →
 * `yala_cannot_remove_owner`), y la única que lo saca sin heredero es `groups_forget_user` — prohibida en los tests
 * porque es destructiva y global. Así que siempre queda una membresía por grupo; lo que se decide es DE QUIÉN.
 * Se le traspasa al CUSTODIO, un usuario de test con el que ningún golden hace pull.
 *
 * El relevo de un grupo, solo con RPCs públicos y el JWT de cada cual:
 *   1. Si está archivado, su dueño lo desarchiva (`join_group` rechaza entrar a un archivado, g13_05).
 *   2. Cada no-dueño de A/B sale con `leave_group`. Un rechazado no puede salir (`leave_group` exige
 *      active|pendingApproval): vuelve a entrar con una invitación nueva y sale.
 *   3. Si el dueño es A o B: el custodio entra, se le aprueba, el dueño hace `transfer_group_ownership` —que lo elige
 *      a él porque ya es el único elegible— y sale.
 * Un grupo BORRADO no admite traspaso (`transfer_group_ownership` exige `deleted=false`): queda como residuo.
 *
 * Idempotente: un grupo del que A y B ya salieron no gasta ni una llamada, y un relevo cortado a medias se retoma
 * desde el estado que dejó (el custodio ya dentro o ya dueño no se repite).
 */

/** Las membresías que ve el pull (`gateway/src/groups/routes.ts`, `memQ`): fuera de este set, el grupo no cuesta. */
export const ESTADOS_EN_PULL = ["active", "pendingApproval", "rejected"] as const;

export interface Actor {
  nombre: string;
  jwt: string;
  sub: string;
}

export interface Actores {
  a: Actor;
  b: Actor;
  custodio: Actor;
}

export interface MetaGrupo {
  owner_user_id: string | null;
  is_archived: boolean;
  deleted: boolean;
}

export interface RespuestaRpc {
  status: number;
  body: any;
}

/** Lo que el relevo necesita del mundo. `puertoStaging` lo cablea contra staging; los tests offline, contra un doble. */
export interface PuertoRelevo {
  /** RPC de PostgREST con el JWT del actor. Quien lo implemente añade `p_key` a `join_group`. */
  rpc(jwt: string, fn: string, args: Record<string, unknown>): Promise<RespuestaRpc>;
  /** Estado de la membresía del actor en cada grupo, SOLO si está en el set del pull. `gids` acota la consulta. */
  membresias(actor: Actor, gids?: string[]): Promise<Map<string, string>>;
  /** Meta del grupo leída con el JWT de un miembro activo; `null` si ese actor no la ve. */
  meta(jwt: string, gid: string): Promise<MetaGrupo | null>;
  /** Push de meta `is_archived=false` del dueño. */
  desarchivar(jwt: string, gid: string): Promise<void>;
}

export interface Residuo {
  gid: string;
  motivo: string;
}

export interface ResultadoRelevo {
  /** Grupos en los que A o B estaban al empezar y de los que salieron. */
  relevados: string[];
  /** Grupos en los que ni A ni B estaban: nada que hacer. */
  intactos: string[];
  /** Grupos donde A o B SIGUEN en el pull al terminar, con el porqué. Vacío = la corrida no dejó nada. */
  residuo: Residuo[];
}

class FalloRelevo extends Error {}

async function exigir(p: PuertoRelevo, actor: Actor, fn: string, args: Record<string, unknown>): Promise<any> {
  const r = await p.rpc(actor.jwt, fn, args);
  if (r.status !== 200) {
    throw new FalloRelevo(`${fn} de ${actor.nombre} → ${r.status} ${JSON.stringify(r.body)}`);
  }
  return r.body;
}

async function invitacion(p: PuertoRelevo, admin: Actor, gid: string): Promise<string> {
  const token = await exigir(p, admin, "create_group_invite", { p_group_id: gid, p_ttl_seconds: 3600, p_max_uses: null });
  if (typeof token !== "string" || token.length === 0) {
    throw new FalloRelevo(`create_group_invite de ${admin.nombre} no devolvió token: ${JSON.stringify(token)}`);
  }
  return token;
}

/**
 * Releva UN grupo. Lanza `FalloRelevo` con el motivo si no puede; `relevarGrupos` lo convierte en residuo.
 * `estado` es la membresía de A y B en este grupo al empezar (solo los que están en el set del pull).
 */
async function relevarUno(p: PuertoRelevo, gid: string, act: Actores, estado: Map<string, string>): Promise<void> {
  const deAB = [act.a, act.b].filter((u) => estado.has(u.sub));
  const lectores = deAB.filter((u) => estado.get(u.sub) === "active");
  let meta: MetaGrupo | null = null;
  for (const u of lectores) {
    meta = await p.meta(u.jwt, gid);
    if (meta) break;
  }
  if (!meta) {
    // Sin un miembro activo entre A y B no hay meta ni admin que invite: solo puede salir quien esté pendiente.
    for (const u of deAB) {
      if (estado.get(u.sub) === "pendingApproval") await exigir(p, u, "leave_group", { p_group_id: gid });
      else throw new FalloRelevo(`${u.nombre} está ${estado.get(u.sub)} y ni A ni B están activos para invitarle`);
    }
    return;
  }
  if (meta.deleted) {
    throw new FalloRelevo("grupo borrado: no admite traspaso de dueño ni salida del dueño");
  }

  const dueno = deAB.find((u) => u.sub === meta!.owner_user_id) ?? null;

  if (meta.is_archived) {
    if (!dueno) throw new FalloRelevo("grupo archivado y su dueño no es A ni B: nadie puede desarchivarlo");
    await p.desarchivar(dueno.jwt, gid);
  }

  for (const u of deAB) {
    if (u === dueno) continue;
    if (estado.get(u.sub) === "rejected") {
      if (!dueno) throw new FalloRelevo(`${u.nombre} está rechazado y su dueño no es A ni B: nadie puede invitarle`);
      const token = await invitacion(p, dueno, gid);
      await exigir(p, u, "join_group", { p_token: token, p_display_name: u.nombre, p_legacy_member_key: null });
    }
    await exigir(p, u, "leave_group", { p_group_id: gid });
  }

  if (!dueno) return;

  const token = await invitacion(p, dueno, gid);
  const entrada = await exigir(p, act.custodio, "join_group", {
    p_token: token,
    p_display_name: act.custodio.nombre,
    p_legacy_member_key: null,
  });
  if (entrada?.status === "pendingApproval") {
    await exigir(p, dueno, "approve_member", { p_group_id: gid, p_member_key: entrada.member_key });
  }
  const traspaso = await exigir(p, dueno, "transfer_group_ownership", { p_group_id: gid });
  if (traspaso?.transferred !== true || traspaso?.new_owner_user_id !== act.custodio.sub) {
    throw new FalloRelevo(`el traspaso no fue al custodio: ${JSON.stringify(traspaso)}`);
  }
  await exigir(p, dueno, "leave_group", { p_group_id: gid });
}

/**
 * Releva `gids` y COMPRUEBA el final: lo que decide el residuo es la membresía de A y B releída al terminar, no que
 * las llamadas devolvieran 200. Un grupo que no pudo relevarse lleva su motivo; uno que sigue en el pull sin motivo
 * también se reporta, porque eso es justo lo que la guarda tiene que ver.
 */
export async function relevarGrupos(
  p: PuertoRelevo,
  gids: string[],
  act: Actores,
  opciones: { concurrencia?: number; alAvanzar?: (hechos: number, total: number) => void } = {},
): Promise<ResultadoRelevo> {
  const unicos = Array.from(new Set(gids));
  if (unicos.length === 0) return { relevados: [], intactos: [], residuo: [] };

  const antesA = await p.membresias(act.a, unicos);
  const antesB = await p.membresias(act.b, unicos);
  const conAB = unicos.filter((g) => antesA.has(g) || antesB.has(g));
  const intactos = unicos.filter((g) => !antesA.has(g) && !antesB.has(g));

  const motivos = new Map<string, string>();
  let siguiente = 0;
  let hechos = 0;
  const concurrencia = Math.max(1, opciones.concurrencia ?? 4);
  await Promise.all(
    Array.from({ length: Math.min(concurrencia, conAB.length) }, async () => {
      for (;;) {
        const i = siguiente++;
        if (i >= conAB.length) return;
        const gid = conAB[i];
        const estado = new Map<string, string>();
        const ea = antesA.get(gid);
        const eb = antesB.get(gid);
        if (ea) estado.set(act.a.sub, ea);
        if (eb) estado.set(act.b.sub, eb);
        try {
          await relevarUno(p, gid, act, estado);
        } catch (e) {
          motivos.set(gid, e instanceof Error ? e.message : String(e));
        }
        hechos++;
        opciones.alAvanzar?.(hechos, conAB.length);
      }
    }),
  );

  const despuesA = conAB.length ? await p.membresias(act.a, conAB) : new Map<string, string>();
  const despuesB = conAB.length ? await p.membresias(act.b, conAB) : new Map<string, string>();
  const residuo: Residuo[] = [];
  const relevados: string[] = [];
  for (const gid of conAB) {
    const quedan: string[] = [];
    if (despuesA.has(gid)) quedan.push(`A ${despuesA.get(gid)}`);
    if (despuesB.has(gid)) quedan.push(`B ${despuesB.get(gid)}`);
    if (quedan.length === 0) relevados.push(gid);
    else residuo.push({ gid, motivo: `${motivos.get(gid) ?? "sin error y aún en el pull"} — quedan: ${quedan.join(", ")}` });
  }
  return { relevados, intactos, residuo };
}

// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
// Cableado contra staging
// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/** El único proyecto contra el que el relevo puede escribir. Producción es `kefvaiymtgytemwbltlz`. */
export const REF_STAGING = "fostjbbwstyuunmmefuk";

export function exigirStaging(url: string): void {
  if (new URL(url).hostname !== `${REF_STAGING}.supabase.co`) {
    throw new Error(`relevo: ${url} no es staging (${REF_STAGING}). No se escribe nada.`);
  }
}

/** HLC canon c1 con la hora de AHORA: el tope de hlc01 acota a `now()+60 s`, así que no se usa uno del futuro. */
function hlcAhora(): string {
  return `${new Date().toISOString()}-0001-${"cc".padStart(16, "0")}`;
}

export function puertoStaging(cfg: {
  url: string;
  anon: string;
  encKey: string;
  /** Push al gateway (`/groups/push`) con el JWT del actor; lo pone quien tiene el `app` y el `env`. */
  push: (jwt: string, deltas: unknown[]) => Promise<{ status: number; body: { results: Array<{ status: string }> } }>;
}): PuertoRelevo {
  exigirStaging(cfg.url);
  const headers = (jwt: string) => ({ apikey: cfg.anon, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" });

  const rpc = async (jwt: string, fn: string, args: Record<string, unknown>): Promise<RespuestaRpc> => {
    const finalArgs = fn === "join_group" ? { ...args, p_key: cfg.encKey } : args;
    const res = await fetch(`${cfg.url}/rest/v1/rpc/${fn}`, { method: "POST", headers: headers(jwt), body: JSON.stringify(finalArgs) });
    const text = await res.text();
    let body: unknown = null;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      body = text;
    }
    return { status: res.status, body };
  };

  return {
    rpc,
    async membresias(actor, gids) {
      // Mismo predicado que el pull. Por lotes: un `in.(...)` con cientos de ids revienta la URL, y sin `gids`
      // se pagina (PostgREST corta en `max-rows`).
      const out = new Map<string, string>();
      const base = `select=group_id,status&user_id=eq.${actor.sub}&deleted=eq.false&status=in.(${ESTADOS_EN_PULL.join(",")})`;
      const leer = async (q: string) => {
        const res = await fetch(`${cfg.url}/rest/v1/group_members?${q}`, { headers: headers(actor.jwt) });
        if (res.status !== 200) throw new Error(`membresías de ${actor.nombre} → ${res.status} ${await res.text()}`);
        return (await res.json()) as Array<{ group_id: string; status: string }>;
      };
      if (gids) {
        for (let i = 0; i < gids.length; i += 50) {
          const lote = gids.slice(i, i + 50).map((g) => `"${g}"`).join(",");
          for (const r of await leer(`${base}&group_id=in.(${lote})`)) out.set(r.group_id, r.status);
        }
        return out;
      }
      for (let offset = 0; ; offset += 500) {
        const filas = await leer(`${base}&order=group_id.asc&limit=500&offset=${offset}`);
        for (const r of filas) out.set(r.group_id, r.status);
        if (filas.length < 500) return out;
      }
    },
    async meta(jwt, gid) {
      const r = await rpc(jwt, "groups_pull_rows_split_groups", { p_group_id: gid, p_after_seq: 0, p_limit: 10, p_key: cfg.encKey });
      if (r.status !== 200 || !Array.isArray(r.body) || r.body.length === 0) return null;
      const row = r.body[0] as Record<string, unknown>;
      return {
        owner_user_id: (row.owner_user_id as string | null) ?? null,
        is_archived: row.is_archived === true,
        deleted: row.deleted === true,
      };
    },
    async desarchivar(jwt, gid) {
      const h = hlcAhora();
      const r = await cfg.push(jwt, [
        {
          entity_type: "split_groups",
          group_id: gid,
          sync_id: null,
          op: "upsert",
          fields: { is_archived: false },
          field_hlcs: { is_archived: h },
          hlc: h,
          client_mutation_id: crypto.randomUUID(),
        },
      ]);
      const estado = r.body?.results?.[0]?.status;
      if (r.status !== 200 || estado !== "applied") {
        throw new FalloRelevo(`desarchivar → ${r.status} ${JSON.stringify(r.body)}`);
      }
    },
  };
}

/** Login por password grant y su `sub`. */
export async function entrar(url: string, anon: string, nombre: string, email: string, password: string): Promise<Actor> {
  const res = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: anon, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const body = (await res.json()) as { access_token?: string; user?: { id?: string } };
  if (!body.access_token || !body.user?.id) throw new Error(`login de ${nombre} (${email}) falló: ${res.status}`);
  return { nombre, jwt: body.access_token, sub: body.user.id };
}

/** Credenciales del custodio, del entorno como las de A y B. Lanza nombrando la variable si falta. */
export function credencialCustodio(env: Record<string, string | undefined>): { email: string; password: string } {
  const email = env.USER_CUSTODIO_EMAIL ?? "i5-goldens-custodio@test.yala";
  const password = env.USER_CUSTODIO_PASS ?? "";
  if (!password) {
    throw new Error(
      "Falta USER_CUSTODIO_PASS en el entorno — sin el custodio, cada corrida dejaría sus grupos en el pull de A y B " +
        "para siempre. Está en ~/Secrets/yala-supabase-test/test-users.env (ver qa/cloud/README.md).",
    );
  }
  return { email, password };
}

/** Mensaje de la guarda: qué grupos de ESTA corrida siguen en el pull de A o B, y por qué. */
export function describirResiduo(r: ResultadoRelevo): string {
  return r.residuo.map((x) => `  ${x.gid}: ${x.motivo}`).join("\n");
}
