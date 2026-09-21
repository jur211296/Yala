---
id: abandoned-restore-no-longer-clears-the-session-window-clock
status: backlog
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `force-fetch-and-wait-ignores-cancellation`, 2026-09-21"
---

# El restore abandonado ya no libera el reloj de la ventana de sesión

## El problema, en lenguaje de usuario

Entro a «Restaurar desde iCloud», me arrepiento y toco atrás. Un rato largo después vuelvo a entrar y
esta vez sí espero. Mis datos son muchos y tardan. A mitad de la descarga, el permiso que me deja
entrar a mi propia cuenta caduca — porque su reloj no cuenta desde que entré esta vez, sino desde la
primera. Si entonces salgo y firmo, la app me dice que **estos datos son de otra persona**. Son míos.

## Medido (2026-09-21)

`ICloudRestoreSessionSignal.noteRestoreStarted` conserva el reloj (`if restoreStartedAt == nil`) a
propósito: reiniciarlo convertiría el tope duro en una ventana extensible a voluntad. Ese sesgo tenía
un contrapeso que **este ticket no vio caer**: hasta el 2026-09-21, el flujo abandonado despertaba al
agotar el tope de `forceFetchAndWait` —90 s— y llamaba a `noteRestoreFinished`, que ponía
`restoreStartedAt = nil`. Una entrada posterior estrenaba ventana completa.

Desde `force-fetch-and-wait-ignores-cancellation`, la espera se corta al salir de la pantalla y el
apagado va detrás del `guard !Task.isCancelled` — con razón, porque apagar ahí cierra la ventana con
el import todavía bajando. **Efecto colateral: nadie libera el reloj.**

Escenario, con los topes de `ICloudRestoreInProgressLogic` (gracia 60 s, tope duro 600 s):

| t | Antes | Ahora |
|---|---|---|
| 0 | entro a Restaurar, `restoreStartedAt = 0` | igual |
| 5 s | toco atrás | igual |
| 90 s | el abandonado despierta y **limpia el ancla** | no pasa nada |
| 400 s | vuelvo a entrar → ancla = 400, ventana hasta 1000 | ancla sigue en 0, ventana hasta **600** |
| 600 s | — | la ventana caduca con el import a medias |

Con el import sin asentar y sin claim que reclame las filas —el claim vive en `UserDefaults` y muere
con la reinstalación, que es la mitad del escenario—, `CrossAccountEntryGuardLogic.decide` devuelve
`.blockedForeignData` al dueño legítimo.

## Por qué no se arregló en el ticket del que sale

Las dos salidas obvias están cerradas:

- **Reiniciar el reloj en cada entrada** es exactamente lo que el docblock prohíbe, y por un motivo
  vivo: el botón de reintentar vuelve a llamar ahí.
- **Reiniciarlo solo si la ventana ya caducó** no cubre el escenario: a t=400 la ventana sigue viva.

Lo que hace falta es separar **el reloj** del **dueño**: que un flujo cancelado suelte su titularidad
(`currentFlow`) sin apagar la ventana (`restoreStartedAt`), y que una entrada nueva sin dueño estrene
reloj. Eso rompe el invariante `restoreStartedAt == nil ⇔ currentFlow == nil`, que hoy tiene test
propio (`ICloudRestoreSignalTests.finishingTheFlowClosesTheWindow`). Es rediseño de la señal, otro eje
que el de la cancelación, y merece su propio ciclo.

## Criterios de aceptación

- [ ] Volver a entrar a Restaurar tras haber abandonado un intento estrena la ventana, sin que el
      botón de reintentar DENTRO de un restore vivo pueda extender el tope duro a voluntad.
- [ ] El flujo abandonado sigue sin apagar la ventana mientras el import baja (lo que cierra
      `force-fetch-and-wait-ignores-cancellation`; no se reabre).
- [ ] El invariante que se sustituya queda escrito y con test, no implícito.

## Relación con otros tickets

- `force-fetch-and-wait-ignores-cancellation` — de donde sale.
- `restore-back-and-reenter-closes-the-live-session-window` — el `FlowToken` cuyo escenario vivo este
  cambio estrecha.
