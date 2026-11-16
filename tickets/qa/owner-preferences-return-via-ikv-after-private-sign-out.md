---
id: owner-preferences-return-via-ikv-after-private-sign-out
status: qa
priority: medium
area: "settings, sync"
created: 2026-09-11
updated: 2026-11-05
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

## Resuelto en el lote N4 (2026-11-05, rama 2.3) — opción A

- El borrado del cierre de sesión arma `SignOutPreferenceHold`. En los TRES cierres (privado, solo grupos y nube), por
  decisión del bot dueño sobre la A: en los tres el teléfono vuelve a «recién instalado».
- Con la retención armada, en `.icloud` no se aplica el iCloud-KV del Apple ID, ni en el arranque ni en los cambios
  que llegan de otro dispositivo. Las señales de vaciado y onboarding se siguen leyendo.
- Se suelta: al abrir Restaurar (y aplica en el acto, para que el resumen tenga el nombre), al terminar cualquier
  onboarding (`signalOnboardingCompleted`), al nacer la sesión privada de «Activar Yala completo» y en `.cloud`.
- Tests: `SignOutPreferenceHoldTests` (marca y arm del hook en los dos modos, con control y aborto) y
  `SignOutPreferenceHoldWiringTests` (los dos aplicadores la miran; los cuatro puntos de suelta).

- Red: con el onboarding ya hecho la retención se suelta sola (`holdsAppleIDPreferences`), para los caminos que lo
  completan sin `signalOnboardingCompleted` (el adopt de una cuenta en la nube que sale antes de arrancar en `.cloud`).

### Residuales aceptados (review adversarial del lote)

- Retiene el ANTES del onboarding, como dice la A: terminado, lo que el onboarding no escribió (tema, Panel, avisos)
  puede llegar del Apple ID como siempre.
- Abrir Restaurar suelta aunque luego se vuelva atrás: Restaurar trae por diseño los datos del Apple ID.
- Con la retención puesta el Panel de quien entra no recibe los predeterminados (auto-sanado: todo visible); sembrarlos
  pisaría el Panel del dueño en sus otros dispositivos.

## Guion de QA (Jürgen, tu iPhone con iCloud activo y tu nombre puesto en Yala)

1. Ajustes de Yala → Cerrar sesión → confirma. Vuelves a la bienvenida.
2. Cierra Yala del todo y ábrela otra vez.
3. Elige «Es mi primera vez» y avanza: el nombre tiene que salir vacío y la moneda la de la región, no la tuya.
4. Sal sin terminar, vuelve a la bienvenida y elige «Restaurar desde iCloud»: tiene que traer tus datos y entrar con
   tu nombre.
