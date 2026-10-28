---
id: budget-threshold-live-activity
status: backlog
priority: medium
area: "live-activities, notificaciones"
created: 2026-10-28
updated: 2026-10-28
source: card `tablero-live-activities-presencia-en-pantalla-de-hi45`; informe `docs/live-activities-factibilidad.md`
---

# Al llegar al umbral de un presupuesto, su barra en la pantalla de bloqueo

## Qué cambia para el usuario

Cuando un presupuesto cruza su umbral (por ejemplo, el 75 %), aparece una tarjeta con su nombre y una barra que se llena
hasta el porcentaje. A los 5 minutos queda la notificación de siempre. Vale para presupuestos personales; los de grupo,
se decide en el ticket.

## Alcance

- Usa la base de `live-activity-base-and-apple-pay-presence`. Engancha en `BudgetAlertService`, que ya decide cuándo
  avisar (y deduplica): la tarjeta sustituye al envío, no a la decisión.
- La comprobación corre con Yala delante, así que la tarjeta nace sin trucos; pero la isla no la enseña hasta salir de
  la app. Decidir en el ticket si dentro de la app se ve además la notificación.

## Hecho cuando

- Guardar un registro que cruza el umbral → tarjeta con nombre, porcentaje y barra animada al salir de Yala.
- Un umbral ya avisado no repite tarjeta (misma deduplicación que hoy).
- A los 5 minutos queda la notificación; Live Activities apagadas → notificación directa.
- Tests del enganche con el seam de envío y guion de QA.

Versión: 2.4. Factibilidad y límites de la plataforma: `docs/live-activities-factibilidad.md`.
