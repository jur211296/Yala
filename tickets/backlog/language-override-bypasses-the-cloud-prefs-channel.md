---
id: language-override-bypasses-the-cloud-prefs-channel
status: backlog
priority: medium
area: "modo-nube, settings, sync, l10n"
created: 2026-09-14
source: "medido al reponer el guard del iCloud-KV (`icloud-kv-prefs-cross-sessions-on-a-lent-phone`), celda E"
---

# En una cuenta en la nube, el idioma no viaja por la nube: va al iCloud del teléfono

## El síntoma, en lenguaje de usuario

Tengo mi cuenta de Yala en la nube y cambio el idioma de la app. **Mis otros dispositivos no se enteran.**
Y si el móvil es prestado, **el idioma se lo cambio al dueño** en todos sus dispositivos.

## Lo medido (2026-09-14, árbol `f548ac94`)

- `LanguageManager.overrideLanguage` (`Yala/Utils/L10n.swift`) escribe el App Group y **directo al
  iCloud-KV** por `OwnerKeyValueStore`. No pasa por `PreferenceSyncService.set`, así que **nunca encola** en
  el outbox de preferencias: los únicos `enqueue` son los de `set`/`remove` y el drenaje único del cutover.
- En `.cloud`, `PreferenceSyncService` no aplica el iCloud-KV; aplica lo que baja el backend
  (`applyPulledPrefs`, que sí sabe aplicar `appLanguageOverride`). Pero el backend solo tiene el idioma que
  el drenaje subió en la migración, y en una cuenta nacida en la nube, ninguno.
- **El comentario que lo daba por inofensivo caducó.** `PreferenceSyncService.swift` dice «su migración a
  `.cloud` es DIFERIDA … DARK, sin efecto hoy». `gateway/wrangler.toml` sirve en producción
  `CLOUD_MODE_ROLLOUT_PERCENT = "100"` y `CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT = "100"`: el camino existe
  en todo build que lo traiga. Su gemelo, en el mismo fichero (el docblock de `prefsOutbox`, ~línea 81), dice
  lo mismo con otras palabras: «DARK: `CloudSyncFlags.storageMode` es SIEMPRE `.icloud` hoy».
- **Y la puerta del iCloud-KV no lo para en un móvil prestado.** Una sesión en la nube completa tiene el eje
  1 en `true` —adoptar una cuenta y terminar el alta personal lo encienden—, así que `OwnerKeyValueGate` está
  abierta para ella, a propósito: el faro y el cutover tienen que escribir ahí desde esa sesión en el
  teléfono propio.

## Población (no re-medida aquí)

El censo del 2026-09-14 (ticket `remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark`)
contó en la telemetría de producción de 90 días **5 altas personales y 1 migración a la nube**, y nada más.
Si una cuenta nacida en la nube emite ese mismo evento no se comprobó al escribir este ticket: mídelo antes
de priorizar.

## Criterios de aceptación

- [ ] En `.cloud`, cambiar el idioma lo encola en el outbox de preferencias y llega a los otros dispositivos
      de la cuenta.
- [ ] En `.cloud`, cambiar el idioma no escribe el iCloud-KV del Apple ID.
- [ ] Los dos comentarios de `PreferenceSyncService` que dan `.cloud` por apagado quedan al día.
