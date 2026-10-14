---
id: panel-stayed-filtered-after-removing-the-account-chip
status: backlog
area: panel
priority: low
created: 2026-10-13
updated: 2026-10-13
source: auditoría UX 2.2, lote 3 (el Panel)
---

# Visto una vez: tras quitar el filtro de cuenta con la «x» del chip, el Panel siguió con las cifras filtradas

## Qué se vio (2026-10-13, simulador iPhone 17 Pro, iOS 27.0, Yala Dev)

Datos de prueba recién cargados desde Ajustes › Cargar datos de prueba, en la misma sesión. Pulsación
larga en «Mi dinero Soles» › Filtrar por esta cuenta, y luego la «x» del chip «Mi dinero Soles» en
«Filtros aplicados». El chip y el punto del botón de filtros desaparecieron, la hoja de Filtros decía
«(Todos)» en todo, y aun así el Panel siguió diciendo «Disponible S/ 0.00» y «Tienes S/ 1,800.00 en 3
cuentas», que son las cifras de la cuenta filtrada. Cerrar la hoja de Filtros no lo despertó;
relanzar la app sí. Captura: `3.4-quitar-filtro-no-recalcula.png` en
`~/Claude/entregas/Yala--auditoria-ux-2-2-lote-3-panel/capturas/`.

## No reproducido

Tres intentos después, con la app relanzada desde XcodeBuildMCP y el log de `performCalculation`
abierto: las tres veces el recálculo corrió (dos `performCalculation` por quitar el chip) y las cifras
volvieron al total. La diferencia con el primer caso: aquél venía de cargar los datos de prueba en la
misma sesión y de la guía «Tu saldo se mueve solo» recién cerrada.

## Hipótesis, sin medir

`PanelViewModel.scheduleRecalculation` sale en silencio con `guard isApplicationActive()`; si el chip se
quitó mientras la app no estaba `.active` (por ejemplo, con una presentación en tránsito), el cambio de
filtro se pierde y nada lo vuelve a pedir hasta otro cambio.

## Qué haría falta para cerrarlo

Reproducir con el seed cargado desde Ajustes en la misma sesión y el log abierto; si `performCalculation`
no aparece tras quitar el chip, mirar `isInBackground` / `isApplicationActive()` en ese instante.
