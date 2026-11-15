---
id: 2026-11-14-pagos-recurrentes-s1
status: done
priority: medium
area: "scheduled-payments, planning"
created: 2026-11-14
updated: 2026-11-14
source: "definición «Atajo del banco y suscripciones» (docs/ux/atajo-banco-y-suscripciones/, PR 940); decisión de Jürgen del 14-nov: todas las recomendadas"
---

# Pagos que se repiten: detectar suscripciones en el historial y proponerlas en Planificación (S1)

Hasta hoy los pagos planificados se creaban a mano. Ahora Yala busca en los registros los cobros que se repiten
(Netflix, Spotify, la luz) y los propone arriba de Pagos planificados. Un toque abre la propuesta ya llena; se crea el
pago, se descarta («No es fijo») o se pospone hasta el próximo cobro («Ahora no»).

## Decisiones (las recomendadas de la definición)

- **S1 = P1**: tarjeta arriba de Pagos planificados mientras haya algo por responder.
- **S2**: 3 cobros mensuales (±4 días) o 4 semanales (±1 día); anuales fuera.
- **S3**: lo descartado se recuerda en cada dispositivo, sin esquema nuevo.
- **S4**: los cobros pasados no se tocan ni se enlazan.
- **S5**: cambios de precio y bajas quedan para el lote S2.

## La regla

Mismo comercio (marca del catálogo de logos, solo si el nombre es el servicio o lo que sigue son palabras de relleno;
si no, el nombre normalizado sin números), cada divisa aparte, monto dentro del 15 % del último (exacto para marcas),
último cobro hace menos de 45 días y sin un pago planificado parecido. Fuera: ingresos, devoluciones, transferencias y
ajustes, gastos y liquidaciones de grupo y lo que generó un pago planificado que todavía existe. Ventana: 200 días.

## Hecho cuando

- [x] Detector con tests: fijo, variable, corto, irregular, ya planificado, en dólares, cambio de hora, fin de mes.
- [x] Tarjeta en Planificación, hoja llena, «Crear pago planificado», «No es fijo», «Ahora no».
- [x] Interruptor y lista de descartados (pantalla propia; la fila en Ajustes queda como card).
- [x] De punta a punta en el iPhone 14 con la semilla `realista` sin los pagos de Netflix y Spotify.

## Resolución (2026-11-14)

Código en `Yala/App/Logic/PagosRecurrentes/` y `Yala/App/Views/Planning/PagosRecurrentes/`, montado en
`ScheduledPaymentsView.swift` (el fichero real: `PlannedPaymentsView.swift` no existe). Guarda con
`ScheduledPaymentEditorViewModel.savePayment`, el mismo guardado del editor. 36 tests en `YalaTests/PagosRecurrentes/`.
Una revisión independiente encontró nueve fallos antes del commit (día 31 recortado a 30 para siempre, próximo cobro
tras un cobro desplazado, «PRIME GYM» propuesto como Prime Video, devoluciones como cobros, aviso con fecha pasada,
permiso de notificaciones, cuenta del cobro fuera del menú, lectura con la función apagada, modelos borrados); todos
arreglados y con test donde la lógica es pura.
