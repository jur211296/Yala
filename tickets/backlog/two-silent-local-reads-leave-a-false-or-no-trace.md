---
id: two-silent-local-reads-leave-a-false-or-no-trace
status: backlog
priority: low
area: "modo-nube, grupos"
created: 2026-09-23
updated: 2026-09-23
source: "barrido del patrón durante `an-incomplete-inventory-reads-as-the-whole-corpus` (2026-09-23)"
---

# Lecturas locales que fallan en silencio y dejan un diagnóstico falso o ninguno

## El problema, en lenguaje de usuario

Nada que se vea en la pantalla: ninguna de las dos decide mal con tus datos. Lo que falla es el rastro. Cuando algo
va mal en un teléfono, estas lecturas no dicen «no pude leer»: una dice algo falso y la otra no dice nada, y quien
diagnostique la avería mira en el sitio equivocado.

## Por qué pasa (leído el 2026-09-23 en este árbol; no ejecutado; tres filas añadidas por la review)

| Sitio | Qué hace con la lectura fallida | Qué rastro deja |
|---|---|---|
| `MigrationWorkExecutor.runAdoptFlow`, paso 4 (el «belt» del marcador) | `(try? context.fetchCount(…CloudMigrationMarker…)) ?? 0` | `migrationEffectFailed(… "marker absent (belt)")`: dice que el marcador del líder no llegó, cuando no se pudo mirar |
| `GroupsSyncClient.rehydrateOutboxFromMirror` | sale con `return` sin re-insertar (correcto: sin saber qué hay vivo, re-insertar duplicaría) | un `logger.error` dentro de `#if DEBUG`: en producción, nada |
| `MigrationWorkExecutor.verifyRebinds` | devuelve `0` | `reverseRebindsVerified` dice «0 re-enlazadas» cuando no se pudo mirar; la fase avanza igual |
| `MigrationWorkExecutor.collectReverseUploadPairs`, fetch de testigos `SyncIdentity` | se tolera a propósito: todas las filas van con testigo scratch | un `print` de `#if DEBUG`: en producción, nada |
| `CloudSyncDebugView` (panel DEBUG), diff de huérfanas del adopt | `adoptOrphanDryRun` devuelve `nil` también con el inventario local ilegible | el panel pinta «red caída al enumerar el backend» |

El primero además es un `try?` que silencia, que las reglas del repo prohíben. El gemelo personal del segundo
(`CloudSyncEngine.rehydrateOutboxFromMirror`) ya deja `outboxFetchFailed(step: "rehydrate-mirror")` desde
`an-incomplete-inventory-reads-as-the-whole-corpus`.

## Criterios de aceptación

- [ ] El belt del marcador distingue «no está» de «no pude leer», con rastro propio para lo segundo.
- [ ] El rehydrate de Grupos deja rastro en producción cuando su fetch falla.
- [ ] `verifyRebinds`, el fetch tolerado de testigos y el panel DEBUG dicen «no pude leer» cuando es eso.
- [ ] Ninguno cambia lo que se decide: el belt sigue sin bloquear y el rehydrate sigue sin re-insertar a ciegas.

## Relacionado

- `an-incomplete-inventory-reads-as-the-whole-corpus` — donde se midieron los dos.
