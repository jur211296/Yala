# Guion de la tanda de QA

> **Qué es esto.** Los tickets de `tickets/qa/` no se drenan de uno en uno: se acumulan y se hacen
> juntos (decisión del owner, 2026-09-03). Este guion los agrupa **por montaje**, que es donde está el
> ahorro: montar dos teléfonos una vez en lugar de trece es la mitad del trabajo de la tanda.
>
> **Actualizado: 2026-09-16 · 52 tickets, los 52 con montaje.** Sale del barrido del 2026-09-16
> (encargo `2026-09-16-barrido-qa-sincerar-cola`): lo que se podía ver en el simulador se vio y salió de
> `qa`, y lo que no tenía guion ni en simulador ni en un aparato se cerró por override del owner. **Lo que
> queda aquí necesita tus manos o aparatos reales.**
>
> Al mover algo a `qa/` o sacarlo de ahí, actualiza este guion. Todavía no hay un checker que lo compare
> con la carpeta: es el punto 2 de [[qa-guion-tanda-no-cubre-17-tickets]].
>
> `qa` NO significa «terminado»: significa que el código está hecho y verificado hasta donde el simulador
> alcanza.

## Cómo se lee

- **Los pasos están en cada ticket.** La columna «Guion» dice la sección y la línea. Si el ticket tiene al
  final una «Corrección al guion · 2026-09-16», esa corrección manda sobre lo de arriba.
- **«PASS si…» es lo que tiene que verse.** Si no se ve, es FAIL y el ticket vuelve a `in-progress` con lo
  que viste. Si no pudiste montarlo, no es FAIL: se queda en `qa` con una nota de qué faltó.

## Orden recomendado

De menor a mayor coste de preparación. El grupo 8 corre solo mientras haces lo demás.

| # | Montaje | Tickets | Qué necesitas |
|---|---|---|---|
| 1 | Simulador, a mano | 3 | Solo el Mac, unos 30 minutos |
| 2 | Un iPhone | 12 | TestFlight o build firmada |
| 3 | Un iPhone con el chat de IA | 4 | El iPhone del grupo 2 |
| 4 | Un iPhone y acceso al servidor | 8 | Staging, wrangler o SQL de Supabase |
| 5 | Dos aparatos con el mismo Apple ID | 8 | iPhone + iPad valen |
| 6 | Cambio de Apple ID | 1 | Dos Apple ID |
| 7 | Dos teléfonos con cuentas distintas | 13 | Dos aparatos, dos cuentas, la misma build |
| 8 | Simulador con tu cuenta o el secreto de staging, a lo largo de un día | 3 | Arrancar hoy y mirar mañana |

---

## Grupo 1 · Simulador, a mano (3)

**Montaje:** El simulador con `Yala Dev`. Son gestos a los que la automatización no llega —el selector de archivos, el selector de moneda y las fichas de una acción de Atajos—; con el dedo, sí.

| Ticket | Qué preparar | PASS si… | Guion en el ticket |
|---|---|---|---|
| `applepay-shortcut-warm-launch-empty-data` | Atajos → Crear atajo → «Registrar pago de Apple Pay» con Cantidad y Comercio | (a) caliente, (b) frío y (c) varios pagos: borradores en la Bandeja y datos intactos sin cerrar la app. (d) con iCloud importando → iPhone | §Implementación 2026-07-04 «QA TestFlight» + §QA · 2026-09-16 |
| `changing-an-account-currency-orphans-its-whole-history` | seed realista + foreign-account JPY + pro; cuenta «QA FX» | Cambiar la divisa pregunta «¿Convertir N movimientos?» y reexpresa; Cancelar no cambia nada; cuenta vacía cambia sin preguntar | §Qué mirar en device-QA L169 (pasos 1, 2 y 4) |
| `csv-import-rows-fall-in-the-chat-sign-sweep` | Yala Dev sin -uitest; dos CSV arrastrados a Archivos | Tras relanzar, el lote importado (+45, +30) sigue positivo y la fila suelta pasa a −20 | §QA · 2026-09-16 (al final) |

---

## Grupo 2 · Un iPhone (12)

**Montaje:** Un iPhone con el TestFlight actual. Varias filas piden borrar la app o un Apple ID desechable: mira «Qué preparar» antes de empezar.

| Ticket | Qué preparar | PASS si… | Guion en el ticket |
|---|---|---|---|
| `beacon-routes-only-never-blocks` | Google sin cuenta Yala; iPhone borrable; crea cuentas reales en producción | «Esa cuenta usa otro método» ofrece entrar con Apple o crear con Google; se crea la segunda cuenta y la de Apple sigue intacta | §Guion de device-QA… L190 |
| `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest` | TestFlight con el cambio; Yala con datos en iCloud privado | En Perfil, «Dónde viven tus datos» sigue mostrando «Migrar a la nube» o «Activar la nube en este dispositivo» | §Device-QA — un solo paso, en iPhone real L119 |
| `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` | TestFlight con el cambio; iPhone cuyos datos de Yala puedan perderse | Tras reinstalar, «Es mi primera vez» muestra «Elige dónde quieres guardar tus datos» con las dos tarjetas | §Device-QA — un solo paso, en iPhone real L95 |
| `cloud-sign-in-discovers-account-kind` | Cuentas solo grupos (Google) y completa; Apple ID sin cuenta; enlace de invitación | Solo grupos no llega al Panel; sin cuenta, «No encontramos una cuenta»; completa aterriza en Grupos; con sesión privada, bloqueo | §Los cuatro recorridos L343 (+ corrección al final) |
| `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest` | Google sin cuenta Yala; iPhone borrable; paso A en simulador Yala Dev | Simulador: ningún botón de crear («Volver» si no hay cuenta); iPhone: aparece «Crear mi cuenta» o «Crear cuenta con Google» | §Device-QA — dos pasos L121 |
| `device-qa-discard-gate-returns-to-restore-without-icloud` | Sesión solo grupos con gastos; iCloud con datos previos; modo avión | Sin red o sin iCloud, «Empezar desde cero» no borra nada y vuelve a Restaurar; al borrar, grupos intactos y ningún aviso falso | §Recorridos L44 |
| `fx-partial-rate-rows-silent-1to1` | Cuenta en yenes con gastos pasados; luego cambiar la divisa preferida | Con red, el gasto en yenes deja de marcarse aproximado al llegar la tasa; tras cambiar la divisa preferida, nada queda 1:1 | §Acceptance Criteria L280 (+ Device-QA parcial L412) |
| `groups-only-second-launch-mounts-icloud-mirror` | Apple ID con datos en iCloud; app borrada; enlace de invitación ajeno | Tras crear un grupo, unirse o cerrar sesión, reabrir tres veces no trae datos de iCloud; «Restaurar desde iCloud» sí lo trae todo | §Guion de device-QA (iPhone real — en simulador NO se puede) L208 |
| `groups-settlement-reminder` | Deuda tuya de un gasto de hace más de 3 semanas; avisos de Grupos y recordatorios encendidos | Llega sin abrir la app «Te recordamos que le debes S/ X a Ana…», uno por grupo, y no se repite en una semana | §Implementado (2026-09-07) L313 |
| `reentry-counts-as-fresh-install` | cuenta nube con transacciones; reinstalar desde TestFlight | «Descargando tus datos…» mientras está vacía; el Panel no enseña «Primeros pasos» ni la oferta de prueba | §QA · 2026-09-16 (al final) |
| `repair-queue-has-no-exit-for-partial-rate-rows` | Transacción en una divisa que el proveedor no trae; dashboard de canarios | Con red, cada arranque sin cambios deja un solo «skipped» sin rehacer el barrido; al llegar la tasa, se corrige sola | §Corrección al guion · 2026-09-16 L221 |
| `scheduled-payments-notif-dedup` | ≥2 pagos que vencen hoy, permiso concedido, hora del aviso a +10 min | Llega un solo resumen a su hora sin abrir la app; antes de la hora configurada no llega nada | §Guion device-QA (owner) L71, fases 2, 4 y 6 |

---

## Grupo 3 · Un iPhone con el chat de IA (4)

**Montaje:** El iPhone del grupo 2 con el chat de IA funcionando (en simulador no hay App Attest, así que el chat no responde). Anota el saldo de la cuenta antes de cada prueba.

| Ticket | Qué preparar | PASS si… | Guion en el ticket |
|---|---|---|---|
| `chat-assistant-plants-exchange-rate-one` | Cuenta en divisa distinta de la preferida (evitar VND) | Guardado desde la tarjeta del chat, el detalle del gasto muestra el tipo de cambio real, no 1 | §Qué falta L128 |
| `chat-draft-drops-the-expense-sign` | Cuenta en soles con el saldo anotado antes de dictar | Tras dictar «gasté 30 soles en el almuerzo» y Guardar en la tarjeta, el saldo baja 30 y los gastos suben 30 | §Qué le pasa al usuario L12 |
| `chat-draft-sign-can-contradict-its-subcategory` | Memoria de comercio: aprobar 5 ingresos con la misma nota en la Bandeja | Al dictar un gasto con esa nota, el borrador no trae la subcategoría de ingreso: la pide antes de guardar | §Pendiente L118 |
| `chat-draft-stamps-its-own-currency-not-the-account` | Ninguna cuenta en USD; una en soles con el saldo anotado | Con «gasté 50 dólares» en la cuenta en soles, la etiqueta del monto pasa a PEN antes de guardar y el saldo de la cuenta cuadra después | §Pendiente L128 |

---

## Grupo 4 · Un iPhone y acceso al servidor (8)

**Montaje:** Un iPhone —`Yala Dev` contra staging o TestFlight contra producción, según la fila— y el acceso que pida la fila: SQL de Supabase, un percent del gateway o wrangler. **Deja cada percent como estaba al terminar.**

| Ticket | Qué preparar | PASS si… | Guion en el ticket |
|---|---|---|---|
| `cloud-signout-collapses-a-groups-session-expiry-into-permanent` | Yala Dev en iPhone; nube con grupo; SQL de staging | «Cerrar sesión» dice «Tu sesión caducó. Vuelve a iniciar sesión…», no «Revisa tu conexión», y el gasto sigue | §Device-QA — NO simulable L102 |
| `cloud-signout-collapses-every-groups-transient-into-permanent` | Cuenta nube (Yala Dev); gasto de grupo sin subir; 5xx en /groups/push | Al cerrar sesión sale al instante «Los últimos cambios de tus grupos no llegaron al servidor…», no «Revisa tu conexión» | §Device-QA — NO simulable L110 |
| `full-mode-activation-must-ask-where-personal-data-lives` | Solo grupos con otro miembro; iCloud con datos; SQL de Supabase; otro teléfono | Activar pregunta dónde guardar; privado ofrece restaurar, borrar o volver sin tocar los grupos; nube queda completa; abandonar no cambia nada | §Device-QA — lo prueba Jürgen L163 |
| `groups-consent-door-spec` | TestFlight fresco, cuenta de pruebas, SQL de Supabase producción | El consentimiento sale una vez, queda una sola fila en groups_consents, y no vuelve en un segundo login | §QA · 2026-09-16 (al final) |
| `groups-killswitch-403-blocks-detach-forever` | Cuenta de grupos asociada; gasto sin subir; percent de Grupos del gateway a 0 | Con Grupos en pausa y cambios sin subir, desasociar o cerrar sesión dice que los grupos están en pausa, no «revisa tu conexión» | §Qué queda: device-QA, y NO es simulable L71 |
| `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` | Yala Dev contra staging; cuenta con grupo; >1 h sin red; SQL de staging | Sin red y con el token caducado, cerrar sesión nunca dice «Tu sesión caducó» (con la sesión borrada, sí); el gasto sube al volver la red | §Device-QA — NO simulable L116 |
| `reentry-killswitch-closes-both-doors` | Percent de la nube en el gateway; un Apple ID con cuenta nube y otro sin | Con kill: «La nube de Yala está en pausa»; sin kill: re-entrar acaba en «¡Tu cuenta está lista!» y abre la app sin reiniciar | §Device-QA — el guion… L175 (+ correcciones L241) |
| `reverse-cutover-cerrado-para-cuentas-born-cloud` | Yala Dev contra staging; iCloud real; alta en la nube con datos; CloudKit Console | «Volver a iCloud» aparece y termina en privado con todo el histórico; los datos están en CloudKit y lo borrado no resucita | §Guion L262 |

---

## Grupo 5 · Dos aparatos con el mismo Apple ID (8)

**Montaje:** Un iPhone y un iPad (o dos iPhone) con el mismo Apple ID e iCloud activo. Varias filas piden un Apple ID desechable con meses de datos en iCloud: prepáralo una vez para todas.

| Ticket | Qué preparar | PASS si… | Guion en el ticket |
|---|---|---|---|
| `device-qa-activation-restore-start-fresh` | TestFlight; solo grupos con gastos; iCloud con datos; Apple ID desechable | «Empezar desde cero» avisa con cifras; borrar deja onboarding sin pedir nombre, con categorías y grupos intactos; otro aparato no restaura nada | §Los recorridos L41 |
| `device-qa-groups-invite-neutral-return` | A con iCloud bajado y onboarding a medias; B en privado; alguien que invite | A avisa de que el teléfono quedará en blanco y al reabrir sale «Unirme al grupo»; B conserva sus datos, sin gastos del grupo | §Recorridos L33 (+ corrección al final) |
| `groups-entry-on-a-mirrored-store-still-blocks-the-owner` | Apple ID con datos en iCloud; app borrada; otro aparato de testigo | «Vengo por un grupo» no bloquea: pide reabrir y sigue a Grupos; «Restaurar desde iCloud» lo trae todo; el testigo no recibe gastos del grupo | §Guion de device-QA (NO simulable) L220 |
| `icloud-kv-prefs-cross-sessions-on-a-lent-phone` | A con sesión privada; B en solo grupos («Vengo por un grupo») | Cambiar idioma o moneda en uno no cambia el otro; con B en privado, sí llega | §Device-QA (Jürgen) L125 |
| `remote-wipe-signal-honored-by-any-session` | A privado con datos; B solo grupos por enlace; consola de B | Al vaciar datos en A, B (solo grupos) conserva perfil y preferencias, sin «Datos no disponibles»; con B privado, sí se vacía | §Guion L95 (+ corrección L128) |
| `restore-start-fresh-keeps-the-imported-corpus` | TestFlight; Apple ID desechable con meses de datos en iCloud | «Empezar desde cero» avisa con las cifras de iCloud; tras borrar, onboarding limpio y nada vuelve, tampoco restaurando en otro aparato | §Device-QA · lo que solo se puede verificar en un iPhone L273 |
| `session-exits-one-verb-per-session` | TestFlight; iPad; grupo con otro miembro; CSV de miles de filas | «Cerrar sesión» espera a iCloud y «Restaurar» lo trae todo; vaciar en privado vacía el iPad, en solo grupos no | §Guion de device-QA (NO simulable) L312 (+ cambios L383) |
| `welcome-private-fresh-start-skips-icloud-check` | TestFlight; Apple ID desechable con meses de datos en iCloud | «Primera vez → privado» avisa con cifras antes de reabrir; borrar deja onboarding limpio e iCloud vacío; sin iCloud, aviso al volver | §Device-QA · lo que solo se puede verificar en un iPhone L290 |

---

## Grupo 6 · Cambio de Apple ID (1)

**Montaje:** Un iPhone y dos Apple ID. El recorrido vacía el teléfono: no lo hagas en el tuyo de diario.

| Ticket | Qué preparar | PASS si… | Guion en el ticket |
|---|---|---|---|
| `device-qa-apple-id-change-closes-private-session` | Dos Apple ID; sesión privada con movimientos; cuenta de grupos asociada | Cambiar de Apple ID muestra el aviso (apagar iCloud Drive, no); «Ahora no» no borra; confirmar vacía el teléfono y volver a A lo restaura | §Recorridos L41 |

---

## Grupo 7 · Dos teléfonos con cuentas distintas (13)

**Montaje:** Dos aparatos con TestFlight, dos cuentas de Yala distintas (A y B) y la misma build. App Attest está en `enforce`, así que nada de esto sale en simulador. **Antes de empezar:** `wrangler tail --env production` en una terminal; es la señal más barata para las filas de avisos.

**Tres avisos medidos que ahorran una tarde:**

- Si el banner no llega, **antes de sospechar del servidor** mira `Ajustes → Yala → Notificaciones` en
  el receptor: APNs devuelve 200 igualmente, y desde el servidor no se distingue.
- `PUSH_ROLE_JWT` estaba configurado en producción el 2026-09-03. Si el fan-out no sale, re-mídelo
  antes de descartarlo.
- El rate-limit de avisos de grupo es de **5 minutos por grupo** y persiste entre arranques: dos
  pruebas seguidas parecerán «no llegó». Espera entre intentos y anota las horas.

| Ticket | Qué preparar | PASS si… | Guion en el ticket |
|---|---|---|---|
| `aviso-de-nuevo-miembro-no-llega-hasta-abrir-la-app` | Admin con enlace; notificaciones de iOS y de Grupos encendidas | Con la app cerrada, al admin le llega «👋 Alguien quiere unirse a uno de tus grupos», sin duplicado al abrir; el aprobado también recibe aviso | §Acceptance Criteria L191 |
| `device-qa-groups-account-association` | Sesión privada; cuenta Google nueva; otro miembro real; iPad con el mismo Apple ID | Asociar enseña tu correo; desasociar conserva o quita; re-asociar no duplica; el iPad no la revive; el otro miembro conserva sus gastos | §Recorridos L23 (+ nota al final) |
| `groups-archived-group-rejects-join` | A dueño de un grupo con enlace; B con otra cuenta, no miembro | Con el grupo archivado, B ve «<grupo> fue archivado» con botón OK, no «Enlace no válido»; desarchivado, B entra como pendiente | §Lo que falta… L178 (+ corrección al final) |
| `groups-equal-split-shows-not-participating-on-peer` | B recién unido por enlace, sin relanzar la app antes del gasto | B, sin matar la app, ve su parte del gasto a medias que creó A; nunca «No participaste» | §Lo que falta… L332 |
| `groups-expense-notif-only-on-foreground` | Dos cuentas en un grupo; avisos de iOS en B; wrangler tail; Console.app | Con B fuera de la app, viva o cerrada, un gasto de A le llega como banner; A no recibe aviso; sin duplicados al entrar | §Cómo se verifica (device-QA, 2 devices…) L188 |
| `groups-invite-skips-unirme-sheet-if-onboarded` | B con onboarding hecho; enlace real de un grupo de A | La hoja sale con el nombre de B puesto; tras «Unirme», Perfil conserva nombre y divisa | §QA Visual · 2026-09-16 (al final) |
| `groups-leave-rpc-error-10` | Grupo sin deudas cuyo dueño entra desde un teléfono que no lo creó | Salir siendo dueño da un mensaje claro sin número de error, y después la pantalla ofrece «Eliminar grupo» | §Verificación L335 |
| `groups-owner-transfer-and-leave` | Dueño y otro miembro con cuenta; deuda pendiente | Con deuda, «Eliminar» sigue gris; «Transferir y salir» nombra al heredero; tras salir, el heredero renombra e invita | §Criterio de hecho (AC) L38 |
| `guest-decline-has-no-screen` | A admin con enlace; B otra cuenta, pendiente de aprobación | Tras el rechazo de A, B sigue viendo el grupo con el aviso de rechazo en vez de desaparecer; su botón lo quita del teléfono | §VERIFICADO DE PUNTA A PUNTA · 2026-09-03 (staging) L248 |
| `invite-backend-stale-config` | Enlace del admin; invitado con otra cuenta; build posterior a TestFlight 12 | Con la app abierta o en frío, tocar el enlace lleva a unirse al grupo, sin alerta de error ni silencio | §2026-08-17 — re-medición contra 2.0.5 L105 (casos 1, 2 y 4) |
| `invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo` | Invitado con Yala recién reinstalada, otra cuenta, red lenta; enlace del admin | Tocar el enlace nada más abrir lleva a unirse al grupo, sin «Hubo un problema con el grupo» | §Qué falta ver L239 |
| `rejected-member-cold-tap-does-nothing` | B rechazado sin quitar el grupo; app cerrada; enlace nuevo del admin | Con la app cerrada, B toca el enlace nuevo y al admin le llega su solicitud, una sola vez | §Lo que falta… L172 |
| `rejoin-tap-renotifies-admins` | A admin con avisos de Grupos; B otra cuenta con solicitud pendiente | B toca el enlace tres veces más y A recibe una sola notificación de solicitud en total | §Lo que falta L124 (punto 3) |

---

## Grupo 8 · Simulador con tu cuenta o el secreto de staging, a lo largo de un día (3)

**Montaje:** El simulador del Mac con lo que pide cada fila: tu cuenta real o `YALA_DEV_SHARED_SECRET`. Dos de ellas piden esperar 24 h, así que arráncalas un día y míralas al siguiente.

**Ojo:** `groups-phone-that-never-attests-is-told-to-retry-forever` deja staging un día en `enforce`,
y mientras dure falla cualquier otra cosa que hable con staging sin App Attest. Si no lo quieres, dilo
y se cierra como no replicable.

| Ticket | Qué preparar | PASS si… | Guion en el ticket |
|---|---|---|---|
| `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` | Simulador con YALA_DEV_SHARED_SECRET de staging (crear cuenta), sin él después; 24 h | Tras 24 h, «Cerrar sesión» dice «Este teléfono no puede sincronizar tus datos» con la cifra; exporta CSV y perderlos lleva al Welcome | §Device-QA — montaje sin verificar en esta sesión L130 |
| `groups-phone-that-never-attests-is-told-to-retry-forever` | simulador sin secreto, wrangler, cuenta de staging, staging en enforce >24 h | Pasadas 24 h, Grupos dice «Este teléfono no puede sincronizar tus grupos» y cerrar sesión ofrece perder los cambios | §QA · 2026-09-16 (al final) |
| `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` | Scheme Yala (producción) en simulador; cuenta real de Grupos; enlace de invitación | La sincronización no se para; al abrir el enlace sale «Está tardando un poco más de lo normal», nunca el inicio de sesión | §Device-QA — parcial L113 |

---

## Al terminar cada ticket

- **No inventes un PASS.** Si no se pudo comprobar, se dice qué faltó y se queda en `qa/`.
- **PASS** → `tickets/done/` con `qa-status: passed`, `qa-date`, una sección «QA Visual» y la evidencia.
  **FAIL** → `tickets/in-progress/` con `qa-status: failed` y lo que viste.
- Si no hay forma de montarlo ni en simulador ni en un aparato, se cierra con `qa-status: not-replicable`
  (override del owner, 2026-09-16). Si toda su prueba vive en otro ticket abierto, con `absorbed`.
- Actualiza `docs/TICKETS.md` (la fila y el conteo) y este guion. El índice se comprueba con un diff
  contra el disco, no a ojo.
- Si tocaste código para arreglar algo, `lastVerified` del área en `qa/coverage-index.json` va en el
  **mismo commit**.
