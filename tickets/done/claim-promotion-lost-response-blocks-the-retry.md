---
id: claim-promotion-lost-response-blocks-the-retry
status: done
priority: medium
area: "modo-nube, groups"
created: 2026-09-11
updated: 2026-09-24
source: "review adversarial del paso 8 del rediseño de sesiones (`full-mode-activation-must-ask-where-personal-data-lives`)"
---

# Si se pierde la respuesta de la promoción, «Reintentar» bloquea la activación a la nube

## El síntoma, en lenguaje de usuario

Uso Yala solo para grupos y activo Yala completo → «Tu cuenta en la nube». Hago el onboarding, contesto la
pregunta del historial y sale «Activando tu cuenta…». Se corta la red justo ahí: «No hemos podido activar tu
cuenta». Toco «Reintentar» y me dice «Tu cuenta ya tiene finanzas personales». No las tiene: la promoción
llegó al servidor y la respuesta no llegó al teléfono. Desde aquí ya no puedo activar la nube.

## Por qué pasa (medido el 2026-09-11)

- La promoción es `POST /account/claim` (`BornCloudSignUpService.signUp`). Con la fila ligera de grupos
  (`personal_claimed_at` nulo) contesta `created` y la marca como completa; con esa fecha ya puesta contesta
  `existing_stable` (`qa/cloud/g15_01_account_kind.sql`).
- Un fallo de red DESPUÉS de que el servidor confirme se ve en el cliente como `.transient` → «Reintentar».
  El reintento encuentra la fecha puesta → `existing_stable` → la activación lo trata como una cuenta que ya
  tiene lo personal (`FullModeActivationFlowLogic.promotionStep`) y bloquea sin escribir nada.
- Lo mismo deja un kill entre la promoción y la primera escritura local, que son dos llamadas síncronas
  seguidas: la cuenta queda completa en el servidor sin nada personal detrás.

Es seguro —no se escribe ni se pierde nada—, pero la única salida que le queda (cerrar sesión y volver a
entrar) le lleva a una cuenta completa VACÍA en la nube.

## Alcance

- Distinguir «la acabo de promocionar yo y no tiene nada» de «ya tenía lo personal»: que el claim diga si la
  cuenta tiene filas personales, o un token de idempotencia por intento de activación.
- Con esa señal, el reintento sigue con el commit (almacenamiento nube → persistir [P]) en vez de bloquear.

## Criterios de aceptación

- [x] Promoción confirmada en el servidor + respuesta perdida → «Reintentar» termina la activación.
- [x] Una cuenta que de verdad tiene lo personal reclamado (desde otro dispositivo) sigue bloqueando sin
      escribir nada.

## Paso 0 (2026-09-24, MODO AUTÓNOMO, noche — decisiones auto-contestadas)

**D1 · ¿Dónde se distingue «la acabo de promocionar yo» de «ya tenía lo personal»? En el servidor.** El
cliente no puede: tras una respuesta perdida solo ve `existing_stable`, y cualquier heurística local
(«yo mandé una promoción») se equivoca si la petición perdida no llegó y OTRO dispositivo promocionó
entretanto — sembraría encima de su alta en curso, que es la fusión que el ADR prohíbe.

**D2 · La señal: identidad del dispositivo + «la cuenta nunca recibió una escritura personal». No un
token nuevo por intento.** Medido en producción (`md5 8668a13c…`, idéntico en staging según g15_01):

- La promoción ya estampa `leader_device_id = p_device_id`, y el contrato del cliente ya dice que «el
  re-claim del MISMO device colapsa a `created`» (`BornCloudSignUpOutcome.transient`). El servidor solo lo
  cumplía con una migración en curso (`v_mip`). El `device_id` ES la clave de idempotencia que el
  protocolo ya definió; un token nuevo duplicaría esa clave y obligaría a desplegar el Worker (decisión de
  Jürgen, y el Worker es un passthrough que hoy no reenvía nada más).
- «Nunca recibió una escritura personal» = **no hay fila en `sync_seq_counters`**. La crea el trigger
  `stamp_server_seq`, que está en las **17** tablas del canal personal (las 16 de dominio y
  `user_preferences`; medido). Es mejor señal que 16 `exists`: sobrevive a borrados, cubre las
  preferencias, y una tabla futura la hereda porque `server_seq` es el cursor del pull. RLS deja al dueño
  leer su fila (`seq_select`, medido), y el RPC es `SECURITY INVOKER`.
- Por qué el vacío es imprescindible además del dispositivo: el mismo teléfono pudo tener esa cuenta
  completa CON datos hace meses (alta born-cloud, cerrar sesión, volver solo por grupos). Sin la segunda
  mitad, el reintento sembraría un segundo corpus encima.

**D3 · La rama nueva, y cada término con el escenario que lo justifica** (sin términos que no protejan
nada): `not p_migration` (una migración con `created` conduciría una máquina sin lease), `v_leader =
p_device_id` (otro dispositivo), `v_kind = 'complete'` (una cuenta que volvió a iCloud no se promociona
aquí), `not v_reverse` (una vuelta a iCloud en curso congela el backend), y el contador. Se descartan
`migrated_at is null` y `reverted_at is null` (razonado, no medido): una cuenta migrada o revertida que
tenga datos ya la para el contador, y una migrada VACÍA del mismo teléfono es justo la que se puede sembrar
sin fusionar nada. Añadirlos daría términos cuyo mutante no muere.

**D4 · Arregla también al gemelo del Welcome.** El alta born-cloud («Soy nuevo → nube») con la respuesta
del INSERT perdida recibía `existing_stable` y adoptaba una cuenta vacía sin sembrar. Mismo claim, misma
rama: ahora el reintento siembra. Se cuenta, no se esconde.

**D5 · Y el kill entre la promoción y la primera escritura local**: el intento siguiente desde el mismo
teléfono encuentra la cuenta vacía y sigue. Un kill DESPUÉS de que el motor suba algo (preferencias,
el bridge) sigue bloqueando, como hoy: es seguro, y que re-ejecutar el commit local sea idempotente no está medido.

**D6 · Despliegue: solo SQL** (`qa/cloud/g16_01_claim_replays_for_the_same_device.sql`), staging antes
que producción, con guarda de md5 de partida y sonda de conducta dentro. **Sin deploy del Worker**: la
firma del RPC no cambia. **Sin cambio de comportamiento en el cliente**: `.seeded` ya lleva al commit;
se corrigen los docblocks que describían el bug.

**D7 · Tests**: la conducta vive en el servidor, así que la red es la sonda ejecutable de la migración
(corre en cada aplicación, aborta si falla) con control negativo contra la función viva y mutantes de
cada término, más los goldens del gateway contra staging. El golden 1 cambia: dos claims concurrentes
del MISMO dispositivo sobre una cuenta vacía son ahora los dos `created`; la exclusión mutua se prueba
con dos dispositivos.

**D8 · Device-QA**: no se monta a voluntad (hay que perder una respuesta HTTP concreta) y el cliente no
cambia de comportamiento ⇒ el ticket va a `done`, no a `qa`.

## Cierre (2026-09-24)

**Qué cambia para el usuario.** Si al activar Yala completo → «Tu cuenta en la nube» se pierde la respuesta del
servidor, «Reintentar» termina la activación en vez de decir «Tu cuenta ya tiene finanzas personales». Lo mismo
en la bienvenida: el alta en la nube cuya respuesta se perdió siembra al reintentar en vez de adoptar una cuenta
vacía. Y un kill entre la promoción y la primera escritura deja de ser un callejón. Una cuenta con algo personal
escrito, o promocionada por otro teléfono, sigue bloqueando sin escribir nada.

**Cómo.** Una rama nueva en `claim_account` (`qa/cloud/g16_01_claim_replays_for_the_same_device.sql`),
**aplicada en producción** (md5 `e7f8bec957091abaa126d8100a3a53bd`; producción tiene hoy 0 cuentas). **Staging
pendiente**: el conector MCP no contestó en toda la sesión → `g16-01-is-not-applied-on-staging`. Sin deploy del
Worker y sin cambio de comportamiento en el cliente (solo docblocks).

**Verificado.**
- Banco transaccional contra el motor de producción: la función viva falla los 3 escenarios de respuesta
  perdida (el bug, medido) y la nueva pasa los 12; cada uno de los 5 mutantes (un término quitado) muere en
  su escenario. Tras la review, el fichero final pasa 13/13 y el control negativo de la cobertura del trigger
  falla como debe.
- Goldens del gateway contra staging: 31 verdes, 3 en skip por estado previo (1, 2, 28), 1 rojo por timeout
  del pull (`corpus-de-test-de-staging-crece-sin-limite`, ajeno). El g3_02 comprueba ya por el wire que RLS
  deja al dueño leer su contador.
- Gate: builds de las dos schemes, 807 unit en 69 suites, 20 XCUITest en 6 suites (centinela limpio).

**Sin device-QA**: el camino exige perder una respuesta HTTP concreta y el cliente no cambia.

**Review adversarial** (2 lentes, servidor y consumidores). Sin bloqueantes. Arreglado en el acto: guarda por md5
final, atributos de la función y cobertura del trigger en el §2, sonda con la cuenta sin líder. A tickets:
`claim-replay-can-seed-beside-a-phone-that-adopted-silently` (medium),
`claim-replay-after-a-kill-mid-commit-can-duplicate-the-onboarding`,
`lost-cloud-signup-then-private-leaves-migrate-blocked` y
`welcome-cloud-replay-marks-born-cloud-without-the-guard` (low).
