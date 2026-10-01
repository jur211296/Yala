# iPad · fase 3: atajos de teclado, puntero, menús contextuales y soltar recibos

## Contexto
Carril adaptativo (alternancia Cola A ↔ adaptive). La última sesión de producto fue Cola A `#311` (wipe-data, en cola de auto-merge). El ticket de crash `ipad-narrowing-the-window-on-groups-crashes-the-app` ya está en `tickets/done/` — no preempta. Este es el paso 9 del carril (`tickets/backlog/ipad-keyboard-shortcuts-pointer-context-menus-and-drop.md`); depende de la fase 1 (sidebar/list-detail) ya en 2.1 / qa.

Simuladores dedicados `YalaLane-Adapt-*` se recrearon justo antes de lanzar (iOS 27.0). Usarlos SIEMPRE por UDID (`-destination id=<UDID>`), nunca por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator` o tocar sims sin el prefijo. DerivedData propio del worktree (`-derivedDataPath .ddp`).

UDIDs actuales (recreados 2026-09-30):
- YalaLane-Adapt-iPhone-SE → A7CA1E5C-C2C0-4AA9-BC5C-8841F30799C8
- YalaLane-Adapt-iPhone-ProMax → 411B12E4-14B6-4D0F-B21E-AEE2C8183D5A
- YalaLane-Adapt-iPad-mini → 98521AEE-0E30-4C45-90E2-DE73AA95D3A7
- YalaLane-Adapt-iPad-Pro-13 → B3E3D8D6-8F1B-4D8D-B862-FE966BA16681

## Qué se pide
Implementar fase 3 del carril adaptativo según el ticket:
- Atajos en `.commands` (⌘N, ⌘⇧N, ⌘F, ⌘K, ⌘1…⌘6, ⌘,, ⌘E, ⌫, ↑↓) — lista exacta en el ticket.
- Resaltado al pasar el puntero (`.hoverEffect`) en filas, tarjetas y chips.
- Menús contextuales en filas de registro, presupuesto, grupo y cuenta (también long-press en iPhone/Duo).
- Soltar imagen/PDF de recibo sobre Yala → abre Nuevo registro por imagen. Fuera de alcance: soltar un registro sobre otra cuenta.
- Criterio de hecho del ticket: capturas en Adapt-iPad-Pro-13 y Adapt-iPhone-ProMax; XCUITest de ⌘N/⌘F en iPad por UDID; gate verde.
- Layout por size class/ancho (ADR 2026-09-27), no por tipo de dispositivo.

## MODO AUTÓNOMO HASTA TERMINAR (cola / ADR-054)
Sesión de la cola en bypass. Tren completo sin checkpoints de proceso: implementar → `/gate` → commit → PR → `gh pr merge <n> --auto --merge` (modo cola de auto-merge; comprobar `autoMergeRequest`; NO esperar a que el CI ponga verde antes de encolar; NO borrar la rama remota) → board y `docs/TICKETS.md` → `/cerrar-total`. Parte en el cuerpo del PR.

## Qué NO hay que tocar
- Simuladores sin prefijo `YalaLane-Adapt-` (son de Cola A / otros).
- Mover dinero soltando un registro sobre otra cuenta.
- Release / TestFlight / producción.
- El ticket de crash de narrowing (ya done); no reabrirlo salvo que lo vuelvas a reproducir de verdad.

## Como se sabe que esta bien
Gate verde; PR en cola de auto-merge a 2.1; ticket movido según el tren; capturas/evidencia del «Hecho cuando» del ticket; `/cerrar-total` limpio.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Dónde viven los atajos?** → `.commands` en la escena, leyendo acciones que publica `MainTabView` con `focusedSceneValue`.
Por qué: cada ventana del iPad manda sobre sí misma, las etiquetas de ⌘1…⌘6 siguen el orden real de la barra lateral y fuera de la app montada (onboarding, splash) los atajos no existen. Alternativa descartada: `.commands` con singletons; ignoraría la ventana y el orden.

**D2 · ¿Qué hace un atajo global con algo ya presentado?** → Nada. Antes de actuar pregunta a `ModalPresentationProbe` y al `shellModalBlocker`.
Por qué: una presentación encendida con el anchor ocupado no monta y puede dejar su flag pegado (regla de presentaciones de `swiftui-ds.md`). Alternativa descartada: encolar por el router todo; ⌘, y ⌘K no tienen intent y crearlos es más superficie.

**D3 · ¿Dónde abren ⌘N, ⌘K y ⌘,?** → Sobre el Panel: ⌘N por el router (`navigate(.panel)` + `presentNewTransaction`, el camino del Centro de Control); ⌘K y ⌘, con una petición en `SessionState` que consume el Panel (su `startChat()` y su hoja de Ajustes). ⌘⇧N usa `navigateToGroupsAndComposeExpense()` del FAB.
Por qué: reusa los caminos que ya tienen puertas Pro/consentimiento. Alternativa descartada: presentar en cada página; siete hosts más.

**D4 · ¿Qué alcance tienen ⌘E, ⌫ y ↑↓?** → Solo en Registros (la página de la barra lateral), con la ventana ancha y el registro abierto en columna; ↑↓ sin nada abierto abre el primero.
Por qué: «el registro abierto» solo existe ahí; en compacta el detalle es una hoja. Estadísticas › Registros queda fuera. Alternativa descartada: también en compacta; ahí no hay registro abierto que editar.

**D5 · ¿Qué ofrece el menú contextual de un registro?** → Editar, Duplicar, Cambiar categoría y Eliminar (con confirmación). Duplicar y Eliminar se ocultan en cualquier registro con puntero de grupo; Cambiar categoría sigue `BridgedEditPolicy` y se oculta en transferencias y ajustes.
Por qué: el menú no puede ofrecer lo que el editor prohíbe, y no hace el fetch que el editor hace para detectar huérfanos, así que es más estricto. Alternativa descartada: replicar el fetch en cada fila.

**D6 · Menús de presupuesto, grupo y cuenta: ¿qué acciones?** → Solo atajos a flujos que ya existen: presupuesto → Editar; grupo → Abrir grupo y Nuevo gasto; tarjeta de cuenta del Panel → Filtrar por esta cuenta y Editar cuenta. Ningún borrado nuevo.
Por qué: el ticket no fija acciones y un borrado nuevo es un camino destructivo sin pedir. Alternativa descartada: añadir Eliminar/Archivar.

**D7 · Soltar un recibo: ¿por dónde?** → El mismo camino que la extensión de compartir: se escribe en `PendingImages/` como JPEG (un PDF se rasteriza en su primera página) y se llama a `enqueueSharedImage`. Sin acceso Pro a la entrada por imagen, aviso de Pro y no se guarda nada.
Por qué: reusa consentimiento y recuperación; sin el candado Pro el fichero se re-emitiría en cada vuelta a primer plano. Alternativa descartada: un camino propio al `ImageSelectionView`.

**D8 · Puntero** → `.hoverEffect(.highlight)` con su forma en fila de registro, fila de presupuesto, tarjeta de grupo, tarjeta de cuenta y chips de filtro. En iPhone no hace nada.
Por qué: son las piezas que el ticket nombra; es un modificador sin efecto sin puntero.

**D9 · Menú contextual en modo selección** → No se engancha: en ese modo el toque selecciona.
