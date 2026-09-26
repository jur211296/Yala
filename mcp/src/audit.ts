/**
 * Registro de accesos (lo pide el diferido #22 del modo nube). Una línea JSON por llamada a una herramienta, a los
 * logs del Worker: qué herramienta, qué cliente OAuth, un hash corto del usuario, cuánto tardó y cómo acabó.
 *
 * Nunca datos financieros, ni el `sub` en claro, ni el token. La auditoría visible para el usuario («Claude leyó
 * tus presupuestos ayer») es fase 2 y necesita almacenamiento propio.
 */
import type { VerifiedToken } from "./auth";

export function userHash(sub: string): string {
  // FNV-1a de 32 bits: basta para correlacionar líneas de log sin exponer el id. No es un secreto ni una firma.
  let h = 0x811c9dc5;
  for (let i = 0; i < sub.length; i++) {
    h ^= sub.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16).padStart(8, "0");
}

export function audit(e: { tool: string; token: VerifiedToken; ms: number; outcome: string }): void {
  console.log(
    JSON.stringify({
      evento: "mcp_herramienta",
      herramienta: e.tool,
      cliente: e.token.clientId,
      usuario: userHash(e.token.sub),
      ms: e.ms,
      resultado: e.outcome,
    }),
  );
}
