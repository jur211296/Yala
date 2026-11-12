# Yala 2.2 · Tocar un segmento de una gráfica pregunta «Ver solo / Ocultar», con incluir y excluir combinables

esfuerzo: high

## Contexto
Card `tablero-al-tocar-un-segmento-de-una-grafica-con-5g94` (léela con `tablero ver`). Decisiones de Jürgen: 2026-10-12 opción B (combinación real de incluidos y excluidos por dimensión, con /spec antes de implementar); 2026-10-25 propuesta A de UI: al tocar un segmento, diálogo «Ver solo X / Ocultar X / Cancelar», y los dos tipos de filtro visibles a la vez en la barra. El /spec de la opción B ya está escrito en el ticket `tickets/backlog/stats-filter-segment-tap-should-ask-include-or-exclude.md` (lote 12.5, PR #631, con maquetas). Toca el modelo de filtros (~45 ficheros), por eso va en sesión y PR propios. Base `origin/2.2`, PR contra 2.2. Ya cerraron 12.1–12.7 (PR #633 en cola de merge).

Antes de tocar UI mira `~/Claude/referencias-ui/README.md` como inspiración (sin copiar marcas ni pantallas).

## Qué se pide
1. Mueve la card a «in progress» con `--agente frank` si no lo está.
2. Implementa el /spec del ticket: modelo de incluidos y excluidos por dimensión, diálogo A al tocar un segmento y barra con los dos tipos de filtro.
3. Paridad Panel / Estadísticas / Registros fijada por tests (totales y saldos iguales con la misma combinación de filtros). Haz una review adversarial del cálculo de saldos y totales antes del PR.
4. Migración del estado de filtros guardado: lo que ya tenga el usuario debe seguir funcionando.
5. Dudas reversibles: opción recomendada y nota en la card. Lo irreversible, a «espera decisión» a jurgen, y sigue con lo demás.
6. Capturas antes/después en `capturas/` (diálogo y barra).
7. Tickets nuevos de lo que encuentres, con su card.

## Qué NO hay que tocar
- marketing/ y Web/ (Lola).
- FAB / consistencia del botón «nuevo» (sesión siguiente).
- Barrido de QA 2.2.
- Despliegues CloudKit/Supabase de producción.
- No desactivar tests ni saltarse protecciones de rama.

## Cómo se sabe que está bien
Se cumple el «hecha cuando» de la card: tocar un segmento pregunta «Ver solo / Ocultar», se combinan incluir y excluir en la misma sesión de filtros, paridad fijada por tests; suite unit en verde; PR a 2.2 en auto-merge; `/cerrar-total`.

## Gate después del CI del PR anterior
Arranca ya sobre `origin/2.2`. Justo antes del gate, si #633 (u otro) sigue en CI, espera a que entre y rebasea una sola vez con el simulador apagado. Si 2.2 no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

## Mini
Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees cerrados (sin preguntar); (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 solo simulador iPhone; (4) tests; (5) apagar y borrar ese sim y el DerivedData de esta sesión. Prohibido solapar build, sim y UITests. Disco ~26 GB libres (<32, APRETADO): limpia sin preguntar antes del build (`limpiar-mac --apply` si hace falta).

## Ritmo
Después: FAB → barrido → capturas App Store. Ve directo; no alargues fuera de esta card.

/cerrar-total

## Paso 0 (Frank, 2026-10-25, MODO AUTÓNOMO)

Medido antes de decidir: los filtros de sesión viven solo en memoria (`SessionState`, sin clave en UserDefaults ni en
el App Group); el asistente de Exportar tiene su propio «Mostrar solo / Ocultar» local, independiente de la sesión.

1. **Modelo.** Por dimensión, los conjuntos de hoy (`selectedAccountIDs`, …) pasan a significar «incluidos» y se
   añaden sus gemelos `excluded*`. `isExcludeMode` se borra de `SessionState`, `FilterCriteria` y `Filterable`: así el
   compilador señala cada lectura que dependía del modo. Regla única `EntityFilter.matches`: si hay incluidos, el id
   tiene que estar; nunca puede estar en excluidos.
2. **Mismo id en los dos conjuntos:** el último que escribe gana (marcarlo en uno lo quita del otro). En el cálculo,
   excluido gana.
3. **Migración.** No hay nada en disco que migrar (medido). Lo que «ya tenía el usuario» es la semántica: un filtro de
   incluir sigue igual; uno de excluir pasa a los conjuntos `excluded*` con el mismo resultado. Exportar se queda con su
   modo local (diferido del /spec); su resultado no cambia.
4. **Diálogo A.** Hoja corta propia, no `.alert` (sus botones no admiten texto dinámico: `swiftui-ds.md`) ni
   `confirmationDialog` (no pinta «Cancelar»). Arriba, nombre e importe; «Ver solo X», «Ocultar X», «Quitar el filtro»
   si X ya está filtrado, y «Cancelar».
5. **Dónde pregunta:** tartas, lista de Detalle, Sankey y necesidades de Distribución, y también las tartas y tops del
   Panel (el mismo gesto no debe escribir distinto según la pantalla). Pregunta siempre, también sin filtros. Los nodos
   «pool» del Sankey no son filtro de sesión: siguen igual.
6. **Barra:** incluidos «Solo X» en lila, excluidos «Sin X» con el contorno rojo, cada uno con su ✕, a la vez.
7. **Hoja de Registros:** el segmento «Mostrar solo / Ocultar» decide qué conjunto escribe un toque; cambiarlo ya no
   vacía nada, y cada chip enseña su estado.
8. **Yala IA (Observaciones):** el resumen de filtros manda incluidos y excluidos por separado.
