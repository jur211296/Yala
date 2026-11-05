# Lote T2 · XCUITest en iPad
toca: `YalaUITests/`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador de iPad (pipeline serial; 1 sim).
Lote tests (cola-2-3-propuesta.md §3 T2).

Cards:
1. El XCUITest de ⌘F para abrir Buscar.
2. En el iPad, el test de la barra lateral falla.
3. Los XCUITest de navegación buscan la barra de pestañas del iPhone.
4. Los XCUITest del registro por imagen no llegan al botón flotante en el iPad.

Hecha cuando: los cuatro pasan de forma estable en iPad sim. No «arregles» skipéandolos sin causa documentada.

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass) salvo D2 y D3, que contestó el bot dueño de la sesión. Se discuten en el PR.

**D1 · ¿Sobre qué rama?** → `2.3`, como dice el encargo; PR contra `2.3`.
Por qué: el worktree nació de `2.2` y Jürgen lo pidió explícito. Alternativa descartada: `2.2` (base del worktree por defecto).

**D2 · Alcance de la card de pestañas (72 usos de `tabBars` en 41 ficheros)** → helper de pestaña por nombre y migrar
SOLO los usos que eligen pestaña, en todas las suites; los que comprueban la barra o leen su estado se quedan y van
listados en una card nueva con cierre propio. El criterio «`tabBars` solo dentro del helper» queda parcial.
Por qué: contestado por el bot dueño (opción C). Alternativa descartada: migrar los 72 (PR enorme, sin ganancia en iPad).

**D3 · `LaunchSliceUITests` comprueba `tabBars` sin elegir pestaña y sale rojo en iPad** → helper «la navegación raíz
está montada» (barra de pestañas o barra lateral) en sus dos usos.
Por qué: contestado por el bot dueño (opción A); es la misma comprobación. Alternativa descartada: dejarla roja.

**D4 · Registro por imagen en iPad** → la suite entra por la acción de imagen del Panel (`panel_action_image`) en
ventana ancha y por el FAB en iPhone, decidido por el idioma del aparato en el test.
Por qué: la suite cubre la hoja de imagen, no el menú del FAB; en iPhone el FAB sigue cubierto. Alternativa
descartada: entrar siempre por la fila (pierde el FAB en iPhone) o declarar la suite de iPhone (la deja sin cubrir).

**D5 · Barra lateral detrás de los casos de estrechar** → arreglar el origen: el caso que estrecha devuelve la ventana
a como estaba al terminar (`addTeardownBlock`). **Revisada al medir:** además, la suite arranca con la ventana a
pantalla completa en el iPad.
Por qué: con el teardown, el par «estrechar + raíz» pasa y sin él falla (control en las dos direcciones); pero una
traza del ancho en cada arranque enseñó un segundo origen que no es de esta suite ni de Yala (la ventana vuelve
flotante a 375 pt al girar tras un caso en vertical). Los tests de la suite ya dan por hecho «iPad a pantalla
completa». Alternativa descartada: reordenar o reintentar en el de la raíz.

**D6 · ⌘F** → el test pulsa Escape antes de ⌘F, con el porqué escrito, y card de producto aparte para probarlo en un
iPad real (contestado por el bot dueño, opción A).
Por qué: medido con trazas en la app, el primer ⌘F tras abrir no llega a la app en el simulador; ⌘4/⌘N sí, y con una
tecla antes ⌘F también. La hipótesis del ticket era falsa (`launch()` ya espera `uitest_ready`). Alternativa
descartada: seguir con la causa en UIKit dentro de este lote.
