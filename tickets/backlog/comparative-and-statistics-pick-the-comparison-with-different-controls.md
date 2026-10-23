---
id: comparative-and-statistics-pick-the-comparison-with-different-controls
status: backlog
priority: low
area: reports
created: 2026-10-21
updated: 2026-10-23
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
