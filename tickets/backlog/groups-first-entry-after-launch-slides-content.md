---
id: groups-first-entry-after-launch-slides-content
status: backlog
area: groups
priority: medium
created: 2026-10-30
updated: 2026-10-30
source: PR #703 (grupos-hero-neto-moneda-principal)
---

# La primera vez que entras a Grupos tras abrir la app, el contenido se desliza ~44 pt

## Qué pasa

Tras abrir la app, el primer toque en la pestaña Grupos deja la pantalla quieta ~0,7-0,9 s (la página carga sus datos al
aparecer). Luego pinta el resumen ~44 pt más abajo de su sitio y lo sube con animación en ~0,3 s. Las entradas siguientes
ya no se mueven: el salto seco al volver a la pestaña lo arregló el PR #703, con el buscador fijo.

Medido en el simulador (iPhone 17 Pro, iOS 27.0) el 2026-10-30, con el árbol de #703 y con el de antes: pasa igual en los
dos. Vídeo: `~/Claude/worktrees/_capturas/2026-10-30-grupos-hero-neto-moneda-principal/primera-entrada-tras-arrancar-sigue-deslizando.mp4`.

## Lo que ya se descartó

- **No es el cajón del buscador.** Con el buscador fijo (`.always`) sigue igual, y el hueco aparece DEBAJO del campo
  «Buscar», no en su sitio.
- **No es que el buscador se enganche al cambiar de rama** (indicador de carga → lista). Colgar `.searchable` del
  `ZStack`, que existe desde el montaje, no lo cambió (experimento revertido).

## Hipótesis por medir

Las páginas de pestaña están montadas desde el arranque, pero `GroupsContainerView` no corre su `onAppear` (y con él
`setContext` → `loadData`) hasta que se ve. La lista sustituye al `ProgressView` con la barra ya visible, y UIKit
recoloca el `contentInset` del scroll nuevo con animación. Para medirlo: instrumentar `hasLoadedOnce` y el
`contentInset` en el primer fotograma, o cargar los datos antes de que la pestaña se vea.

## Cuándo está hecho

La primera entrada tras abrir la app pinta el resumen en su sitio desde el primer fotograma, verificado en vídeo.
