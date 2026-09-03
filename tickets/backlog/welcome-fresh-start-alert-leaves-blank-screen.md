---
id: welcome-fresh-start-alert-leaves-blank-screen
status: backlog
priority: high
area: onboarding
created: 2026-09-02
updated: 2026-09-02
---

# Cerrar el alert de «Empezar desde cero» deja el Welcome en blanco, sin salida

## El síntoma, en lenguaje de usuario

Abro Yala teniendo datos de antes en el teléfono. Toco «Empezar» → «Es mi primera vez en Yala». Me
pregunta si quiero borrar todo. **Pulse lo que pulse —«Cancelar» o «Borrar todo y continuar»— me
quedo mirando una pantalla vacía, sin un solo botón.** No hay forma de seguir: tengo que matar la app
y volver a abrirla.

Cancelar debería devolverme a la pantalla de las tres opciones para elegir otra cosa. No me devuelve
a ningún sitio.

## Dónde muerde

| Entorno | Estado |
|---|---|
| Producción | **Alcanzable.** Es el onboarding de cualquiera que reinstale o vuelva teniendo datos locales |
| Simulador | Reproducible a voluntad (ver abajo) |

No depende de ningún flag: el recorrido no pasa por Grupos, ni por nube, ni por sesión secundaria.

## Cómo verlo (determinista, iPhone 17 Pro, scheme Yala / Debug)

```
-uitest -uitest-reset -uitest-seed grupos
```

`welcome_hero_cta` → `welcome_chooser_new` → **«Cancelar»** en el alert «Empezar desde cero».

Resultado: el árbol rs/1 pasa a `screenHash 1njjbcs`, `count 6`, **cero targets interactivos**.

## Lo MEDIDO el 2026-09-02, con control positivo y negativo

Se descubrió mientras se verificaba el seam `-uitest-fail-wipe`, y lo primero que se hizo fue
descartar que lo causara ese seam. Tres lanzamientos, mismo `screenHash` exacto en los tres:

1. Con `-uitest-fail-wipe`, pulsando **«Borrar todo y continuar»** → el wipe falla, sale el alert «No
   pudimos borrar tus datos», y al cerrarlo: pantalla vacía.
2. Con `-uitest-fail-wipe`, pulsando **«Cancelar»** → pantalla vacía. **Cancelar no invoca ningún
   wipe**, así que el seam es irrelevante en esta rama.
3. **Sin** `-uitest-fail-wipe`, pulsando **«Cancelar»** → pantalla vacía.

⇒ es preexistente, no lo introduce ningún seam, y **no es un fallo del borrado**: es el alert.

## Lo que contradice

`Yala/App/Views/Shared/ShellDataAlertsModifier.swift:105` dice literalmente:

> `// Cancel: user queda en el Chooser (showWelcomeFlow sigue true) —`
> `// puede elegir Restore/Invite o re-tap "Soy nuevo".`

El Chooser **no** se queda. Y el `catch` de la rama de fallo (líneas 98-103) tampoco toca
`showWelcomeFlow` —correctamente— y aun así la pantalla acaba igual de vacía. El estado del flag no
es el problema; lo es quién está montado debajo del alert.

## Hipótesis a comprobar primero (INFERIDA, no medida)

Que el `.alert` cuelgue de una vista que se desmonta al presentarse, de modo que al cerrarse no queda
nada debajo a lo que volver. Empezar por el `.alert` de `showFreshStartWipeAlert`
(`ShellDataAlertsModifier.swift`, sobre las líneas 67-111) y por quién monta el Chooser cuando
`showWelcomeFlow == true` — probablemente `WelcomeFlowContainer` / `ContentView`.

## Buscar TODAS las instancias del mismo patrón

`ShellDataAlertsModifier` monta varios alerts más con la misma forma: `showRestoreOffer` (sobre la
línea 113), el de wipe remoto y el de mismatch de iCloud. Comprobar si alguno queda igual de huérfano
al cerrarse antes de dar el fix por completo.

## Criterio de hecho

- [ ] Cancelar el alert devuelve al Chooser con sus tres opciones tapeables.
- [ ] Cerrar el alert de FALLO del wipe (el de `-uitest-fail-wipe`) también deja una pantalla usable.
- [ ] Barrido de los otros alerts de `ShellDataAlertsModifier` con el mismo patrón.
- [ ] XCUITest del recorrido: es determinista y los identifiers ya existen (`welcome_hero_cta`,
      `welcome_chooser_new`). El seam `-uitest-fail-wipe` cubre además la rama de fallo.

---

## 2026-09-03 · Arreglado. Y la causa NO era la hipótesis del ticket

**Reproducido primero**, con la receta de arriba: `screenHash 1njjbcs`, `count 6`, cero targets, y
captura en negro absoluto. El bug es real y alcanzable en producción.

### La hipótesis del ticket era razonable y era falsa

Decía: «que el `.alert` cuelgue de una vista que se desmonta al presentarse, de modo que al cerrarse
no queda nada debajo». Se acerca, pero invierte la causa y el efecto — y esa inversión cambia el fix.
Se probaron y descartaron **tres** hipótesis antes de medir:

1. **El flag se queda pegado** (mía). Se implementó bajarlo a mano en las dos ramas. **No cambió
   nada**: mismo `screenHash`, misma pantalla negra.
2. **Dos anchors presentando ante el mismo observable** (regla 4). Falsa: `WelcomeFlowModifier`
   recibe el binding pero sólo lo ENCIENDE (`ContentView.swift:1628`); quien presenta es únicamente
   `ShellDataAlertsModifier`.
3. **Otro alert con el mismo copy.** Falsa: sólo existe uno con `welcome.freshStart.*`.

### Lo MEDIDO, instrumentando el setter del cover y el log de readiness

```
ContentView readiness blocked by: freshStartWipeAlert  [freshStartAlert=true  welcomeFlow=true ]
DIAG gated.set: true -> false  (inhibitor=false)          <- SwiftUI desmonta el cover
ContentView readiness blocked by: freshStartWipeAlert  [freshStartAlert=true  welcomeFlow=false]
DIAG cancel: antes=true
DIAG cancel: despues=false
```

**`showWelcomeFlow` pasa a `false` solo, mientras el alert está abierto y ANTES de que el usuario
toque nada.** El alert cuelga del anchor de `ContentView`; el Welcome es un `fullScreenCover` del
MISMO anchor. Un anchor no puede presentar dos cosas, así que al encender el alert SwiftUI **dismissa
el cover** — y lo hace por su setter, con lo que el flag baja legítimamente. **No es un flag pegado:
es un dismiss real.**

⇒ Por eso el fix (1) no servía: para cuando la persona pulsa el botón, el Welcome ya está muerto.
Cerrar el alert es sólo la mitad del trabajo; la otra mitad es decir a dónde va.

Es la regla (4) de Presentaciones en su forma menos evidente: no son dos anchors compitiendo por un
observable, es **un anchor con dos presentaciones**.

### El fix, y no es invención: el vecino ya lo hacía

`Yala/App/Views/Shared/ShellDataAlertsModifier.swift` — las dos ramas del alert de fresh-start y el
botón OK del alert de fallo bajan su flag y **reabren el Welcome en `.chooser`**, con el guard
`if !hasCompletedOnboarding`.

Ese molde ya estaba treinta líneas más abajo, **en el mismo fichero**: el alert de `showRestoreOffer`
reabre el Chooser exactamente así («Decisión consciente: volver al Chooser»), desde que alguien se
topó con esto en aquel camino. El de fresh-start se quedó sin ello.

`.chooser` y no `.hero`: cancelar devuelve al punto exacto donde se estaba. Y se arregla también la
**rama del borrado fallido** —el caso 1 de los tres lanzamientos del ticket—, donde además es lo
correcto de producto: el wipe falló, los datos siguen ahí, y hay que poder elegir otra cosa.

### Verificación

Simulador, misma receta, tras el fix: **`screenHash 09jhu32`** — el Chooser, con sus cuatro targets
(`welcome_chooser_new`, `_restore`, `_invite`, `welcome_back_button`). Antes: `1njjbcs`, cero.

Pin: `YalaUITests/Flows/WelcomeFreshStartAlertUITests.swift`, dos tests — que el Chooser vuelve
ENTERO (las tres cards, no sólo «no está en blanco») y que vuelve USABLE (re-tocar la card reabre el
alert; un Chooser inerte pasaría el primero).

### Corrige un comentario que mentía

`ShellDataAlertsModifier.swift` decía «Cancel: user queda en el Chooser (showWelcomeFlow sigue true)».
No se quedaba. Describía la intención, nunca el comportamiento — y el cuerpo del botón estaba vacío
precisamente porque se daba por cierta.
