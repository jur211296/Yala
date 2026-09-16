---
id: reverse-exit-on-a-reverted-account-rejects-the-retry
status: backlog
priority: medium
area: "modo-nube, migración, backend"
created: 2026-09-16
updated: 2026-09-16
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
