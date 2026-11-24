---
id: 2026-11-23-estadisticas-resumen-propuesta-rediseno
status: done
priority: medium
area: "statistics, insights, diseño"
created: 2026-11-23
updated: 2026-11-23
source: "Jürgen, pruebas de Yala 2.3 en iPhone (23-nov)"
---

# Propuesta visual para rehacer Estadísticas → Resumen

Jürgen vio en la 2.3 que «Tu salud financiera» ocupa demasiado alto para cuatro números, que «Categoría principal» y la
caja ancha de «Promedio diario» aportan poco, que «Gastos hormiga» está desordenado y que el Resumen no lleva a ninguna
otra vista ni conversa con lo que ya vio en el Panel.

## Hecho cuando

Hay un artifact visual con dos o tres propuestas comparables contra lo de hoy, en marco de iPhone, oscuro y claro, con
tabla de recomendación, y su copia en `docs/propuestas/estadisticas-resumen-2-3/`.

## Resolución (2026-11-23)

Artifact público: https://claude.ai/artifact/VHMmwfczWRgT4pqvf67pjY · copia en `docs/propuestas/estadisticas-resumen-2-3/`.

- **A · Ordenar**: mismas piezas, compactas.
- **B · Decidir** (recomendada): franja de salud, «Para decidir hoy», hormiga protagonista, fila «Ir a».
- **C · Mosaico**: cuatro anillos y tarjetas con salida.

La maqueta de «Hoy» sale de `InsightsTabView` de la 2.3. Lo que pide cálculo nuevo va marcado en la página: ritmo del mes
de gastos hormiga (hoy el «≈ al mes» solo sale en períodos de más de 31 días), lo que queda por día de un presupuesto,
el orden y silencio de las acciones, y un filtro de Registros por comercio. «Comparativa» vive en Informes, no en
Estadísticas, así que no está entre los accesos.

## Siguiente paso

Jürgen elige en el bloque «Tu decisión» del artifact (se guarda en su base, colección `decisiones`). Con esa elección
se abre el ticket de construcción; nada de código de la app se tocó aquí.
