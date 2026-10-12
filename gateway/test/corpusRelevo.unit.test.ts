/**
 * El relevo del corpus (`corpusRelevo.ts`) contra un doble de staging que reproduce las reglas de los RPCs que usa,
 * copiadas de sus cuerpos en staging el 2026-10-12: el dueño no puede salir, `leave_group` solo acepta
 * active|pendingApproval, `join_group` rechaza grupos borrados y la RE-ENTRADA o entrada nueva a uno archivado, y
 * `transfer_group_ownership` elige heredero admin-primero y más antiguo. Offline: corre en el CI.
 *
 * Lo que fija es el criterio del encargo: al terminar, A y B fuera del pull de cada grupo, sin `groups_forget_user`,
 * y lo que no se pudo relevar sale como residuo con su porqué en vez de pasar en silencio.
 */
import { describe, expect, it } from "vitest";
import { relevarGrupos, exigirStaging, ESTADOS_EN_PULL, type Actor, type Actores, type PuertoRelevo } from "./corpusRelevo";

interface Miembro {
  status: string;
  role: string;
  joined: number;
}
interface Grupo {
  owner: string;
  archived: boolean;
  deleted: boolean;
  members: Map<string, Miembro>;
}

const A: Actor = { nombre: "A", jwt: "jwt-a", sub: "sub-a" };
const B: Actor = { nombre: "B", jwt: "jwt-b", sub: "sub-b" };
const CUSTODIO: Actor = { nombre: "Custodio", jwt: "jwt-c", sub: "sub-custodio" };
const ACT: Actores = { a: A, b: B, custodio: CUSTODIO };

class StagingDoble implements PuertoRelevo {
  grupos = new Map<string, Grupo>();
  tokens = new Map<string, string>();
  llamadas: string[] = [];
  private reloj = 0;
  private subDe = new Map<string, string>([
    [A.jwt, A.sub],
    [B.jwt, B.sub],
    [CUSTODIO.jwt, CUSTODIO.sub],
    ["jwt-otro", "sub-otro"],
  ]);

  sembrar(gid: string, owner: string, miembros: Record<string, { status: string; role?: string }>, extra: Partial<Grupo> = {}) {
    const members = new Map<string, Miembro>();
    for (const [sub, m] of Object.entries(miembros)) members.set(sub, { status: m.status, role: m.role ?? "member", joined: this.reloj++ });
    this.grupos.set(gid, { owner, archived: false, deleted: false, members, ...extra });
  }

  private err(code: string) {
    return { status: 400, body: { code: "P0001", message: code } };
  }

  async rpc(jwt: string, fn: string, args: Record<string, unknown>) {
    this.llamadas.push(fn);
    const uid = this.subDe.get(jwt)!;
    if (fn === "groups_forget_user") throw new Error("groups_forget_user está prohibido");
    const gid = (args.p_group_id as string) ?? this.tokens.get(args.p_token as string);
    const g = gid ? this.grupos.get(gid) : undefined;
    if (!g) return this.err("yala_invalid_invite");
    const yo = g.members.get(uid);
    const esAdmin = yo?.status === "active" && yo.role === "admin";
    switch (fn) {
      case "create_group_invite": {
        if (!esAdmin) return this.err("yala_not_authorized");
        const token = `tok-${this.tokens.size}`;
        this.tokens.set(token, gid);
        return { status: 200, body: token };
      }
      case "join_group": {
        if (g.deleted) return this.err("yala_group_deleted");
        if (yo && (yo.status === "active" || yo.status === "pendingApproval")) {
          return { status: 200, body: { member_key: uid, status: yo.status, changed: false } };
        }
        if (g.archived) return this.err("yala_group_archived");
        g.members.set(uid, { status: "pendingApproval", role: yo?.role ?? "member", joined: yo?.joined ?? this.reloj++ });
        return { status: 200, body: { member_key: uid, status: "pendingApproval", changed: true } };
      }
      case "approve_member": {
        const t = g.members.get(args.p_member_key as string);
        if (!esAdmin || !t || t.status !== "pendingApproval") return this.err("yala_not_authorized");
        t.status = "active";
        return { status: 200, body: { status: "active" } };
      }
      case "transfer_group_ownership": {
        if (g.deleted || g.owner !== uid) return { status: 200, body: { transferred: false, already: true } };
        const cand = [...g.members.entries()]
          .filter(([sub, m]) => m.status === "active" && sub !== uid)
          .sort(([, x], [, y]) => (x.role === "admin" ? 0 : 1) - (y.role === "admin" ? 0 : 1) || x.joined - y.joined)[0];
        if (!cand) return { status: 200, body: { transferred: false, already: false, reason: "no_eligible_owner" } };
        cand[1].role = "admin";
        g.owner = cand[0];
        return { status: 200, body: { transferred: true, already: false, new_owner_user_id: cand[0] } };
      }
      case "leave_group": {
        if (!yo || !(yo.status === "active" || yo.status === "pendingApproval")) return this.err("yala_member_not_found");
        if (g.owner === uid) return this.err("yala_owner_cannot_leave");
        yo.status = "left";
        return { status: 200, body: { status: "left" } };
      }
      default:
        return this.err(`fn desconocida ${fn}`);
    }
  }

  async membresias(actor: Actor, gids?: string[]) {
    const out = new Map<string, string>();
    for (const [gid, g] of this.grupos) {
      if (gids && !gids.includes(gid)) continue;
      const m = g.members.get(actor.sub);
      if (m && (ESTADOS_EN_PULL as readonly string[]).includes(m.status)) out.set(gid, m.status);
    }
    return out;
  }

  async meta(jwt: string, gid: string) {
    const g = this.grupos.get(gid);
    const m = g?.members.get(this.subDe.get(jwt)!);
    if (!g || m?.status !== "active") return null;
    return { owner_user_id: g.owner, is_archived: g.archived, deleted: g.deleted };
  }

  async desarchivar(jwt: string, gid: string) {
    this.llamadas.push("desarchivar");
    const g = this.grupos.get(gid)!;
    const m = g.members.get(this.subDe.get(jwt)!);
    if (m?.role !== "admin") throw new Error("solo un admin desarchiva");
    g.archived = false;
  }

  estado(gid: string, sub: string) {
    return this.grupos.get(gid)?.members.get(sub)?.status;
  }
}

const enPull = (s?: string) => s !== undefined && (ESTADOS_EN_PULL as readonly string[]).includes(s);

describe("relevo del corpus de staging · A y B salen del pull de los grupos de la corrida", () => {
  it("dueño A con B activo (setupGroup): los dos fuera, el custodio queda de dueño", async () => {
    const s = new StagingDoble();
    s.sembrar("g1", A.sub, { [A.sub]: { status: "active", role: "admin" }, [B.sub]: { status: "active" } });
    const r = await relevarGrupos(s, ["g1"], ACT);
    expect(r.residuo).toEqual([]);
    expect(r.relevados).toEqual(["g1"]);
    expect(enPull(s.estado("g1", A.sub))).toBe(false);
    expect(enPull(s.estado("g1", B.sub))).toBe(false);
    expect(s.grupos.get("g1")!.owner).toBe(CUSTODIO.sub);
    expect(s.estado("g1", CUSTODIO.sub)).toBe("active");
  });

  it("dueño B con A admin activo (G10·1, tras el traspaso): A sale primero y B traspasa al custodio, no a A", async () => {
    const s = new StagingDoble();
    s.sembrar("g10", B.sub, { [A.sub]: { status: "active", role: "admin" }, [B.sub]: { status: "active", role: "admin" } });
    const r = await relevarGrupos(s, ["g10"], ACT);
    expect(r.residuo).toEqual([]);
    expect(s.grupos.get("g10")!.owner).toBe(CUSTODIO.sub);
  });

  it("B rechazado (3-ter): no puede salir tal cual; vuelve a entrar con invitación nueva y sale", async () => {
    const s = new StagingDoble();
    s.sembrar("g3t", A.sub, { [A.sub]: { status: "active", role: "admin" }, [B.sub]: { status: "rejected" } });
    const r = await relevarGrupos(s, ["g3t"], ACT);
    expect(r.residuo).toEqual([]);
    expect(s.estado("g3t", B.sub)).toBe("left");
  });

  it("B pendiente (G10·2) y grupo solo de A (5d, 8): fuera los dos", async () => {
    const s = new StagingDoble();
    s.sembrar("gp", A.sub, { [A.sub]: { status: "active", role: "admin" }, [B.sub]: { status: "pendingApproval" } });
    s.sembrar("ga", A.sub, { [A.sub]: { status: "active", role: "admin" } });
    const r = await relevarGrupos(s, ["gp", "ga"], ACT);
    expect(r.residuo).toEqual([]);
    expect(r.relevados.sort()).toEqual(["ga", "gp"]);
  });

  it("archivado (5c): el dueño lo desarchiva antes, o el custodio no podría entrar", async () => {
    const s = new StagingDoble();
    s.sembrar("garch", A.sub, { [A.sub]: { status: "active", role: "admin" }, [B.sub]: { status: "active" } }, { archived: true });
    const r = await relevarGrupos(s, ["garch"], ACT);
    expect(r.residuo).toEqual([]);
    expect(s.llamadas[0]).toBe("desarchivar");
  });

  it("grupo borrado (lo que hacía 3-quater con A): residuo con motivo, sin tocar nada", async () => {
    const s = new StagingDoble();
    s.sembrar("gdel", A.sub, { [A.sub]: { status: "active", role: "admin" } }, { deleted: true });
    const r = await relevarGrupos(s, ["gdel"], ACT);
    expect(r.relevados).toEqual([]);
    expect(r.residuo).toHaveLength(1);
    expect(r.residuo[0].motivo).toContain("grupo borrado");
    expect(r.residuo[0].motivo).toContain("A active");
    expect(s.llamadas).toEqual([]);
  });

  it("idempotente: una segunda pasada no gasta ni una llamada y lo cuenta como intacto", async () => {
    const s = new StagingDoble();
    s.sembrar("g1", A.sub, { [A.sub]: { status: "active", role: "admin" }, [B.sub]: { status: "active" } });
    await relevarGrupos(s, ["g1"], ACT);
    s.llamadas = [];
    const r = await relevarGrupos(s, ["g1"], ACT);
    expect(s.llamadas).toEqual([]);
    expect(r).toEqual({ relevados: [], intactos: ["g1"], residuo: [] });
  });

  it("retoma un relevo cortado: el custodio ya pendiente no se re-invita a ciegas y se aprueba", async () => {
    const s = new StagingDoble();
    s.sembrar("gcut", A.sub, { [A.sub]: { status: "active", role: "admin" }, [CUSTODIO.sub]: { status: "pendingApproval" } });
    const r = await relevarGrupos(s, ["gcut"], ACT);
    expect(r.residuo).toEqual([]);
    expect(s.grupos.get("gcut")!.owner).toBe(CUSTODIO.sub);
  });

  it("si el heredero no es el custodio (otro admin real dentro), lo dice: residuo, no éxito", async () => {
    const s = new StagingDoble();
    s.sembrar("gotro", A.sub, { [A.sub]: { status: "active", role: "admin" }, "sub-otro": { status: "active", role: "admin" } });
    const r = await relevarGrupos(s, ["gotro"], ACT);
    expect(r.residuo).toHaveLength(1);
    expect(r.residuo[0].motivo).toContain("no fue al custodio");
  });

  it("decide la relectura, no los 200: un leave_group que responde bien y no saca a nadie es residuo", async () => {
    class LeaveSordo extends StagingDoble {
      async rpc(jwt: string, fn: string, args: Record<string, unknown>) {
        if (fn === "leave_group") return { status: 200, body: { status: "left" } };
        return super.rpc(jwt, fn, args);
      }
    }
    const s = new LeaveSordo();
    s.sembrar("gsordo", A.sub, { [A.sub]: { status: "active", role: "admin" } });
    const r = await relevarGrupos(s, ["gsordo"], ACT);
    expect(r.relevados).toEqual([]);
    expect(r.residuo).toHaveLength(1);
    expect(r.residuo[0].motivo).toContain("sin error y aún en el pull");
  });

  it("nunca llama a groups_forget_user", async () => {
    const s = new StagingDoble();
    s.sembrar("g1", A.sub, { [A.sub]: { status: "active", role: "admin" }, [B.sub]: { status: "rejected" } });
    s.sembrar("g2", B.sub, { [A.sub]: { status: "active", role: "admin" }, [B.sub]: { status: "active", role: "admin" } }, { archived: true });
    await relevarGrupos(s, ["g1", "g2"], ACT);
    expect(s.llamadas).not.toContain("groups_forget_user");
  });
});

describe("relevo del corpus · solo escribe en staging", () => {
  it("acepta staging y rechaza producción y cualquier otro host", () => {
    expect(() => exigirStaging("https://fostjbbwstyuunmmefuk.supabase.co")).not.toThrow();
    expect(() => exigirStaging("https://kefvaiymtgytemwbltlz.supabase.co")).toThrow(/no es staging/);
    expect(() => exigirStaging("https://fostjbbwstyuunmmefuk.supabase.co.evil.dev")).toThrow(/no es staging/);
  });
});
