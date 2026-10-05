---
id: detach-with-a-stuck-groups-drain-names-only-the-first-of-two-causes
status: done
priority: very-low
area: "grupos, sync, copy"
created: 2026-10-05
updated: 2026-10-05
source: "pariente de `groups-stuck-drain-on-a-healthy-phone-says-try-again-later` (encargo del 2026-10-05, punto 3)"
---

# Desasociar con el drain de Grupos atascado y la sesión caducada dice solo «tu sesión caducó»

## El problema, en lenguaje de usuario

Rarísimo: hacen falta dos fallos a la vez. Si este teléfono no consigue preparar para subir un cambio de tus grupos
—siempre, no una vez— **y además** tu sesión de grupos caducó, «Desasociar» dice «Tu sesión de grupos caducó. Entra otra
vez y vuelve a intentarlo». Es verdad, y volver a entrar hace falta igual. Pero no basta: al volver a intentarlo sale el
segundo aviso, «Algunos de los últimos cambios de tus grupos no se pudieron preparar… cierra y vuelve a abrir Yala; si sigue
pasando, actualízala». La persona se entera de los dos problemas de uno en uno. No se pierde nada.

Lo mismo con el teléfono sin App Attest en lugar de la sesión caducada: el desasociar dice primero lo del App Attest.

## Por qué pasa (medido en el código el 2026-10-05)

- `CloudSignOutFlowLogic.stuckCaptureVerdict`: con la captura atascada, si el último ciclo paró por un motivo que abre la
  salida de la pérdida (`lossCause`: sin App Attest, sin sesión, otra cuenta), devuelve ESE motivo. Es lo correcto en los
  cierres de sesión, porque su salida «Cerrar sesión y perderlos» cuenta también lo que el drain no capturó y lo resuelve
  todo de una vez.
- El desasociar comparte el push-all pero no ofrece esa salida (`detachGroupsAccount` pasa `lossExit: nil`, decisión de
  Jürgen del 2026-09-15). Así que allí el motivo del ciclo solo sirve para el aviso, y el aviso nombra una causa de dos.
- Cambiar qué texto gana, o juntar los dos, es una decisión de copy: no se tocó en el ticket padre.

## Propuestas (decide Jürgen)

- **A.** En el desasociar, con la captura atascada gana el drain: sale `.groupsCaptureUnfinished`. Cero copy nuevo. Pero
  quien arregle el drain (actualizando la app) se encuentra después con «tu sesión caducó»: también son dos pasos, en el
  otro orden, y el primer aviso calla algo que la persona podría arreglar ya.
- **B (recomendada).** Un texto propio que diga las dos cosas, solo para el desasociar: «Tu sesión de grupos caducó y
  algunos de los últimos cambios de tus grupos no se pudieron preparar para subirlos. No se pierden. Entra otra vez, cierra
  y vuelve a abrir Yala (si sigue pasando, actualízala) y vuelve a intentarlo.» Más el gemelo del App Attest. Es lo más
  honesto, y es lo que Jürgen suele preferir aunque cueste más: dos motivos o una marca en el bloqueo, y 2 textos × 16
  locales.
- **C.** Dejarlo como está. Cada aviso es verdad, y los dos pasos hacen falta igual; hacen falta dos fallos raros a la vez.

## Decisión

**Opción B**, decidida por Jürgen el 2026-10-05 a las 10:48, con su texto literal para la sesión caducada y el encargo de
redactar el gemelo del App Attest con el mismo criterio.

## Criterios de aceptación

- [x] Desasociar con el drain atascado y la sesión caducada (o sin App Attest) dice lo que hay que hacer para TODO.
- [x] Sin salida que pierda nada en el desasociar (decisión del 2026-09-15).
- [x] Los cierres de sesión no cambian: su aviso de pérdida ya cuenta lo que el drain no capturó.

## Hecho (2026-10-05)

**Para el usuario.** Si este teléfono no consigue preparar algún cambio de tus grupos **y además** tu sesión de grupos caducó
(o el teléfono lleva más de un día sin la verificación de seguridad, o hay cambios de otra cuenta), «Desasociar» dice las dos
cosas en un solo aviso y qué hacer para todo. Antes decía una, la persona la arreglaba y al reintentar le salía la otra.

**Cómo.** Un tipo propio del aviso del desasociar, `CloudSignOutFlowLogic.DetachBlockedNotice` (`.reason(motivo)` o
`.alsoCaptureUnfinished(causa)`), que decide una función pura, `detachBlockedNotice(reason:captureStuck:)`: dos causas solo con
la captura atascada **y** un motivo de `lossCause`. No es un `BlockReason` nuevo a propósito: ese enum lo comparten los
cierres, el desasociar y «Empezar de cero» con una docena de `switch` exhaustivos, y lo único que cambia es el texto de un
gesto. El coordinador lo decide con su testigo (`groupsCaptureStuck`), solo en el bloqueo del push-all;
`DetachOutcome.blockedBeforeWriting` lleva el aviso ya decidido y la sección de Ajustes lo pinta.

Medido al implementar: el desasociar recibe la combinación por **dos** caminos del push-all, no uno —el outbox a 0
(`stuckCaptureVerdict`) y las filas vivas con la re-captura atascada (`lossBlockAfterRecapture`)—, y llega también la tercera
causa, **otra cuenta** (todo lo que el drain no captura es de otra cuenta). Se trató con el mismo criterio: entrar con esa
cuenta no basta (el drain sigue atascado) y arreglar el drain tampoco (siguen siendo de otra cuenta).

**Textos** (es-419; 16 locales, es-AR en voseo, es-ES en pretérito perfecto, `es`/`pt` copias de su base):
- Sesión (literal de Jürgen): «Tu sesión de grupos caducó y algunos de los últimos cambios de tus grupos no se pudieron
  preparar para subirlos. No se pierden. Entra otra vez, cierra y vuelve a abrir Yala (si sigue pasando, actualízala) y vuelve
  a intentarlo.»
- App Attest: «Este teléfono lleva más de un día sin conseguir la verificación de seguridad que pide nuestro servidor, y
  algunos de los últimos cambios de tus grupos no se pudieron preparar para subirlos. No se pierden. Para que se preparen,
  cierra y vuelve a abrir Yala (si sigue pasando, actualízala).» Sin «y vuelve a intentarlo», a diferencia del de sesión:
  reabrir Yala cura el drain, no la verificación, y la review lo cazó como promesa falsa. El aviso del App Attest a secas
  tampoco promete nada.
- Otra cuenta: «Hay cambios de grupos que se apuntaron en este teléfono con otra cuenta, y solo se pueden subir con ella.
  Además, algunos de ellos no se pudieron preparar para subirlos. No se pierden. Cierra y vuelve a abrir Yala (si sigue pasando,
  actualízala) y entra con esa cuenta para que suban.»

**Tests.** `YalaTests/CloudSync/GroupsDetachTwoCausesTests.swift`: la lógica pura, el desasociar REAL por los dos caminos y
las tres causas con el ciclo y la captura sustituidos (más dos controles: la sesión caducada sin atasco y el atasco solo), y el
cableado y el copy (el literal de Jürgen, las 3 claves en los 16 locales). Rojo medido con la tubería puesta y la decisión de
antes (un solo motivo): 5 casos rojos, controles verdes.

**Sin device-QA ni capturas.** El aviso solo sale con un drain que falla en todos sus intentos y, a la vez, sesión caducada o
sin App Attest: ni el simulador ni un iPhone lo producen sin un seam de depuración en el coordinador, que nadie pidió. La
tubería nueva de la sección (el aviso por el retorno) la recorre el XCUITest
`GroupsAssociationRowUITests.test_detachWhenTheSessionSurvivesSignOut_stopsAndSaysSo`.

**Residuales, sin tocar** (los encontró la review adversarial; vienen del orden de prioridades de `stuckCaptureVerdict`, que
este ticket no cambia y que comparten los cierres):
- Sesión caducada y TODO lo atascado de otra cuenta: gana el motivo del ciclo, sale el texto de sesión («cambios de tus
  grupos» deja de ser exacto) y al reintentar sale el de otra cuenta.
- Filas de otra cuenta en el outbox con un cambio propio atascado: solo se nombra el atasco. Ticket
  `stuck-groups-drain-hides-held-rows-of-another-account`.
- «Sin dueño probado» cuenta como otra cuenta (`heldForAnotherAccount`), así que «entra con esa cuenta» puede no tener una
  cuenta concreta detrás. Lo hereda del aviso de otra cuenta a secas.
