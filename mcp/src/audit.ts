/**
 * Registro de accesos (lo pide el diferido #22 del modo nube). Una línea JSON por evento, a los logs del Worker:
 *
 * - `mcp_herramienta`: qué herramienta, qué cliente, un hash corto del usuario, cuánto tardó y cómo acabó.
 * - `mcp_autorizacion`: una conexión nueva de Claude, o por qué no se completó.
 * - `mcp_revocacion`: una conexión que el Worker retiró, y por qué (Supabase la revocó, caducó…).
 *
 * Nunca datos financieros, ni el `sub` en claro, ni ningún token. La auditoría visible para el usuario («Claude
 * leyó tus presupuestos ayer») es fase 2 y necesita almacenamiento propio.
 */
export function userHash(sub: string): string {
  // FNV-1a de 32 bits: basta para correlacionar líneas de log sin exponer el id. No es un secreto ni una firma.
  let h = 0x811c9dc5;
  for (let i = 0; i < sub.length; i++) {
    h ^= sub.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16).padStart(8, "0");
}

/** Quién hizo la llamada: el cliente de Claude (id del Worker) y el usuario de Yala. */
export interface AuditSubject {
  clientId: string;
  sub: string;
}

export function audit(e: { tool: string; session: AuditSubject; ms: number; outcome: string }): void {
  console.log(
    JSON.stringify({
      evento: "mcp_herramienta",
      herramienta: e.tool,
      cliente: e.session.clientId,
      usuario: userHash(e.session.sub),
      ms: e.ms,
      resultado: e.outcome,
    }),
  );
}

/** Eventos de la conexión. `sub` se escribe como hash; el resto de campos tienen que ser cortos y sin datos. */
export function auditEvent(
  evento: "mcp_autorizacion" | "mcp_revocacion",
  fields: { cliente?: string; sub?: string; motivo?: string; resultado?: string },
): void {
  const { sub, ...rest } = fields;
  console.log(JSON.stringify({ evento, ...rest, ...(sub ? { usuario: userHash(sub) } : {}) }));
}
