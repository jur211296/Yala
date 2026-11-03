---
id: floating-plus-flashes-when-entering-a-tab
status: qa
area: ui
priority: low
created: 2026-10-30
updated: 2026-11-02
source: PR #703 (grupos-hero-neto-moneda-principal)
---

# El «+» flotante asoma ~0,2 s al entrar a la pestaña Grupos y se va

## Qué pasa

Al tocar la pestaña Grupos, el botón flotante «+» aparece abajo a la derecha durante 2-3 fotogramas y se funde, aunque los
botones de arriba («Nuevo gasto», «Nuevo grupo») están a la vista. Se ve en el vídeo de Jürgen del 30-oct
(`~/Claude/tmp-frank/video-grupos-parpadeo-hero-2026-10-30.mp4`, primer fotograma de Grupos) y en el simulador, en todas
las entradas.

## Por qué (inferido, sin instrumentar)

`revealsFloatingActionWhenScrolledAway` (`TopPrimaryAction.swift`) escucha `onScrollVisibilityChange`. Con la pestaña
oculta, los botones de arriba cuentan como «no visibles» y el flotante queda encendido. Al volver, se ve un fotograma
antes de que llegue el aviso de «visibles». El modificador no se reinicia en `onAppear` a propósito, para conservar el
flotante si volviste con la lista desplazada. El Panel, Presupuestos y Pagos usan el mismo modificador: comprobar si les
pasa.

## Cuándo está hecho

Al entrar a una pestaña con los botones de arriba a la vista, el flotante no aparece en ningún fotograma (vídeo), y sigue
apareciendo si se vuelve con la lista desplazada.

## Qué se hizo (2026-11-02, encargo fluidez-extra, card 2m2r)

Confirmado en vídeo antes de tocar: el «+» asomaba ~0,15 s al volver a Grupos y a Presupuestos con los botones de arriba a
la vista, y en la primera entrada de cada página. El Panel no (decide por desplazamiento, no por este modificador).

- La raíz (`MainTabView`) dice a cada página si es la que se ve (`\.isRootPageShown`, también Más y Buscar), y
  `revealsFloatingActionWhenScrolledAway` ignora lo que oye con la página oculta: el «+» se queda como estaba al salir.
  «La que se ve» y no «la seleccionada» (`RootTabLayoutLogic.displayedTab`): en la shell de solo grupos la selección se
  queda en Panel y Grupos se habría creído oculta, sin «+» nunca (lo vio la review adversarial).
- El primer «no visible» al montarse, antes de haber visto nunca el botón, queda en suspenso 0,4 s: el falso del montaje
  se desmiente en uno o dos fotogramas, y ese aviso era el «+» de la primera entrada y el contenido que nacía 44 pt abajo
  (`groups-first-entry-after-launch-slides-content`). Si nadie lo desmiente, el botón nació fuera de pantalla (iPhone
  girado con texto grande) y el «+» sale.

Medido después: ningún fotograma con el «+» en las entradas a Grupos y Presupuestos; con la lista bajada, al volver el «+»
sigue (`TopPrimaryActionUITests#test_budgets_returningWithTheListScrolled_keepsTheFloating`). Tests de la lógica y del
cableado: `TopPrimaryActionRevealLogicTests`, `RootDisplayedTabTests`, `TopPrimaryActionRevealWiringTests`.

## QA en el iPhone

1. En Grupos, con «Nuevo gasto» y «Nuevo grupo» a la vista, ve al Panel y vuelve: abajo a la derecha no debe asomar el «+».
2. Haz lo mismo en Planificación → Presupuestos.
3. En Presupuestos (o en Grupos, si tienes muchos), baja hasta que salga el «+» abajo a la derecha. Ve al Panel y vuelve:
   el «+» tiene que seguir ahí.
