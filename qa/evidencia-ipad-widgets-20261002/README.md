# iPad · widgets grandes y extragrande (2026-10-02)

Ticket: `ipad-large-and-extra-large-widgets`. Datos: seed `realista` (`-uitest-seed realista`, segundo arranque sin reset para que la app reescriba el snapshot del App Group).

| Fichero | Qué enseña |
|---|---|
| `pro13-claro-galeria-*` | Galería del iPad Pro 13" en claro: Últimos registros, Próximos pagos y Presupuestos en grande; Resumen del mes en extragrande |
| `pro13-claro-inicio` / `pro13-oscuro-inicio` | Pantalla de inicio del Pro 13" con los cuatro widgets nuevos, claro y oscuro |
| `mini-oscuro-galeria-*` | Los mismos cuatro en la galería del iPad mini, en oscuro |
| `mini-claro-inicio` / `mini-oscuro-inicio` | Inicio del iPad mini con los cuatro, claro y oscuro |
| `promax-*-inicio-existentes` | Regresión en iPhone Pro Max: Balance mediano y Últimos registros mediano (widget tocado) siguen leyendo el snapshot y el mediano conserva sus 3 filas |

Lo que NO hay: galería del Pro 13" en oscuro ni del mini en claro (el modo se ve en la pantalla de inicio de los dos), y comparación al píxel antes/después en iPhone — no había build previa instalada; la red del «no apaga widgets» es `WidgetDTOParityTests`.

Sims: `YalaLane-Adapt-iPad-Pro-13` (8774BC90), `YalaLane-Adapt-iPad-mini` (D373DF84), `YalaLane-Adapt-iPhone-ProMax` (D2A5E333), iOS 27.0.
