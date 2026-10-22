---
id: adopt-effect-retries-forever-with-no-ceiling
status: done
priority: medium
area: "modo-nube, migración, adopt"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `an-incomplete-inventory-reads-as-the-whole-corpus` (2026-09-23), lente de desenlaces"
---

# Si entrar en tu cuenta de la nube no puede terminar, la app lo reintenta para siempre sin decírtelo

## El problema, en lenguaje de usuario

Entro en mi cuenta de la nube en un segundo teléfono. La app tiene que reconciliar lo que este teléfono tenía con lo
que ya está en la nube. Si esa reconciliación no puede terminar, la app lo reintenta cada vez que la abro, sin
decirme nada: la pantalla de Almacenamiento se queda como si no hubiera empezado, la sincronización no arranca y no
hay tarjeta ni salida.

## Por qué pasa (leído el 2026-09-23 en este árbol; no ejecutado)

`runAdoptOrphanReconcile` devuelve `.transient` → `runAdoptFlow` lanza `adoptRetry` → el runner deja el efecto
pendiente (`drainPendingEffects`, `Stop.effectFailed`) y `runGuarded` se lo traga. El par queda en
`(notStarted, pendiente)`, `startRuntimeIfStable` no arranca el motor y la pantalla pinta `.idle`. No hay techo ni
tarjeta: es el mismo hueco que `forward-migration-steps-have-no-ceiling-and-no-exit` cerró en los pasos de la ida.

Ya pasaba con la red (enumeración, Merkle, push). Desde `an-incomplete-inventory-reads-as-the-whole-corpus` pasa
también con una tabla local que no se deja leer, que es la causa que esperar NO arregla: antes de ese ticket el adopt
se completaba sin las huérfanas de esa tabla —pérdida silenciosa—; ahora no pierde nada, pero tampoco termina nunca.

Detalle de coste: cada intento enumera el backend entero y consulta `/sync/merkle` ANTES de leer el inventario local,
así que una avería local paga la red en cada reintento. Leer el inventario primero lo evitaría sin cambiar el
desenlace.

## Qué habría que decidir (es de producto)

1. ¿El adopt lleva techo, como los pasos de la ida? ¿Corto para la avería local y largo para la red?
2. ¿Qué ve la persona al vencer, y qué salida tiene? Ojo con `adopt-claim-stays-parked-with-no-ceiling`: la salida de
   la ida (`failedRollback` → «Reintentar» → `notStarted`) es un callejón para quien adopta.

## Criterios de aceptación

- [x] Decisión de Jürgen sobre techo, texto y salida (2026-09-23, 15:40 Lima; el texto, revisado con él tras la review).
- [x] Un adopt que no puede terminar por una causa que esperar no arregla sale con esa salida, con test.

## Relacionado

- `adopt-claim-stays-parked-with-no-ceiling` — el paso del claim del adopt (22 %), otro sitio del mismo flujo.
- `an-incomplete-inventory-reads-as-the-whole-corpus`.

## Decisiones (Jürgen, 2026-09-23)

1. **Techo**: 15 min ACUMULADOS con la base local que no se deja leer; 72 h desde el primer intento fallido con cualquier
   causa. La red pausa el reloj corto, no lo borra.
2. **Mientras espera**: Almacenamiento enseña la tarjeta de progreso con «Retomar» y «Cancelar la activación». Cancelar
   lleva a «Activar la nube en este dispositivo».
3. **Al vencer**: tarjeta de fallo con texto por motivo y «Reintentar», que lleva a «Activar la nube en este dispositivo».
   Textos: «No pudimos entrar en tu cuenta de la nube: este dispositivo no pudo leer tus datos para juntarlos con los de tu
   cuenta. Lo que tienes en este dispositivo sigue aquí; vuelve a intentarlo en un rato.» y «…la activación lleva días sin
   poder terminar. Lo que tienes en este dispositivo sigue aquí; vuelve a intentarlo más tarde.» (primera versión decía
   «Tus datos siguen en este dispositivo»; la review la cazó y Jürgen eligió el cambio).

El Paso 0 completo, con las decisiones técnicas y su revisión, está en el encargo
(`encargos/lanzados/2026-09-23-adopt-effect-retries-forever-with-no-ceiling.md`).

## Qué se hizo

- El ejecutor separa la avería local (`.localFailure` → `MigrationExecutorError.adoptLocalFailure`) de la red
  (`.transient`) en `runAdoptOrphanReconcile`, y lee el inventario una vez antes de la red.
- El runner observa cada fallo del efecto (`observeAdoptEffectFailure`), con dos relojes en `MigrationState.adoptEffectStall*`
  (schema 14), y sale a `failedRollback` con la marca del adopt (`AdoptClaimExit.effectLocalFailure` / `.effectStalled`).
  Sin techo si el modo `.cloud` ya está persistido. «Cancelar» con el efecto pendiente (antes de cada intento y al fallar).
- Almacenamiento pinta el efecto pendiente como progreso (fracción 0,6) con «Cancelar» y conserva la sección de Grupos.
- Tres claves nuevas en los 16 idiomas. Regla: «Y el EFECTO del adopt también» en `.claude/rules/swiftdata-cloudkit.md`.

## Verificación

- Suite unitaria completa en verde (7668 casos). 25 mutantes sobre las líneas que cargan el peso, todos muertos. Tests nuevos: `MigrationRunnerTests` §16, `MigrationStateMachineTests`
  (adoptEffect*), `MigrationWorkExecutorTests` (adopt*LocalFailure*, deriva del reloj), `AdoptEffectCeilingLogicTests`.
- Review adversarial de tres lentes (consumidores, relojes, tests y textos). Arreglado de ella: el texto «tus datos siguen
  aquí», el «Cancelar» que no paraba un intento que salía bien, la sección de Grupos que desaparecía, la ventana del guard
  anti-fusión, el registro de pt-PT y zh-Hans y dos tests que faltaban.
- Tickets nuevos de la review: `welcome-adopt-effect-failure-has-no-reason-and-no-cancel`,
  `adopt-exit-keeps-the-session-it-opened`, `adopt-effect-ceiling-never-sees-an-import-that-never-settles`,
  `adopt-effect-after-the-cloud-mode-retries-silently`; y una nota en `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved`.

## Device-QA

No hay: el escenario no se monta a voluntad en un iPhone (una base local que no se deja leer, 72 h sin red, o un efecto
que falle justo después del claim). Lo cubren los tests de lógica, del runner y los scans del cableado de la pantalla.
