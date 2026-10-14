---
id: first-panel-says-available-zero-next-to-the-opening-balance
status: backlog
area: panel
priority: low
created: 2026-10-13
updated: 2026-10-13
source: auditoría UX 2.2, pasada UI del lote 1 (primera vez y onboarding)
---

# El primer Panel dice «Disponible S/ 0.00» justo encima de «Tienes S/ 1.800»

**Clase:** observación de UX para el lote 3 de la auditoría UX 2.2 (el Panel). Salió en la pasada UI del lote 1 y
no se revisó ahí porque no es de ese lote: no se sabe todavía si es un bug o el diseño.

## Qué se vio (medido en el simulador, 2026-10-13)

Alta nueva «Llevar el control» › «Todo junto en una sola cuenta» con saldo S/ 1.800 (calculado). Al llegar al
Panel, la cifra grande dice **«Disponible S/ 0.00»** y, dos bloques más abajo, «Tus finanzas: Tienes S/ 1.800 en 1
cuenta». Quien acaba de escribir su saldo ve un cero como cifra principal. Captura:
`despues-L1-12a-panel-sin-oferta.png` en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-1-pasada-ui/capturas/`.

## Qué decidir

Si «Disponible» del primer día debe contar el saldo inicial, o si el hero tiene que explicar qué mide cuando aún no
hay movimientos del mes. Lo revisa el lote 3 con las cinco lentes.

## Revisado en el lote 3 (2026-10-13)

Es diseño, no bug: «Disponible» es lo que entró menos lo que salió en el período, y el saldo inicial no es un
ingreso. Lo que falla es que la pantalla no lo dice. Va como mejora **L3-1** con opciones A/B/C y maquetas en
`~/Claude/propuestas/auditoria-ux-2.2/variantes-L3.html` (recomendada: rótulo «Balance de octubre» y una línea con la
cuenta; sin movimientos, «Aún no registras movimientos este mes · Tienes S/ 1.800 en tus cuentas»). Card de Jürgen:
`tablero-ux-2-2-l3-1-la-cifra-grande-dice-disponi-dg5z`. Este ticket se cierra cuando se implemente la opción elegida.
