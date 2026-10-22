---
id: autonomous-mode-still-asks-to-continue-after-listing-more-than-three-files
status: done
priority: high
area: "tooling, proceso"
created: 2026-09-22
updated: 2026-09-22
source: "encargo de Jürgen tras el PR #212 (2026-09-22)"
---

# En MODO AUTÓNOMO la sesión sigue preguntando «¿Sigo?» y dejando el merge a Jürgen

## El problema

En la cola autónoma (bypass + «MODO AUTÓNOMO HASTA TERMINAR») la sesión se paraba en dos sitios
que el encargo ya había resuelto:

- **Tras listar el plan**, si tocaba más de 3 ficheros: «¿Sigo?».
- **Tras implementar**, con el PR en verde: «mergea tú», o esperando el device-QA de iPhone.

Pasó entero en `snapshot-upload-has-no-ceiling-and-no-way-out` (PR #212).

La causa eran tres reglas escritas para la sesión interactiva y sin excepción para la autónoma:

| Dónde | Regla |
|---|---|
| `CLAUDE.md`, General Rules | «Esperar aprobación si son más de 3 archivos» |
| `CLAUDE.md`, Control de Ejecución · `frank.md`, Control de ejecución | «Tras implementar… detenerse. No encadenar tests, QA ni commits» |
| `CLAUDE.md`, Dónde se commitea · `frank.md`, Cómo entregas | «Un PR abierto lo mergea él salvo que pida otra cosa» |

Y la memoria `feedback_autonomo_hasta_el_final.md` decía «de día pregunta aunque diga autónomo» sin
acotar a qué: se podía leer como que el plan o el merge también se preguntan.

## Qué se cambió

- `CLAUDE.md` § «Control de Ejecución» se bifurca: **interactiva** (lista, >3 espera OK, para tras
  implementar) y **MODO AUTÓNOMO** (qué cuenta como tal, y el tren entero hasta `/cerrar-total` sin
  «¿Sigo?», sin dejar el merge, con el device-QA fuera del camino del merge). El gate rojo sigue
  parando en los dos modos.
- La regla de >3 ficheros y la del merge remiten a esa bifurcación.
- `frank.md` dice lo mismo en corto y apunta al `CLAUDE.md` para la definición.
- La memoria aclara que la norma de día es para producto y acceso, no para «¿sigo?» ni «¿mergeo?».

## Lo que NO cambió

- La norma diurna: de 6:00 a 21:00 (Lima) una decisión real de producto o de acceso se pregunta con
  `AskUserQuestion`.
- El release (subir un build) sigue siendo de Jürgen. Mergear no es release.
