---
id: activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable
status: done
priority: high
area: "onboarding, modo-nube"
created: 2026-09-14
updated: 2026-09-14
source: "review adversarial del PR de `activation-restore-start-fresh-keeps-the-imported-rows` (dos lentes, 2026-09-14); NO reproducido en device"
---

# «Empezar desde cero» sin red sigue sin borrar, y encima queda apuntado para un borrado peor

## El síntoma, en lenguaje de usuario

Estoy activando Yala completo, he visto mis datos viejos y he tocado «Empezar desde cero». La app va a
comprobar qué hay en mi iCloud y **se cae la red**. Me dice «No pudimos revisar tu iCloud» y me ofrece
«Seguir así». Sigo… y mis datos viejos están todos ahí. Nadie borró nada, aunque yo lo confirmé.

## Lo medido (2026-09-14, en el PR que cierra `activation-restore-start-fresh-keeps-the-imported-rows`)

- Tres salidas de `WelcomePrivateICloudGateView` llaman a `onProceed()` **sin pasar por `performWipe`**:
  `continueWithoutValidating()` (`:479-483`, el botón de `.noICloud` y la acción secundaria de
  `.unreachable`), `case .proceed` (`:586-593`) y el atajo de `isUITesting` (`:553-556`).
- En la puerta del chooser (`.privateGate`) eso es un daño menor: se llega **antes** del relanzamiento y
  el corpus todavía no ha bajado al teléfono. En `.restoreDiscardGate` no: ahí **hubo relanzamiento**, el
  store espeja, y las filas importadas ya están en el dispositivo. Es el bug del ticket padre por otra
  rama, bajo un copy que promete lo contrario.
- **Y el daño encadenado es peor que el hueco.** `continueWithoutValidating` escribe
  `markPrivateChoseWithoutICloud()`. Cuando la activación termine y la sesión sea privada,
  `runLateICloudMirrorCheck` ofrecerá el aviso del espejo tardío, cuyo borrado es
  `performICloudCorpusWipe(.handover)` (`ContentView.swift:330`) — preferencias, purga del dominio de
  Grupos y `hasCompletedOnboarding = false`. O sea: el scope que el ticket padre argumenta que **no**
  puede aplicarse a quien acaba de activar conservando sus grupos.
- `.noICloud` es inalcanzable por este camino (para llegar hubo que encontrar corpus en iCloud). El caso
  real es `.unreachable`: la red se cae en la ventana entre el relanzamiento y la sonda.

## Qué hay que decidir

1. ¿Qué se le ofrece a quien confirmó «empezar de cero» y no se pudo preguntar a iCloud? Las tres
   opciones razonables: **(a)** devolver a Restaurar sin declarar nada (no se promete un borrado que no
   ocurrió); **(b)** borrar solo lo local, que sí está aquí, y dejar la zona para el aviso tardío;
   **(c)** dejarlo como está y avisar con copy honesto.
2. Si se elige (b) o (c): el aviso del espejo tardío tiene que dejar de usar `.handover` para quien salió
   por aquí, o se llevará los grupos.

## Criterios de aceptación

- [x] Tras confirmar «Empezar desde cero» sin red, la app **no declara** un borrado que no ocurrió.
- [x] El aviso del espejo tardío que llegue después **no purga el dominio de Grupos** de quien activó
      conservándolos.

---

# Cierre (2026-09-14)

**Decisión de Jürgen: (a).** Devolver a Restaurar sin declarar ningún borrado. Con (a) no se elige
(b)/(c): no hay que cambiar el aviso del espejo tardío por este camino, porque este camino deja de
escribir el testigo que lo levanta.

## Qué cambia para quien usa Yala

Usas Yala solo para grupos, decides activar Yala completo, y en «Restaurar» tocas **«Empezar desde
cero»**. La app va a mirar qué hay en tu iCloud y no lo consigue —se cae la red, o iCloud está apagado en
el teléfono—. **Antes** te decía «Seguir así», te llevaba al onboarding, y tus datos viejos seguían
enteros: un borrado que nunca ocurrió, anunciado como si hubiera ocurrido. **Ahora** te dice que no pudo
mirar, que **no borró nada**, y te devuelve a la pantalla anterior con las dos opciones abiertas —
reintentar, o traerte tus datos—. Nadie decide por ti mientras no se pueda comprobar.

Y se cierra el daño de detrás, que era el peor y no se veía: aquel «Seguir así» dejaba la app **apuntada**
para el aviso del espejo tardío, cuyo botón de borrar se lleva las preferencias y **los grupos**. O sea
que quien activaba Yala completo justo para conservar sus grupos podía acabar sin ellos, arranques
después, por una red que se cayó dos segundos.

## El arreglo

`WelcomePrivateICloudGateView` gana un parámetro **`unverifiedExit`**, un enum de dos casos y **sin
default**, por lo mismo que `deviceCorpus`: la vista la montan tres sitios y contestan cosas opuestas, así
que el compilador obliga a cada uno a pronunciarse. Un default heredaría el desenlace de uno de los dos, y
eso es exactamente la forma del bug — la puerta de «Empezar desde cero» nació reusando esta vista y se
trajo la salida de la otra sin que nadie lo decidiera.

| montaje | `unverifiedExit` | qué hace sin respuesta de iCloud |
|---|---|---|
| Welcome (`WelcomeFlowContainer`) | `.proceedWatchingTheMirror` | sigue, y escribe el testigo del espejo tardío |
| activación · `.privateGate` | `.proceedWatchingTheMirror` | ídem — aquí nadie ha pedido borrar todavía |
| activación · `.restoreDiscardGate` | `.returnWithoutClaimingAWipe` | **retira el arm y vuelve a Restaurar**, sin escribir nada |

Las fases `.noICloud` y `.unreachable` salen las dos por `exitWithoutValidating()`, el **único** sitio que
bifurca: repetir ese `switch` en cada fase es como una de las dos se queda atrás.

**El arm sí se retira, y eso no es alcance nuevo: es no-regresión.** `continueWithoutValidating` ya
llamaba a `discardPendingWipe()` en este mismo punto. Y es correcto por su propio criterio: un borrado que
ni se pudo medir no deja nada a medias que proteger, mientras que un arm superviviente lo **reanuda a
ciegas** en el arranque siguiente, con ese mismo `.handover`.

## Lo medido que CONTRADICE al ticket

**`.noICloud` sí es alcanzable por este camino.** El ticket lo daba por imposible «porque para llegar hubo
que encontrar corpus en iCloud». Medido: `WelcomeRestoreView` ofrece «Empezar desde cero» desde cuatro
estados y **tres de ellos no afirman que haya datos** — `notFoundView`, `iCloudDisabledView` y `wipedView`
llaman a `onStartFresh()` directo, sin el diálogo de confirmación (fijado en
`RestoreStartFreshGateTests:359-368`). Con iCloud apagado en el teléfono la pantalla lo dice y ofrece el
botón igual, la sonda contesta `.noAccount`, y la puerta cae en `.noICloud` con el borrado ya pedido.
Arreglar solo la fase que el ticket nombra habría dejado la misma clase de bug viva en una esquina
alcanzable — el fix heredando la forma del bug.

## Copy

Tres claves nuevas en los 16 locales: `welcome.privateICloud.discardUnverifiedBody` (red caída),
`discardUnverifiedNoAccountBody` (sin cuenta) y `discardUnverifiedBack` (la salida). Los títulos se reusan.
Los cuerpos de siempre no valían porque prometen el camino que ya no existe — `errorBody` dice «Inténtalo
otra vez **antes de seguir**» y `noAccountBody` «**Puedes seguir**: por ahora tus datos se quedan aquí»—, y
el criterio nº1 de este ticket es justamente no declarar lo que no pasó.

**Y son DOS cuerpos, no uno, porque la review lo midió**: con uno compartido, el estado K repetía su propio
título («No pudimos revisar tu iCloud» + «No pudimos revisar qué hay en tu iCloud») en los 16 locales, y
perdía lo único accionable que `noAccountBody` sí decía —**que iCloud está apagado en este teléfono**—, que
es justo lo que el botón «Reintentar» de esa fase necesita para significar algo.

## Lo que queda FUERA, y por qué

- **El atajo de `isUITesting` en `measure()`** es hermeticidad de test, no un camino de producción: bajo
  XCUITest no se toca CloudKit en ningún punto del Welcome, y el docblock defiende que el recorrido
  determinista quede byte-idéntico. Cambiarlo rompería esa identidad sin arreglar nada vivible.
- **`case .proceed`** no cae en el supuesto de (a): ahí a iCloud **sí** se le preguntó, y contestó que la
  zona está vacía, así que no hay ningún borrado que declarar. El residuo teórico —zona vacía con filas
  importadas todavía en el teléfono— exige que otro dispositivo vacíe la zona en la ventana entre el
  restore y la sonda; si aparece, es ticket propio y su arreglo es borrar lo local, no volver atrás.
- **`wipeDevice(iCloudUnverified:)`** sigue llamando a `continueWithoutValidating()` directo y no al
  bifurcador, a propósito: el desenlace que vuelve atrás existe para no declarar un borrado que no
  ocurrió, y allí **ocurrió**. Además hoy es inalcanzable desde la activación (los dos montajes pasan
  `deviceCorpus: nil`).
- **La rama `.proceed` con la zona vacía y las filas ya importadas** — la review la cazó y no cae en el
  supuesto de (a): ahí a iCloud sí se le preguntó. Ticket propio:
  `discard-gate-proceed-leaves-the-imported-rows-behind`.
- **La misma puerta en el Welcome sigue diciendo «Puedes seguir»** tras pedir un borrado. Medido: allí el
  MECANISMO es correcto —la puerta recibe `deviceCorpus`, así que con datos locales borra, y su testigo
  levanta un `.handover` que ahí sí es el scope que toca—, con lo que es copy y no datos. Ticket propio:
  `welcome-discard-gate-says-carry-on-right-after-asking-to-wipe`.
- **(b) y (c)**, el wipe de producción y `marketing/`, intactos.

## Cobertura

`unit:YalaTests/WelcomePrivateICloudGateWiringTests` — `unverifiedExit_pairsEachOutcomeWithItsBranch`
(el par `case` → llamada en la misma línea, más las dos ausencias de la salida nueva) y el par
montaje ↔ salida con **prohibición del opuesto** en las dos puertas, dentro de
`activationNeverAsksAboutTheDeviceCorpus`. **Cinco mutantes verificados**, los cinco en rojo:

| mutante | qué cae |
|---|---|
| swap del desenlace en `.restoreDiscardGate` | `activationNeverAsksAboutTheDeviceCorpus` (2 issues) |
| el Welcome pasa el desenlace de la otra puerta | `gateProceed_crossesThePortal` |
| las dos ramas del bifurcador, invertidas | `unverifiedExit_pairsEachOutcomeWithItsBranch` (2) |
| el arreglo revertido (las dos fases llaman directo al que sigue) | `lateWitness_writtenOnContinueOnly` (2) |
| la salida nueva vuelve a escribir el testigo | el conteo `== 1` + la ausencia (2 tests) |
| la salida nueva deja el arm puesto | `unverifiedExit_pairsEachOutcomeWithItsBranch` |
| el chevron vuelve a dejar el arm puesto | `backButton_discardsTheArmWhenNothingCouldBeMeasured` |
| el estado K que vuelve pierde su «Reintentar» | `noICloud_offersRetryOnlyWhereTheRemedyExists` (3) |
| la rama que sigue gana un «Reintentar» que no puede hacer nada | ídem (2) |
| los dos botones de `.unreachable`, intercambiados | `lateWitness_writtenOnContinueOnly` (2) |
| el label dice «Seguir así» mientras vuelve | `unverifiedCopy_matchesItsOutcome` |
| el estado K usa el cuerpo de la red caída | ídem |
| el parámetro gana un valor por defecto | ídem |
| el copy nuevo deja de nombrar iCloud | `copy_isOwnAndNamesICloud` |

## La review adversarial (3 lentes) cazó SEIS defectos míos, tres con cambio de código

El peor: **extender (a) al estado K creaba un camino muerto de dos pantallas.** `.noICloud` se pintaba con
un CTA único que devolvía a Restaurar, y Restaurar con iCloud apagado ofrece «Abrir Ajustes» y «Empezar
desde cero» — o sea que las dos pantallas se devolvían la pelota y la activación no se podía terminar desde
dentro. Hoy esa fase ofrece **«Reintentar búsqueda»** cuando vuelve, y su cuerpo dice la causa y el remedio.
Es el mismo «camino muerto» que la review de septiembre le cazó a `.unreachable`, repetido por mí en la
fase de al lado.

Los otros cinco: **el chevron salía sin retirar el arm** —dos controles al mismo destino con efectos
durables distintos, y el arm superviviente lo reanuda a ciegas con `.handover`—; el cuerpo compartido
repetía el título y tiraba la causa; **nadie miraba el copy por desenlace**, así que un mutante dejaba la
puerta diciendo «Seguir así» mientras volvía; nada fijaba el «sin default» del parámetro; y una errata en
el literal de un accessor salía a pantalla como clave cruda sin que la paridad la viera.

**Y un séptimo, que es mío y de método:** el primer `noICloud_offersRetryOnlyWhereTheRemedyExists` era un
**falso verde**. Su tramo iba hasta el final del cuerpo, así que un mutante que quitara el «Reintentar» y
dejara un `twoWayNoticeContent` en un `case` de más abajo lo cumplía igual. Lo descubrió el mutante, no la
lectura. Hoy el tramo se acota por el `case` siguiente.

**Device-QA:** las dos fases no son alcanzables en simulador — `measure()` sale por `isUITesting` antes de
la sonda, y `ICloudPersonalCorpusProbe` no tiene seam de uitest. Ticket:
`tickets/qa/device-qa-discard-gate-returns-to-restore-without-icloud.md`.
