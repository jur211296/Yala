---
id: discard-gate-cannot-close-an-orphan-session-window
status: backlog
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

## Lo que hay que decidir

- **¿El descarte puede cerrar una ventana que no es suya?** Si sí, hace falta un verbo —o un
  parámetro— que apague sin `guard`, y el `parked` que deje tiene que seguir siendo el reloj viejo.
- **Si no**, entonces el criterio del ticket hermano («ningún camino a la puerta de descarte deja la
  ventana viva») es inalcanzable por construcción y hay que reescribirlo acotado, porque hoy el
  escáner `everyPathToTheDiscardGateClosesTheSessionWindow` promete más de lo que puede dar.
- **Ojo al alcance**: la PUERTA (`WelcomePrivateICloudGateView`) tiene **tres** instanciaciones y solo
  una llega por `onStartFresh`. Por `WelcomeFlowContainer.swift:459` («Soy nuevo» → «Privado») se
  llega con la ventana viva y huérfana sin pasar por Restaurar siquiera. Cualquier arreglo que quiera
  decir «todos los caminos a la puerta» tiene que mirar las tres.

## Criterios de aceptación

- [ ] Decidido y escrito si el descarte puede apagar una ventana huérfana.
- [ ] Si puede: el recorrido de seis pasos de arriba deja la ventana cerrada, con test que lo recorra.
- [ ] Si no puede: el criterio del ticket hermano queda reescrito con su alcance real, y el mensaje
      del escáner deja de prometer lo que no cubre.
- [ ] El dueño legítimo que abandona y vuelve **sin** descartar sigue con su ventana viva: es el
      invariante de `abandoned-restore-no-longer-clears-the-session-window-clock`.

## Relación con otros tickets

- `wiped-state-reaches-the-discard-gate-with-the-window-open` — de donde sale; cerró el camino en el
  que la MISMA instancia tiene el token.
- `abandoned-restore-no-longer-clears-the-session-window-clock` — el invariante que hace que esto sea
  una decisión y no un bug obvio.
- `restore-timeout-closes-the-session-window-with-the-import-still-running` — por qué abandonar
  suelta en vez de apagar.
