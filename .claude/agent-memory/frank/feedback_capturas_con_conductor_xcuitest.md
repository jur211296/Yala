---
name: capturas-con-conductor-xcuitest
description: Antes/después de varias pantallas: un XCUITest temporal que las fotografía, build-for-testing del árbol sin tocar y editar mientras corre
metadata:
  type: feedback
---

Para las capturas de un lote con muchas pantallas (lote decidido 2.2 · 04, 2026-10-19), conducir el simulador a mano con
`axe` costó tres intentos y abrió filas que no tocaba. Lo que funcionó: un `YalaUITests/ZZLote04CapturasUITests.swift`
temporal (molde del `ZZLote19CapturasUITests` de la auditoría) que lanza cada estado con sus seams y escribe PNG a una
ruta del scratchpad.

- `build-for-testing` del árbol SIN tocar con `-derivedDataPath /Volumes/ExtDev/DerivedData/<slug>`; en cuanto termina,
  `test-without-building` de las capturas del «antes» en segundo plano y **ya se puede editar el código**: la corrida usa
  los productos compilados. El mismo conductor saca el «después» y vale de humo de los flujos.
- Lo que no tiene seam (grupo migrado, alerta de error) va con ganchos `#if DEBUG` marcados `LOTE04-TEMP`, que se retiran
  con un grep antes del `/gate`. El conductor se copia al scratchpad y se borra del árbol.
- Al esperar una corrida, **no** `pkill -f` con un patrón que mis propios bucles de espera contienen: se mataron ellos.

**Why:** Jürgen pide antes/después de todo cambio visible y las rutas en el cierre; a mano no escala y el antes se
pierde si se edita primero.

**How to apply:** cualquier encargo con más de dos pantallas que fotografiar. Relacionado:
[[el-antes-sale-del-build-del-rojo]], [[conducir-simulador-con-axe]].
