/**
 * Kill-switch SERVER-SIDE del canal Grupos → backend: punto ÚNICO de decisión sobre
 * `GROUPS_BACKEND_ROLLOUT_PERCENT` en las cuatro rutas de `/groups/*`.
 *
 * ## Por qué existe (medido el 2026-07-31)
 *
 * El percent lo leían SOLO `config.ts` (para publicarlo en `GET /config`) y `env.ts` (para declararlo).
 * Las rutas de grupos no lo consultaban jamás ⇒ bajarlo a `"0"` y desplegar cambiaba la respuesta de
 * `/config` en segundos, pero **un device que ya tenía el 100 cacheado seguía usando el canal 6 horas o
 * más** (`RemoteFlagDecisionLogic.refreshMinInterval = 6 * 60 * 60` es el intervalo MÍNIMO entre fetches, y
 * los únicos disparadores son el boot y dos `onAppear` — no hay refresh en foreground ni por timer, así que
 * para un device que no relance la app la ventana no tiene techo) y el gateway se lo aceptaba. Medido también en la dirección contraria el mismo día: un
 * iPhone real se quedó con `groupsBackendEnabled == false` durante horas DESPUÉS de subir el percent a
 * 100 — el invitado abría el enlace de invitación y la app no hacía nada. Mismo mecanismo, mismo retraso.
 * El runbook afirmaba que volver a `"0"` «apaga el canal en segundos»; era falso para los devices, y es
 * una frase que se lee en mitad de un incidente.
 *
 * ## LA restricción de diseño: el servidor aplica el KILL, no el ROLLOUT
 *
 * El servidor **NO puede** replicar la decisión del cliente device a device. El bucket sale de
 * `RemoteFlagDecisionLogic.stableBucket(seed:)` sobre un seed de INSTALACIÓN que jamás sale del device: al
 * gateway solo llega un SHA-256 truncado a 16 hex, y solo en el payload de `/metrics`
 * (`Yala/Services/Metrics/MetricsService.installHash` → `metrics.ts`), nunca en las peticiones de grupos. Calcular el bucket server-side desde otra cosa
 * (el `sub`, el keyId, la IP) produciría una partición DISTINTA de la del cliente: devices ON por la
 * lógica del cliente y OFF por la del servidor, y al revés. Split-brain, y del tipo que no se ve hasta
 * que alguien mueve el percent a un valor intermedio.
 *
 * ⇒ `percent == 0` ⇒ rechazar; **cualquier valor `> 0` ⇒ no rechazar** y dejar que el cliente decida con
 * su bucket. Eso entrega exactamente la propiedad que se busca (parada inmediata) sin inventarse una
 * cohorte que el servidor no puede conocer. Un guard que exigiera `bucket < percent` sería el rollout, no
 * el kill, y es justo el bug que este módulo evita.
 *
 * ## Por qué reusa `parseRolloutPercent` de `config.ts` y no parsea por su cuenta
 *
 * Es lo que hace que la partición del servidor y la que `GET /config` PUBLICA no puedan divergir: con dos
 * parseos, un valor basura (`"abc"`, `"-1"`, `" 5"`) podría leerse OFF en un sitio y ON en el otro, y esa
 * incoherencia es exactamente la clase de fallo que el módulo existe para cerrar. Hereda además su
 * fail-closed: ausente/inválido → 0 → **rechazo**. Coherente por construcción — el gateway rechaza
 * exactamente cuando `/config` publica 0.
 *
 * ## Lo que el kill NO puede cortar: el teardown del borrado de cuenta
 *
 * `groups_forget_user` está EXENTO a propósito, espejando una decisión ya tomada en el cliente:
 * `GroupBackendMembershipService.forgetUser()` usa `ensureEligibleForTeardown()` (capacidad COMPILADA),
 * y su docblock —`Yala/Services/CloudSync/Groups/GroupBackendMembershipService.swift:13-20`— dice por
 * escrito que compartir el gate compuesto «haría fallar el paso 1 del borrado y dejaría al usuario sin
 * poder ejercer su derecho de supresión mientras durase» el kill. Un servidor que corte más que el
 * cliente reintroduce esa retención de PII desde el otro lado. Otros 9 RPCs de la allowlist son
 * ENTRADAS (crear, unirse, invitar, revocar, aprobar, expulsar, salir, renombrarse, transferir
 * ownership), todos con gate COMPUESTO en el cliente, y son justo lo que el kill existe para cerrar.
 *
 * ## Los 2 del consent (C1): NO exentos, y no es por descarte
 *
 * `record_groups_consent` / `groups_consent_state` no los llama ninguno de los dos gates de arriba: los
 * llama un INTENT DURABLE, y esa es exactamente la razón de dejarlos dentro del kill. Un 403 aquí no
 * pierde nada — el cliente clasifica `yala_groups_disabled` como TRANSITORIO y CONSERVA el intent (sin
 * TTL, sin tope), así que el registro se completa solo cuando el canal vuelva. Exceptuarlos, en cambio,
 * dejaría escrituras entrando durante un incidente por una puerta que nadie mira, y sin ninguna ganancia:
 * con el canal apagado no hay grupos que crear ni a los que unirse, así que registrar el consent en ese
 * instante no desbloquea a nadie. La aceptación ya ocurrió y la prueba de que ocurrió no depende de que
 * el request llegue HOY.
 *
 * ## Las rutas que NO llevan el kill, y por qué (la pregunta que se hace todo el que llega aquí)
 *
 * `POST /push/register` y `POST /push/unregister` reusan `requireUserAndAttest` de `groups/routes.ts` y
 * sirven al canal de Grupos, así que parecen candidatas. No lo son, por los dos lados:
 *   · **register**: `PushTokenRegistrar.attemptUpload()` ya gatea por el COMPUESTO
 *     (`CloudSyncFlags.groupsBackendEnabled`), así que con el kill puesto el cliente deja de llamar por su
 *     cuenta en cuanto refresque. Y lo que hace la ruta —apuntar un device token— no muta ni lee datos de
 *     grupos: mientras el snapshot siga viejo, lo peor que pasa es que se registre un token que servirá
 *     cuando el canal vuelva. Bloquearlo no evita ningún daño.
 *   · **unregister**: es TEARDOWN (`PushTokenSignOutSeam.clearForSignOut`, con 6 call-sites, todos en
 *     `CloudSessionSignOut.swift`). Bloquearlo dejaría tokens huérfanos recibiendo silent pushes de un
 *     canal del que el usuario ya salió, que es peor que no bloquear nada.
 * El `waitUntil` del fan-out (`fanOutGroupPush`) tampoco necesita guard propio: solo se alcanza desde un
 * `/groups/push` que ya pasó por aquí.
 *
 * **Consecuencia asumida y ratificada por el owner (2026-08-03):** con el kill activo, CERRAR SESIÓN
 * queda bloqueado, porque `CloudSessionSignOut` exige drenar el outbox de grupos vía `/groups/push` y
 * jamás descarta filas. Es reversible y reintentable (el usuario ve el alert de siempre, su outbox queda
 * intacto) y es el precio de que el kill pare las ESCRITURAS, que es la mitad peligrosa. El BORRADO de
 * cuenta NO pasa por push (`closeLocalAfterAccountDeletionCloud`: «NO hay push-all NI re-verify»), así
 * que el derecho de supresión no se toca.
 */
import type { Env } from "../env";
import { parseRolloutPercent } from "../config";
import { jsonError } from "../errors";

/**
 * Mensaje único del 403. NOMBRA la var y dice explícitamente que no es transitorio: un error que no se
 * explica a sí mismo obliga a leer el código del gateway en mitad de un incidente. No hay fuga — el
 * NOMBRE de una var pública del Worker no es un secreto, y su valor ya se publica en `GET /config`.
 */
export const GROUPS_DISABLED_MESSAGE =
  "Canal de Grupos apagado por configuración (GROUPS_BACKEND_ROLLOUT_PERCENT = 0). " +
  "Apagado DELIBERADO, no un fallo transitorio: no reintentar.";

/**
 * RPCs de `/groups/rpc/:fn` que el kill NO corta. Uno solo, y su porqué está en el header: es el TEARDOWN
 * del borrado de cuenta, y el cliente ya lo exceptúa por capacidad compilada. Al añadir un RPC nuevo a
 * `PARAM_ALLOWLIST`, la pregunta es por qué gate lo llama el cliente: `ensureEligible()` (compuesto) →
 * NO va aquí; `ensureEligibleForTeardown()` (compilado) → va aquí.
 */
export const KILL_EXEMPT_RPCS: ReadonlySet<string> = new Set(["groups_forget_user"]);

/**
 * La `Response` 403 lista para devolver si el canal está apagado, o `null` si puede pasar. Molde de
 * `gateRequest` (`ratelimit.ts`): el caller hace `if (killed) return killed`.
 *
 * El 403 no es cosmético — es lo que hace el rechazo DISTINGUIBLE de un transitorio en el cliente sin
 * tocar el canal de sync: `GroupsSyncClient` (push y pull) y `GroupsMerkleClient` ya mapean 403 →
 * `.accountUnavailable` → `SyncCadencePolicy.stopUntilRelaunch`, o sea parada SIN bucle de reintentos.
 * Un 503 caería en su `default` → `.transient` → backoff exponencial para siempre contra un veredicto
 * definitivo, que es la clase de bug que costó el 2026-07-31.
 */
export function groupsChannelKilled(env: Env): Response | null {
  // `parseRolloutPercent` de config.ts, NUNCA un parseo escrito aquí. No es estilo: es lo que hace que la
  // coherencia con `GET /config` sea POR CONSTRUCCIÓN y no por coincidencia. Un `Number(raw) > 0` diverge
  // ya HOY, medido en las dos direcciones —`"0.5"`/`"0.9"` dejan pasar con /config publicando 0, y `"1abc"`
  // rechaza con /config publicando 1—, y lo cazan los tres valores DISCRIMINANTES de la tabla de
  // equivalencia. Un `parseInt` inline coincide hoy por casualidad (el clamp no altera el signo del `> 0`)
  // y divergiría en silencio el día que `parseRolloutPercent` cambie: eso NO lo caza ningún test de
  // valores, así que lo pinnea el source-scan «parser compartido» de test/groups.killswitch.test.ts.
  if (parseRolloutPercent(env.GROUPS_BACKEND_ROLLOUT_PERCENT) > 0) return null;
  return jsonError("yala_groups_disabled", GROUPS_DISABLED_MESSAGE, 403);
}
