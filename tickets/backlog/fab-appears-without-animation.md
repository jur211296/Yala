---
id: fab-appears-without-animation
status: backlog
priority: very-low
area: ui
created: 2026-09-09
source: idea Jürgen 2026-09-09
updated: 2026-10-08
---

# El botón flotante de nuevo registro aparece de golpe

## La idea

Animar la entrada del FAB de nuevo registro: que aparezca con una transición propia en vez de
materializarse de un fotograma al siguiente.

## Por qué importa

Es el botón que más se pulsa en la app. Un elemento flotante que surge sin aviso se lee como un
salto de la interfaz; animado, se lee como que la pantalla terminó de cargar.

## Lo medido (2026-09-09) — la premisa es cierta, y además desigual

El FAB es `FABStackView` (`Yala/App/Views/Shared/FABStackView.swift:11`), y el «+» concreto es
`transactionFAB` (`:155-172`, `accessibilityIdentifier("fab_new_transaction")`). Vive en tres
pantallas y **entra distinto en cada una**:

| dónde | qué hace al aparecer |
|---|---|
| Panel (`PanelView.swift:608`) | funde: el bloque lleva `.transition(.opacity)` (`:630`), dentro de un `dsWithAnimation` (`:558-561`) |
| Estadísticas → Registros (`DetailContainerView.swift:253`) | **nada**: el bloque no lleva `.transition` y el fichero tiene **cero** `.transition(` |
| Registros (`RecordsStandaloneView.swift:159`) | tampoco propio; el único `.transition` del fichero (`:300`) es de otra vista |

Y el vocabulario ya está escrito **dentro del propio componente**: `fabScaleTransition` =
`.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)` (`FABStackView.swift:53`),
que ya usan el FAB de IA (`:75`) y los botones del menú (`:220`). El «+» principal es el único que
no lo usa: sólo rota el icono al abrir el menú (`.rotationEffect`, `:164`).

Así que el trabajo no es diseñar una animación nueva, sino **darle al «+» la entrada que sus
hermanos ya tienen, y que sea la misma en las tres pantallas**. Respetar `reduceMotion`, como hace
el resto del componente.

## Estado

Idea capturada, **sin spec**. Polish visual: no toca lógica ni datos.

## Prioridad

`low` a propósito, y es la única de las cinco de esta tanda que no va en `medium`: no bloquea nada
ni corrige nada incorrecto. Si Jürgen la quiere antes, es cambiar una línea de este frontmatter.

## Medido en 2.1 (triage 2026-10-08)

- `FABStackView.transactionFAB` sigue sin `.transition(Self.fabScaleTransition)`, que sí llevan el FAB de IA y los botones del menú.
- `DetailContainerView.swift` sigue con cero `.transition(` y el bloque del FAB de `RecordsStandaloneView` tampoco lleva transición propia. Los commits posteriores (iPad, observadores de Registros) no tocan la entrada del FAB.

Triage 2026-10-08: abierto · low → very-low · el «+» sigue entrando sin transición en Estadísticas y Registros; es pulido visual que no corrige nada incorrecto (lo dice el propio ticket).
