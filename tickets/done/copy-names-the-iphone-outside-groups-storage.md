---
id: copy-names-the-iphone-outside-groups-storage
status: done
priority: low
area: "copy, l10n, ipad"
created: 2026-10-24
updated: 2026-10-26
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

## Hecho (2026-10-26, card hxah)

- Eran **24** claves en español, no 23 (`pj22.language.inIOSFooter` también decía «Ajustes del iPhone»). En polaco el grep
  sin raíz no las veía: escribe «iPhonie» / «iPhone’a».
- «este iPhone», «tu iPhone», «otro iPhone» y «el modelo de tu iPhone» → «este dispositivo» y compañía, en los 16
  idiomas, con el término de i9r1 (de Gerät, fr appareil, nl apparaat, pl urządzenie, ja この端末, zh 这台设备).
- «Ajustes del iPhone» → «Ajustes» a secas, con el nombre de la app en cada idioma (pt-PT Definições).
- Fuera, a ticket propio: ~79 claves dicen «este teléfono» con el mismo fallo en el iPad
  (`copy-names-this-phone-outside-groups`).
