# Implementar ticket: activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable

## Contexto
Cola autónoma bypass. Tras #159. Hermano del #158: tras «Empezar desde cero» en activación, si iCloud es unreachable, tres salidas llaman onProceed sin wipe — datos viejos siguen, y markPrivateChoseWithoutICloud puede disparar espejo tardío con .handover (purga grupos).

## Decisión de Jürgen (2026-09-14)
**(a)** Devolver a Restaurar sin declarar ningún borrado. No se promete un wipe que no ocurrió.
Con (a) no se elige (b)/(c): no hace falta cambiar el aviso del espejo tardío por este camino — no se debe escribir markPrivateChoseWithoutICloud ni proceder como si hubiera wipe.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs nuevos → ticket `--solo-crear`; decisiones nuevas → avisar a Frank (pregunta directa). Device-QA → `tickets/qa/`.

Avisos a Frank: (1) bloqueo/decisión; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.

No lances el siguiente: Frank encadena.

## Que se pide
1. Leer ticket + puerta WelcomePrivateICloudGateView (.restoreDiscardGate).
2. Implementar (a): unreachable → volver a Restaurar; no declarar borrado; no dejar armado el camino handover de grupos.
3. Criterios del ticket; PR a `2.1`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. (b)/(c). Wipe de prod.

## Como se sabe que esta bien
Criterios del ticket; tests; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-14)

La opción **(a)** ya venía decidida por Jürgen. Lo que sigue son las decisiones que (a) deja abiertas y
que había que cerrar antes de escribir. Cada una lleva lo que se midió para contestarla.

### 1. ¿Dónde vive la bifurcación: en la vista o en el call-site?

**En la vista, con un parámetro sin default.** `WelcomePrivateICloudGateView` la montan tres sitios
(`WelcomeFlowContainer:250`, `FullModeActivationView` `.privateGate:123` y `.restoreDiscardGate:139`), y
los tres comparten las fases `.noICloud` / `.unreachable`. Un parámetro `unverifiedExit` **sin valor por
defecto** obliga a los tres a pronunciarse, que es el patrón que el propio fichero ya usa con
`deviceCorpus` («los sitios que montan esta puerta contestan cosas OPUESTAS»). Un default heredaría el
desenlace de uno de los dos, que es la forma exacta del bug: la puerta nueva nació reusando la vista y se
trajo la salida de la vieja sin que nadie lo decidiera.

### 2. ¿Solo `.unreachable`, o también `.noICloud`?

**Las dos.** El ticket dice que `.noICloud` es inalcanzable por este camino «porque para llegar hubo que
encontrar corpus en iCloud». **Medido y falso:** `WelcomeRestoreView` ofrece «Empezar desde cero» desde
cuatro estados, y tres de ellos no afirman que haya datos — `notFoundView`, `iCloudDisabledView` y
`wipedView` llaman a `onStartFresh()` directo (fijado por
`RestoreStartFreshGateTests.bothStatesThatClaimDataStillConfirm:359-368`). Con iCloud desactivado en el
teléfono la pantalla lo dice y ofrece el botón igual, así que la sonda contesta `.noAccount` y la puerta
cae en `.noICloud`. Arreglar solo la fase que el ticket nombra dejaría la misma clase de bug viva en una
esquina alcanzable.

### 3. ¿A dónde vuelve exactamente?

**Por `onBack()`, que en `.restoreDiscardGate` es `go(to: .restore)`.** No por `onRestore()`: aquél
significa «traer mis datos» y cruza el portal con su destino (`proceed(to: .fullActivationRestore, …)`),
o sea que elige por la persona lo contrario de lo que acaba de pedir. `onBack()` la devuelve a la
pantalla de Restaurar con las dos opciones abiertas, que es lo que (a) pide.

### 4. ¿Se retira el arm del borrado al volver?

**Sí, y no es alcance nuevo: es no-regresión.** La salida de hoy (`continueWithoutValidating`) ya llama a
`discardPendingWipe()` en este mismo punto, así que quitarlo empeoraría el estado. Y es correcto por su
propio criterio: un borrado que ni siquiera se pudo medir no deja nada a medias que proteger, y mientras
el arm está puesto `ContentView.runLateICloudMirrorCheck:1493` lo **reanuda a ciegas** con
`performICloudCorpusWipe(.handover)`. Es la otra mitad del punto 2 del encargo («no dejar armado el
camino handover de grupos»); la primera mitad es no escribir `markPrivateChoseWithoutICloud`, cuyo aviso
tardío borra con ese mismo `.handover` (`ContentView.swift:352`).

### 5. ¿Copy reusado o copy nuevo?

**Dos claves nuevas, títulos reusados.** `errorBody` dice «Inténtalo otra vez **antes de seguir**» y
`noAccountBody` dice «**Puedes seguir**: por ahora tus datos se quedan aquí» — las dos prometen un
«seguir» que en este desenlace ya no existe, y el criterio nº1 del ticket es justamente no declarar lo
que no pasó. Los títulos (`errorTitle`, `noAccountTitle`) siguen valiendo tal cual y conservan el matiz
entre «no hay cuenta» y «no hubo conexión», así que el cuerpo puede ser uno solo para las dos fases: el
hecho que describe es el mismo. Las dos claves —`discardUnverifiedBody` y `discardUnverifiedBack`— van a
los 16 locales con `qa/scripts/add-l10n-key.sh` y se traducen a mano (el marcador `[NEEDS_TRANSLATION]`
lo bloquea `LocalizationParityTests`).

### 6. ¿Y las otras dos salidas que el ticket lista?

**Se quedan como están, y por motivos distintos.**

- **El atajo de `isUITesting` en `measure()`** es hermeticidad de test, no un camino de producción: bajo
  XCUITest no se toca CloudKit en ningún punto del Welcome, y el docblock defiende que el recorrido
  determinista quede byte-idéntico. Cambiarlo rompería esa identidad sin arreglar nada que un usuario
  pueda vivir.
- **`case .proceed`** no cae en el supuesto de (a): ahí a iCloud **sí** se le preguntó y contestó que la
  zona está vacía, así que no hay borrado que declarar. El residuo teórico —zona vacía con filas
  importadas todavía en el teléfono— exige que otro dispositivo vacíe la zona en la ventana entre el
  restore y la sonda; si aparece, es ticket propio y su arreglo es borrar lo local, no volver atrás.

### 7. ¿Review adversarial?

**Sí.** El cambio toca el desenlace de un borrado irreversible y el testigo que dispara un segundo
borrado con scope `.handover`. Es exactamente la lógica donde el `CLAUDE.md` la pide.
