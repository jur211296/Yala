---
name: runner-ax-timeout-tras-suite-larga
description: XCUITest que muere con «Timed out waiting for AX loaded notification» tras correr YalaTests entero: reiniciar el simulador, no repetir a ciegas
metadata:
  type: feedback
---

Tras correr `YalaTests` entero (13.636 casos, ~6 min) en el mismo simulador, las dos corridas siguientes de XCUITest
murieron sin ejecutar un caso: `YalaUITests-Runner … failed to initialize for UI testing (Timed out waiting for AX loaded
notification)`, exit 65, `** TEST FAILED **`. Disco con 15 GB libres y centinela limpio: no era ni disco ni otra sesión.
`simctl shutdown` + `boot` + `bootstatus -b` + ~20 s de asiento, y la tercera pasó 14/14. Medido el 2026-11-12 en la Mini,
iOS 27.2, gate del lote de Registros 2.3.

**Why:** repetir igual gastó 1,5 min de presupuesto de UI por intento sin cambiar nada; el simulador se queda con la
accesibilidad colgada.

**How to apply:** si un XCUITest sale con esa línea y cero `Test Case`, no lo cuentes como rojo ni lo repitas tal cual:
reinicia el simulador una vez y vuelve a lanzar con `test-without-building`. Relacionado: [[el-carril-espera-a-cola-a]].

**Otra cara, 2026-11-15 (Max, barrido final 2.3):** con el simulador heredado de otra sesión ya arrancado, la primera
corrida de XCUITest cayó caso por caso con `Failed to get matching snapshots: Error getting main window
kAXErrorAPIDisabled` y `uitest_ready ausente — bootstrap no completó` (timeouts de 125 s). Costó 12 de los 30 min de
presupuesto. Tras `shutdown` + `boot` + `bootstatus -b`, 43/43 verdes con `test-without-building`. **Reinicia el simulador
ANTES de la primera corrida de XCUITest de una sesión**, no después del primer rojo.

**Tercera vez, 2026-11-18 (Mini, motor del mes del flujo de caja):** mismo síntoma por el mismo orden (gate paso 2 con
`YalaTests` entero y luego el paso 3). Con un choke-point tocado, **reinicia el simulador entre el paso 2 y el 3 de
antemano**: cuesta 40 s y ahorra una vuelta de 7 min.

**Cuarta cara, 2026-11-23 (Mini, éxito siempre al guardar):** a mitad de una tanda de 14 clases, desde un `typeText`
cada gesto empezó a esperar 60 s («App animations complete notification not received» / «Unable to monitor animations»)
y un caso cayó porque el aviso de 30 s caducó durante esas esperas. Los casos hermanos con el mismo camino habían pasado
en ~40 s. Cortar la corrida, `shutdown` + `boot` y repetir solo lo que faltaba: todo verde. **Una espera de 60 s por
gesto es el simulador, no el cambio: corta y reinicia en vez de dejar que se coma el presupuesto.**
