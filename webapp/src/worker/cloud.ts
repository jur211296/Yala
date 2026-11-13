/**
 * ¿Esta cuenta usa la nube de Yala? Lo lee el núcleo compartido (`shared-core`), con la sesión NORMAL del login social:
 * el rol de solo lectura no puede leer `profiles`, y la RLS de `profiles` solo deja a cada usuario ver su fila.
 *
 * - `complete`: activó la nube en el iPhone. Entra.
 * - `groups_only`: solo usa Grupos. No entra hasta el lote 3 (decisión D3).
 * - `none`: nunca activó la nube (o Supabase creó la cuenta en este mismo login). No entra; se le explica cómo.
 *
 * La app crea la fila al activar la nube; no hay trigger en `auth.users`. Lanza si Supabase no contesta bien, para que
 * quien llama falle cerrado.
 */
import { YalaReader } from "../../../shared-core/src/data";
import type { Env } from "./env";
import type { Fetcher } from "./egress";

export type CloudKind = "complete" | "groups_only" | "none";

export async function cloudKind(env: Env, fetcher: Fetcher, normalAccess: string): Promise<CloudKind> {
  const reader = new YalaReader(env, normalAccess, fetcher);
  const rows = await reader.one<{ kind: string | null }>("profiles", [["select", "kind"]], 1);
  const row = rows[0];
  if (!row) return "none";
  return row.kind === "groups_only" ? "groups_only" : "complete";
}
