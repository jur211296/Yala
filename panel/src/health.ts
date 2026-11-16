/**
 * Umbrales de Salud (decisión de la sesión de construcción, 2026-11-06, ASUMIDA y ajustable aquí): cada canario lleva
 * un color según cuántos aparatos lo dieron en la semana.
 *
 *  - **Informativos** (no colorean nunca): los que cuentan algo que salió bien o un paso normal —copias guardadas,
 *    avisos entregados, desenlaces, reparaciones hechas, esperas de permiso—. Se reconocen por su sufijo o están en
 *    `INFORMATIONAL`.
 *  - **El resto**: ámbar con 1 aparato o más, rojo con `RED_DEVICES` o más.
 *  - `OVERRIDES` fija otros umbrales para un canario concreto.
 *
 * Esto NO sustituye a Sentry: los cuelgues siguen allí. Aquí va lo que Sentry no ve.
 */
export type Level = "info" | "ok" | "warn" | "bad";

export const RED_DEVICES = 5;

const INFORMATIONAL_SUFFIX = /(Succeeded|Delivered|Outcome|Accepted|Repaired|Reconciled|Relayed|Checked|Choice|Step|Persisted|Retired|Fused|Uploaded|Restored|Translated|Rehydrated|Route|Parse|Regenerated|Waited|Pending|Deferred)$/;

export const INFORMATIONAL = new Set<string>(["routingReadinessBlocked", "routingIntentSuperseded", "routingWelcomeChainSuperseded"]);

export const OVERRIDES: Record<string, { warn: number; bad: number }> = {
  // Una copia que falla se reintenta sola: preocupa cuando se repite en varios aparatos.
  cloudkitExportFailed: { warn: 3, bad: 10 },
};

export function levelFor(name: string, devices: number): Level {
  if (INFORMATIONAL.has(name) || INFORMATIONAL_SUFFIX.test(name)) return "info";
  const t = OVERRIDES[name] ?? { warn: 1, bad: RED_DEVICES };
  if (devices >= t.bad) return "bad";
  if (devices >= t.warn) return "warn";
  return "ok";
}
