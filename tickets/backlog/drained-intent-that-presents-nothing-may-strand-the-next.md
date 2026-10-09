---
id: drained-intent-that-presents-nothing-may-strand-the-next
status: backlog
priority: low
area: "presentaciones, router"
created: 2026-10-08
updated: 2026-10-08
source: "review adversarial de `queued-offer-after-dismiss-flakes-on-a-cold-simulator` (2026-10-08)"
---

# Un aviso de la cola que no llega a enseñar nada podría dejar esperando al siguiente

## Qué se sospecha (inferido, no medido)

`ContentView` drena un intent `.contentView` por cada bump de `AppRouter.revision`, desde el
`.onChange(of: AppRouter.shared.revision)`. `drainNext` sube la revisión al sacar el intent, y ese bump ocurre **dentro
de la acción del `onChange`**, es decir, durante la actualización de la vista. Es la misma forma que el bug de
`queued-offer-after-dismiss-flakes-on-a-cold-simulator`, donde se midió que un `markReady` hecho ahí a veces no
dispara el `onChange(revision)` siguiente.

Con un intent que presenta algo no importa: la presentación tapa el shell, y al cerrarse la liberación (ya aplazada
fuera de la actualización) vuelve a drenar. Con uno que **no presenta nada** —`.remoteOnboardingCompleted`, un
`.presentRemoteWipeNotice` cuyas condiciones ya no se cumplen, `.appleIDChangedClosePrivate` con el aviso ya puesto— el
consumidor sigue listo y nada vuelve a bumpear: si el bump del `drainNext` se pierde, el siguiente de la cola espera al
próximo intent o a que algo cambie la matriz.

## Lo que hay que medir antes de tocar nada

1. Con la instrumentación del ticket hermano, encolar un intent que no presente nada seguido de la oferta de prueba y
   lanzar N ≥ 20 veces. ¿Aparece alguna vez `DIAGDRAIN drained <el primero>` sin el `DIAGREV` siguiente?
2. Si sí: el mismo arreglo que el hermano (re-mirar la cola una vuelta después cuando el handler no presentó nada).

## Criterios de aceptación

- [ ] Medido con N ≥ 20: se atasca o no.
- [ ] Si se atasca, arreglado y con la medición antes/después.
