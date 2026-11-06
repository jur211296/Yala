---
id: language-override-bypasses-the-cloud-prefs-channel
status: qa
priority: medium
area: "modo-nube, settings, sync, l10n"
created: 2026-09-14
updated: 2026-11-05
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

Triage 2026-10-08: abierto · medium → medium · el setter de `LanguageManager.overrideLanguage` sigue escribiendo solo en el App Group y en `OwnerKeyValueStore` (`L10n.swift:69-88`), sin encolar; los comentarios «DARK» siguen en `PreferenceSyncService.swift:81` y `:147-149`.

## Resuelto en el lote N4 (2026-11-05, rama 2.3)

- `LanguageManager.overrideLanguage` (y el remap de alias) pasan por `PreferenceSyncService.syncLanguageOverride`: en
  `.icloud` escribe el iCloud-KV por la puerta, como antes; en `.cloud` encola en el outbox de preferencias («idioma del
  sistema» viaja como `""`, que el merge del otro dispositivo lee como quitar el override) y NO toca el iCloud-KV.
- Los dos comentarios «DARK» de `PreferenceSyncService` quedan al día.
- Población (pedía medirse antes de priorizar): no se re-midió; se hizo igual porque el lote lo encargaba.
- Tests: `LanguageOverrideCloudChannelTests` (las dos ramas con su control y el cableado de `L10n.swift`);
  `OwnerKeyValueWiringTests` saca `L10n.swift` de los usuarios de la puerta.

## Guion de QA (Jürgen, dos dispositivos con la misma cuenta de Yala en la nube)

1. En el primero: Ajustes de Yala → Personalización → Idioma → elige otro (por ejemplo, English).
2. En el segundo, abre Yala y espera un minuto con la app delante (o ciérrala y ábrela).
3. Lo que tiene que pasar: el segundo cambia al mismo idioma.
4. Vuelve en el primero a «Idioma del sistema»: el segundo vuelve también al del sistema.
