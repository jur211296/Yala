---
name: el-historial-del-simulador-cuelga-el-soltar
description: XCUITest que sueltan la cuenta de grupos se cuelgan 120 s si el almacén de pruebas del simulador acumuló historial; y el runner que no arranca con «AX loaded» tras la batería unitaria. Las dos se curan con el simulador.
metadata:
  type: feedback
---

Si los XCUITest que confirman «soltar la cuenta de grupos» caen a los ~120 s con «main thread busy for 30.0s» justo
tras tocar la salida, **muestrea antes de culpar al cambio** (`sample <pid de Yala> 4`): el 2026-11-11 la pila era
`GroupsSyncClient.fetchHistory` leyendo el historial ENTERO de SwiftData en el hilo principal, y `YalaModel-UITest.store`
pesaba 142 MB con la semilla `minimal` (el `-uitest-reset` borra filas, no el historial). Los mismos casos pasaban una
hora antes. `simctl erase` de mi simulador → 17/17 verde.

Y si `xcodebuild test` sale 65 con cero casos y «Timed out waiting for AX loaded notification», es el simulador, no el
test: me pasó dos veces justo después de correr `YalaTests` entero en el mismo simulador. Apagar y arrancar lo curó.

**Why:** las dos parecen regresión del cambio (fallan los tests del área tocada) y no lo son; sin muestrear, habría
revertido una hoja que estaba bien.

**How to apply:** antes del paso 3 del gate en un simulador que ya corrió muchas tandas, `erase`; ante un 65 sin casos,
reiniciar el simulador antes de repetir. Si Jürgen ve el cuelgue en un iPhone real con mucho historial, ese sí es un bug
(el soltar lee el historial en el hilo principal) y va a card. Relacionado: [[conducir-a-mano-contamina-los-unit]].
