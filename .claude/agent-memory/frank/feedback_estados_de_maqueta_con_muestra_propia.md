---
name: estados-de-maqueta-con-muestra-propia
description: Capturar los N estados de una maqueta cuando la semilla queda fuera del `toca`: muestra DEBUG propia en la carpeta de la vista, por argumento de lanzamiento.
metadata:
  type: feedback
---

Para enseñar los seis estados de la maqueta de Salud financiera (20-nov-2026) hacía falta datos que ninguna semilla
daba (tarjeta endeudada, pagos que no alcanzan, resumen de IA guardado), y `Yala/Seed` no estaba en el `toca`. Lo que
funcionó: un `…Muestra.swift` `#if DEBUG` dentro de la carpeta de la vista, que con `-uitest -uitest-<pantalla>-estado X`
sustituye nota y datos del cargador (`cargador.usar(muestra)`), y el conductor de capturas recorre los estados con
`TEST_RUNNER_CAPTURA_ESTADOS`. Sirve también para XCUITest deterministas del caso difícil.

**Why:** tocar la semilla habría salido del `toca` (choque con la otra sesión de Yala) y una semilla real no fija un
resumen de IA guardado.

**How to apply:** encargo con maquetas de varios estados y semilla ajena. Y el presupuesto de 30 min de interfaz se va
en capturas: 6 estados × 2 temas ≈ 8 min; acota con `CAPTURA_ESTADOS` y `CAPTURA_PANTALLAS` en las repeticiones.
Relacionado: [[capturas-con-conductor-xcuitest]].
