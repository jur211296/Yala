---
id: ipad-account-form-uitest-times-out-inside-a-long-run
status: backlog
priority: low
area: "qa, ipad"
created: 2026-11-11
updated: 2026-11-11
source: "gate del lote 2.3 · Panel día 1 y gráfica de saldo, 2026-11-11"
---

# El XCUITest del formulario de cuenta en el iPad se agota a veces dentro de una corrida larga

`ReadableWidthIPadUITests.test_accountForm_opensAtPageSize_withItsContentAtTheReadableWidth` (iPad Pro 13 simulado,
iOS 27.2) cayó 2 veces con «Failed to get matching snapshots: Timed out while evaluating UI query»: tras tocar
«Agregar cuenta» la app no llega a quedar ociosa («App event loop idle notification not received», 60 s) y la
consulta de `account_name_field` se agota. Las dos veces fue dentro de una corrida de varias suites seguidas. Aislado
pasó 3 de 3 con el mismo binario, y 1 de 1 con la base `origin/2.3`.

El camino del test (Ajustes › Cuentas › Agregar) no pinta nada de lo que cambió ese lote: «Tus finanzas» abre plegada
con la semilla `minimal`. Sin medir: qué tiene ocupado el hilo principal (un `sample` del proceso durante el cuelgue
no se llegó a tomar: la corrida que se iba a muestrear pasó).

Hecho cuando se sepa qué ocupa el hilo principal en ese instante, o el caso pase 10 de 10 dentro de la tanda del iPad.
