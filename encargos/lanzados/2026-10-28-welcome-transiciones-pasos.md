# Welcome: pantallas que entran desde arriba con flash negro

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `welcome-transiciones-pasos` · Sesión cola **S12d** · al cerrar → **S12e**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/welcome-transiciones-pasos-feer.md`

Léelo y ejecútalo tal cual. Vídeo del antes: `~/Claude/entregas/Yala--bugs-animacion-2026-10-27/welcome-transiciones.mp4`.

## Qué NO tocar
Lo que diga el brief. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (simulador iPhone 17 Pro, iOS 27.0, `origin/2.2` en 955d70d0c): Hero → «¡Hola!» se
funde bien. «¡Hola!» → «Ya hay una cuenta…» y «Ya hay una cuenta…» → «Es mi primera vez» **no**: la pantalla que sale
desaparece en un fotograma, queda el degradado vacío y la nueva entra fundiendo. En el vídeo del iPhone de Jürgen,
además, la nueva crece desde la esquina con negro alrededor. Lo común: desde 90b6e0870 (25-oct) cada paso con «‹» va
dentro de su propia `NavigationStack` (`welcomeBackButton`), y cambiar de paso quita una pila de UIKit y pone otra.

**D1 · ¿Cómo se arregla?** → Una sola `NavigationStack` para todo el cover del Welcome (`welcomeNavigationHost()`),
montada por encima del degradado y de los pasos; dentro, `welcomeBackButton` solo pone su botón en la barra.
Por qué: la pila deja de entrar y salir, los pasos cambian como vistas normales y se funden; es el «fondo quieto» del
fundido de entrada. Alternativa descartada: seguir con una pila por paso y apagar su animación de tamaño — no arregla
que la que sale desaparezca de golpe, y el crecimiento solo se ve en el iPhone, así que no se puede comprobar aquí.

**D2 · ¿Y las pantallas sin «‹» (Hero, relanzamiento, «Abriendo tu invitación…»)?** → Se pintan igual que hoy: se
comprueba con capturas antes/después; si la barra vacía las desplaza, se corrige en esas pantallas sin tocar su
diseño. Por qué: el encargo prohíbe rediseñar el Welcome.

**D3 · ¿Entra la activación de Yala completo desde Grupos (`FullModeActivationView`), que reusa dos de estas
pantallas?** → No. Conserva su pila por pantalla (fuera del host, `welcomeBackButton` hace lo de siempre).
Por qué: intercala pantallas con pila propia (onboarding, restaurar) que no caben dentro de otra pila; es otro
recorrido y otro arreglo. Va a «Encontrado» con card.

**D4 · ¿Qué curva y qué pasa con Reducir movimiento entre pasos?** → La del fundido de entrada:
`easeInOut(WelcomeCoverContentLogic.crossfadeSeconds)`, también con Reducir movimiento (hoy, con él, el paso cambia en
seco). Por qué: el encargo pide el mismo lenguaje y dice que con Reducir movimiento un fundido vale; un fundido no
desplaza nada. Alternativa descartada: dejar el `.smooth(0.5, extraBounce: 0.1)` actual — rebote sin sentido en una
opacidad y dos ritmos distintos dentro del mismo cover.

**D5 · ¿Cómo queda fijado?** → Test de cableado (escaneo de fuente) en `WelcomeCoverContentLogicTests`: el cover monta
`welcomeNavigationHost()` y `welcomeBackButton` no abre pila dentro del host. Más vídeo antes/después. Por qué: una
animación no se puede afirmar en XCUITest; lo que la rompe es volver a poner una pila por paso, y eso sí se pilla.

**D6 · ¿Cierre en done o en qa?** → `in qa` asignada a Jürgen con guion corto: el crecimiento desde la esquina solo
salió en su iPhone y el simulador no lo reproduce. No frena el merge (modo cola).
