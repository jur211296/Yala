import type { Env } from "./env";

/**
 * Hechos de USO que solo ve el servidor (2026-11-06, decisión 5 de la telemetría propia: «Grupos, Nube y Pro se
 * cuentan desde el servidor»). Los lee el cron del panel (`panel/`), no una persona con SQL.
 *
 * No son canarios: un canario dice «algo raro pasó» y su gate es «en cero»; estos cuentan cosas normales (una prueba
 * de Pro que empieza, alguien que gastó su última pregunta del día). Por eso llevan su propio `e = "server"` y no se
 * mezclan con los de `serverCanary.ts`. Mismo dataset (binding `METRICS`) y misma forma:
 *
 *   blobs   [e="server", n=<nombre>, d=<detalle>, app="gateway", install="gateway"]
 *   doubles [x]
 *   indexes ["gateway"]
 *
 * El detalle NUNCA lleva un id de transacción, un user id, un keyId ni un importe: solo tipos de aviso de Apple,
 * planes y categorías. Lista cerrada, como la de los canarios: un nombre nuevo se añade aquí y en el README.
 */
export const SERVER_EVENTS = [
  /**
   * Un aviso de App Store Server Notifications V2 con firma válida y de nuestro bundle.
   * `d` = `<notificationType>|<subtype o ->|<trial|paid|->|<Production|Sandbox|->`. El tercer campo dice si la
   * transacción del aviso entró con la oferta de prueba gratis (`offerDiscountType = FREE_TRIAL`).
   */
  "appstoreNotification",
  /**
   * Una petición de IA gastó la ÚLTIMA pregunta de su cupo (del día, o de la prueba de Free). Sale una vez por
   * persona y cupo, no en cada rechazo posterior. `d` = `<free|pro>|<daily|trial>|<categoría>`.
   */
  "aiQuotaExhausted",
] as const;
export type ServerEvent = (typeof SERVER_EVENTS)[number];

const MAX_DETAIL_CHARS = 128;

export function serverEvent(env: Pick<Env, "METRICS">, name: ServerEvent, detail = "", x = 1): void {
  const dataset = env.METRICS;
  if (!dataset) return;
  try {
    dataset.writeDataPoint({
      blobs: ["server", name, detail.slice(0, MAX_DETAIL_CHARS), "gateway", "gateway"],
      doubles: [x],
      indexes: ["gateway"],
    });
  } catch (e) {
    console.log(`[server-event] writeDataPoint falló name=${name} ${String(e).slice(0, 80)}`);
  }
}

/**
 * El detalle de `appstoreNotification`, en un solo sitio para que el panel y el test lean lo mismo.
 * `offerDiscountType`: `undefined` = el aviso no trae transacción («-»); `null` o cualquier otro valor = transacción
 * pagada («paid»); `"FREE_TRIAL"` = prueba gratis («trial»).
 */
export function appstoreNotificationDetail(args: {
  notificationType: unknown;
  subtype: unknown;
  offerDiscountType: unknown;
  environment: unknown;
}): string {
  const slug = (v: unknown) => (typeof v === "string" && /^[A-Za-z0-9_]{1,40}$/.test(v) ? v : "-");
  const offer = args.offerDiscountType === undefined ? "-" : args.offerDiscountType === "FREE_TRIAL" ? "trial" : "paid";
  return `${slug(args.notificationType)}|${slug(args.subtype)}|${offer}|${slug(args.environment)}`;
}
