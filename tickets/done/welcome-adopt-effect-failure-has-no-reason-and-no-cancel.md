---
id: welcome-adopt-effect-failure-has-no-reason-and-no-cancel
status: done
priority: medium
area: "modo-nube, onboarding, adopt"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `adopt-effect-retries-forever-with-no-ceiling` (2026-09-23), lente de consumidores"
---

# Si entrar en tu cuenta falla desde la bienvenida, la pantalla culpa a tu conexión y no te deja cancelar

## El problema, en lenguaje de usuario

Instalo Yala en un teléfono nuevo y entro en mi cuenta de la nube desde la bienvenida. Si la parte final no puede
terminar, la barra se queda en «Conectando…» con «Retomar», sin botón para cancelar ni flecha atrás. Cuando por fin se
rinde (15 min si el fallo es del teléfono, 72 h si es la red), dice «No pudimos verificar tu cuenta. Revisa tu conexión»,
aunque la causa sea que el teléfono no pudo leer sus propios datos.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

`CloudWelcomeSignInFlow.phase` mapea `.failed` a `.error(retryable: true)` sin mirar `adoptClaimExit`, así que los
dos textos nuevos del efecto (`adoptEffectLocalFailure`, `adoptEffectStalled`) solo llegan a Almacenamiento. Y
`canGoBack` es `false` en `.adopting`: el «Cancelar» del efecto (ticket `adopt-effect-retries-forever-with-no-ceiling`)
existe solo en Ajustes.

## Qué habría que decidir (es de producto)

1. ¿El error del Welcome dice el motivo con los mismos textos de Almacenamiento?
2. ¿«Cancelar» (o la flecha atrás) durante el efecto en la bienvenida, y a dónde lleva?

## Relacionado

- `adopt-effect-retries-forever-with-no-ceiling`, `adopt-claim-stays-parked-with-no-ceiling`.

## Decisión (Jürgen 2026-09-23)

**A:** mismos textos por motivo que en Almacenamiento (`adoptEffectLocalFailure` / `adoptEffectStalled`), más Cancelar o flecha atrás durante el efecto en la bienvenida.

## Hecho (2026-09-23)

**Si entrar en tu cuenta falla desde la bienvenida, la pantalla dice el motivo con las frases de Almacenamiento**, y
mientras la barra está en pantalla hay «Cancelar la activación».

- **El motivo.** Fase nueva `.adoptExit(AdoptClaimExit)` cuando la máquina falla con la marca del adopt puesta
  (distinta de `.cancelled`, solo en la ida y detrás de `claimBlocker`, que sigue ganando). El texto sale de
  `StorageFailureCopyLogic.adoptExitMessage`, la MISMA función que usa la tarjeta de Almacenamiento: cubre las dos del
  efecto y, por la misma puerta, las tres del claim, que tenían el mismo genérico. Icono de aviso, «Reintentar» y flecha.
- **La salida.** «Cancelar la activación» bajo la barra, con el predicado de Almacenamiento (`canCancelMigration`: efecto
  pendiente o claim del adopt), su diálogo y su cuerpo por fase (ahora en `cancelMigrationBody`, compartida) y su
  `cancelMigration()`. Vuelve al chooser —a donde lleva la flecha desde el error— **solo cuando la cancelación aterrizó**:
  `notStarted`, sin el pendiente del efecto y con la marca `.cancelled` (`WelcomeAdoptCancel.afterCancel`). El poll lo mira
  en cada vuelta mientras haya una cancelación pedida, porque puede aterrizar en una pasada posterior; y «Retomar» con
  ella pedida reanuda, nunca vuelve a reclamar.
- **Lo que cazó la review (dos lentes).** La primera versión salía al chooser mirando solo `notStarted`, que es también el
  efecto ANTES de cancelar y el adopt que terminó bien: tiraba una cuenta ya adoptada o dejaba el efecto vivo a la espalda.
  Una cancelación diferida (la pre-espera del import vencida) dejaba la barra en 0 % con un «Retomar» que re-reclamaba. El
  `.onChange` que baja el diálogo colgaba del botón, que sale del árbol en la misma pasada: pasó al `body`. Y el botón
  deshabilitado parecía activo: ahora se atenúa.
- **Sin copy nuevo ni schema.** Tests: `WelcomeAdoptExitTests` y el source-scan de
  `ForwardStepCeilingLogicTests.adoptScreen_isWired` actualizado. 24 mutantes en dos tandas.
- **Sin device-QA:** montar el fallo exige que el reconcile falle 15 min en un iPhone con una cuenta real.

**Fuera, con su ticket:** la sesión que abrió el adopt sigue abierta al cancelar (`adopt-exit-keeps-the-session-it-opened`,
anotado); el «desde aquí» del diálogo en la bienvenida (`welcome-adopt-cancel-dialog-says-from-here`, producto); y el
«Reintentar» de `.adoptExit(.accountUnavailable)` (`welcome-adopt-exit-offers-retry-on-a-blocked-account`).
