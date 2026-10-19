---
name: conducir-a-mano-contamina-los-unit
description: Lanzar Yala Dev a mano con -uitest-group-invite/solo-grupos deja el eje de sesión privada en los defaults del host, y 16 unit tests de cierre de sesión salen rojos
metadata:
  type: feedback
---

Tras un barrido a mano en el simulador, `erase` antes de volver a correr `YalaTests`. El 2026-10-19 lancé la app con
`-uitest-group-invite -uitest-seed solo-grupos` para capturar la exportación de solo grupos y la corrida siguiente de
unit dio 16 rojos (`path == .privateSignOut` en `GroupsOutboxOwnershipTests` y `PrivateSignOutMigrationGuardTests`, más
uno en `GroupLegWithoutAccountTests`); con el simulador borrado, los 10.759 en verde.

**Why:** los unit tests corren dentro de la app host (mismo bundle `com.jurgenschmidt.yala.dev`, mismos
`UserDefaults`), y ese arranque deja el eje 1 en «sin sesión privada». Parece una regresión del cierre de sesión.

**How to apply:** orden del día de gate: pruebas a mano y capturas DESPUÉS del gate, o `simctl shutdown` + `erase` +
`boot` antes de él. Familia de la regla del teclado de `testing.md` ([[el-tap-de-xcodebuildmcp-se-pierde-en-pantallas-vivas]]).
