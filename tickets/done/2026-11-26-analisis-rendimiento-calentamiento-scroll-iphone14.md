---
id: 2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14
status: done
priority: high
area: "performance, panel, statistics, records, spotlight, widgets"
created: 2026-11-26
updated: 2026-11-26
source: "pedido de Jürgen del 26-nov-2026, 08:39 Lima (encargo «Análisis profundo de calentamiento, batería y scroll en iPhone 14»)"
---

# Calentamiento, batería y scroll al volver a Yala: diagnóstico medido en el iPhone 14

Jürgen: al cambiar de app (por ejemplo, al banco) y volver a Yala varias veces, el teléfono se calienta; al volver y
escrolear rápido, sigue sintiéndose lento. Sesión de diagnóstico y plan, sin cambios de código.

## Hecho cuando

- Medido en el iPhone 14 real (no en el simulador): CPU, estado térmico, tirones, memoria y energía, ciclo por ciclo al
  irse y volver de otras apps, y scroll rápido en Panel, Registros, Estadísticas, Pagos planificados, Grupos y Bandeja.
- Causas raíz con fichero y función, y la evidencia de la traza de cada una.
- Lotes de optimización propuestos, con mejora esperada y cómo se mide después en el mismo iPhone.

## Resolución (2026-11-26)

Informe completo: `docs/qa/rendimiento-iphone14-2026-11-26/README.md` (método, base usada, 11 pasadas con hora de Lima,
extractos en `datos/`, guiones en `scripts/`). Lo medido, en corto:

1. **Cada vuelta a primer plano recalcula las pantallas montadas sin mirar si algo cambió**
   (`PanelView.swift:522-524` y el mismo molde en Estadísticas, Registros, Grupos, detalle de grupo e Informes). Con
   16.004 movimientos, el hilo principal queda al 100 % entre 16 y 25 s en cada vuelta, y el scroll se congela de 12 a
   20 s.
2. **El recálculo del Panel es síncrono y cuesta 7-16 s** (`PanelViewModel.performCalculation`): tendencia, salud
   financiera, 24 presupuestos que recorren cada uno los 16 mil movimientos y lecturas de SwiftData.
3. **El pulso de la gráfica de tendencia anima sin fin** (`TrendChartView.swift:394`, `:461-467`): 35-38 % de un núcleo
   con la app quieta en cualquier pantalla; 0,3 % sin él.
4. **iOS mató a Yala dos veces en segundo plano** (`0x8BADF00D`, vigilante de 10 s) con el hilo principal dentro del
   reindexado de Spotlight y del recálculo del Panel, y registró 9 avisos de abuso de CPU (`cpu_resource`) entre el 24 y
   el 26-nov.
5. El costo no crece con los ciclos (no hay fuga de tareas); la memoria sí sube ~25 MiB por vuelta.

Con los dos cambios simulados por interruptores temporales (sin pulso y sin recarga al volver), en el mismo iPhone:
vuelta de ~33 s de CPU en 36 s a ~1,5 s en 20 s; reposo de 38 % a 0,3 %; impacto de energía al volver de 25,2 a 5,9.

Propuestos seis lotes, en orden: 1) volver no recalcula lo que no cambió, 2) sin animaciones infinitas fuera de la
vista, 3) no morir en segundo plano, 4) el recálculo del Panel deja de bloquear, 5) render del scroll, 6) memoria por
vuelta. No se crearon cards: la decisión de encolarlos es de Jürgen.
