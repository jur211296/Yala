/**
 * Conteos de la base de Grupos y de las cuentas (decisión 5). Una sola RPC, `yala_stats_counts()`
 * (`qa/cloud/tel01_stats_counts.sql`), llamada con el JWT de máquina `yala_stats`: ese rol solo puede ejecutar esa
 * función, que devuelve números. Ni el panel ni el rol leen una fila de nadie.
 */
export async function fetchStatsCounts(url: string, anonKey: string, roleJwt: string): Promise<Record<string, unknown>> {
  const res = await fetch(`${url}/rest/v1/rpc/yala_stats_counts`, {
    method: "POST",
    headers: { apikey: anonKey, Authorization: `Bearer ${roleJwt}`, "content-type": "application/json" },
    body: "{}",
  });
  if (!res.ok) throw new Error(`supabase ${res.status}: ${(await res.text()).slice(0, 160)}`);
  const body = (await res.json()) as unknown;
  if (typeof body !== "object" || body === null || Array.isArray(body)) throw new Error("supabase: respuesta sin objeto");
  return body as Record<string, unknown>;
}
