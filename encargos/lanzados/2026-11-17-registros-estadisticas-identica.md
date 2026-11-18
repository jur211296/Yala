Yala
# Estadísticas: la vista de Registros idéntica a Registros standalone
---
toca: Yala/App/Views/Statistics/RecordsTabView.swift,Yala/App/Views/Records/RecordsStandaloneView.swift,Yala/App/Views/Records/Compartida/,Yala/Resources/de.lproj/RegistrosCompartida.strings,Yala/Resources/en-GB.lproj/RegistrosCompartida.strings,Yala/Resources/en.lproj/RegistrosCompartida.strings,Yala/Resources/es-419.lproj/RegistrosCompartida.strings,Yala/Resources/es-AR.lproj/RegistrosCompartida.strings,Yala/Resources/es-ES.lproj/RegistrosCompartida.strings,Yala/Resources/es.lproj/RegistrosCompartida.strings,Yala/Resources/fr.lproj/RegistrosCompartida.strings,Yala/Resources/it.lproj/RegistrosCompartida.strings,Yala/Resources/ja.lproj/RegistrosCompartida.strings,Yala/Resources/nl.lproj/RegistrosCompartida.strings,Yala/Resources/pl.lproj/RegistrosCompartida.strings,Yala/Resources/pt-BR.lproj/RegistrosCompartida.strings,Yala/Resources/pt-PT.lproj/RegistrosCompartida.strings,Yala/Resources/pt.lproj/RegistrosCompartida.strings,Yala/Resources/zh-Hans.lproj/RegistrosCompartida.strings,YalaTests/RegistrosEstadisticasIguales/,tickets/done/2026-11-17-registros-estadisticas-identica.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Los componentes de `Yala/App/Views/Records/Components/` se reutilizan; si hace falta tocar alguno, mínimo y anotado en «Decidido sin consultar» (otra sesión de Pagos planificados los usa sin cambiarlos).

## Qué pidió Jürgen (17-nov, 17:35 Lima)
**B · Aparte: la vista de Registros dentro de Estadísticas** (`Statistics/RecordsTabView.swift`) debe ser **idéntica** a Registros standalone (`RecordsStandaloneView.swift`): mismos filtros, buscador, filas, agrupación, vista de lista/calendario, selección y menús, con el período de Estadísticas como filtro de partida. Lo ideal: extraer la vista compartida a `Yala/App/Views/Records/Compartida/` y que ambas la usen.


## Cómo entregar
- Si hacen falta textos nuevos, en una **tabla propia** `RegistrosCompartida.strings` (16 idiomas), no en Localizable.strings. Carpetas sincronizadas: no hace falta tocar el pbxproj.
- Probar en claro, oscuro, con el iPhone girado y en iPad, en el iPhone 14 por DeviceMCP. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Tests en `YalaTests/RegistrosEstadisticasIguales/`.
- Entregable visual: artifact de Claude con Registros standalone y la de Estadísticas lado a lado, antes y después. Nunca Markdown ni PDF.

## Reglas
- Sin esquema de datos nuevo. Commits y PR sin firma de IA, PR contra 2.3. Toca solo lo declarado; si hace falta otro archivo, mínimo y anotado en «Decidido sin consultar».
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión», sin mergear ni desplegar lo incompleto).
- Cierre: si está completo, CI verde y el modo lo permite, `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (sesión semi, lanzada en bypass): todas son menores y reversibles; las recomendaciones se dan
> por buenas y se discuten en el PR.

Hechos medidos antes de decidir: `RecordsStandaloneView` ya monta `RecordsTabView` como su lista. Lo que diverge son
tres llaves: `showsQuickFilters` (solo Registros: chips Cuenta · Categoría · Más filtros con Lista/Calendario en su
fila), el entorno `offersRecordsListSearch` (solo Registros: «Buscar en Registros» al tirar) y
`keepsCalendarAtReadableWidth` + página de una columna con el calendario en iPad (decisión 66 de 2.3, solo Registros).
Filas, agrupación por meses, menú «···», menú contextual, selección y barra de selección ya son los mismos componentes.
El período ya es global (`RecordsViewModel.period` lee `SessionState.selectedPeriod`), así que el de Estadísticas ya es
el de partida.

**D1 · ¿Mover `RecordsTabView.swift` a `Records/Compartida/` o envolverlo?** → Se crea
`Records/Compartida/RecordsSharedList.swift`, la única entrada a la lista, que fija las tres llaves igual para los dos
anfitriones; `RecordsTabView` se queda en su ruta y pierde `showsQuickFilters` (siempre con chips).
Por qué: 13 tests y 9 entradas del índice de cobertura leen el fichero por su ruta; moverlo es churn sin cambio para el
usuario. Alternativa descartada: `git mv` del fichero (mismo resultado, 20+ ficheros más en el diff).

**D2 · Buscar en Estadísticas › Registros: ¿recalcula toda Estadísticas por tecla?** → No: el texto del buscador
recalcula solo la lista (`RecordsViewModel.applyFilters`, con la misma espera de 150 ms que Registros).
Por qué: con diez años la pasada entera tarda segundos (decisión 28 de 2.3) y el buscador solo filtra la lista.
Alternativa descartada: reusar `onFilterChange` (pasada completa por tecla).

**D3 · Calendario en iPad dentro de Estadísticas** → igual que Registros (decisión 66): con la vista calendario en
ventana ancha no hay panel lateral, la lista va a ancho completo con el calendario a ancho legible, y lo abierto se
abre en hoja. Al pasar a calendario con un registro abierto en el panel, se cierra (como Registros), no salta a hoja.
Por qué: «vista de lista/calendario idéntica». Alternativa descartada: dejar el calendario apretado en 400 pt.

**D4 · Barra de arriba** → los botones de Registros (Seleccionar, «···») y la barra del modo selección
(Cancelar, Seleccionar todo) salen de una pieza compartida en `Compartida/`. «Seleccionar» solo con icono sigue siendo
cosa de la columna de lista del iPad en Registros (decisión 67): en Estadísticas no hay columna y el título cabe.
Por qué: misma pieza = no divergen. Alternativa descartada: copiar los items en los dos sitios (como hoy).

**D5 · Ficheros fuera de `toca:`** → `Statistics/DetailContainerView.swift` (anfitrión de Estadísticas: monta la
pieza, D2, D3, D4), `Records/Components/RecordsListSearchField.swift` (solo el comentario que decía «solo Registros»),
`qa/coverage-index.json` (contrato QA), y tests: `YalaUITests/RegistrosEstadisticasIguales/` (XCUITest: chips y
buscador en Estadísticas; conductor de capturas). Mínimos y anotados en el cierre.

**D6 · Textos nuevos** → ninguno previsto: todo reusa textos que ya existen. Si no sale ninguno, no se crea
`RegistrosCompartida.strings` (una tabla vacía no aporta).

**D7 · Decisión del 17-nov a incorporar** → se apunta en `.claude/rules/swiftui-ds.md` (no en `docs/DECISIONS.md`: su índice generado choca con cualquier otra sesión que escriba allí y frenaría el auto-merge) como la que sustituye a «Estadísticas ›
Registros no lleva chips (decisión 15, F2) ni buscador (decisión 14)». La parte de Pagos planificados y la de Yala web
no son de este encargo; se dice en el cierre. `decisiones.py incorporar-lote` no existe en la Max: se avisa.
