# Una sola Yala: Flujo de caja + Grupos (lienzo)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `una-sola-yala-flujo-grupos` · Sesión cola **S11** · al cerrar → **S12**.

## Contexto · cards del lote
- Flujo de caja tiene que sentirse la misma app: alinear sus pantallas con el diseño del resto
- Grupos tiene que sentirse la misma app: alinear sus pantallas con el diseño nuevo de Registros y Estadísticas

## Briefs per-card (lee y cumple cada uno)
- `~/Claude/tmp-frank/flujo-caja-misma-app-e7by.md`
- `~/Claude/tmp-frank/grupos-misma-app-k2up.md`

## Qué se pide
1. Lee ambos briefs y el lienzo «Una sola Yala» (decisiones Jürgen 19-oct: todas las recomendadas).
2. Implementa piezas Flujo 2/5/6 + Grupos 1/3/4 + comunes en un PR coherente a 2.2.
3. Antes de diseñar UI: mira `~/Claude/referencias-ui/README.md` (inspiración, no copies marcas).
4. Capturas antes/después en `capturas/`.

Mueve las cards a «in progress» con `--agente frank` al empezar; al cerrar, a in qa / done según el cierre de cada una.

## Qué NO tocar
- marketing/ y Web/ (Lola).
- Otras sesiones de la cola (no las lances).
- No desactivar tests ni saltarte el gate.
- Lo específico de cada brief per-card.

## Cómo se sabe que está bien
Cada card cumple su hechaCuando; suite relevante verde; PR a 2.2 en auto-merge; `/cerrar-total`.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones (resueltas en autónomo, bypass, 2026-10-26)

Medido en `origin/2.2` `1b043c9a1`. El inventario del 19-oct caducó en parte: Flujo de caja ya trae casi todo
alineado por el lote 12.5 (hero en crear plan y en el mes, filas con icono 40, `BudgetProgressBar`, `RecordRowView`
en «Últimos registros», alto adaptable en las gráficas, cápsula de mes rellena en acento, sin mayúsculas, montos con
`amountTint`, selector en pastilla en «Agregar línea»), y Ajustes/Miembros del grupo ya son `YalaSettingsList`.

1. **Qué se implementa.** Las fichas del lienzo que siguen sin alinear hoy (todas las recomendadas + sin pregunta).
   Lo ya alineado no se toca.
2. **Pieza común: chip de pestaña.** Se saca a un componente compartido (`NavigationChipButton`) con dos modos:
   nombre solo en el elegido (Estadísticas, Grupos) y nombre siempre (Planificación, Reportes: «el nombre cabe y se
   queda», lienzo). Reportes pasa además a `navigationChipsInset`.
3. **Pieza común: cifra del grupo (3A).** Un solo hero del grupo (`HeroHeader` + `panelHeroAmount`) en Gastos y en
   Saldos, alimentado por el mismo cálculo (`GroupBalancesPresentationLogic.summary`), para que al cambiar de pestaña
   la cifra no se mueva. Primera divisa grande; las demás y el detalle en la línea de abajo. Saldos pierde la tarjeta
   en cristal. En Gastos el hero sigue llevando a Saldos al tocarlo (la banda de hoy lo hace; no quito una salida).
4. **Fila de gasto de grupo (1A).** Icono en círculo lleno de 40 (como `RecordRowView`), cifra en blanco si debes y
   turquesa (`amountTint`) si te deben, y la relación en la pastilla de debajo («Te deben» / «Debes»), no en un rótulo
   encima. Cabecera de día = `RecordDateSectionView` y separación `sm`, como Registros.
5. **Período en Estadísticas del grupo (4A).** La cápsula `PeriodSelectorLabel` de Estadísticas como etiqueta del
   menú del grupo (los períodos del grupo no cambian: `GroupStatsPeriod`), a la derecha del rótulo del hero; la de
   divisa, igual y solo con más de una divisa. «Total gastado / Mi parte» se funden en el hero «Gastado en el grupo»
   con «tu parte …» debajo. Barras de «¿Quién puso más?» en el acento liso; tendencia con alto adaptable.
6. **Saldos, sin pregunta.** Deudas en tarjeta normal (`panelCard`), sin cristal teñido; «Saldar» con el relleno de
   acento y `onAccent`; títulos con `YalaSectionHeader`. La tarjeta de pago pendiente (L13-2) se queda: es un aviso.
7. **Color de montos en Grupos.** Turquesa solo lo que te deben, blanco lo que debes: tarjeta de la lista, banda de la
   lista de grupos, detalle del gasto («tu parte»), saldos iniciales de Miembros. `Color.groupBalance` (sin llamadores)
   se retira.
8. **Lista de grupos.** La línea pequeña pasa a hero «En tus grupos te deben» con la cifra de 36 pt (ficha de la lista).
9. **Detalle del gasto de grupo a media pantalla.** Se abre en `[.medium, .large]` con `yalaSheetDetents` y «tu parte»
   en blanco con su pastilla. La reorganización completa (tarjeta de datos y «Duplicar · Eliminar» abajo) solo si cabe
   sin rehacer la hoja; si no, ticket aparte a backlog.
10. **Flujo de caja (2A, 6A, sin pregunta).** Línea del plan con la cifra de Presupuestos («Te quedan / Te pasaste»,
    `BudgetRemainingFigure`) donde falte; gráficas en `panelCard` sin el título duplicado de la hoja; «Gastos por
    revisar» con la fila de Presupuestos; hojas con `yalaSheetDetents`. 5A ya está hecho (se verifica, no se toca).
11. **Textos nuevos** («Te deben», «Debes», «Gastado en el grupo», «En tus grupos te deben»): reutilizar claves que ya
    existan; las nuevas, en los 16 idiomas.
12. **Capturas.** Conductor XCUITest local (no se commitea) con la semilla `ficha`, modo claro, iPhone 17 Pro iOS 27.0,
    antes y después en `capturas/`.
13. **Review adversarial: no** (polish visual; no toca cálculos ni sync). Sí `/gate` entero.
