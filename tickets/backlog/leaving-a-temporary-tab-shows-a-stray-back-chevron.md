---
id: leaving-a-temporary-tab-shows-a-stray-back-chevron
status: backlog
priority: medium
area: "tab-bar, navigation"
created: 2026-11-20
updated: 2026-11-20
source: "encargo de fluidez de Reportes (20-nov-2026), visto en el vídeo del simulador"
---

# Salir de una pestaña abierta desde «Más» enseña un «‹» y baja la cabecera un instante

Medido en el simulador iPhone 17 Pro (iOS 27.2), con la barra por defecto (Panel, Estadísticas, Planificación,
Registros, Más): con Reportes abierto desde «Más», tocar «Ver en Registros» en el detalle de una línea del Flujo de caja
deja ver, antes de llegar a Registros, la página de Reportes con un «‹» arriba a la izquierda y la cabecera ~40 pt más
abajo. Con Reportes abierto, la barra enseñaba Panel, Estadísticas, Planificación, Reportes y Más (Registros fuera).
Inferido, sin aislar: al pasar a Registros, `SceneNavigation.selectedMainTab` vacía `temporaryTab` en el mismo cambio y
UIKit recoloca Reportes en su controlador «More» nativo un fotograma (el comentario de `showsSearchTab` en
`ContentView` ya nombra ese «stray back chevron»). Afecta a cualquier pestaña temporal que salte a otra de la barra, no
solo a Reportes.

Evidencia: `~/Claude/entregas/2026-11-20-flujo-de-caja-fluidez-rebote-y-filtros/evidencia/salto-ver-en-registros.png`.

## Hecho cuando

Ir de una pestaña temporal a otra de la barra no enseña el «‹» ni mueve la cabecera, medido en vídeo, sin tocar el
orden de la barra que eligió la persona (ver las reglas de la raíz en `swiftui-ds.md`: cambiar la barra en caliente
ya cerró la app).
