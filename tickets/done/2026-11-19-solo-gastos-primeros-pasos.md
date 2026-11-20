---
id: 2026-11-19-solo-gastos-primeros-pasos
status: done
priority: high
area: "onboarding, primeros-pasos, panel"
created: 2026-11-19
updated: 2026-11-20
card: tablero-solo-gastos-no-tiene-primeros-pasos-
source: "Jürgen, 19-nov 21:35, build 2.3 (5), cuenta nueva en iCloud privado"
---

# «Solo gastos» no tiene Primeros pasos: deberían ser los del onboarding normal, adaptados

Jürgen creó una cuenta de cero en iCloud privado, eligió «Solo gastos» y no salieron los Primeros pasos.

## Causa (medida en el simulador, 2026-11-20)

`PanelView.setupDeckSlot` cambiaba el mazo por un botón suelto «Anotar el primer gasto» (`SetupFirstExpenseAction`)
mientras durara la llegada tranquila en «Solo gastos». Venía de la ficha Y23-05. El mazo solo aparecía después del
primer gasto, y ya en el paso 3: el tutorial de «Aprender a registrar» no se ofrecía nunca.

## Hecho cuando

«Solo gastos» llega con el mazo de los siete pasos, adaptado donde el modo lo pide, y cambiar de modo no pierde lo hecho.

## Resolución (2026-11-20)

- Mismo mazo de siete y en el mismo orden. El paso 1 sale hecho porque Yala crea «Gastos Soles»; en «Ver los 7 pasos» su
  línea dice «Tus gastos van a «Gastos Soles», que Yala crea sola.». El mazo arranca en «Aprender a registrar · 2 de 7».
- No se quitó el paso 1: los flujos de cada paso (de otra sesión) dicen «2 de 7», «6 de 7» y «7 de 7».
- Los pasos 2 a 7 ya trabajan solo con gastos (presupuesto y pago filtran categorías de gasto).
- Cambiar de modo no toca lo hecho: el mazo es el mismo en los dos. Medido en el simulador pasando de «Solo gastos» a
  completo en el paso 5.
- Tests: `YalaTests/SoloGastosPrimerosPasos/`.
