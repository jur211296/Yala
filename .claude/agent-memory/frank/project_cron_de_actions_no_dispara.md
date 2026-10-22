---
name: cron-de-actions-no-dispara
description: El `schedule` de Actions estuvo muerto en Yala y REVIVIÓ el 2026-09-08, con 4h35 de retraso. Lo que eso rompe — el margen del vigilante — y por qué un disparo no es todavía un reloj.
metadata:
  type: project
---

**Estuvo muerto y revivió el mismo día.** Esta ficha nació el 2026-09-08 por la mañana diciendo que
el `cron` de GitHub Actions no dispara en `jur211296/Yala`; **esa misma tarde disparó**. Las dos
mediciones eran correctas en su momento — la lección no es cuál valía, es que **esta clase de hecho
caduca en horas, no en semanas**.

## Lo que estaba medido (mañana del 8-sep)

Cero `event: schedule` en todo el repositorio, nunca. Una nocturna (`cron: '17 8 * * *'`) sin
disparar con casi 8 h de margen, y un canario `*/5` con **siete ventanas y cero runs**. La app pasó
de 24-31 corridas de UI al día a **cero automáticas** sin que nada lo dijera: cuando un `schedule`
no dispara no hay run, no hay rojo y no hay aviso.

## Lo que medí a las 13:14 UTC del mismo día

```
wf=QA · id=34228530861 · creado=2026-09-08T12:52:03Z · rama=2.1 · path=.github/workflows/qa.yml
```

`event=schedule` → **1**. Controles positivos en la misma tanda: `push` → 1103,
`workflow_dispatch` → 4, así que la consulta mide lo que dice medir.

**El dato que importa no es que disparara: es el retraso.** Ventana declarada 08:17 UTC, nacimiento
real **12:52 UTC** ⇒ **4 h 35 min**. GitHub no publica tope para eso.

## Lo que ese retraso rompe, y que no se veía

`nocturna-vigilante.yml` comprueba a las **11:43 UTC** que la nocturna nació, con un margen
declarado de 3 h 26 min «de sobra para el retraso bajo carga». **El retraso real de hoy fue mayor
que su margen**: habría mirado 1 h 09 min *antes* de que naciera y cantado un rojo falso, en el
único canal que vigila que la cobertura de UI sigue viva.

No ha explotado porque **el vigilante nunca ha disparado por `schedule`** (0 runs, medido): vive del
`push`. Se detona el día que su cron despierte — o sea, ahora. Ticket:
`vigilante-margen-menor-que-el-retraso-real-del-cron`.

⇒ **Un margen fijo contra un retraso sin tope es una apuesta.** Lo que no depende del retraso es
preguntar por una **ventana** («¿nació algún run en las últimas 24 h?»), no por un instante.

## How to apply

- **Antes de apoyarte en cualquier versión de esta ficha, re-mide.** Cuesta un comando:
  ```
  gh api 'repos/jur211296/Yala/actions/runs?event=schedule&per_page=100' --jq .total_count
  ```
  Re-comprobada por última vez: **2026-09-08, 13:14 UTC** (valor: 1).
- **Un disparo no es un reloj.** Para decidir si sirve hace falta muestra: ≥10 de 14 días ⇒ sirve;
  ≤3 ⇒ fue un accidente. La decisión de qué hacer con eso es de Jürgen y está preparada en
  `cobertura-ui-diaria-cuelga-del-push`, con fecha de re-mirada **2026-09-22**.
- **Sigue en pie el punto ciego del `push`:** 8 de los últimos 30 días sin commits en `2.1`, rachas
  de hasta 3 (re-medido el 8-sep, idéntico).
- **Dos cosas que no hay que volver a hacer,** las dos ya cometidas aquí:
  1. **Leer un `workflow_dispatch` en verde como evidencia de que el reloj funciona.** Corre el mismo
     contenido, así que no distingue nada.
  2. **Preguntar «¿corrió el workflow?» sin filtrar por evento.** Responde que sí todos los días.

La forma de medirlo, con sus dos trampas de API, está en `docs/aprendizajes-tecnicos.md` («Una
corrida programada que no ocurre no deja rastro»).

Relacionado: [[mis-mediciones-fallan-por-el-filtro]] · [[el-ci-se-verifica-en-local]] ·
[[hipotesis-lista-negra-recomprobadas]] — esta ficha es ahora el ejemplo más corto de por qué esas
hipótesis llevan fecha.
