---
id: inbox-swipe-save-success-sheet-shows-blank
status: backlog
priority: high
area: inbox
created: 2026-11-10
updated: 2026-11-10
source: lote 03 de las necesarias 2.3 (sesión del 2026-11-10), medido en XCUITest
---

# Deslizar para guardar un borrador abre una pantalla de éxito vacía

Medido el 2026-11-10 en el simulador (iPhone 17 Pro, iOS 27.2), en `origin/2.3` sin cambios y con el lote 03 encima: al
deslizar a la derecha un borrador completo de la Bandeja, se guarda bien (sale de pendientes y el saldo cambia) pero la
hoja que sube encima está vacía: fondo oscuro, sin el check, sin el resumen y sin «Aceptar». Solo se cierra
arrastrándola hacia abajo. Vídeos en los `.xcresult` de `YalaUITests/InboxDuplicateCheckUITests` (caso «Guardar de todas
formas» y el antes de deslizar).

El código es el mismo en `1.0` (lo publicado), `2.2` y `2.3`: `InboxView` presenta `.sheet(isPresented:
$showSwipeSuccessView)` con el contenido sacado de OTRO `@State` (`if let data = swipeSuccessData`), y los dos se
escriben en el mismo toque (`approveDraft`). Es la trampa de `.claude/rules/swiftui-ds.md` («`.sheet(isPresented:)` con el
contenido sacado de OTRO `@State` sale VACÍA si el `body` no lee ese estado fuera del cierre»). Inferido, sin bisecar
desde cuándo se ve así: la regla se midió en iOS 27.0.

## Qué hacer

El molde de la regla: `.sheet(item:)` con los datos del éxito (o leer `swipeSuccessData` en el `body`). Como está en lo
publicado, decidir si va como arreglo urgente sobre `1.0` (`docs/FLUJO-RAMAS-Y-HOTFIX.md`) o en la próxima versión.
Al arreglarlo, `InboxDuplicateCheckUITests#test_swipeToSave_onAPossibleDuplicate_saveAnywaySavesIt` puede volver a
esperar `inbox_success_accept`.
