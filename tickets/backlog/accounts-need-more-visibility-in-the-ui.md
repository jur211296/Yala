---
id: accounts-need-more-visibility-in-the-ui
status: backlog
priority: low
area: "accounts, ui"
created: 2026-09-09
updated: 2026-10-08
source: idea Jürgen 2026-09-09
---

# Las cuentas se ven poco: hay que darles más presencia en la app

## La idea

Subir de rango a las cuentas. Hoy quedan discretas y hay que ir a buscarlas; la idea es que se vean,
que estén a mano y que el saldo de cada una se lea sin navegar hasta ellas.

## Por qué importa

La cuenta es la unidad con la que el usuario piensa su dinero — «cuánto tengo en el banco», «cuánto
en efectivo». Si lo único visible es el agregado, no puede contrastarlo con lo que ya sabe, y un
número que no se puede contrastar deja de creerse.

## Dónde vive hoy (medido el 2026-09-09)

Las cuentas están **dos niveles hacia dentro y en horizontal**, que es probablemente el origen de la
sensación:

- `Yala/App/Views/Panel/Sections/PanelPanoramaSection.swift:12` — sección **colapsable** «Tus
  finanzas» (`panel.panorama.title`). Las cuentas cuelgan de ahí (`:236-249`).
- `Yala/App/Views/Panel/PanelAccountsSection.swift:9` → `AccountsCarouselView.swift:4` — un
  **carrusel horizontal** (`ScrollView(.horizontal)` + `LazyHStack`), no una lista: sólo se ven las
  primeras tarjetas y el resto se descubre deslizando.
- La tarjeta: `Yala/App/Views/Panel/AccountCardView.swift:12`.

## Estado

Idea capturada, **sin spec**. Falta decidir qué superficie cambia (la sección del Panel, una
pestaña propia, ambas) y qué cuenta como «más visible». `/spec` cuando se priorice.

## Relacionados

- [[panel-accounts-redesign]] — misma zona, pedido el 2026-05-13: «más espacio, clic abre sheet,
  editar dentro del sheet, añadir filtro a la toolbar». Al hacer spec, decidir si son un solo
  trabajo o dos.
- [[account-form-as-medium-detent-sheet]] — el patrón de sheet que Jürgen quiere para ese camino.
- [[panel-colapsa-la-seleccion-de-cuentas-a-la-primera]] y
  [[filtro-de-cuentas-se-colapsa-al-navegar-a-registros]] — dos defectos vivos del filtro de
  cuentas. Conviene mirarlos antes de rediseñar encima.

## Pregunta para Jürgen (triage 2026-10-08)

Falta decidir qué superficie cambia.

- **A.** Sacar las cuentas del plegable «Tus finanzas» y darles una sección propia, siempre abierta, en el Panel.
- **B.** Una superficie propia de Cuentas (pestaña o lista vertical con el saldo de cada una).
- **C.** Dar la idea por cumplida con el rediseño del 03-oct y la lista de Ajustes (`accounts-settings-list-redesign`), y cerrarla.

**Recomendación: A.** Es el cambio más barato y ataca justo lo medido: hoy las cuentas están dos niveles hacia dentro. Con A la prioridad es `low`.

## Medido en 2.1 (triage 2026-10-08)

- El carrusel sigue horizontal y dentro de la sección plegable (`Yala/App/Views/Panel/Sections/PanelPanoramaSection.swift:26`, `panelAccountsCollapsed`).
- `panel-accounts-redesign` (done, 03-oct) agrandó las tarjetas y dejó la sección como estaba a propósito: «La sección no crece (eso es `accounts-need-more-visibility-in-the-ui`)» (`encargos/lanzados/2026-10-03-panel-accounts-redesign.md:66`).

Triage 2026-10-08: abierto · medium → low · idea sin spec; el rediseño del 03-oct dejó la sección igual a propósito y falta decidir la superficie (pregunta A/B/C).
