# Revisión por vistas 2.3 · Registros, filtros, calendario y búsqueda

**Qué es.** Revisión de UX de la zona 31 del mapa de cobertura, sobre `origin/2.3` del 7-nov-2026. No cambia la app y
no elige: deja seis problemas priorizados, de 3 a 4 alternativas maquetadas para cada uno y una recomendación. Decide
Jürgen.

**Cómo abrirla.** `index.html` en el navegador (las páginas enlazan entre sí y las capturas van en `capturas/`). Desde el
móvil, `revision-registros.pdf`, con lo mismo.

**El caso.** Ana busca el «Almuerzo de trabajo» de S/ 45.90 que pagó con la Cuenta Principal el 17 de octubre (hace
3 semanas), entre 2.334 registros de dos años; filtra por cuenta y categoría, quita los filtros y corrige en lote la
categoría de tres taxis. Datos ficticios en las maquetas; semilla de pruebas «realista» en las capturas.

## Vistas cubiertas

| Vista | Capturas |
|---|---|
| `RecordsStandaloneView` | con datos, vacía, lista arriba y muy abajo, texto grande (AX3), iPad |
| `RecordRowView` · `RecordDateSectionView` | filas y cabeceras, normal y AX3, en selección |
| `RecordsCalendarView` | mes actual, mes anterior, día elegido, AX3, iPad |
| `RecordsFiltersView` + `FilterChipView` | hoja, categorías, elegidos, aplicados, sin resultados, tras limpiar, Panel después, AX3 |
| `GlobalSearchView` | recientes, resultados, sin resultados, por importe, AX3 |
| `TransactionSnippetView` | sin captura (Siri no se puede conducir en el simulador): reconstruida del código |
| Menú contextual y edición masiva | menú, selección vacía, 3 elegidos, todo elegido, borrar todo, «Editar 3 registros» |

Sin conexión y sin permisos no cambian estas vistas (trabajan con los datos del teléfono). «Cargando» no tiene indicador
y un error de carga no se enseña: está en los hallazgos secundarios.

## Problemas y recomendación

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Buscar desaparece justo en Registros y no entiende importes | Alta | **B1** · campo de búsqueda dentro de Registros (con importe) |
| 2 | Filtrar por cuenta y categoría pide 7 toques, dentro de «···» | Alta | **F2** · chips rápidos encima de la lista |
| 3 | Con la lista vacía, el filtro culpable queda fuera de pantalla | Alta | **L1** · banda «Filtrando por…» con «Quitar todo» |
| 4 | En «Todo el tiempo», la lista no dice el año ni deja saltar a un mes (9 deslizamientos hasta hace 3 semanas) | Media-alta | **T2** · separador de mes fijo que lleva a otro mes (+ T1, año y total del día) |
| 5 | «Seleccionar todo» marca 2.334 registros y el lote no se puede deshacer | Alta | **E1** · «Deshacer» también en lote (+ el texto de E2) |
| 6 | Al tocar un día del calendario, lo que cambia queda fuera de la pantalla | Media | **C2** · el calendario se pliega a la semana |

Si hay que empezar por lo barato: B3, F1 + F3, L3, T1 y E2 son cambios de texto o de sitio y no cierran la puerta a lo
anterior.

## Decisiones para Jürgen

1. ¿Registros tiene su propio campo de búsqueda (B1), y Buscar busca también por importe?
2. ¿Fila fija de chips sobre la lista (F2), o solo «Filtros» a la vista y arreglar la hoja de categorías (F1 + F3)?
3. ¿Los filtros siguen siendo de la sesión (los ven Panel y Estadísticas) o pasan a ser de cada pantalla (L4)?
4. ¿Separador de mes y año en la cabecera (T2 + T1)? ¿Registros sigue abriendo en «Todo el tiempo»?
5. ¿«Deshacer» en lote (E1)? Pide medir cuánto cuesta guardar el «antes» de miles de registros.
6. ¿Calendario plegado a la semana (C2) o el día en una hoja (C1)? ¿Se reabre L8-10 para poner moneda en la celda?

## Qué es medido y qué no

- **Medido:** capturas del simulador (iPhone 17 Pro, iOS 27.2, Yala Dev de `origin/2.3`), 9 deslizamientos hasta el
  17 de octubre, tamaños del árbol de accesibilidad (círculos de 17 pt, botones de 32 pt), y el tiempo de abrir
  Registros (ver «Perfiles y eficiencia»).
- **Leído en el código:** cada cita con fichero y línea.
- **Hipótesis:** los siete perfiles (simulados, no entrevistas) y las notas de rendimiento sin medir.
- Lo decidido en la auditoría 2.2 (lote 8, L8-1 a L8-17) está implementado y no se repropone; las alternativas que lo
  reabren lo dicen (F2 → L8-16, T1 → L8-14, E3 → L8-12, C3 → L8-10).

## Archivos

`index.html` · `01-estado-actual.html` · `02-revision.html` · `11-buscar.html` … `16-calendario.html` · `estilo.css` ·
`capturas/` · `revision-registros.pdf` · `fuente/` (generador: `python3 build.py`; `--todo X.html` para el PDF).
