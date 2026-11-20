---
id: 2026-11-19-panel-progresivo-primeros-pasos
status: done
priority: high
area: "panel, primeros-pasos, guias"
created: 2026-11-19
updated: 2026-11-20
card: tablero-panel-progresivo-en-primeros-pasos-s
source: "Jürgen, 19-nov 21:45 (acuerdo ya tomado), «Ingresos y gastos» y «Solo gastos»"
---

# Panel progresivo en Primeros pasos: solo aparece lo que ya se completó, sin guía ni coach tips

Al entrar, solo los Primeros pasos. Tras la primera cuenta, esa cuenta en «Tus finanzas». Tras registrar, «Últimos
registros». Tras presupuesto y pago, sus widgets si dijo que sí. Durante los Primeros pasos, ninguna guía ni coach tip.

## Lo que se colaba (medido en el simulador sobre la base, 2026-11-20)

- Llegada: guía «Este es tu resumen», oferta «Lleva tus finanzas al siguiente nivel» (Pro), «Tu salud financiera»,
  Tendencias, Planificación vacía y «Últimos registros» vacío.
- Tras la cuenta: lo mismo, más la cuenta.
- En el tutorial del paso 2: la guía «Registra un gasto o ingreso» encima de la guía propia del tutorial.
- Tras registrar y tras el presupuesto: la oferta Pro.
- En Estadísticas (paso 6): la guía «Yala analiza por ti».
- En Ajustes: el tour «Tus cuentas · 1 de 3».

## Resolución (2026-11-20)

- `PrimerosPasosPanelGate` (en `SetupDeckLogic.swift`) decide qué secciones pinta el Panel con el mazo a medias y lo
  aplican las dos lecturas de secciones ocultas del Panel y `PrimerosPasosPanelGateObserver`. Sin barra de filtros ni
  tarjeta de tipo de cambio. «Solo gastos»: la cuenta aparece con el paso 2 (el 1 lo hizo Yala).
- El primer «Sí, mostrarlo en el Panel» con el mazo a medias abre Planificación con SOLO ese widget.
- Avisos: con el mazo a medias solo siguen el de la nube y el de versión nueva.
- Guías de cada pantalla (las que tienen X), tour Pro y de tipo de cambio del Panel, tour de Ajustes, guía de «días
  después» y consejos de TipKit: callados con el mazo a medias. No se dan por vistos: salen al terminar.
- Se quedan las guías que son parte de un paso (Bandeja al cerrar el 2, Más en el 3, 4 y 6, Grupos en el 5, la guía del
  formulario en el 2).
- Tests: `YalaTests/PanelProgresivo/`.

## Fuera

- La oferta Pro vuelve a la vista al completar los siete pasos: es el momento que la ficha Y23-18 reserva para la
  oferta.
