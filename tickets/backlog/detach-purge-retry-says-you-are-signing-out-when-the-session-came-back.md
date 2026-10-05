---
id: detach-purge-retry-says-you-are-signing-out-when-the-session-came-back
status: backlog
priority: low
area: "modo-nube, settings, groups"
created: 2026-10-02
source: "hallazgo de `detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait`"
---

# «Terminar de soltar la cuenta» puede decir «Estás cerrando sesión» cuando lo que pasó es que volviste a entrar

## El problema, en lenguaje de usuario

Un desasociar quedó a medias y la sección ofrece «Terminar de soltar la cuenta». Lo toco, y mientras espera (hasta un
minuto, a que iCloud termine de bajar datos) vuelvo a entrar en esa misma cuenta. El aviso que sale dice «Estás cerrando
sesión en este momento. Termina eso primero y vuelve a intentarlo». No estoy cerrando sesión: acabo de entrar.

## Lo leído en el código (sin ejecutar)

- `CloudSessionSignOut.retryDetachPurge` devuelve `.busy` en tres sitios: la fase ocupada, el sello que ya no casa (o la
  sesión de esa cuenta viva) antes de empezar, y `.preconditionLost` tras la espera de `writeDetachUnderQuiescence`.
- `GroupsAssociationSection.apply` pinta todo `.busy` con `.detachBusy` («Estás cerrando sesión»). Solo el primero es
  verdad. El segundo lo filtra la vista (`hasPendingPurge` exige la misma condición), así que en la práctica es el tercero.
- Desde 2026-10-02 la fase ocupada ya no puede venir de un desasociar anterior bloqueado
  (`detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait`), así que `.busy` del gesto entero sí es
  «hay un cierre de sesión en curso».

## Lo que se espera

Que la sesión que volvió tenga su propio desenlace y su propio texto (copy nuevo en los idiomas: decisión de producto),
o que la sección simplemente se re-pinte en silencio, porque con la sesión de esa cuenta viva ya no ofrece terminar.
