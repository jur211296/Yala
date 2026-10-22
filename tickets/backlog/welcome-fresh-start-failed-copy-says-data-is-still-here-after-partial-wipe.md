---
id: welcome-fresh-start-failed-copy-says-data-is-still-here-after-partial-wipe
status: backlog
priority: low
area: "onboarding, groups, l10n"
created: 2026-10-01
updated: 2026-10-08
source: "review adversarial de `groups-purge-save-crosses-two-stores-without-atomicity` (lente de consumidores); anterior a ese cambio"
---

# El aviso de fallo de «Empiezo de cero» dice «Tus datos siguen aquí» cuando parte ya se borró

## El problema, en lenguaje de usuario

Elijo «Empiezo de cero» y algo falla. El aviso dice «Tus datos siguen aquí, así que no seguimos adelante». Pero
mis movimientos y cuentas ya se borraron: el fallo llegó después.

## Lo medido (leyendo el código, 2026-10-01)

En los tres llamadores de «Empiezo de cero» (`ContentView` ~2105 y ~2225, `ShellDataAlertsModifier.performFreshStartWipe`)
`DataWipeService.wipeAllUserData` corre ANTES de `wipeLocalGroupsDomain`. Si el segundo lanza, lo personal ya no
está. El alert de `ShellDataAlertsModifier` usa `welcome.freshStart.failedMessage` (es: «Tus datos siguen aquí…»),
que en ese caso es falso. La puerta del teléfono usa `wipeDeviceFailedBody` («Puede que parte de tus datos ya no
esté»), que sí es verdad.

No lo introdujo `groups-purge-save-crosses-two-stores-without-atomicity`: ya pasaba con el `save()` único.

## Qué haría falta

Que ese alert diga lo mismo que la puerta del teléfono cuando el fallo llega después de `wipeAllUserData`, o
separar el texto por dónde falló. Los 16 idiomas y `BRAND-VOICE.md`.

## Medido en 2.1 (triage 2026-10-08)

- `ShellDataAlertsModifier.performFreshStartWipe`: `wipeAllUserData` sigue antes de `wipeLocalGroupsDomain`, y el `catch` genérico abre el aviso con `welcome.freshStart.failedMessage` («Tus datos siguen aquí…», `es.lproj`:5460).
- Se queda en `low`: hace falta que el segundo borrado lance después del primero (un fallo de guardado), y lo que el aviso dice que sigue es lo que la persona pidió borrar.

Triage 2026-10-08: abierto · low → low · el texto sigue siendo falso en ese fallo, pero requiere que el segundo borrado lance tras el primero.
