---
id: 2026-11-16-verificacion-propuesta
status: done
priority: medium
area: "qa, ci, proceso"
created: 2026-11-16
updated: 2026-11-17
source: "encargo de Jürgen del 16-nov (20:56): comparar nuestra verificación con el artículo del equipo de Claude Code y traer una propuesta visual"
---

# Cómo verificamos, contra el artículo de verificación de Claude Code

**Entregable:** artifact público https://claude.ai/artifact/RTWfBUbDi4tbW1eKbEA81d con la tabla
práctica-contra-hoy, los datos de 2.3 de dos semanas y seis propuestas con selector Sí / No /
Después. Fuente e inventario con comandos: `docs/verificacion/`.

## Lo que se encontró

- Las pruebas de interfaz no corren en ningún PR: solo de noche y sin bloquear. 11 casos rotos
  llegaron a 2.3 en dos tandas; el PR que rompió los 4 del 16-nov corrió 6 clases en su gate y
  ninguna de las rotas.
- 65 rojos de unit pasaron al repetirlos (12 % de las corridas) y mergearon en verde; 60 son de
  las pruebas de la caché de `CurrencyConverter`.
- 13 de 572 commits dicen cómo se verificaron; 0 reverts; 1 de 11 arreglos nombra su origen.
- Las reglas suman 5.445 líneas sin poda; `testing.md` cita un fichero que no existe.

## Propuestas (esperan el voto de Jürgen en el artifact)

P1 rescates y cuarentena · P2 interfaz de lo tocado en cada PR · P3 `Verificado:` en el commit ·
P4 checklist con disparadores y un revisor · P5 revisión mensual de escapes y poda · P6 property
tests y diferenciales. Cada una nombra la sesión que la implementaría. Esta sesión no tocó código
ni CI.
