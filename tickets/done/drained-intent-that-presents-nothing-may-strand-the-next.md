---
id: drained-intent-that-presents-nothing-may-strand-the-next
status: done
priority: low
area: "presentaciones, router"
created: 2026-10-08
updated: 2026-11-05
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

- [x] Medido con N ≥ 20: se atasca o no.
- [x] Si se atasca, arreglado y con la medición antes/después. (No se atasca: no hay arreglo.)

## Medido (2026-11-05, lote P5 de la 2.3): no se atasca

- Seam nuevo `<scheme>://uitest-notice?kind=quiet-then-trial-offer` (`UITestRouterNoticeStage.notices(for:)`): encola,
  por la puerta de siempre y con Yala delante, `.remoteOnboardingCompleted` (que con el onboarding hecho no presenta
  nada) y detrás la oferta de prueba. Por prioridad (`.high` frente a `.normal`) el silencioso drena primero (inferido de
  `AppRouter.enqueue`, no instrumentado).
- `QueuedNoticeAfterQuietIntentUITests` con `-test-iterations 20` (iPhone 17 Pro, iOS 27.2): **20 de 20 verdes**, la
  oferta sale siempre, 13,7–14,7 s por corrida (unimodal: ninguna cola lenta que delate un rescate tardío).
- Control: la oferta sola, mismo arranque, verde. Sin `fakePrices` la oferta no sale nunca (se guarda para el arranque
  siguiente, L17-5): la primera tanda salió 20/20 roja por eso, no por la carrera.
- El caso distingue un atasco: con un mutante que quita el cambio de revisión al drenar el aviso silencioso, rojo.
- No se tocó el router. El caso queda en la suite como red (una corrida, ~15 s).
