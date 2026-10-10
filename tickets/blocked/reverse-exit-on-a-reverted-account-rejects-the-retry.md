---
id: reverse-exit-on-a-reverted-account-rejects-the-retry
status: blocked
priority: high
area: "modo-nube, migración, backend"
created: 2026-09-16
updated: 2026-10-09
source: "review adversarial de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16), lente de datos — H1; decisión D17 (b) de Jürgen: ticket aparte"
---

# En el segundo dispositivo de una cuenta que ya volvió a iCloud, salir de la espera cierra la puerta a reintentar

## El problema, en lenguaje de usuario

Tengo Yala en dos iPhone con la misma cuenta en la nube. En el primero vuelvo a iCloud y termina bien. En el
segundo pulso «Volver a iCloud», la subida no avanza y salgo (cancelo, o salta el techo). Sigo en la nube.
Cuando lo intento otra vez, la barra se queda en el 15 % y no pasa nada.

## Por qué pasa (contrato del backend, `qa/cloud/README.md`; el SQL no está en el repo)

1. El primer dispositivo completa: `reverse_complete` degrada la cuenta a `kind='groups_only'` y pone
   `reverted_at`. El backend sigue congelado.
2. El segundo pide `reverse_claim`. Entra por la mitad `reverted_at` del guard de `g15_02` y, como es un claim
   FRESCO, **resetea `reverse_frozen_at` y `reverted_at`** del run anterior.
3. Sale de `reverseUpload`: `reverse_abort` deja `rip=false`, `reverse_frozen_at=null` y **`reverted_at` sigue
   nulo**. La cuenta queda `groups_only` sin `reverted_at`.
4. Al reintentar, el guard (`kind='complete'` **o** `reverted_at` no nulo) responde `not_complete`, y el cliente no
   tiene salida para un rechazo: `reverse-claim-rejection-has-no-way-out-in-the-client`.

Antes de la salida de `reverseUpload` ya se llegaba al mismo estado por un aborto PRE-montaje (tope de mismatch o
de red del verify), pero la salida lo hace mucho más alcanzable.

## Qué no se midió

La semántica del RPC sale del README y del golden 17 (`gateway/test/account.goldens.test.ts`). El 2026-09-16
staging no respondía ni a `select 1` desde el conector, así que no se leyó `pg_get_functiondef`. Primero, medirlo.

## Medido el 2026-09-16 (sesión de `reverse-claim-rejection-has-no-way-out-in-the-client`)

Se leyó el cuerpo vivo de `migration_progress` en **producción** (solo lectura; md5 `14fc5e2c…`, el final de `g15_02`).
Confirma los pasos 2 y 3 de arriba: el claim fresco pone `reverse_frozen_at = null` y `reverted_at = null`, y
`reverse_abort` no toca `reverted_at`. Staging no se midió.

**Y hay un segundo camino al mismo `not_complete`, sin salir de ninguna espera.** En la cuenta ya revertida, un claim
fresco con ÉXITO cuya respuesta se pierde (el cliente lo lee como `.transient`) deja `reverse_in_progress = true` con este
dispositivo como líder y `reverted_at` ya a null. El reintento choca con el guard de `kind`/`reverted_at` **antes** de
llegar a la rama del re-claim idempotente del mismo líder, así que recibe `not_complete`. Desde ese ticket el cliente sale
a la nube con una nota y sin `reverse_abort` (el rechazo no reservó nada), así que la reserva de este dispositivo queda
puesta hasta que alguien la aborte o la usurpe. No congela nada: el 409 de `/sync/push` solo mira `reverse_frozen_at`.

**Y un tercero, que no deja nada roto pero dice algo falso** (lente de backend de la misma review). Con tres dispositivos:
A completa su vuelta; B empieza la suya (claim fresco: `reverted_at` a null) y sube durante horas; C toca «Volver a iCloud»
en ese rato. El guard de `kind`/`reverted_at` va **antes** de mirar líder y lease, así que C recibe `not_complete` en vez de
`other_leader`, y la app le dice que su cuenta no lo permitía y que escriba a soporte. Cuando B hace `reverse_complete`,
`reverted_at` vuelve y el reintento de C pasa.

En el segundo camino, además, la nota del cliente se queda corta: dice «Ese intento no cambió nada», y lo que ve la persona como un solo intento —el toque sin red y el reintento— sí dejó la reserva de este dispositivo puesta y `reverted_at` a null. Sus datos no cambiaron; el backend, sí.

Los tres caminos tienen la misma raíz, el reset de `reverted_at` en el claim fresco, y el arreglo de backend de abajo cierra
los tres. Otra opción que cierra solo el segundo y el tercero: evaluar reserva, líder y lease antes del guard.

## Arreglos posibles

- **Backend:** que el claim fresco no resetee `reverted_at` cuando `kind <> 'complete'`, o que `reverse_abort`
  restaure el valor previo. DDL en staging y producción.
- **Cliente:** que un `.rejected` del claim tenga salida (el ticket hermano), para que al menos no se clave. **Hecho el
  2026-09-16**: vuelve a la nube y dice «tu cuenta no lo permitía» con el correo de soporte. El canario
  `cloudReverseClaimRejected` con detalle `not_complete` cuenta cuántos teléfonos caen aquí.

## Criterios de aceptación

- [ ] Medido contra la función viva: qué resetea el claim fresco y qué deja `reverse_abort`.
- [ ] Tras salir en el segundo dispositivo, reintentar «Volver a iCloud» avanza (o, como mínimo, dice por qué no).

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit` (D17) · `reverse-claim-rejection-has-no-way-out-in-the-client`.

## Medido en 2.1 (triage 2026-10-08)

- Backend: ningún SQL posterior a `g15_02` (último commit `8dcc15d31`, 10-sep) cambia `reverse_claim` ni `reverse_abort`.
  Los `g16_*` son de la ida.
- Cliente: el rechazo tiene salida a soporte desde `13a20e6fb`. El canario `cloudReverseClaimRejected` (`MetricsService.swift:683`)
  cuenta los `not_complete`.
- `high`: el segundo camino, un claim con éxito cuya respuesta se pierde, solo necesita mala red. Deja a la persona sin poder
  volver a iCloud en ese dispositivo, y su única salida es escribir a soporte.

Triage 2026-10-08: abierto · medium → high · El arreglo es de backend y no existe: ningún SQL posterior a g15_02 (10-sep) cambia el reset de reverted_at en el claim fresco; el cliente solo tiene la salida a soporte de 13a20e6fb.

## Preparado el 2026-10-09 — bloqueado en el deploy (falta una credencial)

**Qué espera:** que alguien con acceso de escritura a las bases de Supabase aplique `qa/cloud/g17_01_reverse_claim_keeps_reverted_at.sql`
en staging y luego en producción, con los pasos de `docs/RUNBOOK-staging-ddl.md` § `g17_01`. La sesión no tenía cómo: el
token de gestión (`~/Secrets/yala-supabase-mgmt/pat`) da 401 en los dos proyectos, el conector de Supabase pedía OAuth y no
hay URI de base en `~/Secrets`. Deploy autorizado por Jürgen el 2026-10-09 14:01.

**Medido contra la función viva de staging, sin tocarla** (golden 16-ter, `gateway/test/account.goldens.test.ts`): tras el
claim del 2.º dispositivo sobre una cuenta ya revertida, `reverted_at` queda a null, y el 3.er dispositivo, el re-claim del
mismo y el reintento tras salir reciben `not_complete`. Los tres caminos del ticket, reproducidos. No se leyó
`pg_get_functiondef` (sin acceso de lectura a funciones): es el paso 1 del RUNBOOK.

**El arreglo** (`g17_01`): cada `reverted_at = null` de `migration_progress` (exactamente 3: claim fresco y dos takeovers)
pasa a `case when kind = 'complete' then null else reverted_at end`. Igual que hoy en una cuenta `complete` (golden 17);
conservado en una `groups_only`. El §1-bis repara las cuentas que el bug ya atascó (`groups_only` + `personal_claimed_at`
+ sin `reverted_at`). Sin cambio de Worker ni de app: mismos códigos y forma de respuesta (lo fija el 16-ter).
Marcha atrás: `qa/cloud/g17_01_rollback.sql`.

**Probado:** banco local `bash qa/cloud/g17_01-local-test.sh` (Postgres 17, réplica del RPC desde el contrato): el §3 falla
con el cuerpo viejo en los cuatro caminos y pasa 11/11 con el nuevo; reparación, rollback, re-aplicación no-op y guardas
(cuerpo divergido, cuarta escritura) en verde; cuatro mutantes muertos. Review adversarial de dos lentes: ningún
consumidor (SQL, Worker, app) lee el valor de `reverted_at`; de ella salieron la reparación de los ya atascados, el número
fijado a 3 y la comprobación de atributos de la función.

**Primer intento en staging (2026-10-09 18:4x, Frank desde el box): abortó sin tocar nada.** La guarda buscaba el
literal `reverted_at = null` con un espacio y el cuerpo vivo (md5 `14fc5e2c…`, igual en producción) alinea las tres
escrituras con 10-11 espacios. Corregido en el encargo `g17-01-guard-matches-any-spacing`: cuenta y sustituye por patrón
conservando el espaciado, sigue exigiendo 3, y el banco corre ahora contra el cuerpo real (fixture en
`qa/cloud/fixtures/`), con el §3 11/11. **md5 nuevo esperado: `776dac35d585393fabeabedf8eafee82`.**

**Cuando se aplique**, cierra el criterio: goldens `-t "I11-3"` 11/11 con el 16-ter verde, el canario
`cloudReverseClaimRejected|not_complete` a cero, y los cinco textos del cliente y de las reglas que describen el reset
(lista en el RUNBOOK). Después, el device-QA:

### Guion de device-QA (dos iPhone, misma cuenta en la nube)

1. En los dos iPhone, Yala con la misma cuenta en la nube (Ajustes → «Dónde viven tus datos» dice «En la nube»).
2. En el iPhone 1: «Dónde viven tus datos» → «Volver a iCloud» y espera a que termine («En iCloud»).
3. En el iPhone 2: «Dónde viven tus datos» → «Volver a iCloud». Cuando la barra esté en la espera de subida, toca
   «Cancelar y seguir en la nube» y confirma. Esperado: vuelve a «En la nube».
4. En el iPhone 2, otra vez «Volver a iCloud». Esperado: la barra avanza; **no** sale «tu cuenta no lo permitía» ni el
   correo de soporte.
5. (Opcional, con un tercer dispositivo) mientras el 2 sube, toca «Volver a iCloud» en el 3. Esperado: el aviso de que otro
   dispositivo está volviendo, no «tu cuenta no lo permitía».
