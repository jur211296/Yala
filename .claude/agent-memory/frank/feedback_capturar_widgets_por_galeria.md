---
name: capturar-widgets-por-galeria
description: Capturar widgets en la galería/inicio del simulador cuesta ~15 swipes por widget y la galería vuelve a la página 1 en cada «Agregar»; planificar el recorrido antes.
metadata:
  type: feedback
---

Añadir widgets de Yala Dev en el simulador (iOS 27) pasa por la galería, que pagina **un tamaño por página** (Balance S, Balance M, Gastos S…; el XL «Resumen del mes» es la 18) y **vuelve a la página 1 tras cada «Agregar widget»**. Cuatro widgets en dos iPads fueron ~120 swipes del MCP.

**Why:** el 2026-10-02 (ticket ipad-large-and-extra-large-widgets) la tanda de capturas costó más que el código. `axe` CLI no sirve (busca `SimulatorKit` en una ruta que Xcode 27 ya no tiene) y la búsqueda de la galería solo filtra por app, no por widget.

**How to apply:** en una sola pasada hasta la página más alta, captura la galería de todos los tamaños al pasar y añade solo el último; los demás, una vuelta cada uno. En iPhone, escribir «Yala Dev» en el buscador abre la app directamente. Tras `-uitest-seed`, relanza **sin** reset/seed: el primer arranque escribe el snapshot del widget antes de sembrar y los widgets salen a cero. El ref del pager alterna entre dos ids según el snapshot: si un swipe falla con TARGET_NOT_ACTIONABLE, usa el otro de la lista de candidatos.
