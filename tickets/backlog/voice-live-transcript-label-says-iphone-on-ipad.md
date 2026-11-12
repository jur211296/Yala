---
id: voice-live-transcript-label-says-iphone-on-ipad
status: backlog
priority: low
area: "copy, l10n, ipad, accesibilidad"
created: 2026-10-29
updated: 2026-10-29
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
