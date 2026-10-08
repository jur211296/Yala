---
id: groups-signout-reentry-banner-has-no-producer
status: backlog
priority: very-low
area: "groups"
created: 2026-09-11
updated: 2026-10-08
source: "paso 9 del rediseño de sesiones (`session-exits-one-verb-per-session`)"
---

# El aviso «Cerraste tu sesión de grupos» ya no tiene quién lo encienda

Desde el paso 9, cerrar una sesión solo-grupos lleva al Welcome en vez de a la pestaña de Grupos, así que
`CloudSessionSignOut` dejó de llamar a `GroupsSignOutBannerMarker.markPending()`: era su único productor.
El lector (`GroupsContainerView`, `showGroupsSignOutReentryBanner`) y sus strings siguen vivos y leen una
marca que nadie escribe; un dispositivo actualizado con la marca puesta la verá una vez.

## Qué hacer

Retirar la marca, el banner y sus strings, o reusarlo si algún cierre vuelve a aterrizar en Grupos.

## Medido en 2.1 (triage 2026-10-08)

- `GroupsSignOutBannerMarker.markPending` solo se llama desde `YalaTests/GroupsSignOutBannerMarkerTests.swift`; en `Yala/` no tiene productor. El lector (`GroupsContainerView`, `showGroupsSignOutReentryBanner`) y tres `clear()` siguen vivos.
- Es código muerto con un único efecto: un teléfono actualizado con la marca puesta ve el banner una vez.

Triage 2026-10-08: abierto · low → very-low · el banner sigue sin productor; es código muerto que retirar.
