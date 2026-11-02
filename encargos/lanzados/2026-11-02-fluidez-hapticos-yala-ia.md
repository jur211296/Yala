---
esfuerzo: high
release: no
---
# Segunda tanda de vibraciones y Yala IA: borrador, error y voz con transición y háptico

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `fluidez-hapticos-yala-ia` · Sesión cola **S35n** · al cerrar → **S36** (`barrido-qa-2-2-b`).

## Contexto
Estas cards salen de la auditoría de fluidez de `fluidez-animaciones-hapticos` (PR #720), que dejó el sistema común en `.claude/rules/swiftui-ds.md` («Fluidez: el sistema común»), `DS.Animation` y `DS.Haptic`. La auditoría completa está en `docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`: usa las filas marcadas C4, C8.

Regla de Jürgen (2026-10-30): todo lo que sale de una sesión entra en 2.2 antes del barrido QA, nada a backlog.

Pantallas: Ajustes, el formulario, gráficas, Bandeja, onboarding, pagos, borrados, errores al guardar y el chat de Yala IA.

Cards:
- `tablero ver tablero-fluidez-c4-segunda-tanda-de-hapticos-86b1` — Fluidez C4: segunda tanda de hápticos
  - Problema: Faltan hápticos en selectores de Ajustes, chips del formulario, etiquetas, sectores y scrub de gráficas, Bandeja (selección, editor), onboarding, pagos (pagado, guardar, borrar), borrado de registros al confirmar, errores al guardar; la Bandeja usa UIImpactFeedbackGenerator suelto.
  - Hecha cuando: Cada fila C4 de la auditoría con su háptico del mapa de DS.Haptic (uno por gesto) y la Bandeja migrada a DS.Haptic.
- `tablero ver tablero-fluidez-c8-yala-ia-borrador-error-y-voz-6sld` — Fluidez C8: Yala IA, borrador, error y voz
  - Problema: En el chat, la tarjeta del borrador pasa de pendiente a guardada o descartada sin transición, el banner de error entra en seco y sin háptico, y nueva conversación y el panel de voz no vibran.
  - Hecha cuando: Esos estados con transición y háptico del mapa; vídeo del chat.

## Qué se pide
1. Lee la auditoría (filas C4, C8) y el sistema común. Resuelve cada fila con `DS.Animation`/`DS.Haptic`, respetando Reducir movimiento, sin inventar curvas ni hápticos nuevos.
2. Para cada card, cumple su «hecha cuando», con tests (unitarios, source-scan o XCUITest según la card) y vídeo o capturas antes y después en `capturas/` y en el digest.
3. Pasa las cards a «in qa» de Jürgen al abrir el PR (con `--agente` de la sesión).

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Filas de la auditoría de otras cards de Fluidez.
- La lógica de datos, la sincronización y el servidor.
- marketing/ ni Web/.
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Cada card cumple su «hecha cuando».
- No hay elementos duplicados en accesibilidad ni XCUITest rotos.
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge y vídeo o capturas.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0

Auto-contestado (sesión autónoma, opción conservadora en cada caso):

1. **Mapa de hápticos, sin hápticos nuevos.** selección → `selection()`; guardar/aprobar/marcar pagado/deshacer real → `success()`; error al guardar o validación → `error()`; borrar o descartar al confirmarlo → `warning()`; acciones sin resultado (empezar a grabar, enviar lo dictado, ocultar aquí) → `light()`/`medium()`. Uno por gesto: si el ViewModel ya vibra, la vista no.
2. **Éxito tras el guardado, no en el botón.** Donde hoy vibra antes del `do/catch` (aprobar deslizando en la Bandeja), se mueve detrás del éxito.
3. **Gráficas: `selection()` al cambiar de sector o de barra**, no en cada fotograma del arrastre (solo cuando cambia el elemento elegido).
4. **Reordenar: `selection()` al soltar**, que es el gesto de iOS para un cambio de orden.
5. **Errores al guardar con alerta: `error()` al mostrarse la alerta** (`onChange` del flag), salvo donde ya vibre.
6. **C8 — tarjeta del borrador:** las ramas pendiente / guardado / descartado / fallido se funden con `DS.Animation.appear`, implícita en el contenedor de mensajes (el chat también vive en una columna junto a una pestaña). La que se va deja de leerse y de tocarse desde su primer fotograma (molde `LoadingExitTransition`), para no duplicar el árbol de accesibilidad. Descartar → `warning()`.
7. **C8 — banner de error:** entra y sale con `.appear` y vibra `error()` al aparecer.
8. **C8 — nueva conversación:** `warning()` al borrar (es el borrado, sin diálogo); `success()` si «Deshacer» la repone. Las animaciones pasan por Reducir movimiento.
9. **C8 — voz:** `medium()` al empezar a grabar, `light()` al enviar con «Listo» (como enviar texto); cancelar no vibra. La entrada/salida del panel pasa por `dsAnimation` (hoy ignora Reducir movimiento).
10. **Tests:** source-scan en `FluidezWiringTests` (o suite hermana) por fila; los hápticos no se ven en XCUITest. Vídeo antes/después del chat en el simulador.
