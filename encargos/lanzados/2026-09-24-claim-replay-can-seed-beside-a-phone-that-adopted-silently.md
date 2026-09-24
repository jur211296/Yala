# Dos teléfonos no pueden sembrar a la vez la misma cuenta de la nube tras un reintento

## Contexto
Acaba de mergear a `2.1` el PR #233 (`g16-01-is-not-applied-on-staging`): staging ya tiene la rama g16_01 de `claim_account` y los goldens del claim pasan contra staging (el 20 sigue en timeout, ticket propio). Antes, el #232 (`claim-promotion-lost-response-blocks-the-retry`) hizo que el reintento tras una respuesta perdida termine la activación cuando la cuenta no tiene escritura personal.

Residual de la review adversarial del #232 (lente servidor, medium): `tickets/backlog/claim-replay-can-seed-beside-a-phone-that-adopted-silently.md`.

AVISO del árbol principal: en `~/Yala` hay `docs/ESTADO.md` y `README.md` sin commit del cierre del #232 (aún dicen staging pendiente). No los toques en el árbol principal. En el cierre de ESTE PR, deja `docs/ESTADO.md` al día: sesión actual = #233 (g16 aplicada en staging + este ticket) y #232 como anterior; staging ya no pendiente.

## Que se pide
Ticket `claim-replay-can-seed-beside-a-phone-that-adopted-silently` → done (o qa solo si hace falta device-QA real).

Síntoma: A activa la nube, se corta la red al final; B entra con «Ya tengo cuenta» en la misma cuenta vacía y arranca de cero; A toca «Reintentar» y también siembra. Quedan dos juegos de cuentas/categorías. No se pierde nada; sobra.

Causa inferida (medir, no asumir): tras g16_01 el reintento de A recibe `created` si no hay fila en `sync_seq_counters`; el adopt de B no deja huella en el servidor hasta su primera subida.

1. Medir la ventana real: ¿el onboarding de B sube algo antes de terminar?
2. Opción robusta (preferida): que el adopt deje huella en el servidor (p. ej. un claim con `kind` que no promociona, o marca «adoptada por») y que la rama g16_01 la mire — no la salida más básica.
3. Criterios del ticket: con B ya dentro (adopt terminado), el reintento de A bloquea aunque B no haya subido nada; el reintento de A sin nadie más dentro sigue terminando.
4. Actualizar `docs/TICKETS.md`, board en disco, memoria/reglas si aplica. Gate + review. PR a `2.1`, merge y `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Bypass completo. Implementa, gate, commit, docs/board del repo (`docs/TICKETS.md` al día), merge y `/cerrar-total` sin preguntar si corres el gate o el commit. La regla «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda suspendida en esta cola: sigue hasta cerrar. Bugs o decisiones nuevas → ticket propio antes de cerrar. Solo para ante decisión/acceso real de Jürgen (device, secretos). Horario Lima nocturno (antes de 06:00): elige la opción robusta / good-practice sin AskUserQuestion; si es demasiado importante para asumir, aparca el ticket y avisa. De día (06:00–21:00): AskUserQuestion solo para producto/acceso real.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) necesitas decisión de producto o acceso de Jürgen; (2) abriste el PR o dejaste preview listo; (3) terminaste y vas a /cerrar-total — resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro (una vez). NO avises por test rojo que reclasificas, build a reintentar ni CI advisory.

## Que NO hay que tocar
- `marketing/` ni Web/
- No commits en el árbol principal sucio de Jürgen (ESTADO/README locales del #232)
- No paralelizar con otro ticket de cola A
- No redeploy del Worker salvo que el arreglo lo exija de verdad (y entonces dilo en el cierre)
- No inventar device-QA si el contrato queda cubierto por goldens/unit

## Como se sabe que esta bien
- Criterios del ticket cumplidos y medidos
- Ticket a `done` (o `qa` con guion si hace falta teléfono)
- `docs/TICKETS.md` coherente; ESTADO del PR refleja #233+#232+#este
- PR mergeado a `2.1` y `/cerrar-total` hecho

## Paso 0

Sesión nocturna (05:30 Lima): decisiones auto-contestadas con la opción robusta.

**Medido (1): la ventana.** El adopt de B **sí** llega al servidor antes de terminar, pero no deja huella. Todo adopt
—«Ya tengo cuenta» en la bienvenida y «Activar la nube en este dispositivo» en Almacenamiento— pasa por
`MigrationRunner.driveClaim` → `MigrationWorkExecutor.performClaim` → `POST /account/claim` con `migration: true` y el
`device_id` de B (es el 22 % de la barra). Sobre la cuenta que A promocionó (`complete`, líder A, sin migración) eso cae
en la rama final de `claim_account` y contesta `existing_stable` **sin escribir nada**. Lo mismo el alta born-cloud de B
(«Soy nuevo → nube», `migration: false`). La subida de B llega después, o nunca si B no crea nada.

**Decisiones:**

1. **Dónde queda la huella: en el claim de B, en el servidor.** Columna nueva `profiles.personal_adopted_at`; la estampa
   `claim_account` cuando un claim PERSONAL **con `migration`** (el del adopt) de un dispositivo que no es el líder
   recibe `existing_stable`. *Corregido tras la review:* la primera versión sellaba también sin `migration`, y un
   segundo teléfono que choca desde «Activar Yala completo» —se queda fuera— bloqueaba a los dos sobre una cuenta
   vacía. Toda entrada real acaba en el claim del adopt; «Soy nuevo → nube» también, tras su claim sin migración. La rama g16_01 exige además que esté vacía. Descartado: una llamada nueva «adopt terminado»
   desde el cliente — pide deploy del Worker y release de la app, y deja fuera a toda la flota actual; el claim ya
   llega antes de que el adopt termine, así que la huella queda antes de lo que pide el criterio 1.
2. **Solo claims personales.** Un claim `groups_only` de otro teléfono (unirse por Grupos) no entra en lo personal y no
   estampa: el reintento de A sigue terminando.
3. **Solo otro dispositivo.** El propio líder que pasa por el adopt (`migration: true` con su mismo `device_id`) no
   estampa: su reintento sigue siendo el mismo alta.
4. **La carrera del mismo instante se serializa.** La lectura que clasifica la fila pasa a `for update`: si el claim de
   B está en vuelo, el reintento de A espera y ve la huella; si A llega antes, B entra después sobre una cuenta que ya
   es de A, que es el caso de siempre.
5. **La huella no se borra.** Un B que entró y luego canceló deja la cuenta marcada: el reintento de A bloquea y A entra
   por el adopt a esa misma cuenta (vacía). Bloquear de más cuesta un adopt; sembrar de más, un corpus duplicado.
   Mismo criterio que g16_01 ya aplica a «otro teléfono con el alta en curso».
6. **Sin Worker, sin app.** La firma del RPC no cambia. El cliente solo cambia docblocks que describen el contrato del
   servidor (`BornCloudSignUpService`, `FullModeActivationFlowLogic`).
7. **Aplicación:** staging primero (el conector contesta hoy como `postgres`), después producción por `apply_migration`,
   con sandbox transaccional antes (función VIVA = control negativo, NUEVA y un mutante por término).
8. **Goldens:** el 28 fijaba el bug como contrato —paso 4 «otro dispositivo» y después paso 5 «el mismo repite →
   `created`»—. Se reordena (el reintento solo antes) y gana el paso del ticket: otro dispositivo entra y el reintento
   bloquea.
9. **Device-QA:** no hace falta. El contrato es del servidor y lo cubren la sonda del §3 y los goldens contra staging;
   ticket a `done`.
