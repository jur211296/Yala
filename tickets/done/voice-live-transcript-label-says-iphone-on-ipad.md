---
id: voice-live-transcript-label-says-iphone-on-ipad
status: qa
priority: low
area: "copy, l10n, ipad, accesibilidad"
created: 2026-10-29
updated: 2026-11-06
source: "medido al cerrar copy-names-this-phone-outside-groups"
---

# VoiceOver lee «Lo que va entendiendo el iPhone» también en el iPad

## Qué ve el usuario

Con VoiceOver, al dictar una nota de voz, la transcripción en vivo se anuncia como «Lo que va entendiendo el iPhone»
(«What your iPhone is picking up», «Was das iPhone gerade versteht»…). En un iPad es falso.

## Lo medido (2026-10-29)

- Una sola clave, `voice.live.transcriptAccessibility` (`L10n.swift`), en los 16 idiomas dice «iPhone».
- Quedó fuera de #644 («este iPhone») y de copy-names-this-phone-outside-groups («este teléfono»): no usa ninguna de
  las dos expresiones, así que la guarda de `LocalizationParityTests` no la ve.

## Por dónde va

«Lo que va entendiendo el dispositivo», o sin sujeto («Lo que se va entendiendo»), en los 16 idiomas.

## Arreglo (2026-11-06)

`voice.live.transcriptAccessibility` dice «el dispositivo» en los 16 idiomas, con el término de cada uno (Gerät,
appareil, apparaat, urządzenie, 端末, 设备…): «Lo que va entendiendo el dispositivo», «What your device is picking up».
Lo fija `LocalizationParityTests.liveTranscriptLabel_namesNoDeviceModel` (ningún idioma nombra iPhone ni iPad en esa
clave). La guarda general de «teléfono» no la veía porque no usa esa palabra.

## QA

Simulador, sin el iPhone: grabar una nota de voz y leer con `axe describe-ui` la etiqueta de la transcripción en vivo.
