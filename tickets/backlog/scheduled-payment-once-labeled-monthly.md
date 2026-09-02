---
id: scheduled-payment-once-labeled-monthly
status: backlog
priority: low
area: planning
created: 2026-09-02
updated: 2026-09-02
---

# Un pago planificado de «una sola vez» se muestra como «Mensual» en la lista

## El síntoma, en lenguaje de usuario

Creo un pago planificado y elijo **«Una sola vez»** en el segmentado de Recurrencia. En la lista de
Pagos planificados, ese pago aparece rotulado **«Mensual»**. El pago no se repite —el comportamiento
es correcto— pero la etiqueta dice lo contrario de lo que elegí.

## Lo MEDIDO el 2026-09-02 (árbol `2.1`)

- `Yala/App/Views/Planning/ScheduledPaymentRowView.swift:136-147` (`recurrenceBadge`) pinta
  `summary.payment.recurrenceType` y **nunca consulta `summary.payment.isRecurring`**.
- `RecurrenceType` (`Yala/App/Models/ScheduledPaymentModels.swift:13`) tiene solo
  `daily` / `weekly` / `monthly` / `yearly`. **No hay caso `once`.**
- ⇒ «Una sola vez» se modela EXCLUSIVAMENTE con `isRecurring: false`, y `recurrenceType` se queda con
  su valor por defecto (`"monthly"`), inerte pero visible.

El badge, por tanto, no puede estar en lo cierto para este caso: le falta el dato que lo distingue.

## Cómo verlo

```
-uitest -uitest-reset -uitest-seed grupos -uitest-skip-onboarding -uitest-scheduled-due-today
```

Planificación → Pagos planificados. La fila **«Recibo vence hoy»** —sembrada con
`isRecurring: false`— muestra el badge «Mensual».

(Ese seam se añadió en `3ba69eab` por otro motivo: alcanzar el escenario de un pago que vence hoy.
El rótulo se vio de paso al verificarlo.)

## Alcance del fix

Que la etiqueta diga «Una sola vez» cuando `isRecurring == false`.

**Antes de crear una clave nueva de localización, comprobar si ya existe:** el segmentado del editor
ya rotula esa opción, así que la cadena está en los 7 idiomas. Buscar cerca del identifier
`scheduled_recurrence_picker` en `ScheduledPaymentEditorView.swift` y reutilizarla.

**Buscar TODAS las instancias del mismo patrón** antes de darlo por hecho: puede haber otras
superficies que pinten `recurrenceType` sin mirar `isRecurring` — el widget, el detalle del pago, las
notificaciones y el resumen del calendario son los candidatos.

## Lo que NO es

No toca cálculo: ni las fechas de vencimiento, ni la generación de ocurrencias, ni las
notificaciones. Es presentación.

## Criterio de hecho

- [ ] La fila de un pago con `isRecurring == false` rotula «Una sola vez», reutilizando la cadena
      existente del editor (sin clave nueva si ya la hay).
- [ ] Barrido de las demás superficies que leen `recurrenceType`.
- [ ] Unit test sobre el helper de la etiqueta con las dos polaridades de `isRecurring`.
