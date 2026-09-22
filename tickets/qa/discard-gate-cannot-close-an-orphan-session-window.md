---
id: discard-gate-cannot-close-an-orphan-session-window
status: qa
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-22
source: "lente 1 de la review adversarial de `wiped-state-reaches-the-discard-gate-with-the-window-open`, 2026-09-22"
---

# La puerta de descarte no puede cerrar una ventana HUÉRFANA

## El problema, en lenguaje de usuario

Hay un recorrido por el que se llega a «Empezar desde cero» con el permiso que deja firmar sin aviso
todavía abierto, y el botón **no puede cerrarlo**. No es el camino del ticket que lo encontró —ése se
cerró el 2026-09-22— sino su hermano: el que pasa por **salir de Restaurar y volver a entrar**.

No hay síntoma para el dueño legítimo. Muerde en un teléfono con los datos de otra persona.

## Medido (2026-09-22)

`WelcomeRestoreView.discardImportAndStartFresh()` apaga con
`ICloudRestoreSessionSignal.noteRestoreDiscardRequested(flowToken)`, y ese verbo necesita **dos**
cosas: un `flowToken` en el `@State` de ESTA instancia de la vista, y que ese token siga siendo el
dueño vigente (`guard currentFlow == token`). El recorrido las rompe las dos:

1. Entra a Restaurar → la señal se enciende en `t0`, dueño `T1`.
2. El tope de 90 s se rinde **con el import vivo** → nadie apaga → `.importIncomplete`.
3. Toca **atrás** → el `.onDisappear` llama a `noteRestoreAbandoned(T1)`: la ventana queda **viva y
   HUÉRFANA** (`restoreStartedAt = t0`, `currentFlow = nil`). Eso es correcto y deliberado: el import
   sigue bajando y CloudKit no para porque nadie mire.
4. Vuelve a entrar a Restaurar. **Instancia nueva: `flowToken` vuelve a `nil`.**
5. `startSearch()` sale por un `return` temprano —`.wiped` o `.iCloudDisabled`— sin encender nada.
6. «Empezar desde cero» → el punto único corre con `flowToken == nil` ⇒ **no-op**.

⇒ se llega a la puerta con la ventana abierta hasta `t0 + 600 s`. Y aunque el `@State` conservara el
token, tampoco cerraría: el dueño es `nil` desde el paso 3.

**Lo mismo por `.iCloudDisabled`**, que es el otro `return` temprano y sí confirma con diálogo: la
confirmación llama al mismo punto único con el mismo `flowToken` nulo.

## Por qué NO se arregló al cerrar el ticket que lo encontró

Porque cerrarlo es una decisión, no una omisión. Apagar una ventana huérfana desde un intento que
no la encendió es exactamente lo que `noteRestoreAbandoned` existe para **no** hacer
(`restore-timeout-closes-the-session-window-with-the-import-still-running`): esa ventana protege un
import que sigue trayendo filas, y cerrarla le devuelve al dueño legítimo el bloqueo sobre su propia
cuenta.

La pregunta abierta es si **el gesto de descartar** es distinto de los demás. Quien pulsa «Empezar
desde cero» declara que no quiere esas filas —detrás está la puerta que las borra—, así que la
premisa «hay que protegerlas» deja de valer **para cualquier import**, sea de este intento o del
anterior. Si esa lectura se acepta, el descarte es el único verbo que puede apagar sin titularidad.

## DECIDIDO (2026-09-22, Jürgen)

**Sí: el descarte puede apagar una ventana que no es de su intento.** Quien pulsa «Empezar desde
cero» declara que no quiere esas filas, y la premisa de la que cuelga todo el diseño de la señal
—«las filas siguen entrando y hay que protegerlas»— deja de valer **para cualquier import**, sea de
este intento o del anterior. `noteRestoreDiscardRequested` es el único de los cinco verbos que apaga
sin titularidad; sus dos hermanos conservan el guard.

## Lo que se hizo

**Una sola línea de producción, y dos que se van.** `noteRestoreDiscardRequested` pierde el parámetro
`FlowToken` y su `guard currentFlow == token`; `discardImportAndStartFresh()` pierde el `if let
flowToken`. Las dos mitades hacían falta: el `@State` de la instancia nueva nace en `nil`, así que el
`if let` ni entraba, y aunque entrara el dueño es `nil` desde que el `.onDisappear` soltó.

El aparcado se escribe **solo si hay reloj**. No es defensa «por si acaso»: sin ese término, un
descarte sobre una ventana ya apagada escribe `parkedStartedAt = nil` encima del reloj que el descarte
anterior guardó, y la vuelta estrena 600 s — el recorrido de tres toques de
`restore-session-window-has-no-reachable-ceiling`, reabierto.

## LA PREGUNTA DEL ALCANCE, MEDIDA: el apagado se queda en el GESTO

El encargo pedía cubrir **las tres** instanciaciones de `WelcomePrivateICloudGateView`, y la forma
obvia de hacerlo es subir el apagado a su montaje: es el destino común de los siete caminos de
Restaurar, el orden con el `.onDisappear` dejaría de importar y cualquier camino futuro quedaría
cubierto solo. **Se implementó, se pasó por tres lentes adversariales, y las tres lo tumbaron por el
mismo motivo.** Queda escrito porque la simetría lo va a volver a sugerir:

- **Dos de las tres instanciaciones no son un descarte, y sus propios docblocks lo dicen.**
  `WelcomeFlowContainer` usa el mismo step `.privateICloudGate` para «Soy nuevo» → «Privado»
  (`handleNewOption(.privateAccount)`), y `FullModeActivationView.privateGate` es ese mismo caso
  dentro de la activación. Los dos llevan `unverifiedExit: .proceedWatchingTheMirror` **porque ahí no
  se ha pedido ningún borrado** — el enum lo dice literalmente: lo que separa sus dos casos es «si la
  persona ya confirmó un borrado antes de llegar aquí».
- **El daño, con su recorrido.** Entra a Restaurar (ventana en `t0`, import bajando) → atrás (ventana
  **huérfana y viva**, que es correcto) → «Es mi primera vez» → «Privado» → la puerta monta y le apaga
  la ventana → «Volver» → «Ya tengo cuenta» → firma. `CrossAccountEntryGuardLogic.decide` pasa de
  `.proceed` a **`.blockedForeignData`**: al dueño legítimo se le dice que sus propios datos son de
  otra persona. Es el bug que esta señal entera existe para impedir, entrando por la puerta de al
  lado. Y a diferencia del camino que vuelve a Restaurar, éste **no se auto-repara**: el aparcado solo
  se hereda al volver a entrar a Restaurar, y aquí no se vuelve.
- **Y no se arregla condicionando por `unverifiedExit`**, que es la salida que parece obvia: en el
  Welcome, el camino del descarte (`ContentView.onStartFresh`) y el de «Soy nuevo» → «Privado»
  comparten el MISMO step y por tanto el mismo `unverifiedExit`. Condicionar ahí dejaría sin apagar
  justo el camino principal del ticket.
- **Segunda razón, de robustez.** En el gesto el apagado cuelga de un TAP, que provablemente ocurrió.
  En el montaje colgaría de una presentación, y en este anchor las presentaciones se caen
  (`.claude/rules/swiftui-ds.md`, regla 4). Su modo de fallo sería dejar la ventana ABIERTA, en
  silencio — justo el desenlace que el ticket cierra.

**Qué queda sin cubrir, y por qué se acepta.** Por «Soy nuevo» → «Privado» se puede llegar a la puerta
con una ventana huérfana viva, y nadie la apaga. No es un agujero equivalente: quien llega ahí **no ha
declarado que descarta nada** —es el invariante de `abandoned-restore-…`, que dice que esa ventana es
legítima mientras el import baje—, y si desde ahí sí borra, el borrado arma el relanzamiento y la
señal muere con el proceso, porque vive en memoria a propósito. El caso que quedaría es «mirar la
puerta, volver y firmar», y ahí apagar hace más daño que dejarla.

## Cobertura

- Unit: `discardingClosesAnOrphanWindow` (el recorrido de seis pasos, con sus controles) y
  `discardingTwiceKeepsTheFirstParkedClock`. Retirado `discardingFromAStaleTokenIsANoOp`, que fijaba
  el guard que esta decisión deroga; su otra mitad la cubre `theParkedClockIsConsumedByTheFreshStart`.
- Source-scan: `everyPathToTheDiscardGateClosesTheSessionWindow` conserva su forma —`wipedView` por el
  punto único, el conteo del IDENTIFICADOR `onStartFresh`, y el cuerpo entero del punto único— y ahora
  ese cuerpo son **dos** sentencias, así que un `if let flowToken` que vuelva lo pone rojo. Nuevo:
  `theDiscardGateItselfNeverClosesTheSessionWindow`, que prohíbe tocar la señal desde la puerta y deja
  escrito en su mensaje por qué.
- **12 mutantes, 12 muertos:** reintroducir el `guard` del verbo; reintroducir el `if let flowToken`;
  aparcado incondicional; `.wiped` al callback crudo; `.wiped` con el botón muerto; la confirmación
  saltándose el punto único; el `cancel` comprometiendo el descarte; una sentencia antepuesta; el
  orden invertido; quitar `currentFlow = nil`; quitar `restoreStartedAt = nil`; y subir el apagado al
  montaje de la puerta.

## Relación con otros tickets

- `wiped-state-reaches-the-discard-gate-with-the-window-open` — de donde sale; cerró el camino en el
  que la MISMA instancia tiene el token.
- `abandoned-restore-no-longer-clears-the-session-window-clock` — el invariante que hace que esto sea
  una decisión y no un bug obvio.
- `restore-timeout-closes-the-session-window-with-the-import-still-running` — por qué abandonar
  suelta en vez de apagar.

## Guion de device-QA (iPhone, 2 cuentas de nube)

**Por qué hace falta teléfono:** la ventana solo se observa por su efecto —el guard de frontera de
cuenta— y ese guard se ejerce al FIRMAR con una cuenta de nube. El simulador no tiene App Attest, así
que no puede crear ni usar una cuenta de la nube sin el secreto de desarrollo. Y el paso 2 pide un
import de CloudKit que tarde más de 90 s, que solo pasa con un corpus real.

**Montaje:** un iPhone con Yala recién instalada y una cuenta de iCloud con histórico grande (para que
el import no termine dentro del tope de 90 s), más **una segunda cuenta de nube (Google o Apple)
distinta** de la que esté en el faro de ese Apple ID.

### Caso 1 · el recorrido del ticket (vía Restaurar)

1. Abrir Yala → Welcome → «Ya tengo cuenta» → «Restaurar desde iCloud». La app relanza.
2. Esperar los 90 s. **Esperado:** «Seguimos trayendo tus datos» (no «No hay datos»).
3. Tocar el chevron de atrás. Vuelve al chooser. **No matar la app.**
4. Ajustes del sistema → apagar la cuenta de iCloud. Volver a Yala.
5. «Ya tengo cuenta» → «Restaurar desde iCloud». **Esperado:** «iCloud no está disponible».
6. «Empezar desde cero» → confirmar. **Esperado:** llega la puerta «Encontramos datos en tu iCloud».
7. En la puerta, tocar «Volver». Luego «Es mi primera vez» → «Tu cuenta en la nube» y firmar con la
   **segunda** cuenta.
   - **Esperado (con el fix):** sale el aviso de frontera de cuenta —«estos datos son de otra
     persona»— en el acto.
   - **Sin el fix:** dejaba firmar encima hasta 10 minutos después del paso 1.

### Caso 2 · el camino que queda FUERA a propósito (control negativo del alcance)

1. Pasos 1 a 3 del caso 1.
2. «Es mi primera vez» → «Privado». **Esperado:** llega la puerta.
3. «Volver» → «Es mi primera vez» → «Tu cuenta en la nube» con la segunda cuenta.
   - **Esperado:** **NO** sale el aviso de frontera de cuenta. Quien llega a esa puerta no ha
     declarado que descarta el import, así que su ventana sigue viva: es el invariante de
     `abandoned-restore-no-longer-clears-the-session-window-clock`. Si aquí saliera el aviso, alguien
     subió el apagado al montaje de la puerta y le está diciendo al dueño legítimo que sus propios
     datos son de otra persona.

### Caso 3 · control negativo (el invariante que NO se puede romper)

1. Pasos 1 a 3 del caso 1.
2. Volver a «Ya tengo cuenta» → «Restaurar desde iCloud», **sin pasar por la puerta**.
   - **Esperado:** la búsqueda sigue, el import continúa y el reintento funciona con normalidad. Quien
     abandona y vuelve sin descartar conserva su ventana: es el invariante de
     `abandoned-restore-no-longer-clears-the-session-window-clock`.

### Caso 4 · el reloj aparcado sigue aparcado

1. Pasos 1 a 6 del caso 1, pero en el paso 7 salir de la puerta por «Traer mis datos» en vez de
   «Volver» (hay que volver a encender iCloud antes).
   - **Esperado:** vuelve a Restaurar y la búsqueda arranca. El tope duro sigue contando desde el paso
     1, así que si han pasado más de 10 minutos la ventana ya no estará abierta — eso es correcto.
