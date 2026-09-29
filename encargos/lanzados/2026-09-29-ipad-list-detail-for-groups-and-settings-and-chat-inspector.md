# iPad · fase 2: Grupos y Ajustes en dos columnas, y Yala IA al lado (carril adaptativo, paso 7/13)

## Contexto
Carril adaptativo, UNA sola sesión de Yala a la vez (orden Jürgen 28-sep 16:31). Tras Cola A #300 toca adaptativo. Fase 1 (#299) ya está en 2.1. La fase Duo (paso 6) sigue bloqueada por Xcode 27.1: NO la toques. Ticket: `tickets/backlog/ipad-list-detail-for-groups-and-settings-and-chat-inspector.md` (low, M). Lee el ticket, el plan `docs/exploracion/adaptativo-ipad-duo.md` §5–§7, el ADR «Yala se adapta por espacio, no por dispositivo» y lo medido en #299 (`swiftui-ds.md` «Layout adaptativo», `ListDetailSplit`, `RootTabLayoutLogic`).

## Que se pide
1. Grupos: lista a la izquierda y grupo abierto a la derecha (mismo molde de lista-detalle de la fase 1).
2. Ajustes: dos columnas en iPad (como Ajustes del sistema), no hoja pequeña con pilas.
3. Yala IA: `.inspector` en ancho regular junto a Panel/Registros/Estadísticas; en compact, la hoja de hoy.
4. Reusa el `NavigationSplitView` único que se pliega en compact; no `if` por dispositivo. Lo abierto sobrevive al redimensionar.
5. Evidencia solo en simuladores `YalaLane-Adapt-*` por UDID, DerivedData del worktree (`.ddp`):
   - `YalaLane-Adapt-iPad-mini` → `8BBAB498-9F59-40D6-9101-5CF4C0CCC7F3`
   - `YalaLane-Adapt-iPad-Pro-13` → `AE7C6D3F-6C1F-4F7E-8120-990D526A6C10`
   - `YalaLane-Adapt-iPhone-SE` → `8803FA85-BBAA-489A-8806-DA045587D151`
   - `YalaLane-Adapt-iPhone-ProMax` → `CDA87FB8-1261-431E-B85B-62786395C8F9`
   Capturas antes/después vertical y horizontal en los iPad; en SE y ProMax la navegación de siempre. XCUITest por UDID. Gate verde. PR a 2.1, `/cerrar-total`.

## Decisiones ya tomadas (Frank; no las vuelvas a preguntar)
- Misma regla de layout que la fase 1: por espacio, no por aparato.
- Reusa `ListDetailSplit` / patrones de #299; no inventes un segundo árbol.
- Fase Duo y Xcode 27.1 fuera de alcance. Residual a ticket si falta algo de Duo.
- Si un subcaso no cabe: ticket propio, no ampliar el alcance.

## Que NO hay que tocar
- Simuladores sin prefijo `YalaLane-Adapt-`. Siempre `-destination id=<UDID>`, nunca por nombre ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator`.
- No instalar Xcode 27.1 ni crear el simulador Duo.
- No arrancar Cola A / sync / nube ni Cola B.
- No abrir otra sesión Yala en paralelo.
- Disco del Mini: limpia DerivedData y scratchpads propios al cerrar. Había ~4 GB libres; se liberó a ~20 GB tocando solo restos de sesiones Yala ya cerradas.

## Como se sabe que esta bien
Criterios «Hecho cuando» del ticket. En iPhone compact no se rompe Grupos/Ajustes/Yala IA. Gate verde, PR mergeado a 2.1, cierre limpio.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board del repo y `/cerrar-total` sin preguntar. Ahora es horario diurno hasta las 21:00 Lima: AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás, opción recomendada. Pasadas las 21:00 no preguntes: elige lo recomendado o aplaza a ticket.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR o dejaste preview/artifact listo; (3) terminaste el ticket y vas a /cerrar-total, con un resumen corto de cierre en lenguaje de usuario; (4) acabaste un tramo y no tienes siguiente paso claro, una vez y no en bucle. NO avises por un test rojo que vas a reclasificar, un build que vas a reintentar ni ruido de CI advisory.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Grupos = `ListDetailSplit`**, como Planificación: el `navigationDestination(item: $viewModel.selectedGroup)` sigue
   en la columna de lista y presenta en la de detalle en ancho; en compacta empuja como hoy. Lo abierto ya vive fuera
   del split (`GroupsViewModel.selectedGroup`). Columna vacía con «Elige un grupo…» (cadena nueva, 16 idiomas).
2. **El detalle de grupo sabe si va en columna** (`GroupDetailView(presentation:)`, molde de
   `TransactionDetailSheet`): en columna no oculta la barra de pestañas/lateral ni pinta el chevron de volver; en pila,
   igual que hoy. La decisión la toma quien monta el split leyendo el size class FUERA de él (regla de #299).
3. **Ajustes = `ListDetailSplit` dentro de la misma hoja**, con `.presentationSizing(.page)` puesto en `ProfileView`
   (cubre los 7 sitios que lo abren). En iPhone `.page` es la hoja de siempre; en iPad, si el espacio de la hoja es
   ancho, salen dos columnas. Si la medición dice que una hoja no llega a ancho regular, subcaso a ticket, no una
   presentación distinta por aparato. La ruta programática (`initialDestination`) pasa a un `navigationDestination`
   del mismo tipo.
4. **Yala IA = `.inspector`** en lugar de `.sheet` en sus tres sitios (Panel, Registros, Estadísticas). En compacta
   SwiftUI lo presenta como hoja: se mide al píxel contra la de hoy en SE y Pro Max; si difiere en algo que no sea
   colocación, se queda la hoja en compacta. La conversación ya se persiste (`persistSession`/`loadPersistedSession`):
   se mide si sobrevive al redimensionar.
5. **Hook de test nuevo** `-uitest-ai-chat-ready` (consentimiento del chat y onboarding vistos) para montar el chat sin
   alertas; identificador `chat_input` en su campo. Solo DEBUG/uitest.
6. **Evidencia** con un XCUITest temporal (borrado antes del commit), por UDID en los cuatro `YalaLane-Adapt-*`, «antes»
   = este árbol antes de tocar vistas. Redimensionado con «Apps en ventanas» como en #299; si la vuelta a ancho no se
   automatiza, el ticket va a `qa` con guion.
7. **Gate** en los simuladores del carril por UDID (como #299), no en `iPhone 17 Pro`.
8. Fuera: Duo, resaltar la fila abierta (`ipad-list-highlights-the-open-row`), Panel/Estadísticas a lo ancho (2b).
