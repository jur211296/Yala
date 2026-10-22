---
id: account-deletion-leaves-attest-key-and-usage-counter-in-cloudflare
status: done
priority: high
area: "gateway, privacy, modo-nube"
created: 2026-10-15
updated: 2026-10-15
source: cierre del PR #469 (textos legales 2.1); card tablero-al-eliminar-una-cuenta-no-se-borran-la-c-3sge
---

# Al eliminar una cuenta no se borran la clave de App Attest ni el contador de uso en Cloudflare

## Qué le pasa al usuario

«Eliminar mi cuenta» borra la cuenta y sus datos en Supabase, pero en el gateway (Cloudflare) quedaban cosas. La
política promete el borrado de la cuenta y no decía qué se conserva ni por qué.

## Lo medido (2026-10-15, código del gateway en `2.1`)

- `attest_keys` de D1 va por keyId del **dispositivo** y no tiene columna de cuenta. El vínculo cuenta↔clave vivía en
  `attest_keys` de Supabase (`/attest/bind`), y ese ya lo borra `delete_personal_account`. La app no llama a
  `/attest/bind`.
- `account_entitlements` (D1, por cuenta) ya se borraba al eliminar la cuenta (C-8).
- Contadores (Durable Object `RateLimiter`): hay dos cubos. El de la **cuenta** (`sub:<sub>`), que usan las rutas
  `/account/*` en producción, **no se borraba**. El del **dispositivo** (keyId) guarda el cupo de prueba de la IA, que
  no se repone nunca.

## Qué se hizo

- `/account/delete` olvida también el contador de la cuenta (`forgetAccountQuota`, op `forget` del Durable Object),
  después del RPC y sin tumbar la respuesta, como el derecho Pro.
- La clave de App Attest y su contador se **conservan**: son del dispositivo, no llevan nada de la cuenta, el teléfono
  los sigue usando y el contador es el que limita las pruebas gratuitas de la IA (borrarlo lo repondría con cada alta y
  baja de cuenta). La política (6 idiomas, «Cuánto tiempo guardamos tus datos») lo dice ahora.
- Tests: `gateway/test/account.delete.test.ts` (qué se olvida, que el cubo es el mismo que cuenta `requireUser`, que
  nada toca `attest_keys`, que con el RPC fallido no se olvida nada). Dos mutantes muertos.
- Sin migración de D1. El despliegue del Worker está en `gateway/RUNBOOK.md`.
