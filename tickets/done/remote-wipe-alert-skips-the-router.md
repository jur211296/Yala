---
id: remote-wipe-alert-skips-the-router
status: done
priority: high
area: "sesiones, routing, onboarding"
created: 2026-09-14
updated: 2026-09-14
source: "review adversarial de `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`, lente de producto y concurrencia"
---

# El aviso de «datos eliminados» se presenta desde una tarea de fondo, y si UIKit lo descarta la app deja de mostrar nada más

## El síntoma, en lenguaje de usuario

Estás mirando una pantalla que Yala te acaba de abrir —el aviso del espejo tardío, la oferta de prueba,
las novedades de la versión, el selector de idioma— y en ese momento vence una cuenta atrás interna de
cinco segundos. La pantalla que tenías delante **desaparece sola**, y en su sitio aparece un aviso de
datos borrados. Si eso sale mal, a partir de ahí **la app no vuelve a mostrarte ningún aviso**: ni la
bandeja, ni las invitaciones de grupo, ni la oferta de Pro. Solo se arregla cerrando la app.

## Lo medido (2026-09-14)

Dos hechos que por separado están bien y juntos abren un modo de fallo nuevo — es la regla escrita en
`.claude/rules/swiftui-ds.md` («Un flag de presentación que además es BLOCKER de la matriz de readiness
convierte "la presentación no montó" en un brick de toda la sesión»):

1. **El productor es asíncrono y escribe `@State` directo.** `ContentView`, `onChange` de
   `hasPersonalData`: `wipeGraceTask = Task { … showRemoteWipeAlert = true }`. La regla de área dice
   que *«si el productor de una presentación es asíncrono, va por el router; el `@State` directo solo
   vale cuando quien lo enciende es un tap»*.
2. **Ese flag es blocker de la matriz** (`ContentView`, las dos construcciones de `ShellReadinessState`,
   y `ContentViewReadinessLogic.blocker` devuelve `"remoteWipeAlert"`). Un `.alert` no tiene
   `onDismiss`, así que si UIKit descarta la presentación el flag se queda en `true` para siempre.

Y el daño del punto 1 está medido en el propio repo: `ShellDataAlertsModifier` documenta con traza de
simulador (`screenHash 1njjbcs`) que **encender un alert de este anchor desmonta el cover** que hubiera
debajo. `ContentView` lo vuelve a citar para justificar por qué el borrado del corpus del dispositivo
cancela la gracia **antes** de borrar.

**El hermano de este mismo aviso ya cumple la regla.** El otro productor de la señal de vaciado entra
por la cola: `PreferenceSyncService.checkForRemoteWipeSignal` hace
`RouterEntryGate.shared.submit(.remoteWipe(…))`, y `ContentView` lo drena. El intent existe
(`RouterIntent`). La gracia de 5 s es el único de los dos que se salta la cola.

Qué puede estar montado cuando vence la gracia, todo colgando del mismo anchor: el aviso del espejo
tardío (`lateICloudCorpus`), los ajustes de sync, la oferta de prueba, las novedades, el selector de
idioma, el restore del Welcome, y los modales de MainTab.

## La otra mitad: el aviso no dice a dónde va la persona

Sus dos ramas son `hasCompletedOnboarding = false` y `{}`. Es exactamente lo que hubo que corregir en
sus dos vecinos del MISMO fichero, donde ahora las dos ramas son explícitas sobre el aterrizaje —
porque al cerrar el alert **no queda nada montado debajo**. Este se quedó sin ello.

## Por qué no se arregló en el PR que lo encontró

Ese PR solo estrechó **quién** llega al encendido (el eje de sesión). No toca **cómo** llega, que es
esto. Y cambiar la vía de presentación es un cambio de routing con su propia superficie de riesgo.

## Criterios de aceptación

- [x] El aviso se presenta por una vía que respeta lo que ya esté montado en el anchor.
- [x] Sus dos ramas dicen explícitamente a dónde va la persona, como sus vecinos del mismo fichero.
- [x] Si la presentación no llega a montar, el flag no deja la matriz de readiness bloqueada.
- [x] Decidido si `orphan-alerts-behind-fullscreen-covers` se cierra con esto o sigue aparte.

## Cerrado el 2026-09-14

### Qué se hizo

**El aviso viaja por la cola.** Intent nuevo `.presentRemoteWipeNotice` (bloque F, `.high`, no
transitorio, id `remoteWipeNotice`), que la gracia de 5 s SUBMITEA en vez de encender el `@State`, y
que `ContentView` drena cuando la matriz de readiness está limpia. **No se reusó `.remoteWipe`, y la
premisa del encargo estaba mal en ese punto**: ese intent no presenta el aviso — su drenaje llama
`handleRemoteWipeSignal`, que **borra**. Reusarlo habría convertido una pregunta en un borrado
silencioso.

**El drenaje RE-MIDE tres condiciones vivas** (las filas siguen ausentes · el onboarding sigue
completo · el eje de sesión) en vez de fiarse del veredicto del productor: el intent no es transitorio
y puede esperar en cola a través de un background entero, y el aviso afirma un hecho sobre AHORA.

**El blocker de la matriz pasa a ser una condición viva** (`remoteWipeNoticePending`) y no el `@State`
del alert, que queda como red visual. Es la regla (4) de Presentaciones, y aquí es load-bearing: la
red de presentación toggla ese flag para re-presentar, y una matriz colgada de él se abriría en cada
reintento.

**La red anti-brick**: `ModalPresentationProbe` (¿hay algo presentado, según UIKit?) +
`RelaunchNetLogic` (el mismo veredicto que verifica los covers terminales). Si la presentación no
monta, reintenta; al agotar el cap del ciclo **suelta la condición viva** y deja un canario
(`remoteWipeNoticeNotPresented`). Y el bucle **no termina al confirmar la presentación**: sigue
vigilando hasta que el aviso se conteste, porque el brick tiene dos formas —la que no monta y la que
se cae después— y la regla nombra las dos. Esa segunda mitad la encontró la review.

**Los aterrizajes**: «Empezar de cero» va al **Hero del Welcome**, que es donde aterriza este mismo
hecho cuando llega por señal (`performLocalWipeForRemoteSync`), fijando `hasShownWelcomeChooser` para
que el destino no dependa de lo que quedara en las preferencias — antes, con el chooser dado por
visto, la persona caía directa en el formulario del onboarding sin que nadie le ofreciera restaurar.
«Seguir esperando» se queda en la app, y ahora eso es verdad: presentado por la cola, debajo sigue
montada la shell. La premisa del ticket («al cerrar el alert no queda nada montado debajo») era cierta
sólo mientras el aviso se encendía desde la tarea de fondo.

**Y cancelar la gracia pasa a retirar el intent de la cola** (`cancelWipeGrace()`, siete call-sites
unificados): con el aviso en la cola, cancelar la tarea ya no basta — uno ya encolado sobrevive al
`cancel()` y saldría más tarde hablando de datos que la persona acaba de borrar ella misma.

### Cómo se verificó

- **Unit**: 244 tests en 17 suites, verde. Tres source-scan nuevos en `RemoteWipeSignalWiringTests`
  (el tramo del productor, el tramo del drenaje con sus tres re-mediciones, y que la matriz cuelga de
  la condición viva y el cap la suelta). Cuatro suites ajenas actualizadas: su ancla era
  `wipeGraceTask?.cancel()`, que ya no existe como literal.
- **XCUITest**: `RemoteWipeNoticeRoutingUITests`, 3 casos verdes, con seam `-uitest-remote-wipe-notice`
  y la oferta de prueba en cola como instrumento — afirma que nada se monta encima del aviso y que lo
  retenido presenta al contestarlo.
- **El brick y su cura, MEDIDOS en simulador con dos mutantes** (receta reproducible):
  1. `isPresented: .constant(false)` en el alert (la presentación nunca monta) + `-uitest-trial-offer`
     → el blocker `remoteWipeAlert` se suelta a los ~10 s y el paywall retenido entra.
  2. Lo mismo, pero además sin la llamada a `armRemoteWipeNoticePresentationNet()` → el log se queda
     en `blocked by: remoteWipeAlert` y el paywall **no presenta nunca** (25 s). Ése es el brick.
  3. Y el tercero, que dejó un residual anotado: forzando la sonda a `false` con el aviso REALMENTE en
     pantalla, los nueve toggles dejan el alert dibujado aunque el estado se apague. La app no se
     brickea (la matriz queda libre), pero el residuo es feo — por eso el caso 1 del XCUITest vigila
     que la sonda siga reconociendo la presentación en el runtime de turno.

### Decisión sobre `orphan-alerts-behind-fullscreen-covers`

**Sigue aparte.** Este ticket arregla UN productor; aquél es el mecanismo general para los alerts que
el router ya drena (`.showInviteError`, `.showGroupSyncError`) y su dirección —clasificarlos o
presentarlos dentro del cover activo— es otra decisión. Lo que sí cambia es su contexto: el molde que
aquí queda escrito (condición viva como blocker + verificación de presentación efectiva) es una
respuesta candidata para él.

### Lo que deja abierto

- `wipe-data-does-not-cancel-the-remote-wipe-grace` gana una **segunda celda**, medida en la review de
  este ticket: `performLocalWipeForRemoteSync` con `skipOnboarding` repone `hasCompletedOnboarding` y
  no cancela la gracia, y ahí el eje de sesión NO tapa el aviso. Anotada en ese ticket, no en uno
  nuevo, porque el arreglo es el mismo.
- El PRODUCTOR sigue sin test de comportamiento (`remote-wipe-receiver-has-no-behaviour-test`): no hay
  seam que haga desaparecer las filas del store bajo el proceso vivo.
- **Device-QA: no aplica.** Lo que este ticket cambia es la vía de presentación, y eso se ejercita
  entero en simulador — el XCUITest lo recorre con el aviso real.
