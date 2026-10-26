import type { Env } from "./env";

/**
 * Canarios PROPIOS del gateway, persistidos en Analytics Engine (card `9f9u`, ticket `gateway-has-no-telemetry`).
 *
 * Hasta el 2026-10-25 los canarios del gateway eran `console.log`: solo existían mientras alguien tuviera
 * `wrangler tail` abierto. Si los avisos de Grupos dejaban de llegar, nadie se enteraba. Ahora cada uno escribe
 * además un datapoint en el MISMO dataset que `POST /metrics` (binding `METRICS`), con la misma forma, para que
 * las queries de `qa/cloud/README.md` § /metrics sirvan sin cambios:
 *
 *   blobs   [e="canary", n=<nombre>, d=<detalle>, app="gateway", install="gateway"]
 *   doubles [x]
 *   indexes ["gateway"]
 *
 * `app = "gateway"` es lo que separa estas filas de las que manda la app (`app` = versión de la app). El detalle
 * nunca lleva un device token, un user id ni nada del usuario: solo estados HTTP, motivos de APNs y nombres de RPC.
 *
 * Sin binding (tests, env sin configurar) no hace nada. Un fallo de escritura no puede romper la petición que lo
 * llama: `writeDataPoint` no lanza en Workers, y aun así va en `try`.
 */

/** Los canarios que emite el gateway. Una lista cerrada: un nombre nuevo se añade aquí y en el README. */
export const SERVER_CANARIES = [
  /** APNs no entregó un aviso de Grupos por un motivo que no es un token muerto. `d` = `status/reason`. */
  "groupApnsSendFailed",
  /** APNs dijo que el token está muerto (`BadDeviceToken`/`Unregistered`) y se podó. `d` = motivo. */
  "groupPushTokenPruned",
  /** El podado del token muerto falló. `d` = estado HTTP. */
  "groupPushTokenPruneFailed",
  /** El fan-out no pudo pedir los tokens de un grupo. `d` = `rpc/status`. */
  "groupFanoutTokensRpcFailed",
  /** Fan-out sin APNs configurado: ningún aviso de Grupos sale. */
  "groupFanoutApnsNotConfigured",
  /** Fan-out sin `PUSH_ROLE_JWT`: no puede pedir tokens, ningún aviso sale. */
  "groupFanoutPushRoleMissing",
  /** Cuántos avisos ENTREGÓ un fan-out (`x`). La serie que dice «los avisos están llegando». */
  "groupFanoutDelivered",
  /** El registro de un token de push falló contra PostgREST. `d` = estado HTTP. */
  "pushTokenRegisterFailed",
  /** Un delta de Grupos llegó con una unidad de coherencia a medias. `d` = entidad. */
  "groupSyncCoherenceGroupPartial",
  /** Un delta personal llegó con una unidad de coherencia a medias. `d` = entidad. */
  "cloudSyncCoherenceGroupPartial",
] as const;
export type ServerCanary = (typeof SERVER_CANARIES)[number];

const MAX_DETAIL_CHARS = 128;

export function serverCanary(env: Pick<Env, "METRICS">, name: ServerCanary, detail = "", x = 1): void {
  const dataset = env.METRICS;
  if (!dataset) return;
  try {
    dataset.writeDataPoint({
      blobs: ["canary", name, detail.slice(0, MAX_DETAIL_CHARS), "gateway", "gateway"],
      doubles: [x],
      indexes: ["gateway"],
    });
  } catch (e) {
    console.log(`[server-canary] writeDataPoint falló name=${name} ${String(e).slice(0, 80)}`);
  }
}
