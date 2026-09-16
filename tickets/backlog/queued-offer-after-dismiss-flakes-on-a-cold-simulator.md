---
id: queued-offer-after-dismiss-flakes-on-a-cold-simulator
status: backlog
priority: low
area: "testing, xcuitest, presentaciones"
created: 2026-09-15
updated: 2026-09-15
source: "gate de `cloud-signout-collapses-a-groups-session-expiry-into-permanent` (2026-09-15)"
---

# La oferta que espera en la cola a veces no aparece al cerrar la hoja, con el simulador recién arrancado

## Lo que pasó (medido)

`AppleIDCloseNoticeUITests.test_notice_presentsThroughTheQueue_andLaterReleasesTheRouter` cayó en su línea 86:
la oferta de prueba (`trial_offer_dismiss`) no apareció en los 45 s siguientes a tocar «Ahora no» en la hoja del
cambio de Apple ID. Fueron cuatro corridas del mismo binario (`test-without-building`), las cuatro con el
centinela del simulador sin intrusos:

| Corrida | Simulador | Caso | Duración |
|---|---|---|---|
| 1.ª | caliente; la corrida murió después, en otra clase, por falta de memoria del sistema | pasa | 23,2 s |
| 2.ª | **recién arrancado**: el apagón de la 1.ª lo dejó apagado | **falla** | 68,3 s |
| 3.ª | caliente | pasa | 22,7 s |
| 4.ª | caliente | pasa | 23,0 s |

Entorno durante las cuatro: 48 procesos `claude` vivos en la máquina y la swap entre 2,9 y 3,2 GB de 4.

**No lo introdujo el cambio de ese gate**: solo tocaba la traducción del motivo en el cierre de la nube, y este
test recorre la celda privada y la oferta en cola. Eso se razona leyendo el test; lo medido es que el mismo
binario pasa 3 de 4.

## Por qué tiene ticket aunque «la primera corrida tras arrancar no cuenta»

`.claude/rules/testing.md` da esa explicación por buena, pero la midió en iOS 27.0 y dice que en 26.x «se
absorbe». Esto es 26.5 y no se absorbió. Y es el segundo rojo de esta forma en dos días: el cierre del #168 anotó
que `RemoteWipeNoticeRoutingUITests` cayó una vez con el paywall sin presentar y dio 3 de 3 aislado, con la
hipótesis de una carrera entre drenar la cola y desmontar el aviso. Ese dato no está en ningún ticket y aquí se
cita de oídas. Con dos casos no se distingue latencia de carrera.

## Lo que hay que medir

1. **N corridas en frío contra N en caliente** del mismo caso, con `simctl shutdown` y `boot` antes de cada
   corrida fría. Si solo cae en frío, es latencia: basta con calentar el simulador antes o con subir la espera.
2. **Si también cae en caliente**, instrumentar el drenaje de la cola al cerrar la hoja. Si drena mientras la
   hoja se desmonta y la oferta se pierde, es la carrera de dos presentaciones del mismo anchor
   (`.claude/rules/swiftui-ds.md`), y eso sí le pasa a una persona.

## Criterios de aceptación

- [ ] Clasificado con los números del punto 1: latencia o carrera.
- [ ] Si es carrera, arreglada y con un test que la reproduzca antes del arreglo.

## Cae también con el simulador CALIENTE, y la MISMA compilación cae 1 de 3 (medido el 2026-09-15)

Gate de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`. **Trece corridas del mismo caso**,
todas con el centinela en 0 —vigilada la corrida entera, no la foto de antes—, así que en ninguna hubo intrusos.

**El punto 1 de «Lo que hay que medir» queda contestado: no es solo el simulador frío.**

| Configuración | Simulador | Corridas | Resultado |
|---|---|---|---|
| árbol de trabajo (con el cambio del gate) | frío y caliente | 3 | **falla** ×3 (68,99 · 67,85 · 72,17 s) |
| árbol base `da26ad18a` y ocho variantes del cambio | caliente | 8 | pasa ×6 (22,7-25,9 s), **falla** ×2 (67,96 · 68,85 s) |
| una MISMA compilación, repetida | caliente | 3 | pasa (22,69) · **falla** (66,98) · pasa (22,67) |

**El dato que más ahorra tiempo al siguiente: la misma compilación, sin tocar nada, cae 1 de 3.** Una bisección
con N=1 por variante separa azar y no causa — esta sesión gastó nueve corridas construyendo una explicación
falsa («cierta forma del `.alert` rompía la cola») antes de que la repetición la tumbara.

**Duraciones bimodales**: 22-26 s cuando pasa, 67-72 s cuando falla (el tope de 45 s del `waitForExistence` más
el recorrido). Nunca nada intermedio, en trece corridas.

**Lo que ya está descartado por medición**, para no repetirlo: concurrencia (centinela 0 ×13) · el simulador frío
como condición necesaria · la racha de App Attest en el simulador (la clave no existe en las preferencias de
ninguna de las dos apps) · cualquier código que corra en ese arranque sin gesto.

**Lo que se ve al fallar** (jerarquía de accesibilidad del propio fallo, adjunta al `.xcresult`): el Panel normal,
sin hoja, sin `Sheet`, sin `Alert` y sin la oferta. La hoja SÍ se cerró —su `waitForNonExistence` de 10 s se
cumple—, así que lo que no vuelve a ocurrir es el drenaje.

⇒ **Siguiente paso, el punto 2 de este ticket, ahora con su premisa medida:** instrumentar el drenaje al cerrar la
hoja (¿se llama al drain?, ¿la condición viva sigue puesta?, ¿la matriz recalcula?) y subir la espera a 120 s en
una corrida de sonda, para separar «tarda más de 45 s» de «no vuelve a drenar nunca». **Lo segundo sí le pasa a
una persona**: se queda sin avisos de bandeja, sin paywall y sin invitaciones de grupo hasta relanzar la app.

**Y el título de este ticket promete de menos**: «on a cold simulator» era la hipótesis de su primera muestra, no
una condición. Conviene renombrarlo cuando se clasifique.

### El entorno, medido mientras esto pasaba (2026-09-15, tarde)

No es color: es la única variable que se movió y que tiene efecto comprobado.

- **El sistema MATÓ una tanda de seis corridas por falta de memoria**, a la segunda. No es una inferencia sobre
  lentitud: el proceso murió por presión de memoria.
- En ese momento: **16 procesos `claude` vivos** (más 28 de la app de escritorio), **swap 4,64 GB usados de
  6,14**, y **0,5 GB de páginas libres** de 16 GB físicos.
- El ticket anotaba en su primera muestra «48 procesos claude y swap 2,9-3,2 GB de 4». O sea: las dos veces que
  este caso cayó, la máquina estaba estrangulada de memoria.
- Disco entre 8 y 15 GB durante la tanda, por debajo del rango donde `.claude/rules/testing.md` midió que no
  distinguía nada (12 GB). Se limpió con la receta del simulador entre tandas.

**Es correlación, no causa demostrada** — pero acota qué medir: el caso espera 45 s a que una presentación en
cola aparezca, y es exactamente el tipo de aserción que una máquina sin memoria convierte en rojo sin que haya
ningún bug. ⇒ **antes de instrumentar el drenaje, repetir la tanda con la máquina descargada** (sin otras
sesiones de Claude Code corriendo XCUITest). Si con memoria libre no cae en N corridas, el ticket se cierra como
«el entorno, no el producto», y lo que hay que arreglar es el tope de espera o la cadencia del gate, no la app.

### Y el cierre de la medición: la MISMA configuración pasa 4 de 4 después

Sin tocar una línea, el árbol que había fallado 3 de 3 volvió a correrse cuatro veces más: **pasa 26,79 ·
24,56 · 24,00 · 24,13 s**. Con eso, el recuento de las **19 corridas** de este caso en la sesión queda así:

| Configuración | Corridas | Fallos |
|---|---|---|
| árbol con el cambio del gate | 7 | 3 |
| ocho variantes del cambio | 8 | 2 |
| la misma variante repetida ×3 | 3 | 1 |
| árbol base limpio (1 con veredicto, 1 murió por memoria) | 1 | 0 |

**Los fallos se reparten entre configuraciones idénticas entre sí**, así que no hay señal en el código: es el
entorno. Y el corolario para quien venga: **con una tasa así, ninguna bisección de este caso significa nada por
debajo de N≈10 por rama.**
