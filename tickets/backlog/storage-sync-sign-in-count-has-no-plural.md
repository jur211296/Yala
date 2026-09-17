---
id: storage-sync-sign-in-count-has-no-plural
status: backlog
priority: low
area: "l10n, ajustes, modo-nube"
created: 2026-09-16
updated: 2026-09-16
source: "segunda review adversarial de `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-16)"
---

# «Inicia sesión para subir 1 cambios» sale sin plural

## El problema, en lenguaje de usuario

Tengo mis datos en la nube, mi sesión caducó y me queda un solo cambio por subir. Ajustes → «Dónde viven tus datos» me
dice «Inicia sesión para subir 1 cambios».

## Lo medido (leído en el código, sin ejecutar)

- `storage.sync.needsSignIn` es `"Inicia sesión para subir %d cambios"` en `Yala/Resources/es.lproj/Localizable.strings`
  y se pinta con `L10n.Storage.Sync.needsSignIn(_:)` (`String(format:)`), en `StorageSettingsView.syncStatusSection`.
- La clave no está en `Localizable.stringsdict` (que tiene otras reglas de plural), así que ningún idioma distingue uno de
  varios. Sin medir en los otros 15 idiomas cómo queda la frase con 1.

## Criterios de aceptación

- [ ] La clave pasa a `Localizable.stringsdict` con `one`/`other` en los 16 idiomas.
- [ ] La batería de paridad de `/l10n-check` sigue en verde.
