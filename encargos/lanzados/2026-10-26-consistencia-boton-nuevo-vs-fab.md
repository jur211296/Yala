---
esfuerzo: medium
---
# Consistencia botón «nuevo» vs FAB — patrón Panel en toda la app

**Card:** `tablero-consistencia-boton-nuevo-vs-fab-panel-pa-kzhe` · Yala 2.2 · medium · cierre cierra-sola  
**Fuente:** Jürgen 2026-10-24 ~20:05 Lima. Notas Duo: `~/Claude/tmp-frank/duo-comentarios-jurgen-2026-10-24.md` (sección Consistencia botón vs FAB).

## Contexto
En el **Panel** el CTA primario ya es un botón «nuevo …» bajo el hero/cabecera; el FAB solo aparece al hacer scroll. En el resto de pestañas principales sigue el FAB fijo desde el tope. Jürgen quiere el mismo patrón app-wide.

Cola viva de Jürgen (2026-10-26): **FAB → barrido QA → capturas**. Lanzar esta sesión **antes** del barrido. Cola 12.1–12.7 y Duo cerrado (opción 2 + comentarios) ya están hechos; el barrido **no** es prerequisito de esta card.

Base: `origin/2.2`. PR contra **2.2**. Effort **medium**.

## Qué se pide
1. Mueve la card a «in progress» con `--agente frank` si no lo está.
2. Usa **Panel** como referencia del patrón correcto (botón arriba + FAB solo al scroll).
3. Audita e unifica en:
   - **Estadísticas** — todas las subpestañas (hoy FAB fijo).
   - **Presupuestos** — «nuevo presupuesto» como botón arriba.
   - **Pagos planificados** — igual.
   - **Grupos** — comprobar si aplica el mismo patrón; si sí, unificar; si no aplica, déjalo documentado en la nota de la card.
4. Botón «nuevo …» arriba (bajo hero / cabecera), no FAB fijo desde el tope.
5. FAB solo como recurso al **hacer scroll**, para tenerlo a mano.
6. Capturas **antes/después** (Duo cerrado e iPhone si aplica) en `capturas/` o la carpeta de entregas de la sesión.
7. Tickets nuevos de lo que encuentres, con su card.
8. `/cerrar-total` al terminar (merge incluido, un solo aviso).

## Qué NO hay que tocar
- **No mezclar** con la sesión Duo de layout/ancho (ya cerrada; no reabrir layout Duo).
- marketing/ y Web/ (Lola).
- Barrido QA 2.2 (va **después** de esta sesión; no lo lances aquí).
- Capturas App Store (después del barrido).
- Despliegues CloudKit/Supabase/Worker.
- No desactivar tests ni saltarse protecciones de rama.

## Cómo se sabe que está bien
Se cumple el «hecha cuando» de la card: en todas las vistas principales el CTA primario es botón arriba (como Panel); el FAB solo aparece al hacer scroll; capturas antes/después; suite relevante en verde; PR a 2.2 en auto-merge; card a done (o in qa solo si hace falta ojo de Jürgen).

## Gate después del CI del PR anterior
Arranca ya sobre `origin/2.2`. Justo antes del gate, si hay un PR de 2.2 en CI, espera a que entre y rebasea una sola vez con el simulador apagado. Si 2.2 no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

## Mini
Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees cerrados (sin preguntar); (2) build `xcodebuild -jobs 2` / `nice -n 10` sin sim booteado; (3) bootear 1 solo simulador iPhone; (4) tests; (5) apagar y borrar ese sim y el DerivedData de esta sesión. Prohibido solapar build, sim y UITests. No toques el working tree sucio de `~/Yala` (scheme local de Jürgen).

## Ritmo
Después de esta card: barrido QA → capturas App Store. Ve directo; no alargues fuera de esta card.

/cerrar-total

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Cómo decide cada página cuándo sale el flotante.** El Panel usa umbrales fijos de desplazamiento (180/150) porque su fila está siempre a la misma altura. Las demás tienen cabeceras de alto variable, así que decide el propio botón de arriba con `onScrollVisibilityChange` (umbral 0,5): fuera de vista → flotante; a la vista → sin flotante. Componente compartido nuevo en `Views/Shared/TopPrimaryAction.swift`. El Panel no se toca.
2. **Estadísticas (las 4 subpestañas).** Bajo el hero de cada una, la misma fila del Panel (`PanelQuickActionsRow`: Nuevo registro · Voz · Foto · Yala IA), con prefijo de ids `stats_` y sin anclas del tour Pro (el tour es del Panel). Gates Pro/consentimiento por los handlers que ya tiene `DetailContainerView`. El `FABStackView` solo al perder la fila de vista.
3. **Presupuestos.** «Nuevo presupuesto» (píldora de acento) bajo el selector de período, antes de la lista; mismo gate de límite que el FAB.
4. **Pagos planificados.** «Nuevo pago planificado» bajo el hero «Por pagar».
5. **Grupos: sí aplica.** Bajo el resumen global: con algún grupo donde apuntar, «Nuevo gasto» (acento, la acción más frecuente) + «Nuevo grupo» (tarjeta); sin ninguno, solo «Nuevo grupo». El flotante (simple o desplegable) solo al hacer scroll. Con solo archivados (sin scroll y con CTA en el vacío) se quita el flotante fijo.
6. **Registros (página propia) fuera:** no está en la lista del encargo ni tiene hero con hueco; queda anotado como hallazgo con card.
7. **Ids de XCUITest.** Los botones de arriba llevan ids nuevos (`budgets_create_button`, `scheduled_payments_create_button`, `groups_action_new_group`, `groups_action_new_expense`, `stats_action_*`); los flotantes conservan los suyos. Los tests que creaban desde arriba pasan a los ids nuevos.
8. **Capturas.** iPhone 17 Pro (iOS 27.0). Duo cerrado no: el runtime 27.1 no está montado en esta Mac (~45 min de descarga) y su simulador no se deja conducir por axe; el cambio no toca layout del Duo.
