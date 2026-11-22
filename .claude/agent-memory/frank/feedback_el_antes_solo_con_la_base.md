---
name: el-antes-solo-con-la-base
description: Una clase de capturas con fase antes/después por variable de entorno pisa el «antes» bueno si la repites con la app nueva; el antes solo se corre contra el binario de la base
metadata:
  type: feedback
---

El 2026-11-21 (reglas de captura) la clase `CuentaSolaReglasCapturasUITests` sacaba antes y después según
`TEST_RUNNER_CAPTURA_FASE`. Para corregir el encuadre la repetí con las dos fases sobre la app ya cambiada, y el
«antes» bueno quedó pisado por capturas que enseñaban la sección nueva. Hubo que reconstruir la base con `git archive`
(disco externo, ~15 min) para repetirlo.

**Why:** el nombre del fichero dice «antes», pero lo que sale es lo que hay instalado; nada lo comprueba.
**How to apply:** el «antes» se saca UNA vez, contra la base, y se guarda aparte (o con otro prefijo) antes de editar;
si hay que repetirlo, solo con el binario de la base. Molde para la base: [[antes-del-iphone-con-git-archive]].
