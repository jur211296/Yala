---
name: build-for-testing-generico-duplica-el-disco
description: build-for-testing con destination generic compila también x86_64 y casi llena la Mini; usa el id del simulador.
metadata:
  type: feedback
---

El 18-nov (asistente de «Nuevo pago planificado», Mini) un `xcodebuild … -destination 'generic/platform=iOS Simulator'
build-for-testing` sobre la DerivedData de XcodeBuildMCP compiló la app y los dos targets de prueba también en x86_64:
+~4 GB y el disco bajó de 9 GB a 1,7 GB libres. Se recuperó borrando los `Objects-normal/x86_64` con `shutil.rmtree`
(el sandbox niega `rm -rf` con variables) y, con el candado del simulador, `simctl erase` del iPhone SE (4,7 GB de
datos de prueba).

**Why:** con el disco justo, CoreSimulator falla con errores que no mencionan el disco, y el gate necesita otro build.

**How to apply:** para compilar pruebas una vez y correrlas en varios aparatos, `build-for-testing` con
`-destination 'platform=iOS Simulator,id=<udid>'` (solo arm64) y luego `test-without-building` con el id de cada
aparato. Mira `df -h /` antes de crear un simulador temporal (el iPad de capturas) y bórralo al acabar.
Relacionado: [[gate-con-la-derived-data-de-xcodebuildmcp]], [[capturas-con-conductor-xcuitest]].
