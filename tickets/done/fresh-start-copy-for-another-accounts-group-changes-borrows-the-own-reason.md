---
id: fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason
status: done
priority: low
area: "grupos, copy"
created: 2026-10-05
updated: 2026-10-05
qa-status: not-replicable
qa-notes: el estado con cambios de otra cuenta atrapados no se provoca a mano ni en el simulador; cubierto por unit con espejo y reglas de dueño reales
source: "review adversarial de `fresh-start-drops-mirror-entries-of-another-identity-without-counting-them` (2026-10-05, lente de verdad del copy)"
---

# «Empezar de cero» cuenta los cambios de otra cuenta, pero los explica con el motivo de los tuyos

## El problema, en lenguaje de usuario

Desde el 2026-10-05, «Empezar de cero» cuenta también los cambios de grupos de OTRA cuenta que guarda este teléfono, porque
el borrado se los lleva. Cuando solo quedan esos, el aviso es exacto: «solo pueden subir con la cuenta que los apuntó, y la
sesión abierta en este teléfono es de otra». Pero cuando además hay cambios tuyos que no suben por otro motivo, la cifra
incluye los de la otra cuenta y el texto habla solo del motivo de los tuyos. No se pierde nada sin aviso: lo que no encaja
es la explicación.

## Los casos (medidos leyendo el código el 2026-10-05; ninguno se ha visto en pantalla)

1. **Tu cuenta no está disponible (`.permanent`) y hay cambios de otra cuenta.** El texto `groups.freshStartPending.lossPermanent`
   dice que la cuenta que los apuntó ya no puede subirlos y que volver a intentarlo no lo arregla. Para los de la otra cuenta
   es falso: nadie lo ha intentado con su cuenta, y entrando con ella subirían. Es el único caso en que alguien puede aceptar
   perder cambios recuperables creyendo que no tienen arreglo. Hacen falta las dos cosas a la vez.
2. **Un motivo pasajero (`.uploadRetryLater`, `.transient`, `.channelPaused`, `.groupsCaptureUnfinished`) y cambios de otra
   cuenta.** El texto dice «inténtalo en un rato», «espera unos segundos» o «cierra y vuelve a abrir Yala», y la cifra suma los
   de la otra cuenta. Esperar sube los tuyos, no los suyos: el intento siguiente vuelve a bloquear, ahora con el motivo de
   «otra cuenta» y la salida de perderlos. No miente sobre los datos; promete que esperar arregla N cambios.
3. **Solo cambios de otra cuenta con tu sesión abierta.** El texto `groups.freshStartPending.lead` y el «¿seguro?»
   (`lossConfirmBody`) dicen «cambios de **tus** grupos». Preexistente: es el mismo texto que ya salía con filas vivas de otra
   cuenta. Y `lossOtherAccount` dice «esa cuenta», en singular, aunque pueden ser varias.
4. **El aviso del alert de la pantalla principal (`ShellDataAlertsModifier.refuseWhileGroupsArePending`).** Con el onboarding
   ya completo, no pasa por la puerta que sube y ofrece perderlos: dice «inténtalo de nuevo en un rato» siempre. Con cambios que
   solo sube otra cuenta, eso no se cumple nunca. Sin sesión ya pasaba; con sesión es nuevo desde el 2026-10-05 (antes se
   borraban sin aviso). **Sin verificar que ese alert se pueda presentar con el onboarding completo**: su único disparador vive
   en la bienvenida (`ContentView.startFreshPrivateOnboarding`). Medirlo es el primer paso.

## Por dónde va (decisión de producto)

- **A.** Separar la cifra: «N cambios tuyos que no han subido (motivo) y M de otra cuenta que solo puede subir ella».
  Exacto, pero son dos textos más en 16 idiomas.
- **B.** Dar precedencia al motivo de «otra cuenta» cuando haya cambios de otra cuenta: un solo texto, y los tuyos se explican
  en el intento siguiente.
- **C.** Dejarlo así: el orden de los avisos lleva siempre a la salida correcta, y los casos 1 y 2 piden dos fallos a la vez.

El caso 4, si resulta alcanzable, va aparte: es un bucle sin salida, no un matiz de texto.

## Decisión (Jürgen, 2026-10-05, tarjeta `tablero-decidir-empezar-de-cero-explica-los-camb-n3k4`)

**A.** Separar la cifra, cada parte con su motivo. La persona no puede aceptar perder lo que el aviso no le explicó bien.

## Qué cambia para el usuario

- Con cambios tuyos sin subir **y** cambios de otra cuenta, el aviso de «Empezar de cero» dice cuántos son de cada clase
  («Tuyos: 2. Apuntados con otra cuenta: 3.»), el motivo de los tuyos, que los de otra cuenta solo suben entrando con la
  cuenta que apuntó cada uno —esperar no los sube—, y qué hace el botón (perderlos todos) o, sin botón, que si los tuyos
  llegan a subir podrá perder solo los de la otra cuenta. El «¿seguro?» repite la cifra partida.
- Con solo cambios de otra cuenta: sin «tus grupos» en el título, el aviso ni el «¿seguro?»; y sin «esa cuenta» en
  singular.
- Con solo tuyos, o sin sesión: el texto de siempre.
- Lo que se borra, la cifra total y las salidas no cambian.

## Qué se hizo

- `FreshStartGroupsBlock.anotherAccountCount`: de la cifra, cuánto solo lo sube otra cuenta (filas retenidas, entradas
  del espejo de otra cuenta y, con el drain atascado, los cambios del History que el registro atribuye a otra cuenta).
- `CloudSignOutFlowLogic.freshStartGroupsCopyShape`: solo tuyos / solo de otra cuenta / las dos (partida o sin partir).
- `SignOutBlockedCopy`: título, aviso y «¿seguro?» por forma; `retryOffersTheLossExit` por pantalla (el alert del shell
  no promete una salida que no tiene).
- 12 claves nuevas y `lossOtherAccount` reescrita, en los 16 locales.
- En la subida sin salida, con filas retenidas, la cifra no se parte (texto neutro): esa cifra unas veces las incluye y
  otras no (ticket `fresh-start-block-count-without-the-loss-exit-sometimes-omits-held-rows`).

## Caso 4

Alcanzable leyendo el código: ticket `fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes`.

## Sin device-QA, y por qué

Como sus hermanos (`fresh-start-drops-mirror-entries-of-another-identity-without-counting-them`,
`groups-outbox-rows-without-a-live-session-have-no-exit`): hace falta un cambio de grupos de otra cuenta atrapado en este
teléfono (una sesión que caducó o un kill a mitad del drain) junto a cambios propios que no suben, y eso no se provoca a
mano. El simulador tampoco: el `sub` de la sesión no se puede fingir, a propósito. Por eso tampoco hay capturas.

Lo cubren los unit de `YalaTests/CloudSync/FreshStartSplitCopyTests.swift`, con el espejo, el filtro de alcance y la regla
de dueño REALES: los tres casos del ticket medidos en rojo antes del arreglo (7 aserciones) y en verde después, la tabla
de formas, cada motivo con las dos clases, y el cableado de las tres pantallas.
