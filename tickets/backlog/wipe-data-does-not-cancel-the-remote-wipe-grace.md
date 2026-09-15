---
id: wipe-data-does-not-cancel-the-remote-wipe-grace
status: backlog
priority: medium
area: "settings, sesiones"
created: 2026-09-14
source: "review adversarial de `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`, lente de caminos"
---

# «Vaciar datos» es el único borrado deliberado que no avisa a la cuenta atrás de los cinco segundos

## El síntoma, en lenguaje de usuario

Vacías tus datos desde Ajustes. Cinco segundos después la app te dice que **te los han borrado desde
otro dispositivo** y te ofrece empezar de cero. Los borraste tú, en este teléfono, hace cinco segundos.

## Lo medido (2026-09-14)

`ContentView` arranca una gracia de 5 s cuando `hasPersonalData` cae de `true` a `false`, para
distinguir un hueco transitorio de CloudKit de un vaciado remoto de verdad. Por eso **todos** los
borrados deliberados la cancelan antes de bajar la señal: el «empiezo de cero» del Welcome
(`ShellDataAlertsModifier`, vía `onCancelWipeGrace`), el borrado del corpus del dispositivo, el de la
puerta privada, el de «Restaurar → empezar desde cero». Cada uno con su comentario explicando por qué.

**`UserDataResetView.handleWipeAllData` no la cancela**, y el `onChange` tampoco mira `isWipingData`
—que además se apaga a los ~800 ms, mucho antes de que venza la gracia—.

Hasta hoy eso no se veía porque en la celda privada el barrido se lleva `hasCompletedOnboarding`, y el
`onChange` exige ese flag para arrancar. En **solo-grupos** no: `applyWipeLanding(.groupsShell)` lo
repone a mano —a propósito, la app sigue enseñando los grupos— así que la gracia arranca.

## Por qué sigue abierto aunque el aviso ya esté callado

`wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal` puso el eje de sesión delante del
aviso, y en solo-grupos el eje da `false`, así que **hoy no se ve**. Pero lo que lo tapa es el eje, no
la causa: la gracia sigue arrancando por un borrado que este mismo teléfono acaba de hacer. Si mañana
cambia el aterrizaje de `.groupsShell`, o aparece otra celda que reponga `hasCompletedOnboarding` tras
vaciar, el aviso vuelve — y esta vez sin que nadie recuerde por qué.

El arreglo es el que ya usan los otros cuatro caminos: cancelar la gracia en el sitio que borra a
propósito, antes de que la señal baje.

## Criterios de aceptación

- [ ] «Vaciar datos» cancela la gracia antes de que `hasPersonalData` caiga, como sus cuatro hermanos.
- [ ] Un test fija que los borrados deliberados que reponen `hasCompletedOnboarding` la cancelan.
- [ ] Verificado con el eje de sesión FORZADO a `true`, o el arreglo no se puede distinguir del tapón.

## Y hay una SEGUNDA celda, medida el 2026-09-14 (tarde) — la del restore remoto

Sale de la review de `remote-wipe-alert-skips-the-router`, y es el mismo patrón con otro culpable:
**`ContentView.performLocalWipeForRemoteSync`, rama `skipOnboarding: true`.** Ese es el camino del
«ya terminaste el onboarding en otro dispositivo»: borra lo local, **repone
`hasCompletedOnboarding = true`** y enseña el toast positivo «tus datos están aquí».

Al reponer el flag deja el guard del `onChange` abierto, exactamente igual que
`applyWipeLanding(.groupsShell)`. Y `hasPersonalData` sí cae: lo recalcula el `onChange` de
`dataVersion` (`ContentView`), que el propio `wipeAllUserData` bumpea. Así que la gracia arranca
**después** de un borrado que la app acaba de hacer a propósito.

Lo que cambia respecto a la celda de arriba: aquí el eje de sesión **no lo tapa**. Este camino solo
corre en una sesión que obedece la señal del Apple ID —o sea, privada— así que las tres condiciones
vivas que el drenaje re-mide desde hoy (filas ausentes · onboarding completo · eje) se cumplen las
tres. El aviso «tus datos fueron eliminados de iCloud» puede salir cinco segundos después del toast
que decía lo contrario.

**MEDIDO**: que la rama repone el flag y no cancela la gracia, y que `dataVersion` alimenta el
recálculo de `hasPersonalData`. **INFERIDO**: que la ventana de los 5 s se cumple en un restore real
—depende de cuándo baje el espejo las filas nuevas—; si el restore es rápido, `hasPersonalData` vuelve
a `true` y el drenaje descarta el aviso por su primera condición.

**No lo introduce el PR de la vía**: con el `@State` directo salía igual, y de hecho salía más —el
drenaje de hoy al menos re-mide. Se anota aquí, y no en un ticket propio, porque el arreglo es el
mismo y fragmentarlo dejaría dos mitades que nadie vuelve a juntar.

- [ ] `performLocalWipeForRemoteSync` cancela la gracia al terminar, en las DOS ramas (con y sin
      `skipOnboarding`): las dos bajan las filas, y la de `skipOnboarding` además repone el flag.
