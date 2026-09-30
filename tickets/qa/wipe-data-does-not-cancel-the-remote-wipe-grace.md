---
id: wipe-data-does-not-cancel-the-remote-wipe-grace
status: qa
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

- [x] «Vaciar datos» cancela la gracia antes de que `hasPersonalData` caiga, como sus cuatro hermanos.
- [x] Un test fija que los borrados deliberados que reponen `hasCompletedOnboarding` la cancelan.
- [x] Verificado con el eje de sesión FORZADO a `true`, o el arreglo no se puede distinguir del tapón.

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

- [x] `performLocalWipeForRemoteSync` cancela la gracia al terminar, en las DOS ramas (con y sin
      `skipOnboarding`): las dos bajan las filas, y la de `skipOnboarding` además repone el flag.

## Implementado (2026-09-30)

**Lo que cambia para quien usa la app:** vaciar tus datos, o recibir en este teléfono el vaciado que hiciste en otro
con el onboarding ya terminado, ya no enseña cinco segundos después «tus datos fueron eliminados de iCloud». El
vaciado remoto de verdad sigue avisando.

**La premisa que no era cierta, y cambió el arreglo.** El «mismo patrón que los cuatro hermanos» —cancelar la gracia
antes de bajar la señal— no la cancela: la tarea la crea el `onChange` en el render siguiente, cuando el `cancel()` ya
pasó. Los hermanos se salvaban porque bajan `hasCompletedOnboarding`. Y `wipeAllUserData` NO bumpea `dataVersion`
(el ticket decía lo contrario): la señal caía en el siguiente bump de quien fuera.

**Qué se hizo:**
- `RemoteWipeGraceLogic` (nuevo, puro): decide la reacción a cada transición de `hasPersonalData` y guarda una
  absorción de UNA caída. Toda transición la desarma.
- `ContentView.settleSignalsAfterDeliberateWipe()`: cancela la gracia, re-mide las dos señales y arma la absorción
  ANTES de escribir `hasPersonalData`. Lo llama `performLocalWipeForRemoteSync` justo tras el `do/catch` del borrado
  (las dos ramas de `skipOnboarding`, éxito y fallo).
- «Vaciar datos» lo pide por `SessionState.requestDeliberateWipeSettle()` en la vuelta del borrado, en éxito y fallo.
- Regla nueva en `.claude/rules/swiftui-ds.md` (Gotchas de vistas).

**Verificación:** `RemoteWipeGraceLogicTests` (12 casos: comportamiento con el eje a `true` + cableado por igualdad) y
el escáner de `ActivationRestoreDiscardTests` actualizado. Review adversarial de tres lentes (timing SwiftUI, caminos,
tests+reglas): dos mutantes que sobrevivían en el cableado —asentamiento solo en el `catch`, o envuelto en `Task {}`—
y la petición sin test de comportamiento; corregidos. Mutantes a mano: 12/12 muertos (quitar o diferir cada petición y asentamiento, invertir armado y escritura, no consumir, armar siempre, absorber tras los guards, contador vacío, observador desenganchado).

**Residual a ticket propio:** `late-icloud-wipe-failure-does-not-settle-the-remote-wipe-grace` (rama de fallo del
aviso tardío, y la medida que falla cerrado). Ninguno de los dos es alcanzable sin un fallo de SwiftData.

## Guion de QA en dispositivo (opcional, no frena el merge)

Montaje: dos dispositivos con el mismo Apple ID e iCloud activo; Yala instalado en los dos, sesión privada con datos.

1. En el **dispositivo A**: Perfil → Ajustes → Vaciar datos → confirma las dos veces.
2. En el **dispositivo B**, con Yala cerrado desde antes del paso 1: termina el onboarding otra vez en A (o ya estaba
   hecho) y abre Yala en B.
3. Esperado en B: el toast «tus datos están aquí» (restore remoto) y **ningún** aviso «tus datos fueron eliminados de
   iCloud» en los 10 s siguientes.
4. En A tras el paso 1 (y en una instalación solo-grupos que vacíe sus datos): **ningún** aviso a los 5-10 s.
5. El vaciado remoto DE VERDAD (filas que desaparecen sin señal) no se puede provocar a mano de forma fiable: lo
   fijan los unitarios (`aRealRemoteWipe_stillStartsTheGrace`).
