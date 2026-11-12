---
id: comparative-and-statistics-pick-the-comparison-with-different-controls
status: done
priority: low
area: reports
created: 2026-10-21
updated: 2026-10-28
source: lote decidido 2.2 · 10 (L18-3), al implementar
---

# La Comparativa elige «con qué comparar» con dos chips; Estadísticas, con una frase que abre un menú

**Clase:** decisión de producto pendiente (coherencia entre pantallas). No es un bug.

## Qué pasa

- **Reportes → Comparativa** (L18-3, opción D, variante 3): arriba de la tabla dice «Octubre comparado con el 1–21 de
  setiembre» y debajo dos chips, «Con el mes anterior» y «Con octubre de 2025».
- **Estadísticas** (L11-4, mergeado antes): la misma elección se hace tocando la frase, que abre un menú.

Las dos decisiones son de Jürgen y cada una se aplicó al pie de la letra. El resultado es que la misma pregunta se
contesta con dos controles distintos según la pantalla.

Capturas: `~/Claude/entregas/Yala--lote-decidido-2-2-10-flujo-de-caja-y-reportes/capturas/despues-03-comparativa-este-mes.png`.

## Qué decidir

Si se unifican (y con cuál de los dos), o si se quedan así.

## Decisión de Jürgen (2026-10-23)

**Se unifican con los chips de la Comparativa.** Estadísticas cambia la frase con menú por los dos chips
(«Con el mes anterior» / «Con <mes> de <año pasado>»). El trabajo está en la card
`tablero-estadisticas-elige-con-que-comparar-con-gvvl` (lista para lanzar).

## Hecho (2026-10-28)

Estadísticas (Resumen › Tus cifras y Distribución › Gráficas) elige con los mismos dos chips que la Comparativa:
«Con el mes anterior» / «Con octubre de 2025». La frase «Comparado con el 1–28 de setiembre» queda encima como
título y cambia al elegir. Los dos sitios usan el mismo componente (`ComparisonModeChips`) y el mismo estado, así que
lo elegido en una pantalla sigue elegido en la otra. Se retiraron las opciones del menú viejo (siete textos en los 16
idiomas). Red: `UXAudit22Lote11y16UITests#test_statistics_picksTheComparisonWithTheTwoChips`.
