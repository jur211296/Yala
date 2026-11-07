---
id: siri-shortcuts-screen-says-pro-required-for-on-device-users
status: backlog
priority: medium
area: siri
created: 2026-11-07
updated: 2026-11-07
source: revisión por vistas 2.3, zona 38 (docs/ux/revision-vistas-2.3/38-bandeja-ia/, hallazgos secundarios)
---

# La pantalla «Siri y Atajos» dice «Requiere Yala Pro» a quien puede usar Siri gratis

Desde la decisión A del 2026-10-21 (`siri-free-users-on-device-model-awaits-decision`), «Anota un gasto en Yala» funciona sin
Pro en un iPhone con el modelo de Apple listo: `SiriOnDeviceEntry.isEnabled = true` y `SiriEntryRoute.decide` manda a
`.onDevice` (`Yala/App/Intents/SiriOnDeviceEntry.swift:30-33`, `:74`).

La pantalla de Ajustes › Siri y Atajos no lo sabe: enseña la insignia PRO y «Requiere Yala Pro» a todo el que no es Pro,
mirando solo `FeatureGateService.shared.isProUser` (`Yala/App/Views/Settings/SiriShortcutsView.swift:106` y `:121`).
Medido en el simulador (captura 80 de la revisión). Un usuario gratis con un iPhone 15 Pro o posterior lee que no puede usar
algo que sí puede.

## Qué hacer

Que la nota dependa de la misma decisión que el intent (`SiriEntryRoute.decide` con el estado del modelo): con el modelo
listo, sin insignia ni candado (o «Gratis en este iPhone»); sin él, como hoy. Copy nuevo: BRAND-VOICE.md.
