---
id: 2026-11-19-ci-2-3-todo-verde
status: done
priority: high
area: "ci, qa"
created: 2026-11-19
updated: 2026-11-19
source: "encargo de Jürgen del 18-nov: revisar el CI de 2.3 y dejarlo en verde antes de TestFlight y el barrido"
---

# El CI de 2.3 en verde, con la UI probada de verdad

Antes de subir a TestFlight y del barrido de QA, el CI de 2.3 tiene que pasar entero y la UI tiene que correr de
verdad: sin tandas cortadas por su tope, sin cancelaciones y sin rojos que no sean de la app.

## Lo medido (runs de 2.3 del 17 y el 18-nov)

- **La UI no cabía.** Las nueve tandas iban de 80 a 110 min de paso y en cada run una o dos agotaban los 110 sin
  terminar: sus últimas suites no corrían. La suite pasó de 519 min (5-nov) a ~872.
- **La tanda 7 cancelada del 18-nov** fue el runner congelado a los 36 min, no el tope (infraestructura).
- **Casos sueltos de 19-29 min** con el runner congelado acababan «passed» y se comían la tanda.
- **El primer caso de cada tanda** pagaba el arranque en frío del runner de XCUITest (4-10 min, rescatado o rojo).
- **El job `tests`**, que frena el merge, iba a 74,9 min de máximo verde con tope 80.
- **Cuatro rojos 3/3 del 18-nov** (tres de la Bandeja y uno de recurrentes): el borrador de la semilla «Taxi aeropuerto»
  (−18,00 hoy−3) se marcaba como posible duplicado los días en que la semilla genera un transporte de −18 en esa fecha
  (importes enteros, misma cuenta). Inferido de los mensajes de fallo y del código; no se reprodujo el día exacto.

## Qué se hizo

- UI en 14 tandas (eran 9) con la tabla de tiempos regenerada: mediana de tres runs, cada caso topado a 600 s
  (`ci-ui-tiempos.sh` acepta varios runs).
- Tope por caso de 10 min en el paso de UI (`-default-test-execution-time-allowance 600`).
- Paso nuevo «Calentar el runner de XCUITest» (un caso corto del Panel que no cuenta) antes de cada tanda.
- Topes: job `tests` 80 → 110, build 40 → 50, pure-logic 45 → 55; build compartido 40 → 50 (job 60 → 75); job `ui`
  150 → 165.
- Semilla: «Taxi aeropuerto» a −18,40, con céntimos como «Fijos casa» (card 04ek).
- `AIConsentAlertUITests`: la espera de cierre del aviso, 5 → 15 s.
- Regla `ci-qa.md` al día.

Decisiones y su porqué: `encargos/lanzados/2026-11-19-ci-2-3-todo-verde.md`, Paso 0, y el cuerpo del PR.
