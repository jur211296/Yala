---
id: reverse-exit-on-a-reverted-account-rejects-the-retry
status: backlog
priority: medium
area: "modo-nube, migración, backend"
created: 2026-09-16
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

## Arreglos posibles

- **Backend:** que el claim fresco no resetee `reverted_at` cuando `kind <> 'complete'`, o que `reverse_abort`
  restaure el valor previo. DDL en staging y producción.
- **Cliente:** que un `.rejected` del claim tenga salida (el ticket hermano), para que al menos no se clave.

## Criterios de aceptación

- [ ] Medido contra la función viva: qué resetea el claim fresco y qué deja `reverse_abort`.
- [ ] Tras salir en el segundo dispositivo, reintentar «Volver a iCloud» avanza (o, como mínimo, dice por qué no).

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit` (D17) · `reverse-claim-rejection-has-no-way-out-in-the-client`.
