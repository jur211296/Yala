---
id: siri-free-users-on-device-model-awaits-decision
status: backlog
priority: medium
area: siri
created: 2026-10-21
updated: 2026-10-21
source: auditoría UX 2.2 · lote 15 · L15-6 (decisión de Jürgen del 2026-10-18, el matiz) · card `tablero-ux-2-2-l15-6-sin-pro-siri-dice-activa-ya-2yze`
---

# «Anotar con Siri» para quien no tiene Pro, con el modelo del propio iPhone: ¿se enciende?

Jürgen eligió la opción B de L15-6 (sin Pro, Siri abre la hoja de Pro, hecho) con un matiz: que el usuario gratis pueda
usar IA «usando el propio modelo de Siri si lo tienen disponible, que no implica gastos para nosotros».

## Qué se midió (2026-10-21, SDK de iOS 27.1)

- `FoundationModels` (`SystemLanguageModel`, `LanguageModelSession`) existe desde iOS 26, el mínimo de Yala. Dice si el
  modelo está disponible en ESE aparato (Apple Intelligence encendido y descargado; iPhone 15 Pro o posterior) y genera
  una estructura tipada (`@Generable`).
- Es viable: está implementado en `Yala/App/Intents/SiriOnDeviceEntry.swift` y cableado en `SiriNaturalEntryIntent`
  (`SiriEntryRoute.decide`): sin Pro, con el interruptor encendido y el modelo disponible, Siri lee el dictado en el
  teléfono —sin servidor, sin coste y sin que el texto salga del iPhone— y deja el borrador en la Bandeja como con Pro.
- Va APAGADO (`SiriOnDeviceEntry.isEnabled` es `false` fuera de DEBUG). Encenderlo cambia lo que vive un usuario gratis:
  en vez de la hoja de Pro, un borrador. Por eso es una decisión.
- No medido: la calidad de la lectura del modelo del iPhone frente al del servidor, ni cuánto tarda dentro del tiempo que
  Siri da a un atajo. Pide un iPhone con Apple Intelligence (en DEBUG se enciende con la clave del App Group
  `debug.siriOnDeviceFreeEntry`).

## Qué hay que decidir

- **A · Encenderlo** para todos los que no tienen Pro y sí el modelo (los demás siguen viendo la hoja de Pro).
- **B · Dejarlo apagado** y retirar el código si no se va a usar.
- **C · Medirlo antes** en un iPhone con Apple Intelligence (calidad y tiempo) y decidir con el dato.

Recomendación: C, y si la lectura es razonable, A. Lo que se regala es la parte que no cuesta (la lectura local) y la
hoja de Pro sigue para quien no tiene el modelo.
