---
name: capturar-widgets-por-galeria
description: Para el antes/después de un widget, el banco qa/widget-render (sin galería); la galería real solo para comprobar unos pocos, con un script que busca por etiqueta y proporción.
metadata:
  type: feedback
---

Añadir widgets de Yala Dev en el simulador (iOS 27) pasa por la galería, que pagina **un tamaño por página** (Balance S, Balance M, Gastos S…; el XL «Resumen del mes» es la 18) y **vuelve a la página 1 tras cada «Agregar widget»**. Cuatro widgets en dos iPads fueron ~120 swipes del MCP.

**Why:** el 2026-10-02 (ticket ipad-large-and-extra-large-widgets) la tanda de capturas costó más que el código. `axe` CLI no servía ese día (buscaba `SimulatorKit` en una ruta que Xcode 27 ya no tenía; el 2026-10-15 ya funcionaba y la galería se recorre con su buscador, ver [[conducir-simulador-con-axe]]) y la búsqueda de la galería solo filtra por app, no por widget.

**How to apply:** en una sola pasada hasta la página más alta, captura la galería de todos los tamaños al pasar y añade solo el último; los demás, una vuelta cada uno. En iPhone, escribir «Yala Dev» en el buscador abre la app directamente. Tras `-uitest-seed`, relanza **sin** reset/seed: el primer arranque escribe el snapshot del widget antes de sembrar y los widgets salen a cero. El ref del pager alterna entre dos ids según el snapshot: si un swipe falla con TARGET_NOT_ACTIONABLE, usa el otro de la lista de candidatos.

**Medido el 2026-10-29 (extragrandes verticales, iPhone 17 Pro, iOS 27.0, axe 1.8):**
- A inicio: `simctl terminate` de la app; `axe button home` y el `button home` de XcodeBuildMCP no hicieron nada.
- Modo edición: pulsación larga en hueco (`axe touch --down`, 2,5 s, `--up`); «Editar» y «Agregar widget» solo con `axe touch --down --up --delay 0.15` (con `tap` el menú no respondía o se cerraba y el toque caía en una app).
- **Los swipes del pager saltan páginas (1 o 2 al azar)**: contar swipes o títulos añadió un widget equivocado. Lo fiable es leer el botón de la vista previa (`Button` con label «Yala Dev, <título>»): su alto distingue el tamaño (164 pequeño, 146 mediano, 325 grande, **329 extragrande vertical**). Script de ida y vuelta por título + alto: así se llega siempre.
- **Reinstalar el `.app` (o relanzar la app con otros argumentos) BORRÓ los widgets de la pantalla de inicio** dos veces. Compila lo definitivo antes de añadirlos y captura sin reinstalar entre medias.
- Un swipe que cae sobre un widget lo abre: la app arranca sin `-uitest` (Welcome) y reescribe la foto. Swipea por encima o por debajo del widget.

**Desde el 2026-10-31 (S35f) el antes/después NO pasa por la galería**: `qa/widget-render/` pinta todos los widgets
fuera de WidgetKit con la foto congelada (90 capturas en ~1 min). La galería queda para comprobar unos pocos en la
pantalla de inicio real (tintado de verdad): un script con `axe` que pulsa largo en un hueco, «Editar» → «Agregar
widget», busca «Yala» y recorre el pager leyendo la etiqueta «Yala Dev, <título>» y la PROPORCIÓN de la vista previa
(va escalada: pequeño 164 × 164, mediano 312 × 147, grande 312 × 326), con swipes de 360→60 en y=560: ~20 s por
widget y sin errores. El panel «Personalizar» (Original/Obscuro/Transparente/Teñido) se toca por coordenadas: no sale
en `describe-ui`.
