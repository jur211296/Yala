---
id: abandoned-restore-no-longer-clears-the-session-window-clock
status: qa
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

- [x] Volver a entrar a Restaurar tras haber abandonado un intento estrena la ventana, sin que el
      botón de reintentar DENTRO de un restore vivo pueda extender el tope duro a voluntad.
- [x] El flujo abandonado sigue sin apagar la ventana mientras el import baja (lo que cierra
      `force-fetch-and-wait-ignores-cancellation`; no se reabre).
- [x] El invariante que se sustituya queda escrito y con test, no implícito.

## Relación con otros tickets

- `force-fetch-and-wait-ignores-cancellation` — de donde sale.
- `restore-back-and-reenter-closes-the-live-session-window` — el `FlowToken` cuyo escenario vivo este
  cambio estrecha.

---

## Resuelto (2026-09-21)

### Qué cambia para quien usa la app

Entro a «Restaurar desde iCloud», me arrepiento y toco atrás. Un rato largo después vuelvo a entrar y
esta vez sí espero. **Ahora el reloj del permiso empieza cuando entré ESTA vez**, no cuando entré la
primera, así que no se me agota a media descarga y la app deja de decirme que mis datos son de otra
persona.

Y lo que ya estaba bien no se movió: mientras el import sigue bajando, salir de la pantalla **no
apaga nada**.

### Cómo

`ICloudRestoreSessionSignal` separa dos cosas que hasta hoy eran la misma:

| | Antes | Ahora |
|---|---|---|
| Invariante | `restoreStartedAt == nil ⇔ currentFlow == nil` | `currentFlow != nil ⇒ restoreStartedAt != nil` (solo esa dirección) |
| Estado nuevo | — | **ventana huérfana**: reloj puesto, dueño `nil` |
| `noteRestoreStarted` | estrena reloj si no hay RELOJ | enciende si está apagada, y **re-ancla una huérfana solo con descarga real detrás** |
| Soltar sin apagar | no existía | `noteRestoreAbandoned(token)`, desde el `onDisappear` de `RestoreProgressView` — **se mudó a `WelcomeRestoreView` el mismo día**, ver nota abajo |

> **Nota del 2026-09-21, misma tarde.** `restore-timeout-closes-the-session-window-with-the-import-still-running`
> **mudó el `noteRestoreAbandoned` a `WelcomeRestoreView.onDisappear`**. El motivo: la pantalla de
> progreso se desmonta también cuando solo cambia el `state` —a `.importIncomplete`, a `.found`—, o sea
> con la persona todavía dentro de Restaurar, y soltar ahí dejaba la ventana huérfana para que el
> reintento la re-anclara cada 90 s. El mecanismo de este ticket no cambia: el re-ancla con descarga real
> detrás sigue siendo el arreglo, y sigue habiendo un solo call-site. Lo que cambia es cuál.
> El residual que eso deja abierto —salir de Restaurar y volver renueva el tope duro— tiene ticket propio:
> `leaving-and-reentering-restore-renews-the-hard-cap`.

La ventana huérfana es lo que hace posibles las dos mitades a la vez: sigue viva para el import que
baja —la cierran el asentamiento o la caducidad, como siempre— pero ya no la vigila nadie, así que la
entrada siguiente la estrena.

### La premisa del ticket que cayó al medirla

El docblock decía que conservar el reloj impedía que el botón de reintentar extendiera el tope a
voluntad. **No lo impedía.** Los cinco botones de «volver a buscar» de `WelcomeRestoreView` solo
salen en estados terminales (`showRefreshToolbar`), y los que pueden tener datos se alcanzan desde
`onSettled`, aguas abajo de `noteRestoreFinished` — o sea que cuando la persona los toca el reloj ya
es `nil` y se estrena igual, antes del ticket y después. Lo único que aquel guard producía era este
bug. Con la condición nueva la protección pasa a ser real Y comprobable: conserva mientras el intento
anterior siga siendo dueño, que es lo que de verdad significa «dentro de un restore vivo».

### Lo que cambió la review

Una lente midió que «estrenar si no hay dueño» a secas abría un agujero nuevo: el ciclo **entrar a
Restaurar → tocar atrás → repetir** re-anclaba el reloj en cada vuelta, y como `isRestoringNow` mide
todos sus plazos desde ahí —la gracia de 60 s incluida—, quien navegara más rápido que esa gracia
mantenía la ventana del guard cross-cuenta abierta indefinidamente. Antes del ticket no se podía: el
reloj no se reiniciaba en reentradas, así que en un teléfono sin import moría a los 60 s.

Lo cierra el testigo del import: **una ventana huérfana solo se re-ancla si llegó algún
`.importEvent`** — o sea, si hay una descarga de verdad que justifique una ventana nueva. Es el mismo
testigo con el que `ICloudRestoreInProgressLogic` separa «el import va lento» de «no hay nada que
importar», y su modo de fallo es conservar el reloj viejo, o sea **cerrar antes**. Va **sin valor por
defecto**, como el `restoreInProgress: Bool` del guard: quien añada un call-site tiene que decidir de
dónde sale, y lo comprueba el compilador.

Las otras dos lentes no encontraron nada: cero hallazgos en ciclo de vida de SwiftUI (cinco hipótesis
refutadas con medición) y, en la de tests, dos huecos menores que ya están cerrados —el helper del
invariante era un `if` que no entraba en tres de cinco pasos, y faltaba el caso de soltar sin dueño.

### Verificación

- Build ✓ · 32 tests del área en verde (`ICloudRestoreInProgressLogicTests`,
  `ICloudRestoreSessionSignalTests`, `ICloudRestoreSignalWiringTests`, `RestoreStartFreshGateTests`,
  `GroupsOrganizerWiringTests`, `WelcomeBackDestinationTests`).
- **8 mutantes, los 8 muertos**: volver al guard viejo, abandonar apagando el reloj, abandonar sin el
  guard del token, `onDisappear` sin soltar, estrenar reloj siempre, quitar el testigo del import,
  cablear el testigo a una constante en la pantalla, y quitar el término del dueño.
- Review adversarial: tres lentes independientes (ciclo de vida de SwiftUI, frontera de cuenta,
  cobertura real de los tests) + las rules de área leídas contra el diff.

### Residual declarado (no se apuntala)

Si SwiftUI llegara a correr el `.task` de una entrada nueva ANTES del `onDisappear` de la anterior, el
reloj se heredaría — o sea, el comportamiento de hoy. Es fail-soft hacia el status quo, no una
regresión nueva, y el guard por token impide cualquier daño al intento vivo. No se añade una segunda
vía por ello.

### Device-QA

No se monta en simulador: exige corpus real en iCloud y un import de más de 90 s.

1. iPhone con la app recién instalada y un Apple ID con histórico grande en iCloud.
2. Welcome → «Ya tengo cuenta» → «Restaurar desde iCloud». Espera a ver la barra moviéndose.
3. A los ~5 s toca atrás. **Comprueba que la app no se queda quieta**: el import sigue.
4. Espera **7 minutos** fuera de esa pantalla, sin matar la app.
5. Vuelve a entrar a «Restaurar desde iCloud» y deja la barra correr **más de 3 minutos**.
6. Toca atrás y firma con tu propia cuenta.
7. **Esperado:** entras a tu cuenta. **Fallo del ticket:** «estos datos son de otra persona».
8. Repite del 1 al 3 y, sin esperar, vuelve a entrar en 10 s: la barra tiene que arrancar igual.

## Tickets abiertos de camino

- `restore-timeout-closes-the-session-window-with-the-import-still-running` — el mismo daño por el eje
  del desenlace: el tope de 90 s apaga la ventana con el import en marcha.
- `restore-error-state-is-never-reached` — el `case error` de `WelcomeRestoreView` no lo asigna nadie.
