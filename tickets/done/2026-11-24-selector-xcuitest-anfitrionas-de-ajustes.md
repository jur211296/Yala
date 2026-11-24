---
id: 2026-11-24-selector-xcuitest-anfitrionas-de-ajustes
status: done
priority: medium
area: "qa, gate"
created: 2026-11-24
updated: 2026-11-24
source: "cierres de Avisos del banco y Correos del banco (23-nov): el gate proponía decenas de clases de Ajustes ajenas al cambio"
---

# El selector de XCUITest ya no propone todo Ajustes por una subpantalla

## Qué pasaba

`qa/scripts/interfaz-de-lo-tocado.py` sigue a las vistas «anfitrionas» de lo tocado (capa 6). `ProfileView` monta las
~40 pantallas de Ajustes en un `switch` de destinos, así que tocar cualquiera traía TODOS los identificadores de
`ProfileView` y, con ellos, cada clase que entra a Ajustes por otra fila.

## Qué cambió

- Si el anfitrión monta lo tocado en una rama `case .x:`, solo cuentan los identificadores de la fila que abre `.x`
  (los que van detrás de `destination: .x`). Un uso suelto en ese anfitrión (la puerta que decide si la fila se ve)
  aporta solo su línea y las dos siguientes.
- Un anfitrión sin ramas sigue aportando el fichero entero, y tocar `ProfileView` mismo sigue trayendo a todas las
  clases que usan sus identificadores (capa 4). Si lo acotado no deja ningún identificador, se vuelve al fichero entero.

## Antes y después (cambio real: `BankEmailForwardingView.swift`)

- Antes: 88 clases (15 dentro del techo de 30 min y 73 fuera), casi todas por `ProfileView.swift`.
- Después: 9 clases, ~22 min: la guía de correos, las dos de Avisos del banco, la bienvenida que enseña la guía y las
  del glob ancho del índice.

## Pruebas

- `qa/scripts/interfaz-de-lo-tocado-test.sh`: casos nuevos de subpantalla, anfitrión tocado, nada de Ajustes y
  anfitrión sin ramas (28/28). Sin el acotado, el de subpantalla cae (mutante medido).
