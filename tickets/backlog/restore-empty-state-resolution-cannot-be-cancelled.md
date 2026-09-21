---
id: restore-empty-state-resolution-cannot-be-cancelled
status: backlog
priority: low
area: "welcome, icloud, restore"
created: 2026-09-20
updated: 2026-09-20
source: "review adversarial (lente de concurrencia y ciclo de vida) de `restore-says-no-data-when-the-icloud-import-never-settled`, 2026-09-20"
---

# El guard de cancelación de `resolveEmptyState` protege algo que no puede ocurrir

## Medido (2026-09-20)

`Yala/App/Views/Onboarding/WelcomeRestoreView.swift`, en la closure de `RestoreProgressView`:
`Task { await resolveEmptyState(settlement) }` es un `Task.init` **no estructurado**, creado dentro
de un closure síncrono de SwiftUI. No hay tarea padre de la que heredar cancelación y SwiftUI no lo
registra (a diferencia de `.task { }`). ⇒ el `guard !Task.isCancelled` que hay tras el único punto
de suspensión de `resolveEmptyState` **nunca dispara**, y el comentario que lo acompaña —«sin este
guard un usuario que toca "volver" durante el refresco vería la pantalla cambiar bajo el dedo»—
describe una protección que no existe.

`Task {}` dentro de un contexto `@MainActor` hereda **aislamiento**, nunca cancelación.

## Por qué es `low` y aun así se anota

Hoy es benigno: la escritura tardía cae sobre el `@State` de un cover ya destruido, así que no se
ve nada raro. Lo que hay que cerrar es la **garantía escrita que no se cumple** — en este repo la
documentación envejece más rápido que el código, y alguien se va a apoyar en ese guard para algo
que sí importe. Ya pasó una vez: el docblock de `resolveEmptyState` se reescribió el 2026-09-20 y
volvió a apoyarse en esa rama.

## Criterios de aceptación

- [ ] O la cancelación funciona de verdad (el trabajo cuelga de un `.task`/`@State` de tarea que la
      vista cancele en `onDisappear`), o el comentario deja de prometerla.
- [ ] Lo que se elija queda medido, no razonado: un mutante que quite el guard tiene que cambiar
      algo observable, o el guard sobra.

## Relación con otros tickets

- `restore-back-and-reenter-closes-the-live-session-window` — el otro «la cancelación no cancela»
  de esta misma pantalla, y ese sí muerde.
