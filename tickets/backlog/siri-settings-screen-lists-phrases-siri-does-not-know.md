---
id: siri-settings-screen-lists-phrases-siri-does-not-know
status: backlog
area: intents
priority: medium
created: 2026-10-13
updated: 2026-10-18
source: docs/ux/mapa-de-flujos-2.2.md (auditoría UX 2.2, fase 1)
---

# La pantalla «Siri y Atajos» enseña frases que Siri no reconoce

**Clase:** bug de copy. Lo revisa el lote 15 de la auditoría UX 2.2, y lo toca la card de Siri con IA de iOS 27.

## Qué pasa

La pantalla informativa de Ajustes › «Siri y Atajos» propone decir frases que no están registradas en
`AppShortcutsProvider`. Quien las dice no consigue nada.

## Medido en el código (2026-10-13, rama 2.2 @ e7e9feda8), en español

| Lo que la pantalla enseña (`es.lproj/Localizable.strings`) | ¿Está en `AppShortcutsProvider.swift`? |
|---|---|
| `siriShortcuts.siri.phrase` = «Crea un registro en Yala» | No |
| `siriShortcuts.siri.alt1` = «Anota un gasto en Yala» | Sí (`SiriNaturalEntryIntent`) |
| `siriShortcuts.siri.alt2` = «Guarda un gasto en Yala» | No |
| `siriShortcuts.phrase.automation` = «Registra desde automatización en Yala» | No (las de Apple Pay son «Registra Apple Pay en…») |
| `siriShortcuts.phrase.quick` / `.voice` / `.image` | Sí |

Los otros 15 idiomas no se midieron.

## Hecho cuando

Cada frase que enseña la pantalla, en los 16 idiomas, está en `AppShortcutsProvider`, con un test que lo cruce.

## Arreglado en español e inglés (lote 15 de la auditoría UX 2.2, 2026-10-15)

En `es`, `es-419`, `es-ES`, `es-AR`, `en` y `en-GB` la pantalla enseña solo frases registradas: la principal pasa a
«Anota un gasto en Yala» y las alternativas a «Apunta un gasto en Yala» y «Registra con Siri en Yala»
(«Note an expense / Log an expense / Record with Siri» en inglés). La fila «Automatización» se retiró en los 16 idiomas:
la acción no existe. Test: `YalaTests/ExternalEntriesLote15Tests.swift` (`SiriShortcutsScreenPhrasesTests`).

**Lo que queda abierto, y por eso el ticket sigue:** `AppShortcutsProvider` solo registra frases en español e inglés
(un array de Swift, sin `AppShortcuts.xcstrings`). En los otros 10 idiomas la pantalla enseña frases traducidas que Siri
no conoce **ninguna**. Es la mejora L15-3 del lote, con card para Jürgen: registrar las frases por idioma o decir en la
pantalla que Siri entiende español e inglés.

**Portugués arreglado (2026-10-18)**: `AppShortcuts.xcstrings` registra en pt, pt-BR y pt-PT las frases que enseña la
pantalla (medido en `root.ssu.yaml`, test `SiriPhrasesPortugueseTests`). Quedan 7 idiomas sin frases propias: alemán,
francés, italiano, japonés, neerlandés, polaco y chino (L15-5, pendiente de Jürgen).
