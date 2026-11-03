---
id: groups-first-entry-after-launch-slides-content
status: qa
area: groups
priority: medium
created: 2026-10-30
updated: 2026-11-02
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

## Qué se hizo (2026-11-02, encargo fluidez-extra, card hsqm)

**La causa no era la carga ni el buscador.** Medido en vídeo con variantes por argumento de lanzamiento (sin los avisos de
arriba, sin la barra vertical, sin toolbar, sin márgenes del scroll, sin `.large`): todas seguían en 44 pt; sin
`revealsFloatingActionWhenScrolledAway`, 0. Al montarse la página, el primer aviso de `onScrollVisibilityChange` llega
antes de que el scroll tenga su sitio y dice «no visible» con el botón de arriba en pantalla. Encendía el «+» con
animación, y esa transacción animaba también el reajuste del scroll: el contenido nacía 44 pt abajo y subía en ~0,2 s.
**Planificación hacía lo mismo** en su primera entrada; Registros (sin flotante) no.

- `TopPrimaryActionRevealLogic.floatingAfterVisibilityChange` ignora el «no visible» hasta haber visto el botón una vez
  (y lo de la página oculta: card 2m2r, `floating-plus-flashes-when-entering-a-tab`).
- Si la primera carga de Grupos llega en el mismo `onAppear`, no se funde (`GroupsFirstLoadLogic.arrivedWithoutWaiting`):
  con la animación de C7, el aviso de cristal «En tu moneda principal…» salía vacío ~0,15 s y se fundía después. Solo esa
  animación: la review adversarial vio que una transacción sin animaciones viajaba a los `onChange` que presentan la hoja
  de invitar o empujan el grupo pendiente. La carga tardía (contexto aún sin configurar) sigue fundiéndose.

Medido después: 0 pt en la primera y la segunda entrada a Grupos y a Planificación, primer fotograma con todo en su sitio.
Capturas y vídeos: `~/Claude/worktrees/_capturas/2026-11-02-fluidez-extra/` (`antes-1.png`, `despues-1.png`, los mp4).

## QA en el iPhone

1. Cierra Yala del todo (deslizar arriba en el selector de apps) y ábrela.
2. Toca la pestaña Grupos (si no está en la barra: Más → Grupos).
3. Mira el resumen de arriba («Te deben…» / «Debes…»): tiene que salir ya en su sitio, sin bajar ni subir, y el aviso
   morado del neto (si lo tienes) entero desde el primer momento. Abajo a la derecha no debe asomar el «+».
4. Repite con Planificación tras cerrar y abrir la app: «Nuevo presupuesto» tampoco debe moverse.
