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
