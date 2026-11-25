---
id: 2026-11-25-recurrente-desde-registro-uitest-rojo-de-madrugada
status: backlog
owner: frank
priority: medium
area: pruebas, planificación
created: 2026-11-25
updated: 2026-11-25
source: hallazgo del gate del lote 4 de la Bandeja sin duplicados (casar con planificados)
---
# Dos casos de «Hacer recurrente» caen en XCUITest a las 02:00 de Lima, también en 2.3 sin cambios

Medido el 2026-11-25 entre las 01:45 y las 02:20 (Lima), iPhone 17 Pro, iOS 27.2, scheme `Yala Dev`:

- `RecurrenteDesdeRegistroUITests.test_detail_makeRecurring_prefillsTheEditor_andTheRecordBecomesItsFirstPayment`:
  «El detalle no ofrece «Recurrente» al pie».
- `RecurrenteDesdeRegistroUITests.test_rowMenu_offersMakeRecurring_andOpensTheEditor`: «El menú del registro no ofrece
  «Hacer recurrente»».

Caen igual sobre la punta del lote 3 (`origin/encargo/2026-11-24-bandeja-fila-con-fuentes`, hoy en 2.3), así que no son
del lote 4. Los otros tres casos de la clase pasan. Hipótesis sin medir: dependen de la hora (la semilla `minimal` fecha
algo con el reloj y de madrugada el registro que el caso abre no es el que ofrece «Recurrente»), la misma familia que
`BandejaFilaConFuentesUITests`, que se arregló en el lote 4 esperando el filtro en vez de una fila.

Qué hacer: correr la clase de día y de madrugada (o con `TEST_RUNNER_TZ` a una zona donde sean las 02:00) y leer el
vídeo del `.xcresult` del rojo; arreglar el caso para que no dependa de la hora.
