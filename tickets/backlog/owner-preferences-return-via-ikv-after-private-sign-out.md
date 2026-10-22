---
id: owner-preferences-return-via-ikv-after-private-sign-out
status: backlog
priority: medium
area: "settings, sync"
created: 2026-09-11
updated: 2026-10-08
source: "review adversarial del plan del paso 9 (`session-exits-one-verb-per-session`)"
---

# Tras cerrar una sesión privada, las preferencias del dueño vuelven por el iCloud KV

## El síntoma, en lenguaje de usuario

Cierro mi sesión privada para prestar el móvil. La otra persona entra y ve mi nombre y mi moneda.

## Lo medido (2026-09-11)

- El borrado de cierre (`performSignOutWipeIfArmed` → `DataWipeService.resetForSignOutWipe`) resetea las
  preferencias LOCALES.
- En `.icloud`, `PreferenceSyncService.bootstrap()` vuelve a aplicar las claves sincronizadas del iCloud KV
  del Apple ID —`userName`, `defaultCurrencyCode` y el resto del catálogo— en el arranque siguiente.
- El iCloud KV es del Apple ID, no de la persona: en el préstamo de móvil que el ADR 2026-09-09 hace
  normal, el Apple ID sigue siendo el del dueño.

## La decisión que falta (Jürgen)

¿El Welcome tras un cierre privado debe arrancar sin preferencias heredadas (no aplicar el iCloud KV hasta
que alguien restaure o haga el onboarding privado), o se acepta como semántica de la plataforma (el
teléfono es del Apple ID)?

## Medido en 2.1 (triage 2026-10-08)

- Sigue igual. `PreferenceSyncService.bootstrap()` (`:110-113`), con `storageMode == .icloud`, hace `iKV.synchronize()` y después `applyRemoteValues()` sobre las 37 keys. Tras un cierre privado el modo vuelve a `.icloud`, y nada condiciona ese apply.
- Agravante inferido, no medido: si la otra persona da de alta una cuenta en la nube, las preferencias del dueño ya están en local y se van con su outbox.

## Pregunta para Jürgen (triage 2026-10-08)

- **A** (recomendada): tras un cierre privado no se aplica el iCloud KV hasta que alguien restaure o termine el onboarding privado. Un flag local lo arma el borrado de cierre y lo retira la restauración.
- **B**: aceptarlo como semántica de la plataforma, porque el teléfono es del Apple ID. Se cierra el ticket.
- **C**: aplicar solo las preferencias de formato y no `userName` ni `defaultCurrencyCode`.

Con A, la prioridad es `medium`.

Triage 2026-10-08: abierto · medium → medium · `PreferenceSyncService.bootstrap()` (`:110-113`) sigue aplicando el iCloud KV del dueño tras un cierre privado; falta la decisión de producto.
