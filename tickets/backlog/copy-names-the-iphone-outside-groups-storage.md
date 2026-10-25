---
id: copy-names-the-iphone-outside-groups-storage
status: backlog
priority: low
area: "copy, l10n, ipad"
created: 2026-10-24
updated: 2026-10-24
source: "lote 12.1 Grupos (card i9r1), barrido del mismo patrón"
---

# Unos 20 textos dicen «este iPhone» y también salen en el iPad (y en el Mac)

## Qué ve el usuario

En un iPad, varias pantallas hablan de «este iPhone»: «iCloud no está activo en este iPhone», «Quitar mis datos de este
iPhone», «Este iPhone ya usó otra cuenta», «En este iPhone, Yala solo tiene tus grupos» (Siri), «Abrir Ajustes del
iPhone»…

## Lo medido (2026-10-24)

- La card i9r1 arregló las 9 claves de Grupos en «Dónde viven tus datos» (`storage.groups.*` y `groups.l19.detach.body`,
  «este dispositivo», 16 idiomas).
- Quedan **23 claves** en `es.lproj` con «iPhone» literal: `grep -n "iPhone" Yala/Resources/es.lproj/Localizable.strings`.
  Son de iCloud, borrado de datos, relanzamiento, Siri, la prueba de Pro, soporte y el Welcome.
- «Este dispositivo» ya es el término de la app (62 claves en español).

## Por dónde va

Dos clases distintas, y no se arreglan igual:

1. **«este iPhone» como sitio de los datos** → «este dispositivo», como en i9r1.
2. **«Ajustes del iPhone»** (abrir Ajustes, cancelar la prueba): en el iPad la app se llama igual («Ajustes»), así que
   basta «Ajustes» a secas. Decisión de copy de Jürgen.

Script de textos por JSON (molde del lote 12.1) y `LocalizationParityTests`.
