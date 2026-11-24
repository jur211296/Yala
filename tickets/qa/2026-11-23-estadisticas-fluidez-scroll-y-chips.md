---
id: 2026-11-23-estadisticas-fluidez-scroll-y-chips
status: qa
priority: high
area: "statistics"
created: 2026-11-23
updated: 2026-11-24
source: "Jürgen, 23-nov-2026 (pruebas de Yala 2.3 en el iPhone): en Estadísticas, al hacer bastante scroll en Resumen, Tendencias y Distribución, o al cambiar entre esos chips, la app se atora y no responde de inmediato"
---

# Estadísticas se atora al cambiar entre Resumen, Tendencias y Distribución

## Causa medida (24-nov, simulador iPhone 17 Pro, Debug, diez años, «Todo el tiempo»)

`sample` del hilo principal alternando los tres chips ocho veces: ~1,6 s ocupado, y ~1,1 s (70 %) era recalcular lo que
ya estaba calculado. `StagedTabPages` desmonta la página que se va (a propósito: el título grande), y la que vuelve nacía
sin su `@State`: las tarjetas de Tendencias (~240 ms por entrada; 1,4 s en el iPhone 14 según G1 de la decisión 28), el
Sankey de Distribución (~175 ms) y «Tu dinero hoy» de cada hero (~27 ms por montaje, dos pasadas por todo el histórico).
Ese cálculo caía justo después de cambiar de chip: el primer scroll se quedaba trabado mientras duraba.

El scroll largo en sí no mostró trabajo de Yala por fotograma (17 muestras en 4,9 s; hilo principal ocupado un 15-20 %
del tiempo, igual antes y después).

## Resolución

- Tendencias y Distribución recuerdan lo último que calcularon con la firma de lo que leyeron
  (`StatisticsPageMemory`, en el `StatisticsViewModel` del contenedor). Volver con la misma firma lo enseña sin
  calcular; con otra, calcula como siempre. El Sankey guarda con qué entradas se calculó y no se repite.
- Los heros de las cuatro páginas comparten «Tu dinero hoy» por contenedor (`StatsMoneyTodayMemory`).
- Medido después, mismo guion: ~1,6 s → ~0,33 s de hilo principal en los ocho cambios (de ~200 a ~40 ms por cambio). Ni
  el cálculo de Tendencias, ni el Sankey ni «Tu dinero hoy» aparecen ya en la muestra.
- Tests: `YalaTests/EstadisticasFluidez/` (memoria y firmas; cableado: cada `onChange` que recalcula tiene su campo en
  la firma, la página consulta la memoria al aparecer y restaura todo lo guardado). Cuatro mutantes caen.

## Guion de QA en el iPhone 14 (Yala Dev, datos de Jürgen o semilla `pesado`)

1. Abre Estadísticas › Resumen y espera a que salgan las cifras.
2. Toca Tendencias, luego Distribución, luego Resumen, y repite tres veces seguidas sin esperar.
   Esperado: la primera vez Tendencias y Distribución pueden enseñar el esqueleto un momento; las siguientes, las
   tarjetas salen en el acto y el scroll responde enseguida.
3. En Tendencias, baja hasta el final y vuelve arriba rápido, dos veces. Esperado: sin tirones.
4. Cambia el período (p. ej. a «Mes pasado») estando en Resumen y pasa a Tendencias y a Distribución.
   Esperado: las cifras son las del período nuevo (no las de antes).
5. Pon un filtro de cuenta desde Filtros, pasa a Distribución y a Tendencias. Esperado: cifras filtradas.
6. Crea un registro desde «Nuevo registro» y vuelve a Tendencias. Esperado: «Entradas y salidas» lo incluye.

## Pendiente

- Medir en el iPhone 14 (no estaba conectado la noche del arreglo): si el scroll largo sigue trabándose con la página
  ya calculada, la causa es otra (render del cristal o de las gráficas, no el hilo principal) y va en card aparte.
