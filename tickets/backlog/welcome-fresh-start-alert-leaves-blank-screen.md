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
