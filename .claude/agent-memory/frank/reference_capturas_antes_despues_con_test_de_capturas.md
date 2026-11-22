---
name: capturas-antes-despues-con-test-de-capturas
description: Para el antes/después de una hoja que axe no abre, un XCUITest de capturas que se salta sin CAPTURA_DIR; el «antes» se corre antes de editar esa vista.
metadata:
  type: reference
---

Los chips de cuenta del Panel no abren la hoja de la cuenta con `axe tap` (ni por id ni por coordenada, 22-nov-2026), y
axe no ve lo que hay dentro de una hoja. Lo que funcionó: `HojaCuentaTarjetaCapturasUITests` (y el mismo molde en
`BandejaChipGrupoCapturasUITests`), que se saltan sin `TEST_RUNNER_CAPTURA_DIR` y guardan PNG con
`TEST_RUNNER_CAPTURA_PREFIJO` y `TEST_RUNNER_CAPTURA_TEMA=claro`.

**How to apply:** el «antes» se corre ANTES de tocar la vista que sale en la captura (el test compila tu árbol de
trabajo); lo que no afecta a esa vista se puede ir escribiendo mientras. Ver [[feedback-capturas-de-hojas-con-xcuitest]].
