---
id: floating-plus-flashes-when-entering-a-tab
status: backlog
area: ui
priority: low
created: 2026-10-30
updated: 2026-10-30
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
