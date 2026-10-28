---
id: welcome-steps-slide-in-from-the-top-with-a-black-flash
status: qa
priority: high
area: "welcome, onboarding"
created: 2026-10-28
updated: 2026-10-28
source: "tablero feer (vídeo de Jürgen del 2026-10-27), encargo 2026-10-28-welcome-transiciones-pasos"
qa-status: needs-testing
---

# Welcome: las pantallas entraban desde arriba con un flash negro entre pasos

## Qué pasaba

En el Welcome (Empezar → «¡Hola! ¿Qué quieres hacer en Yala?» → «Ya hay una cuenta de Yala con este Apple ID»), cada
paso aparecía desde arriba y por un momento se veía negro (vídeo de Jürgen del 27-oct, en su iPhone). En el simulador
se veía la otra mitad: la pantalla que salía desaparecía de golpe, sin fundirse, y quedaba un instante el degradado vacío.

Dos causas:

1. Desde el 25-oct (90b6e0870) cada paso con «‹» iba dentro de su propia `NavigationStack`. Cambiar de paso quitaba una
   pila de UIKit y ponía otra: la que salía no se fundía y la que entraba, en el iPhone, se dimensionaba animada desde la
   esquina enseñando su fondo negro.
2. En el cover del Welcome, la pantalla que salía se pintaba por debajo del degradado opaco del `ZStack`: el salto entre
   los pasos y la entrada a la cuenta (también el de «Ya tengo una cuenta», el del PR #629) solo fundía la que entraba.

## Qué se hizo

- Una sola pila de navegación para todo el cover del Welcome (`welcomeNavigationHost()`), montada por encima de los
  pasos; dentro, `welcomeBackButton` solo pone su «‹» en la barra. Fuera del cover (la activación de Yala completo desde
  Grupos) cada pantalla sigue con su pila.
- `.zIndex(1)` en las dos pantallas del cover.
- Entre pasos, el mismo fundido que la entrada (0,35 s, `easeInOut`), también con «Reducir movimiento».

## Verificación

- `WelcomeCoverContentLogicTests` (cableado) y `YalaTests` entero en verde.
- XCUITest del Welcome, onboarding y entrada a la nube en verde.
- Vídeos antes/después en el simulador (iPhone 17 Pro, iOS 27.0), con y sin «Reducir movimiento»:
  `/Users/jur/Claude/worktrees/_capturas/2026-10-28-welcome-transiciones-pasos/`.

## QA en el iPhone (Jürgen)

El crecimiento desde la esquina con negro solo salió en el iPhone; el simulador no lo reproduce. Con un build de Yala
Dev que traiga este cambio:

1. Borra Yala Dev del iPhone e instálala de nuevo, para que abra en el Welcome.
2. Toca «Empezar». La pantalla «¡Hola! ¿Qué quieres hacer en Yala?» tiene que aparecer fundiéndose, sin moverse.
3. Toca «Es mi primera vez en Yala». Con tu Apple ID sale «Ya hay una cuenta de Yala con este Apple ID»: tiene que
   fundirse sobre el fondo morado quieto, sin negro y sin entrar desde arriba.
4. Toca «Crear otra cuenta» y luego «‹» dos veces: las tres vueltas, igual.
5. Vuelve a «¡Hola!», toca «Ya tengo una cuenta» y luego «‹»: igual.
6. (Opcional) Con Ajustes › Accesibilidad › Movimiento › Reducir movimiento activado, repite 2 y 3: también funde.

Sale bien si en ninguno de los saltos ves negro ni nada que llegue desde arriba o desde una esquina.
