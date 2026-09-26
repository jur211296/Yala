---
id: ipad-large-and-extra-large-widgets
status: backlog
priority: low
area: "widgets, ipad"
created: 2026-09-26
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.5 y §8, fase 5), 2026-09-26"
---

# iPad · fase 5: widgets grandes y uno extragrande

**Tamaño S–M. Independiente de las demás fases.**

## Lo medido hoy

Solo tres widgets admiten `.systemLarge`: los dos donuts (`CategoriesPieWidget`, `SubcategoriesPieWidget`)
y Flujo de caja. **Ninguno** admite `.systemExtraLarge`, que es solo de iPad.

## Qué cambia para el usuario

- `.systemLarge` para Presupuestos, Últimos registros y Pagos planificados.
- Un `.systemExtraLarge` «Resumen del mes»: saldo, gasto por categoría y presupuestos en una pieza.

Ojo: un campo nuevo en el DTO del App Group apaga los widgets si no se añade a las dos copias (app y
widgets).

## Relacionados

- [[ipad-native-app]]. [[after-session-redesign-review-widgets-siri-applepay-and-web-copy]] — revisar
  los widgets en Cola B deja el DTO preparado.
