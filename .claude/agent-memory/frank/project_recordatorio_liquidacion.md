---
name: recordatorio-liquidacion-cerrado-en-codigo
description: El nudge de deuda de grupo está en 2.1 (PR #89) desde el 2026-09-07. Falta device-QA y una decisión de Jürgen sobre descubribilidad; y queda escrito por qué NO se respeta simplifyDebts, que es lo que más se va a querer «arreglar» sin leer.
metadata:
  type: project
---

**Estado: en `2.1` (PR #89, mergeado el 2026-09-07). El ticket está en `qa/`.**

Si le debes dinero a alguien en un grupo y esa cuenta lleva tres semanas sin moverse, Yala avisa al
**deudor** (decisión del owner del 6-sep), una vez por grupo aunque debas a varias personas, sin
repetir antes de una semana. Nace **apagado**. V1 sin tocar el schema de CloudKit: el rate-limit
vive en `UserDefaults`.

## Lo que espera a Jürgen

- **Device-QA**: los cuatro gates end-to-end, el deep link y el texto renderizado. Área
  `groups-settlement-reminders` en el coverage-index, clasificada `manual` — la entrega depende del
  reloj real y del permiso de notificaciones, nada de eso es determinista en XCUITest.
- **`groups-settlement-reminder-discoverability` — decisión suya, y es la que importa.** Tal como
  está, el feature funciona y **casi nadie lo va a recibir**: nace apagado, no entra en el primer de
  notificaciones (donde sí se enciende su hermano `budgetAlertsEnabled` — heredé el default sin
  heredar el encendido) y depende de un segundo interruptor invisible, el `NotificationItem` de
  Grupos, que también nace apagado y de cuya dependencia nada avisa.
- **`groups-settlement-reminder-stale-clock`**: el reloj no ve las ediciones de un gasto viejo ni
  los pagos retro-fechados. Pide campo nuevo y migración de schema.

## La decisión que alguien va a querer revertir sin leer

**No se respeta `SplitGroup.simplifyDebts`: el aviso usa deudas DIRECTAS siempre.** Parece un bug —
el importe del push puede no coincidir con la fila que enseña la pantalla en un grupo con
simplificación — y está puesto a propósito, con el caso numérico en el docblock del servicio.

El motivo: con simplificación, la arista «yo → X» es un **enrutado de mínimo flujo de caja calculado
sobre saldos de terceros**, no una deuda con historia entre X y yo. Y este feature no muestra un
saldo: **afirma una antigüedad**, y ese reloj solo existe por par directo. Sin ello el aviso podía
decir «lleva semanas quieta» sobre dinero de anoche con un importe 7,6× el real, y el rate-limit se
rompía porque su clave (`Debt.id`) cambiaba cuando dos personas ajenas se pagaban algo.

⇒ **si alguien viene a «alinearlo con la pantalla», eso ES el mutante.** La primera versión lo tenía
así y la review adversarial lo tumbó.

## Dos piezas que toqué y no son mías

- **`Debt` es `nonisolated`** desde este PR. Un value type `Sendable` de cuatro campos no necesita
  actor, y sin la anotación el default del target aísla su `id` computado, que la lógica pura usa
  como clave de dedup: warning hoy, error en Swift 6.
- **El conteo de call-sites de `GroupChannelFreshness` pasó de tres a cuatro**, y el cuarto **no
  hace la misma pregunta que los otros tres**: ellos preguntan «¿puedo afirmar que esto NO EXISTE?»,
  este «¿está completa mi foto de deudas?». Por eso exige `belongsToBackendChannel` además de
  `isFresh` — el gate concede `.fresh` incondicional a una zona sin canal, que para el editor es
  correcto y aquí significa lo contrario.

Ver [[feedback_review_adversarial_caza_lo_mio]] para cómo salieron los dos.
