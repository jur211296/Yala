---
id: wiped-state-reaches-the-discard-gate-with-the-window-open
status: backlog
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
source: "lente 2 de la review adversarial de `restore-session-window-has-no-reachable-ceiling`, 2026-09-21"
---

# El estado `.wiped` llega a la puerta de descarte con la ventana de sesión abierta

## El problema, en lenguaje de usuario

No hay síntoma para el dueño legítimo. En un teléfono con los datos de otra persona hay un camino
—estrecho— por el que se llega a la puerta de «Empezar desde cero» **sin que la ventana que abre el
guard de frontera de cuenta se cierre**, y se queda abierta hasta diez minutos mientras la persona
está parada en esa pantalla. Es el mismo agujero que la review del 2026-09-21 cerró para el botón
de al lado, por el único camino que no pasa por su diálogo.

## Medido (2026-09-21)

`WelcomeRestoreView.wipedView` llama a `onStartFresh()` **directo**, sin diálogo de confirmación y
sin tocar la señal:

```swift
primaryTitle: L10n.Welcome.Restore.startFresh,
primaryAction: onStartFresh
```

Los otros seis caminos a «Empezar desde cero» pasan todos por `showStartFreshConfirm`, cuya
confirmación llama a `ICloudRestoreSessionSignal.noteRestoreDiscardRequested` — que apaga la ventana
aparcando su reloj. `.wiped` no.

**Por qué normalmente no muerde, y por qué a veces sí.** `.wiped` sale de un `return` temprano de
`startSearch()`, que corre **antes** de encender la señal: en la primera entrada no hay ventana que
cerrar. Pero la pantalla ofrece «volver a buscar», y `RestoreOfferGate.wasWiped` lee
`PreferenceSyncService.lastWipeTimestamp`, **una preferencia sincronizada**: puede llegar de otro
dispositivo entre la primera búsqueda y el reintento. Recorrido:

1. Entra a Restaurar con iCloud disponible → la señal se enciende, `restoreStartedAt = T0`.
2. Llega el sello del wipe desde el otro dispositivo.
3. Toca «volver a buscar» → `startSearch()` sale por `.wiped` → la señal **no se toca**.
4. «Empezar desde cero» → `onStartFresh()` directo → la puerta.
5. El `.onDisappear` **suelta** la titularidad (`noteRestoreAbandoned`) y **no toca el reloj**: la
   ventana queda HUÉRFANA y VIVA hasta el tope duro de 600 s.

⇒ con la persona declarando que descarta el import, el guard de frontera de cuenta sigue entornado.

## Lo que hay que decidir

- **Si `.wiped` debe confirmar como los otros seis.** Su copy dice que el usuario ya borró sus datos
  aquí, así que el diálogo puede sobrar — pero entonces el apagado tiene que ir en el propio
  `onStartFresh` de ese estado, no en la confirmación.
- **O si el apagado sube un nivel**, a un punto por el que pasen los siete caminos. Ojo: el que se
  elija tiene que seguir dejando que el `cancel` del diálogo vuelva sin haber apagado nada.

## Criterios de aceptación

- [ ] Ningún camino a la puerta de descarte deja la ventana de sesión viva.
- [ ] El `cancel` del diálogo sigue sin tocarla.
- [ ] Un test que recorra el camino de `.wiped`, que hoy no tiene ninguno: el escáner
      `discardingTheImportClosesTheWindowFromTheConfirmation` solo mira el cuerpo del diálogo.

## Relación con otros tickets

- `restore-session-window-has-no-reachable-ceiling` — de donde sale; cerró el mismo agujero para los
  seis caminos que sí confirman.
