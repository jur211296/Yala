---
updated: 2026-09-02
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-02 (Lima)

**Rama** `2.1` · **HEAD** `e7540621` — *test(inbox): pinnear la FECHA de la conversion a gasto de
grupo*. TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión
La cola de QA no estaba parada por falta de sesiones de QA: de sus 15 tickets, **ninguno se cerraba
entero en simulador**. Se escribieron los tres seams que faltaban (un borrador que nace con fecha
pasada, un pago planificado que vence hoy, y poder hacer fallar el borrado de «Empiezo de cero» a
voluntad) y con el primero **se cerró `inbox-convert-draft-to-group-expense`**: 12/12 ACs vistos en
pantalla, incluida la FECHA, que llevaba desde agosto solo «medida en el código». Cerrado además con
XCUITest y mutación verificada. **La app en producción no cambia**: todo vive bajo `#if DEBUG`
salvo un identifier de accesibilidad.

## Abiertos
- **`welcome-fresh-start-alert-leaves-blank-screen`** (backlog, **high**) — tocar «Es mi primera vez»
  y luego cancelar deja la app sin ningún control, sin salida salvo matarla. Preexistente, medido con
  tres lanzamientos. Onboarding de usuario nuevo con datos previos, **en producción**.
- **`scheduled-payment-once-labeled-monthly`** (backlog, low) — un pago «una sola vez» se rotula
  «Mensual»: el badge lee `recurrenceType` y nunca mira `isRecurring`. Cosmético.
- **`AUDIT-appstore-guidelines.md`** — 3 hallazgos de riesgo de rechazo (divulgación de OpenAI). De Lola.

## Release 2.1 (sin cambios)
2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Siguiente
De los 14 de `qa/`, **8 piden tu teléfono y 3 staging al 100** — no los drena un agente. Lo que
rinde: consolidar esos 11 en **un guion único de device-QA agrupado por montaje** (2 cuentas · 2
devices · flags), una tarde tuya en vez de once sesiones. Los 9 de `in-progress` siguen parados.

## Bloqueo
Ninguno.
